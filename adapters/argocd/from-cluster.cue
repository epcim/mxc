// vim: set ts=2 sw=2 et :
package argocd

import (
	alpha  "github.com/epcim/mxc/schema/alpha:alpha"
	"github.com/epcim/mxc/schema:schema"
	"github.com/epcim/mxc/adapters/helm/app-template:app_template"
	"strings"
)

#FromCluster: {
	input: schema.#ClusterConfig

	let deploy = alpha.#DeployAlpha & {
		targets: {}
	} & [if input.deployAlpha != _|_ { input.deployAlpha }, {}][0]

	output: {
		// Existing alpha ApplicationSets projection
		applicationSets: {
			for targetName, target in deploy.targets if target.enabled != false {
				let instances = [if target.instances != _|_ { target.instances }, {}][0]
				"\(targetName)": schema.#ApplicationSet & {
					metadata: {
						name:      "\(input.clusterName)-\(targetName)"
						namespace: "argocd"
					}
					spec: {
						generators: [{
							list: elements: [
								for instanceName, instance in instances if instance.enabled != false {
									name:      instanceName
									stack:     instance.stack
									namespace: *targetName | string
									cuePath:   "\(input.clusterName)/\(targetName)/\(instanceName)"
									if instance.dependsOn != _|_ {
										dependsOn: strings.Join([for dep in instance.dependsOn { dep.name }], ",")
									}
								}
							]
						}]
						template: {
							metadata: name: "{{name}}"
							spec: {
								project: "default"
								source: {
									repoURL:        "https://example.invalid/mxc.git"
									targetRevision: "HEAD"
									path:           "."
									plugin: {
										name: "mxc-render"
										env: [
											{name: "MXC_STACK", value: "{{stack}}"},
											{name: "MXC_CUE_PATH", value: "{{cuePath}}"},
										]
									}
								}
								destination: {
									server:    "https://kubernetes.default.svc"
									namespace: "{{namespace}}"
								}
							}
						}
					}
				}
			}
		}

		// --- Static ArgoCD-Helm Adapter Projection (As in Proposal) ---
		
		// 1. argocd/services.yaml flat list input for ApplicationSets
		services: [
			for catKey, catApps in input.apps
			for appKey, appSpec in catApps
			if appSpec.deployment == "argocd" {
				svc: appSpec.appName
				chart: [if appSpec.helmChart != _|_ && appSpec.helmChart.chartName != _|_ { appSpec.helmChart.chartName }, "app-template"][0]
				chartVersion: [if appSpec.helmChart != _|_ && appSpec.helmChart.chartVersion != _|_ { appSpec.helmChart.chartVersion }, "4.6.2"][0]
			}
		]

		// 2. operational overrides mapped to <svc>/values-override.yaml
		overrides: {
			for catKey, catApps in input.apps
			for appKey, appSpec in catApps
			if appSpec.deployment == "argocd" {
				"\(appSpec.appName)": {
					let templateName = [
						if appSpec.valuesSchema != _|_ { appSpec.valuesSchema },
						if appSpec.contextSchema != _|_ { appSpec.contextSchema },
						""
					][0]
					
					if templateName == "#app-template" {
						(app_template.#Projection & {
							"appSpec":      appSpec
							"domain":       input.network.domain
							"ingressClass": input.kube.ingress.class
						}).output
					}
					
					if templateName != "#app-template" {
						if appSpec.values != _|_ { appSpec.values }
						if appSpec.values == _|_ && appSpec.context != _|_ { appSpec.context }
					}
				}
			}
		}
	}
}
