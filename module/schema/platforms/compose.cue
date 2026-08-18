// vim: set ts=2 sw=2 et :
package platforms

// #PlatformCompose defines parameters for Docker Compose execution environments.
#PlatformCompose: {
	containerName?: string
	restartPolicy?: "no" | "always" | "on-failure" | "unless-stopped" | *"unless-stopped"
	networkMode?:   "bridge" | "host" | "overlay" | string
	extraHosts?: [...string]
	privileged?: bool | *false
	user?:       string
	envFile?: [...string]
	...
}
