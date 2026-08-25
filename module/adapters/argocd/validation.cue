// vim: set ts=2 sw=2 et :
package argocd

import (
	"list"
	"github.com/epcim/mxc/schema"
)

// #Validation holds optional package-level validations for the ArgoCD adapter.
// These are unified with the #Projection block to enforce SRE boundaries.
#Projection: P=schema.#BaseProjection & {
	// Optional ArgoCD workload constraints
	for catKey, catApps in P.cluster.apps {
		for appKey, appSpec in catApps {
			let _adapterList = [
				if (appSpec.adapter & string) != _|_ {[appSpec.adapter]},
				if (appSpec.adapter & [...string]) != _|_ {appSpec.adapter},
				[],
			][0]
			if list.Contains(_adapterList, "argocd") {
				// Assert namespace is set if kustomize block is defined
				if appSpec.kustomize != _|_ {
					cluster: apps: "\(catKey)": "\(appKey)": kustomize: namespace: !=""
				}
			}
		}
	}
}
