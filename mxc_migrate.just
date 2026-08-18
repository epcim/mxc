# Model-X Configuration (MXC) Migration Tasks
# Self-contained migration recipes embedded directly inside Just

# Migrate legacy expose: http: fqdn: ... syntax to top-level appFqdn in CUE files
[group('mxc-migration')]
migrate-appfqdn target="cluster-home-mxc" *args="":
    #!/usr/bin/env python3
    import sys
    import os
    import re
    import argparse

    def migrate_cue_content(content: str) -> tuple[str, int]:
        changes = 0

        # Pattern 1: Single line 'expose: http: fqdn: <EXPR>'
        pattern1 = re.compile(r'^(\s*)expose:\s*http:\s*fqdn:\s*(.+)$', re.MULTILINE)
        def repl1(match):
            nonlocal changes
            changes += 1
            indent = match.group(1)
            fqdn_val = match.group(2)
            return f"{indent}appFqdn: {fqdn_val}"
        content = pattern1.sub(repl1, content)

        # Pattern 2: Multi-line expose block with only http.fqdn
        pattern2 = re.compile(
            r'(\s*)expose:\s*\{\s*\n\s*http:\s*\{\s*\n\s*fqdn:\s*([^\n]+)\s*\n\s*\}\s*\n\s*\}',
            re.MULTILINE
        )
        def repl2(match):
            nonlocal changes
            changes += 1
            indent = match.group(1)
            fqdn_val = match.group(2).strip()
            return f"{indent}appFqdn: {fqdn_val}"
        content = pattern2.sub(repl2, content)

        return content, changes

    def process_file(filepath: str, dry_run: bool = False) -> int:
        with open(filepath, 'r', encoding='utf-8') as f:
            original = f.read()
        modified, count = migrate_cue_content(original)
        if count > 0:
            print(f"[{'DRY-RUN' if dry_run else 'APPLIED'}] {filepath}: {count} replacements made.")
            if not dry_run:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(modified)
        return count

    def process_directory(directory: str, dry_run: bool = False) -> int:
        total_changes = 0
        for root, dirs, files in os.walk(directory):
            dirs[:] = [d for d in dirs if not d.startswith('.') and d != 'pkg']
            for file in files:
                if file.endswith('.cue'):
                    full_path = os.path.join(root, file)
                    total_changes += process_file(full_path, dry_run=dry_run)
        return total_changes

    def main():
        parser = argparse.ArgumentParser(description="Migrate expose.http.fqdn to appFqdn in CUE files.")
        parser.add_argument("target", nargs="?", default="{{ target }}", help="Path to file or directory")
        parser.add_argument("--dry-run", action="store_true", help="Preview changes without modifying")
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

        print(f"▶ Scanning for expose: http: fqdn in: {target_path}")
        if os.path.isfile(target_path):
            total = process_file(target_path, dry_run=parsed.dry_run)
        else:
            total = process_directory(target_path, dry_run=parsed.dry_run)
        print(f"✓ Completed migration. Total substitutions: {total}")

    if __name__ == "__main__":
        main()
