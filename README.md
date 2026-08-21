# Model-X Configuration (MXC)

MXC is a declarative, type-safe, and compile-time-validated platform configuration engine. It separates abstract developer **logical intent** from physical **runtime deployment engines** (such as Kluctl, Kustomize, and Helm).

[![Docs & Interactive Playground](https://img.shields.io/badge/Docs-Interactive%20Playground-6366f1?style=for-the-badge)](https://epcim.github.io/mxc)

🚀 **Live Interactive Documentation**: Explore our [GitHub Pages Site](https://epcim.github.io/mxc) to view real-time compilation examples, interact with the CUE Lattice Theory validation playground, and read our technical specs.

This repository is designed to be **fully self-contained and standalone-ready**, allowing basic cluster setups to be compiled, validated, and rendered completely without any external library dependencies.

At its core, **MXC is just `cue export` of unified variable trees and configurations**. 

Adapters simply transform this exported data into native input formats for whatever deployment or provisioning tool you choose: **Kluctl, Kustomize, K0rdent, Terraform / OpenTofu, Helm, or ArgoCD**.

```text
                      ┌────────────────────────────────────────┐
                      │       just mxc::apply TARGET           │
                      └──────────────────┬─────────────────────┘
                                         │
                         CUE evaluates adapter for tag
                                         │
             ┌───────────────────────────┼───────────────────────────┬───────────────────────────┐
             ▼                           ▼                           ▼                           ▼
     ┌───────────────┐           ┌───────────────┐           ┌───────────────┐           ┌───────────────┐
     │    kluctl     │           │   kustomize   │           │    k0rdent    │           │   terraform   │
     └───────┬───────┘           └───────┬───────┘           └───────┬───────┘           └───────┬───────┘
             │                           │                           │                           │
      kluctl deploy ...        kustomize build /           kcm apply /                 tofu / terraform
                               kubectl apply -f            kubectl apply -f CR         apply ...
```

---

## 💡 Core Philosophy: Low Learning Curve, Upstream Fidelity & AI-Ready Architecture

MXC is designed around three foundational principles: **Zero Steep Learning Curve**, **Direct Upstream Fidelity**, and **AI-First Maintainability**.

1. **No Steep Learning Curve (Pure Declarative Data)**:
   - CUE is a strict superset of JSON and YAML. There are no proprietary programming paradigms, imperative macros, or hidden domain-specific languages (DSLs) to learn.
   - If you know how to write a Kubernetes manifest, Docker Compose file, or Helm `values.yaml`, you already know how to write MXC configurations.

2. **Direct Upstream Specification Fidelity**:
   - Rather than inventing artificial, leaky abstractions that get out of date, MXC embeds and directly leverages **native upstream specifications**:
     - Kubernetes objects and Kustomize JSON patches (`external.#Kustomization`).
     - Upstream Helm chart `values` schemas validated directly at compile-time.
     - Docker Compose parameters and AWS Terraform structures.
   - You retain 100% feature-fidelity with upstream tools without waiting for framework updates.

3. **AI-Driven Adapter & Skill Architecture (2026 Era)**:
   - In modern workflows, developers and platform engineers do not waste time hand-writing brittle boilerplate glue or complex manifest translations.
   - **Adapters and scaffolding are managed natively by AI agent skills and coding assistants** (e.g. Gemini, Claude, AGY CLI).
   - Human operators declare high-level intent (`image`, `ports`, `storage`, `expose`), while AI agents generate, validate, and adapt the underlying rendering pipelines across Kluctl, Helm, ArgoCD, or K0rdent seamlessly.

4. **Minimal Primitives & Composable Profiles**:
   - **Pristine Primitives (`#App`, `#Cluster`, `#Platform`, `#Adapter`)**: Completely neutral, unopinionated foundation with zero vendor lock-in.
   - **MXC Reference Profile (`schema/mxc/`)**: A "batteries-included" reference implementation providing pre-composed container facets (`#ImageSpec`, `#PortsSpec`, `#StorageSpec`) and platform defaults (`#PlatformMxc`, `#PlatformMxcLab`). Custom teams can adopt `schema/mxc/` out of the box or define their own corporate profile alongside it.

---

## 🏛️ Architecture & Core Components

```text
mxc/
├── module/             # Publishable github.com/epcim/mxc CUE module
│   ├── cue.mod/
│   ├── schema/         # Compiler rules (#App, #AppMxc, #Cluster, #Platform, #WithPlatform)
│   │   ├── platforms/  # Pure target execution platform schemas (k8s, compose, aws, k0rdent)
│   │   ├── mxc/        # Consolidated MXC reference profile & facets (#ImageSpec, #KubeSpec, #PlatformMxc)
│   │   ├── alpha/      # Alpha deployment schemas (#TopologyAlpha, #DeployAlpha)
│   │   └── external/   # Upstream & third-party schemas (Kustomize, NetBird)
│   └── adapters/       # Kluctl, Helm, Kustomize, ArgoCD and catalog adapters
├── docs/               # Platform documentation & slideshows
├── examples/           # Consumer examples, not included in OCI
└── test/               # Schema integration tests, not included in OCI
```

### 1. Standalone Mode vs. Library Mode

#### 🟢 Standalone Mode (`mxc` only)
Standard configurations compile, validate, and render using **only the files inside this directory**. This ensures the compiler can run offline, in air-gapped environments, or on simple clusters without downloading external library submodules.

#### 🔵 Library Mode (`mxc` + `mxc-library`)
For production-grade, multi-cluster organizations, the optional `mxc-library` repository standardizes core system planes (Monitoring, DBs, Auth, and Storage stacks). 
* To prevent maintenance hazards and keep the codebase DRY, library adapters use **CUE module-level pass-through aliases** that dynamically import and inherit schemas from `mxc` over standard OCI registry schemas (`github.com/epcim/mxc/...`).

---

## ✨ Core Features & Advanced Capabilities

### 🛡️ Upstream Chart Schema Vendoring & Typo Protection

To prevent parameter drift and catch syntax or configuration errors before any manifests are generated or deployed, MXC supports **Upstream Chart Schema Vendoring**:

* **Catalog-Driven Vendoring**: External Helm chart schemas are registered declaratively in our central `schema/catalog.cue` definition.
* **Automatic Compilation & Import**: The companion `mxc-library` owns the `cue cmd vendor-schema` workflow that downloads and compiles official `values.schema.json` schemas (or `values.yaml` fallback) into native CUE definitions (`values_schema.cue`) beside the owning stacks.
* **Compile-Time Typo Protection**: Unifying the imported `#ValuesSchema` definition with the application's `values` or `context` field instantly blocks the build if an invalid parameter is introduced.

#### 💡 Example: Typo Protection in Action

If you introduce a typo (such as setting `installCRD_typo: false` instead of `installCRDs: false`) inside `cert-manager.cue`:

```cue
context: #ValuesSchema & {
    installCRD_typo: false
}
```

Running `just mxc::validate` or `cue vet` instantly blocks compilation:

```text
#CertManager.context.installCRD_typo: field not allowed:
    ./cue.mod/pkg/github.com/epcim/mxc/schema/apps.cue:52:5
    ./stacks/infra/cert-manager/cert-manager.cue:27:3
```

This guarantees offline, type-safe validations against official upstream chart constraints in milliseconds!

---

## 🚀 Quick Start Guide

### Prerequisites
Ensure you have the following installed on your developer machine:
* [CUE Compiler](https://cuelang.org/) (v0.11.0+)
* [Just Task Runner](https://github.com/casey/just)
* [yq](https://github.com/mikefarah/yq) & [jq](https://github.com/jqlang/jq)

---

## 🛠️ Usage Instructions & 4-Stage Lifecycle

All commands use the unified `just` task namespace:

### 4-Stage Lifecycle Pipeline

MXC structures deployments into 4 explicit stages:

```
┌─────────────┐       ┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│ 1. export   │  ──▶  │ 2. build    │  ──▶  │ 3. diff     │  ──▶  │ 4. run      │
│ (vars.yml)  │       │ (manifests) │       │ (preview)   │       │ (execution) │
└─────────────┘       └─────────────┘       └─────────────┘       └─────────────┘
```

#### Stage 1: Export (`export`)
Compiles high-level CUE application models and merges them with cluster overrides into a flat parameters file (`vars.yml`) or prints the evaluated CUE data to stdout:
```bash
just mxc::export [TARGET] [-t TAG]
# Examples:
just mxc::export cluster-home-mxc
just mxc::export cluster-home-mxc -t silo
```

#### Stage 2: Build (`build`)
Renders all Kubernetes manifests, Helm charts, and Kustomize overlays offline into the local `.build/` cache:
```bash
just mxc::build [TARGET] [-t TAG]
# Examples:
just mxc::build cluster-home-mxc
just mxc::build -t silo
```

#### Stage 3: Diff (`diff`)
Compares offline rendered `.build/` manifests against the live Kubernetes cluster state:
```bash
just mxc::diff [TARGET] [-t TAG] [--dry-run]
# Examples:
just mxc::diff -t silo
just mxc::diff cluster-home-mxc --dry-run
```

#### Stage 4: Run (`run`) & Apply Alias (`apply`)
Executes the rendered manifests against the live target cluster:
```bash
just mxc::run [TARGET] [-t TAG]
# Legacy/alternative execution alias:
just mxc::apply [TARGET] [-t TAG]
# Dry-run execution:
just mxc::run -t silo --dry-run
```

---

### 🎯 Flexible Workload & Tag Targeting

All lifecycle commands (`build`, `diff`, `run`, `apply`, `show`) support flexible, auto-detected workload targeting syntax:

* `just mxc::diff cluster.apps.silo --dry-run` ➔ Auto-extracts tag `silo` from CUE path
* `just mxc::diff apps.silo --dry-run` ➔ Auto-extracts tag `silo`
* `just mxc::diff silo --dry-run` ➔ Auto-extracts tag `silo` from positional argument
* `just mxc::diff -t silo --dry-run` ➔ Uses explicit tag flag `-t`

```bash
# Examples across lifecycle stages:
just mxc::build silo                  # Builds only the silo workload
just mxc::diff cluster.apps.silo      # Diffs only the silo workload against cluster
just mxc::run apps.silo --dry-run     # Dry-run deployment for silo
```

---

### Manifest Inspection & Cluster Catalog

#### Inspect Rendered Manifests (`show`)
Inspects generated manifests in `.build/` with syntax highlighting (`bat` / `cat`):
```bash
just mxc::show [TARGET] [-t TAG]     # Present rendered manifests for target/tag
just mxc::show -l                    # List all rendered manifest files in .build/
```

#### Service Discovery & Catalog
```bash
just mxc::list [TARGET]              # List active services in the cluster
just mxc::list-services [TARGET]     # List service names and resolved DNS/FQDN endpoints
just mxc::show-catalog [TARGET]      # Export complete flat service catalog to stdout
```

#### Schema Validation & IDE Schemas
```bash
just mxc::validate                   # Run type-safety and Docker Compose validations
just mxc::schema-export              # Generate JSON Schema files for IDE autocompletion
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

When you execute `just mxc::export cluster-home-mxc`, the compiler automatically parses this schema, projects the bjw-s app-template details, injects standard probes/timezones, and dumps a completely formatted `vars.yml` that Kluctl renders instantly!

---

## 🔒 Future-Proof OCI Portability

To support publishing and pulling both `mxc` and `mxc-library` as separate, independent **OCI artifacts** in the future, we enforce **strict self-containment**:
* **No Symlinks**: Directory symbolic links are not used to avoid broken links during extracted OCI runs.
* **No Path Traversal**: Code and manifests never use relative parent traversal paths (`../some/path`).
* **Clean Module Boundaries**: All active logical schemas are shared and resolved cleanly via standard CUE import boundaries (`github.com/epcim/mxc/...`).

See [`docs/oci-publishing.md`](docs/oci-publishing.md) for the validated GHCR
dry-run, publication, and clean-consumer workflow.
