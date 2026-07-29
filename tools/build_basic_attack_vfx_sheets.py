#!/usr/bin/env python3

from __future__ import annotations

from pathlib import Path
from typing import Callable

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets/generated/vfx"
PARTS_DIR = OUTPUT_DIR / "parts"
FRAME_SIZE = (320, 192)
FRAME_COUNT = 8

StageBuilder = Callable[[int], dict[str, Image.Image]]


def _blank() -> Image.Image:
    return Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))


def _layer() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = _blank()
    return image, ImageDraw.Draw(image, "RGBA")


def _compose_sheet(frames: list[Image.Image]) -> Image.Image:
    sheet = Image.new(
        "RGBA",
        (FRAME_SIZE[0] * FRAME_COUNT, FRAME_SIZE[1]),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * FRAME_SIZE[0], 0))
    return sheet


def _combine(parts: dict[str, Image.Image]) -> Image.Image:
    result = _blank()
    for part in parts.values():
        result.alpha_composite(part)
    return result


def _mask(frame: Image.Image) -> Image.Image:
    alpha = frame.getchannel("A")
    alpha = alpha.filter(ImageFilter.MaxFilter(5))
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.75))
    mask = Image.new("RGBA", FRAME_SIZE, (255, 255, 255, 0))
    mask.putalpha(alpha)
    return mask


def _rotated_polygon(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[float, float]],
    fill: tuple[int, int, int, int],
) -> None:
    draw.polygon([(round(x), round(y)) for x, y in points], fill=fill)


def _line(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[float, float]],
    fill: tuple[int, int, int, int],
    width: int,
) -> None:
    draw.line([(round(x), round(y)) for x, y in points], fill=fill, width=width, joint="curve")


def _shard(
    draw: ImageDraw.ImageDraw,
    center: tuple[float, float],
    length: float,
    width: float,
    angle: float,
    fill: tuple[int, int, int, int],
) -> None:
    import math

    dx = math.cos(angle)
    dy = math.sin(angle)
    nx = -dy
    ny = dx
    cx, cy = center
    points = [
        (cx + dx * length * 0.58, cy + dy * length * 0.58),
        (cx + nx * width, cy + ny * width),
        (cx - dx * length * 0.42, cy - dy * length * 0.42),
        (cx - nx * width * 0.72, cy - ny * width * 0.72),
    ]
    _rotated_polygon(draw, points, fill)


def _slash_core(
    center_x: float,
    center_y: float,
    length: float,
    height: float,
    alpha: int,
) -> Image.Image:
    image, draw = _layer()
    nose = center_x + length * 0.48
    tail = center_x - length * 0.48
    body = [
        (nose, center_y),
        (center_x + length * 0.16, center_y - height * 0.24),
        (center_x - length * 0.18, center_y - height * 0.33),
        (tail, center_y - height * 0.10),
        (tail + length * 0.08, center_y + height * 0.08),
        (center_x - length * 0.10, center_y + height * 0.28),
        (center_x + length * 0.20, center_y + height * 0.18),
    ]
    _rotated_polygon(draw, body, (30, 168, 255, int(alpha * 0.46)))
    highlight = [
        (nose - length * 0.05, center_y - height * 0.02),
        (center_x + length * 0.08, center_y - height * 0.11),
        (center_x - length * 0.25, center_y - height * 0.08),
        (tail + length * 0.18, center_y + height * 0.02),
        (center_x - length * 0.16, center_y + height * 0.07),
        (center_x + length * 0.20, center_y + height * 0.06),
    ]
    _rotated_polygon(draw, highlight, (235, 255, 255, alpha))
    _line(
        draw,
        [
            (tail + length * 0.12, center_y + height * 0.10),
            (center_x + length * 0.14, center_y + height * 0.02),
            (nose - length * 0.02, center_y - height * 0.03),
        ],
        (255, 255, 255, alpha),
        max(2, round(height * 0.08)),
    )
    return image.filter(ImageFilter.GaussianBlur(0.25))


