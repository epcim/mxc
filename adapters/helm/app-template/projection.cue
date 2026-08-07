// vim: set ts=2 sw=2 et :
// bjw-s-labs app-template adapter projection — see README.md for upstream repo/version details
package app_template

import (
	"github.com/epcim/mxc/schema:schema"
)

// Helper to project an abstract AppCore definition to standard bjw-s app-template values format
#Projection: {
	appSpec:      schema.#AppCore
	cluster:      schema.#ClusterConfig

	let domain = cluster.network.domain
	let ingressClass = cluster.kube.ingress.class
	let _ingressAnnotations = [if cluster.kube.ingress.annotations != _|_ { cluster.kube.ingress.annotations }, {}][0]

	// Safely resolve optional ports with a concrete empty struct fallback
	let portsVal = (appSpec & { ports: {} }).ports
	let portsList = [for k, v in portsVal { k }]
	let hasPorts = len(portsList) > 0

	// Safely resolve optional expose block
	let exposeVal = (appSpec & { expose: {} }).expose

	// The generated bjw-s app-template values structure
	output: {
		// 1. Generate standard app-template controllers & containers structure
		controllers: {
			main: {
				containers: {
					main: {
						if appSpec.image != _|_ {
							image: {
								repository: appSpec.image.repository
								tag:        appSpec.image.tag
							}
						}
						if hasPorts {
							ports: [
								for k, v in portsVal {
									{
										name:          k
										containerPort: v.port
										protocol:      v.protocol
									}
								}
							]
						}
					}
				}
			}
		}

		// 2. Generate services if ports are defined and non-empty
		if hasPorts {
			service: {
				main: {
					controller: "main"
					ports: {
						for k, v in portsVal {
							"\(k)": {
								port: v.port
							}
						}
					}
				}
			}
		}
		if !hasPorts {
			service: {
				main: {
					enabled: false
				}
			}
		}

		// 3. Generate ingress configuration if ports are defined and non-empty
		if hasPorts {
			ingress: {
				for k, v in exposeVal if v.target == "ingress" {
					"\(k)": {
						enabled: true
						let classVal = [if v.ingressClass != "" { v.ingressClass }, ingressClass][0]
						className: classVal
						let defaultFqdn = "\(appSpec.appName).\(domain)"
						let fqdn = [
							if v.fqdn != _|_ { v.fqdn },
							if v.fqdn == _|_ { defaultFqdn }
						][0]
						hosts: [{
							host: fqdn
							paths: [{
								path: "/"
								service: {
									identifier: "main"
									port:       k
								}
							}]
						}]
						tls: [{
							hosts: [fqdn]
						}]
						let mergedAnnotations = {
							for _k, _val in _ingressAnnotations {
								if v.annotations == _|_ || v.annotations[_k] == _|_ {
									"\(_k)": _val
								}
							}
							if v.annotations != _|_ {
								for _k, _val in v.annotations {
									"\(_k)": _val
								}
							}
						}
						if len(mergedAnnotations) > 0 { annotations: mergedAnnotations }
					}
				}
			}
		}

		// 4. Merge any user-specified context/values overrides
		if appSpec.values != _|_ { appSpec.values }
		if appSpec.values == _|_ && appSpec.context != _|_ { appSpec.context }
	}
}
