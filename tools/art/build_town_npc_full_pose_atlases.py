"""Build reviewed full-pose Town NPC atlases, including visiting townsfolk.

Resident sit rows retain the procedural-v1 poses. The generated motion-v2 rows
replace idle/walk/chat, while motion-v3 adds lookout, stretch, greeting,
role-work, and five full-pose emotion loops. Visitors use their generated base,
extra, and emotion strips.
"""

from __future__ import annotations

import colorsys
from pathlib import Path
from statistics import median

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[2]
CHARACTER_ROOT = PROJECT_ROOT / "assets" / "town" / "npc" / "characters"
STRIP_ROOT = CHARACTER_ROOT / "motion_strips_v2"
EXTRA_STRIP_ROOT = CHARACTER_ROOT / "motion_strips_v3"
FALLBACK_ROOT = CHARACTER_ROOT / "procedural_v1"

RESIDENTS = ("traveler", "witch", "guard", "grocer", "scientist", "innkeeper")
VISITORS = ("visitor_farmer", "visitor_minstrel")
CELL_SIZE = (144, 152)
FRAME_COUNT = 4
STATE_COUNT = 13
CHARACTER_ACTION_STATE_COUNT = 17
LEGACY_STATE_COUNT = 9
TARGET_HEIGHT = 132
TARGET_SIT_HEIGHT = 120
FOOT_BASELINE_Y = 144
SOURCE_TO_ATLAS_ROWS = ((0, 0), (1, 1), (2, 3))
EXTRA_TO_ATLAS_ROWS = ((0, 9), (1, 10), (2, 11), (3, 12))
EMOTION_TO_ATLAS_ROWS = ((0, 4), (1, 5), (2, 6), (3, 7), (4, 8))
CHARACTER_ACTION_TO_ATLAS_ROWS = ((0, 13), (1, 14), (2, 15), (3, 16))
GUARD_FALLBACK_ROWS = (2,)


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


def _extract_rows(path: Path, expected_rows: int) -> list[list[Image.Image]]:
    sheet = Image.open(path).convert("RGBA")
    alpha = sheet.getchannel("A")
    row_ranges = _occupied_ranges([
        alpha.crop((0, y, sheet.width, y + 1)).getbbox() is not None
        for y in range(sheet.height)
    ])
    if len(row_ranges) != expected_rows:
        raise ValueError(
            f"{path.name}: expected {expected_rows} occupied rows, found {row_ranges}"
        )

    rows: list[list[Image.Image]] = []
    for top, bottom in row_ranges:
        row_alpha = alpha.crop((0, top, sheet.width, bottom))
        column_ranges = _occupied_ranges([
            row_alpha.crop((x, 0, x + 1, bottom - top)).getbbox() is not None
            for x in range(sheet.width)
        ])
        if len(column_ranges) != FRAME_COUNT:
            # Long disconnected props such as the guard's spear can split the
            # alpha projection. Generated sheets have a strict four-column
            # layout, so recover each authored cell from equal column bands.
            column_ranges = []
            for column in range(FRAME_COUNT):
                band_left = round(sheet.width * column / FRAME_COUNT)
                band_right = round(sheet.width * (column + 1) / FRAME_COUNT)
                band = alpha.crop((band_left, top, band_right, bottom))
                bounds = band.getbbox()
                if bounds is None:
                    raise ValueError(
                        f"{path.name}: empty grid cell row {top} column {column}"
                    )
                column_ranges.append((band_left + bounds[0], band_left + bounds[2]))
        poses: list[Image.Image] = []
        for left, right in column_ranges:
            pose = sheet.crop((left, top, right, bottom))
            bounds = pose.getchannel("A").getbbox()
            if bounds is None:
                raise ValueError(f"{path.name}: extracted an empty pose")
            poses.append(pose.crop(bounds))
        rows.append(poses)
    return rows


def _extract_equal_grid(path: Path, row_count: int) -> list[list[Image.Image]]:
    """Extract generated transparent sheets whose cells use an exact visual grid."""
    sheet = Image.open(path).convert("RGBA")
    alpha = sheet.getchannel("A")
    row_ranges = _occupied_ranges([
        alpha.crop((0, y, sheet.width, y + 1)).getbbox() is not None
        for y in range(sheet.height)
    ])
    if len(row_ranges) != row_count:
        raise ValueError(f"{path.name}: expected {row_count} rows, found {row_ranges}")
    rows: list[list[Image.Image]] = []
    for row, (top, bottom) in enumerate(row_ranges):
        poses: list[Image.Image] = []
        for column in range(FRAME_COUNT):
            left = round(sheet.width * column / FRAME_COUNT)
            right = round(sheet.width * (column + 1) / FRAME_COUNT)
            pose = sheet.crop((left, top, right, bottom))
            bounds = pose.getchannel("A").getbbox()
            if bounds is None:
                raise ValueError(f"{path.name}: empty grid cell {row},{column}")
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


