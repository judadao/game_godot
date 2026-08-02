"""Build the priest atlas from reviewed full-pose animation strips.

The generated strips contain two rows of four characters, but their spacing is
not assumed to be mathematically uniform. Transparent row/column gaps are used
to isolate each complete pose so a neighbour's hair, sleeve, or hand can never
leak into another frame.

Run from the project root:

    python tools/art/build_priest_animation.py
"""

from __future__ import annotations

from pathlib import Path
from statistics import median

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[2]
ASSET_ROOT = PROJECT_ROOT / "assets" / "town" / "npc" / "priest"
STRIP_ROOT = ASSET_ROOT / "pose_strips_v2"
OUTPUT_PATH = ASSET_ROOT / "priest_animation_atlas.png"

FRAME_SIZE = (384, 512)
FRAME_COUNT = 8
TARGET_CHARACTER_HEIGHT = 448
FOOT_BASELINE_Y = 492
ACTIONS = (
    "front_idle", "front_chat", "side_walk", "side_chat",
    "prayer", "bless", "comfort", "courage",
)
GENERATED_ACTION_PATH = ASSET_ROOT / "pose_strips_v3" / "priest_actions.png"
GENERATED_ACTION_COLUMNS = {
    "prayer": (0, 1, 2, 3),
    "bless": (0, 1, 2, 3),
    # Exclude the kneeling scale break and the unauthorised shield/staff pose.
    "comfort": (1, 2, 3, 2),
    "courage": (0, 1, 2, 2),
}
PING_PONG_COLUMNS = (0, 1, 2, 3, 3, 2, 1, 0)


def _occupied_ranges(values: list[bool]) -> list[tuple[int, int]]:
    ranges: list[tuple[int, int]] = []
    start: int | None = None
    for index, occupied in enumerate(values):
        if occupied and start is None:
            start = index
        elif not occupied and start is not None:
            ranges.append((start, index))
            start = None
    if start is not None:
        ranges.append((start, len(values)))
    return ranges


def _extract_poses(path: Path) -> list[Image.Image]:
    sheet = Image.open(path).convert("RGBA")
    alpha = sheet.getchannel("A")
    occupied_rows = [
        alpha.crop((0, y, sheet.width, y + 1)).getbbox() is not None
        for y in range(sheet.height)
    ]
    row_ranges = _occupied_ranges(occupied_rows)
    if len(row_ranges) != 2:
        raise ValueError(f"{path.name}: expected 2 occupied rows, found {row_ranges}")

    poses: list[Image.Image] = []
    for top, bottom in row_ranges:
        row_alpha = alpha.crop((0, top, sheet.width, bottom))
        occupied_columns = [
            row_alpha.crop((x, 0, x + 1, bottom - top)).getbbox() is not None
            for x in range(sheet.width)
        ]
        column_ranges = _occupied_ranges(occupied_columns)
        if len(column_ranges) != 4:
            raise ValueError(
                f"{path.name}: expected 4 isolated poses in row {top}, "
                f"found {column_ranges}"
            )
        for left, right in column_ranges:
            pose = sheet.crop((left, top, right, bottom))
            bounds = pose.getchannel("A").getbbox()
            if bounds is None:
                raise ValueError(f"{path.name}: extracted an empty pose")
            poses.append(pose.crop(bounds))
    return poses


def _extract_generated_rows(path: Path) -> list[list[Image.Image]]:
    sheet = Image.open(path).convert("RGBA")
    alpha = sheet.getchannel("A")
    row_ranges = _occupied_ranges([
        alpha.crop((0, y, sheet.width, y + 1)).getbbox() is not None
        for y in range(sheet.height)
    ])
    if len(row_ranges) != 4:
        raise ValueError(f"{path.name}: expected four generated rows, found {row_ranges}")
    rows: list[list[Image.Image]] = []
    for top, bottom in row_ranges:
        poses: list[Image.Image] = []
        row_alpha = alpha.crop((0, top, sheet.width, bottom))
        column_ranges = _occupied_ranges([
            row_alpha.crop((x, 0, x + 1, bottom - top)).getbbox() is not None
            for x in range(sheet.width)
        ])
        if len(column_ranges) != 4:
            raise ValueError(f"{path.name}: expected four poses, found {column_ranges}")
        for left, right in column_ranges:
            pose = sheet.crop((left, top, right, bottom))
            bounds = pose.getchannel("A").getbbox()
            if bounds is None:
                raise ValueError(f"{path.name}: empty generated cell {row},{column}")
            poses.append(pose.crop(bounds))
        rows.append(poses)
    return rows


def _normalize_poses(poses: list[Image.Image]) -> list[Image.Image]:
    source_height = median(pose.height for pose in poses)
    scale = TARGET_CHARACTER_HEIGHT / source_height
    normalized: list[Image.Image] = []
    for pose in poses:
        size = (
            max(1, round(pose.width * scale)),
            max(1, round(pose.height * scale)),
        )
        resized = pose.resize(size, Image.Resampling.NEAREST)
        if resized.width >= FRAME_SIZE[0]:
            raise ValueError(
                f"Normalized pose width {resized.width} exceeds frame width {FRAME_SIZE[0]}"
            )
        canvas = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
        x = (FRAME_SIZE[0] - resized.width) // 2
        y = FOOT_BASELINE_Y - resized.height
        if y <= 0:
            raise ValueError(f"Normalized pose height {resized.height} leaves no top padding")
        canvas.alpha_composite(resized, (x, y))
        normalized.append(canvas)
    return normalized


def main() -> None:
    atlas = Image.new(
        "RGBA",
        (FRAME_SIZE[0] * FRAME_COUNT, FRAME_SIZE[1] * len(ACTIONS)),
        (0, 0, 0, 0),
    )
    generated_rows = _extract_generated_rows(GENERATED_ACTION_PATH)
    for row, action in enumerate(ACTIONS):
        if row < 4:
            poses = _extract_poses(STRIP_ROOT / f"{action}.png")
        else:
            source_row = generated_rows[row - 4]
            selected = [source_row[index] for index in GENERATED_ACTION_COLUMNS[action]]
            poses = [selected[index].copy() for index in PING_PONG_COLUMNS]
        if len(poses) != FRAME_COUNT:
            raise ValueError(f"{action}: expected {FRAME_COUNT} poses, found {len(poses)}")
        for column, pose in enumerate(_normalize_poses(poses)):
            atlas.alpha_composite(pose, (column * FRAME_SIZE[0], row * FRAME_SIZE[1]))

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(OUTPUT_PATH, optimize=True)
    print(f"Wrote {OUTPUT_PATH.relative_to(PROJECT_ROOT)} ({atlas.width}x{atlas.height})")


if __name__ == "__main__":
    main()
