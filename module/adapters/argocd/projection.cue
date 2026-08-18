// vim: set ts=2 sw=2 et :
package argocd

import (
	"list"
	"github.com/epcim/mxc/schema"
)

// #AppAdapter defines the specific fields mapped for ArgoCD values overrides.
#AppAdapter: S=schema.#BaseAppAdapter & {
	output: {
		// Direct metadata delivery: these are the fields used by ArgoCD values overrides
		if S.spec.secrets != _|_ {secrets: S.spec.secrets}
		if S.spec.values != _|_ {values: S.spec.values}
	}
}

// #Projection projects a ClusterConfig into flat parameters for ArgoCD.
#Projection: P=schema.#BaseProjection & {
	// --- Static ArgoCD-Helm Adapter Projection (As in Proposal) ---

	// 1. argocd/services.yaml flat list input for ApplicationSets
	let _supported = ["argocd"]
	services: [
		for catKey, catApps in P.cluster.apps
		for appKey, appSpec in catApps
		if list.Contains(_supported, appSpec.deployment) {
			svc: appSpec.appName
			chart: [if appSpec.helmChart != _|_ && appSpec.helmChart.chartName != _|_ {appSpec.helmChart.chartName}, "app-template"][0]
			chartVersion: [if appSpec.helmChart != _|_ && appSpec.helmChart.chartVersion != _|_ {appSpec.helmChart.chartVersion}, "4.6.2"][0]
		}
	]

	// 2. operational overrides mapped to <svc>/values-override.yaml
	overrides: {
		for catKey, catApps in P.cluster.apps
		for appKey, appSpec in catApps
		if list.Contains(_supported, appSpec.deployment) {
			"\(appSpec.appName)": (#AppAdapter & {spec: appSpec, cluster: P.cluster}).output
		}
	}

	// 3. Consolidated output block for export tasks
	output: {
		if len(services) > 0 {
			"services": services
		}
		if len(overrides) > 0 {
			"overrides": overrides
		}
	}
}
