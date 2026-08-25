// vim: set ts=2 sw=2 et :
// Package fn provides reusable CUE helper definitions for safe field extraction,
// attribute navigation, and direct field propagation across MXC adapters and schemas.
package fn

// #Pick extracts specified key(s) from #src and mixes them directly into the target struct.
// Symmetrical with jq / lodash `pick`.
//
// Usage (single key):
//   output: {
//     fn.#Pick & { #src: spec, #key: "helmChart" }
//   }
//
// Usage (multiple keys):
//   output: {
//     fn.#Pick & { #src: spec, #keys: ["helmChart", "kustomize", "secrets"] }
//   }
#Pick: {
	#src:   _
	#key?:  string
	#keys?: string | [...string]

	let _keyList = [
		if #key != _|_ {[#key]},
		if (#keys & string) != _|_ {[#keys]},
		if (#keys & [...string]) != _|_ {#keys},
		[],
	][0]

	for k in _keyList {
		if (#src & {"\(k)": _})[k] != _|_ {
			let _unified = (#src & {"\(k)": _})
			"\(k)": _unified[k]
		}
	}
}

// #Propagate is an alias for #Pick.
#Propagate: #Pick

// #Get safely extracts a field value or returns a fallback default.
//
// Usage:
//   let _storage = fn.#Get & { #in: (spec & {storage: _}).storage, #default: {} }
//   if len(_storage.out) > 0 {
//     ...
//   }
#Get: {
	#in:      _
	#default: _ | *null
	out: [if #in != _|_ { #in }, #default][0]
}

// #GetNamespace resolves the namespace from an application spec with fallback.
// Priority order:
//   1. spec.kustomize.namespace
//   2. spec.namespace
//   3. #default (fallback)
//
// Usage:
//   helmChart: {
//     releaseName: spec.appName
//     namespace: (fn.#GetNamespace & { #spec: spec, #default: spec.appName }).out
//   }
#GetNamespace: {
	#spec:    _
	#default: string | *"default"
	out: [
		if (#spec & {kustomize: namespace: string}).kustomize.namespace != _|_ { (#spec & {kustomize: namespace: string}).kustomize.namespace },
		if (#spec & {namespace: string}).namespace != _|_ { (#spec & {namespace: string}).namespace },
		#default,
	][0]
}
