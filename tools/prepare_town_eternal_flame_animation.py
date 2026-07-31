#!/usr/bin/env python3
"""Split approved Eternal Flame 4x2 sheets into aligned runtime frames."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_FIRE_SHEET = (
	ROOT
	/ "design/figma/town/b2_front_style_candidates/eternal_flame_animation"
	/ "top_fire_sheet_v1.png"
)
DEFAULT_RUNE_SHEET = (
	ROOT
	/ "design/figma/town/b2_front_style_candidates/eternal_flame_animation"
	/ "rune_charge_sheet_v1.png"
)
DEFAULT_OUTPUT_ROOT = (
	ROOT / "assets/town/modular_v3/landmarks/eternal_flame_animation"
)
FRAME_COUNT = 8
COLUMNS = 4
ROWS = 2


def _align_frames(
	frames: list[Image.Image],
	anchor_mode: str,
) -> list[Image.Image]:
	bounds = [frame.getchannel("A").getbbox() for frame in frames]
	if any(bound is None for bound in bounds):
		raise ValueError("Animation frames must all contain visible pixels.")
	typed_bounds = [bound for bound in bounds if bound is not None]
	if anchor_mode == "bottom":
		target_x = frames[0].width * 0.5
		target_y = round(
			sum(bound[3] for bound in typed_bounds) / len(typed_bounds)
		)
	else:
		target_x = frames[0].width * 0.5
		target_y = frames[0].height * 0.5

	aligned: list[Image.Image] = []
	for frame, bound in zip(frames, typed_bounds):
		source_x = (bound[0] + bound[2]) * 0.5
		source_y = bound[3] if anchor_mode == "bottom" else (
			(bound[1] + bound[3]) * 0.5
		)
		offset = (
			round(target_x - source_x),
			round(target_y - source_y),
		)
		canvas = Image.new("RGBA", frame.size, (0, 0, 0, 0))
		canvas.alpha_composite(frame, offset)
		aligned.append(canvas)
	return aligned


def _split_sheet(
	sheet_path: Path,
	output_dir: Path,
	anchor_mode: str,
) -> None:
	image = Image.open(sheet_path).convert("RGBA")
	frame_width = image.width // COLUMNS
	frame_height = image.height // ROWS
	if frame_width <= 0 or frame_height <= 0:
		raise ValueError(f"Animation sheet is too small: {sheet_path}")

	frames: list[Image.Image] = []
	for frame_index in range(FRAME_COUNT):
		column = frame_index % COLUMNS
		row = frame_index // COLUMNS
		left = column * frame_width
		top = row * frame_height
		frames.append(image.crop(
			(left, top, left + frame_width, top + frame_height)
		))

	output_dir.mkdir(parents=True, exist_ok=True)
	for frame_index, frame in enumerate(
		_align_frames(frames, anchor_mode)
	):
		alpha = frame.getchannel("A")
		if alpha.getbbox() is None:
			raise ValueError(
				f"Animation frame {frame_index} is empty: {sheet_path}"
			)
		for corner in (
			(0, 0),
			(frame.width - 1, 0),
			(0, frame.height - 1),
			(frame.width - 1, frame.height - 1),
		):
			if frame.getpixel(corner)[3] != 0:
				raise ValueError(
					f"Animation frame {frame_index} has an opaque corner: "
					f"{sheet_path} {corner}"
				)
		output_path = output_dir / f"frame_{frame_index:02d}.png"
		frame.save(output_path, "PNG", optimize=True)
		print(
			f"{sheet_path.relative_to(ROOT)} -> "
			f"{output_path.relative_to(ROOT)} {frame.size}"
		)


def prepare_animation(
	fire_sheet: Path,
	rune_sheet: Path,
	output_root: Path,
) -> None:
	_split_sheet(fire_sheet, output_root / "flame", "bottom")
	_split_sheet(rune_sheet, output_root / "rune", "center")


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("--fire-sheet", type=Path, default=DEFAULT_FIRE_SHEET)
	parser.add_argument("--rune-sheet", type=Path, default=DEFAULT_RUNE_SHEET)
	parser.add_argument("--output-root", type=Path, default=DEFAULT_OUTPUT_ROOT)
	args = parser.parse_args()
	prepare_animation(args.fire_sheet, args.rune_sheet, args.output_root)


if __name__ == "__main__":
	main()
