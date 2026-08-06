// Schema: [apps.cue](../../schema/apps.cue#L4) -> schema.#AppCore
// cue-language-server: $schema=../../schema/mxc-cluster.schema.json
// vim: set ts=2 sw=2 et :
package mxc

import (
	smed "github.com/epcim/mxc-library/stacks/media"
)

cluster: apps: media: {
	silo: smed.#Silo & {
		expose: http: fqdn: "silo.\(cluster.network.domain)"
	}
}
