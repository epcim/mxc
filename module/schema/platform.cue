// vim: set ts=2 sw=2 et :
package schema

import (
	"github.com/epcim/mxc/schema/mxc"
	"github.com/epcim/mxc/schema/platforms"
)

// #Platform defines the minimal, pristine target execution platform primitive.
// It is designed resource-free with open outer seams (...) to support arbitrary user platforms.
#Platform: {
	// Environment variables injected for platform runtime
	env?: [string]: string

	// Standard platform execution domains (optional and typed if used)
	k8s?:     platforms.#PlatformK8s
	compose?: platforms.#PlatformCompose
	aws?:     platforms.#PlatformAWS
	k0rdent?: platforms.#PlatformK0rdent

	...
}

// Re-export MXC reference platform profiles (consolidated to two primary profiles)
#PlatformMxc:    mxc.#PlatformMxc
#PlatformMxcLab: mxc.#PlatformMxcLab
