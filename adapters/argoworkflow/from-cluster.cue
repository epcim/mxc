// vim: set ts=2 sw=2 et :
package argoworkflow

import (
	alpha  "github.com/epcim/mxc/schema/alpha:alpha"
	"github.com/epcim/mxc/schema:schema"
)

#FromCluster: {
	input: schema.#ClusterConfig

	let deploy = alpha.#DeployAlpha & {
		targets: {}
	} & [if input.deployAlpha != _|_ { input.deployAlpha }, {}][0]
	output: {
		workflowTemplates: {
			for targetName, target in deploy.targets if target.enabled != false {
				let instances = [if target.instances != _|_ { target.instances }, {}][0]
				"\(targetName)": schema.#WorkflowTemplate & {
					metadata: {
						name:      "\(input.clusterName)-\(targetName)"
						namespace: "argo"
					}
					spec: {
						entrypoint: "deploy"
							templates: [
								{
									name: "deploy"
									dag: tasks: [
										for instanceName, instance in instances if instance.enabled != false {
											name:     instanceName
											template: "apply-stack"
										if instance.dependsOn != _|_ {
											dependencies: [for dep in instance.dependsOn if dep.kind == "instance" || dep.kind == "stack" { dep.name }]
										}
										arguments: parameters: [
											{name: "stack", value: instance.stack},
											{name: "target", value: targetName},
										]
									}
								]
							},
							{
								name: "apply-stack"
								container: {
									image:   "ghcr.io/epcim/mxc-runner:latest"
									command: ["sh", "-c"]
									args:    ["just mxc::export >/dev/null"]
								}
							},
						]
					}
				}
			}
		}
	}
}
