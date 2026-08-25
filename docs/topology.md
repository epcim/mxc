# MXC Deployment Architecture: Standalone Clusters vs. Hierarchical Topology

This guide explains MXC's two primary operational patterns: **Standalone Single-Cluster** deployment and **Hierarchical Multi-Cluster Topology**.

---

## 🧭 Pattern Comparison

| Feature | Pattern 1: Standalone Cluster | Pattern 2: Hierarchical Topology |
| :--- | :--- | :--- |
| **Root Schema** | [`schema.#ClusterMxc`](file:///Users/p.michalec/Workspace/gitea/gitops-infra/mxc/module/schema/cluster.cue#L38) or [`schema.#Cluster`](file:///Users/p.michalec/Workspace/gitea/gitops-infra/mxc/module/schema/cluster.cue#L10) | [`schema.#Topology`](file:///Users/p.michalec/Workspace/gitea/gitops-infra/mxc/module/schema/topology.cue#L34) + [`schema.#Location`](file:///Users/p.michalec/Workspace/gitea/gitops-infra/mxc/module/schema/topology.cue#L12) |
| **Target Use Case** | Single homelab cluster, isolated development environment, edge box | Multi-region cloud fleets, multi-site edge networks, global platforms |
| **Structure** | Flat, direct cluster parameters | Tree: `Topology -> Location(s) -> Cluster(s) -> App(s)` |
| **Location Field** | Optional IPAM string metadata (`network.location?: string`) | Recursive nesting node (`location?: [string]: #Location`) |
| **Example Directory** | [`examples/cluster-standalone/`](file:///Users/p.michalec/Workspace/gitea/gitops-infra/mxc/examples/cluster-standalone/) | [`examples/topology-multicloud/`](file:///Users/p.michalec/Workspace/gitea/gitops-infra/mxc/examples/topology-multicloud/) |

---

## 📦 Pattern 1: Standalone Single-Cluster (`#ClusterMxc`)

When managing a dedicated, self-contained cluster (e.g. `cluster-home-mxc` or a standalone dev cluster), you **do not need** a topology or dummy location wrapper. 

The cluster is defined directly at the root of your workspace:

```cue
// cluster.cue
package mxc

import (
	"github.com/epcim/mxc/schema"
	adp_kluctl "github.com/epcim/mxc/adapters/kluctl"
)

C=cluster: schema.#ClusterMxc & {
	clusterName: "cluster-standalone"
	environment: "development"
	network: {
		domain: "homelab.lan"
		vips: {
			traefik: {address: "192.168.1.50", dns: "traefik.homelab.lan"}
		}
	}
	apps: {
		home: {
			homarr: schema.#AppMxc & {
				appName: "homarr"
				adapter: "kluctl"
				image: repository: "ghcr.io/ajnart/homarr"
			}
		}
	}
}

// Bind deployer adapter directly
adapters: kluctl: adp_kluctl.#Projection & {
	cluster: C
}
```

### Exporting:
```bash
# Export flat vars for Kluctl deployer
cue export ./... -e 'adapters.kluctl.output' --out yaml > vars.yml
```

---

## 🌐 Pattern 2: Hierarchical Multi-Cluster Topology (`#Topology`)

When orchestrating a fleet of clusters across multiple cloud providers (AWS, GCP) and regional/edge locations (e.g., Frankfurt, Prague), use [`schema.#Topology`](file:///Users/p.michalec/Workspace/gitea/gitops-infra/mxc/module/schema/topology.cue#L34):

```cue
// topology.cue
package mxc

import (
	"github.com/epcim/mxc/schema"
	adp_kluctl "github.com/epcim/mxc/adapters/kluctl"
)

topology: schema.#Topology & {
	name: "global-fleet"
	
	// Global environment variables and platform defaults
	platform: env: GLOBAL_TIER: "enterprise"

	location: {
		cloud: {
			name: "cloud-providers"
			location: {
				"aws-us-east-2": {
					platform: env: CLOUD_PROVIDER: "aws"
					cluster: {
						"aws-prod01": schema.#ClusterMxc & {
							clusterName: "aws-prod01"
							environment: "production"
							network: domain: "prod01.ohio.aws.apealive.net"
							apps: { ... }
						}
					}
				}
			}
		}
		edge: {
			location: {
				"site-prague": {
					cluster: {
						"edge-prg01": schema.#ClusterMxc & {
							clusterName: "edge-prg01"
							environment: "production"
							network: domain: "edge01.prg.apealive.net"
							apps: { ... }
						}
					}
				}
			}
		}
	}
}

// Bind adapters to specific cluster nodes from the topology tree
adapters: {
	aws_prod01: kluctl: adp_kluctl.#Projection & {
		cluster: topology.location.cloud.location["aws-us-east-2"].cluster["aws-prod01"]
	}
	edge_prg01: kluctl: adp_kluctl.#Projection & {
		cluster: topology.location.edge.location["site-prague"].cluster["edge-prg01"]
	}
}
```

### Exporting:
```bash
# Export deployment parameters for a specific cluster in the topology
cue export ./topology.cue -e 'adapters.aws_prod01.kluctl.output' --out yaml
```

---

## 🎯 Summary Rules

1. **For single clusters**: Use [`#ClusterMxc`](file:///Users/p.michalec/Workspace/gitea/gitops-infra/mxc/module/schema/cluster.cue#L38) directly. No dummy location or topology overhead is required.
2. **For multi-cluster platforms**: Use [`#Topology`](file:///Users/p.michalec/Workspace/gitea/gitops-infra/mxc/module/schema/topology.cue#L34) with nested [`#Location`](file:///Users/p.michalec/Workspace/gitea/gitops-infra/mxc/module/schema/topology.cue#L12) to inherit platform configurations and project individual cluster manifests.
