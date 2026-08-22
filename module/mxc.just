set quiet := true

root := env_var_or_default("GIT_ROOT", `git rev-parse --show-toplevel 2>/dev/null || pwd`)
BUILD_DIR := env('BUILD_DIR', root + "/.build")
TARGET := env('MXC_TARGET', env('TARGET', '.'))
GHCR_USER := env('GHCR_USER', '')
_module_dir := if path_exists(root + "/module/cue.mod") == "true" { root + "/module" } else { source_dir() }
_registry_config := "file:" + root + "/registry.cue"

# Format all CUE files in repository / target
[group('mxc')]
fmt path="":
    #!/usr/bin/env bash
    target="${1:-.}"
    echo "▶ Formatting CUE files in $target..."
    find "$target" -name "*.cue" -not -path '*/.git/*' -not -path '*/cue.mod/pkg/*' -exec cue fmt {} +
    echo "✓ CUE files formatted."

# Run CUE schema validation (cue vet) against MXC rules
[group('mxc')]
[no-cd]
vet *args="":
    just -q mxc::_vet {{ TARGET }} {{ args }}

# Validate MXC schemas and export flow. Alias for the full MXC test suite.
[group('mxc')]
[no-cd]
validate *args="":
    just -q mxc::test {{ TARGET }} {{ args }}

# ============================================================================
# STAGE 1: EXPORT & MODEL COMPILATION
# ============================================================================

# Internal export helper to write vars.yml
[no-cd]
_export dest=TARGET expr="mxc_vars" *args="":
    #!/usr/bin/env fish
    mkdir -p {{ BUILD_DIR }}/{{ dest }}
    cue -C {{ dest }} export -e '{{ expr }}' --out yaml > {{ BUILD_DIR }}/{{ dest }}/vars.yml
    cp {{ BUILD_DIR }}/{{ dest }}/vars.yml {{ dest }}/vars.yml

# Export CUE parameters or evaluate expressions to stdout (or vars.yml)
[group('mxc')]
[no-cd]
export *args="":
    #!/usr/bin/env fish
    set -l raw_args (string split -n ' ' -- "{{ args }}")
    set -l dest "{{ TARGET }}"
    set -l expr ""
    argparse --ignore-unknown 't/include-tag=+' 'exclude-tag=+' 'd/dest=' 'e/expr=' -- $raw_args 2>/dev/null
    if set -q _flag_d
        set dest $_flag_d
    end
    if set -q _flag_e
        set expr $_flag_e
    else if test (count $argv) -ge 2
        set dest $argv[1]
        set expr $argv[2]
    else if test (count $argv) -eq 1
        if test -d "$argv[1]" -o -d "{{ root }}/$argv[1]"
            set dest $argv[1]
        else
            set expr $argv[1]
        end
    end

    # Single app tag export shortcut to stdout
    if set -q _flag_t; and test (count $_flag_t) -eq 1; and test -z "$expr"
        cue -C $dest export -e "adapters.catalog.apps.\"$_flag_t[1]\"" --out yaml
        exit 0
    end

    # Specific expression export to stdout
    if test -n "$expr"
        cue -C $dest export -e "$expr" --out yaml
        exit 0
    end

    # Default full export to vars.yml and print to stdout
    just -q mxc::_export $dest "mxc_vars"
    cat $dest/vars.yml

# Compile and display the fully projected variables of a single application directly to stdout
[group('mxc')]
[no-cd]
show app dest=TARGET:
    @cue -C {{ dest }} export -e "adapters.catalog.apps.\"{{ app }}\"" --out yaml 2>/dev/null || (printf "\033[31m❌ Error: Application '{{ app }}' is not defined inside target '{{ dest }}'!\033[0m\n" >&2 && exit 1)

# Compile and display the flat services catalog of all active workloads directly to stdout
[group('mxc')]
[no-cd]
show-catalog dest=TARGET:
    @cue -C {{ dest }} export -e "adapters.catalog.services" --out yaml

# List all active services configured across the cluster
[group('mxc')]
[no-cd]
list dest=TARGET:
    @cue -C {{ dest }} export -e "adapters.catalog.services" --out yaml

# Display a simplified key-value mapping of all active services to their primary DNS/FQDN endpoints
[group('mxc')]
[no-cd]
list-services dest=TARGET:
    @cue -C {{ dest }} export -e "adapters.catalog.endpoints" --out yaml

# ============================================================================
# STAGE 2: BUILD (OFFLINE MANIFEST RENDERING)
# ============================================================================

