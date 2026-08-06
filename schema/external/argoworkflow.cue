// vim: set ts=2 sw=2 et :
package external

#WorkflowParameter: {
	name:  string
	value: string
}

#WorkflowDagTask: {
	name:         string
	template:     string
	dependencies?: [...string]
	arguments?: {
		parameters?: [...#WorkflowParameter]
	}
}

#WorkflowTemplateSpecTemplate: {
	name: string
	dag?: {
		tasks: [...#WorkflowDagTask]
	}
	container?: {
		image:   string
		command?: [...string]
		args?:    [...string]
	}
}

#WorkflowTemplate: close({
	apiVersion: "argoproj.io/v1alpha1"
	kind:       "WorkflowTemplate"
	metadata:   #ObjectMeta
	spec: {
		entrypoint: string
		templates:  [...#WorkflowTemplateSpecTemplate]
	}
})
