// vim: set ts=2 sw=2 et :
package platforms

import (
	"github.com/epcim/mxc/schema/external:external"
)

// #PlatformK8s defines the Kubernetes container execution environment and capability bindings.
#PlatformK8s: {
	// Target Kubernetes cluster name (for placement and context resolution)
	clusterName?: string

	// Target Pod & Service Kubernetes namespace
	namespace?: string

	// Distribution flavor for platform-specific tweaks (e.g. talos, k3s, eks)
	distribution?: "talos" | "k3s" | "microk8s" | "eks" | "gke" | "kwok" | string | *"k8s"

	// Storage class mappings for abstract storage tiers
	storage?: {
		defaultClass?: string
		classes?: {
			fast?:       string
			replicated?: string
			backup?:     string
			[string]:    string
		}
		...
	}

	// Ingress controller configuration and annotations
	ingress?: {
		provider?:    string
		class?:       string
		annotations?: [string]: string
		...
	}

	// Scoped Kubernetes manifest customization engine
	kustomize?: external.#Kustomization

	// Scoped native Helm chart specification
	helmChart?: external.#HelmChartSpec

	// Runtime pod scheduling & security defaults
	runtime?: {
		nodeSelector?:  [string]: string
		tolerations?:   [...]
		priorityClass?: string
		...
	}

	...
}
