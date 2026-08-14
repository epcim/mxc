// vim: set ts=2 sw=2 et :
package catalog

import (
	"github.com/epcim/mxc/schema:schema"
)

// #AppAdapter defines the specific fields mapped for the catalog.
#AppAdapter: S=schema.#BaseAppAdapter & {
	output: {
		appName:    S.spec.appName
		deployment: S.spec.deployment
		if S.spec.image != _|_ { image: S.spec.image }

		// Direct metadata delivery: these are the fields used by the catalog
		if S.spec.tags != _|_ { tags: S.spec.tags }
		if S.spec.k0rdent != _|_ { k0rdent: S.spec.k0rdent }
		if S.spec.values != _|_ { values: S.spec.values }
		if S.spec.kustomize != _|_ { kustomize_spec: S.spec.kustomize }
	}
}

// #Projection projects a ClusterConfig into flat parameters for Catalog.
#Projection: P=schema.#BaseProjection & {

	// Flat, queryable service catalog listing all workloads configured across the cluster
	services: [
		for catKey, catApps in P.cluster.apps
		for appKey, appSpec in catApps {
			name:        appSpec.appName
			category:    catKey
			deployment:  appSpec.deployment
			image:       [if appSpec.image != _|_ { appSpec.image }, null][0]
			
			// Auto-generate live URLs for any ingress-exposed ports
			endpoints: [
				for portKey, exposeSpec in appSpec.expose
				if exposeSpec.target == "ingress" {
					name: portKey
					url:  "https://" + [if exposeSpec.fqdn != _|_ { exposeSpec.fqdn }, appSpec.appName + "." + P.cluster.network.domain][0]
				}
			]
		}
	]

	// Simplified flat mapping of service names directly to their primary resolved FQDN
	endpoints: {
		for catKey, catApps in P.cluster.apps
		for appKey, appSpec in catApps {
			let ingressPorts = [
				for portKey, exposeSpec in appSpec.expose
				if exposeSpec.target == "ingress" {
					[if exposeSpec.fqdn != _|_ { exposeSpec.fqdn }, appSpec.appName + "." + P.cluster.network.domain][0]
				}
			]
			if len(ingressPorts) > 0 {
				"\(appSpec.appName)": "https://" + ingressPorts[0]
			}
		}
	}

	// Flat mapping of every application name directly to its compiled specification
	apps: {
		for catKey, catApps in P.cluster.apps
		for appKey, appSpec in catApps {
			"\(appSpec.appName)": (#AppAdapter & { spec: appSpec, cluster: P.cluster }).output
		}
	}
}
