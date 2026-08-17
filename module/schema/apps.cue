// vim: set ts=2 sw=2 et :
package schema

import (
	"github.com/epcim/mxc/schema/external:external"
	"github.com/epcim/mxc/schema/mxc_k8s:mxc_k8s"
)

#SchemaRef: string | [...string]

// #App is the ultra-minimal universal specification for an application workload.
// It defines core identity, rendering adapter selection, and parameters.
#App: {
	appName: string

	// Open rendering adapter selector (defaults to "export" for raw value dump)
	adapter: string | *"export"

	// Backward-compatibility alias for legacy 'deployment'
	deployment?: string
	if deployment != _|_ {
		adapter: deployment
	}

	// Primary type-safe configuration values surface
	values?: {
		[string]: _
	}

	// Extensible helm-values context block (retained for backward compatibility)
	context?: {
		[string]: _
	}

	// Primary schema reference for values shape
	valuesSchema?: #SchemaRef

	// Reference(s) to the values-schema governing `context`'s shape (alias for valuesSchema)
	contextSchema?: #SchemaRef

	if context != _|_ {
		values: context
	}
	if contextSchema != _|_ {
		valuesSchema: contextSchema
	}

	// Flavor / sizing tier selector
	flavor?: string

	// Logical tags for stack/feature grouping and cascading
	tags?: [...string]

	...
}

// #AppMxc is the official container intent contract, unifying #App with
// container lifecycle, networking, storage, secrets, and deployment escapes.
#AppMxc: #App & {
	adapter: *"kluctl" | string

	image?:   mxc_k8s.#ImageSpec
	ports?:   mxc_k8s.#PortsSpec
	expose?:  mxc_k8s.#ExposeSpec
	storage?: mxc_k8s.#StorageSpec
	secrets?: mxc_k8s.#SecretsSpec

	// Dynamic kustomize context mappings matching full upstream schemas
	kustomize?: external.#Kustomization

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

	// Application-specific templates or custom overlays configuration
	overlays?: {
		[string]: _
	}

	// Extensible helm chart properties for native helm deployments
	helmChart?: external.#HelmChartSpec

	...
}

// Re-export resource specifications from mxc_k8s facet
#ResourcesSpec:   mxc_k8s.#ResourcesSpec
#ResourcePresets: mxc_k8s.#ResourcePresets

// Backward compatibility aliases
#AppSimple: #AppMxc
#AppCore:   #AppMxc
