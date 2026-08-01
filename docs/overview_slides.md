---
marp: true
theme: gaia
_class: lead
paginate: true
backgroundColor: #121214
color: #e4e6eb
---

# Model-X Configuration (MXC)
## Declarative, Type-Safe Platform Orchestration

---

## 💡 The Core Problem

> "Application configuration will never be unified. Deployment configuration must be."

* **The Kubernetes YAML Mess**: High-level intent is buried under thousands of lines of boilerplate.
* **Typo-Prone Helm & Jinja**: Errors are caught only at deploy-time or runtime.
* **The Coupling Hazard**: Standard setups are tightly coupled to huge shared libraries, preventing simple or offline runs.

---

## 🚀 The Solution: Model-X Configuration (MXC)

MXC decouples developer **logical intent** from physical **runtime deployment templates** using a two-pass CUE compile pattern:

1. **Logical Intent (CUE Schemas)**: Developers define apps, tags, routing, and sizing with type-safety and auto-completions.
2. **Dynamic Projection (Adapters)**: MXC compiles and projects this intent into flat parameters loaded by standard deploy engines (Kluctl, Kustomize, Docker Compose).

---

## 🛠️ The Architecture Layout

```text
mxc/
├── schema/             # Compiler Rules (#AppCore, #ClusterConfig)
│   ├── apps.cue        # Workload types, probes, and Reloader specs
│   └── kluctl.cue      # Kluctl deploy contract definitions
├── adapters/           # Decoupled Standalone Adapters
│   ├── app_template/   # bjw-s app-template mapper
│   ├── kluctl/         # Kluctl layout, PVCs, rollout-restarts
│   └── kustomize-only/ # Raw manifest injection
└── examples/           # Standalone cluster references
```

---

## 📦 Standalone vs. Library Modes

### Standalone Mode (`mxc` only)
* Standard configurations compile and render completely independently.
* Ideal for simple clusters, air-gapped runtimes, or quick tests.
* Zero external repo downloads or submodules.

### Library Mode (`mxc` + `mxc-library`)
* Standardizes multi-cluster setups by wrapping production service stacks (e.g. Monitoring, CI/CD, Storage planes).
* Uses CUE **package-level aliases** to keep active code completely DRY.

---

## ⚡ Active Features

* **AD-014 Reloader Lifecycles**: Standard Pod/Deployment annotation injection driven directly by schema-validated parameters.
* **First-Class Restarts**: Automatic Kubernetes ServiceAccount, Role, RoleBinding, and CronJob generation for scheduled restarts.
* **Type-Safe Autocompletions**: Automated JSON Schema exports (`schema-export`) enabling IDE linting on YAML variables.

---

## 🛡️ The "Báze" (Bases) & Stacks Layout

To achieve clean separation of concerns and directory symmetry, we partition our platform library:

* **`bases/` (Czech "báze")**: Represents the core cluster platform/foundation layers. Houses bootstrap concerns (namespaces, `kube-system` policies, load-balancers like `metallb`).
* **`stacks/`**: Dedicated, reusable workload planes and production service compositions (e.g., Traefik routes, Authelia SSO, monitoring stacks).
* **6-Letter Symmetry**: Semantically balanced directory lengths (`bases/` and `stacks/`) separating system-level foundations from workload configurations.

---

## ⚡ Global Kustomize Namespace Injection & CUE Overlays

We eliminate dynamic variable bloat in our templates and CUE schemas by following Kustomize best practices:

* **Global Decoupling**: Omit custom `namespace` variable overlays. Instead, rely on Kustomize's native pipeline wrapper (`kustomize.namespace`) to patch/inject target namespaces globally at the last second.
* **CUE-Defined Kustomize Overlays (`kustomize.overlays`)**: Specify raw Kubernetes resources as native, type-safe CUE structures under `kustomize.overlays` list, rendering dynamically as valid YAML without legacy Jinja.
* **The Enabled State Pattern**: Use simple `{ enabled: true }` configuration structures in CUE to represent active states. This provides a truthy value in Jinja/Python environments without introducing redundant fields.

---

## 🔮 Future-Proof OCI Packaging

* **No Symlinks, No Traversals**: Avoids OS relative path constraints (`../`) to support independent OCI publication.
* **Dynamic Import Resolution**: Adapters inherit schemas cleanly via OCI-ready CUE module registries (`github.com/epcim/mxc/...`).
