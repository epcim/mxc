# Local Agent Skill: MXC Platform Architecture & Compilation

* **Name:** `mxc-platform-skill`
* **Description:** Provides instruction patterns and execution workflows for AI agents tasked with modifying or extending the Model-X Configuration (MXC) framework inside this repository.

---

## 🚀 Welcome, Agent!

This repository uses **MXC (Model-X Configuration)** as a type-safe, lightweight, and offline parameters compiler sitting upstream of **Kluctl**. 

Before editing any configuration file or writing any CUE schemas, you **MUST** read and understand these operational rules and layouts.

---

## 📁 Layout Boundaries

All MXC configurations are self-contained inside the `./mxc/` directory at the root of the repository:

```text
mxc/                               # Fully self-contained CUE configuration kernel at repository root
├── cue.mod/                       # CUE module metadata (github.com/epcim/mxc)
├── schema/                        # Central, tool-agnostic validation rules
│   ├── apps.cue                   # Workload intent schema (#AppCore)
│   ├── cluster.cue                # Infrastructure boundaries (#ClusterConfig)
│   └── adapter.cue                # Decoupled output adapter interface (#Adapter)
│
├── cluster-home-mxc/              # active environment overrides (Idea 2 Layer)
│   └── vars-env.cue               # Maps applications to physical IPs, domains, and VIPs
│
└── mxc.just                       # Self-contained task-runner module
```

---

## ⚡ Key Commands

Never run raw shell hacks. Always use the nested, parameterizable `just` task namespace:

```bash
# 1. Validate all schemas & values against type constraints
just mxc::validate

# 2. Compile and output flat parameters (vars.yml) to stdout for a specific cluster
just mxc::export cluster-home-mxc

# 3. Compile and save validated parameters directly for Kluctl
just mxc::export cluster-home-mxc > cluster-home-mxc/vars.yml
```

> [!IMPORTANT]
> **Directory Scoping:** Do NOT use `[no-cd]` or hardcode `cd mxc &&` inside the Justfile recipes. The nested task runner is designed to let the `just` engine switch directory context natively.

---

## 🎨 Design Principles for CUE Authors

### Principle 1: Separate Workload Intent from Cluster Reality
* **workload spec (`apps.cue`):** Focuses strictly on abstract developer requests (`expose: target: "ingress"`, storage sizes). Never leak internal container ports or specific domain suffixes here.
* **Infrastructure spec (`cluster.cue`):** Maps logical intents to physical cluster capabilities (injecting `storageClass: "longhorn"`, base domains `example.com`, and VIP configurations).

### Principle 2: Native Pluggable Adapter Pattern & Flat Projection (#Projection)
Do not pollute core schemas with target-specific properties. If you need to generate ArgoCD CRDs, Terragrunt variables, or Prometheus rules, implement a custom adapter utilizing the approved **Flat Adapter Projection (`#Projection`)** pattern:

1. **Top-Ordering of #AppAdapter**: `#AppAdapter` MUST always be defined first inside each `projection.cue` file (directly below the package header and import blocks). This guarantees instant readability of the individual application parameters translation layer before looking at the bulk cluster-wide `#Projection` structures.
2. **Decoupled Metadata Assignment**: To prevent parameter leakage, `#BaseAppAdapter` in `schema/adapter.cue` defines only universally safe attributes (`appName`, `deployment`). Sibling adapters must explicitly repeat only the direct metadata assignments they actually utilize inside their own `#AppAdapter.output` definition block:
   ```cue
   // Example inside kluctl output adapter
   #AppAdapter: S=schema.#BaseAppAdapter & {
       output: {
           // Direct metadata delivery: explicitly maps only consumed properties
           if S.spec.tags != _|_ { tags: S.spec.tags }
           if S.spec.secrets != _|_ { secrets: S.spec.secrets }
           if S.spec.values != _|_ { values: S.spec.values }
           ...
       }
   }
   ```
