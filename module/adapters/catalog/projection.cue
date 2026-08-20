// vim: set ts=2 sw=2 et :
package catalog

import (
	"github.com/epcim/mxc/schema"
)

// #AppAdapter defines the specific fields mapped for the catalog.
#AppAdapter: S=schema.#BaseAppAdapter & {
	output: {
		appName: S.spec.appName
		if S.spec.appDesc != _|_ {appDesc: S.spec.appDesc}
		if S.spec.appFqdn != _|_ {appFqdn: S.spec.appFqdn}
		adapter: S.spec.adapter
		if S.spec.image != _|_ {image: S.spec.image}

		// Direct metadata delivery: these are the fields used by the catalog
		if S.spec.valuesSchema != _|_ {valuesSchema: S.spec.valuesSchema}
		if S.spec.tags != _|_ {tags: S.spec.tags}
		if S.spec.k0rdent != _|_ {k0rdent: S.spec.k0rdent}
		if S.spec.values != _|_ {values: S.spec.values}
		if S.spec.kustomize != _|_ {kustomize_spec: S.spec.kustomize}
	}
}

// #Projection projects a ClusterConfig into flat parameters for Catalog.
#Projection: P=schema.#BaseProjection & {

	// Flat, queryable service catalog listing all workloads configured across the cluster
	services: [
		for catKey, catApps in P.cluster.apps
		for appKey, appSpec in catApps {
			name:    appSpec.appName
			category: catKey
			adapter:  appSpec.adapter
			if appSpec.appDesc != _|_ {description: appSpec.appDesc}
			if appSpec.valuesSchema != _|_ {valuesSchema: appSpec.valuesSchema}
			image: [if appSpec.image != _|_ {appSpec.image}, null][0]

			let exposeVal = (appSpec & {expose: {}}).expose
			let defaultDomain = [if P.cluster.network.domain != _|_ {P.cluster.network.domain}, ""][0]
			let resolvedFqdn = [
				if appSpec.appFqdn != _|_ {appSpec.appFqdn},
				if exposeVal.http != _|_ && exposeVal.http.fqdn != _|_ {exposeVal.http.fqdn},
				if defaultDomain != "" {appSpec.appName + "." + defaultDomain},
				"",
			][0]

			// Auto-generate live URLs for any ingress-exposed ports or appFqdn
			endpoints: [
				if resolvedFqdn != "" {
					name: "http"
					url:  "https://" + resolvedFqdn
				},
				for portKey, exposeSpec in exposeVal
				if portKey != "http" && exposeSpec.target == "ingress" {
					name: portKey
					url: "https://" + [if exposeSpec.fqdn != _|_ {exposeSpec.fqdn}, appSpec.appName + "." + defaultDomain][0]
				},
			]
		}
	]

	// Simplified flat mapping of service names directly to their primary resolved FQDN
	endpoints: {
		for catKey, catApps in P.cluster.apps
		for appKey, appSpec in catApps {
			let exposeVal = (appSpec & {expose: {}}).expose
			let defaultDomain = [if P.cluster.network.domain != _|_ {P.cluster.network.domain}, ""][0]
			let resolvedFqdn = [
				if appSpec.appFqdn != _|_ {appSpec.appFqdn},
				if exposeVal.http != _|_ && exposeVal.http.fqdn != _|_ {exposeVal.http.fqdn},
				if defaultDomain != "" {appSpec.appName + "." + defaultDomain},
				"",
			][0]
			if resolvedFqdn != "" {
				"\(appSpec.appName)": "https://" + resolvedFqdn
			}
		}
	}

	// Flat mapping of every application name directly to its compiled specification
	apps: {
		for catKey, catApps in P.cluster.apps
		for appKey, appSpec in catApps {
			"\(appSpec.appName)": (#AppAdapter & {spec: appSpec, cluster: P.cluster}).output
		}
	}
}
