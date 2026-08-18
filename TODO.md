# 📝 MXC Project TODOs: Reshaping & Automating the Projection Layer

This document tracks planned architectural refactors, automations, and enhancements designed to reduce maintenance overhead and make the MXC compilation kernel resilient and self-sustaining without frequent updates.

---

## 🚀 The Core Challenge: High-Frequency Projection Updates

Currently, [`mxc/module/adapters/kluctl/projection.cue`](module/adapters/kluctl/projection.cue) and its child adapters translate abstract workload specifications (`#AppCore`) to target physical charts (like `bjw-s app-template`) using **explicit, hardcoded key-by-key mappings**.

*   **Symptoms**: Adding a new workload capability (e.g., custom annotator, new PVC structure, additional sidecars, or volume mount parameters) requires editing the central `projection.cue` files.
*   **The Goal**: Establish a robust, self-sustaining compiler design where **the adapter layer works without requiring updates for routine configuration adjustments or new app fields**.

---

## 🎯 1. Architectural Reshaping TODOs

### ⬜ Task 1.1: Transition to "Closed Core, Open Seams" Pattern
*   **Concept**: Stop mapping every specific workload property (like `reloader` or `restart`) in the core compiler. Instead, represent workload intents as standard, metadata-annotated metadata blocks, and use a generic, dynamic mapper that maps attributes based on a unified target API structure.
*   **Action Items**:
    1.  Redefine `#AppCore` to utilize generic, recursive pass-through blocks (e.g. `spec`, `metadata`, `values`) that adapters can project dynamically using structural loops rather than explicit variable checks.
    2.  Adopt CUE's list-comprehension iteration to map entire key-value namespaces directly onto the target chart context.

### ⬜ Task 1.2: Decoupled Multi-Cluster Overlay Slices
*   **Concept**: Decouple deployment-specific overlays (like network policies or custom PVC bindings) from the global parameter flattener.
*   **Action Items**:
1.  Shift global overlays compilation out of `projection.cue` into independent CUE overlay generators matching the "Subscriber & Validator" pattern.
2.  Allow apps to declare local, self-contained overlay payloads that are projected directly into output directories, removing the global `overlays` unification bottleneck.

### ⬜ Task 1.3: 2-Week Phased Deprecation Schedule (Target: 2026-09-01)
*   **Concept**: Execute the 3-step phased deprecation roadmap across core compiler schemas, downstream stacks (`mxc-library`), and cluster GitOps targets within a strict 2-week migration window.
*   **3-Step Phased Deprecation Protocol**:
    1.  **Step 1 (Days 1–3, Current): Dual-Representation & Auto-Derivation**:
        - Retain legacy aliases/keys with under-the-hood auto-derivation from the new source of truth.
        - Mark legacy properties with `// TODO: Deprecate by 2026-09-01`.
    2.  **Step 2 (Days 4–10, Week 1): Downstream Migration & Warning Phase**:
        - Migrate all downstream consumers (`mxc-library` stacks, `cluster-home-mxc`, CI/CD workflows) to the new interfaces.
        - Add non-fatal deprecation warnings in compiler export tasks for deprecated fields.
    3.  **Step 3 (Days 11–14, Week 2): Canonical Cutover & Schema Cleanup**:
        - Safely remove auto-derivation bridges, aliases, and deprecated fields from the core schemas.
        - Enforce strict `close()` constraints on clean primitives.

*   **Active Deprecation Targets & Milestones**:

    | Target | Legacy Interface | New Standard | Week 1: Migration (Due Day 7) | Week 2: Cleanup (Due Day 14) |
    |---|---|---|---|---|
    | **1. Export Key** | `mxc_vars` | `adapters.kluctl.output` | Migrate cluster `vars-env.cue` & CI to `adapters.<target>.output` | Remove `mxc_vars` alias; default export to adapter output |
    | **2. Workload Platform Escape Hatches** | Root `kustomize`, `k0rdent`, `helmChart` on `#App` | `platform.k8s.kustomize`, `platform.k0rdent`, `platform.k8s.helmChart` | Migrate `mxc-library` stacks to `platform: { k8s: { ... } }` | Remove root-level bridge from `#AppMxc` |
    | **3. Core App Contract Naming** | `#AppCore`, `#AppSimple` | `#App` (minimal) & `#AppMxc` (container facet) | Update all library stack definitions to `#AppMxc` / `#App` | Remove `#AppCore` backward-compatibility alias |
    | **4. OCI Artifact Identifiers** | `core`, `library` | `mxc`, `mxc-library` | Update all external CI workflows & documentation | Remove `core`/`library` aliases from `mxc.just` |
    | **5. Legacy Facet Imports** | `schema/mxc_k8s`, `schema/mxc_platform` | `schema/mxc` (`package mxc`) | Audit and migrate external imports to `schema/mxc` | Seal `schema/mxc` package layout |

---

## 🤖 2. Automation & Generative Tooling TODOs

### ⬜ Task 2.1: Automated Translation Generation (Code-Gen)
*   **Concept**: Avoid writing manual CUE projection logic. Instead, run code-generation scripts that reflect downstream JSON schemas or Helm chart values definitions to auto-generate mapping layers.
*   **Action Items**:
    1.  Build a Python/Go CLI tool (integrated as a `just` task, e.g., `just mxc::codegen-adapter`) that ingests a target Helm values schema and outputs a complete, type-safe CUE projection file.
    2.  Establish version-controlled schemas of major downstream templates (`bjw-s` v4, v5, etc.) and auto-swap the corresponding mapping adapter.

### ⬜ Task 2.2: Post-Rendering KRM Pipelines (Cuestomize Model)
*   **Concept**: Shift enforcement from pre-compilation graph unification to **post-rendering policy checking**.
*   **Action Items**:
    1.  Implement a lightweight CI verification stage using the KRM transformer model to ingest fully rendered YAML manifests and execute policy checking (`cue vet`) downstream.
    2.  This separates the generation concerns (which can use simple pass-throughs) from validation concerns (which can enforce strict constraints on final flat manifests), preventing compilation latency at scale.
