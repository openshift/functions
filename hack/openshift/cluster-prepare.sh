#!/usr/bin/env bash
#
# Prepare an OpenShift cluster for e2e.sh: install OpenShift Pipelines and the
# Custom Metrics Autoscaler (KEDA with the HTTP add-on) on the cluster of the
# current oc context, then create and switch to a fresh test namespace.
# Safe to re-run. See README.md.
#
# Must not source hack/common.sh: that script overwrites KUBECONFIG.

set -o errexit -o nounset -o pipefail
cd "$(dirname "$0")/deploy"

# Run a command until it succeeds. A freshly installed operator serves its
# CRDs and resources late. Tries are quiet; the last one shows its error.
retry() {
  for _ in $(seq 30); do
    "$@" >/dev/null 2>&1 && return
    sleep 10
  done
  "$@"
}

oc apply -f pipelines-subscription.yaml -f cma-subscription.yaml

# Ready implies the CSV, the controller and the webhook are up. The CSV can
# succeed before the CRDs exist (openshift/functions#61), so wait on them too.
retry oc wait tektonpipeline/pipeline --for=condition=Ready --timeout=30s
retry oc wait crd/pipelineruns.tekton.dev crd/tasks.tekton.dev \
  --for=condition=Established --timeout=30s

# Tekton Results' TaskRun finalizer races namespace deletion and hangs suite
# cleanup. The field is "result", singular; "results" is ignored.
oc patch tektonconfig config --type=merge -p '{"spec":{"result":{"disabled":true}}}'

# The apply fails until the KedaController CRD exists. The operator's own
# deployment is in openshift-keda too, so wait on each operand by name:
# "oc wait deployment --all" can pass before they are created.
retry oc apply --server-side --force-conflicts -f keda-controller.yaml
for d in keda-operator keda-metrics-apiserver keda-admission \
  keda-add-ons-http-operator keda-add-ons-http-interceptor keda-add-ons-http-scaler; do
  retry oc wait -n openshift-keda "deployment/${d}" --for=condition=Available --timeout=30s
done

ns="${TEST_NAMESPACE:-func-e2e-$(printf '%04x%04x' "${RANDOM}" "${RANDOM}")}"
oc new-project "${ns}" >/dev/null 2>&1 || oc project "${ns}"
echo "Cluster ready. Current project: ${ns}"
