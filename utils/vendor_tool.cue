// vim: set ts=2 sw=2 et :
package utils

import (
	"tool/file"
	"tool/http"
	"tool/exec"
	"path"
	"strings"
	"github.com/epcim/mxc-library/schema"
)

// CUE command definition driven dynamically by catalog.cue schema entries
command: "vendor-schema": {
	// Dynamically fetch the git repository top-level directory
	get_root: exec.Run & {
		cmd: ["git", "rev-parse", "--show-toplevel"]
		stdout: string
	}

	let root = strings.TrimSpace(get_root.stdout)

	for source in schema.catalog {
		// Only run for schema sources (type is json-schema or helm-values-schema)
		if source.type != _|_ && (source.type == "json-schema" || source.type == "helm-values-schema") {
			let is_yaml = source.type == "helm-values-schema"
			let file_name = path.Base(source.path)
			let dest_dir = root + "/mxc-library/" + source.outputDir
			let dest = "\(dest_dir)/\(file_name)"
			
			// Dynamically derive package name from the stack directory name (e.g. "cert-manager" -> "cert_manager")
			let dir_parts = strings.Split(dest_dir, "/")
			let pkg_index = len(dir_parts) - 2
			let raw_pkg = dir_parts[pkg_index]
			let pkg = strings.Replace(raw_pkg, "-", "_", -1)

			"\(source.name)": {
				mkdir: file.MkdirAll & {
					$dep: get_root.$done
					path: dest_dir
				}
				fetch: http.Get & {
					$dep: get_root.$done
					url:  source.url
				}
				write: file.Create & {
					$dep:     mkdir.$done
					filename: dest
					contents: fetch.response.body
				}
				import: exec.Run & {
					$dep: write.$done
					let mode = [
						if is_yaml { "yaml" },
						"jsonschema",
					][0]
					cmd: [
						"cue", "import", "-f",
						"-p", pkg,
						"-l", "#ValuesSchema:",
						"-o", "\(dest_dir)/../values_schema.cue",
						mode,
						dest,
					]
				}
			}
		}
	}
}
