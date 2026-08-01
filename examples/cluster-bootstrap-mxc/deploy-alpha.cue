package mxc

// Minimal example of the alpha topology contract used by the non-Kluctl
// adapter direction. This stays in the example folder only, so the real
// cluster config can evolve independently.
//
// This is intentionally smaller than the richer shared DNS topology model.
// It demonstrates only the smallest useful placement surface for one target
// and one app entry.
cluster: topologyAlphaExampleApp: {
	apiVersion: "placement.mxc.cue/v1alpha1"
	kind:       "Topology"
	targets: {
		infra: {
			// `package` is optional engine metadata. It can help the runtime locate
			// implementation packages, but it is not the primary deployment intent.
			package: "deploy/infra"
			context: {
				namespace: "infra"
			}
			apps: {
				traefik: {}
			}
		}
	}
}