# Build manifests using Kluctl engine
[group('mxc-adapters')]
[no-cd]
build-kluctl dest=TARGET *args="":
    #!/usr/bin/env fish
    mkdir -p {{ BUILD_DIR }}
    set -l raw_args (string split -n ' ' -- "{{ args }}")
    argparse --ignore-unknown 't/include-tag=+' 'exclude-tag=+' 'd/dest=' -- $raw_args 2>/dev/null
    set -l kluctl_args
    for t in $_flag_t
        set -a kluctl_args "--include-tag" $t
    end
    for e in $_flag_exclude_tag
        set -a kluctl_args "--exclude-tag" $e
    end
    for extra in $argv
        set -a kluctl_args $extra
    end
    kluctl render -t {{ dest }} --offline-kubernetes --render-output-dir {{ BUILD_DIR }} $kluctl_args

# Build manifests using Kustomize adapter
[group('mxc-adapters')]
[no-cd]
@build-kustomize app dest=TARGET:
    rm -rf {{ BUILD_DIR }}/kustomize/{{ app }}
    mkdir -p {{ BUILD_DIR }}/kustomize/{{ app }}
    cue -C {{ dest }} export -e "adapters.kustomize.output.apps.\"{{ app }}\".kustomize" --out yaml > {{ BUILD_DIR }}/kustomize/{{ app }}/kustomization.yaml 2>/dev/null || true
    cue -C {{ dest }} export -e "adapters.kustomize.output.apps.\"{{ app }}\".overlays" --out yaml > {{ BUILD_DIR }}/kustomize/{{ app }}/mxc-overlays.yaml 2>/dev/null || true

# Build values using Helm adapter
[group('mxc-adapters')]
[no-cd]
@build-helm app dest=TARGET:
    rm -rf {{ BUILD_DIR }}/helm/{{ app }}
    mkdir -p {{ BUILD_DIR }}/helm/{{ app }}
    cue -C {{ dest }} export -e "adapters.helm.output.apps.\"{{ app }}\"" --out yaml > {{ BUILD_DIR }}/helm/{{ app }}/app.yaml
    cue -C {{ dest }} export -e "adapters.helm.output.apps.\"{{ app }}\".values" --out yaml > {{ BUILD_DIR }}/helm/{{ app }}/values.yaml 2>/dev/null || true

# High-level build dispatcher
[group('mxc-ops')]
[no-cd]
build *args="":
    #!/usr/bin/env fish
    set -l raw_args (string split -n ' ' -- "{{ args }}")
    set -l dest "{{ TARGET }}"
    set -l extra_tags
    argparse --ignore-unknown 't/include-tag=+' 'exclude-tag=+' 'd/dest=' -- $raw_args 2>/dev/null
    if set -q _flag_d
        set dest $_flag_d
    end
    for pos in $argv
        if test -d "$pos" -o -d "{{ root }}/$pos"
            set dest $pos
        else if not string match -q -- "-*" "$pos"
            # Extract app name if passed as cluster.apps.name or apps.name or name
            set -l app_tag (string replace -r '^.*apps\.' '' "$pos")
            set -a extra_tags $app_tag
        end
    end
    set -l all_tags $_flag_t $extra_tags

    just -q mxc::_export $dest

    # Dispatch to specific adapter for single-app tag if configured
    if test (count $all_tags) -eq 1
        set -l app $all_tags[1]
        set -l adp (cue -C $dest export -e "adapters.catalog.apps.\"$app\".adapter" --out json 2>/dev/null | yq '. | if type == "array" then .[0] else . end' 2>/dev/null)
        switch "$adp"
            case kustomize
                just -q mxc::build-kustomize $app $dest
                exit 0
            case helm
                just -q mxc::build-helm $app $dest
                exit 0
        end
    end

    set -l pass_args
    for t in $all_tags
        set -a pass_args "-t" $t
    end
    for e in $_flag_exclude_tag
        set -a pass_args "--exclude-tag" $e
    end
    just -q mxc::build-kluctl $dest $pass_args

# ============================================================================
# STAGE 3: DIFF (PREVIEW CHANGES)
# ============================================================================

