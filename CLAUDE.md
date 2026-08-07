# MXC Configuration Architecture

This document defines the platform design and integration workflows for **Model-X Configuration (MXC)**, specifically details the **Hybrid Schema Approach** for supporting advanced declarative platform engines like **Mirantis K0rdent (cAPI)** and native upstream **Kustomize** schemas.

---

## Requirements

- Always talk in ASD-STE100 simplified technical English. This applies to assistant messages and tool calls (file writes, code, mcp calls, etc.)

---

## 🚀 Welcome, Agent! (Operational Guide)

This repository uses **MXC (Model-X Configuration)** as a type-safe, lightweight, and offline parameters compiler sitting upstream of **Kluctl**. 

Before editing any configuration file or writing any CUE schemas, you **MUST** read and understand these operational rules and layouts.

### 📁 Layout Boundaries
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
│   +-- helm/app-template/     # bjw-s app-template logical projection (see its README.md for upstream chart/version)
│   +-- kluctl/                # Generic Kluctl render manifests & overlays
│   +-- kustomize/             # Direct Kustomize manifest injections
│
+-- mxc.just                   # Self-contained task-runner module
```

### ⚡ Key Commands
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

## 🎨 Core Vision: The Hybrid Schema Model

The core philosophy of MXC is to decouple **Developer Intent** (logical app specification) from **Platform Provider Realities** (physical cluster representations like Kluctl, Helm, or K0rdent).

To support highly complex configurations without over-abstracting or losing feature-fidelity, MXC uses a **Hybrid Schema Architecture**:

1. **Intent-Based by Default**: Standard properties (images, ports, storage, exposures) are modeled as abstract, validated CUE fields.
2. **Upstream Direct Schemas**: Platform-specific substructures are integrated by embedding raw, versioned upstream schemas directly inside CUE (e.g., `#Kustomization` matching Kustomize specs).
3. **Escape-Hatch Objects**: Unstructured or emerging Custom Resource specs (like K0rdent `MultiClusterService`) are mapped as optional pass-through nodes (`k0rdent`), allowing direct, zero-loss configuration matching the provider API.

---

## 🛠️ Schema Implementations

### 1. Upstream Kustomize Schema Integration (`schema.#Kustomization`)
Instead of maintaining a custom, brittle mapping for Kustomize fields, the MXC schema includes `#Kustomization` in `mxc/schema/kustomize.cue`. This maps precisely to upstream Kubernetes structures, allowing operators to leverage **JSON Patches** and standard resource inclusion natively inside CUE.

```cue
#Kustomization: {
	apiVersion?: string
	kind?:       "Kustomization" | string
	namespace?:  string
	resources?: [...string]
	patches?: [...#Patch]
	images?: [...#Image]
	labels?: [...#Label]
}
```

### 2. Mirantis K0rdent cAPI Integration (`k0rdent`)
The `#AppCore` schema has been extended with an optional `k0rdent` config block. This allows declarative multi-cluster service targeting, template selection, and direct postgres/mysql/redis backing bindings to pass natively through the parameters compiler.

```cue
k0rdent?: {
	serviceSpec?: {
		[string]: _
	}
	template?: string
	values?: {
		[string]: _
	}
}
```

### 3. Network Configuration Schema (`vars_net.cue` ➔ `vars-net.schema.json`)
The network topology, CIDRs, VLANs, and VIP (Virtual IP) pools are strictly governed by the `#NetworkConfig` schema defined in [`mxc/schema/vars_net.cue`](schema/vars_net.cue). This layout aligns directly with NetBox IPAM export formats, allowing clean synchronization with automated infrastructure registers.
*   **Key Fields**: `dns`, `vips`, `vlans`, `lb_pools`, `site`, `location`.
*   **Editor Autocomplete**: Auto-generated into `mxc/schema/vars-net.schema.json` via our schema-exporter to provide instant YAML diagnostics and validations.

### 4. Kubernetes Cluster platform Schema (`vars_k8s.cue` ➔ `vars-k8s.schema.json`)
The Kubernetes distribution type, global container environments, storage classes, and ingress base-annotations are modeled by the `#KubeConfig` schema in [`mxc/schema/vars_k8s.cue`](schema/vars_k8s.cue).
*   **Key Fields**: `type` (enum of talos, k3s, microk8s, etc.), `namespaces`, `storage` (default/local/performance class), `ingress` (class, global annotations).
*   **Editor Autocomplete**: Auto-generated into `mxc/schema/vars-k8s.schema.json` to enable automated linting for platform changes in `vars-k8s.yml`.

### 5. Workload Classification & The "Everything is a Template" Principle
In MXC, we treat **every deployment as wrapped in an adapter template (scaffolding)**. 

Rather than duplicating common platform-level concerns (like labels, annotations, tags, or namespace bindings) inside each individual application's private, complex Helm values, we enforce them **natively and uniformly** across all applications using Kustomize post-rendering patches.

To categorize how each application's template is processed by our compiler, the `#AppCore` schema defines an explicit, **required** **`deployment`** parameter — there is no implicit default. An app that omits it fails `cue vet`; this is deliberate, because the adapter has no safe universal default. `deployment` is a pure **rendering-adapter selector** — "which engine consumes this app's `context`" — and nothing else; it carries no information about chart shape (see AD-020).

