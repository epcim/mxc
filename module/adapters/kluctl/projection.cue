// vim: set ts=2 sw=2 et :
package kluctl

import (
	"list"
	"github.com/epcim/mxc/schema"
)

// #AppAdapter handles the 1:1 parameter delivery for a single application.
// All complex validation resides inside the schema layer (validation.cue / apps.cue).
#AppAdapter: S=schema.#BaseAppAdapter & {
	let _isAppTemplate = len([for s in [if (S.spec.valuesSchema & string) != _|_ {[S.spec.valuesSchema]}, if (S.spec.valuesSchema & [...string]) != _|_ {S.spec.valuesSchema}, []][0] if s == "#app-template" {s}]) > 0
	let _hasPVC = (S.spec.storage != _|_ && !_isAppTemplate) || (S.spec.overlays != _|_ && S.spec.overlays.pvc != _|_) || (output.overlays != _|_ && output.overlays.pvc != _|_)

	output: {
		// Direct metadata delivery
		if S.spec.tags != _|_ {tags: S.spec.tags}
		if S.spec.k0rdent != _|_ {k0rdent: S.spec.k0rdent}
		if S.spec.secrets != _|_ {secrets: S.spec.secrets}
		if S.spec.values != _|_ {values: S.spec.values}
		if S.spec.kustomize != _|_ {kustomize_spec: S.spec.kustomize}
		if S.spec.overlays != _|_ {overlays: S.spec.overlays}

		// Pass-through or generate kustomize file-lists
		if S.spec.kustomize != _|_ {
			kustomize: {
				for k, v in S.spec.kustomize if k != "resources" && k != "overlays" {
					"\(k)": v
				}

				let defaultResources = [
					if S.spec.kustomize.resources != _|_ {S.spec.kustomize.resources},
					["helm-rendered.yaml"],
				][0]

				resources: list.Concat([
					defaultResources,
					[
						if S.spec.kustomize.overlays != _|_ {"overlays/mxc-overlays.yaml"},
					],
					[
						if _hasPVC {"overlays/pvc.yaml"},
					],
				])
			}
		}

		if S.spec.kustomize != _|_ && S.spec.kustomize.overlays != _|_ {
			kustomize_overlays: S.spec.kustomize.overlays
		}
		...
	}
}

// #Projection projects a ClusterConfig into flat parameters for Kluctl.
#Projection: P=schema.#BaseProjection & {
	// Map workloads using our simplified, declarative #AppAdapter
	let _supported = ["kluctl"]
	apps: {
		for catKey, catApps in P.cluster.apps {
			for appKey, appSpec in catApps
			if list.Contains(_supported, appSpec.deployment) {
				"\(appKey)": (#AppAdapter & {
					"spec":    appSpec
					"cluster": P.cluster
				}).output
			}
		}
	}

	// Streamlined overlays and global PVC extraction
	overlays: {
		if P.cluster.networkPolicies != _|_ {
			networkPolicies: [for v in P.cluster.networkPolicies {v}]
		}

		// Flat, transparent collection of PVCs for the deployment runtime
		pvc: [
			for appKey, appOut in apps
			if appOut.overlays != _|_ && appOut.overlays.pvc != _|_
			for pvcItem in appOut.overlays.pvc {
				pvcItem
			}
		]

		// Pass-through other non-PVC overlays
		for catKey, catApps in P.cluster.apps {
			for appKey, appSpec in catApps {
				if appSpec.overlays != _|_ {
					for k, v in appSpec.overlays if k != "pvc" {
						"\(k)": v
					}
				}
			}
		}
	}

	// Filtered output parameters for the Kluctl engine
	output: {
		for k, v in P if k != "cluster" && k != "output" {
			"\(k)": v
		}
	}
}
