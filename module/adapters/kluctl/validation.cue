// vim: set ts=2 sw=2 et :
package kluctl

import (
	"list"
	"github.com/epcim/mxc/schema"
)

// #Validation holds optional package-level validations for the Kluctl adapter.
// These are unified with the #Projection block to enforce SRE boundaries.
#Projection: {
	cluster: schema.#ClusterMxc

	// 1. Enforce clusterName is defined and non-empty
	cluster: clusterName: !=""

	// 2. Validate that all mapped workloads have DNS-compliant Kubernetes resource names
	for catKey, catApps in cluster.apps {
		for appKey, appSpec in catApps {
			let _adapterList = [
				if (appSpec.adapter & string) != _|_ {[appSpec.adapter]},
				if (appSpec.adapter & [...string]) != _|_ {appSpec.adapter},
				["kluctl"],
			][0]
			if list.Contains(_adapterList, "kluctl") {
				cluster: apps: "\(catKey)": "\(appKey)": appName: =~"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$"
			}
		}
	}
}
