#!/usr/bin/env python3
"""Build a one-page Figma SVG from individually replaceable Town objects."""

from __future__ import annotations

import argparse
import base64
import io
import json
import math
from pathlib import Path
from typing import Any
from xml.sax.saxutils import escape

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LAYOUT = ROOT / "data/town_modular_layout.json"
DEFAULT_OUTPUT = (
	ROOT / "output/playwright/town_objects/town_modular_objects_figma.svg"
)
DEFAULT_PREVIEW = (
	ROOT / "output/playwright/town_objects/town_modular_reconstructed_map.png"
)
MAP_SCALE = 2.0
BOARD_WIDTH = 6000
BOARD_BACKGROUND = "#11161b"
PANEL = "#1b2229"
CARD = "#232c34"
BORDER = "#3b4853"
TEXT = "#f3eee2"
MUTED = "#9eabb5"
ACCENT = "#d8a84f"
CATEGORY_ORDER = ["background", "ground", "facility", "landmark", "street_prop"]
CATEGORY_LABELS = {
	"background": "背景分層",
	"ground": "地板模組",
	"facility": "房屋／設施",
	"landmark": "核心地標",
	"street_prop": "街道物件",
}


def _resource_file(resource_path: str) -> Path:
	if not resource_path.startswith("res://"):
		raise ValueError(f"Expected res:// source, got {resource_path}")
	return ROOT / resource_path.removeprefix("res://")


def _png_data_uri(image: Image.Image) -> str:
	buffer = io.BytesIO()
	image.save(buffer, "PNG", optimize=True)
	return "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode("ascii")


def _svg_text(
	parts: list[str],
	value: str,
	x: float,
	y: float,
	size: int,
	color: str,
	weight: int = 400,
) -> None:
	parts.append(
		f'<text x="{x:g}" y="{y:g}" fill="{color}" '
		f'font-family="Noto Sans CJK TC, sans-serif" font-size="{size}" '
		f'font-weight="{weight}">{escape(value)}</text>'
	)


def _target_size(layer: dict[str, Any], image: Image.Image) -> tuple[float, float]:
	if "target_size" in layer:
		return float(layer["target_size"][0]), float(layer["target_size"][1])
	scale = layer["scale"]
	return image.width * float(scale[0]), image.height * float(scale[1])


def _fit_size(
	source_size: tuple[int, int],
	bounds: tuple[float, float],
) -> tuple[float, float]:
	scale = min(bounds[0] / max(1, source_size[0]), bounds[1] / max(1, source_size[1]))
	return source_size[0] * scale, source_size[1] * scale


def _load_assets(
	layers: list[dict[str, Any]],
) -> dict[str, Image.Image]:
	assets: dict[str, Image.Image] = {}
	for layer in layers:
		source = str(layer["source"])
		if source in assets:
			continue
		path = _resource_file(source)
		if not path.exists():
			raise FileNotFoundError(f"Missing modular Town object: {path}")
		assets[source] = Image.open(path).convert("RGBA")
	return assets


def _build_map(
	parts: list[str],
	payload: dict[str, Any],
	layers: list[dict[str, Any]],
	assets: dict[str, Image.Image],
	asset_ids: dict[str, str],
	x: float,
	y: float,
) -> tuple[float, float]:
	map_width = float(payload["map"]["width"])
	map_height = float(payload["map"]["height"])
	render_width = map_width * MAP_SCALE
	render_height = map_height * MAP_SCALE
	parts.append(
		f'<rect x="{x:g}" y="{y:g}" width="{render_width:g}" height="{render_height:g}" '
		f'rx="24" fill="#202832" stroke="{BORDER}" stroke-width="3"/>'
	)
	parts.append(
		f'<clipPath id="townMapClip"><rect x="{x:g}" y="{y:g}" '
		f'width="{render_width:g}" height="{render_height:g}" rx="24"/></clipPath>'
	)
	parts.append(f'<g id="ReconstructedTownMap" clip-path="url(#townMapClip)">')
	for layer in sorted(
		(layer for layer in layers if bool(layer["visible"])),
		key=lambda item: int(item["z_index"]),
	):
		image = assets[str(layer["source"])]
		target_width, target_height = _target_size(layer, image)
		position_x = float(layer["position"][0])
		position_y = float(layer["position"][1])
		image_x = x + (position_x - target_width * 0.5) * MAP_SCALE
		image_y = y + (position_y - target_height * 0.5) * MAP_SCALE
		parts.append(
			f'<g id="MapObject_{escape(str(layer["id"]))}" '
			f'data-category="{escape(str(layer["category"]))}" '
			f'data-source="{escape(str(layer["source"]))}">'
		)
		parts.append(
			f'<use href="#{asset_ids[str(layer["source"])]}" '
			f'transform="translate({image_x:g} {image_y:g}) '
			f'scale({target_width * MAP_SCALE / image.width:g} '
			f'{target_height * MAP_SCALE / image.height:g})"/>'
		)
		parts.append("</g>")
	parts.append("</g>")
	return render_width, render_height


def _build_preview(
	payload: dict[str, Any],
	layers: list[dict[str, Any]],
	assets: dict[str, Image.Image],
	output_path: Path,
) -> None:
	map_width = int(payload["map"]["width"])
	map_height = int(payload["map"]["height"])
	canvas = Image.new("RGBA", (map_width, map_height), (0, 0, 0, 0))
	for layer in sorted(
		(layer for layer in layers if bool(layer["visible"])),
		key=lambda item: int(item["z_index"]),
	):
		image = assets[str(layer["source"])]
		target_width, target_height = _target_size(layer, image)
		target = image.resize(
			(max(1, round(target_width)), max(1, round(target_height))),
			Image.Resampling.LANCZOS,
		)
		position_x = float(layer["position"][0])
		position_y = float(layer["position"][1])
		canvas.alpha_composite(
			target,
			(
				round(position_x - target.width * 0.5),
				round(position_y - target.height * 0.5),
			),
		)
	output_path.parent.mkdir(parents=True, exist_ok=True)
	canvas.save(output_path, "PNG", optimize=True)
	print(output_path)


