package schema

import "strings"
// NBRoutingPeer
//
// NBRoutingPeer is the Schema for the nbroutingpeers API.

#NBRoutingPeer: {
	@jsonschema(schema="http://json-schema.org/draft-07/schema#")
	@jsonschema(id="https://netbird.io/v1/NBRoutingPeer")
	apiVersion?: "netbird.io/v1"
	kind?:       "NBRoutingPeer"
	metadata!: {
		name!:      string
		namespace?: string
		labels?: [string]:      string
		annotations?: [string]: string
		...
	}

	// NBRoutingPeerSpec defines the desired state of NBRoutingPeer.
	spec?: {
		replicas?: int
		labels?: [string]:       string
		annotations?: [string]:  string
		nodeSelector?: [string]: string

		// ResourceRequirements describes the compute resource requirements.
		resources?: {
			limits?: [string]: matchN(1, [int, string])
			requests?: [string]: matchN(1, [int, string])
			...
		}
		tolerations?: [...{
			key?:               string
			operator?:          string
			value?:             string
			effect?:            string
			tolerationSeconds?: int
			...
		}]
		volumes?: [...{
			...
		}]
		volumeMounts?: [...{
			...
		}]
		...
	}
	...
}
// NBSetupKey
//
// NBSetupKey is the Schema for the nbsetupkeys API.

#NBSetupKey: {
	@jsonschema(schema="http://json-schema.org/draft-07/schema#")
	@jsonschema(id="https://netbird.io/v1/NBSetupKey")
	apiVersion?: "netbird.io/v1"
	kind?:       "NBSetupKey"
	metadata!: {
		name!:      string
		namespace?: string
		labels?: [string]:      string
		annotations?: [string]: string
		...
	}

	// NBSetupKeySpec defines the desired state of NBSetupKey.
	spec!: {
		// SecretKeyRef is a reference to the secret containing the setup key
		secretKeyRef!: {
			// Name of the Secret
			name?: string

			// The key of the secret to select from
			key!: string

			// Specify whether the Secret or its key must be defined
			optional?: bool
			...
		}

		// ManagementURL optional, override operator management URL
		managementURL?: string
		volumes?: [...{
			...
		}]
		volumeMounts?: [...{
			...
		}]
		...
	}
	...
}
// NBResource
//
// NBResource advertises a K8s service to NetBird network for VPN access.

#NBResource: {
	@jsonschema(schema="http://json-schema.org/draft-07/schema#")
	@jsonschema(id="https://netbird.io/v1/NBResource")
	apiVersion?: "netbird.io/v1"
	kind?:       "NBResource"
	metadata!: {
		// Resource name (unique within namespace)
		name!: string

		// Kubernetes namespace
		namespace?: string
		labels?: [string]:      string
		annotations?: [string]: string
		...
	}

	// NBResourceSpec defines the desired state of NBResource.
	spec!: {
		// Display name in NetBird dashboard
		name!: strings.MinRunes(1)

		// NetBird Network ID (from NBRoutingPeer status, or use networkRef)
		networkID?: string

		// Reference to NBRoutingPeer name (alternative to networkID)
		networkRef?: string

		// Service address (DNS name or IP, e.g., jellyfin.media.svc.cluster.local)
		address!: strings.MinRunes(1)

		// NetBird groups that can access this resource
		groups!: [...strings.MinRunes( 1)]

		// Optional policy name for access control
		policyName?: string

		// Source groups for the policy
		policySourceGroups?: [...string]

		// Allowed TCP ports (empty = all)
		tcpPorts?: [...int]

		// Allowed UDP ports (empty = all)
		udpPorts?: [...int]
		...
	}
	...
}
