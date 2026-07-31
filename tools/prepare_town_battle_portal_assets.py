#!/usr/bin/env python3
"""Prepare the Town Battle Portal aperture mask and hand-drawn animation cels."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[1]
CANDIDATE_ROOT = ROOT / "design/figma/town/b2_front_style_candidates"
DEFAULT_BASE = CANDIDATE_ROOT / "battle_portal_base_v5.png"
DEFAULT_BASE_CHROMA = (
	CANDIDATE_ROOT
	/ "battle_portal_animation"
	/ "battle_portal_base_v5_chroma.png"
)
DEFAULT_CORE_SHEET = (
	CANDIDATE_ROOT
	/ "battle_portal_animation"
	/ "portal_vortex_core_sheet_v3.png"
)
DEFAULT_UNDERPAINT = (
	CANDIDATE_ROOT
	/ "battle_portal_animation"
	/ "portal_vortex_underpaint_v1.png"
)
DEFAULT_OUTPUT_ROOT = (
	ROOT / "assets/town/modular_v3/landmarks/battle_portal_animation"
)
RUNTIME_CANVAS = (800, 960)
INNER_MARGIN = 16
SHEET_COLUMNS = 4
SHEET_ROWS = 3
FRAME_COUNT = SHEET_COLUMNS * SHEET_ROWS
CELL_GUTTER = 12
PIXEL_BLOCK = 4
PORTAL_PALETTE = (
	(21, 17, 43),
	(34, 27, 70),
	(56, 42, 104),
	(74, 65, 145),
	(100, 94, 180),
	(151, 139, 207),
)
UNDERPAINT_COLOR = (21, 17, 43, 255)
KEY_RED_MAX = 96
KEY_GREEN_MIN = 180
KEY_BLUE_MAX = 96


def _is_key(pixel: tuple[int, int, int, int]) -> bool:
	red, green, blue, _alpha = pixel
	return (
		red <= KEY_RED_MAX
		and green >= KEY_GREEN_MIN
		and blue <= KEY_BLUE_MAX
		and green >= red * 2
		and green >= blue * 2
	)


def _enclosed_key_mask(chroma: Image.Image) -> Image.Image:
	image = chroma.convert("RGBA")
	width, height = image.size
	key_pixels = [_is_key(pixel) for pixel in image.getdata()]
	exterior = bytearray(width * height)
	queue: deque[tuple[int, int]] = deque()

	def enqueue_if_key(x: int, y: int) -> None:
		index = y * width + x
		if key_pixels[index] and not exterior[index]:
			exterior[index] = 1
			queue.append((x, y))

	for x in range(width):
		enqueue_if_key(x, 0)
		enqueue_if_key(x, height - 1)
	for y in range(height):
		enqueue_if_key(0, y)
		enqueue_if_key(width - 1, y)

	while queue:
		x, y = queue.popleft()
		for next_x, next_y in (
			(x - 1, y),
			(x + 1, y),
			(x, y - 1),
			(x, y + 1),
		):
			if 0 <= next_x < width and 0 <= next_y < height:
				enqueue_if_key(next_x, next_y)

	mask = Image.new("RGBA", image.size, (0, 0, 0, 0))
	output = mask.load()
	for y in range(height):
		for x in range(width):
			index = y * width + x
			if key_pixels[index] and not exterior[index]:
				output[x, y] = (255, 255, 255, 255)
	if mask.getchannel("A").getbbox() is None:
		raise ValueError("Portal chroma source has no enclosed doorway aperture.")
	return mask


def _runtime_transform(
	base: Image.Image,
) -> tuple[tuple[int, int, int, int], tuple[int, int], tuple[int, int]]:
	bounds = base.getchannel("A").getbbox()
	if bounds is None:
		raise ValueError("Portal Base candidate is fully transparent.")
	trimmed_width = bounds[2] - bounds[0]
	trimmed_height = bounds[3] - bounds[1]
	available = (
		RUNTIME_CANVAS[0] - INNER_MARGIN * 2,
		RUNTIME_CANVAS[1] - INNER_MARGIN,
	)
	scale = min(
		available[0] / trimmed_width,
		available[1] / trimmed_height,
	)
	render_size = (
		max(1, round(trimmed_width * scale)),
		max(1, round(trimmed_height * scale)),
	)
	offset = (
		(RUNTIME_CANVAS[0] - render_size[0]) // 2,
		RUNTIME_CANVAS[1] - render_size[1],
	)
	return bounds, render_size, offset


def _prepare_mask(
	base_path: Path,
	chroma_path: Path,
	output_path: Path,
) -> None:
	base = Image.open(base_path).convert("RGBA")
	chroma = Image.open(chroma_path).convert("RGBA")
	if base.size != chroma.size:
		raise ValueError("Portal Base and chroma source sizes must match.")
	source_mask = _enclosed_key_mask(chroma)
	bounds, render_size, offset = _runtime_transform(base)
	rendered = source_mask.crop(bounds).resize(
		render_size,
		Image.Resampling.NEAREST,
	)
	canvas = Image.new("RGBA", RUNTIME_CANVAS, (0, 0, 0, 0))
	canvas.alpha_composite(rendered, offset)
	mask_bounds = canvas.getchannel("A").getbbox()
	if mask_bounds is None:
		raise ValueError("Prepared portal aperture mask is empty.")
	output_path.parent.mkdir(parents=True, exist_ok=True)
	canvas.save(output_path, "PNG", optimize=True)
	print(
		f"{chroma_path.relative_to(ROOT)} -> {output_path.relative_to(ROOT)} "
		f"{canvas.size}; aperture={mask_bounds}"
	)


def _nearest_palette_color(
	red: int,
	green: int,
	blue: int,
) -> tuple[int, int, int]:
	return min(
		PORTAL_PALETTE,
		key=lambda color: (
			(color[0] - red) ** 2
			+ (color[1] - green) ** 2
			+ (color[2] - blue) ** 2
		),
	)


def _pixelate_and_quantize(image: Image.Image) -> Image.Image:
	small_size = (
		max(1, image.width // PIXEL_BLOCK),
		max(1, image.height // PIXEL_BLOCK),
	)
	pixelated = image.resize(
		small_size,
		Image.Resampling.LANCZOS,
	).resize(image.size, Image.Resampling.NEAREST)
	output = Image.new("RGBA", image.size, (0, 0, 0, 0))
	output_pixels = output.load()
	for y in range(image.height):
		for x in range(image.width):
			red, green, blue, alpha = pixelated.getpixel((x, y))
			if alpha < 80:
				continue
			mapped = _nearest_palette_color(red, green, blue)
			output_pixels[x, y] = (*mapped, 255)
	return output


def _prepare_underpaint(
	source_path: Path,
	mask_path: Path,
	output_path: Path,
) -> None:
	source = Image.open(source_path).convert("RGBA")
	source_bounds = source.getchannel("A").getbbox()
	if source_bounds is None:
		raise ValueError("Portal underpaint candidate is fully transparent.")
	mask = Image.open(mask_path).convert("RGBA")
	mask_bounds = mask.getchannel("A").getbbox()
	if mask_bounds is None:
		raise ValueError("Prepared portal aperture mask is empty.")
	mask_crop = mask.getchannel("A").crop(mask_bounds)
	render_size = (
		mask_bounds[2] - mask_bounds[0],
		mask_bounds[3] - mask_bounds[1],
	)
	rendered = source.crop(source_bounds).resize(
		render_size,
		Image.Resampling.LANCZOS,
	)
	rendered = _pixelate_and_quantize(rendered)
	underpaint = Image.new("RGBA", render_size, UNDERPAINT_COLOR)
	underpaint.alpha_composite(rendered)
	underpaint.putalpha(mask_crop)
	canvas = Image.new("RGBA", RUNTIME_CANVAS, (0, 0, 0, 0))
	canvas.alpha_composite(underpaint, (mask_bounds[0], mask_bounds[1]))
	output_path.parent.mkdir(parents=True, exist_ok=True)
	canvas.save(output_path, "PNG", optimize=True)
	print(
		f"{source_path.relative_to(ROOT)} -> {output_path.relative_to(ROOT)} "
		f"{RUNTIME_CANVAS}; aperture={mask_bounds}"
	)


def _derive_highlights(core: Image.Image) -> Image.Image:
	output = Image.new("RGBA", core.size, (0, 0, 0, 0))
	output_pixels = output.load()
	for y in range(core.height):
		for x in range(core.width):
			red, green, blue, alpha = core.getpixel((x, y))
			if alpha == 0:
				continue
			if (red, green, blue) == PORTAL_PALETTE[-1]:
				output_pixels[x, y] = (171, 154, 222, 176)
			elif (red, green, blue) == PORTAL_PALETTE[-2]:
				output_pixels[x, y] = (112, 107, 194, 112)
	return output


def _prepare_animation_sheet(
	source_path: Path,
	mask_path: Path,
	core_output_dir: Path,
	highlight_output_dir: Path,
) -> None:
	sheet = Image.open(source_path).convert("RGBA")
	mask = Image.open(mask_path).convert("RGBA")
	mask_bounds = mask.getchannel("A").getbbox()
	if mask_bounds is None:
		raise ValueError("Prepared portal aperture mask is empty.")
	mask_crop = mask.getchannel("A").crop(mask_bounds)
	render_size = (
		mask_bounds[2] - mask_bounds[0],
		mask_bounds[3] - mask_bounds[1],
	)
	core_output_dir.mkdir(parents=True, exist_ok=True)
	highlight_output_dir.mkdir(parents=True, exist_ok=True)

	for frame_index in range(FRAME_COUNT):
		column = frame_index % SHEET_COLUMNS
		row = frame_index // SHEET_COLUMNS
		left = round(column * sheet.width / SHEET_COLUMNS) + CELL_GUTTER
		right = round((column + 1) * sheet.width / SHEET_COLUMNS) - CELL_GUTTER
		top = round(row * sheet.height / SHEET_ROWS) + CELL_GUTTER
		bottom = round((row + 1) * sheet.height / SHEET_ROWS) - CELL_GUTTER
		if left >= right or top >= bottom:
			raise ValueError(f"Portal frame {frame_index} has invalid crop bounds.")
		cell = sheet.crop((left, top, right, bottom))
		rendered = cell.resize(render_size, Image.Resampling.LANCZOS)
		rendered = _pixelate_and_quantize(rendered)
		rendered.putalpha(
			ImageChops.multiply(rendered.getchannel("A"), mask_crop)
		)
		core_canvas = Image.new("RGBA", RUNTIME_CANVAS, (0, 0, 0, 0))
		core_canvas.alpha_composite(rendered, (mask_bounds[0], mask_bounds[1]))
		core_path = core_output_dir / f"frame_{frame_index:02d}.png"
		core_canvas.save(core_path, "PNG", optimize=True)
		highlight_canvas = _derive_highlights(core_canvas)
		highlight_path = (
			highlight_output_dir / f"frame_{frame_index:02d}.png"
		)
		highlight_canvas.save(highlight_path, "PNG", optimize=True)

	print(
		f"{source_path.relative_to(ROOT)} -> "
		f"{core_output_dir.relative_to(ROOT)} + "
		f"{highlight_output_dir.relative_to(ROOT)} "
		f"{FRAME_COUNT} pixel-art cels {RUNTIME_CANVAS}; aperture={mask_bounds}"
	)


def prepare_assets(
	base_path: Path,
	chroma_path: Path,
	core_sheet_path: Path,
	underpaint_path: Path,
	output_root: Path,
) -> None:
	mask_path = output_root / "portal_aperture_mask.png"
	_prepare_mask(
		base_path,
		chroma_path,
		mask_path,
	)
	_prepare_underpaint(
		underpaint_path,
		mask_path,
		output_root / "portal_underpaint.png",
	)
	_prepare_animation_sheet(
		core_sheet_path,
		mask_path,
		output_root / "vortex_core",
		output_root / "vortex_highlights",
	)


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("--base", type=Path, default=DEFAULT_BASE)
	parser.add_argument("--base-chroma", type=Path, default=DEFAULT_BASE_CHROMA)
	parser.add_argument("--core-sheet", type=Path, default=DEFAULT_CORE_SHEET)
	parser.add_argument("--underpaint", type=Path, default=DEFAULT_UNDERPAINT)
	parser.add_argument("--output-root", type=Path, default=DEFAULT_OUTPUT_ROOT)
	args = parser.parse_args()
	prepare_assets(
		args.base,
		args.base_chroma,
		args.core_sheet,
		args.underpaint,
		args.output_root,
	)


if __name__ == "__main__":
	main()
