# set shell := ["bash", "-cu"]

# FIXME, this is not needed shell is by default, but requested fish shell for longer tasks

root := clean(source_dir() + "/..")
TARGET_DEFAULT := `echo "${TARGET:-cluster-home-mxc}" | sed -E 's/(-mxc)?$/-mxc/'`

# Run CUE schema validation (cue vet) against MXC rules
[group('mxc')]
vet *args="":
    just _vet {{ TARGET_DEFAULT }} {{ args }}

# Validate MXC schemas and export flow. Alias for the full MXC test suite.
[group('mxc')]
validate *args="":
    just test {{ TARGET_DEFAULT }} {{ args }}

# Compile CUE and merge it with legacy cluster-home/vars.yml into target vars.yml
[group('mxc')]
export dest=TARGET_DEFAULT expr="mxc_vars" *args="":
    just _export {{ dest }} {{ expr }} {{ args }}

# Compile and display the fully projected variables of a single application directly to stdout
[group('mxc')]
show app:
	@cd {{ root }}/{{ TARGET_DEFAULT }} && cue export -e "adapters.catalog.output.apps.\"{{ app }}\"" --out yaml 2>/dev/null || (printf "\033[31m❌ Error: Application '{{ app }}' is not defined inside target '{{ TARGET_DEFAULT }}'!\033[0m\n" >&2 && exit 1)

# Compile and display the flat services catalog of all active workloads directly to stdout
[group('mxc')]
show-catalog:
	@cd {{ root }}/{{ TARGET_DEFAULT }} && cue export -e "adapters.catalog.output.services" --out yaml

# List all active services configured across the cluster
[group('mxc')]
list:
	@cd {{ root }}/{{ TARGET_DEFAULT }} && cue export -e "adapters.catalog.output.services" --out yaml

# Display a simplified key-value mapping of all active services to their primary DNS/FQDN endpoints
[group('mxc')]
list-services:
	@cd {{ root }}/{{ TARGET_DEFAULT }} && cue export -e "adapters.catalog.output.endpoints" --out yaml

# Compile, export, and preview deployment differences on the cluster (allows extra kluctl args)
[group('mxc-ops')]
diff *args="":
    just _diff {{ args }}

# Compile, export, and apply/deploy configurations to the cluster (uses active KUBECONFIG, allows extra kluctl args)
[group('mxc-ops')]
apply *args="":
    just _apply {{ args }}

# Compile, export, and render offline manifests directly to the build directory (purely offline, does not contact cluster)
[group('mxc-ops')]
build *args="":
    just _build {{ args }}

# Sync CUE packages/libraries (such as mxc-library) via vendir if vendir.yml exists
[group('mxc-ops')]
sync:
    just _sync {{ TARGET_DEFAULT }}

# Internal helper implementations (prefixed with _ for clean encapsulation)
_vet dest *args="":
    (cd {{ root }}/{{ dest }} && cue vet ./... {{ args }})

_export dest expr="mxc_vars" *args="":
    #!/usr/bin/env fish
    echo "▶ Compiling CUE variables for {{ dest }}..."
    cd {{ root }}/{{ dest }}; and cue export -e '{{ expr }}' --out yaml > {{ root }}/{{ dest }}/vars-cue.yml.tmp
    if test "{{ dest }}" = "cluster-home-mxc"; and test -s "{{ root }}/cluster-home/vars.yml"
    	echo "▶ Merging with legacy cluster-home variables..."
    	yq ea 'select(fileIndex == 0) * select(fileIndex == 1)' {{ root }}/cluster-home/vars.yml {{ root }}/{{ dest }}/vars-cue.yml.tmp > {{ root }}/{{ dest }}/vars.yml
    else
    	mv {{ root }}/{{ dest }}/vars-cue.yml.tmp {{ root }}/{{ dest }}/vars.yml
    end
    rm -f {{ root }}/{{ dest }}/vars-cue.yml.tmp

