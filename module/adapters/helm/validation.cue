// vim: set ts=2 sw=2 et :
package helm

import (
	"list"
	"github.com/epcim/mxc/schema"
)

// #Validation holds package-level validations for the Helm adapter.
// These are unified with the #Projection block to enforce SRE boundaries.
#Projection: {
	cluster: schema.#ClusterConfig

	// Validate Helm-specific constraints for workloads using the helm adapter
	for catKey, catApps in cluster.apps {
		for appKey, appSpec in catApps {
			let _adapterList = [
				if (appSpec.adapter & string) != _|_ {[appSpec.adapter]},
				if (appSpec.adapter & [...string]) != _|_ {appSpec.adapter},
				["kluctl"],
			][0]

			if list.Contains(_adapterList, "helm") || list.Contains(_adapterList, "helm+kustomize") {
				if appSpec.helmChart != _|_ {
					cluster: apps: "\(catKey)": "\(appKey)": helmChart: {
						repo:         !=""
						chartVersion: !=""
						...
					}
				}
			}
		}
	}
}
