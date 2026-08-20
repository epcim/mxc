// vim: set ts=2 sw=2 et :
package helm

import (
	"list"
	"github.com/epcim/mxc/schema"
)

// #AppAdapter handles parameter mapping for standalone Helm apps (with optional Kustomize post-processing).
#AppAdapter: S=schema.#BaseAppAdapter & {
	output: {
		appName: S.spec.appName
		adapter: S.spec.adapter
		if S.spec.tags != _|_ {tags: S.spec.tags}

		if S.spec.helmChart != _|_ {
			helmChart: S.spec.helmChart
		}

		if S.spec.values != _|_ {
			values: S.spec.values
		}

		// Optional kustomize configuration for post-helm custom resources/overlays
		if S.spec.kustomize != _|_ {
			kustomize: {
				for k, v in S.spec.kustomize if k != "resources" && k != "overlays" {
					"\(k)": v
				}

				let defaultResources = [
					if S.spec.kustomize.resources != _|_ {S.spec.kustomize.resources},
					[],
				][0]

				resources: list.Concat([
					defaultResources,
					[
						if S.spec.kustomize.overlays != _|_ {"overlays/mxc-overlays.yaml"},
					],
				])
			}
		}

		if S.spec.kustomize != _|_ && S.spec.kustomize.overlays != _|_ {
			overlays: S.spec.kustomize.overlays
		}
		if S.spec.overlays != _|_ {
			customOverlays: S.spec.overlays
		}
		...
	}
}

// #Projection projects a ClusterConfig into flat parameters for Helm apps.
#Projection: P=schema.#BaseProjection & {
	let _supported = ["helm", "helm+kustomize"]

	// Filter and project apps configured with adapter: "helm" (or list containing "helm")
	apps: {
		for catKey, catApps in P.cluster.apps {
			for appKey, appSpec in catApps {
				let _adapterList = [
					if (appSpec.adapter & string) != _|_ {[appSpec.adapter]},
					if (appSpec.adapter & [...string]) != _|_ {appSpec.adapter},
					["kluctl"],
				][0]
				if len([for a in _adapterList if list.Contains(_supported, a) {a}]) > 0 {
					"\(appSpec.appName)": (#AppAdapter & {
						"spec":    appSpec
						"cluster": P.cluster
					}).output
				}
			}
		}
	}

	output: {
		"apps": apps
	}
}
