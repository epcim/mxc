// vim: set ts=2 sw=2 et :
package kluctl

import (
	"github.com/epcim/mxc/schema"
)

// #Validation holds optional package-level validations for the Kluctl adapter.
// These are unified with the #Projection block to enforce SRE boundaries.
#Projection: {
	cluster: schema.#ClusterConfig

	// 1. Enforce clusterName is defined and non-empty
	cluster: clusterName: !=""

	// 2. Validate that all mapped workloads have DNS-compliant Kubernetes resource names
	for catKey, catApps in cluster.apps {
		for appKey, appSpec in catApps {
			if appSpec.deployment == "kluctl" {
				cluster: apps: "\(catKey)": "\(appKey)": appName: =~"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$"
			}
		}
	}
}
