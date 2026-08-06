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
		// Standard, pre-validated app parameters passed to Kluctl (Flattened categories)
		apps: {
			for catKey, catApps in input.apps {
				for appKey, appSpec in catApps {
					"\(appKey)": {
						appName: appSpec.appName
						if appSpec.k0rdent != _|_ { k0rdent: appSpec.k0rdent }
						if appSpec.tags != _|_ { tags: appSpec.tags }
						deployment: appSpec.deployment

						// Distinguish between app-template workloads and native charts: the
						// generic bjw-s app-template chart is selected by contextSchema
						// referencing "#app-template" — deployment stays "kluctl" either way.
						let contextSchemaList = [
							if (appSpec.contextSchema & string) != _|_ {appSpec.contextSchema},
							if (appSpec.contextSchema & [...string]) != _|_ for s in appSpec.contextSchema {s},
						]
						let isAppTemplate = len([for s in contextSchemaList if s == "#app-template" {s}]) > 0

						if appSpec.restart != _|_ {
							restart: {
								schedule:   appSpec.restart.schedule
								targetKind: appSpec.restart.targetKind
								targetName: [if appSpec.restart.targetName != _|_ { appSpec.restart.targetName }, appSpec.appName][0]
							}
						}

						if appSpec.kustomize != _|_ || appSpec.restart != _|_ {
							kustomize: {
								if appSpec.kustomize != _|_ {
									for k, v in appSpec.kustomize {
										if k != "resources" && k != "overlays" {
											"\(k)": v
										}
									}
								}
								
								let defaultResources = [
									if appSpec.kustomize != _|_ && appSpec.kustomize.resources != _|_ { appSpec.kustomize.resources },
									["helm-rendered.yaml"]
								][0]

								resources: list.Concat([
									defaultResources,
									[
										if (appSpec.storage != _|_ && !isAppTemplate) || (appSpec.overlays != _|_ && appSpec.overlays.pvc != _|_) { "overlays/pvc.yaml" },
										if appSpec.restart != _|_ { "overlays/rollout-restart.yaml" },
										if appSpec.kustomize != _|_ && appSpec.kustomize.overlays != _|_ { "overlays/cue-overlays.yaml" },
									]
								])
							}
						}

						if appSpec.kustomize != _|_ && appSpec.kustomize.overlays != _|_ {
							kustomize_overlays: appSpec.kustomize.overlays
						}


						if appSpec.helmChart != _|_ { helmChart: appSpec.helmChart }
						if isAppTemplate && appSpec.helmChart == _|_ {
							helmChart: {
								repo:         "https://bjw-s-labs.github.io/helm-charts"
								chartName:    "app-template"
								chartVersion: "4.6.2"
								releaseName:  appSpec.appName
								if appSpec.kustomize != _|_ {
									namespace:    appSpec.kustomize.namespace
								}
								skipCRDs:     false
								skipPrePull:  true
							}
						}

						if isAppTemplate {
							let baseContext = (app_template.#Projection & {
								"appSpec":      appSpec
								"domain":       input.network.domain
								"ingressClass": input.kube.ingress.class
							}).output

							context: baseContext
						}

						if !isAppTemplate {
							// For native helm charts, pass through custom context values directly
							context: {
								if appSpec.context != _|_ { appSpec.context }
							}
						}

						if appSpec.storage != _|_ {
							volumes: {
								for k, v in appSpec.storage {
									"\(k)": {
										size:         v.size
										storageClass: v.class
									}
								}
							}
							if !isAppTemplate {
								overlays: {
									pvc: [
										for k, v in appSpec.storage {
											name:         "\(appSpec.appName)-\(k)"
											size:         v.size
											storageClass: v.class
										}
									]
								}
							}
						}
					}
				}
			}
		}

		// Dynamic overlay rendering projection
		overlays: {
			if input.networkPolicies != _|_ {
				networkPolicies: [
					for k, v in input.networkPolicies {
						v
					}
				]
			}
			// Collect and concatenate all pvc overlays from all apps using flat nested list comprehension
			pvc: [
				for groupName, groupApps in input.apps
				for appName, appSpec in groupApps
				if appSpec.overlays != _|_ && appSpec.overlays.pvc != _|_
				for pvcItem in appSpec.overlays.pvc {
					pvcItem
				}
			]
			// Collect other structural overlays natively
			for groupName, groupApps in input.apps {
				for appName, appSpec in groupApps {
					if appSpec.overlays != _|_ {
						for k, v in appSpec.overlays {
							if k != "pvc" {
								"\(k)": v
							}
						}
					}
				}
			}
		}
	}
}
