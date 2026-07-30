#!/usr/bin/env python3
"""Build the cross-platform Town Figma plugin with embedded local assets."""

from __future__ import annotations

import base64
import io
import json
from pathlib import Path

from PIL import Image


PLUGIN_DIR = Path(__file__).resolve().parent
TOWN_DIR = PLUGIN_DIR.parent
ROOT = TOWN_DIR.parents[2]
VECTOR_DIR = TOWN_DIR / "vector_sources"
B2_DIR = TOWN_DIR / "b2_front_style_candidates"
B2_REFERENCE = (
	ROOT / "concept/town/main_horizontal_concept/town_style_direction_a_locked.png"
)
TEMPLATE_PATH = PLUGIN_DIR / "code.template.js"
OUTPUT_PATH = PLUGIN_DIR / "code.js"


def _base64_review_png(path: Path, max_size: tuple[int, int]) -> str:
	image = Image.open(path).convert("RGBA")
	image.thumbnail(max_size, Image.Resampling.LANCZOS)
	buffer = io.BytesIO()
	image.save(buffer, "PNG", optimize=True)
	return base64.b64encode(buffer.getvalue()).decode("ascii")


def _base64_review_jpeg(
	path: Path,
	max_size: tuple[int, int],
	quality: int,
) -> str:
	image = Image.open(path).convert("RGB")
	image.thumbnail(max_size, Image.Resampling.LANCZOS)
	buffer = io.BytesIO()
	image.save(buffer, "JPEG", quality=quality, optimize=True, progressive=True)
	return base64.b64encode(buffer.getvalue()).decode("ascii")


def main() -> None:
	svg_assets = {
		path.stem: path.read_text(encoding="utf-8")
		for path in sorted(VECTOR_DIR.glob("*.svg"))
	}
	reference_assets = {
		path.stem: _base64_review_jpeg(path, (1400, 800), 82)
		for path in sorted(TOWN_DIR.glob("*.png"))
	}
	b2_assets = {
		path.stem: _base64_review_png(path, (760, 760))
		for path in sorted(B2_DIR.glob("*.png"))
	}
	if len(b2_assets) != 8:
		raise ValueError(f"Expected 8 Town B2 candidates, found {len(b2_assets)}")
	if not B2_REFERENCE.exists():
		raise FileNotFoundError(f"Missing locked Town reference: {B2_REFERENCE}")
	b2_reference = _base64_review_jpeg(B2_REFERENCE, (1800, 900), 86)

	result = TEMPLATE_PATH.read_text(encoding="utf-8")
	result = result.replace(
		"__TOWN_SVG_ASSETS__",
		json.dumps(svg_assets, ensure_ascii=False, separators=(",", ":")),
	)
	result = result.replace(
		"__TOWN_REFERENCE_ASSETS__",
		json.dumps(reference_assets, separators=(",", ":")),
	)
	result = result.replace(
		"__TOWN_B2_REVIEW_ASSETS__",
		json.dumps(b2_assets, separators=(",", ":")),
	)
	result = result.replace(
		"__TOWN_B2_REFERENCE_ASSET__",
		json.dumps(b2_reference),
	)
	OUTPUT_PATH.write_text(result, encoding="utf-8")
	print(f"Built {OUTPUT_PATH}")
	print(f"Vector sources: {len(svg_assets)}")
	print(f"Raster references: {len(reference_assets)}")
	print(f"B2 review assets: {len(b2_assets)}")


if __name__ == "__main__":
	main()