# Diff manifests using Kluctl engine (encapsulates Kluctl-specific flag filtering)
[group('mxc-adapters')]
[no-cd]
diff-kluctl dest=TARGET *args="":
    #!/usr/bin/env fish
    mkdir -p {{ BUILD_DIR }}
    set -l raw_args (string split -n ' ' -- "{{ args }}")
    argparse --ignore-unknown 't/include-tag=+' 'exclude-tag=+' 'd/dest=' 'y/yes' 'dry-run' -- $raw_args 2>/dev/null
    set -l kluctl_args
    for t in $_flag_t
        set -a kluctl_args "--include-tag" $t
    end
    for e in $_flag_exclude_tag
        set -a kluctl_args "--exclude-tag" $e
    end
    for extra in $argv
        if not test "$extra" = "--prune" -o "$extra" = "--force-apply"
            set -a kluctl_args $extra
        end
    end
    kluctl diff -t {{ dest }} --ignore-kluctl-metadata --replace-on-error --render-output-dir {{ BUILD_DIR }} $kluctl_args

# Diff manifests using Kustomize adapter
[group('mxc-adapters')]
[no-cd]
@diff-kustomize app dest=TARGET: (build-kustomize app dest)
    kubectl diff -k {{ BUILD_DIR }}/kustomize/{{ app }}

# Diff values using Helm adapter
[group('mxc-adapters')]
[no-cd]
@diff-helm app dest=TARGET: (build-helm app dest)
    helm diff upgrade $(yq '.helmChart | [(.releaseName // "'{{ app }}'"), (.repo + ("/" + .chartName // "")), "--version", .chartVersion, "--namespace", (.namespace // "default")] | join(" ")' {{ BUILD_DIR }}/helm/{{ app }}/app.yaml) $([ -s {{ BUILD_DIR }}/helm/{{ app }}/values.yaml ] && echo "-f {{ BUILD_DIR }}/helm/{{ app }}/values.yaml")

# High-level diff dispatcher
[group('mxc-ops')]
[no-cd]
diff *args="":
    #!/usr/bin/env fish
    set -l raw_args (string split -n ' ' -- "{{ args }}")
    set -l dest "{{ TARGET }}"
    set -l extra_tags
    argparse --ignore-unknown 't/include-tag=+' 'exclude-tag=+' 'd/dest=' 'y/yes' 'dry-run' 'i/interactive' -- $raw_args 2>/dev/null
    if set -q _flag_d
        set dest $_flag_d
    end
    for pos in $argv
        if test -d "$pos" -o -d "{{ root }}/$pos"
            set dest $pos
        else if not string match -q -- "-*" "$pos"
            # Extract app name if passed as cluster.apps.name or apps.name or name
            set -l app_tag (string replace -r '^.*apps\.' '' "$pos")
            set -a extra_tags $app_tag
        end
    end
    set -l all_tags $_flag_t $extra_tags

    just -q mxc::_export $dest

    # Dispatch to specific adapter for single-app tag if configured
    if test (count $all_tags) -eq 1
        set -l app $all_tags[1]
        set -l adp (cue -C $dest export -e "adapters.catalog.apps.\"$app\".adapter" --out json 2>/dev/null | yq '. | if type == "array" then .[0] else . end' 2>/dev/null)
        switch "$adp"
            case kustomize
                just -q mxc::diff-kustomize $app $dest
                exit 0
            case helm
                just -q mxc::diff-helm $app $dest
                exit 0
        end
    end

    set -l pass_args
    for t in $all_tags
        set -a pass_args "-t" $t
    end
    for e in $_flag_exclude_tag
        set -a pass_args "--exclude-tag" $e
    end
    if set -q _flag_dry_run
        set -a pass_args "--dry-run"
    end
    just -q mxc::diff-kluctl $dest $pass_args

# ============================================================================
# STAGE 4: RUN (ENVIRONMENT EXECUTION)
# ============================================================================

# Run manifests using Kluctl engine
[group('mxc-adapters')]
[no-cd]
run-kluctl dest=TARGET *args="":
    #!/usr/bin/env fish
    mkdir -p {{ BUILD_DIR }}
    set -l raw_args (string split -n ' ' -- "{{ args }}")
    argparse --ignore-unknown 't/include-tag=+' 'exclude-tag=+' 'd/dest=' 'y/yes' 'dry-run' -- $raw_args 2>/dev/null
    set -l kluctl_args
    for t in $_flag_t
        set -a kluctl_args "--include-tag" $t
    end
    for e in $_flag_exclude_tag
        set -a kluctl_args "--exclude-tag" $e
    end
    if set -q _flag_y
        set -a kluctl_args "--yes"
    end
    if set -q _flag_dry_run
        set -a kluctl_args "--dry-run"
    end
    for extra in $argv
        set -a kluctl_args $extra
    end
    kluctl deploy -t {{ dest }} --replace-on-error --render-output-dir {{ BUILD_DIR }} $kluctl_args

