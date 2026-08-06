// vim: set ts=2 sw=2 et :
package mxc

import "github.com/epcim/mxc/schema:schema"

cluster: schema.#ClusterConfig & {
	clusterName: "cluster-standalone"
	environment: "development"
	kube: {
		type: "kwok"
		storage: {
			default: "local-path"
		}
		ingress: {
			class: "traefik"
			annotations: {
				"traefik.ingress.kubernetes.io/router.entrypoints": "websecure"
				"traefik.ingress.kubernetes.io/router.tls":         "true"
				"traefik.ingress.kubernetes.io/preserve-host":      "true"
			}
		}
		env: {
			TZ: "Europe/Prague"
		}
	}
	network: {
		domain: "homelab.lan"
		vips: {
			traefik: {address: "192.168.1.50", dns: "traefik.homelab.lan"}
			traefik_svc: {address: "192.168.1.51", dns: "svc.homelab.lan"}
		}
	}
}

// Projection endpoint for Kluctl engine
mxc_vars: adapters.kluctl.output
