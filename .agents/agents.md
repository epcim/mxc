# Local Agent Skill: MXC Platform Architecture & Multi-Agent Workflows

* **Name:** `mxc-platform-general`
* **Role:** Developer & Operator
* **Description:** Unified instruction manual and best-practice workflows for any AI assistant tasked with modifying or extending the Model-X Configuration (MXC) framework inside this repository.

---

## 🚀 Welcome, Agent!

This repository uses **MXC (Model-X Configuration)** as a type-safe, lightweight, and offline parameters compiler sitting upstream of **Kluctl**. 

Before editing any configuration file or writing any CUE schemas, you **MUST** read and understand these operational rules and layouts.

---

## 📁 Layout Boundaries

All MXC configurations are self-contained inside the `./mxc/` directory at the root of the repository:

```text
mxc/                               # Fully self-contained CUE configuration kernel at repository root
+-- cue.mod/                   # CUE module metadata (github.com/epcim/mxc)
    +-- schema/                    # Central, tool-agnostic validation rules
    │   +-- apps.cue               # Workload intent schema (#AppCore)
    │   +-- cluster.cue            # Infrastructure boundaries (#ClusterConfig)
    │   +-- adapter.cue            # Decoupled output adapter interface (#Adapter)
    │
    +-- adapters/                  # Platform Output Adapters (AD-003)
    │   +-- app_template/          # bjw-s app-template logical projection
    │   +-- kluctl/                # Generic Kluctl render manifests & overlays
    │   +-- kustomize-only/        # Direct Kustomize manifest injections
    │
    +-- mxc.just                   # Self-contained task-runner module
```

---

## ⚡ Key Commands

Never run raw shell hacks. Always use the nested, parameterizable `just` task namespace:

```bash
# 1. Validate all schemas & values against type constraints
just mxc::validate

# 2. Compile and output flat parameters (vars.yml) to stdout
just mxc::export

# 3. Generate Editor Autocompletion Schemas
just mxc::schema-export
```

---

## 🎨 Design Principles for CUE Authors

### 1. Separate Workload Intent from Cluster Reality
* **Workload Spec (`apps.cue`):** Focuses strictly on abstract developer requests (`expose: target: "ingress"`, storage sizes). Never leak internal container ports or specific domain suffixes here.
* **Infrastructure Spec (`cluster.cue`):** Maps logical intents to physical cluster capabilities (injecting `storageClass: "longhorn"`, base domains `example.com`, and VIP configurations).

### 2. Standardizing API Endpoints (The API vs Port Isolation Rule)
Never hardcode protocol-specific transport ports (such as SSH running on port 2222) inside standard REST API endpoints (like `RENOVATE_ENDPOINT`).
* **Rule**: Standard web/API integrations must target HTTP/HTTPS (ports 80/443) served by ingress reverse-proxies (like Nginx), letting the router translate raw SSH Git transport traffic independently.

### 3. Centralizing Generic Stack Defaults inside `mxc-library`
To respect the "dry-run, schema-validated parameters" model, common platform defaults (such as Velero S3 credentials patterns, S3 region and path-style configurations, or common port mappings) must be centralized as schema defaults inside `mxc-library/stacks/` rather than duplicated at the cluster-level. This guarantees that environment files (like `apps-infra.cue`) remain perfectly clean and elegant:
```cue
velero: stk_infra.#Velero // No verbose inline boilerplate blocks!
```

### 4. Optional Modular "Clean Stack" Layout & Pure CUE Overlays
To manage highly complex application stacks (e.g., Traefik, Authelia) that require auxiliary custom manifests (like Secrets, IngressRoutes, or custom CRs), we support transitioning from flat `.cue` stack files to organized subdirectories.

* **Optional / Escape-Hatch Only:** This is strictly optional. Do not use this directory nesting for simple or standard workloads (like game pods, single containers, etc.). Simple workloads must continue to use flat, single `.cue` files in `mxc-library/stacks/` to avoid unnecessary nesting and code boilerplate.
* **Zero-Jinja Overlays:** Inside modular subdirectories, auxiliary custom manifests are modeled as native CUE configurations under a `manifests/` or `overlays/` folder rather than legacy Jinja-templated YAML files. This ensures static edit-time validation and eliminates runtime string-replacement interpolation.

