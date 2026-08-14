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

### ⬜ Task 1.3: Enforce Phased Deprecations for Schema Changes
*   **Concept**: Maintain perfect, 100% backward-compatibility when modifying schema definitions. Rather than making immediate breaking cuts, changes must occur in a phased deprecation pattern to prevent breaking downstream stack repositories or user cluster configs.
*   **Action Items**:
1.  When refactoring fields, retain legacy properties as auto-derived/computed fields unified under-the-hood from the new source of truth.
2.  Annotate deprecated properties clearly with a `// TODO: Deprecate...` statement.
3.  Plan migrations in three steps: (1) schema supports both new and derived old fields, (2) update external repos (`mxc-library`) to use new fields, (3) safely clean up old fields.

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
