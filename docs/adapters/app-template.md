# `helm/app-template` adapter

Projects an abstract `#AppCore` app definition into
[bjw-s-labs](https://github.com/bjw-s-labs/helm-charts)'s generic **`app-template`** Helm chart
values format — the chart used by every app that doesn't have (or need) its own dedicated
upstream Helm chart.

- **Upstream project**: https://github.com/bjw-s-labs/helm-charts (org renamed from `bjw-s` to
  `bjw-s-labs`; `github.com/bjw-s/helm-charts` still resolves, via redirect, to the same place)
- **Chart repo**: `https://bjw-s-labs.github.io/helm-charts`
- **Chart docs**: https://bjw-s-labs.github.io/helm-charts/docs/app-template/
- **Chart**: `app-template` — "a common powered chart template, useful for small projects that
  don't have their own chart"

## Pinned version

**`4.6.2`**, hardcoded in `mxc/module/adapters/kluctl/projection.cue`'s synthesized `helmChart` block
(`repo`/`chartName`/`chartVersion`) — this is the *only* place the version is set; every app using
this adapter shares it.

The chart repo currently publishes a `5.x` major (`5.0.1` as of this writing) built on a bumped
`common` library. bjw-s-labs publish an upgrade guide for major bumps
(`docs/app-template/upgrades/4-to-5/`) — read it before bumping `chartVersion`, since `4.x` → `5.x`
changes chart-internal structure this adapter's `#Projection` output depends on (e.g. `common`
library conventions for `controllers`/`persistence`). Bumping the version here requires re-checking
every field this adapter emits against the new chart's values schema, not just editing the string.

## How it works

This adapter is selected by `contextSchema: "#app-template"` on an `#AppCore` app (`deployment`
stays `"kluctl"` — see AD-020 in `docs/ARCH_DECISIONS.md`), *not* by a dedicated `deployment` value.
`mxc/module/adapters/kluctl/projection.cue` detects this via its `isAppTemplate` check and, when true:

1. Synthesizes the `helmChart` block above (apps never set their own chart coordinates for this
   case — only native, non-app-template charts set `helmChart` explicitly).
2. Runs this package's `#Projection`, which maps `#AppCore`'s generic, chart-agnostic fields onto
   the shape the `app-template` chart's `values.yaml` expects:
   - `image`, `ports` → `controllers.main.containers.main.{image,ports}`
   - `ports` (non-empty) → `service.main` (a `service.main.enabled: false` stub when there are none)
   - `expose.<port>` where `target == "ingress"` → `ingress.<port>` (host/TLS/annotations, defaulting
     the ingress class and FQDN from cluster-level input when the app didn't set its own)
   - `context` (whatever the app set directly) is merged in last, so any app can still reach chart
     fields this projection doesn't otherwise generate (persistence, probes, resources, etc.)
3. The kluctl adapter then merges this output with any `reloader` annotations before handing it to
   Kluctl as the app's Helm values.

There is no captured/vendored JSON schema for `app-template`'s own values yet — `contextSchema:
"#app-template"` is currently a forward-reference to this adapter's contract, pending the
vendor/validate pipeline described in `AGENTS-TODO.md`.

## Placement

This adapter lives under `mxc/module/adapters/` only — it is a core, generic projection every standalone
`mxc` + cluster config can render without depending on `mxc-library` (see `mxc/AGENTS.md` §10.6,
"Independence of Core Adapters"). Application-*specific* content (per-app overlays, stack
definitions that use this adapter via `contextSchema: "#app-template"`) belongs in `mxc-library`,
but the adapter/projection code itself does not move there.
