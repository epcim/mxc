// vim: set ts=2 sw=2 et :
package kluctl

import (
	"list"
	"github.com/epcim/mxc/schema:schema"
	"github.com/epcim/mxc/adapters/helm/app-template:app_template"
)

#FromCluster: {
	input: schema.#ClusterConfig

	output: {
		clusterName: input.clusterName
		environment: input.environment
		global: {
			ecr:            "containers.\(input.network.domain)"
			internalDomain: input.network.domain
			externalDomain: input.network.domain
		}
		kube: {
			storageClass: input.kube.storage.default
			ingressClass: input.kube.ingress.class
		}
		network: {
			domain: input.network.domain
			vips: {
				for k, v in input.network.vips {
					"\(k)": v.address
				}
			}
		}

		// Clean, declarative mapping of workloads using the #AppAdapter helper
		apps: {
			for catKey, catApps in input.apps {
				for appKey, appSpec in catApps {
					"\(appKey)": (#AppAdapter & {
						"spec":         appSpec
						"domain":       input.network.domain
						"ingressClass": input.kube.ingress.class
					}).output
				}
			}
		}

		// Streamlined overlay collections
		overlays: {
			if input.networkPolicies != _|_ {
				networkPolicies: [for v in input.networkPolicies { v }]
			}
			
			// Flat, self-contained PVC collection
			pvc: [
				for catKey, catApps in input.apps
				for appKey, appSpec in catApps
				if appSpec.overlays != _|_ && appSpec.overlays.pvc != _|_
				for pvcItem in appSpec.overlays.pvc {
					pvcItem
				}
			]

			// Pass-through of any other non-PVC overlays
			for catKey, catApps in input.apps {
				for appKey, appSpec in catApps {
					if appSpec.overlays != _|_ {
						for k, v in appSpec.overlays if k != "pvc" {
							"\(k)": v
						}
					}
				}
			}
		}
	}
}

// ============================================================================
// Private Helper Definitions (Enforcing Clean Separation of Concerns)
// ============================================================================

#AppAdapter: {
	spec:         schema.#AppCore
	domain:       string
	ingressClass: string

	// Direct polymorphic template resolution by name (removing boolean variables)
	_templateName: [
		if spec.valuesSchema != _|_ { spec.valuesSchema },
		if spec.contextSchema != _|_ { spec.contextSchema },
		""
	][0]

	// The compiled projection output for this application
	output: {
		appName:    spec.appName
		deployment: spec.deployment
		if spec.tags != _|_ { tags: spec.tags }
		if spec.k0rdent != _|_ { k0rdent: spec.k0rdent }

		// Dynamic restart mappings
		if spec.restart != _|_ {
			restart: {
				schedule:   spec.restart.schedule
				targetKind: spec.restart.targetKind
				targetName: [if spec.restart.targetName != _|_ { spec.restart.targetName }, spec.appName][0]
			}
		}

		// Optional kustomize definitions
		if spec.kustomize != _|_ || spec.restart != _|_ {
			kustomize: {
				if spec.kustomize != _|_ {
					for k, v in spec.kustomize {
						if k != "resources" && k != "overlays" {
							"\(k)": v
						}
					}
				}
				
				let defaultResources = [
					if spec.kustomize != _|_ && spec.kustomize.resources != _|_ { spec.kustomize.resources },
					["helm-rendered.yaml"]
				][0]

				resources: list.Concat([
					defaultResources,
					[
						if (spec.storage != _|_ && _templateName != "#app-template") || (spec.overlays != _|_ && spec.overlays.pvc != _|_) { "overlays/pvc.yaml" },
						if spec.restart != _|_ { "overlays/rollout-restart.yaml" },
						if spec.kustomize != _|_ && spec.kustomize.overlays != _|_ { "overlays/cue-overlays.yaml" },
					]
				])
			}
		}

		if spec.kustomize != _|_ && spec.kustomize.overlays != _|_ {
			kustomize_overlays: spec.kustomize.overlays
		}

		// Helm chart resolution
		if spec.helmChart != _|_ { helmChart: spec.helmChart }
		if _templateName == "#app-template" && spec.helmChart == _|_ {
			helmChart: {
				repo:         "https://bjw-s-labs.github.io/helm-charts"
				chartName:    "app-template"
				chartVersion: "4.6.2"
				releaseName:  spec.appName
				if spec.kustomize != _|_ {
					namespace:    spec.kustomize.namespace
				}
				skipCRDs:     false
				skipPrePull:  true
			}
		}

		// Optional storage mappings
		if spec.storage != _|_ {
			volumes: {
				for k, v in spec.storage {
					"\(k)": {
						size:         v.size
						storageClass: v.class
					}
				}
			}
			if _templateName != "#app-template" {
				overlays: pvc: [
					for k, v in spec.storage {
						name:         "\(spec.appName)-\(k)"
						size:         v.size
						storageClass: v.class
					}
				]
			}
		}

		// Polymorphic values resolution
		if _templateName == "#app-template" {
			let baseContext = (app_template.#Projection & {
				"appSpec":      spec
				"domain":       domain
				"ingressClass": ingressClass
			}).output

			context: baseContext
		}

		if _templateName != "#app-template" {
			context: {
				if spec.values != _|_ { spec.values }
				if spec.values == _|_ && spec.context != _|_ { spec.context }
			}
		}
	}
}
