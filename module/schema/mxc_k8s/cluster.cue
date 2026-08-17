// vim: set ts=2 sw=2 et :
package mxc_k8s

// #KubeSpec defines Kubernetes platform and cluster runtime configurations.
#KubeSpec: {
	// Kubernetes distribution type
	type: "microk8s" | "k3s" | "talos" | "eks" | "gke" | "aks" | "kind" | "kwok" | string
	storage?: {
		default:      string
		performance?: string
		backup?:      string
		local?:       string
		...
	}
	ingress?: {
		class: string
		annotations?: [string]: string
		...
	}
	namespaces?: [...string]
	env?: {
		TZ?: string
		...
	}
	...
}
