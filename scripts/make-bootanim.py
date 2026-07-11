#!/usr/bin/env python3
"""Build an Android bootanimation.zip from an asset.

Usage:
  python make-bootanim.py --asset <logo.png | frames_dir> --out bootanimation.zip
                          [--width 1080] [--height 2340] [--fps 30] [--bg 0,0,0]

- Single image  -> centered/scaled on a solid background; part0 fades in (plays once),
                   part1 holds the logo (loops forever until boot completes).
- Folder of *.png/*.jpg (sorted) -> used directly as part0 frames, looped.

The zip is written with ZIP_STORED (no compression) — REQUIRED by Android's
bootanimation; a Deflated zip renders as a black/blank boot.
"""
import argparse, os, sys, glob, zipfile, io

def load_pillow():
    try:
        from PIL import Image
        return Image
    except ImportError:
        sys.exit("Pillow not installed. Run: python -m pip install pillow")

def auto_bg(img):
    """Average the four corner pixels so letterbox bars blend with the image edges."""
    im = img.convert("RGB")
    w, h = im.size
    pts = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    px = [im.getpixel(p) for p in pts]
    return tuple(sum(c[i] for c in px) // len(px) for i in range(3))

def fit_on_canvas(Image, img, W, H, bg, margin):
    img = img.convert("RGBA")
    if bg is None:
        bg = auto_bg(img)
    canvas = Image.new("RGBA", (W, H), bg + (255,))
    # contain: scale to fit within the screen, preserve aspect (fills the limiting dimension)
    r = min(W / img.width, H / img.height) * margin
    new = img.resize((max(1, int(img.width * r)), max(1, int(img.height * r))), Image.LANCZOS)
    canvas.alpha_composite(new, ((W - new.width) // 2, (H - new.height) // 2))
    return canvas.convert("RGB")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--asset", required=True)
    ap.add_argument("--out", default="bootanimation.zip")
    ap.add_argument("--width", type=int, default=1080)
    ap.add_argument("--height", type=int, default=2340)
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--bg", default="auto", help="background 'auto' (match image edges) or R,G,B")
    ap.add_argument("--margin", type=float, default=1.0, help="scale factor of contain-fit (1.0 = fill)")
    ap.add_argument("--fade-frames", type=int, default=18)
    ap.add_argument("--hold-frames", type=int, default=8)
    a = ap.parse_args()
    Image = load_pillow()
    W, H = a.width, a.height
    bg = None if a.bg.strip().lower() == "auto" else tuple(int(x) for x in a.bg.split(","))

    parts = {}  # name -> list of (filename, PIL.Image)
    desc_parts = []  # (count, pause, name)

    if os.path.isdir(a.asset):
        files = sorted(glob.glob(os.path.join(a.asset, "*.png")) +
                       glob.glob(os.path.join(a.asset, "*.jpg")))
        if not files:
            sys.exit(f"No .png/.jpg frames in {a.asset}")
        frames = [fit_on_canvas(Image, Image.open(f), W, H, bg, a.margin) for f in files]
        parts["part0"] = [(f"{i+1:04d}.png", im) for i, im in enumerate(frames)]
        desc_parts.append((0, 0, "part0"))  # loop forever
    else:
        src = Image.open(a.asset)
        bg_color = bg if bg is not None else auto_bg(src)
        logo = fit_on_canvas(Image, src, W, H, bg_color, a.margin)
        black = Image.new("RGB", (W, H), bg_color)
        fade = []
        for i in range(a.fade_frames):
            alpha = (i + 1) / a.fade_frames
            fade.append(Image.blend(black, logo, alpha))
        parts["part0"] = [(f"{i+1:04d}.png", im) for i, im in enumerate(fade)]
        parts["part1"] = [(f"{i+1:04d}.png", logo) for i in range(a.hold_frames)]
        desc_parts.append((1, 0, "part0"))  # play fade-in once
        desc_parts.append((0, 0, "part1"))  # then hold/loop forever

    desc = f"{W} {H} {a.fps}\n" + "".join(f"p {c} {p} {n}\n" for c, p, n in desc_parts)

    with zipfile.ZipFile(a.out, "w", zipfile.ZIP_STORED) as z:
        z.writestr("desc.txt", desc)
        for name, frames in parts.items():
            for fn, im in frames:
                buf = io.BytesIO()
                im.save(buf, format="PNG")
                z.writestr(f"{name}/{fn}", buf.getvalue())

    total = sum(len(v) for v in parts.values())
    print(f"Wrote {a.out}: {W}x{H} @ {a.fps}fps, {len(parts)} part(s), {total} frames (STORED)")
    print("desc.txt:\n" + desc)

if __name__ == "__main__":
    main()
