#!/usr/bin/env python3
"""Build one-page current Town object inventory for Figma import."""

from __future__ import annotations

import argparse
import base64
import io
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable
from xml.sax.saxutils import escape

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
CANVAS_SIZE = (3840, 2500)
BACKGROUND = "#11161b"
PANEL = "#1b2229"
CARD = "#232c34"
BORDER = "#3b4853"
TEXT = "#f3eee2"
MUTED = "#9eabb5"
ACCENT = "#d8a84f"
FONT_REGULAR = "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"
FONT_BOLD = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"


@dataclass(frozen=True)
class AssetItem:
	label: str
	source: str
	region: tuple[int, int, int, int] | None = None
	note: str = ""


BUILDINGS = [
	AssetItem("材料場住宅", "assets/town/rebuild_v2/town_buildings_atlas_v2.png", (64, 72, 410, 402), "WestHouse"),
	AssetItem("道具商店", "assets/town/rebuild_v2/town_buildings_atlas_v2.png", (64, 552, 390, 370), "ItemShop"),
	AssetItem("鍛造塔屋", "assets/town/rebuild_v2/town_buildings_atlas_v2.png", (990, 530, 480, 394), "Blacksmith"),
	AssetItem("市集商店", "assets/town/rebuild_v2/town_buildings_atlas_v2.png", (494, 552, 400, 370), "MarketStall"),
	AssetItem("市政住宅", "assets/town/rebuild_v2/town_buildings_atlas_v2.png", (494, 72, 380, 402), "TownHall"),
	AssetItem("藍圖塔屋", "assets/town/rebuild_v2/town_buildings_atlas_v2.png", (914, 40, 550, 434), "BlueprintShop"),
]

PROPS = [
	AssetItem("入口柵欄", "assets/town/rebuild_v2/town_props_portals_atlas_v2.png", (50, 440, 320, 190), "EntranceFence"),
	AssetItem("街燈", "assets/town/rebuild_v2/town_props_portals_atlas_v2.png", (790, 45, 155, 350), "ResidentialLamp"),
	AssetItem("公告欄", "assets/town/rebuild_v2/town_props_portals_atlas_v2.png", (405, 55, 310, 330), "NoticeBoard"),
	AssetItem("水井", "assets/town/rebuild_v2/town_props_portals_atlas_v2.png", (52, 50, 300, 332), "CivicWell"),
	AssetItem("長椅", "assets/town/rebuild_v2/town_props_portals_atlas_v2.png", (1040, 120, 390, 260), "CivicBench"),
	AssetItem("市場推車", "assets/town/rebuild_v2/town_props_portals_atlas_v2.png", (345, 680, 300, 290), "MarketCart"),
	AssetItem("鍛造爐", "assets/town/rebuild_v2/town_props_portals_atlas_v2.png", (45, 690, 300, 280), "SmithForge"),
	AssetItem("木箱堆", "assets/town/rebuild_v2/town_props_portals_atlas_v2.png", (410, 420, 270, 235), "CratePile"),
	AssetItem("木桶堆", "assets/town/rebuild_v2/town_props_portals_atlas_v2.png", (740, 420, 260, 245), "BarrelPile"),
	AssetItem("花圃", "assets/town/rebuild_v2/town_props_portals_atlas_v2.png", (1050, 440, 390, 200), "FlowerBed"),
	AssetItem("武器招牌", "assets/town/generated/town_signs_atlas.png", (0, 0, 384, 341), "WeaponSign"),
	AssetItem("藥水招牌", "assets/town/generated/town_signs_atlas.png", (768, 0, 384, 341), "PotionSign"),
	AssetItem("旅店招牌", "assets/town/generated/town_signs_atlas.png", (1152, 0, 384, 341), "InnSign"),
	AssetItem("空白門牌", "assets/town/generated/town_signs_atlas.png", (768, 682, 384, 342), "BlankSign"),
]

NPCS = [
	AssetItem("鎮長", "assets/town/rebuild_v2/town_npcs_atlas_v2.png", (36, 54, 274, 590), "Mayor"),
	AssetItem("村民", "assets/town/rebuild_v2/town_npcs_atlas_v2.png", (1535, 54, 280, 590), "VillagerMale"),
	AssetItem("藍圖商人", "assets/town/rebuild_v2/town_npcs_atlas_v2.png", (1840, 54, 270, 590), "EquipmentMerchant"),
	AssetItem("守衛", "assets/town/rebuild_v2/town_npcs_atlas_v2.png", (1235, 40, 300, 610), "Guard"),
	AssetItem("道具商人", "assets/town/rebuild_v2/town_npcs_atlas_v2.png", (330, 54, 280, 590), "ItemMerchant"),
	AssetItem("鐵匠", "assets/town/rebuild_v2/town_npcs_atlas_v2.png", (620, 54, 300, 590), "Blacksmith"),
	AssetItem("旅店主人", "assets/town/rebuild_v2/town_npcs_atlas_v2.png", (930, 54, 300, 590), "Innkeeper"),
	AssetItem("戰鬥傳送門", "assets/town/rebuild_v2/town_props_portals_atlas_v2.png", (1080, 660, 220, 320), "BattleGateway"),
]


