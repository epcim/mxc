// vim: set ts=2 sw=2 et :
// bjw-s-labs app-template adapter projection — see README.md for upstream repo/version details
package app_template

import (
	"github.com/epcim/mxc/schema"
	"github.com/epcim/mxc/schema/mxc"
)

// Helper to project an abstract #App (or container-specialized #AppMxc) to standard bjw-s app-template values format
#Projection: {
	appSpec: schema.#App
	cluster: schema.#Cluster

	let domain = [
		if cluster.domain != _|_ {cluster.domain},
		if (cluster & {network: domain: string}).network.domain != _|_ {cluster.network.domain},
		"cluster.local",
	][0]
	let _k8sIngress = (cluster & {platform: k8s: ingress: {}}).platform.k8s.ingress
	let _defaultIngressClass = [if _k8sIngress.class != _|_ {_k8sIngress.class}, "traefik"][0]
	let _ingressAnnotations = [if _k8sIngress.annotations != _|_ {_k8sIngress.annotations}, {}][0]

	// Check if appSpec defines AppContainer container keys (image, ports, or expose)
	let isAppMxc = len([
		if (appSpec & {image: {repository: string}}).image.repository != _|_ {1},
		if len((appSpec & {ports: {}}).ports) > 0 {1},
		if len((appSpec & {expose: {}}).expose) > 0 {1},
	]) > 0

	// The generated bjw-s app-template values structure
	output: {
		// Single container workload projection block (for #AppMxc containerized apps)
		if isAppMxc {
			let _appContainer = (appSpec & mxc.#AppContainer)
			let _image = (_appContainer & {image: {}}).image
			let _ports = (_appContainer & {ports: {}}).ports
			let _expose = (_appContainer & {expose: {}}).expose

			// 1. Generate standard app-template controllers & containers structure
			controllers: main: containers: main: {
				if _image.repository != _|_ {
					image: {
						repository: _image.repository
						if _image.tag != _|_ {tag: _image.tag}
					}
				}
				if len(_ports) > 0 {
					ports: [
						for k, v in _ports {
							name:          k
							containerPort: v.port
							protocol: [if v.protocol != _|_ {v.protocol}, "TCP"][0]
						}
					]
				}
			}

			// 2. Generate services if ports are defined
			if len(_ports) > 0 {
				service: main: {
					controller: "main"
					ports: {
						for k, v in _ports {
							"\(k)": port: v.port
						}
					}
				}
			}

			// 3. Generate ingress configuration if expose is defined
			if len(_expose) > 0 {
				ingress: {
					for k, v in _expose if v.target == "ingress" {
						"\(k)": {
							enabled: true
							let _targetClass = (v & {ingressClass: *"" | string}).ingressClass
							let _customClass = [if _targetClass != "" {_targetClass}, _defaultIngressClass][0]
							className: _customClass
							let defaultFqdn = "\(appSpec.appName).\(domain)"
							let _customFqdn = (v & {fqdn: *"" | string}).fqdn
							let _targetHost = [
								if appSpec.appFqdn != _|_ {appSpec.appFqdn},
								if _customFqdn != "" {_customFqdn},
								defaultFqdn,
							][0]
							hosts: [{
								host: _targetHost
								paths: [{
									path: "/"
									service: {
										identifier: "main"
										port:       k
									}
								}]
							}]
							tls: [{
								hosts: [_targetHost]
							}]
							let mergedAnnotations = {
								for _k, _val in _ingressAnnotations {
									if v.annotations == _|_ || v.annotations[_k] == _|_ {
										"\(_k)": _val
									}
								}
								if v.annotations != _|_ {
									for _k, _val in v.annotations {
										"\(_k)": _val
									}
								}
							}
							if len(mergedAnnotations) > 0 {annotations: mergedAnnotations}
						}
					}
				}
			}
		}

		// 4. Merge any user-specified context/values overrides
		if appSpec.values != _|_ {appSpec.values}
		if appSpec.values == _|_ && appSpec.context != _|_ {appSpec.context}
	}
}
