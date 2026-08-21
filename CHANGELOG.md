# Changelog

## [Unreleased]

### Added

#### Decoupled 4-Stage Lifecycle Pipeline & Modular Adapter System (`mxc.just`)

- **4-Stage Symmetrical Lifecycle Verbs**:
  - `export`: Compiles CUE parameters into `vars.yml` (or outputs single application YAML / expressions to stdout with `-t <tag>` or `-e <expr>`).
  - `build`: Renders manifests offline into `.build/`.
  - `diff`: Previews differences between rendered manifests and the live cluster.
  - `run`: Applies rendered manifests to the target cluster.
  - Backward compatibility aliases: `deploy` and `apply` forward directly to `run`.
- **Decoupled Modular Adapters**:
  - `build-kluctl`, `build-kustomize`, `build-helm`
  - `diff-kluctl`, `diff-kustomize`, `diff-helm`
  - `run-kluctl`, `run-kustomize`, `run-helm`
  - Engine-specific flag isolation: Kluctl argument parsing (`-t` translated to `--include-tag`, diff flag sanitization) isolated strictly inside `*-kluctl` adapter recipes.
- **Global Just Environment & Variable Resolution**:
  - `TARGET := env('MXC_TARGET', env('TARGET', 'cluster-home-mxc'))`
  - `BUILD_DIR := env('BUILD_DIR', root + "/.build")`
  - Recipes use `*args=""` so flag options starting with `-` (e.g. `-t hass`) are captured into `$raw_args` and parsed via `argparse` without binding errors.
- **Just Shebang / Silence Rules Enforcement**:
  - Shebang scripts (`#!/usr/bin/env fish`) hide command echoing by default. Defining them without `@` prefix prevents Just from echoing the script body.
  - Non-shebang recipes use `@` prefix to suppress command line echoing.
  - Child recipe calls inside `mxc.just` use `just -q mxc::<recipe>` to guarantee quiet manifest execution.

#### Target Platform Adaptation & Multi-Plane Bindings (MXC-PROP-004)

- **Target Platform Adaptation Schema (`#Platform` & `schema/platforms/`)**:
  - Pristine `#Platform` primitive with open outer seams (`...`) allowing workloads to specify requirements across distinct runtime environments (`k8s`, `compose`, `aws`, `k0rdent`).
  - Scoped domain specifications:
    - `#PlatformK8s` (`schema/platforms/k8s.cue`): Cluster name, namespace, distribution, storage class mapping, ingress annotations, and scoped engines (`kustomize`, `helmChart`).
    - `#PlatformCompose` (`schema/platforms/compose.cue`): Container names, restart policies, network modes, extra hosts.
    - `#PlatformAWS` (`schema/platforms/aws.cue`): AWS regions, account IDs, IAM roles, S3 buckets, and Terraform modules.
    - `#PlatformK0rdent` (`schema/platforms/k0rdent.cue`): Mirantis K0rdent service templates, multicluster routing, and values.
  - Dedicated `schema/mxc/` package: Consolidated MXC reference profile and composable facets (`#ImageSpec`, `#PortsSpec`, `#StorageSpec`, `#KubeSpec`, `#PlatformMxc`, `#PlatformMxcLab`, `#PlatformSimple`).

- **"Rule of Three Buckets" Workload Architecture**:
  - Cleanly separates workload definitions into **Abstract Intent** (`image`, `ports`, `storage: { size, tier }`, `expose`), **Workload Values Payload** (`values` / `context` 1:1 symmetric bag), and **Platform Scope** (`platform: { k8s, compose, aws, k0rdent }`).
  - Polymorphic `values`: Supports arbitrary non-bjw-s structures (native Helm chart values, Terraform module `tfvars`, Docker Compose variables) based on the target adapter without schema restriction.

- **Non-Breaking Escape Hatch Bridging**:
  - `#AppMxc` automatically bridges root-level `kustomize` and `k0rdent` into `platform.k8s.kustomize` and `platform.k0rdent`, ensuring 100% backward compatibility for all existing cluster workspaces.
  - `#WithPlatform` facet added to `#ClusterConfig`.

- **Multi-Adapter Composition & Execution**:
  - Documented pattern for instantiating upstream and local custom adapters inside an open `adapters: { ... }` registry map satisfying `#Projection: { cluster: #Cluster, output: _ }`.

#### Minimal Core Primitives & Composable Facets (MXC-PROP-003)

