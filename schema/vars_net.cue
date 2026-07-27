// Network Configuration
//
// Network/IPAM configuration for cluster - NetBox compatible
package schema

@jsonschema(schema="http://json-schema.org/draft-07/schema#")
@jsonschema(id="https://gitea.apealive.net/epcim/gitops-infra/schemas/vars-net.schema.json")
network?: {
	// Site/location identifier
	site?: string

	// Geographic location
	location?: string

	// VLAN definitions
	vlans?: [string]: #vlan
	dns?: {
		servers?: [...string]
		search?: [...string]
		...
	}

	// LoadBalancer IP pools (MetalLB)
	lb_pools?: [string]: #lb_pool

	// VIP allocations
	vips!: [string]: #vip
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
...
