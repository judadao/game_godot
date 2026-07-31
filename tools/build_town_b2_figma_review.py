#!/usr/bin/env python3
"""Build the compact one-page Figma board for the approved Town Base set."""

from __future__ import annotations

import base64
import io
import json
from pathlib import Path
from typing import Any
from xml.sax.saxutils import escape

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
REFERENCE_PATH = (
	ROOT / "output/playwright/town_objects/town_modular_reconstructed_map.png"
)
LAYOUT_PATH = ROOT / "data/town_modular_layout.json"
OUTPUT_PATH = ROOT / "design/figma/town/town_base_building_landmark_map_review.svg"
PREVIEW_PATH = ROOT / "output/playwright/town_objects/town_base_building_landmark_map_review.png"

BOARD_WIDTH = 5200
BOARD_HEIGHT = 4300
BACKGROUND = "#10151a"
PANEL = "#1a2229"
CARD = "#222c34"
BORDER = "#40505d"
TEXT = "#f4eee0"
MUTED = "#a5b0b8"
ACCENT = "#d9aa50"
LANDMARK = "#8569d8"

CANDIDATES = [
	{
		"id": "material_yard",
		"layout_id": "material_yard",
		"name": "材料行 / MATERIAL YARD",
		"kind": "BUILDING",
		"target": "300 × 240",
		"path": "design/figma/town/b2_front_style_candidates/material_yard_front_style_b2.png",
	},
	{
		"id": "player_forge",
		"layout_id": "player_blacksmith",
		"name": "主角鐵匠鋪 / PLAYER FORGE",
		"kind": "BUILDING",
		"target": "360 × 316",
		"path": "design/figma/town/b2_front_style_candidates/player_forge_front_style_b2.png",
	},
	{
		"id": "town_hall",
		"layout_id": "town_hall",
		"name": "村長家 / TOWN HALL",
		"kind": "BUILDING",
		"target": "342 × 288",
		"path": "design/figma/town/b2_front_style_candidates/town_hall_front_style_base_v3.png",
	},
	{
		"id": "sword_soul_shop",
		"layout_id": "sword_soul_shop",
		"name": "劍魂商 / SWORD SOUL SHOP",
		"kind": "BUILDING",
		"target": "334 × 295",
		"path": "design/figma/town/b2_front_style_candidates/sword_soul_shop_front_style_base_v3.png",
	},
	{
		"id": "equipment_blueprint_shop",
		"layout_id": "equipment_blueprint_shop",
		"name": "裝備圖紙商 / BLUEPRINT SHOP",
		"kind": "BUILDING",
		"target": "334 × 295",
		"path": "design/figma/town/b2_front_style_candidates/equipment_blueprint_shop_front_style_base_v3.png",
	},
	{
		"id": "far_east_residence",
		"layout_id": "far_east_residence",
		"name": "東郊民宅 / EAST RESIDENCE",
		"kind": "BUILDING",
		"target": "298 × 331",
		"path": "design/figma/town/b2_front_style_candidates/far_east_residence_front_style_base_v3.png",
	},
	{
		"id": "eternal_flame",
		"layout_id": "eternal_flame",
		"name": "不滅火炬 / ETERNAL FLAME",
		"kind": "LANDMARK",
		"target": "345 × 560",
		"path": "assets/town/modular_v3/landmarks/eternal_forge_monument_base_v4.png",
	},
	{
		"id": "battle_portal",
		"layout_id": "battle_portal",
		"name": "戰鬥傳送門 / BATTLE PORTAL",
		"kind": "LANDMARK",
		"target": "200 × 240",
		"path": "assets/town/modular_v3/landmarks/battle_portal_base_v4.png",
	},
]


def _png_data_uri(image: Image.Image) -> str:
	buffer = io.BytesIO()
	image.save(buffer, "PNG", optimize=True)
	return "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode("ascii")


