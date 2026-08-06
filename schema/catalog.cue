// vim: set ts=2 sw=2 et :
package schema

// #CRDSource describes an upstream Kubernetes CRD whose OpenAPI schema is vendored into
// schema/<outputDir>/ as a generated JSON Schema + default CR skeleton. Consumed by
// `just schema fetch-crd` (just/schema.just), which drives the generic fetch+generate
// pipeline off this list instead of hardcoding any one CRD's name.
//
// Kind/group/version are deliberately NOT declared here -- the fetch pipeline reads them
// straight out of the fetched CRD's own `.spec.names.kind`/`.spec.group`/`.spec.versions[0].name`,
// so a catalog entry only needs to say where the CRD comes from and where its output lands.
#SchemaSource: {
	type:      "json-schema" | "helm-values-schema" | "openapi"
	name:      string          // informational identifier
	repo:      string          // GitHub "owner/repo" the schema is fetched from
	ref:       string | *"main" // pinned branch/tag -- bump deliberately when re-vendoring, see AD-021
	path:      string          // path to the schema within repo
	outputDir: string          // repo-root-relative dir the schema lands in
}

#CRDSource: {
	type:      *"crd" | string
	name:      string          // informational identifier + raw CRD YAML filename stem
	repo:      string          // GitHub "owner/repo" the CRD YAML is fetched from
	ref:       string | *"main" // pinned branch/tag -- bump deliberately when re-vendoring, see AD-021
	path:      string          // path to the CRD YAML within repo
	outputDir: string          // repo-root-relative dir the CRD yaml + generated schema/defaults land in
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

