// Schema: [apps.cue](../../module/schema/apps.cue#L4) -> schema.#AppCore
// cue-language-server: $schema=../../docs/generated-schema/mxc-cluster.schema.json
// vim: set ts=2 sw=2 et :
package mxc

import (
	_homarr "github.com/epcim/mxc-library/stacks/home/homarr"
)

cluster: apps: home: {
	homarr: _homarr.#Homarr & {
		expose: http: fqdn: "homarr.\(cluster.network.domain)"
	}
}
