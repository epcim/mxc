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
#CRDSource: {
	name:      string          // informational identifier + raw CRD YAML filename stem
	repo:      string          // GitHub "owner/repo" the CRD YAML is fetched from
	ref:       string | *"main" // pinned branch/tag -- bump deliberately when re-vendoring, see AD-021
	path:      string          // path to the CRD YAML within repo
	outputDir: string          // repo-root-relative dir the CRD yaml + generated schema/defaults land in
}

catalog: [...#CRDSource] & [
	{
		name:      "nbsetupkeys"
		repo:      "netbirdio/kubernetes-operator"
		path:      "config/crd/bases/netbird.io_nbsetupkeys.yaml"
		outputDir: "schema/netbird.io"
	},
	{
		name:      "nbroutingpeers"
		repo:      "netbirdio/kubernetes-operator"
		path:      "config/crd/bases/netbird.io_nbroutingpeers.yaml"
		outputDir: "schema/netbird.io"
	},
	{
		name:      "nbresources"
		repo:      "netbirdio/kubernetes-operator"
		path:      "config/crd/bases/netbird.io_nbresources.yaml"
		outputDir: "schema/netbird.io"
	},
	{
		name:      "nbgroups"
		repo:      "netbirdio/kubernetes-operator"
		path:      "config/crd/bases/netbird.io_nbgroups.yaml"
		outputDir: "schema/netbird.io"
	},
	{
		name:      "nbpolicies"
		repo:      "netbirdio/kubernetes-operator"
		path:      "config/crd/bases/netbird.io_nbpolicies.yaml"
		outputDir: "schema/netbird.io"
	},
]