def _crescent_edge(
    center_x: float,
    center_y: float,
    length: float,
    height: float,
    alpha: int,
    bend: float,
) -> Image.Image:
    image, draw = _layer()
    top: list[tuple[float, float]] = []
    bottom: list[tuple[float, float]] = []
    import math

    for index in range(18):
        ratio = index / 17.0
        x = center_x - length * 0.42 + length * 0.86 * ratio
        arc = math.sin(ratio * math.pi)
        y = center_y - height * (0.46 * arc + bend * (ratio - 0.5))
        thickness = height * (0.045 + 0.12 * arc)
        top.append((x, y - thickness))
        bottom.append((x, y + thickness * 0.45))
    _rotated_polygon(draw, top + list(reversed(bottom)), (140, 255, 190, int(alpha * 0.86)))
    _line(draw, top[2:16], (246, 255, 220, alpha), max(2, round(height * 0.045)))
    return image.filter(ImageFilter.GaussianBlur(0.35))


def _afterimage(
    center_x: float,
    center_y: float,
    length: float,
    height: float,
    alpha: int,
    count: int,
) -> Image.Image:
    image, draw = _layer()
    for index in range(count):
        offset = index * 18.0
        lane = (index - (count - 1) * 0.5) * height * 0.18
        _line(
            draw,
            [
                (center_x - length * 0.56 - offset, center_y + lane),
                (center_x - length * 0.22 - offset * 0.45, center_y + lane * 0.6),
                (center_x + length * 0.20 - offset * 0.12, center_y - lane * 0.15),
            ],
            (58, 210, 255, int(alpha * (0.36 - index * 0.05))),
            max(1, round(height * (0.09 - index * 0.01))),
        )
    return image.filter(ImageFilter.GaussianBlur(0.55))


def _shards(
    center_x: float,
    center_y: float,
    length: float,
    height: float,
    alpha: int,
    count: int,
) -> Image.Image:
    image, draw = _layer()
    import math

    for index in range(count):
        seed = index * 1.618
        ratio = (index + 1) / (count + 1)
        x = center_x - length * (0.55 + 0.22 * math.sin(seed)) + length * ratio * 0.45
        side = -1.0 if index % 2 == 0 else 1.0
        y = center_y + side * height * (0.22 + 0.48 * ((index * 37) % 100) / 100.0)
        angle = -0.10 + side * (0.12 + 0.22 * math.sin(seed * 0.7))
        _shard(
            draw,
            (x, y),
            8.0 + (index % 4) * 3.0,
            1.7 + (index % 3) * 0.55,
            angle,
            (128, 255, 180, int(alpha * (0.62 - index * 0.018))),
        )
    return image.filter(ImageFilter.GaussianBlur(0.2))


def _release_parts(frame_index: int) -> dict[str, Image.Image]:
    t = frame_index / (FRAME_COUNT - 1)
    rise = max(0.16, 1.0 - abs(t - 0.50) / 0.50)
    alpha = round(255 * max(0.0, rise) ** 0.72)
    length = 72.0 + rise * 112.0
    height = 34.0 + rise * 56.0
    center_x = 138.0 + t * 28.0
    center_y = 124.0 - rise * 30.0
    fade = 1.0 - max(0.0, t - 0.62) / 0.38
    alpha = max(22, round(alpha * max(0.12, fade)))
    return {
        "afterimage": _afterimage(center_x - 10.0, center_y + 18.0, length, height, alpha, 3),
        "core_blade": _slash_core(center_x, center_y, length, height, alpha),
        "crescent_edge": _crescent_edge(center_x, center_y, length, height, alpha, 0.42),
        "shards": _shards(center_x - 4.0, center_y + 6.0, length, height, alpha, 10),
    }


def _travel_parts(frame_index: int) -> dict[str, Image.Image]:
    t = frame_index / (FRAME_COUNT - 1)
    ease = min(1.0, t * 1.25)
    fade = 1.0 - max(0.0, t - 0.64) / 0.36
    alpha = max(20, round(245 * max(0.10, fade)))
    length = 96.0 + 142.0 * (1.0 - abs(ease - 0.45) * 0.45)
    height = 32.0 + 34.0 * (1.0 - abs(ease - 0.45))
    center_x = 116.0 + t * 88.0
    center_y = 100.0 - 8.0 * (1.0 - abs(t - 0.5) * 2.0)
    return {
        "afterimage": _afterimage(center_x - 22.0, center_y + 2.0, length, height, alpha, 4),
        "core_blade": _slash_core(center_x, center_y, length, height, alpha),
        "crescent_edge": _crescent_edge(center_x, center_y, length, height, alpha, 0.12),
        "shards": _shards(center_x - 10.0, center_y, length, height, alpha, 14),
    }


