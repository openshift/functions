#!/usr/bin/env bash
#
# Build func from this checkout with the PR-built func-utils image baked
# in via ldflags, then run e2e on the claimed cluster.
#
# Downstream: keda deployer, no Serverless. Three slices:
#   --remote: Tekton s2i (sed pack->s2i, same as kn-plugin-func) + PR func-utils
#   Core Go:  host builder on the farm (oci pusher, no daemon)
#   Expose:   host builder + --expose=route (from knative/func #3991)
#
# Required:
#   FUNC_UTILS_IMG  - ci-operator pipeline pullspec for func-util
#   KUBECONFIG      - claimed cluster (Prow cluster_claim)
#

set -o errexit
set -o nounset
set -o pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"

if [[ -z "${FUNC_UTILS_IMG:-}" ]]; then
  echo "FUNC_UTILS_IMG must be set (ci-operator image dependency)" >&2
  exit 1
fi
if [[ -z "${KUBECONFIG:-}" ]]; then
  echo "KUBECONFIG must be set" >&2
  exit 1
fi
if ! command -v oc >/dev/null 2>&1; then
  echo "oc is required on PATH" >&2
  exit 1
fi

echo "=== func-utils image ==="
echo "FUNC_UTILS_IMG=${FUNC_UTILS_IMG}"

# Tests call kubectl. Prow injects oc via cli: latest.
mkdir -p /tmp/bin
ln -sf "$(command -v oc)" /tmp/bin/kubectl
export PATH="/tmp/bin:${PATH}"

export GOPATH="${GOPATH:-/tmp/go}"
export GOCACHE="${GOCACHE:-/tmp/gocache}"
mkdir -p "${GOPATH}" "${GOCACHE}"

# The golang build-root often sets GOFLAGS=-mod=vendor. Makefile assigns
# GOFLAGS with FUNC_UTILS_IMG ldflags, but an environment GOFLAGS wins
# over that assignment. Clear it so make build bakes the PR image.
unset GOFLAGS

echo "=== building func binary ==="
make build FUNC_UTILS_IMG="${FUNC_UTILS_IMG}"

NS="$(oc project -q)"
DOMAIN="$(oc get ingresses.config cluster -o jsonpath='{.spec.domain}')"
REG="${FUNC_E2E_REGISTRY:-ttl.sh/funce2e$(head -c 128 </dev/urandom | LC_CTYPE=C tr -dc 'a-z0-9' | head -c 6)}"

export FUNC_E2E_BIN="${ROOT}/func"
export FUNC_E2E_KUBECONFIG="${KUBECONFIG}"
export FUNC_E2E_NAMESPACE="${NS}"
export FUNC_E2E_DOMAIN="${DOMAIN}"
export FUNC_E2E_REGISTRY="${REG}"
export FUNC_E2E_VERBOSE="${FUNC_E2E_VERBOSE:-true}"
export FUNC_E2E_DEPLOYER="${FUNC_E2E_DEPLOYER:-keda}"
export FUNC_E2E_ROUTE="${FUNC_E2E_ROUTE:-true}"

echo "=== e2e env ==="
echo "FUNC_E2E_BIN=${FUNC_E2E_BIN}"
echo "FUNC_E2E_NAMESPACE=${FUNC_E2E_NAMESPACE}"
echo "FUNC_E2E_DOMAIN=${FUNC_E2E_DOMAIN}"
echo "FUNC_E2E_REGISTRY=${FUNC_E2E_REGISTRY}"
echo "FUNC_E2E_KUBECONFIG=${FUNC_E2E_KUBECONFIG}"
echo "FUNC_E2E_DEPLOYER=${FUNC_E2E_DEPLOYER}"
echo "FUNC_E2E_ROUTE=${FUNC_E2E_ROUTE}"

echo "=== remote s2i e2e ==="
sed -i 's|"--builder", "pack"|"--builder", "s2i"|' ./e2e/e2e_*.go
sed -i 's|--builder=pack|--builder=s2i|' ./e2e/e2e_*.go
# -skip TestRemote_Deploy_InClusterRegistry: Kind registry hostname.
go test -tags e2e -timeout 90m -count=1 -v \
  -run 'TestRemote_' \
  -skip 'TestRemote_Deploy_InClusterRegistry' \
  ./e2e

echo "=== host builder Go core e2e ==="
# Skip TestCore_CredentialsDockerPusher: pack/s2i use the docker pusher, farm has no daemon.
go test -tags e2e -timeout 90m -count=1 -v \
  -run 'TestCore_' \
  -skip 'TestCore_CredentialsDockerPusher' \
  ./e2e

echo "=== expose e2e ==="
# RouteAllBuilders: pack/s2i need a local daemon.
# RouteRequiresOpenShift / RemoteRouteRequiresOpenShift skip themselves (Kind-only).
go test -tags e2e -timeout 90m -count=1 -v \
  -run 'TestExpose_' \
  -skip 'TestExpose_RouteAllBuilders' \
  ./e2e
