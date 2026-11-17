# OpenShift Downstream

Scripts and configuration specific to the OpenShift downstream (openshift/functions).

## Upstream sync

Rebasebot syncs `knative/func:main` to `openshift/functions:main` on weekdays.
Downstream-only changes use `UPSTREAM: <carry>:` commit tags to persist across rebases.

### post-rebase-hook.sh

Runs after each rebasebot sync. Removes files not used in the OpenShift org:
- `.github/` (GitHub Actions disabled)
- `OWNERS_ALIASES` (knative team aliases don't resolve in OpenShift Prow)
- `.ko.yaml` (upstream CI only, downstream uses Konflux)

Commits as `UPSTREAM: <drop>:` so it's recreated each sync.

## E2E tests on OpenShift

The e2e suite runs on a plain OpenShift cluster with no Knative Serving or
Eventing: tests locate the deployed function via `func describe`
(`functionURL` in `e2e/e2e_test.go`) and reach cluster-local routes through an
in-cluster dialer pod. Functions deploy with the raw deployer, the downstream
default; the keda tests select keda themselves.

The same two scripts serve the developer flow (current `oc` context) and Prow
(claimed cluster via KUBECONFIG, PR-built func-utils image via
FUNC_UTILS_IMG). The `e2e.sh` header lists its environment variables.

### Usage

```
oc login <cluster>                                   # OCP 4.x cluster
./hack/openshift/cluster-prepare.sh                  # Pipelines + CMA, fresh namespace
./hack/openshift/e2e.sh                              # whole suite
./hack/openshift/e2e.sh -run TestCore_Deploy_Basic   # one test
./hack/openshift/e2e.sh -skip '^$'                   # also the default-skipped tests
```

`cluster-prepare.sh` installs the operators (safe to re-run) and creates and
switches to a fresh `func-e2e-*` namespace (or `TEST_NAMESPACE`). `e2e.sh`
runs in the current project (override with `NAMESPACE`). It builds `func`
from the checkout, pushes function images to a random anonymous ttl.sh
namespace (images expire within 24h), and swaps the tests' hardcoded `pack`
builder for the downstream `s2i` for the run only (the originals are restored
on exit, so do not edit `e2e/e2e_*.go` during a run). Arguments go to
`go test` and override the script's `-skip` and `-timeout`.

The run leaves the namespace behind for debugging; remove it with
`oc delete project <namespace>`.

### Test map

What each part of the suite needs on the cluster:

| Tests | Deployer / builder | Cluster needs |
|---|---|---|
| `TestCore_*`, `TestLifecycle_*`, `TestMetadata_` (envs, labels, volumes) | raw, host builder | nothing beyond OpenShift; reached cluster-locally via the dialer pod |
| `TestExpose_Route`, `TestExpose_ClusterLocalByDefault`, `TestExpose_RouteDomainTLS` | raw + `--expose=route`, host builder | OpenShift Routes (built in) |
| `TestExpose_Keda*` | keda + `--expose=route`, host builder | Custom Metrics Autoscaler with the HTTP add-on |
| `TestExpose_RemoteRoute`, `TestExpose_RemoteKedaRoute` | `--remote`, raw / keda + `--expose=route` | OpenShift Pipelines; the keda one also the CMA |
| `TestRemote_*` (except `InClusterRegistry`) | `--remote`, s2i builds on-cluster | OpenShift Pipelines; egress to github.com (test sources) and ttl.sh |
| `TestMetadata_Subscriptions*`, `TestMetadata_TriggerSync` | - | Knative Eventing Broker: skipped, no Knative downstream |
| `TestMatrix_*`, `TestPodman_*`, `TestConfigCI_*` | - | self-skip (gated by `FUNC_E2E_MATRIX`, `FUNC_E2E_PODMAN`, `FUNC_E2E_CONFIG_CI`) |
| `TestExpose_RouteRequiresOpenShift`, `TestExpose_RemoteRouteRequiresOpenShift` | - | self-skip on OpenShift (they assert refusal on clusters without Routes) |
| `TestRemote_Deploy_InClusterRegistry` | - | skipped: hardcodes the Kind in-cluster registry |
| `TestCore_CredentialsDockerPusher`, `TestExpose_RouteAllBuilders` | - | skipped: pack/s2i through a local container daemon |

The default skip list is the Knative Eventing, Kind-registry and
local-daemon rows above. `-skip '^$'` runs them too; any `-skip` you pass
replaces the list.

### Tekton Results

`cluster-prepare.sh` disables Tekton Results
(`spec.result.disabled` on the `tektonconfig/config` CR): its TaskRun
finalizer races namespace deletion and hangs suite cleanup.
