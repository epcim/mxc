# Publishing MXC as a CUE OCI Module

MXC publishes the CUE module `github.com/epcim/mxc` to
`ghcr.io/epcim/mxc`. GitHub remains the source repository; GHCR is the
versioned distribution channel consumed by CUE.

## Prerequisites

1. Create a GitHub Personal Access Token owned by a user with package-write
   access to the `epcim` namespace.
2. Grant the token `read:packages` and `write:packages`. Add `repo` only when
   required for private repositories or packages.
3. Do not store the token in `.env`, `.envrc`, Git, or command history.
4. Install `cue`, `just`, `jq`, and Docker.

The repository `.envrc` supplies the non-secret default:

```bash
GHCR_USER=epcim
```

Export the token only in the current shell:

```bash
export GHCR_PAT='<github-personal-access-token>'
```

Confirm configuration without printing the token:

```bash
just ghcr-status
```

## Prepare the Release

CUE modules with `source: kind: "git"` can only be published from a clean Git
worktree. Commit and push the intended release before packaging:

```bash
git status --short
git add -A
git commit -m 'feat: add multi-cluster deployment model'
git push origin main
```

Review the commit before publishing. A published semantic version should be
treated as immutable.

## Validate and Package

Run the complete core validation and OCI dry run:

```bash
just test-alpha
just oci-package core v0.1.0
```

The dry run resolves the module to:

```text
github.com/epcim/mxc@v0.1.0
ghcr.io/epcim/mxc:v0.1.0
```

It does not write to GHCR.

## Publish Locally

The publish recipe refuses to continue when `GHCR_PAT` is absent. It performs
the Docker login internally using `GHCR_USER` and `GHCR_PAT`:

```bash
just oci-publish core v0.1.0
```

After the first publication, open the package settings on GitHub and set the
package visibility to public when anonymous consumption is required.

On shared machines, remove the stored Docker credential afterward:

```bash
docker logout ghcr.io
```

## Publish with GitHub Actions

1. Open the repository settings on GitHub.
2. Add an Actions secret named `GHCR_PAT`.
3. Ensure the token owner matches `GHCR_USER` and can publish packages under
   `epcim`.
4. Run the `Publish MXC OCI Module` workflow.
5. Enter `v0.1.0` as the workflow version.

The workflow intentionally uses `secrets.GHCR_PAT`; it does not use
`secrets.GITHUB_TOKEN`.

## Verify from a Clean Consumer

Create a new CUE module outside this repository and use the same registry
mapping:

```bash
mkdir /tmp/mxc-consumer
cd /tmp/mxc-consumer
cue mod init example.local/mxc-consumer
export CUE_REGISTRY='file:/path/to/mxc/cue.mod/registry.cue'
cue mod get github.com/epcim/mxc@v0.1.0
```

Create a CUE file importing the published schema:

```cue
package consumer

import schema "github.com/epcim/mxc/schema:schema"

app: schema.#AppCore & {
	appName:    "example"
	deployment: "kluctl"
	ports:      {}
	expose:     {}
}
```

Then validate:

```bash
cue mod tidy
cue vet ./...
```

Only after this clean-consumer check should downstream modules pin
`github.com/epcim/mxc@v0.1.0`.
