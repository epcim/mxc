# 🎯 Advanced CUE Compiler Authoring & Evaluation Guidelines

This document captures advanced CUE evaluation patterns, compiler constraints, and structural workarounds discovered during the scaling of the Model-X Configuration (MXC) framework.

---

## 1. The Optional Field Evaluation Trap (Open vs. Closed Structs)

In CUE, evaluating conditional assertions (e.g., `if spec.ports != _|_` or `len(spec.ports) > 0`) on an **absent optional field** inside an open struct results in an **incomplete condition** (`_` bottom / incomplete error). 

CUE cannot prove whether the field will be merged or added in a downstream projection layer, so it halts compilation with an incomplete type symbol.

### ❌ The Broken Pattern
Evaluating list lengths or checking absence directly on optional attributes:
```cue
#AppCore: {
    ports?: [string]: #PortSpec
}

// In the projection layer:
let hasPorts = len(appSpec.ports) > 0 // Throws "_" incomplete evaluation if ports is absent!
```

###  The Robust Solution (Structural Pre-Unification)
Before performing any field selections or length operations, **unify the struct with its default concrete empty shape** using a local let variable. This collapses the open-ended index signature into a concrete instance:

```cue
// Force unify ports with an empty map default
let portsVal = (appSpec & { ports: {} }).ports
let portsList = [for k, v in portsVal { k }]
let hasPorts = len(portsList) > 0 // Safely evaluates to true/false without halting!
```

---

## 2. Preventing Leaked Index Signatures (`[string]: _`)

When working with flexible schemas that allow extensible sub-blocks:
```cue
#IPXEBoot: {
    context: service: main: {
        [string]: _ // Extensible index signature
    }
}
```
If you map conditional structures at the root of your adapter's output (e.g., nesting config definitions inside `if hasPorts`), ensure they do not unify incomplete values back up to closed schemas. 

### Best Practice: Conditionally Rendered Root Attributes
To compile cleanly with zero-port applications (like NetBird gateways or isolated tools):
```cue
// inside the adapter/projection.cue:
output: {
    // Render ingress configuration only if ports are active
    if hasPorts {
        ingress: {
            main: { ... }
        }
    }
}
```
This isolates the open conditional structures at the root level of the output map, preventing evaluation crashes from leaking into the parent kluctl deployment model.
