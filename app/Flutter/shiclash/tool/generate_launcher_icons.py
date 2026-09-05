from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "branding" / "shiclash-launcher-source.png"
BACKGROUND = (5, 4, 5, 255)


def square_icon(size: int, inset: float = 0.08) -> Image.Image:
    source = Image.open(SOURCE).convert("RGBA")
    side = max(1, round(size * (1 - (inset * 2))))
    source.thumbnail((side, side), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), BACKGROUND)
    canvas.alpha_composite(source, ((size - source.width) // 2, (size - source.height) // 2))
    return canvas.convert("RGB")


def android_icons() -> None:
    sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    for directory, size in sizes.items():
        destination = res / directory
        destination.mkdir(parents=True, exist_ok=True)
        square_icon(size).save(destination / "ic_launcher.png", optimize=True)
        square_icon(round(size * 2.25), inset=0.24).save(
            destination / "ic_launcher_foreground.png", optimize=True
        )


def ios_icons() -> None:
    icon_dir = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    contents = json.loads((icon_dir / "Contents.json").read_text(encoding="utf-8"))
    for item in contents["images"]:
        filename = item.get("filename")
        point_size = item.get("size")
        scale = item.get("scale")
        if not filename or not point_size or not scale:
            continue
        width = float(point_size.split("x", 1)[0])
        multiplier = int(scale.rstrip("x"))
        square_icon(round(width * multiplier)).save(icon_dir / filename, optimize=True)


def branding_icons() -> None:
    destination = ROOT / "assets" / "branding"
    square_icon(384).save(destination / "shiclash-mark.png", optimize=True)
    square_icon(120).save(destination / "shiclash-oauth-logo.png", optimize=True)


if __name__ == "__main__":
    android_icons()
    ios_icons()
    branding_icons()
    print(f"Launcher icons generated from {SOURCE}")
