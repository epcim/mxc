// vim: set ts=2 sw=2 et :
// ==============================================================================
// MXC Unified Topology & Location Architecture
// ==============================================================================
// Defines the physical and logical infrastructure hierarchy:
// Topology -> Location(s) -> Cluster(s) -> App(s)
// ==============================================================================
package schema

// #Location defines a physical or logical infrastructure boundary
// (e.g., cloud provider, region, datacenter, zone, rack, or site).
#Location: {
	name?: string
	tags?: [...string]

	// Target platform adaptation parameters attached at location level
	platform?: #Platform

	values?: [string]:  _
	context?: [string]: _
	if context != _|_ {
		values: context
	}

	// Arbitrary recursive nested sub-locations (e.g. cloud.aws.us-east-2)
	location?: [string]: #Location

	// Compute clusters hosted at this location
	cluster?: [string]: #ClusterMxc
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
	location?: [string]: #Location
	...
}
