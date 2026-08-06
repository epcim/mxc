// vim: set ts=2 sw=2 et :
package argocd

import (
	"list"
	alpha  "github.com/epcim/mxc/schema/alpha:alpha"
	"github.com/epcim/mxc/schema:schema"
	"github.com/epcim/mxc/schema/external:external"
	"strings"
)

// #AppAdapter defines the specific fields mapped for ArgoCD values overrides.
#AppAdapter: S=schema.#BaseAppAdapter & {
	output: {
		// Direct metadata delivery: these are the fields used by ArgoCD values overrides
		if S.spec.secrets != _|_ { secrets: S.spec.secrets }
		if S.spec.values != _|_ { values: S.spec.values }
	}
}

// #Projection projects a ClusterConfig into flat parameters for ArgoCD.
#Projection: P=schema.#BaseProjection & {

	let deploy = alpha.#DeployAlpha & {
		targets: {}
	} & [if P.cluster.deployAlpha != _|_ { P.cluster.deployAlpha }, {}][0]

	// Define schema + default values for standard ArgoCD settings
	repoURL:        string | *"https://example.invalid/mxc.git"
	targetRevision: string | *"HEAD"
	destServer:     string | *"https://kubernetes.default.svc"
	pluginName:     string | *"mxc-render"
	pluginEnv:      [...{name: string, value: string}] | *[
		{name: "MXC_STACK", value: "{{stack}}"},
		{name: "MXC_CUE_PATH", value: "{{cuePath}}"},
	]

	// Existing alpha ApplicationSets projection
	applicationSets: {
		for targetName, target in deploy.targets if target.enabled != false {
			let instances = [if target.instances != _|_ { target.instances }, {}][0]
			let targetRepoURL = [if target.repoURL != _|_ { target.repoURL }, repoURL][0]
			let targetRevisionVal = [if target.targetRevision != _|_ { target.targetRevision }, targetRevision][0]
			let targetDestServer = [if target.destServer != _|_ { target.destServer }, destServer][0]
			let targetPluginName = [if target.pluginName != _|_ { target.pluginName }, pluginName][0]
			let targetPluginEnv = [if target.pluginEnv != _|_ { target.pluginEnv }, pluginEnv][0]
			let targetProject = [if target.project != _|_ { target.project }, "default"][0]
			let targetPath = [if target.path != _|_ { target.path }, "."][0]

			"\(targetName)": external.#ApplicationSet & {
				metadata: {
					name:      "\(P.cluster.clusterName)-\(targetName)"
					namespace: "argocd"
				}
				spec: {
					generators: [{
						list: elements: [
							for instanceName, instance in instances if instance.enabled != false {
								name:      instanceName
								stack:     instance.stack
								namespace: *targetName | string
								cuePath:   "\(P.cluster.clusterName)/\(targetName)/\(instanceName)"
								if instance.dependsOn != _|_ {
									dependsOn: strings.Join([for dep in instance.dependsOn { dep.name }], ",")
								}
							}
						]
					}]
					template: {
						metadata: name: "{{name}}"
						spec: {
							project: targetProject
							source: {
								repoURL:        targetRepoURL
								targetRevision: targetRevisionVal
								path:           targetPath
								if targetPluginName != "" {
									plugin: {
										name: targetPluginName
										env:  targetPluginEnv
									}
								}
							}
							destination: {
								server:    targetDestServer
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
	let _supported = ["argocd"]
	services: [
		for catKey, catApps in P.cluster.apps
		for appKey, appSpec in catApps
		if list.Contains(_supported, appSpec.deployment) {
			svc: appSpec.appName
			chart: [if appSpec.helmChart != _|_ && appSpec.helmChart.chartName != _|_ { appSpec.helmChart.chartName }, "app-template"][0]
			chartVersion: [if appSpec.helmChart != _|_ && appSpec.helmChart.chartVersion != _|_ { appSpec.helmChart.chartVersion }, "4.6.2"][0]
		}
	]

	// 2. operational overrides mapped to <svc>/values-override.yaml
	overrides: {
		for catKey, catApps in P.cluster.apps
		for appKey, appSpec in catApps
		if list.Contains(_supported, appSpec.deployment) {
			"\(appSpec.appName)": (#AppAdapter & { spec: appSpec }).output
		}
	}
}