def _font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
	path = FONT_BOLD if bold else FONT_REGULAR
	return ImageFont.truetype(path, size=size)


def _load_item(item: AssetItem) -> Image.Image:
	image = Image.open(ROOT / item.source).convert("RGBA")
	if item.region is not None:
		x, y, width, height = item.region
		image = image.crop((x, y, x + width, y + height))
	alpha = image.getchannel("A")
	bounds = alpha.getbbox()
	return image.crop(bounds) if bounds is not None else image


def _contain_size(size: tuple[int, int], bounds: tuple[int, int]) -> tuple[int, int]:
	width, height = size
	max_width, max_height = bounds
	scale = min(max_width / max(1, width), max_height / max(1, height))
	return max(1, round(width * scale)), max(1, round(height * scale))


def _png_data_uri(image: Image.Image) -> str:
	buffer = io.BytesIO()
	image.save(buffer, "PNG", optimize=True)
	return "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode("ascii")


def _draw_section_title(draw: ImageDraw.ImageDraw, title: str, x: int, y: int, note: str) -> None:
	draw.text((x, y), title, font=_font(34, True), fill=TEXT)
	draw.text((x, y + 47), note, font=_font(20), fill=MUTED)


def _draw_card(
	canvas: Image.Image,
	draw: ImageDraw.ImageDraw,
	item: AssetItem,
	rect: tuple[int, int, int, int],
) -> None:
	x, y, width, height = rect
	draw.rounded_rectangle((x, y, x + width, y + height), radius=18, fill=CARD, outline=BORDER, width=2)
	image = _load_item(item)
	target = _contain_size(image.size, (width - 34, height - 94))
	image = image.resize(target, Image.Resampling.LANCZOS)
	image_x = x + (width - image.width) // 2
	image_y = y + 16 + (height - 94 - image.height) // 2
	canvas.alpha_composite(image, (image_x, image_y))
	draw.text((x + 18, y + height - 66), item.label, font=_font(23, True), fill=TEXT)
	draw.text((x + 18, y + height - 35), item.note, font=_font(16), fill=MUTED)


def _svg_text(parts: list[str], value: str, x: float, y: float, size: int, color: str, weight: int = 400) -> None:
	parts.append(
		f'<text x="{x}" y="{y}" fill="{color}" font-family="Noto Sans CJK TC" '
		f'font-size="{size}" font-weight="{weight}">{escape(value)}</text>'
	)


def _svg_card(parts: list[str], item: AssetItem, rect: tuple[int, int, int, int]) -> None:
	x, y, width, height = rect
	parts.append(f'<g id="{escape(item.note or item.label)}">')
	parts.append(
		f'<rect x="{x}" y="{y}" width="{width}" height="{height}" rx="18" '
		f'fill="{CARD}" stroke="{BORDER}" stroke-width="2"/>'
	)
	image = _load_item(item)
	target = _contain_size(image.size, (width - 34, height - 94))
	image_x = x + (width - target[0]) / 2
	image_y = y + 16 + (height - 94 - target[1]) / 2
	parts.append(
		f'<image x="{image_x}" y="{image_y}" width="{target[0]}" height="{target[1]}" '
		f'href="{_png_data_uri(image)}" preserveAspectRatio="xMidYMid meet"/>'
	)
	_svg_text(parts, item.label, x + 18, y + height - 43, 23, TEXT, 700)
	_svg_text(parts, item.note, x + 18, y + height - 17, 16, MUTED)
	parts.append("</g>")


def _grid_rects(
	origin: tuple[int, int],
	columns: int,
	card_size: tuple[int, int],
	gap: tuple[int, int],
	count: int,
) -> Iterable[tuple[int, int, int, int]]:
	for index in range(count):
		column = index % columns
		row = index // columns
		yield (
			origin[0] + column * (card_size[0] + gap[0]),
			origin[1] + row * (card_size[1] + gap[1]),
			card_size[0],
			card_size[1],
		)


