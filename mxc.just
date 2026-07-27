set shell := ["bash", "-cu"]
root := source_dir() + "/.."
TARGET_DEFAULT := env("MXC_TARGET", "cluster-home-mxc")

# Run CUE schema validation (cue vet) against MXC rules
[group('mxc')]
vet dest=TARGET_DEFAULT *args="":
	just mxc::_vet \
		{{ if path_exists(root + "/" + dest) == "true" { dest } else { TARGET_DEFAULT } }} \
		{{ if path_exists(root + "/" + dest) == "true" { args } else { trim(dest + " " + args) } }}

# Compile CUE and merge it with legacy cluster-home/vars.yml into target vars.yml
[group('mxc')]
export dest=TARGET_DEFAULT expr="mxc_vars" *args="":
	just mxc::_export \
		{{ if path_exists(root + "/" + dest) == "true" { dest } else { TARGET_DEFAULT } }} \
		{{ if path_exists(root + "/" + dest) == "true" { expr } else { dest           } }} \
		{{ if path_exists(root + "/" + dest) == "true" { args } else { trim(expr + " " + args) } }}

# Compile, export, and preview deployment differences on the cluster (allows extra kluctl args)
[group('mxc')]
diff dest=TARGET_DEFAULT *args="":
	just mxc::_diff \
		{{ if path_exists(root + "/" + dest) == "true" { dest } else { TARGET_DEFAULT } }} \
		{{ if path_exists(root + "/" + dest) == "true" { args } else { trim(dest + " " + args) } }}

# Compile, export, and apply/deploy configurations to the cluster (uses active KUBECONFIG, allows extra kluctl args)
[group('mxc')]
apply dest=TARGET_DEFAULT *args="":
	just mxc::_apply \
		{{ if path_exists(root + "/" + dest) == "true" { dest } else { TARGET_DEFAULT } }} \
		{{ if path_exists(root + "/" + dest) == "true" { args } else { trim(dest + " " + args) } }}


# Internal helper implementations (prefixed with _ for clean encapsulation)
_vet dest *args="":
	(cd {{root}}/{{dest}} && cue vet ./... {{args}})

_export dest expr="mxc_vars" *args="":
	#!/usr/bin/env fish
	echo "▶ Compiling CUE variables for {{dest}}..."
	cd {{root}}/{{dest}}; and cue export -e '{{expr}}' --out yaml > {{root}}/{{dest}}/vars-cue.yml.tmp
	if test -f "{{root}}/cluster-home/vars.yml"
		echo "▶ Merging with legacy cluster-home variables..."
		yq ea 'select(fileIndex == 0) * select(fileIndex == 1)' {{root}}/cluster-home/vars.yml {{root}}/{{dest}}/vars-cue.yml.tmp > {{root}}/{{dest}}/vars.yml
	else
		mv {{root}}/{{dest}}/vars-cue.yml.tmp {{root}}/{{dest}}/vars.yml
	end
	rm -f {{root}}/{{dest}}/vars-cue.yml.tmp

_diff dest *args="":
	just mxc::_export {{dest}}
	echo "▶ Running Kluctl Diff on {{dest}}..."
	cd {{root}} && kluctl diff -t {{dest}} --ignore-kluctl-metadata --replace-on-error {{args}}

_apply dest *args="":
	just mxc::_export {{dest}}
	echo "▶ Running Kluctl Deploy on {{dest}}..."
	cd {{root}} && kluctl deploy -t {{dest}} --replace-on-error {{args}}


# Run CUE schema test validations and CI checks for Forgejo / GitHub Actions
[group('mxc')]
test target=TARGET_DEFAULT *args="":
	#!/usr/bin/env fish
	set_color blue
	echo "▶ Starting MXC Validation & CI Test Suite..."
	set_color normal

	# Step 1: Validate Core MXC Schemas
	echo ""
	set_color blue
	echo "▶ [Step 1/3] Checking core CUE schema compilation..."
	set_color normal
	if cue vet {{root}}/mxc/schema/...
		set_color green
		echo "✓ Core CUE schemas compiled successfully."
		set_color normal
	else
		set_color red
		echo "✗ Error: Core CUE schema compilation failed."
		set_color normal
		exit 1
	end

	# Step 2: Validate Curated Docker Compose Schema
	echo ""
	set_color blue
	echo "▶ [Step 2/3] Validating Docker Compose configuration against cue.dev/x/ curated registry..."
	set_color normal
	if cue vet -d '#ComposeConfig' {{root}}/mxc/test/validate_compose.cue {{root}}/mxc/test/docker-compose.test.yml
		set_color green
		echo "✓ Docker Compose configuration is 100% valid."
		set_color normal
	else
		set_color red
		echo "✗ Error: Docker Compose configuration failed schema validation."
		set_color normal
		exit 1
	end

	# Step 3: Verify Environmental Export Compilation
	echo ""
	set_color blue
	echo "▶ [Step 3/3] Testing parameters compilation & export (vars.yml)..."
	set_color normal
	if just mxc::export {{target}} > /dev/null
		set_color green
		echo "✓ Environment parameters exported successfully."
		set_color normal
	else
		set_color red
		echo "✗ Error: Environment parameter compilation failed."
		set_color normal
		exit 1
	end

	echo ""
	set_color -o green
	echo "🎉 SUCCESS: All Model-X Configuration (MXC) validations passed perfectly!"
	set_color normal


# Export custom CUE schemas to standard JSON Schema files for editor integration (YAML/JSON LS)
[group('mxc')]
schema-export:
	#!/usr/bin/env bash
	echo "▶ Exporting custom CUE schemas to JSON Schema..."
	(cd {{root}}/mxc && cue export ./schema/vars_net.cue --out jsonschema) > {{root}}/mxc/schema/vars-net.schema.json
	(cd {{root}}/mxc && cue export ./schema/vars_k8s.cue --out jsonschema) > {{root}}/mxc/schema/vars-k8s.schema.json
	(cd {{root}}/mxc && cue export ./schema --out jsonschema -e '#ClusterConfig') > {{root}}/mxc/schema/mxc-cluster.schema.json
	echo "✓ Successfully exported vars-net.schema.json, vars-k8s.schema.json, and mxc-cluster.schema.json inside mxc/schema/!"



