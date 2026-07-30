#!/usr/bin/env python3
"""Build the static TownModularVisuals scene from its replaceable-object layout."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LAYOUT = ROOT / "data/town_modular_layout.json"
DEFAULT_SCENE = ROOT / "scenes/maps/town/components/TownModularVisuals.tscn"
CATEGORY_NODES = {
	"background": "Background",
	"ground": "Ground",
	"facility": "Facilities",
	"landmark": "Landmarks",
	"street_prop": "StreetProps",
}


def _pascal_case(value: str) -> str:
	return "".join(part.capitalize() for part in re.split(r"[^a-zA-Z0-9]+", value) if part)


def _res_path_to_file(resource_path: str) -> Path:
	if not resource_path.startswith("res://"):
		raise ValueError(f"Town modular source must use res://: {resource_path}")
	return ROOT / resource_path.removeprefix("res://")


def _vector2(value: list[object]) -> str:
	if len(value) != 2:
		raise ValueError(f"Expected a two-value vector, got {value!r}")
	return f"Vector2({float(value[0]):g}, {float(value[1]):g})"


def _texture_scale(layer: dict[str, Any]) -> list[float]:
	if "scale" in layer:
		return [float(layer["scale"][0]), float(layer["scale"][1])]
	target_size = layer.get("target_size")
	if target_size is None:
		raise ValueError(f"{layer['id']} must define target_size or scale")
	source_file = _res_path_to_file(str(layer["source"]))
	if not source_file.exists():
		raise FileNotFoundError(f"Missing modular Town asset: {source_file}")
	with Image.open(source_file) as image:
		width, height = image.size
	return [float(target_size[0]) / width, float(target_size[1]) / height]


def _validate_layout(payload: dict[str, Any]) -> list[dict[str, Any]]:
	if int(payload.get("schema_version", 0)) != 1:
		raise ValueError("Town modular layout schema_version must be 1")
	map_contract = payload.get("map")
	if not isinstance(map_contract, dict):
		raise ValueError("Town modular layout must define map metadata")
	for key in ("id", "width", "height", "gameplay_baseline_y"):
		if key not in map_contract:
			raise ValueError(f"Town modular map is missing {key}")
	layers = payload.get("layers")
	if not isinstance(layers, list) or not layers:
		raise ValueError("Town modular layout must define non-empty layers")
	seen_ids: set[str] = set()
	for layer in layers:
		if not isinstance(layer, dict):
			raise ValueError("Town modular layers must be dictionaries")
		layer_id = str(layer.get("id", ""))
		if not layer_id or layer_id in seen_ids:
			raise ValueError(f"Town modular object ID must be non-empty and unique: {layer_id}")
		seen_ids.add(layer_id)
		category = str(layer.get("category", ""))
		if category not in CATEGORY_NODES:
			raise ValueError(f"Unsupported Town modular category: {category}")
		_res_path_to_file(str(layer.get("source", "")))
		_vector2(layer.get("position", []))
		_texture_scale(layer)
	return layers


def build_scene(layout_path: Path, scene_path: Path) -> None:
	payload = json.loads(layout_path.read_text(encoding="utf-8"))
	layers = _validate_layout(payload)
	sources = sorted({str(layer["source"]) for layer in layers})
	resource_ids = {
		source: f"{index + 1}_{Path(source).stem}"
		for index, source in enumerate(sources)
	}
	lines = [
		f'[gd_scene load_steps={len(sources) + 1} format=3]',
		"",
	]
	for source in sources:
		lines.append(
			f'[ext_resource type="Texture2D" path="{source}" id="{resource_ids[source]}"]'
		)
	lines.extend(
		[
			"",
			'[node name="TownModularVisuals" type="Node2D"]',
			f'metadata/layout_path = "res://{layout_path.relative_to(ROOT).as_posix()}"',
			f'metadata/map_width = {int(payload["map"]["width"])}',
			f'metadata/map_height = {int(payload["map"]["height"])}',
			f'metadata/gameplay_baseline_y = {float(payload["map"]["gameplay_baseline_y"]):g}',
		]
	)
	for category_node in CATEGORY_NODES.values():
		lines.extend(
			[
				"",
				f'[node name="{category_node}" type="Node2D" parent="."]',
				f'metadata/layer_role = "{category_node.lower()}"',
			]
		)
	for layer in layers:
		layer_id = str(layer["id"])
		category = str(layer["category"])
		source = str(layer["source"])
		ownership = layer.get("interaction_ownership", {})
		lines.extend(
			[
				"",
				f'[node name="{_pascal_case(layer_id)}" type="Sprite2D" parent="{CATEGORY_NODES[category]}"]',
				f'position = {_vector2(layer["position"])}',
				f'scale = {_vector2(_texture_scale(layer))}',
				f'z_index = {int(layer["z_index"])}',
				f'visible = {"true" if bool(layer["visible"]) else "false"}',
				f'texture = ExtResource("{resource_ids[source]}")',
				f'metadata/object_id = "{layer_id}"',
				f'metadata/category = "{category}"',
				f'metadata/source_asset = "{source}"',
				f'metadata/interaction_mode = "{ownership.get("mode", "none")}"',
				f'metadata/interaction_owner_scene = "{ownership.get("owner_scene", "")}"',
				f'metadata/interaction_node_path = "{ownership.get("node_path", "")}"',
				f'metadata/interaction_id = "{ownership.get("interaction_id", "")}"',
				f'metadata/service_id = "{ownership.get("service_id", "")}"',
			]
		)
	scene_path.parent.mkdir(parents=True, exist_ok=True)
	scene_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
	print(scene_path)


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("--layout", type=Path, default=DEFAULT_LAYOUT)
	parser.add_argument("--scene", type=Path, default=DEFAULT_SCENE)
	args = parser.parse_args()
	build_scene(args.layout, args.scene)


if __name__ == "__main__":
	main()
