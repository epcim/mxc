// vim: set ts=2 sw=2 et :
package external

import (
	corev1 "cue.dev/x/k8s.io/api/core/v1"
	netv1 "cue.dev/x/k8s.io/api/networking/v1"
	cert "cue.dev/x/crd/cert-manager.io/v1"
	acme "cue.dev/x/crd/cert-manager.io/acme/v1"
	kyverno "cue.dev/x/kyverno/clusterpolicy/v1"
	dockercompose "cue.dev/x/dockercompose"
)

// Placeholders to keep imports active and fully schema-validated by the compiler
#K8sPod:                 corev1.#Pod
#K8sNetworkPolicy:       netv1.#NetworkPolicy
#CertCertificate:        cert.#Certificate
#CertChallenge:          acme.#Challenge
#KyvernoClusterPolicy:   kyverno.#ClusterPolicy
#DockerComposeConfig:    dockercompose.#Schema

#PortSpec: {
	port:     int & >=1 & <=65535
	protocol: "TCP" | "UDP" | *"TCP"
}

#VolumeSpec: {
	enabled?: bool | *true
	size:  string
	class?: string
}
