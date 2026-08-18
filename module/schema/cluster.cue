// vim: set ts=2 sw=2 et :
package schema

import (
	alpha "github.com/epcim/mxc/schema/alpha:alpha"
	"github.com/epcim/mxc/schema/external:external"
	"github.com/epcim/mxc/schema/mxc:mxc"
)

// #Cluster is the ultra-minimal compute deployment target primitive.
#Cluster: {
	clusterName: string
	// Lifecycle stage
	environment: "production" | "staging" | "development" | string

	// TODO: Deprecate top-level env in favor of platform.env
	env?: [string]: string
	values?: {
		[string]: _
	}
	context?: {
		[string]: _
	}
	if context != _|_ {
		values: context
	}
	...
}

// Composable Platform & Infrastructure Facets

// #WithKube attaches Kubernetes platform properties.
#WithKube: {
	kube: mxc.#KubeSpec
	...
}

// #WithNetwork attaches NetBox-compatible network and IPAM topology.
#WithNetwork: {
	network: {
		site?:     string
		location?: string
		vlans?: [string]: #vlan
		dns?: {
			servers?: [...string]
			search?: [...string]
			...
		}
		lb_pools?: [string]: #lb_pool
		vips: [string]:      #vip
		domain: string
		...
	}
	...
}

#lb_pool: {
	vlan?: string
	// IP range (e.g., 172.31.2.32-172.31.2.63)
	range!: string
	interfaces?: [...string]
	...
}

#vip: {
	address!: string
	pool?:    string
	// DNS hostname
	dns?: string
	...
}

#vlan: {
	// VLAN ID (0 = untagged/native)
	id!:      int & >=0 & <=4094
	subnet!:  =~"^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+/[0-9]+$"
	gateway?: string
	...
}

// #WithApps attaches application workload inventory grouped by category.
#WithApps: {
	apps: [Category=string]: [AppKey=string]: #App
	...
}

// #WithPlatform attaches target platform adaptation configuration.
#WithPlatform: {
	platform?: #Platform
	...
}

// #WithPolicies attaches Kubernetes NetworkPolicy definitions.
#WithPolicies: {
	networkPolicies?: [string]: external.#K8sNetworkPolicy
	...
}

// #ClusterMxc is the unified default cluster contract.
#ClusterMxc: #Cluster & #WithPlatform & #WithNetwork & #WithApps & #WithPolicies

// #ClusterConfig is retained as a backward-compatibility alias for #ClusterMxc.
#ClusterConfig: #ClusterMxc

// #TopologyAlpha composes concrete named clusters and application deployment instances.
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
			app: #AppMxc
		}
	}
	...
}
