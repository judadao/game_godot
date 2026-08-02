"""Insert reviewed full-pose idle, walk, and chat rows into Town NPC atlases.

The remaining sit/laugh/emotion rows come from the retained procedural-v1
atlases until they receive their own generated full-pose replacements.
"""

from __future__ import annotations

import colorsys
from pathlib import Path
from statistics import median

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[2]
CHARACTER_ROOT = PROJECT_ROOT / "assets" / "town" / "npc" / "characters"
STRIP_ROOT = CHARACTER_ROOT / "motion_strips_v2"
FALLBACK_ROOT = CHARACTER_ROOT / "procedural_v1"

CHARACTERS = ("traveler", "witch", "guard", "grocer", "scientist", "innkeeper")
CELL_SIZE = (144, 152)
FRAME_COUNT = 4
STATE_COUNT = 9
TARGET_HEIGHT = 132
TARGET_SIT_HEIGHT = 120
FOOT_BASELINE_Y = 144
SOURCE_TO_ATLAS_ROWS = ((0, 0), (1, 1), (2, 3))
GUARD_FALLBACK_ROWS = (2, 4, 5, 6, 7, 8)


def _occupied_ranges(values: list[bool]) -> list[tuple[int, int]]:
    result: list[tuple[int, int]] = []
    start: int | None = None
    for index, occupied in enumerate(values):
        if occupied and start is None:
            start = index
        elif not occupied and start is not None:
            result.append((start, index))
            start = None
    if start is not None:
        result.append((start, len(values)))
    return result


def _extract_rows(path: Path) -> list[list[Image.Image]]:
    sheet = Image.open(path).convert("RGBA")
    alpha = sheet.getchannel("A")
    row_ranges = _occupied_ranges([
        alpha.crop((0, y, sheet.width, y + 1)).getbbox() is not None
        for y in range(sheet.height)
    ])
    if len(row_ranges) != 3:
        raise ValueError(f"{path.name}: expected 3 occupied rows, found {row_ranges}")

    rows: list[list[Image.Image]] = []
    for top, bottom in row_ranges:
        row_alpha = alpha.crop((0, top, sheet.width, bottom))
        column_ranges = _occupied_ranges([
            row_alpha.crop((x, 0, x + 1, bottom - top)).getbbox() is not None
            for x in range(sheet.width)
        ])
        if len(column_ranges) != FRAME_COUNT:
            raise ValueError(
                f"{path.name}: expected {FRAME_COUNT} isolated poses in row {top}, "
                f"found {column_ranges}"
            )
        poses: list[Image.Image] = []
        for left, right in column_ranges:
            pose = sheet.crop((left, top, right, bottom))
            bounds = pose.getchannel("A").getbbox()
            if bounds is None:
                raise ValueError(f"{path.name}: extracted an empty pose")
            poses.append(pose.crop(bounds))
        rows.append(poses)
    return rows


def _normalize_row(poses: list[Image.Image]) -> list[Image.Image]:
    scale = TARGET_HEIGHT / median(pose.height for pose in poses)
    normalized: list[Image.Image] = []
    for pose in poses:
        size = (max(1, round(pose.width * scale)), max(1, round(pose.height * scale)))
        resized = pose.resize(size, Image.Resampling.NEAREST)
        if resized.width >= CELL_SIZE[0] or resized.height >= CELL_SIZE[1]:
            raise ValueError(f"Normalized pose {size} exceeds atlas cell {CELL_SIZE}")
        cell = Image.new("RGBA", CELL_SIZE, (0, 0, 0, 0))
        x = (CELL_SIZE[0] - resized.width) // 2
        y = FOOT_BASELINE_Y - resized.height
        cell.alpha_composite(resized, (x, y))
        normalized.append(cell)
    return normalized


def _clear_cell(atlas: Image.Image, column: int, row: int) -> None:
    atlas.paste(
        Image.new("RGBA", CELL_SIZE, (0, 0, 0, 0)),
        (column * CELL_SIZE[0], row * CELL_SIZE[1]),
    )


