# Model-X Configuration (MXC) Migration Framework
# Numbered migration recipes correlated with OCI package schema versions

root := env_var_or_default("GIT_ROOT", `git rev-parse --show-toplevel 2>/dev/null || pwd`)
TARGET := env('MXC_TARGET', env('TARGET', '.'))

# List all available MXC migrations and their target OCI version milestones
[group('mxc-migration')]
[no-cd]
migrate-list:
    #!/usr/bin/env python3
    import json
    migrations = [
        {
            "id": "0001",
            "oci_version": "v0.1.0",
            "name": "expose_to_appfqdn",
            "desc": "Migrate legacy expose: http: fqdn: ... syntax to top-level appFqdn",
        },
        {
            "id": "0002",
            "oci_version": "v0.1.0",
            "name": "appcore_to_app",
            "desc": "Migrate legacy schema.#AppCore to canonical schema.#App",
        },
    ]
    print(json.dumps(migrations, indent=2))

# Execute all MXC migrations sequentially on target CUE directory or file
[group('mxc-migration')]
[no-cd]
migrate target=TARGET *args="":
    #!/usr/bin/env python3
    import sys
    import os
    import re
    import argparse

    # --- Migration Registry ---
    def migration_0001_expose_to_appfqdn(content: str) -> tuple[str, int]:
        changes = 0
        # Pattern 1: Single line 'expose: http: fqdn: <EXPR>'
        pattern1 = re.compile(r'^(\s*)expose:\s*http:\s*fqdn:\s*(.+)$', re.MULTILINE)
        def repl1(match):
            nonlocal changes
            changes += 1
            return f"{match.group(1)}appFqdn: {match.group(2)}"
        content = pattern1.sub(repl1, content)

        # Pattern 2: Multi-line expose block with only http.fqdn
        pattern2 = re.compile(
            r'(\s*)expose:\s*\{\s*\n\s*http:\s*\{\s*\n\s*fqdn:\s*([^\n]+)\s*\n\s*\}\s*\n\s*\}',
            re.MULTILINE
        )
        def repl2(match):
            nonlocal changes
            changes += 1
            return f"{match.group(1)}appFqdn: {match.group(2).strip()}"
        content = pattern2.sub(repl2, content)
        return content, changes

    def migration_0002_appcore_to_app(content: str) -> tuple[str, int]:
        changes = 0
        pattern = re.compile(r'\bschema\.#AppCore\b')
        def repl(match):
            nonlocal changes
            changes += 1
            return "schema.#App"
        content = pattern.sub(repl, content)
        return content, changes

    MIGRATIONS = [
        {
            "id": "0001",
            "oci_version": "v0.1.0",
            "name": "expose_to_appfqdn",
            "apply": migration_0001_expose_to_appfqdn,
        },
        {
            "id": "0002",
            "oci_version": "v0.1.0",
            "name": "appcore_to_app",
            "apply": migration_0002_appcore_to_app,
        },
    ]

    def process_file(filepath: str, selected_migrations, dry_run: bool = False) -> int:
        with open(filepath, 'r', encoding='utf-8') as f:
            original = f.read()

        current = original
        total_file_changes = 0
        for m in selected_migrations:
            current, count = m["apply"](current)
            if count > 0:
                print(f"  [{'DRY-RUN' if dry_run else 'APPLIED'}] [{m['id']}_{m['oci_version']}_{m['name']}] {count} changes in {os.path.basename(filepath)}")
                total_file_changes += count

        if total_file_changes > 0 and not dry_run:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(current)
        return total_file_changes

    def process_directory(directory: str, selected_migrations, dry_run: bool = False) -> int:
        total = 0
        for root, dirs, files in os.walk(directory):
            dirs[:] = [d for d in dirs if not d.startswith('.') and d != 'pkg']
            for file in files:
                if file.endswith('.cue'):
                    total += process_file(os.path.join(root, file), selected_migrations, dry_run=dry_run)
        return total

    def main():
        parser = argparse.ArgumentParser(description="Run ordered MXC schema migrations against CUE configs.")
        parser.add_argument("target", nargs="?", default="{{ target }}", help="Path to target file or directory")
        parser.add_argument("--migration", "-m", help="Run only a specific migration ID (e.g. 0001)")
        parser.add_argument("--dry-run", action="store_true", help="Preview changes without writing to disk")
        extra_args = "{{ args }}".split()
        parsed = parser.parse_args([a for a in extra_args if a] or None)

        target_input = parsed.target
        if os.path.isabs(target_input):
            target_path = target_input
        elif os.path.exists(os.path.join("{{ root }}", target_input)):
            target_path = os.path.join("{{ root }}", target_input)
        else:
            target_path = os.path.abspath(target_input)

        if not os.path.exists(target_path):
            print(f"Error: Target path does not exist: {target_path}", file=sys.stderr)
            sys.exit(1)

        selected = MIGRATIONS
        if parsed.migration:
            selected = [m for m in MIGRATIONS if m["id"] == parsed.migration or m["name"] == parsed.migration]
            if not selected:
                print(f"Error: Unknown migration '{parsed.migration}'", file=sys.stderr)
                sys.exit(1)

        print(f"▶ Running {len(selected)} migration(s) on: {target_path}")
        for m in selected:
            print(f"  • Migration {m['id']} ({m['oci_version']}): {m['name']}")

        if os.path.isfile(target_path):
            total_changes = process_file(target_path, selected, dry_run=parsed.dry_run)
        else:
            total_changes = process_directory(target_path, selected, dry_run=parsed.dry_run)

        print(f"✓ Migration complete. Total replacements: {total_changes}")

    if __name__ == "__main__":
        main()

# Run migration 0001: v0.1.0 expose.http.fqdn to appFqdn
[group('mxc-migration')]
[no-cd]
migrate-0001 target=TARGET *args="":
    just -f {{ source_file() }} migrate {{ target }} --migration 0001 {{ args }}

# Run migration 0002: v0.1.0 schema.#AppCore to schema.#App
[group('mxc-migration')]
[no-cd]
migrate-0002 target=TARGET *args="":
    just -f {{ source_file() }} migrate {{ target }} --migration 0002 {{ args }}

# Alias for backward compatibility
[group('mxc-migration')]
[no-cd]
migrate-appfqdn target=TARGET *args="":
    just -f {{ source_file() }} migrate-0001 {{ target }} {{ args }}
