#!/usr/bin/env bash
# Replace the VERS arg in all .tekton/ pipelines with the given version.
# Usage: hack/openshift/set-tekton-vers.sh <version>

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <version>" >&2
  exit 1
fi

VERSION="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEKTON_DIR="$ROOT/.tekton"

if [ ! -d "$TEKTON_DIR" ]; then
  echo "error: $TEKTON_DIR not found" >&2
  exit 1
fi

# Allow common semver characters (including '+' for build metadata)
regex='^[A-Za-z0-9._+ -]+$'
if ! [[ "$VERSION" =~ $regex ]]; then
  echo "error: invalid version '$VERSION'" >&2
  exit 1
fi

found=0
for file in "$TEKTON_DIR"/*.yaml; do
  if grep -q 'VERS=' "$file"; then
    sed -i "s/VERS=.*/VERS=${VERSION}/" "$file"
    echo "updated $file"
    found=1
  fi
done

if [ "$found" -eq 0 ]; then
  echo "warning: no VERS arg found in $TEKTON_DIR" >&2
fi