# Run manifests using Kustomize adapter
[group('mxc-adapters')]
[no-cd]
@run-kustomize app dest=TARGET: (build-kustomize app dest)
    kubectl apply -k {{ BUILD_DIR }}/kustomize/{{ app }}

# Run values using Helm adapter
[group('mxc-adapters')]
[no-cd]
@run-helm app dest=TARGET: (build-helm app dest)
    helm upgrade --install $(yq '.helmChart | [(.releaseName // "'{{ app }}'"), (.repo + ("/" + .chartName // "")), "--version", .chartVersion, "--namespace", (.namespace // "default"), "--create-namespace"] | join(" ")' {{ BUILD_DIR }}/helm/{{ app }}/app.yaml) $([ -s {{ BUILD_DIR }}/helm/{{ app }}/values.yaml ] && echo "-f {{ BUILD_DIR }}/helm/{{ app }}/values.yaml")

# Adapter alias for backwards compatibility
[no-cd]
@deploy-kluctl dest=TARGET *args="":
    just -q mxc::run-kluctl {{ dest }} {{ args }}

# High-level run dispatcher
[group('mxc-ops')]
[no-cd]
run *args="":
    #!/usr/bin/env fish
    set -l raw_args (string split -n ' ' -- "{{ args }}")
    set -l dest "{{ TARGET }}"
    set -l extra_tags
    argparse --ignore-unknown 't/include-tag=+' 'exclude-tag=+' 'd/dest=' 'y/yes' 'dry-run' 'i/interactive' -- $raw_args 2>/dev/null
    if set -q _flag_d
        set dest $_flag_d
    end
    for pos in $argv
        if test -d "$pos" -o -d "{{ root }}/$pos"
            set dest $pos
        else if not string match -q -- "-*" "$pos"
            # Extract app name if passed as cluster.apps.name or apps.name or name
            set -l app_tag (string replace -r '^.*apps\.' '' "$pos")
            set -a extra_tags $app_tag
        end
    end
    set -l all_tags $_flag_t $extra_tags

    just -q mxc::_export $dest

    # Dispatch to specific adapter for single-app tag if configured
    if test (count $all_tags) -eq 1
        set -l app $all_tags[1]
        set -l adp (cue -C $dest export -e "adapters.catalog.apps.\"$app\".adapter" --out json 2>/dev/null | yq '. | if type == "array" then .[0] else . end' 2>/dev/null)
        switch "$adp"
            case kustomize
                just -q mxc::run-kustomize $app $dest
                exit 0
            case helm
                just -q mxc::run-helm $app $dest
                exit 0
        end
    end

    set -l pass_args
    for t in $all_tags
        set -a pass_args "-t" $t
    end
    for e in $_flag_exclude_tag
        set -a pass_args "--exclude-tag" $e
    end
    if set -q _flag_y
        set -a pass_args "--yes"
    end
    if set -q _flag_dry_run
        set -a pass_args "--dry-run"
    end
    just -q mxc::run-kluctl $dest $pass_args

# High-level aliases for run
[group('mxc-ops')]
[no-cd]
@deploy *args="":
    just -q mxc::run {{ args }}

[group('mxc-ops')]
[no-cd]
@apply *args="":
    just -q mxc::run {{ args }}

# Sync CUE packages/libraries (such as mxc-library) via vendir if vendir.yml exists
[group('mxc-ops')]
sync dest=TARGET:
    #!/usr/bin/env fish
    if test -f "{{ root }}/{{ dest }}/vendir.yml"
        echo "▶ Syncing CUE dependencies for {{ dest }} via vendir..."
        cd {{ root }}/{{ dest }} && vendir sync
    else
        echo "ℹ No vendir.yml found in {{ dest }}. Skipping sync."
    end

# Vendor/copy local mxc module into dependent packages (cluster-home-mxc, mxc-library) if present
[group('mxc')]
[no-cd]
vendor-upstream-copy:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "▶ Syncing mxc module into dependent local packages..."
    if [[ -d "{{ root }}/cluster-home-mxc" ]]; then
        mkdir -p "{{ root }}/cluster-home-mxc/cue.mod/pkg/github.com/epcim/mxc"
        rsync -a --delete --exclude='.git*' "{{ _module_dir }}/" "{{ root }}/cluster-home-mxc/cue.mod/pkg/github.com/epcim/mxc/"
    fi
    if [[ -d "{{ root }}/mxc-library" ]]; then
        mkdir -p "{{ root }}/mxc-library/cue.mod/pkg/github.com/epcim/mxc"
        rsync -a --delete --exclude='.git*' "{{ _module_dir }}/" "{{ root }}/mxc-library/cue.mod/pkg/github.com/epcim/mxc/"
    fi
    echo "✓ Synced mxc module successfully."

