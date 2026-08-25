# Local Agent Skill: MXC Schema Migration & Adoption Guide

* **Name:** `mxc-migration-skill`
* **Role:** Platform Migration Engineer & CUE Architect
* **Description:** Specialized instructions and reasoning patterns for AI agents and test harnesses to identify, migrate, and modernize Model-X Configuration (MXC) schemas, cluster descriptors, application stacks, and adapter projections.

---

## 🚀 Mission Overview

When upgrading older cluster configurations, library stacks, or adapter projections to recent MXC releases, AI agents must follow this systematic migration guide.

Rather than running blind script search-and-replaces, understand the **underlying architectural separation** between:
1. **Pristine Core Primitives** (`#App`, `#Cluster`, `#Platform`, `#Adapter` in `schema/`)
2. **MXC Reference Profile** (`#AppMxc`, `#ClusterMxc`, `#PlatformMxc`, `#PlatformMxcLab` in `schema/mxc/` and `schema/`)
3. **Execution Platform Domains** (`platforms.#PlatformK8s`, `platforms.#PlatformCompose`, `platforms.#PlatformAWS`, `platforms.#PlatformK0rdent` in `schema/platforms/`)
4. **Hierarchical Topology** (`schema.#Topology`, `schema.#Location` in `schema/topology.cue`)

---

## 🔄 Core Migration Mapping Reference

| Legacy Construct | Modern Canonical Construct | Location / Import | Rationale |
| :--- | :--- | :--- | :--- |
| `schema.#AppCore` | `schema.#AppMxc` | `github.com/epcim/mxc/schema` | `#AppMxc` unifies pristine `#App` with container intent facets (`mxc.#AppSpec`). |
| `schema.#ClusterConfig` | `schema.#ClusterMxc` | `github.com/epcim/mxc/schema` | Unified cluster contract combining `#Cluster`, `mxc.#WithNetwork`, and `#WithApps`. |
| `schema.#Cluster & schema.#WithPlatform` | `schema.#ClusterMxc` | `github.com/epcim/mxc/schema` | Platform profile (`#PlatformMxc` / `#PlatformMxcLab`) is set directly under `cluster.platform`. |
| `appSpec: schema.#AppCore` (in adapters) | `appSpec: schema.#AppMxc` | `github.com/epcim/mxc/schema` | Adapters evaluating storage, image, ports, or secrets require `#AppMxc` (or `mxc.#AppSpec`). |
| Manual Jinja overlay files | `kustomize.overlays: [...]` | Native CUE list of Kubernetes API objects | CUE-defined typed overlays serialized into `overlays/mxc-overlays.yaml`. |
| Flat multi-cluster scripts | `schema.#Topology` & `schema.#Location` | `github.com/epcim/mxc/schema` | Native hierarchical multi-cloud, multi-region, and edge topology modeling with platform inheritance. |

---

## 🛠️ Step-by-Step Migration Procedures

### Step 1: Migrating Workload Declarations (`apps.cue`)

#### ❌ Before (Legacy)
```cue
package mxc

import "github.com/epcim/mxc/schema:schema"

cluster: apps: {
    infra: {
        traefik: schema.#AppCore & {
            appName: "traefik"
            adapter: "kluctl"
            ports: { web: port: 80 }
            kustomize: { namespace: "sys" }
        }
    }
}
```

#### ✅ After (Modern)
```cue
package mxc

import "github.com/epcim/mxc/schema:schema"

cluster: apps: {
    infra: {
        traefik: schema.#AppMxc & {
            appName: "traefik"
            adapter: "kluctl"
            ports: { web: port: 80 }
            kustomize: { namespace: "sys" }
        }
    }
}
```

---

### Step 2: Migrating Cluster Environment Descriptors (`globals.cue` / `vars-env.cue`)

#### ❌ Before (Legacy)
```cue
package mxc

import "github.com/epcim/mxc/schema:schema"

C=cluster: schema.#Cluster &
    schema.#WithPlatform & {
        clusterName: "prod01"
        environment: "production"
        platform: schema.#PlatformMxcLab & { ... }
        network: {
            domain: "example.com"
        }
    }
```