```text
mxc-library/stacks/infra/
+-- traefik/
    +-- traefik.cue                       # Core schema and parameter bindings
    +-- manifests/                        # Optional: Pure CUE schemas for auxiliary resources
        +-- cloudflare_api.cue            # Secret defined natively in CUE
        +-- ingress_dashboard.cue         # IngressRoute defined natively in CUE
```

### 5. CUE-Defined Kustomize Overlays (`kustomize.overlays`)
For application instances that require custom Kubernetes resources (such as `IngressRoute`, `Middleware`, or additional config maps) without creating complex subdirectory stacks, developers can use the `kustomize.overlays` list parameter.

* **Type-Safe Serialization**: Developers specify raw Kubernetes API objects as native CUE values in the `kustomize.overlays` list. The compiler projects these directly into `overlays/mxc-overlays.yaml`, serialized as multi-document YAML via Jinja, and includes them automatically in the Kustomize resource list.
* **No Side-Effects**: This allows for complete, verified workloads to be defined inside a single, clean `.cue` file, keeping everything structurally validated and eliminating dynamic variable interpolation errors.

Example:
```cue
hajimari: {
	appName: "hajimari"
	kustomize: {
		namespace: "home"
		overlays: [
			{
				apiVersion: "traefik.io/v1alpha1"
				kind:       "Middleware"
				metadata: name: "hajimari-headers"
				spec: headers: {
					browserXssFilter:     true
					contentTypeNosniff: true
				}
			}
		]
	}
}
```

### 6. Reshaping and Automating the Projection Layer (Future Resiliency)
To stop the high frequency of manual updates within the `projection.cue` translation layers when new application features are added, we have established a strict plan to reshape and automate this pipeline.
* **Practice**: Avoid manually hardcoding specific parameters (like `reloader` or `restart`) inside the central `mxc/adapters/kluctl/projection.cue` kernel. Instead, future additions must favor highly generic metadata pass-through blocks, automated schema-driven code generation, and post-rendering validation checks (such as the KRM pipeline model).
* **Reference**: Refer to the central [**`TODO.md`**](TODO.md) file at the root of the `mxc/` context for detailed action items, design concepts, and development trackers.

### 7. The Phased Deprecation & Backward-Compatibility Pattern
When refactoring schema-level fields or parameters in the core compiler schema (`mxc/schema/`), always maintain 100% backward-compatibility. Since external stack configurations (`mxc-library`) and target environments expect stable variables, schema updates must be executed using a **three-step phased deprecation pattern** rather than breaking immediate cuts:

1. **Step 1: Double-Representation & Auto-Derivation**: Keep legacy properties on the core interfaces (e.g., `#BaseAppAdapter`), but automatically compute/derive their values under-the-hood from the new source of truth. Mark the legacy properties clearly with a `// TODO: Deprecate...` comment.
2. **Step 2: Downstream Migration**: Update downstream repositories (`mxc-library` stacks) and user cluster configs to start consuming the new parameters/structures.
3. **Step 3: Cleanup**: Once all consumers have migrated, safely delete the legacy properties and their auto-derivation blocks from the core compiler schemas.

This ensures zero compilation or parameter-rendering disruption across target platforms during major refactoring efforts.

---

## 🛠️ Verification Checklist (Before Ending Your Turn)

1. **Verify Compilation:** Ensure `just mxc::validate` and `just mxc::export` run in milliseconds with zero warnings and exit with **code 0**.
2. **Review Output:** Run `just mxc::export` and visually inspect that all default container ports are resolved, FQDNs are properly computed, and storage classes are correctly assigned.
3. **Never Manual Edit vars.yml:** If you need to change a port, volume, or IP, update it in the **CUE input source files** (`cluster-home/vars-env.cue` or schemas), then run `just mxc::export` to regenerate the output. Do not edit `cluster-home/vars.yml` directly.
