// Schema: [apps.cue](../../module/schema/apps.cue#L4) -> schema.#AppCore
// cue-language-server: $schema=../../docs/generated-schema/mxc-cluster.schema.json
// vim: set ts=2 sw=2 et :
package mxc

import "github.com/epcim/mxc/schema:schema"

cluster: apps: {
	// Infrastructure namespace applications
	infra: {
		traefik: schema.#AppCore & {
			appName: "traefik"
			deployment: "kluctl"
			contextSchema: "#app-template"  // Triggers app-template adapter behavior
			helmChart: {
				repo:         "https://traefik.github.io/charts"
				chartName:    "traefik"
				chartVersion: "34.2.0"
				releaseName:  "traefik"
				namespace:    "sys"
			}
			ports: {
				web: port: 80
				websecure: port: 443
			}
			kustomize: {
				namespace: "sys"
			}
		}
	}

	// Home category applications
	home: {
		homarr: schema.#AppCore & {
			appName: "homarr"
			deployment: "kluctl"
			contextSchema: "#app-template"
			helmChart: {
				repo:         "https://bjw-s-labs.github.io/helm-charts"
				chartName:    "app-template"
				chartVersion: "4.6.2"
				releaseName:  "homarr"
				namespace:    "home"
			}
			image: {
				repository: "ghcr.io/ajnart/homarr"
				tag:        "0.16.0"
			}
			ports: {
				http: port: 7575
			}
			expose: {
				http: {
					target: "ingress"
					fqdn:   "homarr.\(cluster.network.domain)"
				}
			}
			kustomize: {
				namespace: "home"
			}
		}
	}

	// Media category applications
	media: {
		silo: schema.#AppCore & {
			appName: "silo"
			deployment: "kluctl"
			contextSchema: "#app-template"
			helmChart: {
				repo:         "https://bjw-s-labs.github.io/helm-charts"
				chartName:    "app-template"
				chartVersion: "4.6.2"
				releaseName:  "silo"
				namespace:    "media"
			}
			image: {
				repository: "ghcr.io/silo-server/silo-server"
				tag:        "latest"
			}
			ports: {
				http: port: 8080
			}
			expose: {
				http: {
					target: "ingress"
					fqdn:   "silo.\(cluster.network.domain)"
				}
			}
			kustomize: {
				namespace: "media"
			}
			secrets: {
				secretKey: "{{ secrets.media.silo.secretKey }}"
				notifications: {
					host: "{{ secrets.infra.notifications.host }}"
					port: "{{ secrets.infra.notifications.port }}"
					user: "{{ secrets.infra.notifications.user }}"
					pass: "{{ secrets.infra.notifications.pass }}"
					addr: "{{ secrets.infra.notifications.addr }}"
				}
			}
			context: {
				controllers: main: containers: main: env: {
					SECRET_KEY: secrets.secretKey
					SMTP_HOST:  secrets.notifications.host
					SMTP_PORT:  secrets.notifications.port
					SMTP_USER:  secrets.notifications.user
					SMTP_PASS:  secrets.notifications.pass
					SMTP_FROM:  secrets.notifications.addr
				}
			}
		}
	}
}
