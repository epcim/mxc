# MXC Hybrid Schema & Rendering Architecture

This document defines the platform design and integration workflows for **Model-X Configuration (MXC)**, specifically details the **Hybrid Schema Approach** for supporting advanced declarative platform engines like **Mirantis K0rdent (cAPI)** and native upstream **Kustomize** schemas.

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

To categorize how each application's template is processed by our compiler, the `#AppCore` schema defines an explicit **`deployment`** parameter:

*   **`"bjw-s" | "app-template"`**: (Default if omitted) Deploys as a standard container using our generic bjw-s Kluctl adapter templates.
*   **`"kluctl"`**: Deploys as a native upstream Helm chart (e.g. MetalLB, Traefik, Longhorn, Woodpecker, Harbor) where the compiler passes custom `context` blocks directly to Helm values.
*   **`"kustomize"`**: Deploys raw, standalone Kustomize manifests.
*   **`"k0rdent"`**: Deploys as a Mirantis K0rdent service catalog managed custom resource.

#### 💡 Dynamic Compiler Detection:
Instead of maintaining a brittle, hardcoded list of application names in our compiler, our `vars-env.cue` compilation loop dynamically detects standard app-templates vs native charts using CUE's list-fallback idiom:
```cue
let deployVal = [if appSpec.deployment != _|_ { appSpec.deployment }, "bjw-s"][0]
let isAppTemplate = deployVal == "bjw-s" || deployVal == "app-template"
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

