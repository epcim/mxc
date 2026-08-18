// vim: set ts=2 sw=2 et :
package mxc

import (
	"github.com/epcim/mxc/schema:schema"
	adp_argocd "github.com/epcim/mxc/adapters/argocd:argocd"
	adp_kluctl "github.com/epcim/mxc/adapters/kluctl:kluctl"
	adp_catalog "github.com/epcim/mxc/adapters/catalog:catalog"
)

C=cluster: schema.#Cluster &
	schema.#WithPlatform & {
		clusterName: "cluster-standalone"
		environment: "development"
		platform: schema.#PlatformMxcLab & {
			env: {
				TZ: "Europe/Prague"
			}
			k8s: {
				distribution: "kwok"
				storage: defaultClass: "local-path"
				ingress: annotations: {
					"traefik.ingress.kubernetes.io/router.entrypoints": "websecure"
					"traefik.ingress.kubernetes.io/router.tls":         "true"
					"traefik.ingress.kubernetes.io/preserve-host":      "true"
				}
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

// Platform Output Adapters bindings
adapters: {
	[string]: {
		cluster: C
	}
	kluctl:  adp_kluctl.#Projection
	argocd:  adp_argocd.#Projection
	catalog: adp_catalog.#Projection
}

// Flat output exported as vars.yml for Kluctl
mxc_vars: adapters.kluctl.output
