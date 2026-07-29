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
    """Return the leading edge of a forward-facing ')' sword crescent."""
    points: list[tuple[float, float]] = []
    for index in range(samples + 1):
        ratio = index / float(samples)
        arc = max(0.0, math.sin(ratio * math.pi))
        x = (
            center_x
            - length * 0.35
            + length * (0.70 + bend * 0.10) * (arc ** 0.72)
        )
        y = (
            center_y
            - height * 0.50
            + height * ratio
            + height * 0.035 * arc * (ratio - 0.5)
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
    """Build a hollow moon blade, open toward its trailing side."""
    mask = Image.new("L", FRAME_SIZE, 0)
    draw = ImageDraw.Draw(mask)
    outer: list[tuple[float, float]] = []
    inner: list[tuple[float, float]] = []
    samples = 40
    for index in range(samples + 1):
        ratio = index / float(samples)
        arc = max(0.0, math.sin(ratio * math.pi))
        outer_x = (
            center_x
            - length * 0.35
            + length * (0.70 + bend * 0.10) * (arc ** 0.72)
        )
        y = (
            center_y
            - height * 0.50
            + height * ratio
            + height * 0.035 * arc * (ratio - 0.5)
        )
        band_width = length * (
            0.018 * (arc ** 0.24)
            + (0.105 + thickness * 0.075 + inner_bite * 0.22)
            * (arc ** 1.08)
        )
        outer.append((outer_x, y))
        inner.append((outer_x - band_width, y))
    draw.polygon(
        [(round(x), round(y)) for x, y in outer + list(reversed(inner))],
        fill=alpha,
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
        int(alpha * 0.64),
        bend,
        0.82,
        0.34,
    )
    hot_mask = _crescent_mask(
        center_x + length * 0.018,
        center_y,
        length * 0.94,
        height * 0.96,
        alpha,
        bend,
        0.22,
        0.10,
    )
    image.alpha_composite(_colored_mask(body_mask, (36, 177, 238, 255), 0.65))
    image.alpha_composite(_colored_mask(hot_mask, (242, 253, 255, 255), 0.22))
    draw = ImageDraw.Draw(image, "RGBA")
    _line(
        draw,
        _crescent_curve_points(
            center_x + length * 0.012,
            center_y,
            length * 0.92,
            height * 0.94,
            bend,
            36,
        )[1:-1],
        (255, 255, 255, alpha),
        max(2, round(length * 0.026)),
    )
    return image.filter(ImageFilter.GaussianBlur(0.20))


def _crescent_edge(
    center_x: float,
    center_y: float,
    length: float,
    height: float,
    alpha: int,
    bend: float,
) -> Image.Image:
    image = _blank()
    glow_mask = _crescent_mask(
        center_x,
        center_y,
        length,
        height,
        int(alpha * 0.68),
        bend,
        0.90,
        0.40,
    )
    image.alpha_composite(_colored_mask(glow_mask, (62, 199, 255, 255), 1.15))
    draw = ImageDraw.Draw(image, "RGBA")
    outer = _crescent_curve_points(center_x, center_y, length, height, bend, 40)
    _line(draw, outer[1:-1], (224, 252, 255, alpha), max(2, round(length * 0.025)))
    _line(
        draw,
        [
            (
                x - length * (0.045 + 0.13 * math.sin(i / 36.0 * math.pi)),
                y,
            )
            for i, (x, y) in enumerate(
                _crescent_curve_points(
                    center_x,
                    center_y,
                    length * 0.94,
                    height * 0.92,
                    bend,
                    36,
                )
            )
        ][2:-2],
        (86, 214, 255, int(alpha * 0.70)),
        max(1, round(length * 0.012)),
    )
    return image.filter(ImageFilter.GaussianBlur(0.28))


def _afterimage(
    center_x: float,
    center_y: float,
    length: float,
    height: float,
    alpha: int,
    count: int,
) -> Image.Image:
    image = _blank()
    for index in range(count):
        ratio = float(index + 1) / float(count + 1)
        ghost_mask = _crescent_mask(
            center_x - 12.0 - float(index) * 12.0,
            center_y + (ratio - 0.5) * 4.0,
            length * (0.92 - float(index) * 0.055),
            height * (0.94 - float(index) * 0.045),
            int(alpha * (0.24 - float(index) * 0.035)),
            0.50,
            0.12,
            0.08,
        )
        image.alpha_composite(_colored_mask(ghost_mask, (40, 173, 244, 255), 0.9))
    return image.filter(ImageFilter.GaussianBlur(0.48))


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
        ratio = (index + 1) / float(count + 1)
        x = (
            center_x
            - length * (0.32 + 0.30 * ratio)
            - length * 0.10 * abs(math.sin(seed))
        )
        side = -1.0 if index % 2 == 0 else 1.0
        y = (
            center_y
            + side * height * (0.18 + 0.34 * ((index * 37) % 100) / 100.0)
        )
        angle = math.pi + side * (0.10 + 0.24 * abs(math.sin(seed * 0.7)))
        _shard(
            draw,
            (x, y),
            7.0 + (index % 4) * 3.2,
            1.4 + (index % 3) * 0.50,
            angle,
            (98, 218, 255, int(alpha * (0.56 - index * 0.015))),
        )
    return image.filter(ImageFilter.GaussianBlur(0.2))


def _release_parts(frame_index: int) -> dict[str, Image.Image]:
    t = frame_index / (FRAME_COUNT - 1)
    rise = max(0.16, math.sin(min(1.0, t * 1.08) * math.pi) ** 0.58)
    fade = 1.0 - max(0.0, t - 0.72) / 0.28
    alpha = max(20, round(255 * rise * max(0.10, fade)))
    length = 116.0 + rise * 96.0
    height = 80.0 + rise * 64.0
    center_x = 160.0
    center_y = 96.0
    return {
        "afterimage": _afterimage(center_x, center_y, length, height, alpha, 2),
        "core_blade": _slash_core(center_x, center_y, length, height, alpha, 0.50),
        "crescent_edge": _crescent_edge(center_x, center_y, length, height, alpha, 0.50),
        "shards": _shards(center_x, center_y, length, height, alpha, 7),
    }


def _travel_parts(frame_index: int) -> dict[str, Image.Image]:
    t = frame_index / (FRAME_COUNT - 1)
    pulse = math.sin(t * math.pi)
    fade = 1.0 - max(0.0, t - 0.76) / 0.24
    alpha = max(20, round(250 * max(0.10, fade)))
    length = 204.0 + pulse * 14.0
    height = 126.0 + pulse * 12.0
    center_x = 164.0
    center_y = 96.0
    return {
        "afterimage": _afterimage(center_x, center_y, length, height, alpha, 3),
        "core_blade": _slash_core(center_x, center_y, length, height, alpha, 0.50),
        "crescent_edge": _crescent_edge(center_x, center_y, length, height, alpha, 0.50),
        "shards": _shards(center_x, center_y, length, height, alpha, 10),
    }


def _impact_parts(frame_index: int) -> dict[str, Image.Image]:
    t = frame_index / (FRAME_COUNT - 1)
    bloom = 1.0 - (1.0 - min(1.0, t * 1.35)) ** 3
    fade = 1.0 - max(0.0, t - 0.62) / 0.38
    alpha = max(20, round(255 * max(0.10, fade)))
    length = 202.0 + bloom * 40.0
    height = 142.0 + bloom * 28.0
    center_x = 160.0
    center_y = 96.0
    image, draw = _layer()
    wedge_mask = _crescent_mask(
        center_x + 4.0,
        center_y,
        length,
        height,
        int(alpha * 0.52),
        0.52,
        0.96,
        0.46,
    )
    image.alpha_composite(_colored_mask(wedge_mask, (42, 178, 255, 255), 1.35))
    _line(
        draw,
        _crescent_curve_points(
            center_x + 4.0,
            center_y,
            length * 0.98,
            height * 0.98,
            0.52,
            40,
        )[1:-1],
        (250, 255, 255, alpha),
        max(3, round(length * 0.027)),
    )
    impact_wedge = image.filter(ImageFilter.GaussianBlur(0.45))
    return {
        "impact_wedge": impact_wedge,
        "core_blade": _slash_core(
            center_x,
            center_y,
            length * 0.90,
            height * 0.90,
            alpha,
            0.52,
        ),
        "crescent_edge": _crescent_edge(
            center_x,
            center_y,
            length * 0.94,
            height * 0.94,
            alpha,
            0.52,
        ),
        "shards": _shards(center_x, center_y, length, height, alpha, 18),
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
