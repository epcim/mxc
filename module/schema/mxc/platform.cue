// vim: set ts=2 sw=2 et :
package mxc

import (
	"github.com/epcim/mxc/schema/platforms"
)

// #PlatformMxc is the default MXC-opinionated platform profile with typed domain execution facets.
#PlatformMxc: {
	// Standard platform execution domains (optional and typed if used)
	k8s?:     platforms.#PlatformK8s
	compose?: platforms.#PlatformCompose
	aws?:     platforms.#PlatformAWS
	k0rdent?: platforms.#PlatformK0rdent

	// Generic multi-cloud or cross-domain IaC tool engine escape hatch
	terraform?: {
		backend?: string
		providers?: [...string]
		[string]: _
	}

	env?: {
		TZ?:      *"UTC" | string
		[string]: string
	}
	...
}

// #PlatformMxcLab provides standard reference defaults for a Talos + Traefik homelab environment.
#PlatformMxcLab: {
	env: {
		TZ:       *"Europe/Prague" | string
		[string]: string
	}
	k8s: platforms.#PlatformK8s & {
		distribution: *"talos" | string
		storage: {
			defaultClass: *"local-path" | string
			classes: {
				fast:       "local-path"
				replicated: "longhorn"
				backup:     "nfs-backup"
			}
		}
		ingress: {
			provider: "traefik"
			class:    "traefik"
			annotations: {
				"traefik.ingress.kubernetes.io/router.entrypoints": "websecure"
				"traefik.ingress.kubernetes.io/router.tls":         "true"
			}
		}
		...
	}
	...
}
