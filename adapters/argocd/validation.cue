// vim: set ts=2 sw=2 et :
package argocd

import (
	"github.com/epcim/mxc/schema:schema"
)

// #Validation holds optional package-level validations for the ArgoCD adapter.
// These are unified with the #Projection block to enforce SRE boundaries.
#Projection: {
	cluster: schema.#ClusterConfig

	// Optional ArgoCD workload constraints
	for catKey, catApps in cluster.apps {
		for appKey, appSpec in catApps {
			if appSpec.deployment == "argocd" {
				// Assert namespace is set if kustomize block is defined
				if appSpec.kustomize != _|_ {
					appSpec: kustomize: namespace: !=""
				}
			}
		}
	}
}
