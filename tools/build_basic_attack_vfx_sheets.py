#!/usr/bin/env python3

from __future__ import annotations

import math
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


def _crescent_curve_points(
    center_x: float,
    center_y: float,
    length: float,
    height: float,
    bend: float,
    samples: int = 30,
) -> list[tuple[float, float]]:
    points: list[tuple[float, float]] = []
    for index in range(samples + 1):
        ratio = index / float(samples)
        arc = math.sin(ratio * math.pi)
        x = center_x - length * 0.48 + length * 0.96 * ratio
        y = (
            center_y
            - height * bend * 0.42 * (arc ** 0.78)
            + height * 0.13 * (ratio - 0.5)
        )
        points.append((x, y))
    return points


def _crescent_mask(
    center_x: float,
    center_y: float,
    length: float,
    height: float,
    alpha: int,
    bend: float,
    thickness: float,
    inner_bite: float,
) -> Image.Image:
    mask = Image.new("L", FRAME_SIZE, 0)
    draw = ImageDraw.Draw(mask)
    upper: list[tuple[float, float]] = []
    lower: list[tuple[float, float]] = []
    samples = 34
    for index in range(samples + 1):
        ratio = index / float(samples)
        arc = math.sin(ratio * math.pi)
        crest = arc ** 0.64
        tail_open = min(1.0, ratio / 0.16)
        nose_taper = max(0.0, 1.0 - max(0.0, ratio - 0.82) / 0.18)
        envelope = tail_open * (0.22 + 0.78 * nose_taper)
        x = center_x - length * 0.50 + length * ratio
        centerline = center_y - height * bend * 0.16 * crest + height * 0.045 * (ratio - 0.5)
        top_y = centerline - height * (0.06 + 0.58 * crest * thickness) * envelope
        bottom_y = centerline + height * (0.05 + 0.22 * crest * thickness) * envelope
        if index == samples:
            top_y = center_y
            bottom_y = center_y
        upper.append((x, top_y))
        lower.append((x, bottom_y))
    draw.polygon([(round(x), round(y)) for x, y in upper + list(reversed(lower))], fill=alpha)

    cut_upper: list[tuple[float, float]] = []
    cut_lower: list[tuple[float, float]] = []
    for index in range(24):
        ratio = index / 23.0
        arc = math.sin(ratio * math.pi)
        x = center_x - length * 0.42 + length * 0.70 * ratio
        y = (
            center_y
            - height * (bend * 0.08) * (arc ** 0.82)
            + height * (0.11 + ratio * 0.055)
        )
        cut = height * (0.035 + (arc ** 0.78) * inner_bite)
        cut_upper.append((x, y - cut * 0.82))
        cut_lower.append((x, y + cut * 0.96))
    draw.polygon(
        [(round(x), round(y)) for x, y in cut_upper + list(reversed(cut_lower))],
        fill=0,
    )
    return mask


def _colored_mask(
    mask: Image.Image,
    fill: tuple[int, int, int, int],
    blur: float = 0.0,
) -> Image.Image:
    alpha = mask
    if blur > 0.0:
        alpha = alpha.filter(ImageFilter.GaussianBlur(blur))
    image = Image.new("RGBA", FRAME_SIZE, fill)
    image.putalpha(alpha)
    return image


def _slash_core(
    center_x: float,
    center_y: float,
    length: float,
    height: float,
    alpha: int,
    bend: float = 0.52,
) -> Image.Image:
    image = _blank()
    body_mask = _crescent_mask(
        center_x,
        center_y,
        length,
        height,
        int(alpha * 0.58),
        bend,
        0.74,
        0.31,
    )
    hot_mask = _crescent_mask(
        center_x + length * 0.03,
        center_y - height * 0.01,
        length * 0.90,
        height * 0.74,
        alpha,
        bend * 0.98,
        0.43,
        0.21,
    )
    image.alpha_composite(_colored_mask(body_mask, (58, 224, 255, 255), 0.45))
    image.alpha_composite(_colored_mask(hot_mask, (242, 255, 255, 255), 0.18))
    draw = ImageDraw.Draw(image, "RGBA")
    centerline = _crescent_curve_points(center_x, center_y, length * 0.88, height * 0.86, bend)
    upper_ridge = [
        (x, y - height * (0.13 + math.sin(i / 30.0 * math.pi) * 0.22))
        for i, (x, y) in enumerate(centerline)
    ]
    _line(
        draw,
        upper_ridge[2:],
        (255, 255, 255, alpha),
        max(2, round(height * 0.052)),
    )
    return image.filter(ImageFilter.GaussianBlur(0.18))


