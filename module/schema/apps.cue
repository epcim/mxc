// vim: set ts=2 sw=2 et :
package schema

import (
	"github.com/epcim/mxc/schema/external:external"
	"github.com/epcim/mxc/schema/mxc:mxc"
)

#SchemaRef: string | [...string]

// #App is the ultra-minimal universal specification for an application workload.
// It defines core identity, rendering adapter selection, and parameters.
#App: {
	appName: string

	// Open rendering adapter selector (defaults to "kluctl")
	adapter: *"kluctl" | string

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

	// Target platform adaptation requirements and bindings
	platform?: #Platform

	// Logical tags for stack/feature grouping and cascading
	tags?: [...string]

	...
}

// #AppMxc is the official container intent contract, unifying #App with
// container lifecycle, networking, storage, secrets, and deployment escapes.
#AppMxc: #App & {
	adapter: *"kluctl" | string

	image?:   mxc.#ImageSpec
	ports?:   mxc.#PortsSpec
	expose?:  mxc.#ExposeSpec
	storage?: mxc.#StorageSpec
	secrets?: mxc.#SecretsSpec

	// Dynamic kustomize context mappings matching full upstream schemas (auto-bridged to platform.k8s.kustomize)
	kustomize?: external.#Kustomization

	// Escape hatch for Mirantis K0rdent service configurations (auto-bridged to platform.k0rdent)
	k0rdent?: {
		serviceSpec?: {
			[string]: _
		}
		template?: string
		values?: {
			[string]: _
		}
	}

	// Automatic bridging to canonical platform scopes
	if kustomize != _|_ {
		platform: k8s: kustomize: kustomize
	}
	if k0rdent != _|_ {
		platform: k0rdent: k0rdent
	}

	// Application-specific templates or custom overlays configuration
	overlays?: {
		[string]: _
	}

	// Extensible helm chart properties for native helm deployments
	helmChart?: external.#HelmChartSpec

	...
}

// Re-export resource specifications from mxc facet
#ResourcesSpec:   mxc.#ResourcesSpec
#ResourcePresets: mxc.#ResourcePresets

// Backward compatibility aliases
#AppSimple: #AppMxc
#AppCore:   #AppMxc
