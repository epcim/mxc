// vim: set ts=2 sw=2 et :
package schema

#ObjectMeta: {
	name:        string
	namespace:   string
	labels?:     [string]: string
	annotations?: [string]: string
}

#ApplicationDestination: {
	server?:    string
	name?:      string
	namespace?: string
}

#ApplicationSourcePluginEnv: {
	name:  string
	value: string
}

#ApplicationSourcePlugin: {
	name: string
	env?:  [...#ApplicationSourcePluginEnv]
}

#ApplicationSource: {
	repoURL:        string
	targetRevision: string
	path:           string
	plugin?:        #ApplicationSourcePlugin
}

#ApplicationSpec: {
	project:     string | *"default"
	source:      #ApplicationSource
	destination: #ApplicationDestination
	syncPolicy?: {
		automated?: {
			prune?:    bool
			selfHeal?: bool
		}
		syncOptions?: [...string]
	}
}

#Application: close({
	apiVersion: "argoproj.io/v1alpha1"
	kind:       "Application"
	metadata:   #ObjectMeta
	spec:       #ApplicationSpec
})

#ApplicationSetGeneratorListElement: {
	name:      string
	stack:     string
	namespace: string
	cuePath:   string
	dependsOn?: string
}

#ApplicationSetGenerator: {
	list?: {
		elements: [...#ApplicationSetGeneratorListElement]
	}
}

#ApplicationSetTemplate: {
	metadata: {
		name: string
	}
	spec: #ApplicationSpec
}

#ApplicationSet: close({
	apiVersion: "argoproj.io/v1alpha1"
	kind:       "ApplicationSet"
	metadata:   #ObjectMeta
	spec: {
		generators: [...#ApplicationSetGenerator]
		template:   #ApplicationSetTemplate
		syncPolicy?: {
			applicationsSync?: string
		}
	}
})
