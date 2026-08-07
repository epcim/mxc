// Schema: [apps.cue](../../schema/apps.cue#L4) -> schema.#AppCore
// cue-language-server: $schema=../../schema/mxc-cluster.schema.json
// vim: set ts=2 sw=2 et :
package mxc

import (
	// Package-private import alias to avoid lexical scope shadowing.
	// In CUE, a struct field label (like `silo:`) shadows an imported package
	// of the same name. We import the package using a private alias starting
	// with an underscore (`_silo`) to safely refer to the schema (like `_silo.#Silo`)
	// within its struct block.
	_silo "github.com/epcim/mxc-library/stacks/media/silo"
)

cluster: apps: media: {
	silo: _silo.#Silo & {
		expose: http: fqdn: "silo.\(cluster.network.domain)"
		secrets: {
			secretKey: "{{ secrets.media.silo.secretKey }}"
			notifications: {
				host: "{{ secrets.infra.notifications.host }}"
				port: "{{ secrets.infra.notifications.port }}"
				user: "{{ secrets.infra.notifications.user }}"
				pass: "{{ secrets.infra.notifications.pass }}"
				addr: "{{ secrets.infra.notifications.addr }}"
			}
		}
	}
}
