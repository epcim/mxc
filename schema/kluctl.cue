// vim: set ts=2 sw=2 et :
package schema

// Kluctl Helm Chart specification matching the kluctl schema/structure
#HelmChartSpec: {
	repo?:         string
	chartName?:    string
	chartVersion?: string
	releaseName?:  string
	namespace?:    string
	skipCRDs?:     bool | *false
	skipPrePull?:  bool | *false
}

// Kluctl Deployment Item specification matching the upstream schema
#KluctlDeploymentItem: {
	path?:    string
	include?: string
	tags?: [...string]
	barrier?: bool
	vars?: [...#KluctlVarsSpec]
}

// Kluctl Variables block specification
#KluctlVarsSpec: {
	file?:   string
	values?: {
		[string]: _
	}
}

// Kluctl deployment.yml root specification
#KluctlDeployment: {
	vars?: [...#KluctlVarsSpec]
	deployments?: [...#KluctlDeploymentItem]
}
