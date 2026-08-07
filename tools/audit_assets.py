#!/usr/bin/env python3
"""Read-only asset classification and direct-reference inventory."""

from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "assets"
MANIFEST_PATH = ASSET_ROOT / "asset_classification.json"
REFERENCE_ROOTS = (ROOT / "project.godot", ROOT / "scripts", ROOT / "scenes", ROOT / "data")
SKIPPED_NAMES = {"README.md", "asset_classification.json"}


def iter_assets() -> list[Path]:
	return sorted(
		path for path in ASSET_ROOT.rglob("*")
		if path.is_file() and not path.name.endswith(".import") and path.name not in SKIPPED_NAMES
	)


def referenced_asset_paths() -> set[str]:
	references: set[str] = set()
	for root in REFERENCE_ROOTS:
		paths = [root] if root.is_file() else root.rglob("*") if root.exists() else []
		for path in paths:
			if not path.is_file():
				continue
			try:
				text = path.read_text(encoding="utf-8")
			except (UnicodeDecodeError, OSError):
				continue
			for token in text.replace('"', " ").replace("'", " ").split():
				if token.startswith("res://assets/"):
					references.add(token.removeprefix("res://").rstrip(",)]}"))
	return references


def main() -> int:
	manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
	categories = sorted(manifest["categories"], key=lambda item: len(item["prefix"]), reverse=True)
	stats: dict[str, dict[str, int]] = defaultdict(lambda: {"files": 0, "bytes": 0, "referenced": 0})
	unclassified: list[str] = []
	references = referenced_asset_paths()
	for path in iter_assets():
		relative = path.relative_to(ROOT).as_posix()
		category = next((item for item in categories if relative.startswith(item["prefix"])), None)
		if category is None:
			unclassified.append(relative)
			continue
		row = stats[category["id"]]
		row["files"] += 1
		row["bytes"] += path.stat().st_size
		row["referenced"] += int(relative in references)
	print("ASSET CLASSIFICATION (read-only; unreferenced files are preserved)")
	for category in manifest["categories"]:
		row = stats[category["id"]]
		print(
			f"{category['id']:<24} files={row['files']:>5} "
			f"direct_refs={row['referenced']:>5} bytes={row['bytes']:>12} status={category['status']}"
		)
	if unclassified:
		print("UNCLASSIFIED")
		for path in unclassified:
			print(path)
		return 1
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
