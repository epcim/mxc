// vim: set ts=2 sw=2 et :
package schema

import (
	alpha "github.com/epcim/mxc/schema/alpha:alpha"
	"github.com/epcim/mxc/schema/external:external"
)

#ClusterConfig: {
	clusterName: string
	environment: "production" | "staging" | "development"

	env?: [string]: string

	kube: {
		type: "microk8s" | "k3s" | "talos" | "eks" | "gke" | "aks" | "kind" | "kwok"
		storage: {
			default:      string
			performance?: string
			backup?:      string
			local?:       string
		}
		ingress: {
			class: string
			annotations?: [string]: string
		}
		namespaces?: [...string]
		env?: {
			TZ?: string
		}
	}

	network: {
		site?:     string
		location?: string
		vlans?: [string]: #vlan
		dns?: {
			servers?: [...string]
			search?: [...string]
		}
		lb_pools?: [string]: #lb_pool
		vips: [string]:      #vip
		domain: string
	}

	// Grouped application specifications by category/group (e.g., example, games, infra, etc.)
	apps: [Category=string]: [AppKey=string]: #AppCore

	// Validated Kubernetes NetworkPolicies
	networkPolicies?: [string]: external.#K8sNetworkPolicy
}

// #TopologyAlpha composes concrete named clusters and application deployment
// instances. Reusable profiles remain ordinary CUE definitions and imports;
// topology references their values directly instead of creating another
// profile registry. Cross-reference and rollout policy belongs to deployment
// adapters/controllers so this composition surface remains open and reusable.
#TopologyAlpha: {
	apiVersion?: *"deploy.mxc.cue/v1alpha1" | string
	kind?:       *"Topology" | string
	clusters: [clusterKey=string]: C=alpha.#ClusterInstanceAlpha & {
		name: clusterKey
		cluster: #ClusterConfig & {
			clusterName: C.clusterInstance
		}
	}
	deploy: alpha.#DeployAlpha & {
		instances: [string]: {
			app: #AppCore
		}
	}
	...
}
