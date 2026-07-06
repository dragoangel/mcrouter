#!/usr/bin/env bash
# Lint and render-check the chart the same way CI does, so you can catch
# problems before pushing. Renders both workload types (StatefulSet and
# DaemonSet) and verifies the artifacthub.io/images annotation is in sync with
# the images the chart actually renders.
#
# Requires: helm, yq.
set -euo pipefail

chart="$(cd "$(dirname "$0")/.." && pwd)/charts/mcrouter"

helm dependency build "$chart"
helm lint "$chart"
helm template t "$chart" --set deploymentType=DaemonSet >/dev/null

# Verify the artifacthub.io/images annotation matches the images the chart
# renders. Artifact Hub shows this list on the package page and scans it for
# CVEs, so a stale/wrong entry misinforms users and breaks scanning. We compare
# against the rendered output rather than re-deriving from values.yaml, which
# would duplicate template logic like `tag | default .Chart.AppVersion`.
#   metrics.enabled=true    - include the exporter sidecar image
#   memcached.enabled=false - exclude the subchart image (memcached documents
#                             its own artifacthub.io/images)
rendered="$(helm template t "$chart" \
  --set metrics.enabled=true --set memcached.enabled=false \
  | grep -oE '^[[:space:]]*image:[[:space:]]*\S+' \
  | awk '{print $2}' | sort -u)"

declared="$(helm show chart "$chart" \
  | yq -r '.annotations."artifacthub.io/images"' \
  | yq -r '.[].image' | sort -u)"

if ! diff <(echo "$rendered") <(echo "$declared") >/dev/null; then
  echo "::error::artifacthub.io/images is out of sync with the images the chart renders (< rendered, > declared):"
  diff <(echo "$rendered") <(echo "$declared") || true
  exit 1
fi
echo "artifacthub.io/images matches rendered images"
