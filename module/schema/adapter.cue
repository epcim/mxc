// vim: set ts=2 sw=2 et :
package schema

// BaseProjection defines the global, cluster-wide projection properties.
#BaseProjection: {
	cluster: #Cluster

	// TODO: Deprecate individual flat mapping of cluster-level globals below,
	// and instead have downstream templates/renderers directly consume the `cluster` object itself.
	clusterName: cluster.clusterName
	environment: cluster.environment
	domain?:     string
	if (cluster & {network: domain: string}).network.domain != _|_ {
		domain: cluster.network.domain
	}

	// Merge full platform directly at platform level
	platform?: #Platform
	if cluster.platform != _|_ {
		platform: cluster.platform
	}

	// Flat properties for downstream rendering engines
	if platform != _|_ {
		if platform.k8s.ingress.class != _|_ {
			ingressClass: platform.k8s.ingress.class
		}
		if platform.env != _|_ {
			env: platform.env
		}
	}
	if cluster.env != _|_ {
		env: cluster.env
	}

	apps?: [string]:     _
	overlays?: [string]: _
	...
}

// BaseAppAdapter defines the standard 1:1 adapter interface for a single workload.
#BaseAppAdapter: {
	spec:    #AppCore
	cluster: #Cluster
	// Simple projections inherit appName. Deployment-aware adapters set name
	// from the DeployAlpha key; instanceName remains an override point.
	name:         *spec.appName | string
	instanceName: *name | string
	appInstance:  *instanceName | string

	// TODO: Deprecate individual flat mapping of cluster-level globals below,
	// and instead have adapters directly consume the `cluster` object itself.
	clusterName: cluster.clusterName
	environment: cluster.environment
	domain?:     string
	if (cluster & {network: domain: string}).network.domain != _|_ {
		domain: cluster.network.domain
	}

	// Merge full platform directly at platform level
	platform?: #Platform
	if cluster.platform != _|_ {
		platform: cluster.platform
	}
	if spec.platform != _|_ {
		platform: spec.platform
	}

	if platform != _|_ {
		if platform.k8s.ingress.class != _|_ {
			ingressClass: platform.k8s.ingress.class
		}
		if platform.k8s.ingress.annotations != _|_ {
			annotations: platform.k8s.ingress.annotations
		}
	}

	output: {
		appName: spec.appName
		adapter: spec.adapter
		if spec.deployment != _|_ {deployment: spec.deployment}
		// NOTE: Each adapter define what metadata is relevant for its own
		// Direct metadata delivery
		// if spec.tags != _|_ { tags: spec.tags }
		// if spec.k0rdent != _|_ { k0rdent: spec.k0rdent }
		// if spec.secrets != _|_ { secrets: spec.secrets }
		// if spec.values != _|_ { values: spec.values }
		// if spec.kustomize != _|_ { kustomize_spec: spec.kustomize }

		...
	}
}
