// vim: set ts=2 sw=2 et :
package example

import (
	"encoding/json"
	"tool/cli"
	"tool/http"
)

// Example Caddy JSON configuration modeled natively in CUE
caddyConfig: {
	apps: http: servers: srv0: {
		listen: [":80", ":443"]
		routes: [
			{
				match: [{
					host: ["app.example.com"]
				}]
				handle: [{
					handler: "reverse_proxy"
					upstreams: [{
						dial: "http://upstream-svc:8080"
					}]
				}]
			},
		]
	}
}

// CUE scripting/tooling command to upload/reload dynamic configuration via HTTP API
//
// Usage:
//   cue cmd caddy-reload
//
command: "caddy-reload": {
	// 1. Serialize CUE configuration model directly to JSON
	config: json.Marshal(caddyConfig)

	// 2. Post payload to service Admin API (:2019/load)
	post: http.Post & {
		url: "http://127.0.0.1:2019/load"
		request: {
			header: "Content-Type": "application/json"
			body: config
		}
	}

	// 3. Print execution response
	print: cli.Print & {
		text: "✓ Configuration pushed to Admin API successfully: \(post.response.status)"
	}
}
