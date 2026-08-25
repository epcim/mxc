// vim: set ts=2 sw=2 et :
package schema

import (
	"github.com/epcim/mxc/schema/mxc"
)

// #Cluster is the foundational compute deployment target primitive.
// It contains core target properties with zero infrastructure-specific facets.
#Cluster: {
	clusterName: string
	environment: "production" | "staging" | "development" | string
	domain?:     string

	// Target platform adaptation configuration (symmetrical with #App.platform and #Location.platform)
	platform?: #Platform

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

// #WithApps attaches application workload inventory grouped by category.
#WithApps: {
	apps: [Category=string]: [AppKey=string]: #App
	...
}

// #ClusterMxc is the unified default cluster contract attaching IPAM network and apps.
#ClusterMxc: #Cluster & mxc.#WithNetwork & #WithApps
