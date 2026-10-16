#!/usr/bin/env bash

# Copyright 2026 The Knative Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

usage() {
  echo "Usage: $0 [--all | --platform GOOS GOARCH]"
  echo "Build all release binaries (default), or one supported platform."
  echo "Set VERS, KVER, HASH and FUNC_UTILS_IMG to override build metadata and helper images."
}

platforms=(linux/amd64 linux/arm64 linux/ppc64le linux/s390x darwin/amd64 darwin/arm64 windows/amd64)
case "${1:---all}" in
  -h|--help)
    usage
    exit 0
    ;;
  -x|--all)
    if (( $# > 1 )); then
      usage >&2
      exit 1
    fi
    ;;
  -p|--platform)
    if (( $# != 3 )); then
      usage >&2
      exit 1
    fi
    supported=false
    for platform in "${platforms[@]}"; do
      if [[ "${platform}" == "$2/$3" ]]; then
        supported=true
        break
      fi
    done
    if [[ "${supported}" != true ]]; then
      echo "Unsupported platform: $2/$3" >&2
      exit 1
    fi
    platforms=("$2/$3")
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# Match the release metadata and helper image flags in the Makefile. Git
# metadata is optional when building from a source archive without .git.
vers="${VERS:-$(git describe --tags --match 'v*' 2>/dev/null || true)}"
kver="${KVER:-$(git describe --tags --match 'knative-*' 2>/dev/null || true)}"
hash="${HASH:-$(git rev-parse --short HEAD 2>/dev/null || true)}"
utils_image="${FUNC_UTILS_IMG:-ghcr.io/knative/func-utils:v2}"
ldflags="-w -s -X knative.dev/func/pkg/version.Vers=${vers}"
ldflags+=" -X knative.dev/func/pkg/version.Kver=${kver}"
ldflags+=" -X knative.dev/func/pkg/version.Hash=${hash}"
ldflags+=" -X knative.dev/func/pkg/k8s.SocatImage=${utils_image}"
ldflags+=" -X knative.dev/func/pkg/k8s.TarImage=${utils_image}"
ldflags+=" -X knative.dev/func/pkg/pipelines/tekton.FuncUtilImage=${utils_image}"

for platform in "${platforms[@]}"; do
  os="${platform%/*}"
  arch="${platform#*/}"
  binary="func_${os}_${arch}"
  if [[ "${os}" == windows ]]; then
    binary+=".exe"
  fi
  echo "Building ${binary}"
  CGO_ENABLED=0 GOOS="${os}" GOARCH="${arch}" \
    go build -trimpath -ldflags "${ldflags}" -o "${binary}" ./cmd/func
done
