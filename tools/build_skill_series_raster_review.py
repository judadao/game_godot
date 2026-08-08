#!/usr/bin/env python3
"""Build deterministic visual-review sheets for skill-series raster materials."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


SERIES = [
    "sword_rain", "moon_wheel", "feather", "thorn", "dr_stone",
    "black_hole", "fire", "lightning", "water_flow", "arcane_swamp",
    "dragon_breath", "dawn_vitality", "shared_branch_vitality",
]
ELEMENTS = ["dark", "fire", "ice", "light", "lightning", "poison", "water", "wind"]
BACKGROUND = (17, 24, 32, 255)
PANEL_A = (23, 35, 46, 255)
PANEL_B = (20, 32, 42, 255)
LABEL = (243, 213, 138, 255)
SERIES_PROFILES = {
    "sword_rain": (-28.0, 0.72, (8, -12)), "moon_wheel": (18.0, 0.80, (-10, 4)),
    "feather": (-12.0, 0.68, (12, -5)), "thorn": (34.0, 0.66, (-8, 12)),
    "dr_stone": (8.0, 0.62, (10, 8)), "black_hole": (88.0, 0.64, (0, 0)),
    "fire": (-38.0, 0.70, (8, 10)), "lightning": (90.0, 0.62, (-6, -4)),
    "water_flow": (0.0, 0.78, (12, 6)), "arcane_swamp": (24.0, 0.62, (-10, 10)),
    "dragon_breath": (0.0, 0.76, (16, -3)), "dawn_vitality": (96.0, 0.60, (0, 0)),
    "shared_branch_vitality": (-18.0, 0.64, (6, -8)),
}


def load_rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def fitted(image: Image.Image, extent: int, opacity: float = 1.0) -> Image.Image:
    ratio = extent / max(image.size)
    size = (max(1, round(image.width * ratio)), max(1, round(image.height * ratio)))
    result = image.resize(size, Image.Resampling.LANCZOS)
    if opacity < 1.0:
        alpha = result.getchannel("A").point(lambda value: round(value * opacity))
        result.putalpha(alpha)
    return result


def centered_composite(canvas: Image.Image, layer: Image.Image, center: tuple[int, int]) -> None:
    position = (center[0] - layer.width // 2, center[1] - layer.height // 2)
    canvas.alpha_composite(layer, position)


def draw_cell(
    canvas: Image.Image,
    origin: tuple[int, int],
    size: tuple[int, int],
    label: str,
    base: Image.Image,
    overlay: Image.Image | None,
    index: int,
) -> None:
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        (origin[0] + 5, origin[1] + 5, origin[0] + size[0] - 5, origin[1] + size[1] - 5),
        radius=18,
        fill=PANEL_A if index % 2 == 0 else PANEL_B,
        outline=(62, 83, 99, 255),
        width=2,
    )
    draw.text((origin[0] + 14, origin[1] + 12), label, fill=LABEL, font=ImageFont.load_default())
    center = (origin[0] + size[0] // 2, origin[1] + size[1] // 2 + 12)
    centered_composite(canvas, fitted(base, min(size) - 54, 0.78), center)
    if overlay is not None:
        series = label.split(" + ", maxsplit=1)[0]
        rotation, scale, offset = SERIES_PROFILES.get(series, (0.0, 0.72, (0, 0)))
        width, height = overlay.size
        components = [
            (overlay.crop((0, 0, round(width * 0.48), round(height * 0.48))), 76, 0.25, (-62, -48), 0.30),
            (overlay.crop((round(width * 0.36), round(height * 0.28), width, round(height * 0.62))), 150, 0.35, (8, -4), 0.30),
            (overlay.crop((round(width * 0.46), round(height * 0.56), width, height)), 104, 0.18, (58, 50), 0.42),
        ]
        for component, extent, rotation_mix, role_offset, opacity in components:
            layer = fitted(component, round(extent * scale), opacity).rotate(
                -rotation * rotation_mix, resample=Image.Resampling.BICUBIC, expand=True
            )
            role_center = (
                center[0] + offset[0] + role_offset[0],
                center[1] + offset[1] + role_offset[1],
            )
            centered_composite(canvas, layer, role_center)


def build_sheet(
    output: Path,
    entries: list[tuple[str, Image.Image, Image.Image | None]],
    columns: int,
    cell: tuple[int, int],
) -> Image.Image:
    rows = (len(entries) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * cell[0], rows * cell[1]), BACKGROUND)
    for index, (label, base, overlay) in enumerate(entries):
        origin = ((index % columns) * cell[0], (index // columns) * cell[1])
        draw_cell(sheet, origin, cell, label, base, overlay, index)
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)
    return sheet


def build_series_sheet(
    output: Path,
    entries: list[tuple[str, Image.Image, Image.Image | None]],
) -> Image.Image:
    """Lay out 13 production series as balanced 5/4/4 rows."""
    cell = (384, 360)
    sheet = Image.new("RGBA", (1920, 1080), BACKGROUND)
    cursor = 0
    for row, row_count in enumerate((5, 4, 4)):
        start_x = (sheet.width - row_count * cell[0]) // 2
        for column in range(row_count):
            label, base, overlay = entries[cursor]
            draw_cell(sheet, (start_x + column * cell[0], row * cell[1]), cell, label, base, overlay, cursor)
            cursor += 1
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)
    return sheet


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    root = args.project_root.resolve()
    output_dir = args.output_dir.resolve()
    base_dir = root / "assets/generated/vfx/skill_materials/base"
    overlay_dir = root / "assets/generated/vfx/skill_materials/blessings"
    bases = {name: load_rgba(base_dir / f"{name}_material_v1.png") for name in SERIES}
    overlays = {name: load_rgba(overlay_dir / f"{name}_overlay_v1.png") for name in ELEMENTS}

    build_sheet(
        output_dir / "native_base_contact_sheet.png",
        [(name, bases[name], None) for name in SERIES],
        columns=5,
        cell=(410, 410),
    )
    build_sheet(
        output_dir / "native_overlay_contact_sheet.png",
        [(name, overlays[name], None) for name in ELEMENTS],
        columns=4,
        cell=(512, 512),
    )
    for element in ELEMENTS:
        build_series_sheet(
            output_dir / f"blessing_{element}_all_series.png",
            [(f"{series} + {element}", bases[series], overlays[element]) for series in SERIES],
        )

    full_entries = [
        (f"{series} + {ELEMENTS[index % len(ELEMENTS)]}", bases[series], overlays[ELEMENTS[index % len(ELEMENTS)]])
        for index, series in enumerate(SERIES)
    ]
    full_frame = build_series_sheet(
        output_dir / "integrated_full_frame.png",
        full_entries,
    )
    slice_width = full_frame.width // 3
    slice_height = full_frame.height // 2
    for row in range(2):
        for column in range(3):
            left = column * slice_width
            top = row * slice_height
            right = full_frame.width if column == 2 else left + slice_width
            bottom = full_frame.height if row == 1 else top + slice_height
            full_frame.crop((left, top, right, bottom)).save(
                output_dir / f"integrated_full_frame_R{row + 1}C{column + 1}.png"
            )

    manifest = [
        "CPU review composition mirrors the production raster layer at impact timing.",
        "Godot's headless dummy renderer cannot provide a SubViewport capture in this workspace.",
        "Native sources remain the authority for alpha and brush-detail inspection.",
        "Series: " + ", ".join(SERIES),
        "Elements: " + ", ".join(ELEMENTS),
    ]
    (output_dir / "README.txt").write_text("\n".join(manifest) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
