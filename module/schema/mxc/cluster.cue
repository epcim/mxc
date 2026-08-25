// vim: set ts=2 sw=2 et :
package mxc

// #WithKube attaches Kubernetes platform properties.
#WithKube: {
	kube: #KubeSpec
	...
}

// #KubeSpec defines Kubernetes platform and cluster runtime configurations.
#KubeSpec: {
	// Kubernetes distribution type
	type: "microk8s" | "k3s" | "talos" | "eks" | "gke" | "aks" | "kind" | "kwok" | string
	storage?: {
		default:      string
		performance?: string
		backup?:      string
		local?:       string
		...
	}
	ingress?: {
		class: string
		annotations?: [string]: string
		...
	}
	namespaces?: [...string]
	env?: {
		TZ?: string
		...
	}
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