def _text(
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


def _fit(source: tuple[int, int], bounds: tuple[float, float]) -> tuple[float, float]:
	scale = min(bounds[0] / source[0], bounds[1] / source[1])
	return source[0] * scale, source[1] * scale


def _resource_file(resource_path: str) -> Path:
	if not resource_path.startswith("res://"):
		raise ValueError(f"Expected res:// source, got {resource_path}")
	return ROOT / resource_path.removeprefix("res://")


def _target_size(layer: dict[str, Any], image: Image.Image) -> tuple[float, float]:
	if "target_size" in layer:
		return float(layer["target_size"][0]), float(layer["target_size"][1])
	scale = layer["scale"]
	return image.width * float(scale[0]), image.height * float(scale[1])


def _compose_layers(
	size: tuple[int, int],
	layers: list[dict[str, Any]],
) -> Image.Image:
	canvas = Image.new("RGBA", size, (0, 0, 0, 0))
	for layer in sorted(layers, key=lambda item: int(item["z_index"])):
		image = Image.open(_resource_file(str(layer["source"]))).convert("RGBA")
		target_width, target_height = _target_size(layer, image)
		rendered = image.resize(
			(max(1, round(target_width)), max(1, round(target_height))),
			Image.Resampling.NEAREST,
		)
		position_x = float(layer["position"][0])
		position_y = float(layer["position"][1])
		canvas.alpha_composite(
			rendered,
			(
				round(position_x - rendered.width * 0.5),
				round(position_y - rendered.height * 0.5),
			),
		)
	return canvas


def _load_map_layers() -> tuple[
	Image.Image,
	Image.Image,
	list[tuple[dict[str, Any], Image.Image]],
]:
	payload = json.loads(LAYOUT_PATH.read_text(encoding="utf-8"))
	map_size = (int(payload["map"]["width"]), int(payload["map"]["height"]))
	visible_layers = [layer for layer in payload["layers"] if bool(layer["visible"])]
	layer_by_id = {str(layer["id"]): layer for layer in payload["layers"]}
	layout_ids = {str(candidate["layout_id"]) for candidate in CANDIDATES}

	missing = sorted(layout_ids - set(layer_by_id))
	if missing:
		raise ValueError(f"Town Base map is missing editable layers: {missing}")

	underlay = _compose_layers(
		map_size,
		[
			layer
			for layer in visible_layers
			if str(layer["id"]) not in layout_ids and int(layer["z_index"]) < -8
		],
	)
	overlay = _compose_layers(
		map_size,
		[
			layer
			for layer in visible_layers
			if str(layer["id"]) not in layout_ids and int(layer["z_index"]) > -8
		],
	)
	map_objects: list[tuple[dict[str, Any], Image.Image]] = []
	for candidate in CANDIDATES:
		layer = layer_by_id[str(candidate["layout_id"])]
		if not bool(layer["visible"]):
			continue
		image = Image.open(_resource_file(str(layer["source"]))).convert("RGBA")
		map_objects.append((layer, image))
	map_objects.sort(key=lambda item: int(item[0]["z_index"]))
	return underlay, overlay, map_objects


def _load_candidates() -> list[tuple[dict[str, str], Image.Image]]:
	loaded: list[tuple[dict[str, str], Image.Image]] = []
	for candidate in CANDIDATES:
		path = ROOT / candidate["path"]
		if not path.exists():
			raise FileNotFoundError(f"Missing Town B2 candidate: {path}")
		image = Image.open(path).convert("RGBA")
		if image.getextrema()[3][0] != 0:
			raise ValueError(f"Candidate has no transparent pixels: {path}")
		loaded.append((candidate, image))
	return loaded


def _build_svg(
	underlay: Image.Image,
	overlay: Image.Image,
	map_objects: list[tuple[dict[str, Any], Image.Image]],
	loaded: list[tuple[dict[str, str], Image.Image]],
) -> None:
	parts = [
		(
			f'<svg xmlns="http://www.w3.org/2000/svg" width="{BOARD_WIDTH}" '
			f'height="{BOARD_HEIGHT}" viewBox="0 0 {BOARD_WIDTH} {BOARD_HEIGHT}">'
		),
		f'<rect width="{BOARD_WIDTH}" height="{BOARD_HEIGHT}" fill="{BACKGROUND}"/>',
		"<defs>",
		(
			f'<image id="MapUnderlay" width="{underlay.width}" '
			f'height="{underlay.height}" href="{_png_data_uri(underlay)}"/>'
		),
		(
			f'<image id="MapOverlay" width="{overlay.width}" '
			f'height="{overlay.height}" href="{_png_data_uri(overlay)}"/>'
		),
	]
	for layer, image in map_objects:
		parts.append(
			f'<image id="MapAsset_{escape(str(layer["id"]))}" width="{image.width}" '
			f'height="{image.height}" href="{_png_data_uri(image)}"/>'
		)
	for candidate, image in loaded:
		parts.append(
			f'<image id="Asset_{candidate["id"]}" width="{image.width}" '
			f'height="{image.height}" href="{_png_data_uri(image)}"/>'
		)
	parts.append("</defs>")

	_text(parts, "TOWN / BASE MODULAR BUILDINGS + TOWN MAP", 100, 100, 54, TEXT, 700)
	_text(
		parts,
		"Runtime composition｜Locked A 背景排版｜Base 前景可替換｜y=672 共用基線",
		102,
		154,
		25,
		MUTED,
	)

	reference_x = 100
	reference_y = 250
	reference_width = 3884
	reference_height = 1618
	_text(parts, "01 / FULL MAP PLACEMENT AUDIT · 1942 × 809", reference_x, 224, 30, ACCENT, 700)
	parts.append(
		f'<rect x="{reference_x}" y="{reference_y}" width="{reference_width}" '
		f'height="{reference_height:g}" rx="24" fill="{PANEL}" '
		f'stroke="{ACCENT}" stroke-width="4"/>'
	)
	parts.append(
		f'<clipPath id="ReferenceClip"><rect x="{reference_x}" y="{reference_y}" '
		f'width="{reference_width}" height="{reference_height:g}" rx="24"/></clipPath>'
	)
	parts.append('<g id="EditableTownMap" clip-path="url(#ReferenceClip)">')
	parts.append(
		f'<g id="Map_BackgroundAndGround"><use href="#MapUnderlay" '
		f'transform="translate({reference_x} {reference_y}) scale(2)"/></g>'
	)
	for layer, image in map_objects:
		target_width, target_height = _target_size(layer, image)
		position_x = float(layer["position"][0])
		position_y = float(layer["position"][1])
		image_x = reference_x + (position_x - target_width * 0.5) * 2
		image_y = reference_y + (position_y - target_height * 0.5) * 2
		parts.append(
			f'<g id="MapObject_{escape(str(layer["id"]))}" '
			f'data-source="{escape(str(layer["source"]))}">'
		)
		parts.append(
			f'<use href="#MapAsset_{escape(str(layer["id"]))}" '
			f'transform="translate({image_x:g} {image_y:g}) '
			f'scale({target_width * 2 / image.width:g} '
			f'{target_height * 2 / image.height:g})"/>'
		)
		parts.append("</g>")
	parts.append(
		f'<g id="Map_ForegroundProps"><use href="#MapOverlay" '
		f'transform="translate({reference_x} {reference_y}) scale(2)"/></g>'
	)
	parts.append("</g>")

	rules_x = 4100
	_text(parts, "PLACEMENT CHECK", rules_x, 292, 30, TEXT, 700)
	rules = [
		"1  Foundation y=672",
		"2  No stretched object",
		"3  No accidental gap",
		"4  No facade collision",
		"5  Background unchanged",
		"6  Portal + flame read as one",
		"7  Neutral Base lighting",
		"8  Each object replaceable",
	]
	for index, rule in enumerate(rules):
		_text(parts, rule, rules_x, 362 + index * 64, 22, MUTED)
	parts.append(
		f'<rect x="{rules_x}" y="930" width="1000" height="280" rx="22" '
		f'fill="{PANEL}" stroke="{BORDER}" stroke-width="3"/>'
	)
	_text(parts, "BASE SHARED PROFILE", rules_x + 36, 993, 25, ACCENT, 700)
	_text(
		parts,
		"Neutral structural AO",
		rules_x + 36,
		1047,
		22,
		TEXT,
	)
	_text(
		parts,
		"Broad light stays in Godot.",
		rules_x + 36,
		1102,
		22,
		MUTED,
	)

	_text(parts, "02 / ISOLATED BASE OBJECTS", 100, 1950, 34, ACCENT, 700)
	card_width = 1220
	card_height = 1050
	gap = 40
	start_y = 2000
	for index, (candidate, image) in enumerate(loaded):
		column = index % 4
		row = index // 4
		x = 100 + column * (card_width + gap)
		y = start_y + row * (card_height + gap)
		accent = LANDMARK if candidate["kind"] == "LANDMARK" else ACCENT
		parts.append(
			f'<g id="Candidate_{candidate["id"]}" data-kind="{candidate["kind"]}">'
		)
		parts.append(
			f'<rect x="{x}" y="{y}" width="{card_width}" height="{card_height}" '
			f'rx="24" fill="{CARD}" stroke="{accent}" stroke-width="3"/>'
		)
		_text(parts, candidate["name"], x + 32, y + 55, 28, TEXT, 700)
		_text(
			parts,
			f'{candidate["kind"]}  ·  GAME TARGET {candidate["target"]}',
			x + 32,
			y + 95,
			21,
			accent,
			700,
		)
		panel_x = x + 32
		panel_y = y + 125
		panel_width = card_width - 64
		panel_height = card_height - 170
		parts.append(
			f'<rect x="{panel_x}" y="{panel_y}" width="{panel_width}" '
			f'height="{panel_height}" rx="18" fill="{PANEL}"/>'
		)
		render_width, render_height = _fit(
			image.size,
			(panel_width - 60, panel_height - 70),
		)
		image_x = panel_x + (panel_width - render_width) * 0.5
		image_y = panel_y + panel_height - render_height - 28
		parts.append(
			f'<use href="#Asset_{candidate["id"]}" '
			f'transform="translate({image_x:g} {image_y:g}) '
			f'scale({render_width / image.width:g} {render_height / image.height:g})"/>'
		)
		baseline_y = panel_y + panel_height - 28
		parts.append(
			f'<line x1="{panel_x + 24}" y1="{baseline_y}" '
			f'x2="{panel_x + panel_width - 24}" y2="{baseline_y}" '
			f'stroke="{BORDER}" stroke-width="2" stroke-dasharray="12 10"/>'
		)
		parts.append("</g>")
	parts.append("</svg>")
	OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
	OUTPUT_PATH.write_text("\n".join(parts), encoding="utf-8")


def _font(size: int) -> ImageFont.ImageFont:
	for path in [
		"/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
		"/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
	]:
		if Path(path).exists():
			return ImageFont.truetype(path, size)
	return ImageFont.load_default()


def _build_preview(
	reference: Image.Image,
	loaded: list[tuple[dict[str, str], Image.Image]],
) -> None:
	scale = 0.5
	canvas = Image.new(
		"RGBA",
		(round(BOARD_WIDTH * scale), round(BOARD_HEIGHT * scale)),
		(16, 21, 26, 255),
	)
	draw = ImageDraw.Draw(canvas)
	draw.text((50, 36), "TOWN / BASE MODULAR BUILDINGS + TOWN MAP", font=_font(27), fill=TEXT)
	ref = reference.resize((1942, 809), Image.Resampling.NEAREST)
	canvas.alpha_composite(ref, (50, 125))
	draw.text((2030, 145), "BASE ISOLATED OBJECTS", font=_font(22), fill=ACCENT)
	draw.text(
		(2030, 195),
		"Neutral Base / shared baseline / runtime composition",
		font=_font(15),
		fill=MUTED,
	)
	card_width = 610
	card_height = 525
	gap = 20
	start_y = 1000
	for index, (candidate, image) in enumerate(loaded):
		column = index % 4
		row = index // 4
		x = 50 + column * (card_width + gap)
		y = start_y + row * (card_height + gap)
		draw.rounded_rectangle(
			(x, y, x + card_width, y + card_height),
			radius=12,
			fill=CARD,
			outline=LANDMARK if candidate["kind"] == "LANDMARK" else ACCENT,
			width=2,
		)
		draw.text((x + 16, y + 14), candidate["name"], font=_font(15), fill=TEXT)
		draw.text(
			(x + 16, y + 45),
			f'{candidate["kind"]} · {candidate["target"]}',
			font=_font(12),
			fill=LANDMARK if candidate["kind"] == "LANDMARK" else ACCENT,
		)
		render_width, render_height = _fit(image.size, (card_width - 44, card_height - 100))
		render = image.resize(
			(max(1, round(render_width)), max(1, round(render_height))),
			Image.Resampling.NEAREST,
		)
		canvas.alpha_composite(
			render,
			(
				round(x + (card_width - render.width) * 0.5),
				round(y + card_height - render.height - 14),
			),
		)
	PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
	canvas.convert("RGB").save(PREVIEW_PATH, "PNG", optimize=True)


def main() -> None:
	if not REFERENCE_PATH.exists():
		raise FileNotFoundError(f"Missing locked Town reference: {REFERENCE_PATH}")
	reference = Image.open(REFERENCE_PATH).convert("RGBA")
	loaded = _load_candidates()
	underlay, overlay, map_objects = _load_map_layers()
	_build_svg(underlay, overlay, map_objects, loaded)
	_build_preview(reference, loaded)
	print(OUTPUT_PATH)
	print(PREVIEW_PATH)


if __name__ == "__main__":
	main()
