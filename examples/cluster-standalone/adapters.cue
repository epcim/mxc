// vim: set ts=2 sw=2 et :
package mxc

import (
	adp_argocd       "github.com/epcim/mxc/adapters/argocd:argocd"
	adp_argoworkflow "github.com/epcim/mxc/adapters/argoworkflow:argoworkflow"
	adp_kluctl       "github.com/epcim/mxc/adapters/kluctl:kluctl"
	adp_catalog      "github.com/epcim/mxc/adapters/catalog:catalog"
)

adapters: {
	kluctl: adp_kluctl.#FromCluster & {
		input: cluster
	}
	argocd: adp_argocd.#FromCluster & {
		input: cluster
	}
	argoworkflow: adp_argoworkflow.#FromCluster & {
		input: cluster
	}
	catalog: adp_catalog.#FromCluster & {
		input: cluster
	}
}
