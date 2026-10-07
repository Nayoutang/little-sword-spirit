"""Assemble an unmodified engine-animation capture into a lightweight preview."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
paths = sorted((root / ".godot/brilliance-frames").glob("[0-9][0-9].png"))
if len(paths) != 21:
    raise SystemExit(f"Expected 21 captured frames, found {len(paths)}")
frames = []
for path in paths:
    frame = Image.open(path).convert("RGB")
    frame.thumbnail((960, 600), Image.Resampling.LANCZOS)
    frames.append(frame)
out = root / "art/previews/brilliance-animation-v1.gif"
frames[0].save(out, save_all=True, append_images=frames[1:],
               duration=[80] * 20 + [500], loop=0, disposal=2, optimize=False)
print(f"BRILLIANCE_GIF frames={len(frames)} bytes={out.stat().st_size}")
