// Schema: [apps.cue](../../schema/apps.cue#L4) -> schema.#AppCore
// cue-language-server: $schema=../../schema/mxc-cluster.schema.json
// vim: set ts=2 sw=2 et :
package mxc

import (
	sinf "github.com/epcim/mxc-library/stacks/infra"
)

cluster: apps: infra: {
	metallb: sinf.#MetalLB & {
		context: {
			l2advertisement: {
				"default-l2": {
					ipAddressPools: ["default-pool"]
					interfaces: ["br0"]
				}
			}
			ipaddresspool: {
				"default-pool": ["192.168.1.32/27"]
			}
		}
	}

	traefik: sinf.#Traefik & {
		flavor: "custom"
		kustomize: {
			namespace: "sys"
			resources: [
				"helm-rendered.yaml",
			]
		}
		helmChart: {
			releaseName: "traefik"
		}
		context: {
			fullnameOverride: "traefik"
			globalArguments: [
				"--providers.kubernetesingress.ingressendpoint.ip=\(cluster.network.vips.traefik.address)",
				"--providers.kubernetesingress.ingressClass=traefik",
			]
			service: {
				spec: {
					loadBalancerIP: cluster.network.vips.traefik.address
				}
			}
			persistence: {
				storageClass: cluster.kube.storage.default
			}
		}
	}
}
