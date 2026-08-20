// vim: set ts=2 sw=2 et :
package kustomize

import (
	"list"
	"github.com/epcim/mxc/schema"
)

// #AppAdapter handles parameter mapping and kustomization manifests for standalone Kustomize apps.
#AppAdapter: S=schema.#BaseAppAdapter & {
	output: {
		appName: S.spec.appName
		adapter: S.spec.adapter
		if S.spec.tags != _|_ {tags: S.spec.tags}

		// Direct kustomize specification
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

		// Overlays projection: extra raw Kubernetes resources (CRs, ConfigMaps, Secrets, IngressRoutes, etc.)
		if S.spec.kustomize != _|_ && S.spec.kustomize.overlays != _|_ {
			overlays: S.spec.kustomize.overlays
		}
		if S.spec.overlays != _|_ {
			customOverlays: S.spec.overlays
		}
		...
	}
}

// #Projection projects a ClusterConfig into flat parameters for Kustomize apps.
#Projection: P=schema.#BaseProjection & {
	let _supported = ["kustomize"]

	// Filter and project apps configured with adapter: "kustomize" (or list containing "kustomize")
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