def _build_library(
	parts: list[str],
	layers: list[dict[str, Any]],
	assets: dict[str, Image.Image],
	asset_ids: dict[str, str],
	start_y: float,
) -> float:
	unique_layers: list[dict[str, Any]] = []
	seen_sources: set[str] = set()
	for layer in layers:
		source = str(layer["source"])
		if source in seen_sources:
			continue
		seen_sources.add(source)
		unique_layers.append(layer)

	card_width = 560
	card_height = 470
	gap = 28
	columns = 10
	current_y = start_y
	for category in CATEGORY_ORDER:
		category_layers = [
			layer for layer in unique_layers if str(layer["category"]) == category
		]
		if not category_layers:
			continue
		_svg_text(parts, CATEGORY_LABELS[category], 100, current_y + 40, 36, TEXT, 700)
		_svg_text(
			parts,
			f"{len(category_layers)} 個獨立來源素材｜每個皆可單獨選取與替換",
			100,
			current_y + 78,
			20,
			MUTED,
		)
		grid_y = current_y + 110
		for index, layer in enumerate(category_layers):
			column = index % columns
			row = index // columns
			card_x = 100 + column * (card_width + gap)
			card_y = grid_y + row * (card_height + gap)
			source = str(layer["source"])
			image = assets[source]
			parts.append(f'<g id="LibraryObject_{escape(str(layer["id"]))}">')
			parts.append(
				f'<rect x="{card_x}" y="{card_y}" width="{card_width}" '
				f'height="{card_height}" rx="18" fill="{CARD}" '
				f'stroke="{BORDER}" stroke-width="2"/>'
			)
			target_width, target_height = _fit_size(
				image.size,
				(card_width - 36, card_height - 122),
			)
			image_x = card_x + (card_width - target_width) * 0.5
			image_y = card_y + 18 + (card_height - 122 - target_height) * 0.5
			parts.append(
				f'<use href="#{asset_ids[source]}" '
				f'transform="translate({image_x:g} {image_y:g}) '
				f'scale({target_width / image.width:g} {target_height / image.height:g})"/>'
			)
			_svg_text(parts, str(layer["id"]), card_x + 18, card_y + card_height - 65, 22, TEXT, 700)
			_svg_text(parts, source, card_x + 18, card_y + card_height - 31, 15, MUTED)
			parts.append("</g>")
		rows = math.ceil(len(category_layers) / columns)
		current_y = grid_y + rows * (card_height + gap) + 60
	return current_y


def build_board(layout_path: Path, output_path: Path, preview_path: Path) -> None:
	payload = json.loads(layout_path.read_text(encoding="utf-8"))
	layers = payload["layers"]
	assets = _load_assets(layers)
	asset_ids = {
		source: f"SourceAsset_{index + 1:02d}"
		for index, source in enumerate(sorted(assets))
	}
	map_x = 100
	map_y = 260
	map_width = float(payload["map"]["width"]) * MAP_SCALE
	library_y = map_y + float(payload["map"]["height"]) * MAP_SCALE + 150
	probe: list[str] = []
	final_height = _build_library(probe, layers, assets, asset_ids, library_y)
	parts = [
		f'<svg xmlns="http://www.w3.org/2000/svg" width="{BOARD_WIDTH}" '
		f'height="{math.ceil(final_height + 100)}" viewBox="0 0 {BOARD_WIDTH} {math.ceil(final_height + 100)}">',
		f'<rect width="{BOARD_WIDTH}" height="{math.ceil(final_height + 100)}" fill="{BOARD_BACKGROUND}"/>',
		"<defs>",
	]
	for source in sorted(assets):
		image = assets[source]
		parts.append(
			f'<image id="{asset_ids[source]}" width="{image.width}" height="{image.height}" '
			f'href="{_png_data_uri(image)}"/>'
		)
	parts.append("</defs>")
	_svg_text(parts, "TOWN / HAND-DRAWN MODULAR OBJECT MAP", 100, 102, 54, TEXT, 700)
	_svg_text(
		parts,
		(
			"每個畫面元素都是有 ID 的獨立物件｜"
			f"風格：{payload.get('visual_style', 'unspecified')}｜"
			"上方為重組地圖｜下方為可替換素材庫"
		),
		102,
		152,
		24,
		MUTED,
	)
	_svg_text(
		parts,
		f"{len(layers)} 個地圖 instances｜{len(assets)} 個獨立 source assets",
		map_x + map_width + 80,
		map_y + 50,
		28,
		ACCENT,
		700,
	)
	_build_map(parts, payload, layers, assets, asset_ids, map_x, map_y)
	_build_library(parts, layers, assets, asset_ids, library_y)
	parts.append("</svg>")
	output_path.parent.mkdir(parents=True, exist_ok=True)
	output_path.write_text("\n".join(parts), encoding="utf-8")
	print(output_path)
	_build_preview(payload, layers, assets, preview_path)


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("--layout", type=Path, default=DEFAULT_LAYOUT)
	parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
	parser.add_argument("--preview", type=Path, default=DEFAULT_PREVIEW)
	args = parser.parse_args()
	build_board(args.layout, args.output, args.preview)


if __name__ == "__main__":
	main()
