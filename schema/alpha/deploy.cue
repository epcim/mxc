// vim: set ts=2 sw=2 et :
package alpha

// Alpha deployment semantics.
//
// This file is intentionally marked alpha because the long-term shape may
// converge toward a Cluster API, K0rdent, or other controller-aligned model.
// Keep orchestration semantics here, not in #AppCore.
//
// Naming follows an explicit alpha-stage style, similar to Kubernetes API
// evolution, so callers can treat these as provisional contracts.

#RefAlpha: close({
	kind: "stack" | "instance" | "target" | "external"
	name: string
})

#StackInstanceAlpha: close({
	enabled?: *true | bool
	stack:    string
	dependsOn?: [...#RefAlpha]
	context?: {
		[string]: _
	}
})

#TargetAlpha: {
	enabled?: *true | bool
	instances?: [string]: #StackInstanceAlpha
	dependsOn?: [...#RefAlpha]
	context?: {
		[string]: _
	}
	...
}

#DeployAlpha: {
	apiVersion?: *"deploy.mxc.cue/v1alpha1" | string
	kind?:       *"Deploy" | string
	targets?: [string]: #TargetAlpha
	...
}

#TopologyAlpha: {
	apiVersion?: *"deploy.mxc.cue/v1alpha1" | string
	kind?:       *"Topology" | string
	clusters?: [string]: #DeployAlpha
	...
}
