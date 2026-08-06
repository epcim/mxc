// vim: set ts=2 sw=2 et :
package app_template

import (
	"github.com/epcim/mxc/schema:schema"
)

// Default bjw-s app-template coordinates for Kluctl/Helm deployers
#DefaultChart: {
	chartName:    string | *"app-template"
	repo:         string | *"https://bjw-s-labs.github.io/helm-charts"
	chartVersion: string | *"4.6.2"
	skipCRDs:     bool | *false
	skipPrePull:  bool | *true
	...
}

// App-template storage projection (volumes & persistence definitions)
#Storage: {
	appSpec: schema.#AppCore

	volumes: {
		for k, v in appSpec.storage {
			let isEnabled = [if v.enabled != _|_ { v.enabled }, true][0]
			if isEnabled {
				"\(k)": {
					enabled: true
					type:    "persistentVolumeClaim"
					global:  "\(appSpec.appName)-\(k)"
				}
			}
		}
	}

	persistence: {
		for k, v in appSpec.storage {
			let isEnabled = [if v.enabled != _|_ { v.enabled }, true][0]
			if isEnabled {
				"\(k)": {
					enabled:       true
					existingClaim: "\(appSpec.appName)-\(k)"
					global:        "\(appSpec.appName)-\(k)"
				}
			}
		}
	}
}

// Kluctl adapter extension to populate app-template deployment schemas
#KluctlExtension: {
	spec:         schema.#AppCore
	domain:       string
	ingressClass: string
	output: {
		helmChart: #DefaultChart & {
			releaseName: spec.appName
			if spec.kustomize != _|_ {
				namespace: spec.kustomize.namespace
			}
		}
		if spec.helmChart != _|_ {
			helmChart: spec.helmChart
		}

		if spec.storage != _|_ {
			let _storage = #Storage & { appSpec: spec }
			volumes:     _storage.volumes
			persistence: _storage.persistence
		}

		context: (#Projection & {
			"appSpec":      spec
			"domain":       domain
			"ingressClass": ingressClass
		}).output
	}
}
