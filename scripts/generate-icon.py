#!/usr/bin/env python3
"""Generate the product icon from the same amber sticky-strip design."""
from pathlib import Path
from PIL import Image
import subprocess

root = Path(__file__).resolve().parents[1]
iconset = root / "build" / "LiteStick.iconset"
iconset.mkdir(parents=True, exist_ok=True)
with Image.open(root / "Support" / "LiteStick.png") as source:
    im = source.convert("RGBA")
sizes = {"16x16":16,"16x16@2x":32,"32x32":32,"32x32@2x":64,
         "128x128":128,"128x128@2x":256,"256x256":256,"256x256@2x":512,
         "512x512":512,"512x512@2x":1024}
for name, pixels in sizes.items():
    im.resize((pixels, pixels), Image.Resampling.LANCZOS).save(iconset / f"icon_{name}.png")
subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(root / "Support" / "LiteStick.icns")], check=True)
print(root / "Support" / "LiteStick.icns")