3. **Flat Projection Pattern (`#Projection`)**: Avoid over-abstracted wrappers (like `.input` and `.output`). The adapter's top-level fields are the output parameters themselves, dramatically simplifying the evaluation structure.
4. **Public Scoping for Primary Inputs**: The primary input block MUST be a public field (`cluster: schema.#ClusterConfig`) to allow parametrizing from downstream environment files (e.g. `globals.cue` in `package mxc` instantiating adapters in `package kluctl`). Private fields (prefixed with `_`) are package-private in CUE and cannot be accessed across packages.
5. **Circular Scoping Mitigation**: To prevent self-referencing loops (e.g. `cluster: cluster`), declare a local alias outside the struct literal (`let _clusterVal = cluster`) and bind it (`cluster: _clusterVal`).
6. **Post-Export Key Filtering**: To ensure the exported `vars.yml` contains pure, concrete configuration fields, standard exported expressions (like `mxc_vars`) MUST filter out the schema-level `cluster` key:
   ```cue
   mxc_vars: {
       for k, v in adapters.kluctl if k != "cluster" {
           "\(k)": v
       }
   }
   ```
7. **Modular Adapter Fixtures (`fixtures.cue`) [Optional]**: Move complex, template-specific default coordinates, storage volumes/overlays mappings, and polymorphic values mappings out of `projection.cue` and into separate `fixtures.cue` (or `fixtures-apptemplate.cue`) files inside the same package. Use CUE's struct-alias pattern (`#AppAdapter: S={ ... }`) inside the fixture files to resolve lexical scope variables (e.g. `S.spec`, `S.domain`) safely and elegantly. This keeps the main projection file clean, high-level, and easy to read.

Example structure:
```cue
package your_adapter

import "github.com/epcim/mxc/schema:schema"

// #AppAdapter is always defined FIRST at the top of the file!
#AppAdapter: S=schema.#BaseAppAdapter & {
    output: {
        // Explicit metadata mappings used by this adapter
        if S.spec.tags != _|_ { tags: S.spec.tags }
        if S.spec.values != _|_ { values: S.spec.values }
    }
}

// #Projection projects a ClusterConfig into flat parameters
#Projection: {
    cluster: schema.#ClusterConfig

    // Flat output fields directly declared at the top-level
    clusterName: cluster.clusterName
    environment: cluster.environment

    // Map workloads using our simplified, declarative #AppAdapter
    apps: {
        for catKey, catApps in cluster.apps {
            for appKey, appSpec in catApps {
                "\(appKey)": (#AppAdapter & { spec: appSpec }).output
            }
        }
    }
}
```

### Principle 3: Referential Integrity with Key-Mapping
To avoid duplicate key specifications (like typing `portName: "http"` inside an exposure map), design schemas so that **exposure keys correspond directly to service ports**. Always use CUE pattern-constraints and let-expressions to fail compilation if an exposure references an undefined port:

```cue
#AppCore: {
	ports: [string]: #PortSpec
	expose: [PortName=string]: {
		let portCheck = ports[PortName]
		if portCheck == _|_ { _|_ } // Compile-time failure on invalid key mappings!
		
		target: "ingress" | "loadbalancer" | "internal"
	}
}
```

### Principle 4: Prefer Direct Projection, Add State Files Only Deliberately
MXC should compile directly to the deployer-facing output by default.

Only introduce an intermediate state artifact when it serves as a stable contract for multiple downstream consumers that cannot evaluate CUE themselves. If you add such a state layer, document who reads it and why it exists.

## 🔄 Downstream Schema Evolution & Adapter-Driven Adaptation Process

When downstream deployment components (such as `bjw-s` app-template or third-party helm schemas) receive updates, they can introduce structural changes or schema drift. To prevent these changes from breaking individual application definitions, we establish a strict **Adapter-Driven Adaptation Process**:

### 1. Schema Drift Identification
* **Process:** Run `just mxc::schema-export` (or equivalent schema fetchers) to update and diff downstream schemas (such as updating raw JSON schemas or helm charts). This identifies structural shifts (such as renamed controller attributes, modified volume keys, or ingress structures).

### 2. Isolate Mapping Updates to the Adapter Layer
* **The Golden Rule:** **NEVER** modify individual application definitions (`.cue` files under `mxc-library/stacks/` or `cluster-home-mxc/`) to match updated downstream physical structures.
* **The Fix:** Implement structural translations solely inside the **CUE Adapter Layer** (e.g., `mxc/adapters/app_template/projection.cue`). The adapter acts as a unified mapping engine, projecting our stable, tool-agnostic `#AppCore` logical fields into the updated downstream-specific physical formats.
* **Why:** This completely insulates the developer-facing application contracts from third-party chart fluctuations. If `bjw-s` moves `ports` or reorganizes `controllers`, we only edit `projection.cue` *once*, instantly fixing compilation for all applications!

### 3. Verification & Validation
* Always run `just mxc::validate` and `just mxc::export` to ensure the updated adapter is structurally sound and compiles all environments cleanly with zero conflicts.

