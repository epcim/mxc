# 📦 Standalone Cluster Example (`cluster-standalone`)

This directory represents a **pure, zero-external-dependency** cluster example called **`cluster-standalone`**.

It demonstrates how to configure and deploy application models utilizing the **Model-X Configuration (MXC)** compiler **entirely without importing external libraries** (like `mxc-library`).

---

## 🏛️ Pure Standalone Architecture

In standard setups, users import reusable container templates and stacks from an external repository (e.g. `github.com/epcim/mxc-library`). 

However, MXC's design is fully modular and supports several architecture configurations:
1. **Zero External Libraries (Standalone - This Example)**:
   * All applications are defined directly inside the environment's CUE files on top of the core `#AppCore` schema from `github.com/epcim/mxc/schema:schema`.
   * Deployment targets local CUE and Kluctl adapters built directly into the core `mxc` compiler package (`github.com/epcim/mxc/adapters/kluctl:kluctl`).
2. **Multiple External Libraries (Mix-and-Match)**:
   * Users can import and mix multiple corporate or community stack libraries.
   * For example, you can register `github.com/epcim/mxc-library` for system infrastructure, and a custom library like `github.com/my-org/mxc-custom-stacks` for internal proprietary workloads, importing both under separate package domains inside `cue.mod/pkg/`!

---

## ⚡ Key Commands

All operations are managed via the platform-integrated `just` task runner at the repository root:

### 1. Validate Schemas & Types
Type check and validate structural constraints:
```bash
just mxc::vet mxc/examples/cluster-standalone
```

### 2. Compile & Export Flat Variables (`vars.yml`)
Compile high-level standalone CUE models, project them through local adapters, and output a completely resolved `vars.yml`:
```bash
just mxc::export mxc/examples/cluster-standalone
```
This instantly generates `mxc/examples/cluster-standalone/vars.yml`, ready to be parsed by Kluctl!
