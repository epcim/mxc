package test

import (
	schema "github.com/epcim/mxc/schema"
)

_kafkaSpec: schema.#AppMxc & {
	appName: "kafka"
	adapter: "kluctl"
	ports: {}
	expose: {}
}

topologyFixture: schema.#Topology & {
	apiVersion: "topology.mxc.cue/v1alpha1"
	kind:       "Topology"
	name:       "global-infra"
	platform: {
		env: {
			GLOBAL_VAR: "true"
		}
	}
	location: {
		cloud: {
			name: "cloud-providers"
			location: {
				"aws-us-east-2": {
					name: "aws-region-ohio"
					cluster: {
						gc01: {
							clusterName: "gc01"
							environment: "production"
							network: {
								domain: "ohio.aws.apealive.net"
								vips: {}
							}
							apps: {
								data: {
									"kafka-01": _kafkaSpec & {
										appName: "kafka"
									}
								}
							}
						}
					}
				}
			}
		}
		edge: {
			name: "edge-sites"
			location: {
				"site-prague": {
					cluster: {
						edge01: {
							clusterName: "edge01"
							environment: "production"
							network: {
								domain: "edge01.prg.apealive.net"
								vips: {}
							}
							apps: {
								iot: {
									esphome: schema.#App & {
										appName: "esphome"
										adapter: "helm"
									}
								}
							}
						}
					}
				}
			}
		}
	}
}

adapterIdentityFixture: {
	simple: schema.#BaseAppAdapter & {
		spec:    _kafkaSpec
		cluster: topologyFixture.location.cloud.location["aws-us-east-2"].cluster.gc01
	}
	customized: schema.#BaseAppAdapter & {
		name:         "kafka-custom"
		instanceName: "kafka-shard-0"
		spec:         _kafkaSpec
		cluster:      topologyFixture.location.cloud.location["aws-us-east-2"].cluster.gc01
	}
}