def _crescent_edge(
    center_x: float,
    center_y: float,
    length: float,
    height: float,
    alpha: int,
    bend: float,
) -> Image.Image:
    image, draw = _layer()
    glow_mask = _crescent_mask(center_x, center_y, length, height, int(alpha * 0.72), bend, 0.86, 0.38)
    image.alpha_composite(_colored_mask(glow_mask, (104, 255, 124, 255), 0.82))
    draw = ImageDraw.Draw(image, "RGBA")
    outer = []
    for index, (x, y) in enumerate(_crescent_curve_points(center_x, center_y, length, height, bend)):
        ratio = index / 30.0
        outer.append((x, y - height * (0.14 + math.sin(ratio * math.pi) * 0.30)))
    _line(draw, outer[1:], (226, 255, 156, alpha), max(2, round(height * 0.060)))
    _line(
        draw,
        _crescent_curve_points(center_x + length * 0.03, center_y + height * 0.18, length * 0.68, height * 0.56, bend * 0.34)[1:24],
        (128, 255, 104, int(alpha * 0.66)),
        max(1, round(height * 0.032)),
    )
    return image.filter(ImageFilter.GaussianBlur(0.24))


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
        offset = index * 15.0
        lane = (index - (count - 1) * 0.5) * height * 0.095
        curve = 0.34 + float(index % 3) * 0.05
        points = [
            (x - offset, y + lane)
            for x, y in _crescent_curve_points(
                center_x - length * 0.11,
                center_y + height * 0.10,
                length * (0.58 - float(index) * 0.030),
                height * (0.58 - float(index) * 0.018),
                curve,
                16,
            )
        ]
        _line(
            draw,
            points,
            (58, 210, 255, int(alpha * (0.36 - index * 0.05))),
            max(1, round(height * (0.070 - index * 0.008))),
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

    for index in range(count):
        seed = index * 1.618
        ratio = (index + 1) / (count + 1)
        x = center_x - length * (0.48 + 0.18 * math.sin(seed)) + length * ratio * 0.54
        side = -1.0 if index % 2 == 0 else 1.0
        y = (
            center_y
            - height * 0.16
            + side * height * (0.14 + 0.30 * ((index * 37) % 100) / 100.0)
        )
        angle = -0.03 + side * (0.08 + 0.18 * math.sin(seed * 0.7))
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
    rise = max(0.18, 1.0 - abs(t - 0.48) / 0.52)
    alpha = round(255 * max(0.0, rise) ** 0.66)
    length = 84.0 + rise * 128.0
    height = 38.0 + rise * 70.0
    center_x = 128.0 + t * 38.0
    center_y = 113.0 - rise * 7.0
    fade = 1.0 - max(0.0, t - 0.68) / 0.32
    alpha = max(22, round(alpha * max(0.12, fade)))
    return {
        "afterimage": _afterimage(center_x - 16.0, center_y + 10.0, length, height, alpha, 3),
        "core_blade": _slash_core(center_x, center_y, length, height, alpha, 0.58),
        "crescent_edge": _crescent_edge(center_x, center_y, length, height, alpha, 0.58),
        "shards": _shards(center_x - 8.0, center_y + 3.0, length, height, alpha, 9),
    }


def _travel_parts(frame_index: int) -> dict[str, Image.Image]:
    t = frame_index / (FRAME_COUNT - 1)
    ease = min(1.0, t * 1.25)
    fade = 1.0 - max(0.0, t - 0.64) / 0.36
    alpha = max(20, round(245 * max(0.10, fade)))
    length = 132.0 + 118.0 * (1.0 - abs(ease - 0.48) * 0.28)
    height = 54.0 + 54.0 * (1.0 - abs(ease - 0.48) * 0.42)
    center_x = 112.0 + t * 82.0
    center_y = 108.0 - 4.0 * (1.0 - abs(t - 0.5) * 2.0)
    return {
        "afterimage": _afterimage(center_x - 28.0, center_y + 4.0, length, height, alpha, 4),
        "core_blade": _slash_core(center_x, center_y, length, height, alpha, 0.50),
        "crescent_edge": _crescent_edge(center_x, center_y, length, height, alpha, 0.50),
        "shards": _shards(center_x - 12.0, center_y + 2.0, length, height, alpha, 12),
    }


def _impact_parts(frame_index: int) -> dict[str, Image.Image]:
    t = frame_index / (FRAME_COUNT - 1)
    bloom = min(1.0, t * 1.45)
    fade = 1.0 - max(0.0, t - 0.56) / 0.44
    alpha = max(20, round(255 * max(0.10, fade)))
    length = 154.0 + bloom * 96.0
    height = 60.0 + bloom * 78.0
    center_x = 128.0 + bloom * 34.0
    center_y = 109.0 - bloom * 7.0
    image, draw = _layer()
    wedge_mask = _crescent_mask(center_x + 8.0, center_y, length, height, int(alpha * 0.46), 0.46, 0.82, 0.30)
    image.alpha_composite(_colored_mask(wedge_mask, (42, 178, 255, 255), 0.58))
    _line(
        draw,
        _crescent_curve_points(center_x + 8.0, center_y - height * 0.03, length * 0.90, height * 0.82, 0.46)[3:],
        (250, 255, 255, alpha),
        max(2, round(height * 0.052)),
    )
    impact_wedge = image.filter(ImageFilter.GaussianBlur(0.35))
    return {
        "impact_wedge": impact_wedge,
        "core_blade": _slash_core(center_x - 10.0, center_y, length * 0.82, height * 0.72, alpha, 0.46),
        "crescent_edge": _crescent_edge(center_x - 8.0, center_y + height * 0.01, length * 0.84, height * 0.76, alpha, 0.46),
        "shards": _shards(center_x + 4.0, center_y - 2.0, length * (0.80 + bloom * 0.22), height, alpha, 16),
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