def _impact_parts(frame_index: int) -> dict[str, Image.Image]:
    t = frame_index / (FRAME_COUNT - 1)
    bloom = min(1.0, t * 1.45)
    fade = 1.0 - max(0.0, t - 0.56) / 0.44
    alpha = max(20, round(255 * max(0.10, fade)))
    length = 128.0 + bloom * 112.0
    height = 34.0 + bloom * 88.0
    center_x = 128.0 + bloom * 34.0
    center_y = 112.0 - bloom * 22.0
    image, draw = _layer()
    nose = center_x + length * 0.52
    tail = center_x - length * 0.28
    _rotated_polygon(
        draw,
        [
            (tail, center_y + height * 0.16),
            (center_x + length * 0.12, center_y - height * 0.08),
            (nose, center_y - height * 0.50),
            (center_x + length * 0.30, center_y + height * 0.05),
            (nose - length * 0.08, center_y + height * 0.28),
            (center_x + length * 0.04, center_y + height * 0.20),
        ],
        (42, 178, 255, int(alpha * 0.42)),
    )
    _line(
        draw,
        [(tail, center_y + height * 0.08), (center_x + length * 0.24, center_y), (nose, center_y - height * 0.20)],
        (250, 255, 255, alpha),
        max(2, round(height * 0.055)),
    )
    impact_wedge = image.filter(ImageFilter.GaussianBlur(0.35))
    return {
        "impact_wedge": impact_wedge,
        "core_blade": _slash_core(center_x - 12.0, center_y, length * 0.74, height * 0.70, alpha),
        "crescent_edge": _crescent_edge(center_x - 16.0, center_y + height * 0.04, length * 0.72, height * 0.70, alpha, -0.22),
        "shards": _shards(center_x + 4.0, center_y - 4.0, length * (0.8 + bloom * 0.3), height, alpha, 18),
    }


def _validate(frames: list[Image.Image], stage: str) -> None:
    if len(frames) != FRAME_COUNT:
        raise ValueError(f"{stage}: expected {FRAME_COUNT} frames, got {len(frames)}")
    for index, frame in enumerate(frames):
        alpha = frame.getchannel("A")
        if alpha.getbbox() is None:
            raise ValueError(f"{stage}: frame {index} has no visible pixels")
        for corner in [(0, 0), (FRAME_SIZE[0] - 1, 0), (0, FRAME_SIZE[1] - 1)]:
            if alpha.getpixel(corner) != 0:
                raise ValueError(f"{stage}: frame {index} has opaque edge pixels")


def _write_stage(stage: str, builder: StageBuilder) -> None:
    part_frames: dict[str, list[Image.Image]] = {}
    combined_frames: list[Image.Image] = []
    for frame_index in range(FRAME_COUNT):
        parts = builder(frame_index)
        for part_name, image in parts.items():
            part_frames.setdefault(part_name, []).append(image)
        combined_frames.append(_combine(parts))
    _validate(combined_frames, stage)
    _compose_sheet(combined_frames).save(OUTPUT_DIR / f"basic_attack_{stage}_sheet_v2.png")
    _compose_sheet([_mask(frame) for frame in combined_frames]).save(
        OUTPUT_DIR / f"basic_attack_{stage}_mask_v2.png"
    )
    for part_name, frames in part_frames.items():
        _compose_sheet(frames).save(
            PARTS_DIR / f"basic_attack_{stage}_{part_name}_sheet_v2.png"
        )


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    PARTS_DIR.mkdir(parents=True, exist_ok=True)
    _write_stage("release", _release_parts)
    _write_stage("travel", _travel_parts)
    _write_stage("impact", _impact_parts)


if __name__ == "__main__":
    main()