---

### Principle 5: Use Deterministic Derived Identities for Infra
When modeling infrastructure identities derived from stable names, compute them in CUE instead of tracking them manually.

For future `infra/proxmox/` VM modeling, prefer deterministic MAC generation from canonical hostnames so repeated renders stay stable and conflict-free.

### Principle 6: Close Inner Schemas, Keep Outer Extension Surfaces Intentional
Use `close({...})` on deep, typo-sensitive configuration blocks so invalid keys fail immediately during `cue vet` or export.

Keep only the outermost integration points open with `...` where additive composition is explicitly intended, such as plugin-style extension surfaces.

### Principle 7: Marshal Embedded YAML or JSON from Native CUE Values
If a CRD or rendered object needs an embedded YAML or JSON string payload, define that payload as native CUE data first and marshal it with `yaml.Marshal` or `json.Marshal`.

This keeps embedded documents structurally validated at compile time instead of treating them as unchecked multiline strings.

### Principle 8: Optional Modular "Clean Stack" Layout & Pure CUE Overlays
For highly complex application stacks (e.g., Traefik, Authelia) that require auxiliary custom manifests (like Secrets, IngressRoutes, or custom CRs), you may optionally transition from flat `.cue` stack files to organized subdirectories. 

* **This is completely optional:** Do NOT use subdirectories for simple deployments (e.g. game pods, single containers, lightweight utilities). Flat `.cue` files in `mxc-library/stacks/` remain the standard, cleanest way to avoid unnecessary boilerplate.
* **Pure CUE Overlays (Zero-Jinja):** When using subdirectories, auxiliary custom manifests should be modeled natively as validated CUE configurations inside a `manifests/` or `overlays/` folder rather than using legacy hybrid Jinja-templated YAML files. They will compile directly into static manifests at export time.
* **Global Kustomize Namespace Injection Rule (Best Practice):** Never define or hardcode dynamic `namespace` fields inside individual overlay files or templates. Instead, define `namespace: xyz` under the application's Kustomize spec (`kustomize.namespace`). Kustomize automatically patches and injects that namespace onto all processed manifests in that directory context, keeping overlays extremely lean and decoupling manifest templates from deployment targets.

```text
mxc-library/stacks/infra/
+-- traefik/
    +-- traefik.cue                       # Core schema and parameter bindings
    +-- manifests/                        # Optional: Pure CUE schemas for auxiliary resources
        +-- cloudflare_api.cue            # Secret defined natively in CUE (no hardcoded namespace!)
        +-- ingress_dashboard.cue         # IngressRoute defined natively in CUE (no hardcoded namespace!)
```

### Principle 9: CUE-Defined Kustomize Overlays (`kustomize.overlays`)
For application instances that require custom Kubernetes resources (such as `IngressRoute`, `Middleware`, or additional config maps) without creating complex subdirectory stacks, developers can use the `kustomize.overlays` list parameter.

* **Type-Safe Serialization**: Developers specify raw Kubernetes API objects as native CUE values in the `kustomize.overlays` list. The compiler projects these directly into `overlays/mxc-overlays.yaml`, serialized as multi-document YAML via Jinja, and includes them automatically in the Kustomize resource list.
### Principle 10: Reshaping and Automating the Projection Layer (Future Resiliency)
To stop the high frequency of manual updates within the `projection.cue` translation layers when new application features are added, we have established a strict plan to reshape and automate this pipeline.
* **Practice**: Avoid manually hardcoding specific parameters (like `reloader` or `restart`) inside the central `mxc/adapters/kluctl/projection.cue` kernel. Instead, future additions must favor highly generic metadata pass-through blocks, automated schema-driven code generation, and post-rendering validation checks (such as the KRM pipeline model).
* **Reference**: Refer to the central [**`TODO.md`**](TODO.md) file at the root of the `mxc/` context for detailed action items, design concepts, and development trackers.

### Principle 11: Derive, Don't Duplicate
When a single logical value (an FQDN, a URL built from it, a hostname list) is needed in more than one place, define it once and reference it everywhere else — never repeat the literal, since the copies will drift apart the moment one is edited and the other is forgotten.

* Reference a same-level sibling field directly by name when both live in the same struct literal:
  ```cue
  context: {
  	expose: ingress: hosts: core: string
  	externalURL: "https://\(expose.ingress.hosts.core)"  // harbor.cue
  }
  ```
