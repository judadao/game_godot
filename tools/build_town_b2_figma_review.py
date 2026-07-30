#!/usr/bin/env python3
"""Build the one-page Figma review board for isolated Town B2 candidates."""

from __future__ import annotations

import base64
import io
from pathlib import Path
from xml.sax.saxutils import escape

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
REFERENCE_PATH = (
	ROOT / "concept/town/main_horizontal_concept/town_style_direction_a_locked.png"
)
OUTPUT_PATH = ROOT / "design/figma/town/town_b2_building_landmark_review.svg"
PREVIEW_PATH = ROOT / "output/playwright/town_objects/town_b2_building_landmark_review.png"

BOARD_WIDTH = 5200
BOARD_HEIGHT = 3740
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
		"name": "材料行 / MATERIAL YARD",
		"kind": "BUILDING",
		"target": "300 × 240",
		"path": "design/figma/town/b2_candidates/material_yard_b2.png",
	},
	{
		"id": "player_forge",
		"name": "主角鐵匠鋪 / PLAYER FORGE",
		"kind": "BUILDING",
		"target": "360 × 316",
		"path": "design/figma/town/b2_candidates/player_forge_b2.png",
	},
	{
		"id": "town_hall",
		"name": "村長家 / TOWN HALL",
		"kind": "BUILDING",
		"target": "280 × 249",
		"path": "design/figma/town/b2_candidates/town_hall_b2.png",
	},
	{
		"id": "sword_soul_shop",
		"name": "劍魂商 / SWORD SOUL SHOP",
		"kind": "BUILDING",
		"target": "250 × 217",
		"path": "design/figma/town/b2_candidates/sword_soul_shop_b2.png",
	},
	{
		"id": "equipment_blueprint_shop",
		"name": "裝備圖紙商 / BLUEPRINT SHOP",
		"kind": "BUILDING",
		"target": "220 × 187",
		"path": "design/figma/town/b2_candidates/equipment_blueprint_shop_b2.png",
	},
	{
		"id": "far_east_residence",
		"name": "東郊民宅 / EAST RESIDENCE",
		"kind": "BUILDING",
		"target": "234 × 204",
		"path": "design/figma/town/b2_candidates/far_east_residence_b2.png",
	},
	{
		"id": "eternal_flame",
		"name": "不滅火炬 / ETERNAL FLAME",
		"kind": "LANDMARK",
		"target": "330 × 495",
		"path": "design/figma/town/b2_candidates/eternal_flame_b2.png",
	},
	{
		"id": "battle_portal",
		"name": "戰鬥傳送門 / BATTLE PORTAL",
		"kind": "LANDMARK",
		"target": "240 × 260",
		"path": "design/figma/town/b2_candidates/battle_portal_b2.png",
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
	reference: Image.Image,
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
			f'<image id="LockedAReference" width="{reference.width}" '
			f'height="{reference.height}" href="{_png_data_uri(reference)}"/>'
		),
	]
	for candidate, image in loaded:
		parts.append(
			f'<image id="Asset_{candidate["id"]}" width="{image.width}" '
			f'height="{image.height}" href="{_png_data_uri(image)}"/>'
		)
	parts.append("</defs>")

	_text(parts, "TOWN / B2 BUILDING + LANDMARK REVIEW", 100, 100, 54, TEXT, 700)
	_text(
		parts,
		"只看獨立物件｜未接 runtime｜六棟建築共用透視｜火炬與傳送門獨立審核",
		102,
		154,
		25,
		MUTED,
	)

	reference_x = 100
	reference_y = 250
	reference_width = 2500
	reference_height = reference.height * reference_width / reference.width
	_text(parts, "01 / LOCKED A COMPOSITION REFERENCE", reference_x, 224, 30, ACCENT, 700)
	parts.append(
		f'<rect x="{reference_x}" y="{reference_y}" width="{reference_width}" '
		f'height="{reference_height:g}" rx="24" fill="{PANEL}" '
		f'stroke="{ACCENT}" stroke-width="4"/>'
	)
	parts.append(
		f'<clipPath id="ReferenceClip"><rect x="{reference_x}" y="{reference_y}" '
		f'width="{reference_width}" height="{reference_height:g}" rx="24"/></clipPath>'
	)
	parts.append(
		f'<use href="#LockedAReference" clip-path="url(#ReferenceClip)" '
		f'transform="translate({reference_x} {reference_y}) '
		f'scale({reference_width / reference.width:g} '
		f'{reference_height / reference.height:g})"/>'
	)

	rules_x = 2740
	_text(parts, "REVIEW CHECKLIST", rules_x, 292, 34, TEXT, 700)
	rules = [
		"1  Front face dominant; narrow right side only",
		"2  Vertical posts stay vertical",
		"3  Foundation remains horizontal",
		"4  Warm upper-left light; cool shadow family",
		"5  Coarse hand-painted pixel clusters",
		"6  One clear function per silhouette",
		"7  No background / NPC / label / floating flag",
		"8  Approve objects individually before runtime use",
	]
	for index, rule in enumerate(rules):
		_text(parts, rule, rules_x, 362 + index * 70, 28, MUTED)
	parts.append(
		f'<rect x="{rules_x}" y="955" width="2260" height="250" rx="22" '
		f'fill="{PANEL}" stroke="{BORDER}" stroke-width="3"/>'
	)
	_text(parts, "B2 SHARED PROFILE", rules_x + 36, 1018, 26, ACCENT, 700)
	_text(
		parts,
		"orthographic pseudo-three-quarter / front + narrow right / upper-right recession",
		rules_x + 36,
		1072,
		25,
		TEXT,
	)
	_text(
		parts,
		"Target size is a review guide only; no production replacement in this round.",
		rules_x + 36,
		1130,
		24,
		MUTED,
	)

	_text(parts, "02 / ISOLATED B2 CANDIDATES", 100, 1420, 34, ACCENT, 700)
	card_width = 1220
	card_height = 1050
	gap = 40
	start_y = 1470
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
	draw.text((50, 36), "TOWN / B2 BUILDING + LANDMARK REVIEW", font=_font(27), fill=TEXT)
	ref = reference.resize((1250, round(1250 * reference.height / reference.width)))
	canvas.alpha_composite(ref, (50, 125))
	draw.text((1370, 145), "B2 ISOLATED CANDIDATES", font=_font(22), fill=ACCENT)
	draw.text(
		(1370, 195),
		"Front dominant / narrow right side / shared upper-left light",
		font=_font(15),
		fill=MUTED,
	)
	card_width = 610
	card_height = 525
	gap = 20
	start_y = 735
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
			Image.Resampling.LANCZOS,
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
	_build_svg(reference, loaded)
	_build_preview(reference, loaded)
	print(OUTPUT_PATH)
	print(PREVIEW_PATH)


if __name__ == "__main__":
	main()
