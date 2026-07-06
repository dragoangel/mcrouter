#!/usr/bin/env bash
# Regenerate the chart's values.schema.json and README.md from values.yaml.
# Run after editing values.yaml or README.md.gotmpl; don't hand-edit the outputs.
#
#   values.schema.json - helm-values-schema-json plugin: types are inferred,
#                        constraints come from `# @schema ...` annotations.
#   README.md          - helm-docs: `# --` comments become the values table,
#                        rendered into README.md.gotmpl.
#
# Requires (versions pinned so output matches CI):
#   helm plugin install https://github.com/losisin/helm-values-schema-json --version v2.5.0 --verify=false
#   go install github.com/norwoodj/helm-docs/cmd/helm-docs@v1.14.2
set -euo pipefail

chart="$(cd "$(dirname "$0")/.." && pwd)/charts/mcrouter"

# --- values.schema.json ---
helm plugin list 2>/dev/null | grep -q '^schema' || {
  echo "installing helm schema plugin..." >&2
  helm plugin install https://github.com/losisin/helm-values-schema-json --version v2.5.0 --verify=false
}
helm schema \
  -f "$chart/values.yaml" \
  -o "$chart/values.schema.json" \
  --draft 7 \
  --schema-root.additional-properties
echo "wrote $chart/values.schema.json"

# --- README.md ---
command -v helm-docs >/dev/null || {
  echo "helm-docs not found; install: go install github.com/norwoodj/helm-docs/cmd/helm-docs@v1.14.2" >&2
  exit 1
}
helm-docs --chart-search-root "$chart" --template-files README.md.gotmpl
echo "wrote $chart/README.md"
