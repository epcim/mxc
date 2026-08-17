package test

import (
	schema "github.com/epcim/mxc/schema:schema"
	k8s "github.com/epcim/mxc/schema/mxc_k8s:mxc_k8s"
)

// Test 1: Ultra-minimal #App (e.g. for native Helm charts)
testMinimalApp: schema.#App & {
	appName: "traefik-native"
	adapter: "kluctl"
	values: {
		additionalArguments: ["--api.insecure=true"]
	}
}

// Test 2: Standard Container #AppMxc
testContainerApp: schema.#AppMxc & {
	appName: "web-portal"
	adapter: "kluctl"
	image: {
		repository:  "nginx"
		tag:         "1.27"
		pullPolicy:  "Always"
		pullSecrets: ["regcred"]
	}
	ports: http: port: 80
	expose: http: {
		target:       "ingress"
		ingressClass: "traefik"
	}
	storage: data: {
		size:  "10Gi"
		class: "longhorn"
	}
}

// Test 3: Composed Cluster Definition
testComposedCluster: schema.#Cluster &
	schema.#WithKube &
	schema.#WithNetwork &
	schema.#WithApps & {
	clusterName: "test-cluster"
	environment: "staging"
	kube: {
		type: "talos"
		storage: default: "longhorn"
		ingress: class:   "traefik"
	}
	network: {
		domain: "example.internal"
		vips: k8s_api: address: "10.0.0.1"
	}
	apps: infra: web: testContainerApp
}

// Test 4: Custom Extension on #AppMxc with open tails
testExtendedApp: schema.#AppMxc & {
	appName: "ai-inference"
	adapter: "kluctl"
	image: repository: "vllm/vllm-openai"
	// Custom extended fields allowed by open struct tails
	gpu: {
		vendor: "nvidia"
		count:  2
	}
	customMonitoring: {
		metricsPath: "/metrics"
		scrape:      true
	}
}
