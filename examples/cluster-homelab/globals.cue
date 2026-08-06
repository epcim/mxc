// vim: set ts=2 sw=2 et :
package mxc

import (
	"github.com/epcim/mxc/schema:schema"
	adp_argocd       "github.com/epcim/mxc/adapters/argocd:argocd"
	adp_argoworkflow "github.com/epcim/mxc/adapters/argoworkflow:argoworkflow"
	adp_kluctl       "github.com/epcim/mxc-library/adapters/kluctl:kluctl"
	adp_catalog      "github.com/epcim/mxc/adapters/catalog:catalog"
)

cluster: schema.#ClusterConfig & {
	clusterName: "cluster-homelab"
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

// Platform Output Adapters bindings
adapters: {
	kluctl: adp_kluctl.#Projection & {
		cluster: cluster
	}
	argocd: adp_argocd.#Projection & {
		cluster: cluster
	}
	argoworkflow: adp_argoworkflow.#Projection & {
		cluster: cluster
	}
	catalog: adp_catalog.#Projection & {
		cluster: cluster
	}
}

// Flat output exported as vars.yml for Kluctl
mxc_vars: adapters.kluctl.output
