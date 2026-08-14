// Kubernetes Cluster Configuration
//
// Kubernetes platform configuration for cluster
package schema

@jsonschema(schema="http://json-schema.org/draft-07/schema#")
@jsonschema(id="https://raw.githubusercontent.com/epcim/mxc/main/docs/generated-schema/vars-k8s.schema.json")
kube?: {
	// Kubernetes distribution type
	type!: "microk8s" | "k3s" | "talos" | "eks" | "gke" | "aks" | "kind" | "kwok"
	networking?: {
		pod_cidr?:         =~"^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+/[0-9]+$"
		service_cidr?:     =~"^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+/[0-9]+$"
		policy_namespace?: string
		...
	}
	storage!: {
		// Default storage class
		default!: string

		// Performance storage class
		performance?: string

		// Backup storage class
		backup?: string

		// Local storage class
		local?: string
		...
	}
	ingress!: {
		// Default ingress class
		class!: string
		annotations?: [string]: string
		...
	}

	// Namespaces to create
	namespaces?: [...string]
	env?: {
		// Timezone
		TZ?: string
		...
	}
	...
}
...
