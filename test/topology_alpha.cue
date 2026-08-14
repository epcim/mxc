package test

import schema "github.com/epcim/mxc/schema:schema"

_clusterConfig: {
	environment: "development"
	kube: {
		type: "kind"
		storage: default: "standard"
		ingress: class:   "nginx"
	}
	network: {
		vips: {}
		domain: "example.invalid"
	}
	apps: {}
}

_kafkaSpec: schema.#AppCore & {
	appName:    "kafka"
	deployment: "kluctl"
	ports: {}
	expose: {}
}

// One shared CUE app definition backs separate deployment instances, and one
// instance targets multiple named clusters.
alphaMultiClusterFixture: schema.#TopologyAlpha & {
	clusters: {
		gc01: cluster:    _clusterConfig
		"dns-0": cluster: _clusterConfig
		"dns-1": cluster: _clusterConfig
	}

	deploy: instances: {
		"kafka-gc": {
			app: _kafkaSpec
			placement: clusters: ["gc01"]
		}
		"kafka-ce": {
			app: _kafkaSpec
			context: rackAware: true
			placement: clusters: ["dns-0", "dns-1"]
			dependsOn: [{kind: "instance", name: "kafka-gc", cluster: "gc01"}]
		}
	}
}

_kafka: alphaMultiClusterFixture.deploy.instances["kafka-gc"]

adapterIdentityFixture: {
	simple: schema.#BaseAppAdapter & {
		spec:    _kafkaSpec
		cluster: alphaMultiClusterFixture.clusters.gc01.cluster
	}
	deployed: schema.#BaseAppAdapter & {
		name:    _kafka.name
		spec:    _kafka.app
		cluster: alphaMultiClusterFixture.clusters.gc01.cluster
	}
	customized: schema.#BaseAppAdapter & {
		name:         _kafka.name
		instanceName: "kafka-shard-0"
		spec:         _kafka.app
		cluster:      alphaMultiClusterFixture.clusters.gc01.cluster
	}
}