# Alias for vendor-upstream-copy
[group('mxc')]
vendor-sync: vendor-upstream-copy

[no-cd]
_vet dest=TARGET *args="":
    cue -C {{ dest }} vet ./... {{ args }}

# Run CUE schema test validations and CI checks for Forgejo / GitHub Actions
[group('mxc')]
[no-cd]
test-alpha:
    #!/usr/bin/env bash
    set -euo pipefail
    (cd {{ _module_dir }} && cue vet ./schema/...)
    (cd {{ root }}/test && cue vet ./...)
    (cd {{ root }}/test && cue export ./topology_alpha.cue -e alphaMultiClusterFixture --out json) | jq -e '.clusters.gc01.cluster.clusterName == "gc01" and .deploy.instances["kafka-gc"].appInstance == "kafka-gc" and (.deploy.instances["kafka-ce"].placement.clusters | length) == 2' >/dev/null
    (cd {{ root }}/test && cue export ./topology_alpha.cue -e adapterIdentityFixture --out json) | jq -e '.simple.appInstance == "kafka" and .deployed.appInstance == "kafka-gc" and .customized.appInstance == "kafka-shard-0"' >/dev/null
    if (cd {{ root }}/test && cue eval ./topology_alpha.cue -e 'alphaMultiClusterFixture & {deploy: instances: invalid: {app: _kafkaSpec, placement: clusters: []}}') >/dev/null 2>&1; then
        echo "Empty placement unexpectedly accepted" >&2
        exit 1
    fi
    if (cd {{ root }}/test && cue eval ./topology_alpha.cue -e 'alphaMultiClusterFixture & {deploy: instances: "kafka-gc": instanceName: ""}') >/dev/null 2>&1; then
        echo "Empty instance name unexpectedly accepted" >&2
        exit 1
    fi
    (cd {{ root }}/test && cue eval ./topology_alpha.cue -e 'alphaMultiClusterFixture & {deploy: instances: extra: {app: _kafkaSpec, placement: clusters: ["gc01"]}}') >/dev/null

[group('mxc')]
[no-cd]
test target=TARGET *args="":
    #!/usr/bin/env fish
    set_color blue
    echo "▶ Starting MXC Validation & CI Test Suite..."
    set_color normal

    # Step 1: Validate Core MXC Schemas
    echo ""
    set_color blue
    echo "▶ [Step 1/3] Checking core CUE schema compilation..."
    set_color normal
    pushd {{ _module_dir }}
    and cue vet ./schema/...
    and popd
    if test $status -eq 0
    	set_color green
    	echo "✓ Core CUE schemas compiled successfully."
    	set_color normal
    else
    	set_color red
    	echo "✗ Error: Core CUE schema compilation failed."
    	set_color normal
    	exit 1
    end
    just mxc::test-alpha

    # Step 2: Validate Curated Docker Compose Schema
    echo ""
    set_color blue
    echo "▶ [Step 2/3] Validating Docker Compose configuration against cue.dev/x/ curated registry..."
    set_color normal
    pushd {{ root }}/test
    and cue vet -d '#ComposeConfig' ./validate_compose.cue ./docker-compose.test.yml
    and popd
    if test $status -eq 0
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
    just mxc::_export {{ target }} > /dev/null
    if test $status -eq 0
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

