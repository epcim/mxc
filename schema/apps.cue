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

	// Extensible helm-values context block passed direct to template/kluctl
	context?: {
		[string]: _
	}

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

	// Simplified Resources and Sizing Flavors
	replicaCount?: int
	flavor?:       string

	// Explicitly define the packaging/deployment format of this application
	deployment?: "bjw-s" | "app-template" | "kluctl" | "kustomize" | "k0rdent"
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
