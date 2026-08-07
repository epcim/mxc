// vim: set ts=2 sw=2 et :
package argoworkflow

import (
	alpha  "github.com/epcim/mxc/schema/alpha:alpha"
	"github.com/epcim/mxc/schema:schema"
	"github.com/epcim/mxc/schema/external:external"
)

// #Projection projects a ClusterConfig into flat parameters for ArgoWorkflow.
#Projection: P=schema.#BaseProjection & {

	let deploy = alpha.#DeployAlpha & {
		targets: {}
	} & [if P.cluster.deployAlpha != _|_ { P.cluster.deployAlpha }, {}][0]

	workflowTemplates: {
		for targetName, target in deploy.targets if target.enabled != false {
			let instances = [if target.instances != _|_ { target.instances }, {}][0]
			"\(targetName)": external.#WorkflowTemplate & {
				metadata: {
					name:      "\(P.cluster.clusterName)-\(targetName)"
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

	// Consolidated output block for export tasks
	output: {
		if len(workflowTemplates) > 0 {
			"workflowTemplates": workflowTemplates
		}
	}
}

