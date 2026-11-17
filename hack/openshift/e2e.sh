#!/usr/bin/env bash
#
# Build func from this checkout and run the e2e suite on an OpenShift cluster
# with no Knative (raw deployer). Run cluster-prepare.sh first. See README.md.
#
# Environment (all optional):
#   FUNC_UTILS_IMG  func-utils image baked into func (default: the downstream
#                   image pinned in Dockerfile.func.rhel9; Prow passes the PR's)
#   KUBECONFIG      default ~/.kube/config
#   NAMESPACE       default: the current oc project
#   REGISTRY        default: a random ttl.sh namespace (anonymous, 24h)
#
# Arguments go to go test and override the defaults below:
#   ./e2e.sh -run TestCore_Deploy_Basic
#   ./e2e.sh -skip '^$'       # also run the tests skipped by default
#   ./e2e.sh -timeout 30m

set -o errexit -o nounset -o pipefail
cd "$(dirname "$0")/../.."

# The compiled-in upstream func-utils deploys an unnamed deployer with
# knative, which this cluster lacks; the git-sourced remote tests name none.
# The downstream image defaults to raw.
FUNC_UTILS_IMG="${FUNC_UTILS_IMG:-quay.io/redhat-user-workloads/ocp-serverless-tenant/functions-utils@$(sed -n 's/^ARG FUNC_UTILS_IMG=.*@//p' Dockerfile.func.rhel9)}"

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
export FUNC_E2E_KUBECONFIG="${KUBECONFIG}"
export FUNC_E2E_NAMESPACE="${NAMESPACE:-$(oc project -q)}"
export FUNC_E2E_REGISTRY="${REGISTRY:-ttl.sh/funce2e$(printf '%04x%04x' "${RANDOM}" "${RANDOM}")}"
export FUNC_E2E_BIN="${PWD}/func"
export FUNC_E2E_VERBOSE="${FUNC_E2E_VERBOSE:-true}"

# The Prow build root sets GOFLAGS=-mod=vendor; this repo has no vendor dir,
# so the go test below would fail.
unset GOFLAGS
make build FUNC_UTILS_IMG="${FUNC_UTILS_IMG}"

# Tests log cluster CPU through kubectl (best effort); oc serves as one.
if ! command -v kubectl >/dev/null; then
  mkdir -p /tmp/bin
  ln -sf "$(command -v oc)" /tmp/bin/kubectl
  export PATH="/tmp/bin:${PATH}"
fi

# The tests hardcode the pack builder; downstream ships s2i. Swap it for this
# run only. Restore from a copy: e2e_podman_test.go has a real --builder=s2i,
# so a reverse sed would break it.
backup="$(mktemp -d)"
cp e2e/e2e_*.go "${backup}/"
trap 'cp "${backup}"/*.go e2e/ && rm -rf "${backup}"' EXIT
sed -i -e 's|"--builder", "pack"|"--builder", "s2i"|' -e 's|--builder=pack|--builder=s2i|' e2e/e2e_*.go

# Skipped: tests needing a Knative Eventing broker, the Kind in-cluster
# registry, or a local container daemon. See the test map in README.md.
go test -tags e2e -count=1 -v -timeout 120m \
  -skip 'TestMetadata_Subscriptions|TestMetadata_TriggerSync|TestRemote_Deploy_InClusterRegistry|TestCore_CredentialsDockerPusher|TestExpose_RouteAllBuilders' \
  ./e2e "$@"
