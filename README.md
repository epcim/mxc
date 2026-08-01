# Model-X Configuration (MXC)

MXC is a declarative, type-safe, and compile-time-validated platform configuration engine. It separates abstract developer **logical intent** from physical **runtime deployment engines** (such as Kluctl, Kustomize, and Helm).

[![Docs & Interactive Playground](https://img.shields.io/badge/Docs-Interactive%20Playground-6366f1?style=for-the-badge)](https://epcim.github.io/mxc)

🚀 **Live Interactive Documentation**: Explore our [GitHub Pages Site](https://epcim.github.io/mxc) to view real-time compilation examples, interact with the CUE Lattice Theory validation playground, and read our technical specs.

This repository is designed to be **fully self-contained and standalone-ready**, allowing basic cluster setups to be compiled, validated, and rendered completely without any external library dependencies.


---

## 🏛️ Architecture & Core Components

```text
mxc/
├── schema/             # Compiler Rules (#AppCore, #ClusterConfig)
│   ├── apps.cue        # Workload schemas, probes, Reloader configs
│   ├── kluctl.cue      # Standard Kluctl deployment schemas
│   ├── cluster.cue     # Platform FQDN and ingress configurations
│   ├── vars_net.cue    # NetBox-compatible network vip mappings
│   └── vars_k8s.cue    # Kubernetes storage/platform presets
├── adapters/           # Platform Adapters
│   ├── app_template/   # bjw-s app-template logical projection
│   ├── kluctl/         # Generic Kluctl render manifests & overlays (PVCs, restarts)
│   └── kustomize-only/ # Direct Kustomize manifest injections
├── docs/               # Platform documentation & slideshows
└── test/               # Schema integration tests & Docker compose mocks
```

### 1. Standalone Mode vs. Library Mode

#### 🟢 Standalone Mode (`mxc` only)
Standard configurations compile, validate, and render using **only the files inside this directory**. This ensures the compiler can run offline, in air-gapped environments, or on simple clusters without downloading external library submodules.

#### 🔵 Library Mode (`mxc` + `mxc-library`)
For production-grade, multi-cluster organizations, the optional `mxc-library` repository standardizes core system planes (Monitoring, DBs, Auth, and Storage stacks). 
* To prevent maintenance hazards and keep the codebase DRY, library adapters use **CUE module-level pass-through aliases** that dynamically import and inherit schemas from `mxc` over standard OCI registry schemas (`github.com/epcim/mxc/...`).

---

## 🚀 Quick Start Guide

### Prerequisites
Ensure you have the following installed on your developer machine:
* [CUE Compiler](https://cuelang.org/) (v0.11.0+)
* [Just Task Runner](https://github.com/casey/just)
* [yq](https://github.com/mikefarah/yq) & [jq](https://github.com/jqlang/jq)

---

## 🛠️ Usage Instructions

All commands are run using the platform-integrated `just` wrapper inside the `mxc/` context:

### 1. Validate the Configuration Schemas
Runs compiler-level type-safety, Docker Compose alignments, and structural parameter checks:
```bash
just mxc::validate
```

### 2. Export Compiled Variables (`vars.yml`)
Compiles your high-level CUE application models and merges them with legacy cluster overrides into a flat, Kluctl-consumable `vars.yml` block:
```bash
just mxc::export <cluster-directory-name>
# Example:
just mxc::export cluster-home-mxc
```

### 3. Generate Editor Autocompletion Schemas
Compiles and generates standard physical JSON Schema files used to validate local YAML/YML files via the IDE's YAML Language Server:
```bash
just mxc::schema-export
```

---

## 📁 Example Setup Walkthrough

The companion [**`cluster-bootstrap-mxc`**](examples/cluster-bootstrap-mxc/) folder represents a fully-formed environment driving deployment logic from CUE.

### How an application is defined:
Applications are authored declaratively inside your environment's `apps.cue` sheet:

```cue
package apps

apps: hajimari: {
    appName: "hajimari"
    image: {
        repository: "ghcr.io/tobiasboothe/hajimari"
        tag:        "v1.0.0"
    }
    ports: http: port: 80
    expose: http: target: "ingress"
    
    // Automated Stakater Reloader annotation injection (AD-014)
    reloader: {
        auto: true
    }

    // Embed type-safe, compile-time-validated custom resource overlays directly
    kustomize: {
        overlays: [
            {
                apiVersion: "traefik.io/v1alpha1"
                kind:       "Middleware"
                metadata: name: "hajimari-headers"
                spec: headers: {
                    browserXssFilter: true
                }
            }
        ]
    }
}
```

When you execute `just mxc::export cluster-home-mxc`, the compiler automatically parses this schema, projects the bjw-s app-template details, injects standard probes/timezones, attaches the requested Reloader annotations, and dumps a completely formatted `vars.yml` that Kluctl renders instantly!

---

## 🔒 Future-Proof OCI Portability

To support publishing and pulling both `mxc` and `mxc-library` as separate, independent **OCI artifacts** in the future, we enforce **strict self-containment**:
* **No Symlinks**: Directory symbolic links are not used to avoid broken links during extracted OCI runs.
* **No Path Traversal**: Code and manifests never use relative parent traversal paths (`../some/path`).
* **Clean Module Boundaries**: All active logical schemas are shared and resolved cleanly via standard CUE import boundaries (`github.com/epcim/mxc/...`).
