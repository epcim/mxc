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
// schema.#TopologyAlpha composes these bindings with #AppCore and
// #ClusterConfig; keeping that composition in package schema avoids an import
// cycle from this alpha package back to its parent.

#RefAlpha: close({
	kind:     "cluster" | "instance" | "external"
	name:     string & !=""
	cluster?: string & !=""
})

// #InstanceIdentityAlpha provides one naming chain for simple and advanced
// deployments. Callers normally set only name; specialized instance names may
// override the default without changing the base object name.
#InstanceIdentityAlpha: {
	name:         string & !=""
	instanceName: *name | (string & !="")
	...
}

#ClusterInstanceAlpha: I=#InstanceIdentityAlpha & {
	clusterInstance: *I.instanceName | (string & !="")
	cluster:         _
}

// #PlacementAlpha selects the named clusters where one application instance is
// deployed. The non-empty list is the simple form; overrides remain optional
// and are interpreted by the deployment adapter.
#PlacementAlpha: {
	clusters: [string, ...string]
	overrides?: [string]: {
		enabled?: *true | bool
		context?: {
			[string]: _
		}
	}
	...
}

// #AppInstanceAlpha binds one reusable application definition to one or more
// named clusters. TopologyAlpha constrains app to #AppCore.
#AppInstanceAlpha: I=#InstanceIdentityAlpha & {
	appInstance: *I.instanceName | (string & !="")
	enabled?:    *true | bool
	app:         _
	placement:   #PlacementAlpha
	dependsOn?: [...#RefAlpha]
	context?: {
		[string]: _
	}
	...
}

#DeployAlpha: {
	apiVersion?: *"deploy.mxc.cue/v1alpha1" | string
	kind?:       *"Deploy" | string
	instances: [instanceKey=string]: #AppInstanceAlpha & {
		name: instanceKey
	}
	...
}
