// vim: set ts=2 sw=2 et :
package schema

import (
	"github.com/epcim/mxc/schema/platforms"
	"github.com/epcim/mxc/schema/mxc"
)

// #Platform defines the target execution platform requirements and runtime adapter bindings.
// It is designed as a pristine primitive with open outer seams (...) to support arbitrary user-defined platforms.
#Platform: {
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

	// Environment variables injected for platform runtime
	env?: [string]: string

	...
}

// Re-export MXC reference platform profiles
#PlatformMxc:    mxc.#PlatformMxc
#PlatformMxcLab: mxc.#PlatformMxcLab
#PlatformSimple: mxc.#PlatformSimple