def _write_normalized_rows(
    atlas: Image.Image,
    source_rows: list[list[Image.Image]],
    row_mapping: tuple[tuple[int, int], ...],
) -> None:
    for source_row, atlas_row in row_mapping:
        for column, cell in enumerate(_normalize_row(source_rows[source_row])):
            _clear_cell(atlas, column, atlas_row)
            atlas.alpha_composite(
                cell,
                (column * CELL_SIZE[0], atlas_row * CELL_SIZE[1]),
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
    fallback = Image.open(fallback_path).convert("RGBA")
    expected_legacy_size = (
        CELL_SIZE[0] * FRAME_COUNT,
        CELL_SIZE[1] * LEGACY_STATE_COUNT,
    )
    if fallback.size != expected_legacy_size:
        raise ValueError(
            f"{fallback_path.name}: expected {expected_legacy_size}, got {fallback.size}"
        )
    state_count = CHARACTER_ACTION_STATE_COUNT if name in ("witch", "scientist") else STATE_COUNT
    atlas = Image.new(
        "RGBA",
        (CELL_SIZE[0] * FRAME_COUNT, CELL_SIZE[1] * state_count),
        (0, 0, 0, 0),
    )
    atlas.alpha_composite(fallback)
    _normalize_existing_atlas_row(atlas, 2, TARGET_SIT_HEIGHT)
    if name == "guard":
        _neutralize_guard_fallback_uniform(atlas)

    source_rows = _extract_rows(STRIP_ROOT / f"{name}_motion.png", 3)
    _write_normalized_rows(atlas, source_rows, SOURCE_TO_ATLAS_ROWS)

    extra_rows = _extract_rows(EXTRA_STRIP_ROOT / f"{name}_extra.png", 4)
    if name == "grocer":
        # The third generated work frame included a stray display plinth. Keep
        # the clean inspection frame in that beat instead of integrating it.
        extra_rows[3][2] = extra_rows[3][1].copy()
    _write_normalized_rows(atlas, extra_rows, EXTRA_TO_ATLAS_ROWS)

    emotion_rows = _extract_rows(EXTRA_STRIP_ROOT / f"{name}_emotion.png", 5)
    _write_normalized_rows(atlas, emotion_rows, EMOTION_TO_ATLAS_ROWS)

    if name in ("witch", "scientist"):
        action_path = EXTRA_STRIP_ROOT.parent / "character_action_strips_v4" / f"{name}_actions.png"
        action_rows = _extract_equal_grid(action_path, 4)
        _write_normalized_rows(atlas, action_rows, CHARACTER_ACTION_TO_ATLAS_ROWS)

    output_path = CHARACTER_ROOT / f"{name}_animation_atlas.png"
    atlas.save(output_path, optimize=True)
    print(f"Wrote {output_path.relative_to(PROJECT_ROOT)} ({atlas.width}x{atlas.height})")


def _build_visitor(name: str) -> None:
    atlas = Image.new(
        "RGBA",
        (CELL_SIZE[0] * FRAME_COUNT, CELL_SIZE[1] * STATE_COUNT),
        (0, 0, 0, 0),
    )
    source_rows = _extract_rows(EXTRA_STRIP_ROOT / f"{name}_base.png", 3)
    normalized_idle = _normalize_row(source_rows[0])

    # Sit has no visitor-specific authored sequence; retain one neutral adult
    # silhouette instead of introducing a scale-changing fallback pose.
    for atlas_row in (0, 2):
        for column, cell in enumerate(normalized_idle):
            atlas.alpha_composite(cell, (column * CELL_SIZE[0], atlas_row * CELL_SIZE[1]))
    _write_normalized_rows(atlas, source_rows, ((1, 1), (2, 3)))

    extra_rows = _extract_rows(EXTRA_STRIP_ROOT / f"{name}_extra.png", 4)
    _write_normalized_rows(atlas, extra_rows, EXTRA_TO_ATLAS_ROWS)

    emotion_rows = _extract_rows(EXTRA_STRIP_ROOT / f"{name}_emotion.png", 5)
    _write_normalized_rows(atlas, emotion_rows, EMOTION_TO_ATLAS_ROWS)

    output_path = CHARACTER_ROOT / f"{name}_animation_atlas.png"
    atlas.save(output_path, optimize=True)
    print(f"Wrote {output_path.relative_to(PROJECT_ROOT)} ({atlas.width}x{atlas.height})")


def main() -> None:
    for name in RESIDENTS:
        _build_character(name)
    for name in VISITORS:
        _build_visitor(name)


if __name__ == "__main__":
    main()
