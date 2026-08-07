#!/usr/bin/env python3
"""Report large GDScript files and functions without modifying the project."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT_ROOT = ROOT / "scripts"
FUNCTION_PATTERN = re.compile(r"^(?:static\s+)?func\s+([A-Za-z0-9_]+)", re.MULTILINE)


def function_spans(text: str) -> list[tuple[str, int, int]]:
	lines = text.splitlines()
	starts: list[tuple[str, int]] = []
	for line_number, line in enumerate(lines, start=1):
		match = FUNCTION_PATTERN.match(line)
		if match:
			starts.append((match.group(1), line_number))
	result: list[tuple[str, int, int]] = []
	for index, (name, start) in enumerate(starts):
		end = starts[index + 1][1] - 1 if index + 1 < len(starts) else len(lines)
		result.append((name, start, end - start + 1))
	return result


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--limit", type=int, default=20, help="number of files/functions to show")
	args = parser.parse_args()
	files: list[tuple[int, Path, str]] = []
	functions: list[tuple[int, Path, str, int]] = []
	for path in SCRIPT_ROOT.rglob("*.gd"):
		text = path.read_text(encoding="utf-8")
		line_count = len(text.splitlines())
		files.append((line_count, path, text))
		for name, start, span in function_spans(text):
			functions.append((span, path, name, start))
	print("LARGEST GDSCRIPT FILES (review by responsibility, not arbitrary line slices)")
	for line_count, path, _text in sorted(files, reverse=True)[: args.limit]:
		print(f"{line_count:>6}  {path.relative_to(ROOT)}")
	print("\nLARGEST FUNCTIONS")
	for span, path, name, start in sorted(functions, reverse=True)[: args.limit]:
		print(f"{span:>6}  {path.relative_to(ROOT)}:{start}  {name}")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
