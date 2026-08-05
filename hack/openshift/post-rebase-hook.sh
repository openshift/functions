#!/bin/bash
# Post-rebase cleanup for OpenShift downstream

# Remove upstream GitHub Actions/Dependabot (disabled in OpenShift org)
rm -rf .github

# Remove upstream OWNERS_ALIASES (knative team aliases don't resolve in OpenShift Prow)
rm -f OWNERS_ALIASES

# Remove ko config (upstream CI only, downstream uses Konflux)
rm -f .ko.yaml

git add -A
# only commit if there are staged changes (no-op if already absent)
git diff --cached --quiet || git commit -m "UPSTREAM: <drop>: Remove upstream-only files not used in OpenShift org"
