#!/usr/bin/env python3
"""Prepare independently replaceable Town ambient animation atlases."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
CANDIDATE_ROOT = (
	ROOT
	/ "design/figma/town/b2_front_style_candidates/town_environment_animation"
)
DEFAULT_OUTPUT_ROOT = ROOT / "assets/town/modular_v3/ambient"
ATLAS_SIZE = (1448, 1086)
COLUMNS = 4
ROWS = 3
FRAME_COUNT = COLUMNS * ROWS
FRAME_SIZE = (ATLAS_SIZE[0] // COLUMNS, ATLAS_SIZE[1] // ROWS)
PIXEL_ART_PRESETS = {
	"falling_leaves_sheet.png": (2, 16),
	"bird_idle_sheet.png": (2, 20),
	"bird_flight_sheet.png": (2, 20),
}
SOURCES = {
	"falling_leaves_sheet.png": (
		CANDIDATE_ROOT
		/ "falling_leaves"
		/ "falling_leaves_4x3_v1_rgba.png"
	),
	"bird_idle_sheet.png": (
		CANDIDATE_ROOT / "birds" / "sparrow_idle_12f_v1.png"
	),
	"bird_flight_sheet.png": (
		CANDIDATE_ROOT / "birds" / "sparrow_takeoff_flight_12f_v1.png"
	),
}


def _validate_atlas(image: Image.Image, source_path: Path) -> None:
	if image.size != ATLAS_SIZE:
		raise ValueError(
			f"Ambient atlas must be {ATLAS_SIZE}, got {image.size}: {source_path}"
		)
	frame_width = image.width // COLUMNS
	frame_height = image.height // ROWS
	for frame_index in range(FRAME_COUNT):
		column = frame_index % COLUMNS
		row = frame_index // COLUMNS
		frame = image.crop(
			(
				column * frame_width,
				row * frame_height,
				(column + 1) * frame_width,
				(row + 1) * frame_height,
			)
		)
		if frame.getchannel("A").getbbox() is None:
			raise ValueError(
				f"Ambient atlas frame {frame_index} is empty: {source_path}"
			)
		for corner in (
			(0, 0),
			(frame.width - 1, 0),
			(0, frame.height - 1),
			(frame.width - 1, frame.height - 1),
		):
			if frame.getpixel(corner)[3] != 0:
				raise ValueError(
					f"Ambient frame {frame_index} has opaque corner "
					f"{corner}: {source_path}"
				)


def _pixelate_frame(
	frame: Image.Image,
	pixel_factor: int,
	color_count: int,
) -> Image.Image:
	low_size = (
		max(1, frame.width // pixel_factor),
		max(1, frame.height // pixel_factor),
	)
	low = frame.resize(low_size, Image.Resampling.BOX)
	alpha = low.getchannel("A").point(lambda value: 255 if value >= 64 else 0)
	quantized = low.quantize(
		colors=color_count,
		method=Image.Quantize.FASTOCTREE,
		dither=Image.Dither.NONE,
	).convert("RGBA")
	quantized.putalpha(alpha)
	return quantized.resize(frame.size, Image.Resampling.NEAREST)


def _align_idle_bird(frame: Image.Image) -> Image.Image:
	bounds = frame.getchannel("A").getbbox()
	if bounds is None:
		return frame
	current_center = (bounds[0] + bounds[2]) / 2.0
	target_center = FRAME_SIZE[0] / 2.0
	offset_x = round(target_center - current_center)
	target_foot_y = 306
	offset_y = target_foot_y - bounds[3]
	aligned = Image.new("RGBA", frame.size, (0, 0, 0, 0))
	aligned.alpha_composite(frame, (offset_x, offset_y))
	return aligned


def _align_flight_bird(frame: Image.Image) -> Image.Image:
	bounds = frame.getchannel("A").getbbox()
	if bounds is None:
		return frame
	current_center = (
		(bounds[0] + bounds[2]) / 2.0,
		(bounds[1] + bounds[3]) / 2.0,
	)
	target_center = (FRAME_SIZE[0] / 2.0, FRAME_SIZE[1] / 2.0)
	offset = (
		round(target_center[0] - current_center[0]),
		round(target_center[1] - current_center[1]),
	)
	aligned = Image.new("RGBA", frame.size, (0, 0, 0, 0))
	aligned.alpha_composite(frame, offset)
	return aligned


def _prepare_runtime_atlas(
	image: Image.Image,
	output_name: str,
) -> Image.Image:
	pixel_factor, color_count = PIXEL_ART_PRESETS[output_name]
	prepared = Image.new("RGBA", image.size, (0, 0, 0, 0))
	for frame_index in range(FRAME_COUNT):
		column = frame_index % COLUMNS
		row = frame_index // COLUMNS
		left = column * FRAME_SIZE[0]
		top = row * FRAME_SIZE[1]
		frame = image.crop(
			(left, top, left + FRAME_SIZE[0], top + FRAME_SIZE[1])
		)
		frame = _pixelate_frame(frame, pixel_factor, color_count)
		if output_name == "bird_idle_sheet.png":
			frame = _align_idle_bird(frame)
		elif output_name == "bird_flight_sheet.png":
			frame = _align_flight_bird(frame)
		prepared.alpha_composite(frame, (left, top))
	return prepared


def prepare_assets(output_root: Path) -> None:
	output_root.mkdir(parents=True, exist_ok=True)
	for output_name, source_path in SOURCES.items():
		image = Image.open(source_path).convert("RGBA")
		_validate_atlas(image, source_path)
		image = _prepare_runtime_atlas(image, output_name)
		_validate_atlas(image, source_path)
		output_path = output_root / output_name
		image.save(output_path, "PNG", optimize=True)
		print(
			f"{source_path.relative_to(ROOT)} -> "
			f"{output_path.relative_to(ROOT)} {image.size}"
		)


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument(
		"--output-root",
		type=Path,
		default=DEFAULT_OUTPUT_ROOT,
	)
	args = parser.parse_args()
	prepare_assets(args.output_root)


if __name__ == "__main__":
	main()
