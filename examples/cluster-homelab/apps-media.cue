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
