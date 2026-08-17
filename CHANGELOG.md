# Changelog

## [Unreleased]

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

### Compatibility

- Existing direct application adapter output remains unchanged.
- Backward-compatibility aliases `#AppCore` and `#ClusterConfig` prevent breaking legacy stacks.
- Downstream renderers may continue using their own projections and can adopt
  `#TopologyAlpha` independently.
- Native CUE OCI consumption requires publishing a version of
  `github.com/epcim/mxc`; no OCI version is currently available.