- **Ultra-Minimal `#App` Core** (`schema/apps.cue`):
  - Stripped out mandatory container baggage. `#App` now captures only core workload identity (`appName`), open rendering engine selector (`adapter: string | *"export"`), sizing (`flavor`), logical tags (`tags`), and parameters (`values`).
  - Open tail (`...`) allows unrestricted downstream domain extensions without schema collisions.
  - Backward compatibility: `deployment` is automatically bridged to `adapter`.

- **`#AppMxc` Container Workload Contract** (`schema/apps.cue`):
  - Pre-composed intent contract unifying `#App` with container lifecycles (`image`), networking (`ports`, `expose`), storage (`storage`), credentials (`secrets`), and platform escape hatches (`kustomize`, `k0rdent`, `helmChart`).
  - Backward compatibility: Aliased to `#AppSimple` and `#AppCore`. Existing workloads compile with zero code changes.

- **Consolidated MXC Reference Facet Package** (`schema/mxc`):
  - Dedicated package (`github.com/epcim/mxc/schema/mxc`) defining `#ImageSpec`, `#PortsSpec`, `#ExposeSpec`, `#StorageSpec`, `#SecretsSpec`, `#ResourcesSpec`, `#KubeSpec`, and platform profiles (`#PlatformMxc`, `#PlatformMxcLab`, `#PlatformSimple`).
  - Open struct tails (`...`) on all facets allow adding rich metadata (e.g. `pullSecrets`, `digest`, custom annotations) without validation friction.
  - Consolidates reference implementation facets into a clean, unified namespace separated from pristine unopinionated core primitives.

- **OCI Package Name Alignment (`mxc` & `mxc-library`)**:
  - `just oci-package` and `just oci-publish` now target exact CUE module identities by default:
    - **`mxc`** (`ghcr.io/epcim/mxc:<tag>`, module `github.com/epcim/mxc@v0`).
    - **`mxc-library`** (`ghcr.io/epcim/mxc-library:<tag>`, module `github.com/epcim/mxc-library@v0`).
  - Legacy aliases (`core` and `library`) are retained as backward-compatible dispatch targets.
  - Aligned [`.github/workflows/publish-oci.yml`](.github/workflows/publish-oci.yml) and [`docs/oci-publishing.md`](docs/oci-publishing.md).

- **Ultra-Minimal `#Cluster` & Platform Facets** (`schema/cluster.cue`):
  - Ultra-minimal `#Cluster` capturing only compute target identity (`clusterName`), environment tier (`environment`), environment variables (`env`), and custom parameters (`values`).
  - Modular, composable infrastructure facets:
    - `schema.#WithKube`: Attaches Kubernetes distribution and cluster runtime settings.
    - `schema.#WithNetwork`: Attaches NetBox-compatible network/IPAM topology, VLANs, DNS, and VIP pools.
    - `schema.#WithApps`: Attaches categorized application workload inventories.
    - `schema.#WithPolicies`: Attaches validated NetworkPolicy definitions.
  - Backward compatibility: `#ClusterConfig` is aliased to `#Cluster & #WithKube & #WithNetwork & #WithApps & #WithPolicies`.

- **Adapter Extension & Wrapping Patterns**:
  - **Pipeline Wrapping (Composition)**: User repositories (like `cluster-home-mxc`) wrap core projections (`kluctl.#ProjectApp`) and append custom transforms directly to `out`.
  - **Self-Projecting Facet Hooks (`#renderHook`)**: Custom traits embed isolated `#renderHook` definitions auto-merged by adapters.
  - **Plugin Middleware**: Open `plugins: [...]` pipeline for dynamic adapter transformations.

---

### Changed

#### Repository and OCI module layout

- The publishable CUE module moved from the repository root to `module/`.
- The CUE module identity remains `github.com/epcim/mxc`; consumer import paths
  such as `github.com/epcim/mxc/schema` and
  `github.com/epcim/mxc/adapters/kluctl` are unchanged.
- Local examples and tests now resolve the core module from `module/`.
- Generated JSON schemas moved from `schema/` to `docs/generated-schema/`.
- Adapter documentation moved outside the publishable module where it is not
  required at runtime.

The core OCI artifact now includes only:

```text
module/cue.mod/module.cue
module/schema/**/*.cue
module/adapters/**/*.cue
module/adapters/**/*.yml
module/adapters/**/*.yaml
```

Repository automation, AI instructions, environment files, CI workflows,
examples, tests, proposals, generated schemas, and publishing configuration are
outside `module/` and therefore excluded from the CUE OCI artifact.

#### Core primitive standardization & values unification

