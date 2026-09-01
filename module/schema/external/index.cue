// vim: set ts=2 sw=2 et :
// ==============================================================================
// MXC Upstream External Schema & CRD Sources Index
// ==============================================================================
// This file defines the registry of upstream external schemas (CRDs, OpenAPI,
// and JSON Schemas) vendored into MXC for compile-time validation.
// Consumed by `just schema fetch` (just/schema.just).
// ==============================================================================
package external

#SchemaSource: {
	type:      "json-schema" | "helm-values-schema" | "openapi"
	name:      string                                                               // informational identifier
	repo:      string                                                               // GitHub "owner/repo" the schema is fetched from
	ref:       string | *"main"                                                     // pinned branch/tag -- bump deliberately when re-vendoring, see AD-021
	path:      string                                                               // path to the schema within repo
	url:       string | *"https://raw.githubusercontent.com/\(repo)/\(ref)/\(path)" // full upstream source URI
	outputDir: string                                                               // repo-root-relative dir the schema lands in
}

#CRDSource: {
	type:      *"crd" | string
	name:      string                                                               // informational identifier + raw CRD YAML filename stem
	repo:      string                                                               // GitHub "owner/repo" the CRD YAML is fetched from
	ref:       string | *"main"                                                     // pinned branch/tag -- bump deliberately when re-vendoring, see AD-021
	path:      string                                                               // path to the CRD YAML within repo
	url:       string | *"https://raw.githubusercontent.com/\(repo)/\(ref)/\(path)" // full upstream source URI
	outputDir: string                                                               // repo-root-relative dir the CRD yaml + generated schema/defaults land in
}

catalog: [...#CRDSource | #SchemaSource] & [
	{
		type:      "openapi"
		name:      "kustomize"
		repo:      "kubernetes-sigs/kustomize"
		ref:       "kyaml/v0.14.3"
		path:      "api/openapi/openapi.json"
		outputDir: "schema/external"
	},
	{
		type:      "json-schema"
		name:      "app-template"
		repo:      "bjw-s-labs/helm-charts"
		ref:       "main"
		path:      "charts/library/common/values.schema.json"
		outputDir: "schema/external"
	},
]
