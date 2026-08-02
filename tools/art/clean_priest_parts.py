"""Remove disconnected generation islands from the priest lower-robe tiles."""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter


PROJECT_ROOT = Path(__file__).resolve().parents[2]
FRONT_PATH = PROJECT_ROOT / "assets" / "town" / "npc" / "priest" / "parts" / "priest_front_parts.png"
TILE_SIZE = (384, 256)


def keep_largest_component(tile: Image.Image) -> Image.Image:
    alpha = tile.getchannel("A")
    pixels = alpha.load()
    visited: set[tuple[int, int]] = set()
    components: list[list[tuple[int, int]]] = []
    for y in range(tile.height):
        for x in range(tile.width):
            if pixels[x, y] < 16 or (x, y) in visited:
                continue
            queue = deque([(x, y)])
            visited.add((x, y))
            component: list[tuple[int, int]] = []
            while queue:
                point = queue.popleft()
                component.append(point)
                px, py = point
                for neighbor in ((px + 1, py), (px - 1, py), (px, py + 1), (px, py - 1)):
                    nx, ny = neighbor
                    if not (0 <= nx < tile.width and 0 <= ny < tile.height):
                        continue
                    if neighbor in visited or pixels[nx, ny] < 16:
                        continue
                    visited.add(neighbor)
                    queue.append(neighbor)
            components.append(component)

    largest = max(components, key=len)
    keep = Image.new("L", tile.size, 0)
    keep_pixels = keep.load()
    for x, y in largest:
        keep_pixels[x, y] = 255
    keep = keep.filter(ImageFilter.MaxFilter(5))

    cleaned = tile.copy()
    cleaned_pixels = cleaned.load()
    keep_pixels = keep.load()
    for y in range(tile.height):
        for x in range(tile.width):
            if keep_pixels[x, y] == 0:
                cleaned_pixels[x, y] = (0, 0, 0, 0)
    return cleaned


def main() -> None:
    sheet = Image.open(FRONT_PATH).convert("RGBA")
    contaminated_tiles = (
        (0, 0),
        (1, 1),
        (1, 2),
        (1, 3),
        (2, 0),
        (2, 1),
        (2, 2),
        (2, 3),
    )
    for row, column in contaminated_tiles:
        box = (
            column * TILE_SIZE[0],
            row * TILE_SIZE[1],
            (column + 1) * TILE_SIZE[0],
            (row + 1) * TILE_SIZE[1],
        )
        cleaned = keep_largest_component(sheet.crop(box))
        sheet.paste(cleaned, (box[0], box[1]))
    sheet.save(FRONT_PATH, optimize=True)
    print(f"Cleaned {FRONT_PATH.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    main()
