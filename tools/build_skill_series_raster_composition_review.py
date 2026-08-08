#!/usr/bin/env python3
"""Render crop-first skill material review evidence from the JSON authority."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont


BACKGROUND = (17, 24, 32, 255)
PANEL = (23, 35, 46, 255)
OUTLINE = (62, 83, 99, 255)
LABEL = (243, 213, 138, 255)
PHASES = ("anticipation", "travel", "contact", "residual")
TIER_NAMES = ("basic", "advanced", "master")
CELL = (384, 270)
FRAME_SIZE = (1920, 1080)


def project_path(root: Path, resource_path: str) -> Path:
    if not resource_path.startswith("res://"):
        raise ValueError(f"Expected res:// path, got {resource_path!r}")
    return root / resource_path.removeprefix("res://")


def load_mapping(root: Path, mapping_path: Path) -> dict[str, Any]:
    document = json.loads(mapping_path.read_text(encoding="utf-8"))
    if document.get("phase_order") != list(PHASES):
        raise ValueError("Composition mapping phase order is not canonical.")
    if document.get("composition_rules", {}).get("whole_sheet_translation") is not False:
        raise ValueError("Review helper refuses mappings that permit whole-sheet translation.")
    for entry in document["series"] + document["blessing_overlays"]:
        source = Image.open(project_path(root, entry["asset_path"])).convert("RGBA")
        if source.size != (1254, 1254):
            raise ValueError(f"{entry['id']} source is {source.size}, expected 1254 square.")
    return document


def crop_component(source: Image.Image, component: dict[str, Any]) -> Image.Image:
    x, y, width, height = (int(value) for value in component["region"])
    return source.crop((x, y, x + width, y + height))


def component_image(
    root: Path,
    entry: dict[str, Any],
    component: dict[str, Any],
    category: str,
) -> Image.Image:
    isolated_resource_path = str(component.get("asset_path", ""))
    isolated_path = (
        project_path(root, isolated_resource_path)
        if isolated_resource_path
        else root / "assets/generated/vfx/skill_materials/components" / category / f"{entry['id']}__{component['id']}.png"
    )
    if isolated_path.exists():
        return Image.open(isolated_path).convert("RGBA")
    source = Image.open(project_path(root, entry["asset_path"])).convert("RGBA")
    return crop_component(source, component)


def save_native_components(
    root: Path,
    output_dir: Path,
    category: str,
    entries: list[dict[str, Any]],
) -> list[tuple[str, Image.Image]]:
    component_dir = output_dir / "native_components" / category
    component_dir.mkdir(parents=True, exist_ok=True)
    review_entries: list[tuple[str, Image.Image]] = []
    for entry in entries:
        for component in entry["components"]:
            image = component_image(root, entry, component, category)
            label = f"{entry['id']} / {component['id']} / {component['role_hint']}"
            image.save(component_dir / f"{entry['id']}__{component['id']}.png")
            review_entries.append((label, image))
    return review_entries


def build_native_sheet(output_path: Path, entries: list[tuple[str, Image.Image]]) -> Image.Image:
    """Pack unscaled component crops; the sheet itself preserves native pixels."""
    columns = 3
    column_width = max(image.width for _, image in entries) + 32
    rows = math.ceil(len(entries) / columns)
    row_heights = []
    for row in range(rows):
        row_entries = entries[row * columns:(row + 1) * columns]
        row_heights.append(max(image.height for _, image in row_entries) + 54)
    sheet = Image.new("RGBA", (columns * column_width, sum(row_heights)), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    y = 0
    font = ImageFont.load_default()
    for row, row_height in enumerate(row_heights):
        for column in range(columns):
            index = row * columns + column
            if index >= len(entries):
                break
            label, image = entries[index]
            x = column * column_width
            draw.rectangle((x + 4, y + 4, x + column_width - 4, y + row_height - 4), fill=PANEL, outline=OUTLINE, width=2)
            draw.text((x + 14, y + 13), label, fill=LABEL, font=font)
            sheet.alpha_composite(image, (x + 14, y + 40))
        y += row_height
    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path)
    return sheet


def transformed_component(
    image: Image.Image,
    layer: dict[str, Any],
    scale_multiplier: float,
    rotation_offset: float,
    opacity: float,
) -> Image.Image:
    scale_x, scale_y = (float(value) * scale_multiplier for value in layer["scale"])
    target_size = (max(1, round(image.width * scale_x)), max(1, round(image.height * scale_y)))
    image = image.resize(target_size, Image.Resampling.LANCZOS)
    alpha = image.getchannel("A").point(lambda value: round(value * opacity))
    image.putalpha(alpha)
    rotation = -float(layer["rotation_degrees"]) - rotation_offset
    if abs(rotation) > 0.01:
        image = image.rotate(rotation, resample=Image.Resampling.BICUBIC, expand=True)
    return image


def anchor_point(anchor: str) -> tuple[float, float]:
    if "source" in anchor:
        return (112.0, 168.0)
    if "path" in anchor:
        return (246.0, 166.0)
    return (348.0, 180.0)


def instance_centers(
    layer: dict[str, Any],
    count: int,
) -> list[tuple[float, float, float, float]]:
    """Return x, y, rotation offset, scale multiplier for deterministic review."""
    stack = layer["stack"]
    mode = str(stack["mode"])
    base_x, base_y = anchor_point(str(layer["anchor"]))
    offset_x, offset_y = (float(value) for value in layer["offset"])
    base_x += offset_x
    base_y += offset_y
    rotation_step = float(stack["rotation_step_degrees"])
    spacing = float(stack["spacing_pixels"])
    values: list[tuple[float, float, float, float]] = []
    for index in range(count):
        centered = index - (count - 1) / 2.0
        x, y = base_x, base_y
        rotation = centered * rotation_step
        scale = 1.0
        if mode == "path_overlap":
            progress = (index + 0.5) / max(1, count)
            x = 86.0 + progress * 280.0
            y = base_y + math.sin(progress * math.pi) * -28.0 + centered * min(3.0, spacing * 0.04)
        elif mode == "vertical_stagger":
            x += centered * min(12.0, spacing * 0.22)
            y -= index * max(12.0, spacing * 0.55)
            scale = 0.92 + index * 0.035
        elif mode == "orbit":
            angle = -math.pi / 2.0 + index * math.tau / max(1, count)
            radius = max(18.0, spacing * 0.75)
            x += math.cos(angle) * radius
            y += math.sin(angle) * radius
            rotation += math.degrees(angle) + 90.0
        elif mode == "contact_fan":
            angle = math.radians(-70.0 + (140.0 * index / max(1, count - 1)))
            radius = max(8.0, spacing * 0.55)
            x += math.cos(angle) * radius
            y += math.sin(angle) * radius
        elif mode == "concentric":
            scale = 0.78 + 0.18 * index
            rotation += index * rotation_step
        values.append((x, y, rotation, scale))
    return values


def composite_layer(canvas: Image.Image, image: Image.Image, center: tuple[float, float], blend: str) -> None:
    position = (round(center[0] - image.width / 2), round(center[1] - image.height / 2))
    if blend == "add":
        # Screen is a stable CPU approximation for reviewing the intended additive overlap.
        patch = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        patch.alpha_composite(image, position)
        rgb = Image.merge("RGB", canvas.convert("RGB").split())
        overlay_rgb = patch.convert("RGB")
        screened = Image.blend(rgb, Image.new("RGB", canvas.size, (255, 255, 255)), 0.0)
        from PIL import ImageChops
        screened = ImageChops.screen(rgb, overlay_rgb)
        mask = patch.getchannel("A")
        canvas.alpha_composite(Image.composite(screened.convert("RGBA"), canvas, mask))
    else:
        canvas.alpha_composite(image, position)


def render_stage(
    root: Path,
    entry: dict[str, Any],
    phase: str,
    tier: str,
    canvas: Image.Image,
    category: str,
    opacity: float = 1.0,
) -> None:
    components = {component["id"]: component for component in entry["components"]}
    stage = next(stage for stage in entry["stages"] if stage["phase"] == phase)
    for layer in stage["layers"]:
        component = components[layer["component"]]
        count = int(layer["stack"]["count_by_tier"][tier])
        for x, y, rotation_offset, scale_multiplier in instance_centers(layer, count):
            raw_component = component_image(root, entry, component, category)
            image = transformed_component(raw_component, layer, scale_multiplier, rotation_offset, opacity)
            composite_layer(canvas, image, (x, y), str(layer["blend"]))


def draw_phase_cell(
    root: Path,
    canvas: Image.Image,
    origin: tuple[int, int],
    series: dict[str, Any],
    overlay: dict[str, Any],
    phase: str,
    tier: str,
    index: int,
) -> None:
    cell = Image.new("RGBA", CELL, PANEL)
    draw = ImageDraw.Draw(cell)
    draw.rounded_rectangle((4, 4, CELL[0] - 4, CELL[1] - 4), radius=16, outline=OUTLINE, width=2)
    draw.text((12, 10), f"{series['id']} + {overlay['id']} / {phase}", fill=LABEL, font=ImageFont.load_default())
    draw.line((82, 214, 368, 214), fill=(72, 68, 54, 255), width=2)
    render_stage(root, series, phase, tier, cell, "base", 0.90)
    render_stage(root, overlay, phase, tier, cell, "blessing", 0.72)
    canvas.alpha_composite(cell, origin)


def save_slices(frame: Image.Image, output_dir: Path, stem: str) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    slice_width = frame.width // 3
    slice_height = frame.height // 2
    for row in range(2):
        for column in range(3):
            left = column * slice_width
            top = row * slice_height
            right = frame.width if column == 2 else left + slice_width
            bottom = frame.height if row == 1 else top + slice_height
            frame.crop((left, top, right, bottom)).save(output_dir / f"{stem}_R{row + 1}C{column + 1}.png")


def build_phase_frame(
    root: Path,
    output_dir: Path,
    series_entries: list[dict[str, Any]],
    overlays: list[dict[str, Any]],
    phase: str,
    tier: str,
) -> Image.Image:
    frame = Image.new("RGBA", FRAME_SIZE, BACKGROUND)
    cursor = 0
    for row, row_count in enumerate((5, 4, 4)):
        start_x = (frame.width - row_count * CELL[0]) // 2
        for column in range(row_count):
            series = series_entries[cursor]
            overlay = overlays[cursor % len(overlays)]
            draw_phase_cell(root, frame, (start_x + column * CELL[0], row * CELL[1]), series, overlay, phase, tier, cursor)
            cursor += 1
    path = output_dir / f"integrated_{phase}_{tier}.png"
    frame.save(path)
    save_slices(frame, output_dir / f"integrated_{phase}_{tier}_slices", f"integrated_{phase}_{tier}")
    return frame


def build_phase_timeline(output_dir: Path, frames: list[tuple[str, Image.Image]]) -> None:
    thumb_size = (960, 540)
    timeline = Image.new("RGBA", (1920, 1080), BACKGROUND)
    draw = ImageDraw.Draw(timeline)
    for index, (phase, frame) in enumerate(frames):
        thumb = frame.resize(thumb_size, Image.Resampling.LANCZOS)
        position = ((index % 2) * thumb_size[0], (index // 2) * thumb_size[1])
        timeline.alpha_composite(thumb, position)
        draw.rectangle((position[0] + 8, position[1] + 8, position[0] + 210, position[1] + 34), fill=(0, 0, 0, 180))
        draw.text((position[0] + 14, position[1] + 14), phase, fill=LABEL, font=ImageFont.load_default())
    timeline.save(output_dir / "integrated_phase_timeline.png")
    save_slices(timeline, output_dir / "integrated_phase_timeline_slices", "integrated_phase_timeline")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    parser.add_argument(
        "--mapping",
        type=Path,
        default=Path("data/skill_series_raster_composition.json"),
    )
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--tier", choices=TIER_NAMES, default="master")
    args = parser.parse_args()

    root = args.project_root.resolve()
    mapping_path = args.mapping if args.mapping.is_absolute() else root / args.mapping
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    document = load_mapping(root, mapping_path)
    series_entries = document["series"]
    overlays = document["blessing_overlays"]

    base_components = save_native_components(root, output_dir, "base", series_entries)
    overlay_components = save_native_components(root, output_dir, "blessing", overlays)
    build_native_sheet(output_dir / "native_base_component_contact_sheet.png", base_components)
    build_native_sheet(output_dir / "native_blessing_component_contact_sheet.png", overlay_components)

    frames = [
        (phase, build_phase_frame(root, output_dir, series_entries, overlays, phase, args.tier))
        for phase in PHASES
    ]
    build_phase_timeline(output_dir, frames)
    (output_dir / "README.txt").write_text(
        "\n".join(
            [
                "Generated from data/skill_series_raster_composition.json.",
                "Native component files and native contact sheets are unscaled source-pixel crops.",
                f"Integrated phase sheets use deterministic {args.tier} stack counts.",
                "Additive layers use a CPU screen approximation; Godot remains the blend authority.",
                "Every integrated frame and the four-phase timeline includes fixed 3x2 slices.",
                "Review full frame, every native component, and every R1C1..R2C3 slice after mapping changes.",
            ]
        ) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
