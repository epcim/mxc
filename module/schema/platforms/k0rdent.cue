// vim: set ts=2 sw=2 et :
package platforms

// #PlatformK0rdent defines Mirantis K0rdent service catalog and MultiClusterService specifications.
#PlatformK0rdent: {
	template?: string
	serviceSpec?: {
		serviceName?: string
		deployment?:  "multicluster" | "cluster" | string
		[string]:     _
	}
	values?: {
		[string]: _
	}
	...
}
