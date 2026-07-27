package mxc

import (
	s_infra "github.com/epcim/mxc-library/stacks/infra"
)

cluster: apps: {
	infra: {
		// Import and extend Traefik from the standard library
		traefik: s_infra.#Traefik & {
			replicaCount: 1
		}
	}
}
