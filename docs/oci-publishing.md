# Publishing MXC as a CUE OCI Module

MXC publishes the CUE module `github.com/epcim/mxc` to
`ghcr.io/epcim/mxc`. GitHub remains the source repository; GHCR is the
versioned distribution channel consumed by CUE.

The publishable module root is `module/`. CUE publishes only tracked files
below that directory:

```text
module/cue.mod/module.cue
module/mxc.just
module/schema/**/*.cue
module/adapters/**/*.cue
module/adapters/**/*.yml
module/adapters/**/*.yaml
```

## Prerequisites

1. Create a GitHub Personal Access Token (classic) owned by a user with package
   write access to the `epcim` namespace. GitHub documents classic PATs as the
   supported authentication method for publishing to GHCR.
2. Grant these token scopes:

   | Scope | Requirement | Purpose |
   |---|---|---|
   | `write:packages` | Required | Upload new CUE module versions to GHCR. |
   | `read:packages` | Required | Read package metadata and verify published versions. |
   | `repo` | Only for private repositories/packages | Access packages linked to a private source repository. It is not needed for a public repository and public package. |
   | `delete:packages` | Not required | Needed only to delete package versions; normal publication must not require it. |

3. Do not grant unrelated scopes such as `admin:org`, `workflow`, or
   `delete_repo`.
4. If `epcim` is an organization using SAML SSO, authorize the PAT for that
   organization after creating it.
5. Ensure the token owner has permission to publish packages in `epcim`. The
   GHCR namespace does not have to match the login username, but that user must
   have package-write access to the namespace.
6. Do not store the token in `.env`, `.envrc`, Git, or command history.
7. Install `cue`, `just`, `jq`, and Docker.

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

CUE modules with `source: kind: "git"` can only be published when the tracked
module subtree is clean. Commit and push the intended module changes before
packaging:

```bash
git status --short
git add -A
git commit -m 'feat: add multi-cluster deployment model'
git push origin main
```

Review the commit before publishing. A published semantic version should be
treated as immutable.

Repository-only files outside `module/` are not part of the artifact. Confirm
the module subtree itself is clean with:

```bash
git status --short -- module
```

## Validate and Package

Run the complete module validation and OCI dry run:

```bash
just test-alpha
just oci-package mxc v0.1.0
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
just oci-publish mxc v0.1.0
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
export CUE_REGISTRY='file:/path/to/mxc/registry.cue'
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
