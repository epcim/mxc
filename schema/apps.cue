// vim: set ts=2 sw=2 et :
package schema

#AppCore: {
	appName: string
	image?: {
		repository: string
		tag:        string
	}
	
	// Kubernetes Service Spec style ports
	ports: [string]: #PortSpec & {
		port: *8080 | int
	}

	// Declarative Exposure Rules: keys must strictly match keys in 'ports'
	expose: [PortName=string]: {
		let portCheck = ports[PortName]
		if portCheck == _|_ { _|_ }

		target:       "ingress" | "loadbalancer" | "internal" | "none" | *"none"
		ingressClass: string | *"" // Automatically resolved by compiler if empty
		fqdn?:        string       // Automatically resolved by compiler if empty
		annotations?: [string]: string
	}

	// Dynamic kustomize context mappings matching full upstream schemas
	kustomize?: #Kustomization

	// Primary type-safe configuration values surface
	values?: {
		[string]: _
	}

	// Extensible helm-values context block (retained for backward compatibility)
	context?: {
		[string]: _
	}

	// Primary schema reference for values shape
	valuesSchema?: string | [...string]

	// Reference(s) to the values-schema governing `context`'s shape (alias for valuesSchema)
	contextSchema?: valuesSchema

	// Declared secret contract: key names this app expects, defaulting to the
	// established Jinja placeholder convention ("{{ secrets.<app>.<key> }}"),
	// resolved by Kluctl/SOPS at apply-time. A real value may unify this away
	// once resolved by an external decrypt step ahead of compilation — see
	// AGENTS.md "Secrets Resolution Strategy".
	secrets?: [string]: _

	// Escape hatch for Mirantis K0rdent service configurations
	k0rdent?: {
		serviceSpec?: {
			[string]: _
		}
		template?: string
		values?: {
			[string]: _
		}
	}

	// Logical tags for stack/feature grouping and cascading (k8s labels & Kluctl tags)
	tags?: [...string]

	storage?: [string]: #VolumeSpec

	// Application-specific templates or custom overlays configuration
	overlays?: {
		[string]: _
	}

	// Simplified Resources and Sizing Flavors
	replicaCount?: int
	flavor?:       string

	// Explicitly define which adapter renders this app's k8s-appliable manifest
	// set. "app-template" is NOT a deployment value: the generic bjw-s chart is
	// still rendered by kluctl like any other chart — use deployment: "kluctl"
	// with contextSchema: "#app-template" to select it (see AD-020).
	// Required: no safe implicit default exists across adapters, so an omission
	// must fail cue vet.
	deployment: "kluctl" | "kustomize" | "k0rdent" | "argocd"

	// Extensible helm chart properties for native helm deployments
	helmChart?: #HelmChartSpec

	// Optional rollout restart cronjob configuration
	restart?: #RestartSpec
}

#PortSpec: {
	port:     int & >=1 & <=65535
	protocol: "TCP" | "UDP" | *"TCP"
}

#VolumeSpec: {
	size:  string
	class?: string
}

#ResourcesSpec: {
	flavor?: "nano" | "small" | "medium" | "large" | "xlarge"
	limits?: {
		cpu?:    string
		memory?: string
	}
	requests?: {
		cpu?:    string
		memory?: string
	}
}

#ResourcePresets: {
	"nano": {
		requests: { cpu: "100m", memory: "128Mi" }
		limits:   { cpu: "200m", memory: "256Mi" }
	}
	"small": {
		requests: { cpu: "250m", memory: "256Mi" }
		limits:   { cpu: "500m", memory: "512Mi" }
	}
	"medium": {
		requests: { cpu: "500m", memory: "512Mi" }
		limits:   { cpu: "1", memory: "1Gi" }
	}
	"large": {
		requests: { cpu: "1", memory: "1Gi" }
		limits:   { cpu: "2", memory: "2Gi" }
	}
	"xlarge": {
		requests: { cpu: "2", memory: "2Gi" }
		limits:   { cpu: "4", memory: "4Gi" }
	}
}


#RestartSpec: {
	schedule: string
	targetKind: "Deployment" | "StatefulSet" | "DaemonSet" | *"Deployment"
	targetName?: string
}




