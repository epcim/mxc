# 🏡 Cluster Homelab Example (`cluster-homelab`)

This directory represents a fully-featured, type-safe, and completely functional cluster example called **`cluster-homelab`** driving deployment logic via **Model-X Configuration (MXC)**.

It replaces the legacy and overly simplified `cluster-bootstrap-mxc` with a highly realistic showcase of real-world patterns, featuring **4 applications** organized cleanly across **2 parent categories**.

---

## 🏛️ Application Architecture & Sizing

This example manages the following workloads:
1. **`infra` Category**:
   * **`metallb`**: Standard bare-metal load balancer setup with L2 advertisement address pools.
   * **`traefik`**: Modular reverse proxy/ingress controller utilizing custom ports and persistence bindings.
2. **`home` Category**:
   * **`homarr`**: Sleek home dashboard/portal with declarative DNS exposure (`homarr.homelab.lan`).
3. **`media` Category**:
   * **`silo`**: Media server/container workload utilizing dynamic volume claims.

All configurations are statically typed, closed against key typos via CUE schemas, and completely decoupled from absolute environmental paths or SOPS decryption overhead, making this target instantly testable in CI/CD.

---

## 🔒 Dependencies & Package Sync Workflow

MXC configurations depend on the upstream `mxc-library` platform schemas. This example supports both local workspace and remote offline workflows:

### Option A: Local Workspace Monorepo (Default)
When checking out this repo inside the `gitops-infra` monorepo, dependencies are mapped cleanly using static Git-tracked symlinks under `cue.mod/pkg/`:
* `cue.mod/pkg/github.com/epcim/mxc` -> Symlinked to `./mxc/module/`
* `cue.mod/pkg/github.com/epcim/mxc-library` -> Symlinked to `./mxc-library/module/`

This allows zero-network editing and rapid iteration with no installation overhead!

### Option B: Standalone / External / CI/CD Sync (Vendir)
If running this example in a standalone `mxc` repository context or in a CI agent where `mxc-library` is not physically present in the workspace, use Carvel `vendir` to fetch the schemas dynamically.

#### 🔱 Flexible Git Referencing
`vendir.yml` supports any stable Git reference under the `git.ref` configuration key:
* **By Branch** (e.g. tracks standard development):
  ```yaml
  git:
    url: https://github.com/epcim/mxc-library.git
    ref: main  # or dev, features, etc.
  ```
* **By Semantic Version / Tag** (Recommended for stability):
  ```yaml
  git:
    url: https://github.com/epcim/mxc-library.git
    ref: v1.0.0
  ```
* **By Commit SHA** (Extremely secure / immutable):
  ```yaml
  git:
    url: https://github.com/epcim/mxc-library.git
    ref: d2e1e36c572a11b6...
  ```

#### ⚡ Execution & Sync
1. Ensure `vendir` is installed (`brew install vendir` or similar).
2. Sync the dependencies into your local tree:
   ```bash
   vendir sync
   ```
This pulls the configured reference of `mxc-library` from GitHub directly into `cue.mod/pkg/github.com/epcim/mxc-library` on-demand.

#### ⚖️ Operational Impact
* **🟢 Positive Impact (Reproducible & Offline-ready)**:
  1. **Deterministic Builds**: Pinning a specific Git `ref` (such as a tag or commit SHA) ensures your configurations compile identically across any developer laptop or headless CI system.
  2. **Air-gapped Friendly**: Once `vendir sync` has run, CUE compile and validation commands require **zero internet connectivity**, resolving everything strictly offline.
  3. **No Container Registries Required**: Provides standard schema distribution without requiring OCI registry hosting or access tokens.
* **🟡 Trade-offs / Maintenance**:
  1. **Manual Synchronization**: When external schema files inside `mxc-library` are updated upstream, developers must manually run `vendir sync` again to retrieve changes.
  2. **File Footprint**: Fetches the external files physically into your filesystem (which are automatically ignored from Git via `.gitignore` under `cue.mod/pkg/`).

### Option C: Native OCI Package Import (Future Architecture Target)
As the project scales, the legacy `vendir` step can be completely replaced by CUE’s native OCI module distribution system. Under this setup, the compiler fetches external modules on-the-fly from an OCI-compliant registry.

#### 💡 The GHCR Trick (No Extra Registry Needed!)
You do not need to host or manage a separate registry! Every GitHub account/org has **GitHub Container Registry (GHCR)** (`ghcr.io`) enabled out-of-the-box. While famously used for Docker images, GHCR is an OCI-compliant registry that natively stores **CUE modules** as OCI artifacts for free.

#### 1. Publishing a CUE Module to GHCR
To publish your library (e.g. `mxc-library`) as an OCI artifact:
1. Log in to GHCR via Docker CLI:
   ```bash
   echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
   ```
2. Navigate to your library and publish natively:
   ```bash
   cue mod publish v1.0.0
   ```

#### 2. Importing the OCI Module inside your Cluster Config
Once published, users omit `vendir.yml` entirely and reference the registry directly inside their `cue.mod/module.cue` configuration:

```cue
// cue.mod/module.cue
module: "github.com/epcim/gitops-infra/mxc/examples/cluster-homelab"
language: {
	version: "v0.9.0"
}

// Points CUE to the GHCR registry for resolution
customRegistry: {
	namespace: "ghcr.io/epcim"
}

deps: {
	"github.com/epcim/mxc-library@v0": {
		v: "v1.0.0"
	}
}
```

When you run compilation, CUE will **automatically fetch, cache, and resolve** the schema definitions in the background with zero manual synchronization required!

---

## ⚡ Key Commands

All execution operations are managed via the platform-integrated `just` task runner at the repository root:

### 1. Validate Schemas & Types
Run full type checking, key constraint validation, and structural validation:
```bash
just mxc::vet mxc/examples/cluster-homelab
```

### 2. Compile & Export Flat Variables (`vars.yml`)
Compile high-level CUE logical intents, project them through adapters, merge them with static platform specs (`vars-k8s.yml` and `vars-net.yml`), and export the output for Kluctl:
```bash
just mxc::export mxc/examples/cluster-homelab
```
This instantly generates a completely resolved, static `vars.yml` inside this folder, ready to be digested by Kluctl!

---

## 🔬 Testing with Kluctl Dry-Runs

To preview exactly how Kluctl would compile and render the Kubernetes manifests (without connecting to or modifying a real cluster), you can run a dry-run:
```bash
just mxc::diff mxc/examples/cluster-homelab --dry-run
```
