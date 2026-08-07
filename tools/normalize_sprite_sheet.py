#!/usr/bin/env python3
"""Normalize generated 4x6 NPC sheets into strict, bleed-free 256px cells."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def remove_light_checkerboard(image: Image.Image) -> Image.Image:
    """Turn image-generator preview checkerboards into real transparency.

    The exported checkerboard consists of near-neutral light pixels. Pixel-art
    character whites are warm/cool tinted and retain enough channel spread to
    survive this matte pass.
    """
    result = image.convert("RGBA")
    pixels = result.load()
    for y in range(result.height):
        for x in range(result.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                continue
            darkest = min(red, green, blue)
            lightest = max(red, green, blue)
            if darkest >= 228 and lightest - darkest <= 14:
                pixels[x, y] = (0, 0, 0, 0)
    return result


def remove_top_edge_bleed(cell: Image.Image) -> Image.Image:
    """Remove a shallow disconnected fragment inherited from the previous row."""
    alpha = cell.getchannel("A")
    pixels = alpha.load()
    width, height = cell.size
    seeds = [(x, y) for y in range(min(6, height)) for x in range(width) if pixels[x, y] > 0]
    if not seeds:
        return cell
    visited: set[tuple[int, int]] = set()
    stack = seeds
    max_y = 0
    while stack:
        point = stack.pop()
        if point in visited:
            continue
        x, y = point
        if x < 0 or y < 0 or x >= width or y >= height or pixels[x, y] == 0:
            continue
        visited.add(point)
        max_y = max(max_y, y)
        stack.extend(((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))
    if max_y >= round(height * 0.45):
        return cell
    cleaned = cell.copy()
    cleaned_pixels = cleaned.load()
    for x, y in visited:
        cleaned_pixels[x, y] = (0, 0, 0, 0)
    return cleaned


def remove_edge_fragments(cell: Image.Image) -> Image.Image:
    """Drop disconnected carry-over effects that hug a generated cell edge."""
    cleaned = cell.copy()
    alpha = cleaned.getchannel("A")
    source = alpha.load()
    pixels = cleaned.load()
    width, height = cleaned.size
    visited: set[tuple[int, int]] = set()
    for y in range(height):
        for x in range(width):
            if source[x, y] == 0 or (x, y) in visited:
                continue
            component: list[tuple[int, int]] = []
            stack = [(x, y)]
            while stack:
                point = stack.pop()
                if point in visited:
                    continue
                px, py = point
                if px < 0 or py < 0 or px >= width or py >= height or source[px, py] == 0:
                    continue
                visited.add(point)
                component.append(point)
                stack.extend(((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)))
            min_x = min(point[0] for point in component)
            max_x = max(point[0] for point in component)
            min_y = min(point[1] for point in component)
            max_y = max(point[1] for point in component)
            touches_edge = min_x <= 2 or min_y <= 2 or max_x >= width - 3 or max_y >= height - 3
            narrow_edge_piece = (max_x - min_x + 1) < width * 0.38 or (max_y - min_y + 1) < height * 0.30
            contains_center = min_x <= width / 2 <= max_x and min_y <= height / 2 <= max_y
            if touches_edge and narrow_edge_piece and not contains_center:
                for px, py in component:
                    pixels[px, py] = (0, 0, 0, 0)
    return cleaned


def clean_neon_key_spill(
    image: Image.Image,
    minimum_pixels: int = 80,
    slender_width: int = 10,
    slender_height: int = 80,
) -> Image.Image:
    cleaned = image.copy()
    pixels = cleaned.load()
    for y in range(cleaned.height):
        for x in range(cleaned.width):
            red, green, blue, alpha = pixels[x, y]
            if (
                alpha > 0
                # The generator's keyed matte leaves a dark 0x78 green fringe
                # after the bright core is removed; include that boundary while
                # retaining naturally muted greens in authored clothing.
                and green >= 115
                and green > red * 1.12
                and green > blue * 1.15
            ):
                pixels[x, y] = (0, 0, 0, 0)
    return remove_tiny_islands(cleaned, minimum_pixels, slender_width, slender_height)


def remove_tiny_islands(
    image: Image.Image,
    minimum_pixels: int = 80,
    slender_width: int = 10,
    slender_height: int = 80,
) -> Image.Image:
    cleaned = image.copy()
    alpha = cleaned.getchannel("A")
    source = alpha.load()
    pixels = cleaned.load()
    visited: set[tuple[int, int]] = set()
    for y in range(cleaned.height):
        for x in range(cleaned.width):
            if source[x, y] == 0 or (x, y) in visited:
                continue
            component: list[tuple[int, int]] = []
            stack = [(x, y)]
            while stack:
                point = stack.pop()
                if point in visited:
                    continue
                px, py = point
                if px < 0 or py < 0 or px >= cleaned.width or py >= cleaned.height or source[px, py] == 0:
                    continue
                visited.add(point)
                component.append(point)
                stack.extend(((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)))
            min_x = min(point[0] for point in component)
            max_x = max(point[0] for point in component)
            min_y = min(point[1] for point in component)
            max_y = max(point[1] for point in component)
            slender_fragment = (
                (max_x - min_x + 1) < slender_width
                and (max_y - min_y + 1) < slender_height
            )
            if len(component) < minimum_pixels or slender_fragment:
                for px, py in component:
                    pixels[px, py] = (0, 0, 0, 0)
    return cleaned


def fade_cell_edges(cell: Image.Image, gutter: int, fade: int) -> Image.Image:
    """Keep generated props inside their animation cell without hard crop seams."""
    if gutter <= 0 and fade <= 0:
        return cell
    result = cell.copy()
    pixels = result.load()
    width, height = result.size
    fade_end = gutter + max(fade, 1)
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                continue
            edge_distance = min(x, y, width - 1 - x, height - 1 - y)
            if edge_distance < gutter:
                pixels[x, y] = (0, 0, 0, 0)
            elif edge_distance < fade_end:
                factor = (edge_distance - gutter) / max(fade, 1)
                pixels[x, y] = (red, green, blue, round(alpha * factor))
    return result


def detected_row_boundaries(source: Image.Image, rows: int) -> list[tuple[int, int]]:
    """Find authored row bands when image generation uses uneven row gutters."""
    alpha = source.getchannel("A")
    occupied = [alpha.crop((0, y, source.width, y + 1)).getbbox() is not None for y in range(source.height)]
    ranges: list[tuple[int, int]] = []
    start: int | None = None
    for y, has_content in enumerate(occupied):
        if has_content and start is None:
            start = y
        elif not has_content and start is not None:
            ranges.append((start, y))
            start = None
    if start is not None:
        ranges.append((start, source.height))
    # Tiny one-pixel holes can split one illustrated row. Repeatedly merge the
    # pair with the smallest gap until the authored row count is recovered.
    while len(ranges) > rows:
        merge_index = min(range(len(ranges) - 1), key=lambda index: ranges[index + 1][0] - ranges[index][1])
        ranges[merge_index:merge_index + 2] = [(ranges[merge_index][0], ranges[merge_index + 1][1])]
    if len(ranges) != rows:
        raise ValueError(f"Expected {rows} occupied row bands, found {ranges}")
    boundaries: list[int] = [0]
    for index in range(rows - 1):
        boundaries.append((ranges[index][1] + ranges[index + 1][0]) // 2)
    boundaries.append(source.height)
    return [(boundaries[index], boundaries[index + 1]) for index in range(rows)]


def move_last_row_crowns(source: Image.Image, columns: int, rows: int) -> Image.Image:
    """Repair raised-relic crowns authored just above the last row boundary."""
    result = source.copy()
    boundary = round(result.height * (rows - 1) / rows)
    strip_height = 55
    cell_width = result.width / columns
    for column in range(columns):
        left = round(column * cell_width + cell_width * 0.11)
        right = round(column * cell_width + cell_width * 0.45)
        strip = result.crop((left, boundary - strip_height, right, boundary))
        result.paste(
            Image.new("RGBA", (right - left, strip_height), (0, 0, 0, 0)),
            (left, boundary - strip_height),
        )
        result.alpha_composite(strip, (left, boundary))
    return result


def extract_last_row_subject(
    source: Image.Image,
    column: int,
    columns: int,
    rows: int,
) -> Image.Image:
    """Extract the last-row actor even when its tall relic enters the prior band."""
    cell_width = source.width / columns
    left = round(column * cell_width)
    right = round((column + 1) * cell_width)
    boundary = round(source.height * (rows - 1) / rows)
    band_top = max(0, boundary - 160)
    band = source.crop((left, band_top, right, source.height))
    alpha = band.getchannel("A")
    source_alpha = alpha.load()
    visited: set[tuple[int, int]] = set()
    candidates: list[list[tuple[int, int]]] = []
    for y in range(band.height):
        for x in range(band.width):
            if source_alpha[x, y] == 0 or (x, y) in visited:
                continue
            component: list[tuple[int, int]] = []
            stack = [(x, y)]
            while stack:
                point = stack.pop()
                if point in visited:
                    continue
                px, py = point
                if px < 0 or py < 0 or px >= band.width or py >= band.height or source_alpha[px, py] == 0:
                    continue
                visited.add(point)
                component.append(point)
                stack.extend(((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)))
            if component and max(point[1] for point in component) >= band.height - 30:
                candidates.append(component)
    if not candidates:
        return band
    subject = max(candidates, key=len)
    result = Image.new("RGBA", band.size, (0, 0, 0, 0))
    result_pixels = result.load()
    band_pixels = band.load()
    for x, y in subject:
        result_pixels[x, y] = band_pixels[x, y]
    return result


def normalize(
    source_path: Path,
    output_path: Path,
    columns: int,
    rows: int,
    edge_gutter: int,
    edge_fade: int,
    remove_checkerboard: bool,
    detect_row_bands: bool,
    remove_neon_key: bool,
    repair_last_row_crowns: bool,
    extract_last_row: bool,
) -> None:
    source = Image.open(source_path).convert("RGBA")
    if remove_checkerboard:
        source = remove_light_checkerboard(source)
    if remove_neon_key:
        source = clean_neon_key_spill(source)
    if repair_last_row_crowns:
        source = move_last_row_crowns(source, columns, rows)
    source_cell_width = source.width / columns
    source_cell_height = source.height / rows
    row_boundaries = detected_row_boundaries(source, rows) if detect_row_bands else []
    target_cell = 256
    output = Image.new("RGBA", (columns * target_cell, rows * target_cell), (0, 0, 0, 0))
    for row in range(rows):
        for column in range(columns):
            left = round(column * source_cell_width)
            right = round((column + 1) * source_cell_width)
            if detect_row_bands:
                top, bottom = row_boundaries[row]
            else:
                top = round(row * source_cell_height)
                bottom = round((row + 1) * source_cell_height)
            cell = (
                extract_last_row_subject(source, column, columns, rows)
                if extract_last_row and row == rows - 1
                else source.crop((left, top, right, bottom))
            )
            cell = remove_edge_fragments(cell)
            cell = fade_cell_edges(cell, edge_gutter, edge_fade)
            # Image generation occasionally lets feet/props from the previous row
            # cross the nominal boundary. Remove only shallow components touching
            # the top edge so the current frame's head and tall props stay intact.
            if row > 0:
                cell = remove_top_edge_bleed(cell)
            alpha = cell.getchannel("A")
            bounds = alpha.getbbox()
            if bounds is None:
                continue
            content = cell.crop(bounds)
            max_width = target_cell - 12
            max_height = target_cell - 12
            scale = min(max_width / content.width, max_height / content.height, 1.0)
            resized = content.resize(
                (max(1, round(content.width * scale)), max(1, round(content.height * scale))),
                Image.Resampling.NEAREST,
            )
            x = column * target_cell + (target_cell - resized.width) // 2
            y = row * target_cell + target_cell - resized.height - 6
            output.alpha_composite(resized, (x, y))
    # Cropping and bottom-aligning can move an authored edge back near a target
    # cell boundary, so enforce the safe gutter once more on the final atlas.
    for row in range(rows):
        for column in range(columns):
            box = (
                column * target_cell,
                row * target_cell,
                (column + 1) * target_cell,
                (row + 1) * target_cell,
            )
            final_cell = fade_cell_edges(output.crop(box), edge_gutter, edge_fade)
            output.paste(final_cell, box)
    clean_neon_key_spill(output).save(output_path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--columns", type=int, default=4)
    parser.add_argument("--rows", type=int, default=6)
    parser.add_argument("--cleanup-only", action="store_true")
    parser.add_argument("--edge-gutter", type=int, default=0)
    parser.add_argument("--edge-fade", type=int, default=0)
    parser.add_argument("--minimum-island-pixels", type=int, default=80)
    parser.add_argument("--slender-width", type=int, default=10)
    parser.add_argument("--slender-height", type=int, default=80)
    parser.add_argument("--remove-light-checkerboard", action="store_true")
    parser.add_argument("--detect-row-bands", action="store_true")
    parser.add_argument("--remove-neon-key", action="store_true")
    parser.add_argument("--repair-last-row-crowns", action="store_true")
    parser.add_argument("--extract-last-row-subject", action="store_true")
    args = parser.parse_args()
    if args.cleanup_only:
        clean_neon_key_spill(
            Image.open(args.input).convert("RGBA"),
            args.minimum_island_pixels,
            args.slender_width,
            args.slender_height,
        ).save(args.out)
    else:
        normalize(
            args.input,
            args.out,
            args.columns,
            args.rows,
            args.edge_gutter,
            args.edge_fade,
            args.remove_light_checkerboard,
            args.detect_row_bands,
            args.remove_neon_key,
            args.repair_last_row_crowns,
            args.extract_last_row_subject,
        )


if __name__ == "__main__":
    main()
