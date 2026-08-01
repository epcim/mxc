// vim: set ts=2 sw=2 et :
package argocd

import (
	alpha  "github.com/epcim/mxc/schema/alpha:alpha"
	"github.com/epcim/mxc/schema:schema"
	"strings"
)

#FromCluster: {
	input: schema.#ClusterConfig

	let deploy = alpha.#DeployAlpha & {
		targets: {}
	} & [if input.deployAlpha != _|_ { input.deployAlpha }, {}][0]
	output: {
		applicationSets: {
			for targetName, target in deploy.targets if target.enabled != false {
				let instances = [if target.instances != _|_ { target.instances }, {}][0]
				"\(targetName)": schema.#ApplicationSet & {
					metadata: {
						name:      "\(input.clusterName)-\(targetName)"
						namespace: "argocd"
					}
						spec: {
							generators: [{
								list: elements: [
									for instanceName, instance in instances if instance.enabled != false {
										name:      instanceName
										stack:     instance.stack
										namespace: *targetName | string
									cuePath:   "\(input.clusterName)/\(targetName)/\(instanceName)"
									if instance.dependsOn != _|_ {
										dependsOn: strings.Join([for dep in instance.dependsOn { dep.name }], ",")
									}
								}
							]
						}]
						template: {
							metadata: name: "{{name}}"
							spec: {
								project: "default"
								source: {
									repoURL:        "https://example.invalid/mxc.git"
									targetRevision: "HEAD"
									path:           "."
									plugin: {
										name: "mxc-render"
										env: [
											{name: "MXC_STACK", value: "{{stack}}"},
											{name: "MXC_CUE_PATH", value: "{{cuePath}}"},
										]
									}
								}
								destination: {
									server:    "https://kubernetes.default.svc"
									namespace: "{{namespace}}"
								}
							}
						}
					}
				}
			}
		}
	}
}
