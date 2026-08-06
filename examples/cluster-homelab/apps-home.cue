// Schema: [apps.cue](../../schema/apps.cue#L4) -> schema.#AppCore
// cue-language-server: $schema=../../schema/mxc-cluster.schema.json
// vim: set ts=2 sw=2 et :
package mxc

import (
	shmr "github.com/epcim/mxc-library/stacks/home/homarr"
)

cluster: apps: home: {
	homarr: shmr.#Homarr & {
		expose: http: fqdn: "homarr.\(cluster.network.domain)"
	}
}