- Renamed `#AppCore` to **`#App`** in `schema/apps.cue` as the canonical primitive for application workload specifications.
- Renamed `#ClusterConfig` to **`#Cluster`** in `schema/cluster.cue` as the canonical primitive for cluster compute targets.
- Standardized on **`values`** as the primary configuration bag across `#App` and `#Cluster` (`values?: [string]: _`).
- Backward compatibility:
  - Added `#AppCore: #App` alias in `schema/apps.cue`.
  - Added `#ClusterConfig: #Cluster` alias in `schema/cluster.cue`.
  - Added automatic bridging between `context` and `values` (`if context != _|_ { values: context }`).

#### Alpha multi-cluster deployment model

- `#TopologyAlpha` now uses the existing `#App` and `#Cluster`
  schemas directly.
- Reusable applications and clusters remain ordinary CUE definitions and
  imports; there is no separate runtime profile registry.
- Package paths are not used as application-profile identities.
- `#DeployAlpha.instances` models one deployable application instance with its
  configuration, dependencies, context, and placement kept together.
- Placement is an explicit, non-empty list of named clusters.
- Instance map keys are canonical names and derive `name`, `instanceName`, and
  `appInstance`. Simple deployments require no extra naming, while advanced
  deployments may override `instanceName`.
- `#BaseAppAdapter` exposes the same identity fallback without changing its
  existing output contract.
- Deployment-specific reference, rollout, and reconciliation policy remains an
  adapter or controller responsibility instead of using hidden schema fields.

Example identity resolution:

```text
appName = kafka
map key = kafka-ce
name = kafka-ce
instanceName = kafka-ce
appInstance = kafka-ce
```

This allows one reusable CUE application definition to produce multiple named
instances, and one application instance to deploy to multiple named clusters.
The model aligns with K0rdent `MultiClusterService` semantics and allows
adapters to emit one ApplicationSet or service object per application instance.
Cluster-centric inventory can be derived when required.

### Removed

- The disconnected single-cluster alpha `targets -> stack instances` model.
- The unused Argo Workflow projection and its nonexistent runner image.
- The old alpha ApplicationSet projection and renderer-specific ApplicationSet
  schema fields.
- Example and task-runner wiring for the removed Argo Workflow projection.

### Migration & Upgrade Instructions

#### Updating MXC Examples (`examples/cluster-*`)

1. **Update schema references**:
   - Replace `schema.#AppCore` with `schema.#App` in your application definition files (e.g. `examples/cluster-standalone/apps.cue`).
   - If importing `#ClusterConfig`, update to `schema.#Cluster`.
   *(Note: Existing `#AppCore` and `#ClusterConfig` references remain valid through compatibility aliases)*.

2. **Migrate `context` to `values`**:
   - In application and cluster overrides, prefer using `values:` instead of `context:`.
   - Both keys are supported during evaluation; `context` automatically feeds `values`.

3. **Verify compilation**:
   ```bash
   cd examples/cluster-homelab
   cue export -e "cluster" --out yaml
   cue export -e "adapters.catalog.services" --out yaml
   ```

#### Updating `cluster-home-mxc` & Target Cluster Workspaces

1. **Adopt Composed Cluster Schema**:
   In `cluster-home-mxc/cluster.cue` (or `vars-env.cue`):
   ```cue
   package cluster

   import (
     schema "github.com/epcim/mxc/schema:schema"
   )

   // Compose only the required facets:
   cluster: schema.#Cluster &
     schema.#WithKube &
     schema.#WithNetwork &
     schema.#WithApps & {
     clusterName: "home"
     environment: "production"
     kube: {
       type: "talos"
       storage: default: "longhorn"
       ingress: class:   "traefik"
     }
     network: {
       domain: "home.internal"
       vips: k8s_api: address: "192.168.1.10"
     }
   }
   ```

2. **Choose Workload Schemas (`#AppMxc` vs `#App`)**:
   - For standard container applications (with `image`, `ports`, `expose`, `storage`):
     ```cue
     import schema "github.com/epcim/mxc/schema:schema"

     vaultwarden: schema.#AppMxc & {
       appName: "vaultwarden"
       adapter: "kluctl"
       image: repository: "vaultwarden/server"
       ports: http: port: 80
       expose: http: target: "ingress"
     }
     ```
   - For native Helm charts / operators (with raw `values` and custom chart structures):
     ```cue
     traefik: schema.#App & {
       appName: "traefik"
       adapter: "kluctl"
       values: {
         deployment: replicas: 2
       }
     }
     ```

3. **Custom Adapter Wrapping (if adding downstream traits or extensions)**:
   If `cluster-home-mxc` defines custom traits (e.g. `gpu`, `monitoring`), wrap the adapter cleanly without modifying core mxc:
   ```cue
   #HomeAppAdapter: {
     in:  schema.#AppMxc
     out: kluctl.#AppAdapter & { spec: in }
     
     // Append downstream custom manifests/overlays
     if in.gpu != _|_ {
       out: output: overlays: gpu_driver: in.gpu
     }
   }
   ```

