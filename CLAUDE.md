# Local Agent Skill (Claude): MXC Platform Architecture & Decoupled Workflows

* **Name:** `mxc-platform-claude`
* **Role:** Developer & Operator
* **Description:** Instruction manual and best-practice workflows specifically optimized for Claude AI agents tasked with maintaining, extending, or refactoring the Model-X Configuration (MXC) framework.

---

## 🚀 Welcome, Claude Agent!

This repository uses **MXC (Model-X Configuration)** as a type-safe, lightweight, and offline parameters compiler sitting upstream of **Kluctl**.

As a Claude agent, you excel in robust conceptual decomposition, schema mapping, and translating logical configurations to physical representations. Enforce consistent patterns and dry-run safety across the codebase.

---

## 📁 Layout Boundaries

All MXC configurations are self-contained inside the workspace directory:

```text
mxc (as repo)
+-- cue.mod/                   # CUE module metadata (github.com/epcim/mxc)
+-- schema/                    # Central, tool-agnostic validation rules
│   +-- apps.cue               # Workload intent schema (#AppCore)
│   +-- cluster.cue            # Infrastructure boundaries (#ClusterConfig)
│   +-- adapter.cue            # Decoupled output adapter interface (#Adapter)
│
+-- adapters/                  # Platform Output Adapters (AD-003)
│   +-- helm/app-template/     # bjw-s-labs app-template logical projection (README.md has upstream/version details)
│   +-- kluctl/                # Generic Kluctl render manifests & overlays
│   +-- kustomize/             # Direct Kustomize manifest injections
│
+-- mxc.just                   # Self-contained task-runner module
```

---

## ⚡ Key Commands

Never run raw shell hacks. Always use the nested, parameterizable `just` task namespace:

```bash
# 1. Validate all schemas & values against type constraints
just mxc::validate

# 2. Compile and output flat parameters (vars.yml) to stdout for a specific cluster
just mxc::export cluster-home-mxc

# 3. Generate Editor Autocompletion Schemas
just mxc::schema-export
```

---

## 🎨 Design Principles for Claude Authors

### 1. Separate Workload Intent from Cluster Reality
* **Workload Spec (`apps.cue`):** Focuses strictly on abstract developer requests (`expose: target: "ingress"`, storage sizes). Never leak internal container ports or specific domain suffixes here.
* **Infrastructure Spec (`cluster.cue`):** Maps logical intents to physical cluster capabilities (injecting `storageClass: "longhorn"`, base domains `example.com`, and VIP configurations).

### 2. Standardizing API Endpoints (The API vs Port Isolation Rule)
Never hardcode protocol-specific transport ports (such as SSH running on port 2222) inside standard REST API endpoints (like `RENOVATE_ENDPOINT`).
* **Rule**: Standard web/API integrations must target HTTP/HTTPS (ports 80/443) served by ingress reverse-proxies (like Nginx), letting the router translate raw SSH Git transport traffic independently.

### 3. Structural Pre-Unification
When checking for optional fields, remember that evaluating a non-existent optional field can block compiler execution. Safely pre-unify blocks with an empty default to allow clean list operations and loop conditions:
```cue
let portsVal = (appSpec & { ports: {} }).ports
let portsList = [for k, v in portsVal { k }]
let hasPorts = len(portsList) > 0
```

### 4. Direct, Decoupled Adapter Projections
Respect the Adapter Pattern (AD-003). Do not mix compiler logical schema evaluation with adapter-specific deployment structures. Keep adapters modular, cleanly decoupled, and readable.

### 5. CUE-Defined Kustomize Overlays (`kustomize.overlays`)
For application instances that require custom Kubernetes resources (such as `IngressRoute`, `Middleware`, or additional config maps) without creating complex subdirectory stacks, use the `kustomize.overlays` list parameter.

* **Type-Safe Serialization**: Specify raw Kubernetes API objects as native CUE values in the `kustomize.overlays` list. The compiler projects these directly into `overlays/mxc-overlays.yaml`, serialized as multi-document YAML via Jinja, and includes them automatically in the Kustomize resource list.
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

### 7. Derive, Don't Duplicate
When one logical value (an FQDN, a URL built from it) is needed in more than one place, define it once and reference it — never repeat the literal, since the copies will drift apart. Reference a same-level sibling field directly by name (`externalURL: "https://\(expose.ingress.hosts.core)"` in `harbor.cue`), reach a value nested at a different level via the stack's `S=schema.#AppCore & {...}` self-alias (`host: S.expose.http.fqdn` in `authelia.cue`), or bind a value computed once at a `cluster-home-mxc` override site with `let` and reuse the binding. Full detail and more examples: `mxc/AGENTS.md` §"Best Practices" #8.

---

## 🛠️ Verification Checklist (Before Ending Your Turn)

1. **Verify Compilation:** Ensure `just mxc::validate` and `just mxc::export` run in milliseconds with zero warnings and exit with **code 0**.
2. **Review Output:** Run `just mxc::export` and visually inspect that all default container ports are resolved, FQDNs are properly computed, and storage classes are correctly assigned.
3. **Never Manual Edit vars.yml:** If you need to change a port, volume, or IP, update it in the **CUE input source files** (`cluster-home-mxc/vars-env.cue` or schemas), then run `just mxc::export` to regenerate the output. Do not edit `cluster-home-mxc/vars.yml` directly.
