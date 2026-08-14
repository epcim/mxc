module: "github.com/epcim/mxc@v0"
language: {
	version: "v0.17.0"
}
source: {
	kind: "git"
}
deps: {
	"cue.dev/x/crd/cert-manager.io@v0": {
		v:       "v0.3.0"
		default: true
	}
	"cue.dev/x/dockercompose@v0": {
		v:       "v0.1.0"
		default: true
	}
	"cue.dev/x/k8s.io@v0": {
		v:       "v0.7.0"
		default: true
	}
	"cue.dev/x/kyverno@v0": {
		v:       "v0.4.0"
		default: true
	}
}