*   **`"kluctl"`**: The primary, most common adapter. Covers three genuinely different chart shapes, disambiguated by `contextSchema`/`helmChart`, never by `deployment` itself: a native upstream Helm chart (e.g. MetalLB, Traefik, Longhorn, Woodpecker, Harbor) via an explicit `helmChart` block; the generic bjw-s app-template chart via `contextSchema: "#app-template"` (no explicit `helmChart` — the adapter synthesizes chart coordinates itself); or a chart-less, raw-manifest app (e.g. `metallb`'s upstream YAML) with neither set, using only `kustomize`/`secrets`.
*   **`"kustomize"`**: Deploys raw, standalone Kustomize manifests (schema-only today, no adapter implementation yet).
*   **`"k0rdent"`**: Deploys as a Mirantis K0rdent service catalog managed custom resource.
*   **`"argocd"`**: Schema-only today, no adapter implementation yet.

**`context` is polymorphic on `contextSchema`, not on `deployment`**: it is not one fixed shape. For the generic bjw-s chart, `context` conforms to `contextSchema: "#app-template"`'s values shape. For a native chart under `"kluctl"`, `context` is that specific upstream chart's own values schema (Traefik's `context` looks nothing like Longhorn's or Harbor's — each is validated against its own chart, referenced via its own `contextSchema` URL once vendored). For a chart-less raw-manifest app, there is no chart values schema at all — `context` is just a free-form parameter list read by an app-specific overlay, similar in spirit to how `secrets` is a free-form `[string]: string` map. This is why native-helm-chart stacks each set their own chart-native ingress/annotation fields directly inside `context` instead of going through the generic `expose.<port>` shape — there is no shared schema across them to centralize against.

`context`'s actual shape is validated per-application, not by `#AppCore` itself — `#AppCore.context` stays a generic `[string]: _` bag on purpose. The real shape contract lives with whichever schema/stack defines that app (an `mxc-library` stack, an app spec living directly in this repo, or a future OCI-packaged stack) and is referenced via `contextSchema` (`#`-prefixed for mxc's own bundled schemas like `"#app-template"`, URL-prefixed for upstream charts not yet vendored) — see AD-020 and the chart-schema vendoring plan in AGENTS-TODO.md.

#### 💡 Dynamic Compiler Detection:
Instead of maintaining a brittle, hardcoded list of application names in our compiler, `mxc/adapters/kluctl/projection.cue` dynamically detects the generic bjw-s app-template case by reading `contextSchema` directly (normalizing its `string | [...string]` disjunction via a list-comprehension `if`-guard, not `deployment`):
```cue
let isAppTemplate = len([for s in contextSchemaList if s == "#app-template" {s}]) > 0
```

### 6. The "Subscriber & Validator" Architectural Pattern
To avoid bloating our local CUE schemas with gigantic cloud-provider specifications (e.g., AWS VPC settings, OpenStack compute flavors, Cluster API resources), we follow the **"Subscriber & Validator"** pattern:

1.  **Logical Intent-First**: We only model high-level logical intent in our local CUE schemas (e.g., location name, region code, physical routing domains).
2.  **Native Projection**: Our output adapters project this intent into standard custom resource YAMLs (like `ClusterDeployment`, `Credential`, or `MultiClusterService`).
3.  **Upstream Schema Subscription**: Rather than redefining these fields, we validate our generated outputs directly against the official, unmodified JSON schemas published by the upstream providers (AWS, OpenStack, or Mirantis).

This guarantees zero schema maintenance, zero local bloat, and perfect, 100% compliance with upstream APIs out of the box!

### 7. Multi-Cluster, Multi-Cloud Topology Routing & Sizing Tiering
To support complex multi-cluster, multi-cloud enterprise footprints (e.g. AWS EKS, GCP GKE, and Bare-Metal locations peered across physical subnets/VPCs), MXC decouples **Regional Topology Overrides** from the underlying **Service Code**:

1.  **Sizing Tier Overrides (`flavor`)**: We define global sizing templates (e.g., `flavor: "dev1"`, `flavor: "prod"`) at the schema level (`schema/k8s.cue #FlavorSizingDefaults`). Individual environments inherit these sizing properties natively, overriding only what is necessary (such as setting replicas to `1` in dev environments, or adding temporary tolerations).
2.  **Infrastructure & IPAM Reference Linking**: Instead of hardcoding subnet allocations directly in the application configuration, clusters are configured with logical reference IDs (e.g., location, vlan, or site names). These references are automatically matched against pre-fetched or externally managed network data (such as NetBox caches), allowing the platform to resolve the physical VPC subnets, CIDRs, and routing VIPs dynamically at compilation time.
3.  **Cross-Cloud Virtual Peerings**: By separating the networking layout from the platform layer, MXC allows us to peer clusters across different cloud providers (e.g., connecting an AWS EKS subnet directly to a GCP VPC peering gateway) purely through high-level logical projections, keeping individual cluster parameters thin, readable, and incredibly simple.

### 8. Scoped Sizing Flavors & Self-Contained Merges (S.flavor)
To support multi-tier sizing defaults (e.g. `"nano"`, `"small"`, `"medium"`, `"large"`) without inflating the central parameters compiler with complex, per-app conditional mapping loops, MXC uses a CUE-native, self-contained struct-alias pattern inside each stack definition:

1. **Scoped local `_flavor` presets**: Every application stack defines its own private, isolated `_flavor` map. This maps logical tiers directly into the application's unique, native helm-values (`context`) layout, preventing package-level variable collisions.
2. **Dynamic Self-Unification (`S=schema.#AppCore & { ... _flavor[S.flavor] }`)**: Using CUE's struct-alias pattern `S`, the struct unifies itself dynamically against the resolved `_flavor` block at evaluation time based on the active `#AppCore.flavor` selector.

```cue
#KluctlController: S=schema.#AppCore & {
	_flavor: {
		small:  { context: controller_resources: limits: { cpu: "1", memory: "512Mi" } }
		medium: { context: controller_resources: limits: { cpu: "2", memory: "1Gi" } }
	}
	flavor: string | *"medium"
	
	_flavor[S.flavor]
}
```

This guarantees 100% decoupling: the core parameters compiler remains clean, simple, and thin, while each application library package retains full autonomous authority over how sizing defaults translate to its native configuration structures!

### 9. State Projection, Deterministic Identities, and Embedded Marshaling
When extending MXC or CUE-backed infra domains, follow these default patterns:

1. **Default to direct projection**: MXC should continue compiling straight to deployer-facing outputs unless a separate state document is required as a stable contract for downstream tools that do not evaluate CUE.
2. **Two-pass pipelines require a stated contract**: Introduce an intermediate state file only when multiple consumers need the same normalized projection. Document its purpose and downstream readers.
3. **Deterministic identities beat manual bookkeeping**: For infra domains like `infra/proxmox/`, derive stable MAC addresses or similar host identifiers from canonical names with CUE functions instead of hardcoding per-node values.
4. **Closed inner schemas, open outer seams**: Use `close()` for deeply validated config blocks such as version maps, node parameters, and app internals; keep the top-level composition surface open only where plugin-style extension is intended.
5. **Marshal embedded YAML/JSON from CUE values**: If a resource needs embedded YAML or JSON as a string payload, define that payload as native CUE data and render it with `yaml.Marshal` or `json.Marshal` so syntax stays compiler-validated.
6. **Native CUE File Embedding (`@embed`)**: To load external configuration files (such as `.yml` or `.json` parameters) natively into CUE structs without manual text template wrapping or indentation alignment, declare a private field `@embed` and unmarshal it with `yaml.Unmarshal`:
   ```cue
   import "encoding/yaml"
   _config: string @embed(file="path/to/config.yml")
   context: yaml.Unmarshal(_config)
   ```

### 10. Adapter Naming and Alpha Deployment Semantics
Use adapter directories to express the deployment target, and use filenames or definitions to express the input contract.

1. Prefer target-oriented adapter namespaces such as `mxc/adapters/argocd/` and `mxc/adapters/argoworkflow/`.
2. Inside those directories, use source-explicit names like `from-cluster.cue`, `from-stack.cue`, or `from-topology.cue` instead of encoding both source and target in the directory name.
3. Keep orchestration semantics such as `dependsOn`, stack grouping, instance binding, and topology in an alpha deployment schema surface like `mxc/schema/alpha/deploy.cue`, not in `mxc/schema/apps.cue`.
4. Use explicit alpha-stage schema names such as `#DeployAlpha` and `#TopologyAlpha`. Their final shape may later align more closely with Cluster API, K0rdent, or another controller-facing contract.
5. Use global `mxc::oci-*` commands as stable wrappers that dispatch to artifact-specific publish/package tasks.
6. **Independence of Core Adapters (`mxc-library` vs `mxc` standalone)**: The core CUE compilation model and base adapters (`kluctl`, `helm/app-template`, and `kustomize`) must be fully self-contained inside the `mxc/` module/directory.
   - Simple, standalone cluster configurations (e.g., `mxc` + `cluster-home-mxc`) must be able to compile, validate, and render successfully **completely without** the `mxc-library` repository.
   - Base adapters inside `mxc/adapters/` (such as `mxc/adapters/kluctl/`, `mxc/adapters/helm/app-template/`, and `mxc/adapters/kustomize/`) handle the core generic projections (PVC overlays, rollout restart cronjobs, base network policies).
   - Only advanced production-grade, application-specific, or multi-tenant deployments that depend on the `mxc-library` stack features expect to use or reference `mxc-library/adapters`.
   - **Self-Contained OCI Portability**: To support publishing and fetching `mxc` and `mxc-library` as separate, independent OCI artifacts in the future, **do NOT use filesystem symbolic links or relative parent path traversals (`../`)** for static template files (such as `.yml` / `.yaml` descriptors). Each package must maintain physical copies of its local static assets, while resolving all active compiler schemas and logical transformations cleanly through standard, OCI-compatible CUE module namespace imports (`github.com/epcim/mxc/...`).

---


## 📝 Real-World Examples

The following examples have been implemented inside `/cluster-home-mxc/vars-env.cue` and compiled into the flat `vars.yml` for Kluctl.

### Example A: `hajimari` (Kustomize JSON Schema Patching)
Demostrates how a developer defines a logical application, and uses our Kustomize schema to apply an inline JSON `replace` patch forcing a read-only root filesystem:

```cue
hajimari: {
	appName: "hajimari"
	image: {
		repository: "hajimari/hajimari"
		tag:        "latest"
	}
	ports: http: port: 80
	expose: http: target: "ingress"
	kustomize: {
		namespace: "home"
		labels: [{ pairs: app: "hajimari" }]
		
		// Upstream JSON Patching Schema in action!
		patches: [{
			target: {
				kind: "Deployment"
				name: "hajimari"
			}
			patch: """
				- op: replace
				  path: /spec/template/spec/containers/0/securityContext/readOnlyRootFilesystem
				  value: true
				"""
		}]
	}
}
```

### Example B: `n8n` (Mirantis K0rdent MultiClusterService Integration)
Demonstrates deploying `n8n` utilizing an abstract application declaration coupled with K0rdent template parameters and multi-cluster routing specs:

```cue
n8n: {
	appName: "n8n"
	image: {
		repository: "docker.n8n.io/n8nio/n8n"
		tag:        "latest"
	}
	ports: http: port: 5678
	expose: http: target: "ingress"
	
	// K0rdent Escape Hatch in action!
	k0rdent: {
		template: "n8n-standard"
		values: {
			database: {
				type: "postgres"
				host: "postgres-svc"
			}
		}
		serviceSpec: {
			serviceName: "n8n"
			deployment:  "multicluster"
		}
	}
}
```

---

## 📥 Schema Acquisition & Storage Workflows

To expand validation coverage for additional platforms, third-party manifests, or custom CRD controllers, use these commands to acquire and store CUE schemas inside `/mxc/schema/`:

### 1. Standard Specs (SchemaStore)
Use CUE's `jsonschema` engine to fetch and compile standard formats (e.g. Kustomize):
```bash
cue import -p schema -f -o mxc/schema/kustomize.cue jsonschema: https://raw.githubusercontent.com/SchemaStore/schemastore/master/src/schemas/json/kustomization.json
```

### 2. Platform CRDs (NetBird, Traefik, Velero)
To import schemas derived from Kubernetes CRDs:
1. Use the root `/schema/Justfile` task (e.g. `just schema-fetch-netbird`) to fetch the CRDs and generate raw JSON schemas under `/schema/`.
2. Run `cue import` with path-labeling to wrap them under a named CUE definition and strip the duplicate package headers:
   ```bash
    # Example: Import NetBird Routing Peer CRD schema into mxc/schema/netbird.cue
    cue import -p schema -f -o - -l '"#NBRoutingPeer"' jsonschema: schema/netbird.io/nbroutingpeer.schema.json \
      | sed 's/"#NBRoutingPeer":/#NBRoutingPeer:/' \
      | grep -v "^package schema" >> mxc/schema/netbird.cue
    ```

### 3. Native JSON Schema Exporting (`just mxc::schema-export`)
To make standard editors (VSCode, Neovim, etc.) recognize and validate compiled output files and variables natively without a CUE LSP, you can run CUE's OpenAPI/JSON Schema exporter:
```bash
just mxc::schema-export
```
This task automatically evaluates our custom schemas at the package level inside the `mxc/` context directory and dumps them directly as standard Draft-07/2020-12 JSON Schema definitions under `mxc/schema/`:
*   `vars_net.cue` ➔ [`mxc/schema/vars-net.schema.json`](schema/vars-net.schema.json)
*   `vars_k8s.cue` ➔ [`mxc/schema/vars-k8s.schema.json`](schema/vars-k8s.schema.json)
*   `#ClusterConfig` ➔ [`mxc/schema/mxc-cluster.schema.json`](schema/mxc-cluster.schema.json) (useful for full autocompletion on static variables or outputs)

### ⚠️ Syntactic Constraint
* **Package Import Placement**: Any generated CUE file containing internal imports (like `import "strings"`) **MUST** declare them strictly at the top of the file directly after the `package schema` header. CUE will fail compilation if imports are declared inline or mid-file.

---

## 🔌 The Adapter Pattern: `template/kluctl` vs. `adapter/kluctl`

Consistent with our architectural decisions (specifically **AD-003: Render Adapter Pattern**), we maintain a strict conceptual split:
*   **The Compiler Namespace (`mxc/`)**: Evaluates logical intent, verifies schemas, and flattens parameters.
*   **The Adapters**: Bridge logical output schemas into concrete deployer formats (like Helm, Kluctl, or Kustomize).

### File Path Naming Convention
Currently, these adapter definitions reside in `template/kluctl/` inside the repository. However, because their semantic function is purely to **adapt** logical declarations into physical deployable models, they are structurally **Adapters**, not generic templates.

*   **Current State**: Retained as `../mxc/template/kluctl` in Kluctl deployment configurations to avoid breaking historical references prematurely.
*   **Future Vision**: As the layout stabilizes, we plan to move these files to an explicit adapter structure (e.g., `templates/adapter/kluctl` or `mxc/adapter/kluctl`). This will explicitly denote their functional behavior as translator layers.

---

## 🔐 Secrets Resolution Strategy & Future-Proofing

To maintain absolute security and compiler decoupling:
*   **Zero Secret Leakage in CUE**: All CUE definitions and compiled metadata remain completely free of plain-text passwords or tokens.
*   **Decryption Isolation**: The parameter-compilation step (CUE) remains fully decoupled from decryption keys (SOPS), leaving secrets processing entirely to the deployer-level runtime.

### Current Implementation: Jinja Placeholders
For current Kluctl deployments, secret parameters are outputted from CUE as standard Jinja placeholders (e.g. `'{{ secrets.infra.notifications.pass }}'`). This is a perfectly acceptable, secure, and lightweight approach for our active layout:
1.  **Security**: Kept safe via SOPS-encrypted files (`vars-sec.yml`).
2.  **Runtime Handoff**: Kluctl decrypts the secrets locally and uses Jinja to replace placeholders natively at apply-time.

### Where to Place the Placeholder: `#AppCore.secrets` vs. Inline ENV
Two valid places exist for a Jinja secret placeholder — pick based on whether the value is a **single, direct key/value assignment** or needs to be **referenced more than once / overridden per-instance**:

*   **Inline directly on the ENV var, at `cluster-home-mxc` level** (e.g. `mxc-library` stack's `context...env.EMBY_SMTP_HOST` overridden in `cluster-home-mxc/apps-media.cue`): correct default when the secret is a simple single-assignment key/value pair, consumed exactly once, with no need to thread it through any other part of the same struct (kustomize generators, multiple env vars, etc). Most app-specific credentials (SMTP, API tokens) fit this case — don't introduce a schema field just to hold a value used in exactly one place.
*   **`#AppCore.secrets` schema field, declared in the `mxc-library` stack itself** (e.g. `netbird.cue`s `secrets.setup_key`, `silo.cue`s `secrets.secretKey`): reserved for when the value must be **referenced more than once inside the same struct** (netbird's `setup_key` also drives `kustomize.secretGenerator.literals`) or must be **overridable per-instance from `cluster-home-mxc`** (netbird's `home-gateway1`/`home-gateway2` each override `secrets.setup_key` with a different peer key). The field's CUE default is still the same Jinja placeholder convention — this is purely about giving cluster-home-mxc a single named override point, not a different resolution mechanism.

### 🛡️ Least-Privilege Secret Isolation & The Flat App Namespace

To resolve variable-shadowing conflicts inside the deployment runtime (Kluctl/Jinja) while maintaining secure, category-independent models:

1.  **The Shadowing Conflict**: When CUE-compiled targets are merged using the pattern `- values: {{ apps.<appName> | to_json }}`, the app's declared `secrets` map (under `#AppCore.secrets` schema) shadows the global, decrypted `secrets` dictionary. This causes any nested Jinja reference (like `{{ secrets.media.silo.secretKey }}`) to crash with an `UndefinedError`.
2.  **Least-Privilege Isolation**: Instead of passing the entire global `secrets` scope to all sub-deployments, we restrict the passed scope to **only** the nested parameters that the app actually references. Apps requiring no Jinja-templated secret parameters (like `cert-manager` or `authelia`) receive **no** secrets scope block.
3.  **The Flat Application Namespace Rule**: To keep application stacks inside `mxc-library` reusable, clean, and category-independent, app-specific secret contracts must be authored using flat app-level paths:
    ```cue
    // mxc-library/stacks/media/silo.cue
    secrets: {
        secretKey: string | *"{{ secrets.silo.secretKey }}"
    }
    ```
4.  **Target Mapping / Bridge**: In `deployment.yml`, we bridge the legacy categorized secret values (stored in `vars-sec.yml` under `secrets.media.silo`) straight into the flat namespace the app expects:
    ```yaml
    # cluster-home-mxc/deployment.yml
    - path: ../mxc-library/adapters/kluctl
      tags: [media, silo]
      vars:
        - values: {{ apps.silo | to_json }}
        - values:
            secrets:
              silo: {{ secrets.media.silo | to_json }}
    ```
    This elegant pattern ensures complete isolation, prevents shadowing conflicts, and keeps legacy files pristine!

### Future-Proofing: Migrating to Non-Jinja Secret Engines
If we migrate to a non-Jinja deployment engine (like Mirantis K0rdent or native Kubernetes operators), **these Jinja secret placeholders can be globally replaced by alternative secret-resolution methods with zero impact on the CUE compiler core**:

1.  **Kubernetes ExternalSecrets (Recommended)**:
    *   *Mechanism*: Replace placeholders with standard environment mappings pointing to an `ExternalSecret` or a standard K8s Secret resource.
    *   *Result*: Deploys K8s resources referencing static secrets generated out-of-band by a Vault/SOPS operator.
2.  **SealedSecrets / SOPS Operators**:
    *   *Mechanism*: Map parameters to inline Secret values encrypted beforehand using Bitnami SealedSecrets or decrypted inline via a cluster-side SOPS operator.
3.  **CUE Decryption Plugins (Sops-CUE)**:
    *   *Mechanism*: Integrate CUE's emerging custom tool functions or local scripts to decrypt `vars-sec.yml` files directly inside CUE, outputting final values securely to restricted target pipelines.

This design guarantees that our core parameters model remains independent of any single secret-management technology.

---

## 📖 Reference Architecture & Inspiration (Cuestomize / KRM)

For future roadmap expansion, pipeline enhancements, and CUE schema design patterns, we reference Workday's Cuestomize project:

*   **Documentation & Book**: [https://workday.github.io/cuestomize/00_cuestomize.html](https://workday.github.io/cuestomize/00_cuestomize.html)
*   **Source Code**: [https://github.com/workday/cuestomize](https://github.com/workday/cuestomize)

### 💡 Core Architectural Concepts
- **KRM Pipeline Integration**: Cuestomize acts as a Kustomize KRM transformer. It ingests intermediate generated YAML manifests, feeds them as input data into a CUE model, evaluates constraints, and outputs mutated YAML back into the pipeline.
- **When to Leverage**: While **Kluctl** is our primary deployment and orchestration engine (due to native Helm support and SOPS secrets handling), Cuestomize represents the industry gold standard for **post-rendering policy checking** (running automated `cue vet` audits on final YAML files before applying to live clusters).

---

## 🚀 Future Roadmap: Code Generation to cAPI CRDs

As the platform matures:
1. **Direct CRD Export**: A dedicated MXC CUE adapter (`adapters.k0rdent.output`) can be registered to project CUE specs directly into standard `MultiClusterService` Custom Resource YAMLs:
   ```bash
   cue export ./cluster-home-mxc/ -e 'adapters.k0rdent.output' --out yaml > mcs-manifest.yaml
   ```
2. **K0rdent API Application**: Instead of compiling for Kluctl, `just mxc::apply` will be able to apply generated CRD specs directly to the Mirantis K0rdent Catalog controller API.

---

## 🏗️ Multiple Ways to Execute MXC CLI Tasks

All task recipes inside the `mxc` namespace are designed to be dynamic and accept custom target paths (representing environments or clusters) as well as trailing argument lists. They can be invoked in three main ways:

### 1. Zero-Configuration Defaults
If no arguments or environment overrides are supplied, tasks default to the target directory configured in the global `TARGET_DEFAULT` variable (defaulting to `cluster-home-mxc`):
```bash
# Validates parameters, schemas, and templates for the default target
just mxc::test

# Evaluates CUE definitions for the default target
just mxc::vet
```

### 2. Environment Variable Overrides
To target a different environment directory dynamically across any task without passing positional parameters, define the `MXC_TARGET` environment variable in your terminal session or prefix it to the command:
```bash
# Temporarily points to cluster-test-mxc and runs verification checks
MXC_TARGET=cluster-test-mxc just mxc::test
```

### 3. Inline Positional Overrides (Highest Precedence)
You can directly pass the target directory name as the first argument to any recipe. You can also append standard Kluctl or CUE flags at the end of the command:
```bash
# Tests a specific cluster folder and filters by specific tag lists
just mxc::test cluster-home-mxc --include-tag woodpecker

# Preview a live kluctl dry-run diff on a test environment
just mxc::diff cluster-test-mxc --include-tag harbor
```

---

## 🎨 Best Practices & Architecture Discoveries

During implementation, several gold-standard patterns were established to guide all future agent development:

### 1. Standardizing Subdirectories by Kubernetes Kind
To keep the environment-specific directories (such as `cluster-home-mxc/`) clean and highly readable, helper schemas and auxiliary configurations must not clutter the root.
* **Practice**: Group auxiliary configurations under a subdirectory named strictly after their primary Kubernetes resource `Kind` in plural (e.g. `cluster-home-mxc/networkpolicies/`).
* **Wiring**: Wire these modules up in the root environment package using clean, declarative imports and explicit assignments (e.g., inside `cluster-home-mxc/policies.cue` with `cluster: networkPolicies: networkpolicies.networkPolicies`).

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
For application instances that require custom Kubernetes resources (such as `IngressRoute`, `Middleware`, or additional config maps) without creating complex subdirectory stacks or custom Helm values, developers can leverage the `kustomize.overlays` array.

* **Core Mechanism**: Developers specify raw Kubernetes API objects as native CUE values inside the `kustomize.overlays` list. The Kluctl adapter (`adapters/kluctl/projection.cue`) automatically maps these objects to `kustomize_overlays`.
* **Dynamic Serialization**: During compilation, these structured CUE objects are projected into a single `overlays/mxc-overlays.yaml` file, dynamically serialized into valid multi-document YAML via Jinja filters (`{{ obj | to_yaml }}`), and added to the Kustomize resource stream.
* **Benefits**:
  1. **Strong Typings**: Avoids typo errors in custom resource fields by validating them directly at compilation time.
  2. **Dry-Run Friendly**: Zero runtime text template interpolation or layout alignment issues.
  3. **Symmetry & Simplicity**: Retains the entire workload definition inside a single, clean `.cue` file.

Example:
```cue
hajimari: {
	appName: "hajimari"
	// ... standard fields ...
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

### 7. Import-Alias Naming Convention for `mxc-library/stacks/*` Packages
Every `cluster-*-mxc/apps-*.cue` file imports one or more `mxc-library/stacks/<name>` packages and binds each to a short alias. The established convention is `s` + a 3-4 letter abbreviation of the stack folder name — e.g. `sinf` (`stacks/infra`), `snet` (`stacks/networking`), `scic` (`stacks/cicd`), `smed` (`stacks/media`), `sgam` (`stacks/game`), `shmr` (`stacks/home/homarr`), `stg` (`stacks/storage`). `mon` (`stacks/monitoring`) is the one deliberate exception, chosen as a readable shortcut.

* **Hard rule — never alias to the bare category name:** Do not set the alias equal to the `cluster.apps.<category>` field name it will be used under (e.g. importing `stacks/cicd` as `cicd` inside a file that defines `cluster: apps: cicd: { ... }`). CUE resolves a bare identifier from the *nearest enclosing scope* — when the alias matches the enclosing struct field's own label, the reference inside that field's value resolves to the field itself (self-reference), not the file-level import. The import is then never actually consumed, and `cue vet` fails with `imported and not used`, even though the alias visibly appears in the file.
* **Why the `s`-prefix convention already avoids this**: none of `sinf`/`snet`/`scic`/`smed`/`sgam`/`shmr`/`stg` collides with any `cluster.apps.<category>` key (`infra`, `networking`, `cicd`, `media`, `game`, `home`, `storage`), so the collision only surfaces if the prefix is dropped in favor of the bare stack name.

### 8. Derive, Don't Duplicate
When a single logical value (an FQDN, a URL built from it, a hostname list) is needed in more than one place inside or across a struct, define it once and reference it everywhere else — never repeat the literal. A repeated literal is a latent bug: the two copies drift apart the moment one is edited and the other is forgotten.

* **Same-level sibling reference** — when both fields live in the same struct literal, reference the sibling field directly by name; no alias needed. `mxc-library/stacks/cicd/harbor.cue`:
  ```cue
  context: {
  	expose: ingress: hosts: core: string
  	// Derived from expose.ingress.hosts.core so callers only ever set one value
  	externalURL: "https://\(expose.ingress.hosts.core)"
  }
  ```
* **Cross-level reference via the `S=` self-alias** — when the second usage is nested deeper than the field it needs (e.g. a hand-rolled `context.ingress` needing the top-level `expose.http.fqdn`), use the stack's own `S=schema.#AppCore & {...}` alias instead of hardcoding a second literal. `mxc-library/stacks/infra/authelia.cue`:
  ```cue
  #Authelia: S=schema.#AppCore & {
  	context: ingress: main: hosts: [{host: S.expose.http.fqdn}]
  }
  ```
* **Local `let` binding at the override site** — when several fields at a single `cluster-home-mxc` override call site all need the same computed value, bind it once with `let` and reference the binding. `cluster-home-mxc/apps-cicd.cue`'s `woodpecker` override:
  ```cue
  context: server: {
  	let _fqdn = "woodpecker.int.\(cluster.network.domain)"
  	env: WOODPECKER_HOST: "https://\(_fqdn)"
  	ingress: {
  		hosts: [{host: _fqdn}]
  		tls: [{hosts: [_fqdn]}]
  	}
  }
  ```

### 9. Cross-App Context References as Composition
Stack definitions inside the same `mxc-library/stacks/<category>` directory share one CUE package (e.g. `package monitoring`), and CUE resolves identifiers at the package level, not per-file — a definition in one file can reference another definition's fields directly by name, with no import needed. Use this to eliminate cross-app duplication (a hostname, a service name) instead of copying the value into every app that needs it.

* **Example (monitoring stack)**: `#Grafana`'s datasource wiring references `#Mimir.kustomize.namespace` and `#Loki.appName` directly instead of each app separately hardcoding the others' namespace/service name. If `#Mimir`'s namespace ever changes, every consumer picks it up automatically.
* **Scope**: only within the same package (same category directory). Across categories/packages, use the normal override-site wiring (`cluster-home-mxc/apps-*.cue`) instead — don't add cross-package imports between stack files just to avoid one literal.

### 10. The Phased Deprecation & Backward-Compatibility Pattern
When refactoring schema-level fields or parameters in the core compiler schema (`mxc/schema/`), always maintain 100% backward-compatibility. Since external stack configurations (`mxc-library`) and target environments expect stable variables, schema updates must be executed using a **three-step phased deprecation pattern** rather than breaking immediate cuts:

1. **Step 1: Double-Representation & Auto-Derivation**: Keep legacy properties on the core interfaces (e.g., `#BaseAppAdapter`), but automatically compute/derive their values under-the-hood from the new source of truth. Mark the legacy properties clearly with a `// TODO: Deprecate...` comment.
2. **Step 2: Downstream Migration**: Update downstream repositories (`mxc-library` stacks) and user cluster configs to start consuming the new parameters/structures.
3. **Step 3: Cleanup**: Once all consumers have migrated, safely delete the legacy properties and their auto-derivation blocks from the core compiler schemas.

This ensures zero compilation or parameter-rendering disruption across target platforms during major refactoring efforts.

---

## 🌐 FQDN & `expose` Convention

`#AppCore.expose.<port>` is the generic, cross-app-category surface for ingress exposure. Two rules keep it unambiguous:

1. **Set `fqdn` explicitly at the `cluster-home-mxc` override site, not in the `mxc-library` stack file.** The stack file defines the app's shape (`ports`, `expose.<port>.target`); the concrete hostname is cluster-specific and belongs where `cluster.network.domain` is in scope, e.g.:
   ```cue
   hass: sinf.#HomeAssistant & {
   	expose: http: fqdn: "hass.svc.\(cluster.network.domain)"
   }
   ```
   Internal-only services use the `.svc.`/`.int.` zone-domain segments so the `apps-network.cue` comprehension (below) auto-routes them through the internal Traefik instance instead of the public one.
2. **When an app hand-rolls its own `context.ingress` block** (because it needs annotations/paths the generic `#Projection` can't express — e.g. `authelia`), set `expose.http.target: "none"` in the stack file. This tells `#Projection` not to also emit a second, duplicate `ingress.http`. Don't hardcode the hostname a second time inside the hand-rolled block — reference the same `#AppCore.expose.http.fqdn` value via the stack's `S=schema.#AppCore & {...}` self-alias, so there is exactly one source of truth for the hostname (see "Derive, Don't Duplicate" below). `mxc-library/stacks/infra/authelia.cue`:
   ```cue
   #Authelia: S=schema.#AppCore & {
   	...
   	context: ingress: main: hosts: [{
   		host: S.expose.http.fqdn
   		...
   	}]
   	tls: [{hosts: [S.expose.http.fqdn]}]
   }
   ```

### Zone-Based `ingressClass` Auto-Assignment
`cluster-home-mxc/apps-network.cue` runs a comprehension over *every* category in `cluster.apps` and *every* port in each app's `expose` map — not just `http` — and inspects each port's `fqdn` for the `.svc.`/`.int.` substrings. When found, it sets that port's `ingressClass: "zone-service-traefik"` automatically:
```cue
cluster: apps: {
	for _category, _apps in cluster.apps {
		"\(_category)": {
			for _appName, _app in _apps
			for _portName, _portVal in _app.expose
			let fqdnVal = [if _portVal.fqdn != _|_ { _portVal.fqdn }, ""][0]
			if strings.Contains(fqdnVal, ".svc.") || strings.Contains(fqdnVal, ".int.") {
				"\(_appName)": expose: "\(_portName)": ingressClass: "zone-service-traefik"
			}
		}
	}
}
```
Do not hand-set `ingressClass` on an app whose fqdn already carries `.svc.`/`.int.` — let the comprehension do it, to avoid the literal drifting out of sync across app files. `#AppCore.expose` is a required field that defaults to `{}`, so apps with no exposed ports at all (native-chart infra pieces like `metallb`/`velero`) simply contribute zero iterations here — no pre-unification guard needed. The condition only cares about the resolved `fqdn` value, not which category or port name it lives under, so the same comprehension covers `expose.http`, `expose.metrics`, or any other port key uniformly.

---

## ✅ App-Spec Review Checklist

Run through this before finishing any edit that touches an `mxc-library/stacks/**/*.cue` file or a `cluster-home-mxc/apps-*.cue` override:

1. **`// Schema:` header comment** points at the correct `apps.cue` schema anchor (top of file).
2. **Upstream source comment**: if the app wraps a specific upstream Helm chart, note the chart name/repo/version near the top or on `helmChart`.
3. **`deployment` is set** (now required, no default — see §5 above) and matches how `context` is actually shaped for that app.
4. **`expose.<port>`** is defined with an explicit `fqdn` at the override site (see convention above), and `target: "none"` is set in the stack file if `context.ingress` is hand-rolled.
5. **Secrets placement follows the existing rule** (inline env override vs. `#AppCore.secrets` field) — see "🔐 Secrets Resolution Strategy" above.
6. **`flavor` resolves to a named preset key**, not a typo — stack `_flavor` maps no longer have a `[_]: {}` catch-all, so an unrecognized flavor string now fails `cue vet` instead of silently resolving to `{}`. If you add a new flavor tier, add the named key to the stack's `_flavor` map, don't rely on a wildcard.
7. **`cue vet ./... -c`** (from the target cluster directory) is clean — the `-c` flag surfaces incomplete/concrete-check errors that plain `cue vet ./...` hides.

---

## 🛠️ Verification Checklist (Before Ending Your Turn)

1. **Verify Compilation:** Ensure `just mxc::validate` and `just mxc::export` run in milliseconds with zero warnings and exit with **code 0**.
2. **Review Output:** Run `just mxc::export` and visually inspect that all default container ports are resolved, FQDNs are properly computed, and storage classes are correctly assigned.
3. **Never Manual Edit vars.yml:** If you need to change a port, volume, or IP, update it in the **CUE input source files** (`cluster-home-mxc/vars-env.cue` or schemas), then run `just mxc::export` to regenerate the output. Do not edit `cluster-home-mxc/vars.yml` directly.
