// vim: set ts=2 sw=2 et :
package test

import (
	dockercompose "cue.dev/x/dockercompose"
)

// Declare the assertion that our target conforms exactly to the curated Compose schema
#ComposeConfig: dockercompose.#Schema