#### Updating `mxc-library` (Downstream Stacks)

1. **Update stack definitions (`stacks/**`)**:
   - Change struct signatures from `S=schema.#AppCore & { ... }` to `S=schema.#App & { ... }`.
   - Update scoped sizing/flavor blocks to define `values:`:
     ```cue
     // Before
     _flavor: {
       small: { context: controller_resources: limits: { cpu: "1", memory: "512Mi" } }
     }
     
     // After (recommended)
     _flavor: {
       small: { values: controller_resources: limits: { cpu: "1", memory: "512Mi" } }
     }
     ```
   - Update schema constraint annotations: `valuesSchema: string` (or URL/anchor reference).

2. **Vendor / Dependency Sync**:
   - Update vendir or CUE module dependency tracking `github.com/epcim/mxc` to include the `module/` layout.
   - Run `cue vet ./...` across `mxc-library` to ensure clean unification against `#App`.

#### Adopting the Generic `mxc.just` in Downstream & Follow-Up Projects

Follow-up repositories and downstream projects using MXC can integrate the standardized 4-stage lifecycle pipeline with the following steps:

1. **Import `mxc.just` in Root Justfile**:
   ```just
   # In root Justfile
   set shell := ["bash", "-cu"]
   set export := true
   set positional-arguments

   # Import mxc task module
   mod? mxc 'mxc/mxc.just'
   ```

2. **Configure Environment Defaults**:
   - Set the default cluster target name via environment variable `MXC_TARGET` (or `TARGET`):
     ```bash
     export MXC_TARGET="cluster-prod-mxc"
     ```
   - Alternatively, pass explicit target flags to any command:
     ```bash
     just mxc::build -d cluster-prod-mxc -t app-name
     ```

3. **Standard 4-Stage Lifecycle Invocations**:
   ```bash
   # Stage 1: Export parameters (full vars.yml or single app YAML to stdout)
   just mxc::export                        # Export full target parameters to vars.yml
   just mxc::export -t vaultwarden         # Inspect single application specification
   just mxc::export -e "adapters.catalog"  # Evaluate specific CUE expression

   # Stage 2: Build offline manifests into .build/
   just mxc::build                         # Render all manifests offline
   just mxc::build -t vaultwarden          # Render manifests for single application

   # Stage 3: Preview changes against live cluster
   just mxc::diff -t vaultwarden --dry-run # Preview diff for application

   # Stage 4: Run / apply manifests to cluster
   just mxc::run -t vaultwarden --dry-run  # Dry-run deployment
   just mxc::run -t vaultwarden            # Live deployment (with confirmation)
   just mxc::run -t vaultwarden -y         # Non-interactive deployment
   ```

4. **Modular Adapter Dispatch & Custom Adapters**:
   - Top-level verbs (`build`, `diff`, `run`) automatically inspect the application's `adapter` property in CUE (`kluctl`, `kustomize`, `helm`).
   - For single-app builds with `adapter: "kustomize"`, dispatch routes to `build-kustomize`.
   - For single-app builds with `adapter: "helm"`, dispatch routes to `build-helm`.
   - For default multi-app runs, dispatch routes to `build-kluctl`.
   - Downstream projects can invoke modular adapters directly:
     ```bash
     just mxc::build-kluctl cluster-prod-mxc -t vaultwarden
     just mxc::diff-kluctl cluster-prod-mxc -t vaultwarden --dry-run
     just mxc::run-kluctl cluster-prod-mxc -t vaultwarden --dry-run
     ```

5. **Authoring Rules for Downstream Just Recipes**:
   - **Shebang Recipes** (Fish / Bash scripts): Do **not** prefix recipe names with `@`. Just hides shebang script commands by default; adding `@` forces Just to echo the script lines.
   - **Non-Shebang Recipes** (Native Just commands): Prefix recipe names with `@` (e.g., `@deploy:`, `@build-kustomize:`) to suppress command echoing.
   - **Child Invocations**: When calling sibling recipes from within Just, pass `-q` (`just -q mxc::<recipe>`) to ensure clean output.

### Compatibility

- Existing direct application adapter output remains unchanged.
- Backward-compatibility aliases `#AppCore` and `#ClusterConfig` prevent breaking legacy stacks.
- Downstream renderers may continue using their own projections and can adopt
  `#TopologyAlpha` independently.
- Native CUE OCI consumption requires publishing a version of
  `github.com/epcim/mxc`; no OCI version is currently available.

