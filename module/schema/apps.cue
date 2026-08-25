// vim: set ts=2 sw=2 et :
package schema

import (
	"github.com/epcim/mxc/schema/mxc"
)

#SchemaRef: string | [...string]

// #App is the foundational workload declaration primitive.
// It captures core identity and parameters without container-specific assumptions:
// - appName / appDesc: Core human and machine identity
// - appFqdn: Optional routable DNS identifier (omitted for background/worker workloads)
// - adapter: Declarative deployment/rendering engine selector
// - values / context: Symmetric data payload for teams (supports both naming preferences)
// - flavor: Sizing / resource scaling overrides
// - platform: Target platform runtime constraints and capabilities
// - tags: Selection tags for build, diff, and deployment stages
#App: {
	appName: string

	// Optional human-readable description for catalog and inventory
	appDesc?: string

	// Root FQDN identifier for the application instance (defaults to appName.<cluster.domain> if exposed)
	appFqdn?: string

	// Open rendering adapter selector (single adapter or ordered list of adapters to execute)
	adapter: *"kluctl" | string | [...string]

	// Primary type-safe configuration values surface
	values?: {
		[string]: _
	}

	// Extensible helm-values context block (symmetric alias to values for team flexibility)
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
#AppMxc: #App & mxc.#AppContainer

// Re-export resource specifications from mxc facet
#ResourcesSpec:   mxc.#ResourcesSpec
#ResourcePresets: mxc.#ResourcePresets
