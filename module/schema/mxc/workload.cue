// vim: set ts=2 sw=2 et :
package mxc

import (
	"github.com/epcim/mxc/schema/external"
)

// #ImageSpec defines high-level container image coordinates and pull settings.
#ImageSpec: {
	repository:  string
	tag?:        string | *"latest"
	digest?:     string
	pullPolicy?: "Always" | "IfNotPresent" | "Never"
	pullSecrets?: [...string]
	...
}

// #PortsSpec maps service port names to network port definitions.
#PortsSpec: [string]: external.#PortSpec & {
	port: *8080 | int
	...
}

// #ExposeSpec defines ingress and external routing intents.
#ExposeSpec: [PortName=string]: {
	target:        "ingress" | "loadbalancer" | "internal" | "none" | *"none"
	ingressClass?: string | *"" // Automatically resolved by compiler if empty
	fqdn?:         string       // Automatically resolved by compiler if empty
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
		requests: {cpu: "100m", memory: "128Mi"}
		limits: {cpu: "200m", memory: "256Mi"}
	}
	"small": {
		requests: {cpu: "250m", memory: "256Mi"}
		limits: {cpu: "500m", memory: "512Mi"}
	}
	"medium": {
		requests: {cpu: "500m", memory: "512Mi"}
		limits: {cpu: "1", memory: "1Gi"}
	}
	"large": {
		requests: {cpu: "1", memory: "1Gi"}
		limits: {cpu: "2", memory: "2Gi"}
	}
	"xlarge": {
		requests: {cpu: "2", memory: "2Gi"}
		limits: {cpu: "4", memory: "4Gi"}
	}
}

// #AppContainer defines MXC container lifecycle, storage, expose, and platform escape extensions.
#AppContainer: {
	image?:    #ImageSpec
	ports?:    #PortsSpec
	expose?:   #ExposeSpec
	storage?:  #StorageSpec
	secrets?:  #SecretsSpec
	platform?: #PlatformMxc

	// Dynamic kustomize context mappings matching full upstream schemas (auto-bridged to platform.k8s.kustomize)
	kustomize?: external.#Kustomization

	// Escape hatch for Mirantis K0rdent service configurations (auto-bridged to platform.k0rdent)
	k0rdent?: {
		serviceSpec?: {
			[string]: _
		}
		template?: string
		values?: {
			[string]: _
		}
	}

	// Automatic bridging to canonical platform scopes
	if kustomize != _|_ {
		platform: k8s: kustomize: kustomize
	}
	if k0rdent != _|_ {
		platform: k0rdent: k0rdent
	}

	// Application-specific templates or custom overlays configuration
	overlays?: {
		[string]: _
	}

	// Extensible helm chart properties for native helm deployments
	helmChart?: external.#HelmChartSpec

	...
}