_build *args="":
    #!/usr/bin/env fish
    set -l dest "{{ TARGET_DEFAULT }}"
    set -l kluctl_args

    set -l raw_args (string split -n ' ' -- "{{ args }}")
    if test (count $raw_args) -gt 0
    	if test -d "{{ root }}/$raw_args[1]"
    		set dest $raw_args[1]
    		set kluctl_args $raw_args[2..-1]
    	else
    		set kluctl_args $raw_args
    	end
    end

    set -l build_dir "{{ root }}/.build"
    if set -q BUILD_DIR
    	set build_dir $BUILD_DIR
    end

    just -f {{ root }}/Justfile clean_build
    mkdir -p $build_dir
    just _export $dest
    echo "▶ Rendering offline manifests for $dest into $build_dir..."
    echo "  \$ kluctl render -t $dest --offline-kubernetes --render-output-dir $build_dir $kluctl_args"
    cd {{ root }} && kluctl render -t $dest --offline-kubernetes --render-output-dir $build_dir $kluctl_args

_diff *args="":
    #!/usr/bin/env fish
    set -l dest "{{ TARGET_DEFAULT }}"
    set -l kluctl_args

    set -l raw_args (string split -n ' ' -- "{{ args }}")
    if test (count $raw_args) -gt 0
    	if test -d "{{ root }}/$raw_args[1]"
    		set dest $raw_args[1]
    		set kluctl_args $raw_args[2..-1]
    	else
    		set kluctl_args $raw_args
    	end
    end

    set -l build_dir "{{ root }}/.build"
    if set -q BUILD_DIR
    	set build_dir $BUILD_DIR
    end
    trap "rm -rf $build_dir" EXIT

    just -f {{ root }}/Justfile clean_build
    mkdir -p $build_dir
    just _export $dest

    # Filter out deploy-only/apply-only flags (like --prune, --force-apply) which are not supported by diff
    set -l diff_args
    for arg in $kluctl_args
        if not test "$arg" = "--prune" -o "$arg" = "--force-apply"
            set -a diff_args $arg
        end
    end

    echo "▶ Running Kluctl Diff on $dest..."
    echo "  \$ kluctl diff -t $dest --ignore-kluctl-metadata --replace-on-error --render-output-dir $build_dir $diff_args"
    cd {{ root }} && kluctl diff -t $dest --ignore-kluctl-metadata --replace-on-error --render-output-dir $build_dir $diff_args

_apply *args="":
    #!/usr/bin/env fish
    set -l dest "{{ TARGET_DEFAULT }}"
    set -l kluctl_args

    set -l raw_args (string split -n ' ' -- "{{ args }}")
    if test (count $raw_args) -gt 0
    	if test -d "{{ root }}/$raw_args[1]"
    		set dest $raw_args[1]
    		set kluctl_args $raw_args[2..-1]
    	else
    		set kluctl_args $raw_args
    	end
    end

    set -l build_dir "{{ root }}/.build"
    if set -q BUILD_DIR
    	set build_dir $BUILD_DIR
    end
    trap "rm -rf $build_dir" EXIT

    just -f {{ root }}/Justfile clean_build
    mkdir -p $build_dir
    just _export $dest

    # Separate diff-supported arguments and deployment-specific arguments
    set -l diff_args
    set -l deploy_args
    set -l has_non_interactive 0
    for arg in $kluctl_args
        set -a deploy_args $arg
        if not test "$arg" = "--prune" -o "$arg" = "--force-apply"
            set -a diff_args $arg
        end
        if test "$arg" = "--yes" -o "$arg" = "-y" -o "$arg" = "--dry-run"
            set has_non_interactive 1
        end
    end

    if test $has_non_interactive -eq 1
        echo "▶ Running Kluctl Deploy (non-interactive) on $dest..."
        echo "  \$ kluctl deploy -t $dest --replace-on-error --render-output-dir $build_dir $deploy_args"
        cd {{ root }} && kluctl deploy -t $dest --replace-on-error --render-output-dir $build_dir $deploy_args
    else
        echo "▶ Calculating clean deployment diff for $dest..."
        echo "  \$ kluctl diff -t $dest --ignore-kluctl-metadata --replace-on-error --render-output-dir $build_dir $diff_args"
        cd {{ root }} && kluctl diff -t $dest --ignore-kluctl-metadata --replace-on-error --render-output-dir $build_dir $diff_args
        
        set_color -o yellow
        read -P "❓ Do you want to apply/deploy these changes to $dest? (y/N) " -l confirm
        set_color normal
        
        if test "$confirm" = "y" -o "$confirm" = "Y"
            echo "▶ Executing Kluctl Deploy..."
            echo "  \$ kluctl deploy -t $dest --replace-on-error --render-output-dir $build_dir --yes $deploy_args"
            cd {{ root }} && kluctl deploy -t $dest --replace-on-error --render-output-dir $build_dir --yes $deploy_args
        else
            set_color red
            echo "❌ Deployment canceled."
            set_color normal
            exit 1
        end
    end