#### ✅ After (Modern)
```cue
package mxc

import "github.com/epcim/mxc/schema:schema"

C=cluster: schema.#ClusterMxc & {
    clusterName: "prod01"
    environment: "production"
    platform: schema.#PlatformMxcLab & { ... }
    network: {
        domain: "example.com"
    }
}
```

---

### Step 3: Migrating Storage & App-Template Adapters (`fixtures.cue` / `projection.cue`)

When building or updating output adapters that inspect workload facets (like `appSpec.storage` or `appSpec.image`):

#### ❌ Before (Legacy)
```cue
#Storage: {
    appSpec: schema.#AppCore
    ...
}
```

#### ✅ After (Modern)
```cue
#Storage: {
    appSpec: schema.#AppMxc
    ...
}
```

---

### Step 4: Adopting Multi-Region & Edge Topology (`#Topology`)

When transitioning from isolated standalone clusters to a fleet-managed infrastructure:

1. **Declare Topology Top-Level**:
   ```cue
   apiVersion: "topology.mxc.cue/v1alpha1"
   kind:       "Topology"
   ```
2. **Define Locations Hierarchy**:
   Use nested `location?: [string]: #Location` blocks (e.g. `cloud.aws`, `cloud.gcp`, `edge.prague`).
3. **Attach Shared Platform Defaults**:
   Set `platform: schema.#PlatformMxc` at parent locations to automatically cascade defaults to all nested clusters.
4. **Bind Compute Clusters**:
   Place individual clusters under `cluster: [string]: schema.#ClusterMxc`.

Example:
```cue
package mxc

import (
    "github.com/epcim/mxc/schema:schema"
    adp_kluctl "github.com/epcim/mxc/adapters/kluctl:kluctl"
)

topology: schema.#Topology & {
    name: "global-enterprise"
    location: {
        cloud: {
            location: {
                aws_us_east: {
                    platform: schema.#PlatformMxc & {
                        aws: region: "us-east-2"
                        env: TZ: "America/New_York"
                    }
                    cluster: {
                        aws_prod01: schema.#ClusterMxc & {
                            clusterName: "aws-prod01"
                            environment: "production"
                            network: domain: "aws.prod.example.com"
                        }
                    }
                }
            }
        }
    }
}

// Multi-cluster adapter projections
adapters: {
    for locName, loc in topology.location.cloud.location {
        for cName, c in loc.cluster {
            "\(cName)": {
                kluctl: adp_kluctl.#Projection & { cluster: c }
            }
        }
    }
}
```

---

## ⚠️ Common Pitfalls & Diagnostic Guide

### 1. The Concrete Verification Trap (`cue vet -c`)
Plain `cue vet ./...` ignores incomplete optional fields. Always use the `-c` flag during migration validation:
```bash
cue vet -c ./...
```
If an error `field not allowed: platform.k8s.kustomize` appears:
* Ensure `cluster.platform` is unified with `schema.#PlatformMxc` / `schema.#PlatformMxcLab` and that `module/schema/platforms/k8s.cue` exports the typed field.
* Ensure apps are declared as `schema.#AppMxc`.

### 2. Import Self-Reference Collision
Never name an import alias identical to an enclosing struct field:
* ❌ Bad: `import "github.com/epcim/mxc/adapters/kluctl:kluctl"` inside a struct with `kluctl: ...`
* ✅ Good: `import adp_kluctl "github.com/epcim/mxc/adapters/kluctl:kluctl"`

### 3. Local `cue.mod/pkg/` Dependencies
Ensure `**/cue.mod/pkg/` is included in `.gitignore` so local symlinks and vendored packages do not pollute git status.

---

## 🛠️ Verification Commands

```bash
# 1. Validate full repository schemas
just mxc::validate

# 2. Test multi-cloud topology fixtures
just mxc::test-topology

# 3. Format all migrated CUE files
just mxc::fmt
```