def _normalize_existing_atlas_row(atlas: Image.Image, row: int, target_height: int) -> None:
    """Normalize retained poses without changing their authored silhouette."""
    for column in range(FRAME_COUNT):
        cell_box = (
            column * CELL_SIZE[0],
            row * CELL_SIZE[1],
            (column + 1) * CELL_SIZE[0],
            (row + 1) * CELL_SIZE[1],
        )
        cell = atlas.crop(cell_box)
        bounds = cell.getchannel("A").getbbox()
        if bounds is None:
            raise ValueError(f"Retained atlas row {row} frame {column} is empty")
        pose = cell.crop(bounds)
        scale = target_height / pose.height
        size = (max(1, round(pose.width * scale)), target_height)
        resized = pose.resize(size, Image.Resampling.NEAREST)
        if resized.width >= CELL_SIZE[0]:
            raise ValueError(
                f"Retained row {row} frame {column} width {resized.width} exceeds cell"
            )
        normalized = Image.new("RGBA", CELL_SIZE, (0, 0, 0, 0))
        normalized.alpha_composite(
            resized,
            ((CELL_SIZE[0] - resized.width) // 2, FOOT_BASELINE_Y - resized.height),
        )
        _clear_cell(atlas, column, row)
        atlas.alpha_composite(normalized, (column * CELL_SIZE[0], row * CELL_SIZE[1]))


def _neutralize_guard_fallback_uniform(atlas: Image.Image) -> None:
    """Keep retained sit/emote poses in the approved charcoal guard uniform."""
    pixels = atlas.load()
    for row in GUARD_FALLBACK_ROWS:
        top = row * CELL_SIZE[1]
        bottom = top + CELL_SIZE[1]
        for y in range(top, bottom):
            for x in range(atlas.width):
                red, green, blue, alpha = pixels[x, y]
                if alpha == 0:
                    continue
                hue, saturation, value = colorsys.rgb_to_hsv(
                    red / 255.0, green / 255.0, blue / 255.0
                )
                if not (0.22 <= hue <= 0.48 and saturation >= 0.18 and value >= 0.12):
                    continue
                luminance = 0.299 * red + 0.587 * green + 0.114 * blue
                charcoal = max(20, min(104, round(luminance * 0.58)))
                pixels[x, y] = (
                    round(charcoal * 0.88),
                    round(charcoal * 0.94),
                    charcoal,
                    alpha,
                )


def _build_character(name: str) -> None:
    fallback_path = FALLBACK_ROOT / f"{name}_animation_atlas.png"
    atlas = Image.open(fallback_path).convert("RGBA")
    expected_size = (CELL_SIZE[0] * FRAME_COUNT, CELL_SIZE[1] * STATE_COUNT)
    if atlas.size != expected_size:
        raise ValueError(f"{fallback_path.name}: expected {expected_size}, got {atlas.size}")
    _normalize_existing_atlas_row(atlas, 2, TARGET_SIT_HEIGHT)
    if name == "guard":
        _neutralize_guard_fallback_uniform(atlas)

    source_rows = _extract_rows(STRIP_ROOT / f"{name}_motion.png")
    for source_row, atlas_row in SOURCE_TO_ATLAS_ROWS:
        for column, cell in enumerate(_normalize_row(source_rows[source_row])):
            _clear_cell(atlas, column, atlas_row)
            atlas.alpha_composite(cell, (column * CELL_SIZE[0], atlas_row * CELL_SIZE[1]))

    output_path = CHARACTER_ROOT / f"{name}_animation_atlas.png"
    atlas.save(output_path, optimize=True)
    print(f"Wrote {output_path.relative_to(PROJECT_ROOT)} ({atlas.width}x{atlas.height})")


def main() -> None:
    for name in CHARACTERS:
        _build_character(name)


if __name__ == "__main__":
    main()