* Reach a value nested at a different level via the stack's own `S=schema.#AppCore & {...}` self-alias:
  ```cue
  #Authelia: S=schema.#AppCore & {
  	context: ingress: main: hosts: [{host: S.expose.http.fqdn}]  // authelia.cue
  }
  ```
* At a `cluster-home-mxc` override call site, bind a computed value once with `let` and reference the binding everywhere it's needed at that site, instead of repeating the interpolation across `env`, `ingress.hosts`, and `ingress.tls`.

### Principle 12: Cross-App Context References as Composition
Stack files inside the same `mxc-library/stacks/<category>` directory share one CUE package, so CUE resolves identifiers at the package level, not per-file — a definition in one file can reference another definition's fields directly by name, with no import needed. Use this to eliminate cross-app duplication (a hostname, a service name) instead of copying the value into every app that needs it. Example: the monitoring stack's `#Grafana` references `#Mimir.kustomize.namespace` and `#Loki.appName` directly. This only applies within the same package — across categories, use the normal `cluster-home-mxc/apps-*.cue` override wiring instead of adding cross-package imports between stack files.

### Principle 13: Import-Alias Naming Convention & the Self-Reference Collision Hazard
Every `cluster-*-mxc/apps-*.cue` file imports one or more `mxc-library/stacks/<name>` packages under a short alias. Convention: `s` + a 3-4 letter abbreviation of the stack folder (`sinf`, `snet`, `scic`, `smed`, `sgam`, `shmr`, `stg`; `mon` for `stacks/monitoring` is the one deliberate exception).

**Never alias an import to the exact name of the enclosing struct field it will be used under** (e.g. importing `stacks/cicd` as bare `cicd` inside a file defining `cluster: apps: cicd: {...}`). CUE resolves a bare identifier from the nearest enclosing scope — when the alias matches the enclosing field's own label, a reference inside that field's value resolves to the field itself (self-reference), not the import. The import is then never actually consumed and `cue vet` fails with `imported and not used`, even though the alias is visibly present in the file. This has hit twice in this codebase (`cicd`/`scic`, `kluctl`/`adp_kluctl`) — the `s`-prefix (or `adp_`-prefix for adapters) convention exists specifically to make this collision structurally impossible.

### Principle 14: The Phased Deprecation & Backward-Compatibility Pattern
When refactoring schema-level fields or parameters in the core compiler schema (`mxc/schema/`), always maintain 100% backward-compatibility. Since external stack configurations (`mxc-library`) and target environments expect stable variables, schema updates must be executed using a **three-step phased deprecation pattern** rather than breaking immediate cuts:

1. **Step 1: Double-Representation & Auto-Derivation**: Keep legacy properties on the core interfaces (e.g., `#BaseAppAdapter`), but automatically compute/derive their values under-the-hood from the new source of truth. Mark the legacy properties clearly with a `// TODO: Deprecate...` comment.
2. **Step 2: Downstream Migration**: Update downstream repositories (`mxc-library` stacks) and user cluster configs to start consuming the new parameters/structures.
3. **Step 3: Cleanup**: Once all consumers have migrated, safely delete the legacy properties and their auto-derivation blocks from the core compiler schemas.

This ensures zero compilation or parameter-rendering disruption across target platforms during major refactoring efforts.

---

## 📥 Schema Acquisition & Storage Workflows

When adding new applications or custom controllers, you must acquire their upstream/CRD schemas and store them inside `/mxc/schema/` to ensure full CUE-level validation and LSP autocompletion.

