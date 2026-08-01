// vim: set ts=2 sw=2 et :
package schema

import alpha "github.com/epcim/mxc/schema/alpha:alpha"

#ClusterConfig: {
	clusterName: string
	environment: "production" | "staging" | "development"
	
	kube: {
		type: "microk8s" | "k3s" | "talos" | "eks" | "gke" | "aks" | "kind" | "kwok"
		storage: {
			default: string
			performance?: string
			backup?: string
			local?: string
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
		site?: string
		location?: string
		vlans?: [string]: #vlan
		dns?: {
			servers?: [...string]
			search?: [...string]
		}
		lb_pools?: [string]: #lb_pool
		vips: [string]: #vip
		domain: string
	}
	
	// Grouped application specifications by category/group (e.g., example, games, infra, etc.)
	apps: [Category=string]: [AppKey=string]: #AppCore

	// Alpha deployment and placement surface. Keep orchestration semantics here
	// while the final contract shape is still under evaluation.
	deployAlpha?: alpha.#DeployAlpha

	// Validated Kubernetes NetworkPolicies
	networkPolicies?: [string]: #K8sNetworkPolicy
}
