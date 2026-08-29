#!/usr/bin/env bash
#
# Prepare a claimed OCP cluster for func remote e2e.
# Downstream path: OpenShift Pipelines + CMA (KEDA HTTP add-on).
#
# Must not source hack/common.sh: that script overwrites KUBECONFIG.
#

set -o errexit
set -o nounset
set -o pipefail

BASEDIR="$(cd "$(dirname "$0")" && pwd)"

if ! command -v oc >/dev/null 2>&1; then
  echo "oc is required on PATH (Prow injects it via cli: latest)" >&2
  exit 1
fi

if [[ -z "${KUBECONFIG:-}" ]]; then
  echo "KUBECONFIG must be set" >&2
  exit 1
fi

wait_for_csv() {
  local ns="$1"
  local name="$2"
  local timeout="${3:-600}"
  local elapsed=0
  local csv=""

  echo "Waiting for subscription ${name} CSV in ${ns}..."
  while [[ -z "${csv}" && "${elapsed}" -lt "${timeout}" ]]; do
    csv="$(oc get subscription.operators.coreos.com -n "${ns}" "${name}" -o jsonpath='{.status.installedCSV}' 2>/dev/null || true)"
    if [[ -z "${csv}" ]]; then
      echo "Subscription ${name} has no installedCSV yet..."
      sleep 5
      elapsed=$((elapsed + 5))
    fi
  done
  if [[ -z "${csv}" ]]; then
    echo "timed out waiting for subscription ${name} in ${ns}" >&2
    oc get subscription.operators.coreos.com,csv -n "${ns}" || true
    return 1
  fi
  echo "Waiting for CSV ${csv} in ${ns}"
  oc wait csv -n "${ns}" "${csv}" \
    --for=jsonpath='{.status.phase}'=Succeeded \
    --timeout="${timeout}s"
}

TEST_NAMESPACE="${TEST_NAMESPACE:-func-e2e-$(head -c 128 </dev/urandom | LC_CTYPE=C tr -dc 'a-z0-9' | fold -w 6 | head -n 1)}"
oc new-project "${TEST_NAMESPACE}" || true
oc project "${TEST_NAMESPACE}"
echo "Using namespace ${TEST_NAMESPACE}"

echo "Installing OpenShift Pipelines"
oc apply -f "${BASEDIR}/deploy/pipelines-subscription.yaml"
wait_for_csv openshift-operators openshift-pipelines-operator-rh
oc wait --for=condition=Established crd/pipelineruns.tekton.dev --timeout=120s
oc wait --for=condition=Established crd/tasks.tekton.dev --timeout=120s

echo "Installing Custom Metrics Autoscaler (KEDA)"
oc apply -f "${BASEDIR}/deploy/cma-subscription.yaml"
wait_for_csv openshift-keda openshift-custom-metrics-autoscaler-operator
oc wait --for=condition=Established crd/kedacontrollers.keda.sh --timeout=120s

echo "Creating KedaController with HTTP add-on"
oc apply --server-side --force-conflicts -f "${BASEDIR}/deploy/keda-controller.yaml"
oc wait deployment --all --timeout=10m --for=condition=Available -n openshift-keda

echo "Cluster prepare complete (Pipelines + CMA, no Serverless)"
echo "TEST_NAMESPACE=${TEST_NAMESPACE}"
