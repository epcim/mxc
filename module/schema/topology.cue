// vim: set ts=2 sw=2 et :
// ==============================================================================
// MXC Unified Topology & Location Architecture
// ==============================================================================
// Defines the physical and logical infrastructure hierarchy:
// Topology -> Location(s) -> Cluster(s) -> App(s)
// ==============================================================================
package schema

// #LocationRef defines a symbolic pointer to a physical or logical location.
#LocationRef: {
	ref?: string // canonical path, e.g. "cloud.aws.us-east-2"
	id?:  string // provider ID, e.g. "site-par2", "vpc-12345"
	...
}

// #Location defines a physical or logical infrastructure boundary
// (e.g., cloud provider, region, datacenter, zone, rack, or site).
#Location: {
	name?: string
	tags?: [...string]

	// Single or multiple location references / network peerings
	locationRef?:  string | #LocationRef | [...(string | #LocationRef)]
	locationRefs?: [...(string | #LocationRef)]

	// Target platform adaptation parameters attached at location level
	platform?: #Platform

	values?: [string]:  _
	context?: [string]: _
	if context != _|_ {
		values: context
	}

	// Arbitrary recursive nested sub-locations (e.g. cloud.aws.us-east-2)
	locations?: {[string]: #Location}
	location?:  {[string]: #Location}

	// Compute clusters hosted at this location
	clusters?: {[string]: #Cluster}
	cluster?:  {[string]: #Cluster}

	// Pure name-based child compute clusters / sub-locations
	[=~"^[a-zA-Z0-9_-]+$" & !~"^(apiVersion|kind|name|type|locationRef|locationRefs|location|locations|cluster|clusters|instances|apps|tags|platform|values|context|env|endpoints|owner|stack|flavor|package|packageSource|clusterName|clusterType|environment|domain|dependsOn|externals|gc|ce|re)$"]: #Cluster | #Location
	...
}

// #Topology is the root deployment topology document.
#Topology: {
	apiVersion?: *"topology.mxc.cue/v1alpha1" | string
	kind?:       *"Topology" | string

	name?: string
	tags?: [...string]

	// Global platform defaults
	platform?: #Platform

	values?: [string]:  _
	context?: [string]: _
	if context != _|_ {
		values: context
	}

	// Physical or logical locations hosting clusters
	locations?: {[string]: #Location}
	location?:  {[string]: #Location}

	// Pure name-based root locations (e.g. gc, ce, cloud, aws)
	[=~"^[a-zA-Z0-9_-]+$" & !~"^(apiVersion|kind|name|type|locationRef|locationRefs|location|locations|cluster|clusters|instances|apps|tags|platform|values|context|env|endpoints|owner|stack|flavor|package|packageSource|clusterName|clusterType|environment|domain|dependsOn|externals|gc|ce|re)$"]: #Location
	...
}
