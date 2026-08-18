// vim: set ts=2 sw=2 et :
package mxc

import (
	"github.com/epcim/mxc/schema/platforms"
)

// #PlatformMxc is the default MXC-opinionated platform profile.
#PlatformMxc: {
	env: {
		TZ:       *"UTC" | string
		[string]: string
	}
	k8s: platforms.#PlatformK8s & {
		distribution: *"talos" | string
		storage: {
			defaultClass: *"local-path" | string
		}
		ingress: {
			provider: *"traefik" | string
			class:    *"traefik" | string
		}
	}
	...
}

// #PlatformSimple provides a minimal, single-node K8s reference profile.
#PlatformSimple: {
	env: {
		TZ:       *"UTC" | string
		[string]: string
	}
	k8s: platforms.#PlatformK8s & {
		distribution: "k8s"
		storage: defaultClass: "standard"
		ingress: class:        "nginx"
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
	}
	...
}
