// vim: set ts=2 sw=2 et :
// Note: This fixtures file is used to simplify the main projection.cue file by extracting
// complex template default coordinates, storage overlays, and polymorphic values mappings.
// Using a separate fixtures file is completely optional; all definitions unify into #AppAdapter.
package kluctl

import (
	"github.com/epcim/mxc/adapters/helm/app-template:app_template"
)

// #AppAdapter extensions for storage, Helm chart defaults, and polymorphic values context mappings.
#AppAdapter: S={
	spec:         _
	domain:       _
	ingressClass: _
	annotations?: [string]: string

	let _isAppTemplate = len([for s in [if (S.spec.valuesSchema & string) != _|_ { [S.spec.valuesSchema] }, if (S.spec.valuesSchema & [...string]) != _|_ { S.spec.valuesSchema }, []][0] if s == "#app-template" {s}]) > 0

	// Polymorphic unification: if app-template is selected, unify with its own schema extension.
	if _isAppTemplate {
		S & app_template.#KluctlExtension
	}



	// Generic fallback parameters for other non-app-template applications.
	if !_isAppTemplate {
		output: {
			if S.spec.helmChart != _|_ {
				helmChart: S.spec.helmChart
			}
			if S.spec.storage != _|_ {
				volumes: {
					for k, v in S.spec.storage {
						"\(k)": {
							enabled: true
							type:    "persistentVolumeClaim"
							global:  "\(S.spec.appName)-\(k)"
						}
					}
				}
				overlays: pvc: [
					for k, v in S.spec.storage {
						name:         "\(S.spec.appName)-\(k)"
						size:         v.size
						storageClass: v.class
					}
				]
			}
			context: [
				if S.spec.values != _|_ { S.spec.values },
				{}
			][0]
			...
		}
	}
}
