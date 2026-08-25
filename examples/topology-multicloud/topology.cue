// vim: set ts=2 sw=2 et :
package mxc

import (
	"github.com/epcim/mxc/schema"
	adp_kluctl "github.com/epcim/mxc/adapters/kluctl"
	adp_argocd "github.com/epcim/mxc/adapters/argocd"
	adp_catalog "github.com/epcim/mxc/adapters/catalog"
)

// Shared reusable workload templates
_kafkaSpec: schema.#AppMxc & {
	appName: "kafka"
	adapter: "kluctl"
	image: {
		repository: "bitnami/kafka"
		tag:        "3.7.0"
	}
	ports: {
		tcp: port: 9092
	}
	expose: {
		tcp: target: "internal"
	}
}

_esphomeSpec: schema.#AppMxc & {
	appName: "esphome"
	adapter: "kluctl"
	image: {
		repository: "ghcr.io/esphome/esphome"
		tag:        "2024.6.0"
	}
	ports: {
		http: port: 6052
	}
	expose: {
		http: {
			target: "ingress"
		}
	}
}

// ==============================================================================
// Multi-Cluster, Multi-Region Topology Declaration
// ==============================================================================
topology: schema.#Topology & {
	apiVersion: "topology.mxc.cue/v1alpha1"
	kind:       "Topology"
	name:       "enterprise-global"

	// Global platform defaults inherited across all locations
	platform: {
		env: {
			GLOBAL_TIER: "enterprise"
		}
	}

	location: {
		// Public Cloud Locations
		cloud: {
			name: "cloud-providers"
			location: {
				"aws-us-east-2": {
					name: "aws-region-ohio"
					platform: {
						env: {
							CLOUD_PROVIDER: "aws"
							REGION:         "us-east-2"
						}
					}
					cluster: {
						"aws-prod01": schema.#ClusterMxc & {
							clusterName: "aws-prod01"
							environment: "production"
							network: {
								domain: "prod01.ohio.aws.apealive.net"
								vips: {}
							}
							apps: {
								data: {
									kafka: _kafkaSpec
								}
							}
						}
					}
				}
				"gcp-europe-west3": {
					name: "gcp-region-frankfurt"
					platform: {
						env: {
							CLOUD_PROVIDER: "gcp"
							REGION:         "europe-west3"
						}
					}
					cluster: {
						"gcp-prod01": schema.#ClusterMxc & {
							clusterName: "gcp-prod01"
							environment: "production"
							network: {
								domain: "prod01.fra.gcp.apealive.net"
								vips: {}
							}
							apps: {
								data: {
									kafka: _kafkaSpec
								}
							}
						}
					}
				}
			}
		}

		// On-Premise / Edge Locations
		edge: {
			name: "edge-sites"
			location: {
				"site-prague": {
					name: "prague-lab"
					platform: {
						env: {
							EDGE_LOCATION: "prg"
						}
					}
					cluster: {
						"edge-prg01": schema.#ClusterMxc & {
							clusterName: "edge-prg01"
							environment: "production"
							network: {
								domain: "edge01.prg.apealive.net"
								vips: {}
							}
							apps: {
								iot: {
									esphome: _esphomeSpec & {
										expose: http: fqdn: "esphome.\(network.domain)"
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

// ==============================================================================
// Adapter Projections from Topology
// ==============================================================================
// Dynamically binds specific clusters from the topology tree to deployer adapters
adapters: {
	aws_prod01: {
		kluctl: adp_kluctl.#Projection & {
			cluster: topology.location.cloud.location["aws-us-east-2"].cluster["aws-prod01"]
		}
		argocd: adp_argocd.#Projection & {
			cluster: topology.location.cloud.location["aws-us-east-2"].cluster["aws-prod01"]
		}
		catalog: adp_catalog.#Projection & {
			cluster: topology.location.cloud.location["aws-us-east-2"].cluster["aws-prod01"]
		}
	}

	edge_prg01: {
		kluctl: adp_kluctl.#Projection & {
			cluster: topology.location.edge.location["site-prague"].cluster["edge-prg01"]
		}
		catalog: adp_catalog.#Projection & {
			cluster: topology.location.edge.location["site-prague"].cluster["edge-prg01"]
		}
	}
}
