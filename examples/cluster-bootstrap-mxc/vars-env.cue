package mxc

cluster: {
	clusterName: "bootstrap-cluster"
	environment: "development"

	kube: {
		type: "kwok"
		storage: {
			default: "local-path"
		}
		ingress: {
			class: "traefik"
		}
		namespaces: [
			"kube-system",
			"infra",
			"media",
		]
	}
}
