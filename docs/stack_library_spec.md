# MXC Stack Library Specification

This document defines the standard layout, schema rules, and adapter contracts for any workload composition library (e.g., `github.com/epcim/mxc-library`) integrated into the MXC ecosystem.

---

## 1. Directory Structure

A standardized MXC Stack Library must follow this directory hierarchy:

```
mxc-library/
├── cue.mod/                   # CUE Module metadata
│   └── module.cue             # Declares module name: "github.com/epcim/mxc-library"
├── stacks/                    # CUE workload declarations (The Content)
│   ├── cicd/                  # Woodpecker, Renovate, Forgejo
│   ├── game/                  # Game namespaces and isolated workloads
│   ├── infra/                 # Core utilities (MetalLB, Traefik, Grafana)
│   ├── media/                 # Storage-heavy media stacks (Emby, Silo)
│   └── networking/            # NetBird client gateways, DNS stacks
└── adapters/                  # Rendering Adapters (The Engine Bindings)
    └── kluctl/                # Kluctl-specific render adapters
        ├── helm-chart.yml     # Standard Helm chart fetch specification
        ├── helm-values.yml    # Parameter-to-values binding
        ├── kustomization.yml  # Kustomize list of resources
        ├── overlays/          # PVCs, NetworkPolicies, custom ConfigMaps
        └── vars.yml           # Base bindings and default values
```

---

## 2. Multi-Library Composition (Mixing & Extending Portfolios)

MXC is designed as an open platform. End-users are not restricted to a single monolithic stack portfolio. Instead, they can mix and match multiple independent CUE libraries by declaring imports inside their cluster configuration.

### How Mixing Works (Unification Merge)

Because CUE values are merged via **unification (`&`)**, multiple imported libraries can define different aspects of the same application category, and the CUE compiler will merge them into a single coherent deployment profile.

### Example: Mixing Core and Third-Party Libraries

Suppose we want to deploy standard infra apps, but we also want to import an enterprise database portfolio from `github.com/company/mxc-cloud-library`:

```cue
// cluster-home-mxc/apps.cue
package mxc

import (
    s_infra "github.com/epcim/mxc-library/stacks/infra"
    s_cloud "github.com/company/mxc-cloud-library/stacks/databases"
)

cluster: apps: {
    // Loaded from epcim/mxc-library
    infra: {
        traefik: s_infra.#Traefik
        grafana: s_infra.#Grafana
    }

    // Loaded from third-party company library
    databases: {
        postgres: s_cloud.#EnterprisePostgres & {
            flavor: "large"
        }
    }
}
```

This makes the platform's portfolio infinitely extensible. Adding a new suite of deployable applications is as simple as adding a CUE import and binding it to a category key.

---

## 3. Conditional Infrastructure Domains (Selective Validation Pattern)

In complex deployments, libraries often define configurations for platform resources like AWS VPCs, EKS clusters, Proxmox hypervisors, or Unifi switches. 

We do **not** want to force every end-user to specify AWS credentials or Proxmox VLAN mappings if they are not deploying those resources. To prevent compilation and schema validation failures on inactive infrastructure domains, MXC uses the **Selective Validation Pattern**.

### The Pattern: Dynamic Activation Schema

We wrap infrastructure definitions in conditional blocks. Schema validation constraints are **only activated** if the domain is explicitly selected/enabled:

```cue
// mxc/schema/infrastructure.cue
package schema

#AwsConfig: {
    enabled: bool | *false

    // Conditional Block: validated ONLY if enabled is explicitly set to true
    if enabled == true {
        region:      string & =~"^[a-z]{2}-[a-z]+-[0-9]$" // e.g. "us-east-1"
        accessKeyId: string & != ""
        vpcId:       string & =~"^vpc-[0-9a-f]+$"
    }
}
```

### Usage in Cluster Configuration

If an environment is running in a local Kwok or Bare-Metal cluster (e.g. `cluster-home-mxc`), AWS configuration is disabled or omitted. No AWS schema validations are executed:

```cue
// cluster-home-mxc/vars-env.cue
cluster: {
    clusterName: "home-cluster"
    
    // AWS is disabled; compiler ignores region & key requirements
    aws: enabled: false 
}
```

If a production profile activates AWS, the compiler immediately enforces strict type and regex checks on the required AWS fields:

```cue
// cluster-aws-prod/vars-env.cue
cluster: {
    clusterName: "aws-prod"
    
    aws: {
        enabled:     true
        region:      "eu-west-1"
        accessKeyId: "AKIAIOSFODNN7EXAMPLE"
        vpcId:       "vpc-0d41e2b444747a8ef"
    }
}
```

---

## 4. Definition of Adapters (AD-003)

An **Adapter** is a rendering layer that maps abstract CUE parameters directly to execution engines (like Kluctl, Helm, or raw Kubernetes manifests).

Every adapter must expose a strict interface to its consumer:

* **`helmChart`:** Defines the upstream chart, repository, version, and optional release values.
* **`context`:** Accepts the compiled CUE schema outputs (matching the exact properties of the application).
* **`kustomize`:** Declares output target namespaces and injects custom overlays (e.g., `overlays/pvc.yaml` or custom authentication middlewares).

By defining this standard, we can transition these adapters over time into purely model-driven CUE packages, eliminating intermediate YAML templates entirely while keeping the composition layer 100% backward-compatible.
