#!/usr/bin/env python3
"""Prepare approved Town Base candidates for the runtime modular layout.

The image-generation candidates deliberately retain generous transparent
working space. Runtime assets instead use a deterministic 4x target canvas:
the visible object is alpha-trimmed, scaled with nearest-neighbour sampling,
centered horizontally, and anchored to the bottom edge. This preserves the
artwork's aspect ratio while keeping every building foundation on the shared
Town baseline without stretching.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LAYOUT = ROOT / "data/town_modular_layout.json"
DEFAULT_CANDIDATE_ROOT = ROOT / "design/figma/town/b2_front_style_candidates"
RUNTIME_SCALE = 4
INNER_MARGIN = 4 * RUNTIME_SCALE

CANDIDATE_BY_ID = {
	"material_yard": "material_yard_front_style_b2.png",
	"player_blacksmith": "player_forge_front_style_b2.png",
	"eternal_flame": "eternal_forge_monument_base_v5.png",
	"battle_portal": "battle_portal_base_v4.png",
	"town_hall": "town_hall_front_style_base_v3.png",
	"sword_soul_shop": "sword_soul_shop_front_style_base_v3.png",
	"equipment_blueprint_shop": "equipment_blueprint_shop_front_style_base_v3.png",
	"far_east_residence": "far_east_residence_front_style_base_v3.png",
}

RUNTIME_BY_ID = {
	"material_yard": ROOT / "assets/town/modular_v2/buildings/material_yard.png",
	"player_blacksmith": ROOT / "assets/town/modular_v2/buildings/player_forge.png",
	"eternal_flame":
		ROOT / "assets/town/modular_v3/landmarks/eternal_forge_monument_base_v5.png",
	"battle_portal":
		ROOT / "assets/town/modular_v3/landmarks/battle_portal_base_v4.png",
	"town_hall": ROOT / "assets/town/modular_v2/buildings/town_hall_base_v3.png",
	"sword_soul_shop": ROOT / "assets/town/modular_v2/buildings/sword_soul_shop_base_v3.png",
	"equipment_blueprint_shop":
		ROOT / "assets/town/modular_v2/buildings/blueprint_research_base_v3.png",
	"far_east_residence":
		ROOT / "assets/town/modular_v2/buildings/east_residence_base_v3.png",
}


def _layers_by_id(payload: dict[str, Any]) -> dict[str, dict[str, Any]]:
	return {
		str(layer["id"]): layer
		for layer in payload["layers"]
		if str(layer.get("id", "")) in CANDIDATE_BY_ID
	}


def _prepare_candidate(
	source_path: Path,
	target_path: Path,
	target_size: tuple[int, int],
) -> None:
	image = Image.open(source_path).convert("RGBA")
	alpha_bounds = image.getchannel("A").getbbox()
	if alpha_bounds is None:
		raise ValueError(f"Town Base candidate is fully transparent: {source_path}")
	trimmed = image.crop(alpha_bounds)

	canvas_size = (
		target_size[0] * RUNTIME_SCALE,
		target_size[1] * RUNTIME_SCALE,
	)
	available_size = (
		canvas_size[0] - INNER_MARGIN * 2,
		canvas_size[1] - INNER_MARGIN,
	)
	scale = min(
		available_size[0] / trimmed.width,
		available_size[1] / trimmed.height,
	)
	render_size = (
		max(1, round(trimmed.width * scale)),
		max(1, round(trimmed.height * scale)),
	)
	rendered = trimmed.resize(render_size, Image.Resampling.NEAREST)
	canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
	left = (canvas.width - rendered.width) // 2
	top = canvas.height - rendered.height
	canvas.alpha_composite(rendered, (left, top))

	for corner in (
		(0, 0),
		(canvas.width - 1, 0),
		(0, canvas.height - 1),
		(canvas.width - 1, canvas.height - 1),
	):
		canvas.putpixel(corner, (0, 0, 0, 0))

	target_path.parent.mkdir(parents=True, exist_ok=True)
	if target_path.exists():
		existing = Image.open(target_path).convert("RGBA")
		if existing.size == canvas.size and existing.tobytes() == canvas.tobytes():
			print(
				f"{source_path.relative_to(ROOT)} -> "
				f"{target_path.relative_to(ROOT)} unchanged"
			)
			return
	canvas.save(target_path, "PNG", optimize=True)
	print(
		f"{source_path.relative_to(ROOT)} -> {target_path.relative_to(ROOT)} "
		f"{image.size} -> {canvas.size}; visible={render_size}"
	)


def prepare_assets(layout_path: Path, candidate_root: Path) -> None:
	payload = json.loads(layout_path.read_text(encoding="utf-8"))
	layers = _layers_by_id(payload)
	missing_layers = sorted(set(CANDIDATE_BY_ID) - set(layers))
	if missing_layers:
		raise ValueError(f"Town layout is missing Base layers: {missing_layers}")

	for object_id, candidate_name in CANDIDATE_BY_ID.items():
		source_path = candidate_root / candidate_name
		if not source_path.exists():
			raise FileNotFoundError(f"Missing approved Town Base candidate: {source_path}")
		target_size_value = layers[object_id].get("target_size", [])
		if len(target_size_value) != 2:
			raise ValueError(f"{object_id} must define a two-axis target_size")
		target_size = (round(target_size_value[0]), round(target_size_value[1]))
		_prepare_candidate(source_path, RUNTIME_BY_ID[object_id], target_size)


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("--layout", type=Path, default=DEFAULT_LAYOUT)
	parser.add_argument("--candidate-root", type=Path, default=DEFAULT_CANDIDATE_ROOT)
	args = parser.parse_args()
	prepare_assets(args.layout, args.candidate_root)


if __name__ == "__main__":
	main()
