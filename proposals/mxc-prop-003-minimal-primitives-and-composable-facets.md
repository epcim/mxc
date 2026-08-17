# MXC-PROP-003: Minimal Core Primitives (#App & #Cluster), Composable Facets, and Open Adapter Plugins

This Platform Improvement Proposal (PIP/RFC) establishes the architectural redesign of MXC's foundational primitives ([`#App`](file:///Users/p.michalec/Workspace/gitea/agx-toolbox/workspace/agent-f5csdns/external/mxc/module/schema/apps.cue#L10) and [`#Cluster`](file:///Users/p.michalec/Workspace/gitea/agx-toolbox/workspace/agent-f5csdns/external/mxc/module/schema/cluster.cue#L10)), transitioning from monolithic structs to an **ultra-minimalist core + composable facets + open adapter pipeline** model.

---

## 🎯 1. Motivation & Problem Statement

Currently, [`#App`](file:///Users/p.michalec/Workspace/gitea/agx-toolbox/workspace/agent-f5csdns/external/mxc/module/schema/apps.cue#L10) and [`#Cluster`](file:///Users/p.michalec/Workspace/gitea/agx-toolbox/workspace/agent-f5csdns/external/mxc/module/schema/cluster.cue#L10) bundle multiple orthogonal concerns into monolithic schemas:

1. **Monolithic `#App`**:
   - Bundles container lifecycles (`image`), networking (`ports`, `expose`), storage (`storage`), credentials (`secrets`), and platform escape hatches (`helmChart`, `kustomize`, `k0rdent`).
   - **Friction**: Native Helm charts, raw Kustomize manifests, and CRD operators must either ignore or bypass root-level container fields, creating competing sources of truth (`image` vs. `values.image`).
   - The required `deployment` enum creates artificial validation boundaries for new rendering targets.

2. **Monolithic `#Cluster`**:
   - Bundles orchestrator runtime (`kube`), Bare-Metal IPAM/VIPs (`network`), security (`networkPolicies`), and application collections (`apps`).
   - **Friction**: Cloud-managed clusters (EKS/GKE) or dev environments (KinD/KWOK) are forced to carry Bare-Metal NetBox IPAM and multi-tier storage schema boilerplate.

---

## 🏛️ 2. Architectural Design

```mermaid
graph TD
    subgraph MXC Core Kernel
        App["#App (Core Identity + Adapter + Values)"]
        AppSimple["#AppSimple (Official Container Contract)"]
        Cluster["#Cluster (Core Identity + Env + Values)"]
    end

    subgraph MXC Core Kernel
        App["#App (Core Identity + Adapter + Values)"]
        AppMxc["#AppMxc (Official Container Contract)"]
        Cluster["#Cluster (Core Identity + Env + Values)"]
    end

    subgraph Kubernetes & Container Facet Package (schema/mxc_k8s)
        K8sFacet["schema/mxc_k8s: #ImageSpec, #PortsSpec, #ExposeSpec, #StorageSpec, #SecretsSpec, #KubeSpec"]
    end

    subgraph Downstream Repositories
        UserApp["cluster-home-mxc: #App & { custom params }"]
        UserCluster["cluster-home-mxc: #Cluster & { kube, network, apps }"]
    end

    AppMxc --> App
    AppMxc --> K8sFacet

    UserApp --> App
    UserCluster --> Cluster
    UserCluster --> K8sFacet
```

---

## 📦 3. Schema Specifications

### 3.1 Ultra-Minimal `#App` Core

The base `#App` represents the universal deployable unit across any rendering engine:

```cue
package schema

#SchemaRef: string | [...string]

// Ultra-minimal application workload primitive
#App: {
	appName: string

	// Open rendering adapter selector (defaults to "export" for raw value dump)
	adapter: string | *"export"

	// Backward-compatibility alias for legacy 'deployment'
	deployment?: string
	if deployment != _|_ {
		adapter: deployment
	}

	values?: [string]: _
	valuesSchema?: #SchemaRef
	flavor?: string
	tags?: [...string]
}
```

### 3.2 The Consolidated Container Facet Package (`schema/mxc_k8s`)

> **Naming & Philosophy**: The package is explicitly named `mxc_k8s` (and the contract `#AppMxc`), reflecting MXC's foundational design pillars:
> * **M**inimal: Only the essential parameters; no unnecessary abstractions.
> * **M**odel: Declarative intent decoupled from physical deployment mechanics.
> * **M**odular / **M**ix: Composable facets unified dynamically via CUE.
> * **M**eta: Rich, structured compilation metadata upstream of target deployers.
>
> Naming it `mxc_k8s` also guarantees clean separation from official upstream Kubernetes API schemas (e.g. `cue.dev/x/k8s.io` or `k8s.io/api/...`).

Container and platform-level schemas (`#ImageSpec`, `#PortsSpec`, `#ExposeSpec`, `#StorageSpec`, `#SecretsSpec`, `#KubeSpec`) are consolidated into `github.com/epcim/mxc/schema/mxc_k8s`.

Each definition maintains an open struct tail (`...`) to allow downstream extensions without validation friction:

```cue
// schema/mxc_k8s/workload.cue
package mxc_k8s

import "github.com/epcim/mxc/schema/external:external"

#ImageSpec: {
	repository: string
	tag?:        string | *"latest"
	digest?:     string
	...
}

#PortsSpec: [string]: external.#PortSpec & {
	port: *8080 | int
	...
}

#ExposeSpec: [PortName=string]: {
	target:       "ingress" | "loadbalancer" | "internal" | "none" | *"none"
	ingressClass: string | *""
	fqdn?:        string
	annotations?: [string]: string
	...
}

#StorageSpec: [string]: external.#VolumeSpec & {
	...
}

#SecretsSpec: [string]: _
```

### 3.3 `#AppMxc` (Official Container Intent Contract)

`#AppMxc` unifies the core `#App` with the `mxc_k8s` container facets, serving as the official intent contract supported out of the box by MXC built-in adapters:

```cue
package schema

import (
	k8s "github.com/epcim/mxc/schema/mxc_k8s"
)

#AppMxc: #App & {
	adapter: *"kluctl" | string
	image?:   k8s.#ImageSpec
	ports?:   k8s.#PortsSpec
	expose?:  k8s.#ExposeSpec
	storage?: k8s.#StorageSpec
	secrets?: k8s.#SecretsSpec
}

// Backward compatibility aliases
#AppSimple: #AppMxc
#AppCore:   #AppMxc
```

### 3.4 Ultra-Minimal `#Cluster` and Platform Facets

```cue
package schema

// Ultra-minimal cluster primitive
#Cluster: {
	clusterName: string
	environment: "production" | "staging" | "development" | string

	env?: [string]: string
	values?: [string]: _
}

// Platform Facets (imported as needed)
#WithKube: {
	kube: {
		type: "microk8s" | "k3s" | "talos" | "eks" | "gke" | "aks" | "kind" | "kwok" | string
		storage?: {
			default:      string
			performance?: string
			backup?:      string
			local?:       string
		}
		ingress?: {
			class:        string
			annotations?: [string]: string
		}
		namespaces?: [...string]
		env?: {
			TZ?: string
		}
	}
}

#WithNetwork: {
	network: {
		domain:    string
		site?:     string
		location?: string
		dns?: {
			servers?: [...string]
			search?:  [...string]
		}
		vlans?:    [string]: _
		lb_pools?: [string]: _
		vips?:     [string]: _
	}
}

#WithApps: {
	apps: [Category=string]: [AppKey=string]: #App
}
```

---

## 🛠️ 4. Downstream Extension Pattern (Zero Naming Friction)

Downstream repositories (e.g. `cluster-home-mxc` or custom user stacks) do not create artificial wrapper types. Instead, they directly declare their local `#App` and `#Cluster` unifying against MXC base schemas:

```cue
// cluster-home-mxc/schema.cue
package mycluster

import "github.com/epcim/mxc/schema"

// Directly extend MXC base #App with cluster/repo-specific fields
#App: schema.#App & {
	image?: {
		pullSecrets?: [...string]
		pullPolicy?:  "Always" | "IfNotPresent" | "Never"
	}
	serviceLoadbalancers?: [...string]
}

// Compose cluster definition for this environment
#Cluster: schema.#Cluster & 
          schema.#WithKube & 
          schema.#WithNetwork & 
          schema.#WithApps & {
	// Local site defaults and constraints
}
```

---

## 🔌 5. Adapter Extension & Wrapping for Custom `#App` Objects

When a user repository (e.g. `cluster-home-mxc` or a custom library stack) extends `#App` with domain-specific objects (e.g., `serviceLoadbalancers`, `gpu`, `customBackup`), how does the compiler project these into deployer outputs without modifying core MXC?

MXC establishes **three complementary adapter extension patterns**:

### Pattern A: Pipeline Wrapping (Adapter Composition)
The user repository wraps the core adapter (`kluctl.#ProjectApp`, `argocd.#ProjectApp`, etc.) and unifies its own transform rules on top of the base output:

```cue
// cluster-home-mxc/adapters/projection.cue
package cluster_home

import (
	"github.com/epcim/mxc/adapters/kluctl"
)

// Wrap and extend the base Kluctl projection for cluster-home workloads
#ProjectHomeApp: {
	app: #App // The user's extended #App

	// 1. Run core projection
	base: kluctl.#ProjectApp & { "app": app }

	// 2. Unify custom object transforms onto base output
	out: base.out & {
		// Custom transform: serviceLoadbalancers -> Extra K8s LoadBalancer Services
		if app.serviceLoadbalancers != _|_ {
			kustomize: overlays: [
				for lb in app.serviceLoadbalancers {
					apiVersion: "v1"
					kind:       "Service"
					metadata: {
						name:      "\(app.appName)-\(lb)"
						namespace: app.kustomize.namespace | *"default"
					}
					spec: {
						type: "LoadBalancer"
						selector: app: app.appName
					}
				}
			]
		}

		// Custom transform: customBackup -> Velero Schedule CR
		if app.customBackup != _|_ {
			kustomize: overlays: [
				{
					apiVersion: "velero.io/v1"
					kind:       "Schedule"
					metadata: name: "\(app.appName)-backup"
					spec: {
						schedule: app.customBackup.schedule
						template: includedNamespaces: [app.kustomize.namespace | *"default"]
					}
				}
			]
		}
	}
}
```

---

### Pattern B: Self-Projecting Facet Hooks (Encapsulated Traits)
When defining reusable custom facets, the facet schema can encapsulate its own projection logic directly via a `#renderHook` definition:

```cue
// custom-library/facets/gpu.cue
package facets

#WithGPU: {
	gpu?: {
		vendor: "nvidia" | "amd" | *"nvidia"
		count:  int | *1

		// Self-contained projection hook consumed by adapters
		#renderHook: {
			values: resources: limits: {
				if vendor == "nvidia" { "nvidia.com/gpu": "\(count)" }
				if vendor == "amd"    { "amd.com/gpu":    "\(count)" }
			}
		}
	}
}
```
The adapter simply loops over any embedded `#renderHook` instances present on the struct and merges them automatically into `out.values` or `out.manifests`.

---

### Pattern C: Pluggable Adapter Middleware / Hooks Pipeline
Core adapters expose an open `plugins` list where downstream configurations inject transform structs:

```cue
// Core adapter execution model
#ProjectApp: {
	app: schema.#App

	// 1. Base Intent Transforms (Image, Expose, Storage)
	baseValues: {
		if (app & { image: _ }).image != _|_ {
			image: repository: app.image.repository
		}
	}

	// 2. Open Middleware/Plugin Pipeline
	plugins: [...#AdapterPlugin] | *[]
	
	// Dynamically chain user-provided plugins
	_applied: [for p in plugins { (p & { "in": app }).out }]
	
	// Final aggregated output
	outValues: baseValues & _applied
}
```

---

### Summary of Extension Options
| Approach | When to Use | Mechanism |
| :--- | :--- | :--- |
| **Pipeline Wrapping (Pattern A)** | Repository-wide customizations (e.g. `cluster-home-mxc` injecting global service meshes, backup CRs, extra annotations). | User defines `#ProjectHomeApp: kluctl.#ProjectApp & { ... }`. |
| **Self-Projecting Hooks (Pattern B)** | Reusable community/library facets (e.g. `#WithGPU`, `#WithMetrics`). | Facet embeds `#renderHook` which adapters auto-merge. |
| **Plugin Middleware (Pattern C)** | Dynamic runtime injection in topologies or multi-target environments. | Pass plugin structs into `plugins: [...]`. |

---

## 🚀 6. Rollout & Backward Compatibility Plan

1. **Phase 1: Add Open Fields and Alias Aliases**:
   - Introduce `adapter: string | *"export"` while preserving `deployment` as an auto-derived alias.
   - Define `#App` as the minimalist core and `#AppMxc` as the container contract.
   - Retain `#AppSimple: #AppMxc` and `#AppCore: #AppMxc` for existing cluster compatibility.
2. **Phase 2: Extract Consolidated Facet Package (`schema/mxc_k8s`)**:
   - Consolidate container/Kubernetes intent sub-schemas (`#ImageSpec`, `#PortsSpec`, `#ExposeSpec`, `#StorageSpec`, `#SecretsSpec`, `#KubeSpec`) into `schema/mxc_k8s` with `...` open tails.
3. **Phase 3: Update Adapters to Micro-Transform Pattern**:
   - Refactor `projection.cue` to use dynamic guard checks and plugin pipelines.
4. **Phase 4: Downstream Migration**:
   - Migrate `cluster-home-mxc` and `mxc-library` to consume `#AppMxc` / `#App` and modular cluster facets.
