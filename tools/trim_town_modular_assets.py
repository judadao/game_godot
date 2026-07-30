#!/usr/bin/env python3
"""Trim transparent generation padding from modular Town PNG assets."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ASSET_ROOT = ROOT / "assets/town/modular_v1"


def trim_assets(asset_root: Path) -> None:
	for path in sorted(asset_root.rglob("*.png")):
		image = Image.open(path).convert("RGBA")
		alpha_bounds = image.getchannel("A").getbbox()
		if alpha_bounds is None:
			raise ValueError(f"Modular Town asset is fully transparent: {path}")
		if path.name == "sky.png":
			continue
		padding = 0 if path.parent.name in {"background", "ground"} else 4
		left = max(0, alpha_bounds[0] - padding)
		top = max(0, alpha_bounds[1] - padding)
		right = min(image.width, alpha_bounds[2] + padding)
		bottom = min(image.height, alpha_bounds[3] + padding)
		trimmed = image.crop((left, top, right, bottom))
		pixels = trimmed.load()
		for corner_x, corner_y in [
			(0, 0),
			(trimmed.width - 1, 0),
			(0, trimmed.height - 1),
			(trimmed.width - 1, trimmed.height - 1),
		]:
			red, green, blue, _alpha = pixels[corner_x, corner_y]
			pixels[corner_x, corner_y] = (red, green, blue, 0)
		trimmed.save(path, "PNG", optimize=True)
		print(f"{path.relative_to(ROOT)}: {image.size} -> {trimmed.size}")


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("--asset-root", type=Path, default=DEFAULT_ASSET_ROOT)
	args = parser.parse_args()
	trim_assets(args.asset_root)


if __name__ == "__main__":
	main()