### 1. Acquiring Standard Upstream Schemas (SchemaStore)
For standard specs (e.g., Kustomize, Docker-Compose, Prometheus Rules) that exist on [SchemaStore](https://www.schemastore.org/), import them directly as CUE type-definitions:
```bash
# Example: Fetch and convert Kustomize SchemaStore spec into mxc/schema/kustomize.cue
cue import -p schema -f -o mxc/schema/kustomize.cue jsonschema: https://raw.githubusercontent.com/SchemaStore/schemastore/master/src/schemas/json/kustomization.json
```

### 2. Acquiring Kubernetes Custom Resource Schemas (CRDs)
For custom platform integrations (e.g., NetBird, Traefik, Velero), follow this two-stage pipeline:

* **Stage 1: Fetch and build the JSON Schema**:
  Use the root `Justfile` schema recipes (e.g., `just schema fetch nbsetupkeys` to fetch a single entry, or `just schema fetch` to fetch all catalog entries) to download the upstream CRD YAMLs and generate flat JSON Schemas + defaults under their target output directories.

* **Stage 2: Compile as Named CUE Definitions**:
  Convert the generated JSON Schema into a named, structured CUE definition (e.g., `#NBRoutingPeer`) inside `/mxc/schema/`. Use path-labeling (`-l`) and strip redundant package headers to allow clean multi-definition wrapping:
  ```bash
  # Example: Compile NetBird Routing Peer CRD schema into mxc/schema/netbird.cue
  cue import -p schema -f -o - -l '"#NBRoutingPeer"' jsonschema: mxc-library/stacks/networking/netbird/schema/nbroutingpeer.schema.json \
    | sed 's/"#NBRoutingPeer":/#NBRoutingPeer:/' \
    | grep -v "^package schema" >> mxc/schema/netbird.cue
  ```

### ⚠️ Critical CUE Syntax Rules for Schemas
* **Consolidated Top-Level Imports**: All `import` statements (e.g., `import "strings"`) **MUST** be placed strictly at the very top of the file, right after the `package schema` header. CUE does not permit inline or mid-file imports.
* **Keep Schemas Tool-Agnostic**: Keep schema files completely free of environment-specific cluster values or overrides. Only define types and default parameters.

---

## 📖 Reference Architecture & Inspiration (Cuestomize / KRM)

For future reference and pipeline iterations, we maintain alignment with modern CUE + Kubernetes integration patterns, particularly KRM (Kubernetes Resource Model) generators:

*   **Workday Cuestomize Book**: [https://workday.github.io/cuestomize/00_cuestomize.html](https://workday.github.io/cuestomize/00_cuestomize.html)
*   **Workday Cuestomize Source**: [https://github.com/workday/cuestomize](https://github.com/workday/cuestomize)

### 💡 Core Architectural Concepts
- **KRM Functionality**: Cuestomize acts as a Kustomize KRM transformer. It ingests resources from the Kustomize stream as standard input, mutates/generates resources using a CUE model, and outputs them back to Kustomize.
- **When to leverage**: While our central **Kluctl** engine is far superior for deployment lifecycle, Helm chart pulling, and SOPS decryption, Cuestomize's pipeline model represents the gold standard for **post-rendering validation policy checks** (running custom `cue vet` pipelines on completely rendered YAML outputs) in future CI/CD tasks.

---

## ✅ App-Spec Review Checklist

Run through this before finishing any edit that touches an `mxc-library/stacks/**/*.cue` file or a `cluster-home-mxc/apps-*.cue` override:

1. **`// Schema:` header comment** points at the correct `apps.cue` schema anchor (top of file).
2. **Upstream source comment**: if the app wraps a specific upstream Helm chart, note the chart name/repo/version near the top or on `helmChart`.
3. **`deployment` is set** (required, no default) and matches how `context` is actually shaped for that app.
4. **`expose.<port>`** carries an explicit `fqdn` set at the override site (never in the stack file), and `target: "none"` is set in the stack file if `context.ingress` is hand-rolled — with the hand-rolled hostname deriving from `S.expose.<port>.fqdn` rather than a second literal (Principle 11).
5. **Secrets placement follows the existing rule**: inline env override for single-use values, `#AppCore.secrets` field for values referenced more than once or overridden per-instance.
6. **`flavor` resolves to a named preset key**, not a typo — stack `_flavor` maps have no `[_]: {}` catch-all, so an unrecognized flavor string fails `cue vet` instead of silently resolving to `{}`.
7. **Import aliases follow Principle 13** — no alias equals the enclosing `cluster.apps.<category>` field label.
8. **`cue vet ./... -c`** (from the target cluster directory) is clean — the `-c` flag surfaces incomplete/concrete-check errors that plain `cue vet ./...` hides.

---

## 🛠️ Verification Checklist (Before Ending Your Turn)

1. **Verify Compilation:** Ensure `just mxc::validate` and `just mxc::export` run in milliseconds with zero warnings and exit with **code 0**.
2. **Review Output:** Run `just mxc::export` and visually inspect that all default container ports are resolved, FQDNs are properly computed, and storage classes are correctly assigned.
3. **Never Manual Edit vars.yml:** If you need to change a port, volume, or IP, update it in the **CUE input source files** (`cluster-home-mxc/vars-env.cue` or schemas), then run `just mxc::export` to regenerate the output. Do not edit `cluster-home-mxc/vars.yml` directly.
