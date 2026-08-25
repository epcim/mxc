# Multi-Cluster & Multi-Region Topology Example

This example demonstrates how to use MXC's **Hierarchical Topology & Location Architecture** ([`#Topology`](file:///Users/p.michalec/Workspace/gitea/gitops-infra/mxc/module/schema/topology.cue#L34) and [`#Location`](file:///Users/p.michalec/Workspace/gitea/gitops-infra/mxc/module/schema/topology.cue#L12)) to manage a fleet of clusters across public clouds (AWS, GCP) and on-premise edge locations.

---

## 🏛️ Architecture Overview

In MXC, infrastructure hierarchy is structured as:
```text
Topology (Global platform defaults)
 └── Location (e.g., cloud.aws-us-east-2, edge.site-prague)
      └── Cluster (e.g., aws-prod01, edge-prg01)
           └── Apps (e.g., kafka, esphome)
```

Each cluster in the topology satisfies [`schema.#ClusterMxc`](file:///Users/p.michalec/Workspace/gitea/gitops-infra/mxc/module/schema/cluster.cue#L38) and can be projected directly into deployer adapters (`kluctl`, `argocd`, `catalog`).

---

## 🚀 Key Commands

### 1. Validate the Topology
```bash
cue vet ./...
```

### 2. Inspect the Full Topology Document
```bash
cue export ./topology.cue -e topology --out yaml
```

### 3. Extract a Specific Cluster from Topology
```bash
# Export the AWS production cluster
cue export ./topology.cue -e 'topology.location.cloud.location["aws-us-east-2"].cluster["aws-prod01"]' --out yaml

# Export the Edge Prague cluster
cue export ./topology.cue -e 'topology.location.edge.location["site-prague"].cluster["edge-prg01"]' --out yaml
```

### 4. Render Adapter Output for a Specific Cluster
```bash
# Render Kluctl deployment parameters for aws-prod01
cue export ./topology.cue -e 'adapters.aws_prod01.kluctl.output' --out yaml

# Render ArgoCD Application manifests for aws-prod01
cue export ./topology.cue -e 'adapters.aws_prod01.argocd.output' --out yaml

# Render Services Catalog for edge-prg01
cue export ./topology.cue -e 'adapters.edge_prg01.catalog.output' --out yaml
```