# Synchronize custom CUE schemas to JSON Schema and harvest upstream application valuesSchema definitions
[group('mxc')]
[no-cd]
schema-sync target=TARGET:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "▶ Exporting custom CUE schemas to JSON Schema..."
    mkdir -p {{ root }}/docs/generated-schema/apps
    (cd {{ _module_dir }} && cue export ./schema -e '#WithNetwork' --out jsonschema) > {{ root }}/docs/generated-schema/vars-net.schema.json
    (cd {{ _module_dir }} && cue export ./schema -e '#WithKube' --out jsonschema) > {{ root }}/docs/generated-schema/vars-k8s.schema.json
    (cd {{ _module_dir }} && cue export ./schema -e '#Platform' --out jsonschema) > {{ root }}/docs/generated-schema/platform.schema.json
    (cd {{ _module_dir }} && cue export ./schema --out jsonschema -e '#ClusterConfig') > {{ root }}/docs/generated-schema/mxc-cluster.schema.json
    echo "✓ Exported core JSON schemas into docs/generated-schema/."

    echo "▶ Harvesting application valuesSchema definitions for target {{ target }}..."
    APPS_JSON=$(cd "{{ root }}/{{ target }}" && cue export -e "adapters.catalog.services" --out json 2>/dev/null || echo "[]")
    echo "$APPS_JSON" | jq -r '.[] | select(.valuesSchema != null) | "\(.name) \(.valuesSchema)"' | while read -r name url; do
        if [[ -n "$name" && -n "$url" ]]; then
            echo "  ↓ Fetching schema for $name from $url..."
            if [[ "$url" =~ ^https?:// ]]; then
                curl -sSL "$url" -o "{{ root }}/docs/generated-schema/apps/${name}.schema.json" || echo "    ⚠️ Warning: Could not download $url"
            elif [[ "$url" =~ ^file:// ]]; then
                cp "${url#file://}" "{{ root }}/docs/generated-schema/apps/${name}.schema.json" 2>/dev/null || true
            fi
        fi
    done
    echo "✓ Completed harvesting values schemas."


# Export adapter-oriented outputs once the corresponding CUE projections exist.
[group('mxc')]
export-argocd dest=TARGET expr="adapters.argocd.output" *args="":
    just _export {{ dest }} {{ expr }} {{ args }}

# Global OCI wrappers. They dispatch artifact-specific tasks so the public
# command surface can stay stable while MXC grows multiple publishable units.
[group('mxc-oci')]
ghcr-status:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "GHCR_USER={{ GHCR_USER }}"
    if [[ -n "${GHCR_PAT:-}" ]]; then
        echo "GHCR_PAT=set"
    else
        echo "GHCR_PAT=unset"
    fi

[group('mxc-oci')]
ghcr-login:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -z "${GHCR_USER:-{{ GHCR_USER }}}" ]]; then
        echo "GHCR_USER is required; set GHCR_USER environment variable" >&2
        exit 1
    fi
    if [[ -z "${GHCR_PAT:-}" ]]; then
        echo "GHCR_PAT is required; refusing GHCR login" >&2
        exit 1
    fi
    user="${GHCR_USER:-{{ GHCR_USER }}}"
    printf '%s' "$GHCR_PAT" | docker login ghcr.io -u "$user" --password-stdin

# Global OCI wrappers
[group('mxc')]
oci-package artifact="mxc" version="" *args="":
    just _oci-package {{ artifact }} {{ version }} {{ args }}

[group('mxc')]
oci-publish artifact="mxc" version="" *args="": ghcr-login
    just _oci-publish {{ artifact }} {{ version }} {{ args }}

[no-cd]
_oci-package artifact version *args="":
    #!/usr/bin/env bash
    set -euo pipefail
    export CUE_REGISTRY='{{ _registry_config }}'
    case "{{ artifact }}" in \
      mxc|core) \
        cd "{{ _module_dir }}" && cue mod tidy --check && cue vet ./schema/... && cue vet ./adapters/... && just mxc::test-alpha && cue mod publish "{{ version }}" --dry-run --json {{ args }} ;; \
      mxc-library|library) \
        cd "${MXC_LIBRARY_DIR:-{{ root }}/../mxc-library/module}" && cue mod tidy --check && cue vet ./... && cue mod publish "{{ version }}" --dry-run --json {{ args }} ;; \
      *) \
        echo "Unknown artifact: {{ artifact }}" >&2; exit 1 ;; \
    esac

[no-cd]
_oci-publish artifact version *args="":
    #!/usr/bin/env bash
    set -euo pipefail
    export CUE_REGISTRY='{{ _registry_config }}'
    case "{{ artifact }}" in \
      mxc|core) \
        cd "{{ _module_dir }}" && cue mod tidy --check && cue vet ./schema/... && cue vet ./adapters/... && just mxc::test-alpha && cue mod publish "{{ version }}" {{ args }} ;; \
      mxc-library|library) \
        cd "${MXC_LIBRARY_DIR:-{{ root }}/../mxc-library/module}" && cue mod tidy --check && cue vet ./... && cue mod publish "{{ version }}" {{ args }} ;; \
      *) \
        echo "Unknown artifact: {{ artifact }}" >&2; exit 1 ;; \
    esac
