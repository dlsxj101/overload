#!/usr/bin/env python3

"""Rebuild the runtime Black Han Sans font from project string literals."""

from __future__ import annotations

import ast
from pathlib import Path
import re
import tempfile

from fontTools.subset import Options, Subsetter
from fontTools.ttLib import TTFont


PROJECT_ROOT = Path(__file__).resolve().parent.parent
SOURCE_FONT = PROJECT_ROOT / "fonts/source/BlackHanSans-Regular.full.ttf"
OUTPUT_FONT = PROJECT_ROOT / "fonts/BlackHanSans-Regular.ttf"
RUNTIME_SUFFIXES = {".gd", ".tscn", ".tres"}
EXCLUDED_DIRECTORIES = {".git", ".godot", "tests", "tools", "web"}
QUOTED_STRING = re.compile(r'"(?:\\.|[^"\\])*"')
PRINTABLE_ASCII = {chr(codepoint) for codepoint in range(0x20, 0x7F)}


def runtime_sources() -> list[Path]:
    sources = [PROJECT_ROOT / "project.godot"]
    for path in PROJECT_ROOT.rglob("*"):
        if not path.is_file() or path.suffix not in RUNTIME_SUFFIXES:
            continue
        if any(part in EXCLUDED_DIRECTORIES for part in path.relative_to(PROJECT_ROOT).parts):
            continue
        sources.append(path)
    return sorted(set(sources))


def project_characters() -> set[str]:
    characters = set(PRINTABLE_ASCII)
    for path in runtime_sources():
        text = path.read_text(encoding="utf-8")
        for match in QUOTED_STRING.finditer(text):
            try:
                value = ast.literal_eval(match.group(0))
            except (SyntaxError, ValueError):
                continue
            characters.update(value)
    return characters


def subset_font(characters: set[str]) -> None:
    if not SOURCE_FONT.exists():
        raise FileNotFoundError(f"Full source font is missing: {SOURCE_FONT}")
    options = Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    options.name_legacy = True
    font = TTFont(SOURCE_FONT)
    subsetter = Subsetter(options=options)
    subsetter.populate(unicodes={ord(character) for character in characters})
    subsetter.subset(font)
    with tempfile.NamedTemporaryFile(
        dir=OUTPUT_FONT.parent,
        prefix="BlackHanSans-subset-",
        suffix=".ttf",
        delete=False,
    ) as temporary_file:
        temporary_path = Path(temporary_file.name)
    try:
        font.save(temporary_path)
        temporary_path.replace(OUTPUT_FONT)
    finally:
        temporary_path.unlink(missing_ok=True)


def validate_output(characters: set[str]) -> None:
    output_font = TTFont(OUTPUT_FONT)
    available_codepoints: set[int] = set()
    for table in output_font["cmap"].tables:
        available_codepoints.update(table.cmap)
    source_font = TTFont(SOURCE_FONT)
    source_codepoints: set[int] = set()
    for table in source_font["cmap"].tables:
        source_codepoints.update(table.cmap)
    expected_codepoints = {
        ord(character)
        for character in characters
        if (character == " " or not character.isspace())
        and ord(character) in source_codepoints
    }
    missing = sorted(expected_codepoints - available_codepoints)
    if missing:
        formatted = ", ".join(f"U+{codepoint:04X}" for codepoint in missing)
        raise RuntimeError(f"Subset is missing runtime characters: {formatted}")


def main() -> None:
    characters = project_characters()
    subset_font(characters)
    validate_output(characters)
    korean_count = sum(0xAC00 <= ord(character) <= 0xD7A3 for character in characters)
    print(
        f"Subset complete: {len(characters)} characters "
        f"({korean_count} Hangul), {OUTPUT_FONT.stat().st_size} bytes"
    )


if __name__ == "__main__":
    main()
