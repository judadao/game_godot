#!/usr/bin/env python3
"""Alpha-separate reviewed multi-cell VFX plates into reusable component PNGs."""

from __future__ import annotations

import argparse
import hashlib
import itertools
import json
from pathlib import Path
from typing import Any

from PIL import Image


# One component may own several anchors so long silhouettes and paired courts
# claim their detached authored fragments without claiming neighboring cells.
ANCHORS: dict[str, dict[str, list[tuple[int, int]]]] = {
    "sword_rain": {"lock_star": [(390, 390)], "blue_crescent": [(470, 800), (980, 590)], "crystal_debris": [(610, 1040)]},
    "moon_wheel": {"moon_crescent": [(320, 620)], "moon_burst": [(900, 480)], "moon_shards": [(900, 900)]},
    "feather": {"feather_fan": [(620, 250)], "feather_dash": [(600, 620)], "falling_feathers": [(620, 1000)]},
    "thorn": {"thorn_seed": [(290, 300)], "thorn_run": [(500, 620), (1050, 610)], "thorn_bloom": [(850, 1030)]},
    "dr_stone": {"stone_orbit": [(390, 350)], "stone_lance": [(860, 660)], "stone_crater": [(610, 1050)]},
    "black_hole": {"void_ring": [(260, 280)], "void_comet": [(760, 610)], "void_collapse": [(920, 990)]},
    "fire": {"fire_pillar": [(360, 360)], "fire_lane": [(260, 840), (1050, 790)], "fire_burst": [(850, 1080)]},
    "lightning": {"storm_ring": [(600, 250)], "chain_bolt": [(200, 620), (1050, 650)], "sky_impact": [(620, 1060)]},
    "water_flow": {"tidal_curl": [(360, 320)], "water_stream": [(260, 850), (1000, 520)], "water_splash": [(900, 1010)]},
    "arcane_swamp": {"swamp_crown": [(390, 360)], "swamp_tendril": [(260, 850), (970, 600)], "swamp_splash": [(880, 1030)]},
    "dragon_breath": {"dragon_head": [(290, 260)], "breath_beam": [(240, 650), (1040, 650)], "breath_burst": [(900, 1050)]},
    "dawn_vitality": {"sun_bloom": [(340, 390)], "rising_leaves": [(970, 400)], "healing_court": [(280, 1010), (950, 1010)]},
    "shared_branch_vitality": {"branch_aura": [(330, 300)], "branch_dash": [(250, 690), (1000, 650)], "branch_court": [(300, 1040), (930, 1040)]},
    "dark": {"void_seed": [(310, 370)], "void_streak": [(850, 600)], "void_burst": [(820, 960)]},
    "fire_overlay": {"flare_seed": [(310, 340)], "flame_streak": [(850, 640)], "fire_burst": [(850, 990)]},
    "ice": {"ice_seed": [(310, 330)], "ice_streak": [(850, 570)], "ice_burst": [(850, 950)]},
    "light": {"light_seed": [(310, 330)], "light_streak": [(850, 620)], "light_burst": [(900, 980)]},
    "lightning_overlay": {"bolt_seed": [(300, 250)], "bolt_streak": [(700, 610)], "bolt_burst": [(930, 990)]},
    "poison": {"poison_seed": [(330, 350)], "poison_streak": [(820, 610)], "poison_burst": [(860, 970)]},
    "water": {"water_seed": [(300, 320)], "water_streak": [(820, 610)], "water_burst": [(860, 990)]},
    "wind": {"wind_seed": [(300, 300)], "wind_streak": [(820, 600)], "wind_burst": [(950, 1000)]},
}


def project_path(root: Path, resource_path: str) -> Path:
    return root / resource_path.removeprefix("res://")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def anchor_key(entry: dict[str, Any], category: str) -> str:
    entry_id = str(entry["id"])
    if category == "blessing" and entry_id in {"fire", "lightning"}:
        return f"{entry_id}_overlay"
    return entry_id


def nearest_component(
    x: float,
    y: float,
    component_anchors: list[tuple[str, list[tuple[int, int]]]],
) -> str:
    best_id = ""
    best_distance = 2**63 - 1
    for component_id, anchors in component_anchors:
        distance = min((x - anchor_x) ** 2 + (y - anchor_y) ** 2 for anchor_x, anchor_y in anchors)
        if distance < best_distance:
            best_id = component_id
            best_distance = distance
    return best_id