_sync dest:
    #!/usr/bin/env fish
    if test -f "{{ root }}/{{ dest }}/vendir.yml"
    	echo "▶ Syncing CUE dependencies for {{ dest }} via vendir..."
    	cd {{ root }}/{{ dest }} && vendir sync
    else
    	echo "ℹ No vendir.yml found in {{ dest }}. Skipping sync."
    end

# Run CUE schema test validations and CI checks for Forgejo / GitHub Actions
[group('mxc')]
test target *args="":
    #!/usr/bin/env fish
    set_color blue
    echo "▶ Starting MXC Validation & CI Test Suite..."
    set_color normal

    # Step 1: Validate Core MXC Schemas
    echo ""
    set_color blue
    echo "▶ [Step 1/3] Checking core CUE schema compilation..."
    set_color normal
    if cue vet {{ root }}/mxc/schema/...
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
    if cue vet -d '#ComposeConfig' {{ root }}/mxc/test/validate_compose.cue {{ root }}/mxc/test/docker-compose.test.yml
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
    if just export > /dev/null
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
    (cd {{ root }}/mxc && cue export ./schema/vars_net.cue --out jsonschema) > {{ root }}/mxc/schema/vars-net.schema.json
    (cd {{ root }}/mxc && cue export ./schema/vars_k8s.cue --out jsonschema) > {{ root }}/mxc/schema/vars-k8s.schema.json
    (cd {{ root }}/mxc && cue export ./schema --out jsonschema -e '#ClusterConfig') > {{ root }}/mxc/schema/mxc-cluster.schema.json
    echo "✓ Successfully exported vars-net.schema.json, vars-k8s.schema.json, and mxc-cluster.schema.json inside mxc/schema/!"

# Export adapter-oriented outputs once the corresponding CUE projections exist.
[group('mxc')]
export-argocd expr="adapters.argocd.output" *args="":
    just _export {{ TARGET_DEFAULT }} {{ expr }} {{ args }}

[group('mxc')]
export-workflows expr="adapters.argoworkflow.output" *args="":
    just _export {{ TARGET_DEFAULT }} {{ expr }} {{ args }}

# Global OCI wrappers. They dispatch artifact-specific tasks so the public
# command surface can stay stable while MXC grows multiple publishable units.
[group('mxc')]
oci-package artifact="library" version="" *args="":
    just _oci-package {{ artifact }} {{ version }} {{ args }}

[group('mxc')]
oci-publish artifact="library" version="" *args="":
    just _oci-publish {{ artifact }} {{ version }} {{ args }}

_oci-package artifact version="" *args="":
    #!/usr/bin/env bash
    case "{{ artifact }}" in \
      library) \
        cd "{{ root }}/mxc-library" && cue mod tidy && cue fmt ./... && cue vet ./... ;; \
      *) \
        echo "Unsupported OCI artifact: {{ artifact }}" >&2; exit 1 ;; \
    esac

_oci-publish artifact version="" *args="":
    #!/usr/bin/env bash
    case "{{ artifact }}" in \
      library) \
        cd "{{ root }}/mxc-library" && cue mod tidy && cue fmt ./... && cue vet ./... && cue mod publish {{ version }} {{ args }} ;; \
      *) \
        echo "Unsupported OCI artifact: {{ artifact }}" >&2; exit 1 ;; \
    esac
