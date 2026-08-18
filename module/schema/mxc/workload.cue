// vim: set ts=2 sw=2 et :
package mxc

import (
	"github.com/epcim/mxc/schema/external:external"
)

// #ImageSpec defines high-level container image coordinates and pull settings.
#ImageSpec: {
	repository:   string
	tag?:          string | *"latest"
	digest?:       string
	pullPolicy?:   "Always" | "IfNotPresent" | "Never"
	pullSecrets?:  [...string]
	...
}

// #PortsSpec maps service port names to network port definitions.
#PortsSpec: [string]: external.#PortSpec & {
	port: *8080 | int
	...
}

// #ExposeSpec defines ingress and external routing intents.
#ExposeSpec: [PortName=string]: {
	target:       "ingress" | "loadbalancer" | "internal" | "none" | *"none"
	ingressClass: string | *"" // Automatically resolved by compiler if empty
	fqdn?:        string       // Automatically resolved by compiler if empty
	annotations?: [string]: string
	...
}

// #StorageSpec defines persistent volume intent.
#StorageSpec: [string]: external.#VolumeSpec & {
	...
}

// #SecretsSpec defines secret contract requirements.
#SecretsSpec: [string]: _

// #ResourcesSpec defines container compute resource constraints.
#ResourcesSpec: {
	flavor?: "nano" | "small" | "medium" | "large" | "xlarge" | string
	limits?: {
		cpu?:    string
		memory?: string
		...
	}
	requests?: {
		cpu?:    string
		memory?: string
		...
	}
	...
}

// Standard resource sizing presets
#ResourcePresets: {
	"nano": {
		requests: { cpu: "100m", memory: "128Mi" }
		limits:   { cpu: "200m", memory: "256Mi" }
	}
	"small": {
		requests: { cpu: "250m", memory: "256Mi" }
		limits:   { cpu: "500m", memory: "512Mi" }
	}
	"medium": {
		requests: { cpu: "500m", memory: "512Mi" }
		limits:   { cpu: "1", memory: "1Gi" }
	}
	"large": {
		requests: { cpu: "1", memory: "1Gi" }
		limits:   { cpu: "2", memory: "2Gi" }
	}
	"xlarge": {
		requests: { cpu: "2", memory: "2Gi" }
		limits:   { cpu: "4", memory: "4Gi" }
	}
}
