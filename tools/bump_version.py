#!/usr/bin/env python3
"""Bump semantic version (major/minor/patch) and build/version codes across native config files."""
import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
PROJECT_GODOT = ROOT / "native/project.godot"
EXPORT_PRESETS = ROOT / "native/export_presets.cfg"


def read_current() -> tuple[tuple[int, int, int], int]:
    project_text = PROJECT_GODOT.read_text()
    version_match = re.search(r'^config/version="(\d+)\.(\d+)\.(\d+)"', project_text, re.M)
    if not version_match:
        raise SystemExit("Could not find config/version=\"X.Y.Z\" in native/project.godot")
    version = tuple(int(part) for part in version_match.groups())

    presets_text = EXPORT_PRESETS.read_text()
    code_match = re.search(r'^version/code=(\d+)', presets_text, re.M)
    if not code_match:
        raise SystemExit("Could not find version/code=<int> in native/export_presets.cfg")
    code = int(code_match.group(1))
    return version, code


def compute_next(current: tuple[int, int, int], kind: str) -> str:
    major, minor, patch = current
    if kind == "major":
        return f"{major + 1}.0.0"
    if kind == "minor":
        return f"{major}.{minor + 1}.0"
    if kind == "patch":
        return f"{major}.{minor}.{patch + 1}"
    raise SystemExit(f"Unsupported bump kind: {kind}")


def update_files(new_version: str, new_code: int) -> None:
    project_text = PROJECT_GODOT.read_text()
    project_text = re.sub(
        r'^(config/version=)"[^"]*"',
        rf'\1"{new_version}"',
        project_text,
        flags=re.M,
    )
    PROJECT_GODOT.write_text(project_text)

    lines = EXPORT_PRESETS.read_text().splitlines(keepends=True)
    current_platform = ""
    updated: list[str] = []
    for line in lines:
        platform_match = re.match(r'^platform="([^"]+)"', line)
        if platform_match:
            current_platform = platform_match.group(1)

        if line.startswith("version/code="):
            line = f"version/code={new_code}\n"
        elif line.startswith("version/name="):
            line = f'version/name="{new_version}"\n'
        elif line.startswith("application/short_version="):
            line = f'application/short_version="{new_version}"\n'
        elif line.startswith("application/product_version="):
            # Windows versions have four numbers; the fourth carries the version code.
            line = f'application/product_version="{new_version}.{new_code}"\n'
        elif line.startswith("application/file_version="):
            line = f'application/file_version="{new_version}.{new_code}"\n'
        elif line.startswith("application/version="):
            # iOS and macOS read this as the build number (CFBundleVersion).
            if current_platform in ("iOS", "macOS"):
                line = f'application/version="{new_code}"\n'
            else:
                line = f'application/version="{new_version}"\n'
        elif line.startswith("export_path="):
            line = re.sub(r'(-v\d+\.\d+\.\d+)?(?=(?:-debug|-release-arm64|-release)?\.[a-zA-Z0-9_]+")', f"-v{new_version}", line, count=1)
        updated.append(line)

    EXPORT_PRESETS.write_text("".join(updated))


def main() -> None:
    parser = argparse.ArgumentParser(description="Bump project version and version code.")
    parser.add_argument("kind", nargs="?", choices=["major", "minor", "patch"], help="Version component to bump")
    parser.add_argument("--show", action="store_true", help="Print the current version and version code")
    parser.add_argument("--version", action="store_true", help="Print only the current X.Y.Z version")
    parser.add_argument("--code", action="store_true", help="Print only the current version code")
    args = parser.parse_args()

    current, code = read_current()
    current_str = ".".join(str(part) for part in current)
    if args.version:
        print(current_str)
        return
    if args.code:
        print(code)
        return
    if args.show or not args.kind:
        print(f"version={current_str} version_code={code}")
        return

    new_version = compute_next(current, args.kind)
    new_code = code + 1
    update_files(new_version, new_code)
    print(f"Updated version: {current_str} -> {new_version} (version_code: {code} -> {new_code})")


if __name__ == "__main__":
    main()
