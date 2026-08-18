// vim: set ts=2 sw=2 et :
package schema

// BaseProjection defines the global, cluster-wide projection properties.
#BaseProjection: {
	cluster: #ClusterConfig

	// TODO: Deprecate individual flat mapping of cluster-level globals below,
	// and instead have downstream templates/renderers directly consume the `cluster` object itself.
	clusterName:  cluster.clusterName
	environment:  cluster.environment
	domain:       cluster.network.domain
	ingressClass?: string
	if cluster.kube.ingress != _|_ && cluster.kube.ingress.class != _|_ {
		ingressClass: cluster.kube.ingress.class
	}
	env: [if cluster.env != _|_ {cluster.env}, {}][0]

	apps?: [string]:     _
	overlays?: [string]: _
	...
}

// BaseAppAdapter defines the standard 1:1 adapter interface for a single workload.
#BaseAppAdapter: {
	spec:    #AppCore
	cluster: #ClusterConfig
	// Simple projections inherit appName. Deployment-aware adapters set name
	// from the DeployAlpha key; instanceName remains an override point.
	name:         *spec.appName | string
	instanceName: *name | string
	appInstance:  *instanceName | string

	// TODO: Deprecate individual flat mapping of cluster-level globals below,
	// and instead have adapters directly consume the `cluster` object itself.
	clusterName:  cluster.clusterName
	environment:  cluster.environment
	domain:       cluster.network.domain
	ingressClass?: string
	if cluster.kube.ingress != _|_ && cluster.kube.ingress.class != _|_ {
		ingressClass: cluster.kube.ingress.class
	}
	annotations?: [string]: string
	if cluster.kube.ingress != _|_ && cluster.kube.ingress.annotations != _|_ {
		annotations: cluster.kube.ingress.annotations
	}

	output: {
		appName:    spec.appName
		deployment: spec.deployment
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
