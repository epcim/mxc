// vim: set ts=2 sw=2 et :
package catalog

import (
	"github.com/epcim/mxc/schema:schema"
)

#FromCluster: {
	input: schema.#ClusterConfig

	output: {
		// Flat, queryable service catalog listing all workloads configured across the cluster
		services: [
			for catKey, catApps in input.apps
			for appKey, appSpec in catApps {
				name:        appSpec.appName
				category:    catKey
				deployment:  appSpec.deployment
				image:       [if appSpec.image != _|_ { appSpec.image }, null][0]
				
				// Auto-generate live URLs for any ingress-exposed ports
				endpoints: [
					for portKey, exposeSpec in appSpec.expose
					if exposeSpec.target == "ingress" {
						name: portKey
						url:  "https://" + [if exposeSpec.fqdn != _|_ { exposeSpec.fqdn }, appSpec.appName + "." + input.network.domain][0]
					}
				]
			}
		]

		// Simplified flat mapping of service names directly to their primary resolved FQDN
		endpoints: {
			for catKey, catApps in input.apps
			for appKey, appSpec in catApps {
				let ingressPorts = [
					for portKey, exposeSpec in appSpec.expose
					if exposeSpec.target == "ingress" {
						[if exposeSpec.fqdn != _|_ { exposeSpec.fqdn }, appSpec.appName + "." + input.network.domain][0]
					}
				]
				if len(ingressPorts) > 0 {
					"\(appSpec.appName)": "https://" + ingressPorts[0]
				}
			}
		}

		// Flat mapping of every application name directly to its compiled specification
		apps: {
			for catKey, catApps in input.apps
			for appKey, appSpec in catApps {
				"\(appSpec.appName)": appSpec
			}
		}
	}
}