def alpha_islands(
    alpha_bytes: bytes,
    width: int,
    height: int,
    alpha_bbox: tuple[int, int, int, int],
) -> list[tuple[list[int], float, float]]:
    """Return 8-connected non-zero-alpha islands and their centroids."""
    visited = bytearray(width * height)
    left, top, right, bottom = alpha_bbox
    islands: list[tuple[list[int], float, float]] = []
    neighbor_offsets = (
        (-1, -1), (0, -1), (1, -1),
        (-1, 0), (1, 0),
        (-1, 1), (0, 1), (1, 1),
    )
    for y in range(top, bottom):
        row = y * width
        for x in range(left, right):
            start = row + x
            if visited[start] or alpha_bytes[start] == 0:
                continue
            visited[start] = 1
            stack = [start]
            pixels: list[int] = []
            sum_x = 0
            sum_y = 0
            while stack:
                index = stack.pop()
                pixel_y, pixel_x = divmod(index, width)
                pixels.append(index)
                sum_x += pixel_x
                sum_y += pixel_y
                for dx, dy in neighbor_offsets:
                    neighbor_x = pixel_x + dx
                    neighbor_y = pixel_y + dy
                    if neighbor_x < left or neighbor_x >= right or neighbor_y < top or neighbor_y >= bottom:
                        continue
                    neighbor = neighbor_y * width + neighbor_x
                    if visited[neighbor] or alpha_bytes[neighbor] == 0:
                        continue
                    visited[neighbor] = 1
                    stack.append(neighbor)
            islands.append((pixels, sum_x / len(pixels), sum_y / len(pixels)))
    return islands


def choose_main_islands(
    islands: list[tuple[list[int], float, float]],
    component_anchors: list[tuple[str, list[tuple[int, int]]]],
) -> dict[str, int]:
    """Choose one distinct large anchor-near island for every component."""
    candidate_indices = sorted(range(len(islands)), key=lambda index: len(islands[index][0]), reverse=True)[:12]
    if len(candidate_indices) < len(component_anchors):
        raise ValueError("Not enough alpha islands to identify all components.")
    best_score = float("inf")
    best_assignment: dict[str, int] = {}
    for indices in itertools.permutations(candidate_indices, len(component_anchors)):
        score = 0.0
        assignment: dict[str, int] = {}
        for (component_id, anchors), island_index in zip(component_anchors, indices):
            pixels, centroid_x, centroid_y = islands[island_index]
            anchor_distance = min(
                (centroid_x - anchor_x) ** 2 + (centroid_y - anchor_y) ** 2
                for anchor_x, anchor_y in anchors
            )
            score += anchor_distance + 50_000_000.0 / max(1, len(pixels))
            assignment[component_id] = island_index
        if score < best_score:
            best_score = score
            best_assignment = assignment
    return best_assignment


def nearest_main_component(
    centroid_x: float,
    centroid_y: float,
    main_samples: dict[str, list[tuple[int, int]]],
) -> str:
    best_id = ""
    best_distance = float("inf")
    for component_id, samples in main_samples.items():
        distance = min(
            (centroid_x - sample_x) ** 2 + (centroid_y - sample_y) ** 2
            for sample_x, sample_y in samples
        )
        if distance < best_distance:
            best_id = component_id
            best_distance = distance
    return best_id


def manual_partition(key: str, x: int, y: int) -> str:
    """Resolve plates whose authored cells touch into one alpha island."""
    if key == "sword_rain":
        if y >= 900:
            return "crystal_debris"
        if x <= 700 and y <= 700:
            return "lock_star"
        return "blue_crescent"
    if key == "thorn":
        if x < 560 and y < 530:
            return "thorn_seed"
        if x > 500 and y > 770:
            return "thorn_bloom"
        return "thorn_run"
    if key == "feather":
        if y < 430:
            return "feather_fan"
        if y < 800:
            return "feather_dash"
        return "falling_feathers"
    if key == "dr_stone":
        if y > 850:
            return "stone_crater"
        if y > (-0.8 * x + 1100):
            return "stone_lance"
        return "stone_orbit"
    if key == "black_hole":
        if x > 650 and y > 780:
            return "void_collapse"
        if x < 490 and y < 510:
            return "void_ring"
        return "void_comet"
    if key == "fire":
        if x > 500 and y > 925:
            return "fire_burst"
        if x < 720 and y < 710:
            return "fire_pillar"
        return "fire_lane"
    if key == "water_flow":
        if x > 630 and y > 700:
            return "water_splash"
        if x < 760 and y < 560:
            return "tidal_curl"
        return "water_stream"
    if key == "arcane_swamp":
        if x > 600 and y > 850:
            return "swamp_splash"
        if x < 720 and y < 590:
            return "swamp_crown"
        return "swamp_tendril"
    if key == "dragon_breath":
        if x > 620 and y > 835:
            return "breath_burst"
        if x < 570 and y < 470:
            return "dragon_head"
        return "breath_beam"
    if key == "shared_branch_vitality":
        if y > 800:
            return "branch_court"
        if x < 610 and y < 520:
            return "branch_aura"
        return "branch_dash"
    if key == "dawn_vitality":
        if y > 700:
            return "healing_court"
        if x < 700:
            return "sun_bloom"
        return "rising_leaves"
    return ""


