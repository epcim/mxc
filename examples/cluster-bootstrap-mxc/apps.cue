package mxc

import (
	s_infra "github.com/epcim/mxc-library/stacks/infra"
)

// `cluster.apps` remains the workload catalog. `cluster.topologyAlphaExampleApp`
// in the example folder is the separate placement/orchestration layer that
// points to deployable app entries without pushing dependency semantics down
// into app schemas.
//
// Unlike the shared DNS MXC model, this example does not try to demonstrate
// multi-target topology, package discovery, or external dependency contracts.
// It is intentionally reduced to a single target and a single stack instance.

cluster: apps: {
	infra: {
		// Import and extend Traefik from the standard library
		traefik: s_infra.#Traefik & {
			replicaCount: 1
		}
	}
}
