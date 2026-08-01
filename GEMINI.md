# Local Agent Skill (Gemini): MXC Platform Architecture & CUE-Native Workflows

* **Name:** `mxc-platform-gemini`
* **Role:** Developer & Architect
* **Description:** Instruction manual and best-practice workflows specifically optimized for Gemini AI agents tasked with maintaining, extending, or refactoring the Model-X Configuration (MXC) framework.

---

## 🚀 Welcome, Gemini Agent!

This repository uses **MXC (Model-X Configuration)** as a type-safe, lightweight, and offline parameters compiler sitting upstream of **Kluctl**. 

As a Gemini agent, you possess an exceptional understanding of **CUE Lang**'s logical unification merges, constraints, and strict mathematical schemas. Use these strengths to enforce flawless type-safety across the repository.

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

# 2. Compile and output flat parameters (vars.yml) to stdout for a specific cluster
just mxc::export cluster-home-mxc

# 3. Generate Editor Autocompletion Schemas
just mxc::schema-export
```

---

## 🎨 Design Principles for Gemini Authors

### 1. Separate Workload Intent from Cluster Reality
* **Workload Spec (`apps.cue`):** Focuses strictly on abstract developer requests (`expose: target: "ingress"`, storage sizes). Never leak internal container ports or specific domain suffixes here.
* **Infrastructure Spec (`cluster.cue`):** Maps logical intents to physical cluster capabilities (injecting `storageClass: "longhorn"`, base domains `example.com`, and VIP configurations).

### 2. Standardizing API Endpoints (The API vs Port Isolation Rule)
Never hardcode protocol-specific transport ports (such as SSH running on port 2222) inside standard REST API endpoints (like `RENOVATE_ENDPOINT`).
* **Rule**: Standard web/API integrations must target HTTP/HTTPS (ports 80/443) served by ingress reverse-proxies (like Nginx), letting the router translate raw SSH Git transport traffic independently.

### 3. The Optional Field Evaluation Trap (Structural Pre-Unification)
In CUE, evaluating conditional assertions on an **absent optional field** inside an open struct results in an **incomplete condition** (`_` bottom / incomplete error). Collapse the open-ended index signature into a concrete instance before doing selection:
```cue
// Force unify ports with an empty map default
let portsVal = (appSpec & { ports: {} }).ports
let portsList = [for k, v in portsVal { k }]
let hasPorts = len(portsList) > 0 // Safely evaluates to true/false without halting!
```

### 4. Close Inner Schemas, Keep Outer Extension Surfaces Open
Use `close({...})` on deep, typo-sensitive configuration blocks so invalid keys fail immediately during validation. Keep only the outermost integration points open with `...` where additive composition is explicitly intended, such as plugin-style extension surfaces.

### 5. CUE-Defined Kustomize Overlays (`kustomize.overlays`)
For application instances that require custom Kubernetes resources (such as `IngressRoute`, `Middleware`, or additional config maps) without creating complex subdirectory stacks, use the `kustomize.overlays` list parameter.

* **Type-Safe Serialization**: Specify raw Kubernetes API objects as native CUE values in the `kustomize.overlays` list. The compiler projects these directly into `overlays/cue-overlays.yaml`, serialized as multi-document YAML via Jinja, and includes them automatically in the Kustomize resource list.
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

---

## 🛠️ Verification Checklist (Before Ending Your Turn)

1. **Verify Compilation:** Ensure `just mxc::validate` and `just mxc::export` run in milliseconds with zero warnings and exit with **code 0**.
2. **Review Output:** Run `just mxc::export` and visually inspect that all default container ports are resolved, FQDNs are properly computed, and storage classes are correctly assigned.
3. **Never Manual Edit vars.yml:** If you need to change a port, volume, or IP, update it in the **CUE input source files** (`cluster-home/vars-env.cue` or schemas), then run `just mxc::export` to regenerate the output. Do not edit `cluster-home/vars.yml` directly.
