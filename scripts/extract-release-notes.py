#!/usr/bin/env python3
"""Extract one version's section from CHANGELOG.md for the release body.

Reads `## [<version>]` through to the next `## [` heading (or EOF) and
writes it to `release_notes.md`. Fails loudly when the version is
missing, so a release never publishes with an empty body after the
build already ran.
"""

import argparse
import re
import sys
from pathlib import Path


def extract_notes(changelog: str, version: str) -> str:
    lines = changelog.splitlines(keepends=True)
    collecting = False
    collected: list[str] = []
    heading = re.compile(r"^## \[(.+?)\]")
    for line in lines:
        match = heading.match(line)
        if match:
            if collecting:
                break
            collecting = match.group(1).strip() == version
            continue
        if collecting:
            collected.append(line)
    notes = "".join(collected).strip("\n").strip()
    if not notes:
        raise ValueError(f"No release notes found for version {version} in CHANGELOG.md")
    return notes + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("version")
    parser.add_argument("--changelog", default="CHANGELOG.md")
    parser.add_argument("--out", default="release_notes.md")
    args = parser.parse_args(argv)

    try:
        changelog = Path(args.changelog).read_text(encoding="utf-8")
        notes = extract_notes(changelog, args.version)
        Path(args.out).write_text(notes, encoding="utf-8")
    except (OSError, ValueError) as error:
        sys.exit(f"ERROR: {error}")

    print(f"Release notes extracted for {args.version} into {args.out}:")
    print(notes, end="")
    return 0


if __name__ == "__main__":
    sys.exit(main())