def separate_entry(
    root: Path,
    output_dir: Path,
    entry: dict[str, Any],
    category: str,
) -> list[dict[str, Any]]:
    source_path = project_path(root, entry["asset_path"])
    source = Image.open(source_path).convert("RGBA")
    width, height = source.size
    alpha = source.getchannel("A")
    alpha_bytes = alpha.tobytes()
    key = anchor_key(entry, category)
    expected_ids = [str(component["id"]) for component in entry["components"]]
    anchor_map = ANCHORS.get(key, {})
    if set(anchor_map) != set(expected_ids):
        raise ValueError(f"{entry['id']} anchor ids {sorted(anchor_map)} do not match {sorted(expected_ids)}")
    component_anchors = [(component_id, anchor_map[component_id]) for component_id in expected_ids]
    masks = {component_id: bytearray(width * height) for component_id in expected_ids}

    alpha_bbox = alpha.getbbox()
    if alpha_bbox is None:
        raise ValueError(f"{entry['id']} source has no alpha.")
    if manual_partition(key, 0, 0):
        left, top, right, bottom = alpha_bbox
        for y in range(top, bottom):
            row = y * width
            for x in range(left, right):
                index = row + x
                if alpha_bytes[index] == 0:
                    continue
                component_id = manual_partition(key, x, y)
                masks[component_id][index] = alpha_bytes[index]
    else:
        islands = alpha_islands(alpha_bytes, width, height, alpha_bbox)
        main_islands = choose_main_islands(islands, component_anchors)
        island_owners = {island_index: component_id for component_id, island_index in main_islands.items()}
        main_samples: dict[str, list[tuple[int, int]]] = {}
        for component_id, island_index in main_islands.items():
            main_pixels = islands[island_index][0]
            step = max(1, len(main_pixels) // 2000)
            main_samples[component_id] = [
                (index % width, index // width)
                for index in main_pixels[::step]
            ]
        for island_index, (pixels, centroid_x, centroid_y) in enumerate(islands):
            component_id = island_owners.get(
                island_index,
                nearest_main_component(centroid_x, centroid_y, main_samples),
            )
            component_mask = masks[component_id]
            for index in pixels:
                component_mask[index] = alpha_bytes[index]

    output_dir.mkdir(parents=True, exist_ok=True)
    manifest: list[dict[str, Any]] = []
    for component_id in expected_ids:
        mask = Image.frombytes("L", source.size, bytes(masks[component_id]))
        bbox = mask.getbbox()
        if bbox is None:
            raise ValueError(f"{entry['id']}/{component_id} extracted no pixels.")
        binary_mask = mask.point(lambda value: 255 if value else 0)
        isolated = Image.composite(
            source,
            Image.new("RGBA", source.size, (0, 0, 0, 0)),
            binary_mask,
        )
        isolated.putalpha(mask)
        trimmed = isolated.crop(bbox)
        filename = f"{entry['id']}__{component_id}.png"
        output_path = output_dir / filename
        trimmed.save(output_path)
        manifest.append(
            {
                "category": category,
                "entry_id": entry["id"],
                "component_id": component_id,
                "source_asset_path": entry["asset_path"],
                "source_sha256": sha256(source_path),
                "asset_path": f"res://assets/generated/vfx/skill_materials/components/{category}/{filename}",
                "asset_sha256": sha256(output_path),
                "source_alpha_bbox": list(bbox),
                "isolated_size": list(trimmed.size),
                "anchors": [list(anchor) for anchor in anchor_map[component_id]],
            }
        )
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    parser.add_argument("--mapping", type=Path, default=Path("data/skill_series_raster_composition.json"))
    parser.add_argument(
        "--output-root",
        type=Path,
        default=Path("assets/generated/vfx/skill_materials/components"),
    )
    args = parser.parse_args()
    root = args.project_root.resolve()
    mapping_path = args.mapping if args.mapping.is_absolute() else root / args.mapping
    output_root = args.output_root if args.output_root.is_absolute() else root / args.output_root
    document = json.loads(mapping_path.read_text(encoding="utf-8"))
    manifest: list[dict[str, Any]] = []
    for category, entries in (
        ("base", document["series"]),
        ("blessing", document["blessing_overlays"]),
    ):
        for entry in entries:
            manifest.extend(separate_entry(root, output_root / category, entry, category))
    (output_root / "manifest.json").write_text(
        json.dumps(
            {
                "schema_version": 1,
                "algorithm": "For touching difficult plates, classify each non-zero-alpha source pixel with the explicit source-coordinate partition in the generator. Otherwise find 8-connected alpha islands, choose one distinct large anchor-near main island per component, and assign detached islands to the nearest sampled main-island pixel. Preserve original RGBA pixels exactly and trim to assigned alpha bbox.",
                "generator": "res://tools/build_skill_series_raster_components.py",
                "components": manifest,
            },
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {len(manifest)} alpha-isolated components to {output_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
