# mcrouter Helm chart

Deploys [mcrouter](https://github.com/facebook/mcrouter), a memcached protocol router, using the
maintained image published from this repository (`ghcr.io/dragoangel/mcrouter`).

## Install

The chart is published as an OCI artifact to GHCR:

```sh
helm install mcrouter oci://ghcr.io/dragoangel/charts/mcrouter --version 0.1.3
```

The chart is cosign-signed (keyless); verify it with:

```sh
cosign verify ghcr.io/dragoangel/charts/mcrouter:0.1.3 \
  --certificate-identity-regexp '^https://github.com/dragoangel/mcrouter/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Or straight from source:

```sh
helm dependency build charts/mcrouter
helm install mcrouter charts/mcrouter
```

To use an external memcached, set `memcached.enabled: false` and pass your own
`config`.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| clusterSuffix | string | `"cluster.local"` | Kubernetes cluster DNS suffix (used to build memcached pod hostnames) |
| commonLabels | object | `{}` | Extra labels applied to all resources |
| config | string | `""` | Custom mcrouter JSON config. If empty, one is generated from the memcached replicas. https://github.com/facebook/mcrouter/wiki/Config-Files |
| containerSecurityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true}` | Container-level security context (no privilege escalation, read-only rootfs, all caps dropped) |
| daemonset.hostPort | int | `5000` | Host port for the mcrouter pod (DaemonSet) |
| deploymentType | string | `"StatefulSet"` | Workload type: StatefulSet or DaemonSet |
| extraArgs | list | `[]` | Extra CLI args appended to the mcrouter command (e.g. fibers-max-pool-size=256) |
| extraEnvVars | list | `[]` | Extra environment variables for the mcrouter container (list of {name,value} or valueFrom). e.g. GLIBCXX_FORCE_NEW=1 / MALLOC_ARENA_MAX=1 to curb RSS growth. |
| extraObjects | list | `[]` | Extra raw manifests to render with the release (templated) |
| extraVolumeMounts | list | `[]` | Additional volume mounts for the mcrouter container |
| extraVolumes | list | `[]` | Additional volumes for the pod |
| fullnameOverride | string | `""` | Override the full resource name |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| image.registry | string | `"ghcr.io"` | Image registry |
| image.repository | string | `"dragoangel/mcrouter"` | Image repository (built and published from this repository) |
| image.tag | string | `""` | Image tag; defaults to the chart appVersion when empty |
| imagePullSecrets | list | `[]` | Image pull secrets for private registries |
| livenessProbe.enabled | bool | `true` | Enable the liveness probe (TCP on the mcrouter port) |
| livenessProbe.failureThreshold | int | `3` |  |
| livenessProbe.initialDelaySeconds | int | `30` |  |
| livenessProbe.periodSeconds | int | `10` |  |
| livenessProbe.successThreshold | int | `1` |  |
| livenessProbe.timeoutSeconds | int | `5` |  |
| memcached | object | `{"config":{"maxconns":1024,"memory":"128m"},"deploymentType":"StatefulSet","enabled":true,"pdb":{"create":true,"minAvailable":"1"},"replicaCount":2,"resources":{"limits":{"memory":"160Mi"},"requests":{"cpu":"100m","memory":"144Mi"}}}` | CloudPirates memcached dependency (StatefulSet). Set enabled: false to point mcrouter at an external memcached via the config value. |
| metrics.container.port | int | `9442` | Exporter metrics port |
| metrics.enabled | bool | `false` | Run a Prometheus exporter sidecar |
| metrics.image.registry | string | `"ghcr.io"` | Exporter image registry |
| metrics.image.repository | string | `"dev25/mcrouter_exporter"` | Exporter image repository |
| metrics.image.tag | string | `"0.5.0"` | Exporter image tag |
| metrics.podMonitor.enabled | bool | `false` | Create a PodMonitor for the exporter |
| metrics.resources | object | `{"limits":{"memory":"24Mi"},"requests":{"cpu":"50m","memory":"16Mi"}}` | Exporter container resources |
| nameOverride | string | `""` | Override the chart name used in resource names and labels |
| nodeSelector | object | `{}` | Node selector for the pods |
| pdb.create | bool | `true` | Create a PodDisruptionBudget (StatefulSet only) |
| pdb.minAvailable | int | `1` | Minimum available routers during voluntary disruptions |
| podAnnotations | object | `{}` | Extra pod annotations |
| podLabels | object | `{}` | Extra pod labels |
| podSecurityContext | object | `{"fsGroup":1001,"runAsGroup":1001,"runAsNonRoot":true,"runAsUser":1001,"seccompProfile":{"type":"RuntimeDefault"}}` | Pod-level security context (hardened: non-root uid 1001, seccomp RuntimeDefault) |
| port | int | `5000` | Port mcrouter listens on |
| priorityClassName | string | `""` | Priority class for the pods |
| readinessProbe.enabled | bool | `true` | Enable the readiness probe (TCP on the mcrouter port) |
| readinessProbe.failureThreshold | int | `3` |  |
| readinessProbe.initialDelaySeconds | int | `5` |  |
| readinessProbe.periodSeconds | int | `5` |  |
| readinessProbe.successThreshold | int | `1` |  |
| readinessProbe.timeoutSeconds | int | `5` |  |
| resources | object | `{"limits":{"memory":"86Mi"},"requests":{"cpu":"50m","memory":"64Mi"}}` | mcrouter container resources |
| service | object | `{"annotations":{},"clusterIP":"None","externalTrafficPolicy":null,"port":5000}` | Service for mcrouter (headless by default) |
| serviceAccount.annotations | object | `{}` | Annotations for the ServiceAccount |
| serviceAccount.automountServiceAccountToken | bool | `false` | Mount the API token (mcrouter needs no cluster API access) |
| serviceAccount.create | bool | `true` | Create a dedicated ServiceAccount |
| serviceAccount.name | string | `""` | ServiceAccount name (defaults to the fullname) |
| statefulset.antiAffinity | string | `"soft"` | Pod anti-affinity: soft or hard |
| statefulset.replicas | int | `2` | Number of mcrouter replicas (StatefulSet) |
| tmpfs.medium | string | `"Memory"` | Backing medium for the writable dirs: Memory (tmpfs) or "" (disk emptyDir) |
| tmpfs.runtimeSizeLimit | string | `"16Mi"` | Cap for /var/mcrouter (stats/fifos/config). Caps are not reservations. |
| tmpfs.spoolSizeLimit | string | `"32Mi"` | Cap for /var/spool/mcrouter (async delete spool); raise for heavy reliable-delete use |
| tolerations | list | `[]` | Tolerations for the pods |

This table and `values.schema.json` are generated from `values.yaml` by
`scripts/helm-gen-docs-and-schema.sh`; don't edit them by hand.

## Attribution

mcrouter itself is © Facebook/Meta, MIT-licensed.