def _build_png(output: Path) -> None:
	canvas = Image.new("RGBA", CANVAS_SIZE, BACKGROUND)
	draw = ImageDraw.Draw(canvas)
	draw.text((100, 54), "TOWN OBJECTS — CURRENT INVENTORY", font=_font(54, True), fill=TEXT)
	draw.text(
		(102, 124),
		"現有素材整理｜不含新風格提案｜來源：正式 Town 場景與仍保留的可拆物件層",
		font=_font(24),
		fill=MUTED,
	)

	_draw_section_title(draw, "目前正式城鎮畫面", 100, 190, "Eternal Forge panorama｜主場景目前的可見背景")
	panorama = Image.open(ROOT / "assets/town/eternal_forge/town_eternal_forge_v1.png").convert("RGBA")
	panorama_size = _contain_size(panorama.size, (1770, 700))
	panorama = panorama.resize(panorama_size, Image.Resampling.LANCZOS)
	draw.rounded_rectangle((100, 280, 1870, 980), radius=22, fill=PANEL, outline=BORDER, width=2)
	canvas.alpha_composite(panorama, (100 + (1770 - panorama.width) // 2, 280 + (700 - panorama.height) // 2))

	_draw_section_title(draw, "現有建築物件", 1980, 190, "TownBuildings｜主場景保留、目前 hidden")
	for item, rect in zip(BUILDINGS, _grid_rects((1980, 280), 3, (560, 330), (28, 28), len(BUILDINGS))):
		_draw_card(canvas, draw, item, rect)

	_draw_section_title(draw, "現有街道物件與招牌", 100, 1050, "TownStreetProps + generated signs｜主場景保留、目前 hidden")
	for item, rect in zip(PROPS, _grid_rects((100, 1140), 7, (326, 360), (20, 24), len(PROPS))):
		_draw_card(canvas, draw, item, rect)

	_draw_section_title(draw, "目前 NPC 與傳送門", 2540, 1050, "TownNPCs + BattleGateway｜主場景目前可見")
	for item, rect in zip(NPCS, _grid_rects((2540, 1140), 4, (280, 360), (22, 24), len(NPCS))):
		_draw_card(canvas, draw, item, rect)

	_draw_section_title(draw, "現有地面素材", 100, 1960, "TownStreetGround｜主場景保留、目前 hidden")
	ground = Image.open(ROOT / "assets/town/rebuild_v2/town_ground_continuous.png").convert("RGBA")
	ground_size = _contain_size(ground.size, (2420, 400))
	ground = ground.resize(ground_size, Image.Resampling.LANCZOS)
	draw.rounded_rectangle((100, 2050, 2500, 2420), radius=22, fill=PANEL, outline=BORDER, width=2)
	canvas.alpha_composite(ground, (100 + (2400 - ground.width) // 2, 2050 + (370 - ground.height) // 2))

	draw.rounded_rectangle((2540, 1960, 3740, 2420), radius=22, fill=PANEL, outline=BORDER, width=2)
	draw.text((2585, 2010), "整理範圍", font=_font(30, True), fill=ACCENT)
	lines = [
		"• 1 張目前正式全景",
		"• 6 棟既有建築",
		"• 10 個街道物件",
		"• 4 種既有招牌",
		"• 7 名目前 NPC",
		"• 1 個戰鬥傳送門",
		"• 1 張連續地面素材",
	]
	for index, line in enumerate(lines):
		draw.text((2585, 2075 + index * 43), line, font=_font(22), fill=TEXT)
	draw.text((2585, 2380), "用途：Figma 單頁現況盤點", font=_font(18), fill=MUTED)
	canvas.convert("RGB").save(output, "PNG", optimize=True)


def _build_svg(output: Path) -> None:
	width, height = CANVAS_SIZE
	parts = [
		f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
		f'<rect width="{width}" height="{height}" fill="{BACKGROUND}"/>',
	]
	_svg_text(parts, "TOWN OBJECTS — CURRENT INVENTORY", 100, 102, 54, TEXT, 700)
	_svg_text(parts, "現有素材整理｜不含新風格提案｜來源：正式 Town 場景與仍保留的可拆物件層", 102, 150, 24, MUTED)

	_svg_text(parts, "目前正式城鎮畫面", 100, 226, 34, TEXT, 700)
	_svg_text(parts, "Eternal Forge panorama｜主場景目前的可見背景", 100, 263, 20, MUTED)
	parts.append(f'<rect x="100" y="280" width="1770" height="700" rx="22" fill="{PANEL}" stroke="{BORDER}" stroke-width="2"/>')
	panorama = Image.open(ROOT / "assets/town/eternal_forge/town_eternal_forge_v1.png").convert("RGB")
	panorama_size = _contain_size(panorama.size, (1770, 700))
	parts.append(
		f'<image id="CurrentTownPanorama" x="{100 + (1770 - panorama_size[0]) / 2}" '
		f'y="{280 + (700 - panorama_size[1]) / 2}" width="{panorama_size[0]}" height="{panorama_size[1]}" '
		f'href="{_png_data_uri(panorama)}"/>'
	)

	_svg_text(parts, "現有建築物件", 1980, 226, 34, TEXT, 700)
	_svg_text(parts, "TownBuildings｜主場景保留、目前 hidden", 1980, 263, 20, MUTED)
	for item, rect in zip(BUILDINGS, _grid_rects((1980, 280), 3, (560, 330), (28, 28), len(BUILDINGS))):
		_svg_card(parts, item, rect)

	_svg_text(parts, "現有街道物件與招牌", 100, 1086, 34, TEXT, 700)
	_svg_text(parts, "TownStreetProps + generated signs｜主場景保留、目前 hidden", 100, 1123, 20, MUTED)
	for item, rect in zip(PROPS, _grid_rects((100, 1140), 7, (326, 360), (20, 24), len(PROPS))):
		_svg_card(parts, item, rect)

	_svg_text(parts, "目前 NPC 與傳送門", 2540, 1086, 34, TEXT, 700)
	_svg_text(parts, "TownNPCs + BattleGateway｜主場景目前可見", 2540, 1123, 20, MUTED)
	for item, rect in zip(NPCS, _grid_rects((2540, 1140), 4, (280, 360), (22, 24), len(NPCS))):
		_svg_card(parts, item, rect)

	_svg_text(parts, "現有地面素材", 100, 1996, 34, TEXT, 700)
	_svg_text(parts, "TownStreetGround｜主場景保留、目前 hidden", 100, 2033, 20, MUTED)
	parts.append(f'<rect x="100" y="2050" width="2400" height="370" rx="22" fill="{PANEL}" stroke="{BORDER}" stroke-width="2"/>')
	ground = Image.open(ROOT / "assets/town/rebuild_v2/town_ground_continuous.png").convert("RGBA")
	ground_size = _contain_size(ground.size, (2420, 400))
	parts.append(
		f'<image id="TownStreetGround" x="{100 + (2400 - ground_size[0]) / 2}" '
		f'y="{2050 + (370 - ground_size[1]) / 2}" width="{ground_size[0]}" height="{ground_size[1]}" '
		f'href="{_png_data_uri(ground)}"/>'
	)

	parts.append(f'<rect x="2540" y="1960" width="1200" height="460" rx="22" fill="{PANEL}" stroke="{BORDER}" stroke-width="2"/>')
	_svg_text(parts, "整理範圍", 2585, 2048, 30, ACCENT, 700)
	for index, line in enumerate([
		"• 1 張目前正式全景",
		"• 6 棟既有建築",
		"• 10 個街道物件",
		"• 4 種既有招牌",
		"• 7 名目前 NPC",
		"• 1 個戰鬥傳送門",
		"• 1 張連續地面素材",
	]):
		_svg_text(parts, line, 2585, 2100 + index * 43, 22, TEXT)
	_svg_text(parts, "用途：Figma 單頁現況盤點", 2585, 2390, 18, MUTED)
	parts.append("</svg>")
	output.write_text("\n".join(parts), encoding="utf-8")


def _build_manifest(output: Path) -> None:
	def encode(item: AssetItem) -> dict[str, object]:
		return {
			"label": item.label,
			"node_or_role": item.note,
			"source": item.source,
			"region": list(item.region) if item.region is not None else None,
		}

	payload = {
		"version": 1,
		"scope": "current_town_inventory",
		"authoritative_scene": "scenes/maps/town.tscn",
		"runtime_panorama": "assets/town/eternal_forge/town_eternal_forge_v1.png",
		"buildings": [encode(item) for item in BUILDINGS],
		"props_and_signs": [encode(item) for item in PROPS],
		"npcs_and_portal": [encode(item) for item in NPCS],
		"ground": "assets/town/rebuild_v2/town_ground_continuous.png",
	}
	output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument(
		"--output-dir",
		default="output/playwright/town_objects",
		help="Directory for PNG, SVG, and manifest outputs.",
	)
	args = parser.parse_args()
	output_dir = ROOT / args.output_dir
	output_dir.mkdir(parents=True, exist_ok=True)
	_build_png(output_dir / "town_objects_current_board.png")
	_build_svg(output_dir / "town_objects_current_board.svg")
	_build_manifest(output_dir / "town_objects_current_manifest.json")
	print(output_dir)


if __name__ == "__main__":
	main()
