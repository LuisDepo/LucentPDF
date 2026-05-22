#!/usr/bin/env python3
"""Genera el branding de LucentPDF (logo SVG, AppIcon set, .icns, PNGs de marca).

Fuente única de verdad del logo. Reejecutar tras cualquier cambio de marca:

    python3 scripts/generate_assets.py

Requiere: cairosvg, Pillow  ->  pip install cairosvg pillow
"""
import io
import json
import os

import cairosvg
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPICON_DIR = os.path.join(
    ROOT, "LucentPDF", "Resources", "Assets.xcassets", "AppIcon.appiconset"
)
BYLOGO_DIR = os.path.join(
    ROOT, "LucentPDF", "Resources", "Assets.xcassets", "ByLogo.imageset"
)
APPLOGO_DIR = os.path.join(
    ROOT, "LucentPDF", "Resources", "Assets.xcassets", "AppLogo.imageset"
)
DOCS_ASSETS = os.path.join(ROOT, "docs", "assets")


def sparkle_path(cx, cy, radius, pull=0.14):
    """Estrella de 4 puntas (destello 'lucent') con lados cóncavos."""
    i = radius * pull
    return (
        f"M {cx},{cy - radius} "
        f"Q {cx + i},{cy - i} {cx + radius},{cy} "
        f"Q {cx + i},{cy + i} {cx},{cy + radius} "
        f"Q {cx - i},{cy + i} {cx - radius},{cy} "
        f"Q {cx - i},{cy - i} {cx},{cy - radius} Z"
    )


def app_icon_svg():
    """Icono de la app: fondo squircle con margen transparente (estilo macOS)."""
    big_sparkle = sparkle_path(706, 312, 104)
    small_sparkle = sparkle_path(386, 690, 40)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#6E63FF"/>
      <stop offset="0.55" stop-color="#4C7BF0"/>
      <stop offset="1" stop-color="#21BDEB"/>
    </linearGradient>
    <linearGradient id="page" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="1" stop-color="#ECEFFF"/>
    </linearGradient>
    <radialGradient id="sheen" cx="0.32" cy="0.26" r="0.85">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.30"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.95"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
    <filter id="pageShadow" x="-40%" y="-40%" width="180%" height="180%">
      <feDropShadow dx="0" dy="22" stdDeviation="30" flood-color="#0A1247" flood-opacity="0.32"/>
    </filter>
  </defs>

  <rect x="96" y="96" width="832" height="832" rx="186" fill="url(#bg)"/>
  <rect x="96" y="96" width="832" height="832" rx="186" fill="url(#sheen)"/>

  <g filter="url(#pageShadow)">
    <path d="M 366,300 H 592 L 688,396 V 718 Q 688,748 658,748 H 366 Q 336,748 336,718 V 330 Q 336,300 366,300 Z" fill="url(#page)"/>
    <path d="M 592,300 L 688,396 L 592,396 Z" fill="#C2C8F2"/>
    <path d="M 592,300 L 688,396 L 592,396 Z" fill="#0A1247" fill-opacity="0.06"/>
  </g>

  <g fill="#AEB4E8">
    <rect x="386" y="468" width="232" height="24" rx="12"/>
    <rect x="386" y="524" width="256" height="24" rx="12"/>
    <rect x="386" y="580" width="190" height="24" rx="12"/>
  </g>

  <circle cx="706" cy="312" r="150" fill="url(#glow)"/>
  <path d="{big_sparkle}" fill="#FFFFFF"/>
  <path d="{small_sparkle}" fill="#FFFFFF" fill-opacity="0.92"/>
</svg>
"""


def wordmark_svg():
    """Logotipo horizontal para documentación / cabeceras."""
    sp = sparkle_path(150, 66, 26)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="760" height="200" viewBox="0 0 760 200">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#6E63FF"/>
      <stop offset="0.55" stop-color="#4C7BF0"/>
      <stop offset="1" stop-color="#21BDEB"/>
    </linearGradient>
  </defs>
  <rect x="20" y="20" width="160" height="160" rx="40" fill="url(#bg)"/>
  <path d="M 66,56 H 116 L 144,84 V 138 Q 144,148 134,148 H 66 Q 56,148 56,138 V 66 Q 56,56 66,56 Z" fill="#FFFFFF"/>
  <path d="M 116,56 L 144,84 L 116,84 Z" fill="#C2C8F2"/>
  <g fill="#AEB4E8">
    <rect x="74" y="100" width="44" height="10" rx="5"/>
    <rect x="74" y="118" width="52" height="10" rx="5"/>
    <rect x="74" y="136" width="34" height="10" rx="5"/>
  </g>
  <path d="{sp}" fill="#FFFFFF"/>
  <text x="214" y="125" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="84" font-weight="700" fill="#1D2147">Lucent<tspan fill="#4C7BF0">PDF</tspan></text>
</svg>
"""


def by_logo_svg():
    """Marca placeholder para 'LucentPDF by ___'. Sustituible por el logo real."""
    sp = sparkle_path(128, 128, 58)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#6E63FF"/>
      <stop offset="1" stop-color="#21BDEB"/>
    </linearGradient>
  </defs>
  <circle cx="128" cy="128" r="120" fill="url(#g)"/>
  <path d="{sp}" fill="#FFFFFF"/>
</svg>
"""


def render_png(svg, size):
    return cairosvg.svg2png(
        bytestring=svg.encode("utf-8"), output_width=size, output_height=size
    )


def main():
    for d in (APPICON_DIR, BYLOGO_DIR, APPLOGO_DIR, DOCS_ASSETS):
        os.makedirs(d, exist_ok=True)

    icon_svg = app_icon_svg()

    # --- SVG fuente ---
    with open(os.path.join(DOCS_ASSETS, "lucentpdf-icon.svg"), "w") as f:
        f.write(icon_svg)
    with open(os.path.join(DOCS_ASSETS, "lucentpdf-wordmark.svg"), "w") as f:
        f.write(wordmark_svg())

    # --- AppIcon set ---
    icon_sizes = [16, 32, 64, 128, 256, 512, 1024]
    for s in icon_sizes:
        with open(os.path.join(APPICON_DIR, f"icon_{s}.png"), "wb") as f:
            f.write(render_png(icon_svg, s))

    contents = {
        "images": [
            {"size": "16x16", "idiom": "mac", "filename": "icon_16.png", "scale": "1x"},
            {"size": "16x16", "idiom": "mac", "filename": "icon_32.png", "scale": "2x"},
            {"size": "32x32", "idiom": "mac", "filename": "icon_32.png", "scale": "1x"},
            {"size": "32x32", "idiom": "mac", "filename": "icon_64.png", "scale": "2x"},
            {"size": "128x128", "idiom": "mac", "filename": "icon_128.png", "scale": "1x"},
            {"size": "128x128", "idiom": "mac", "filename": "icon_256.png", "scale": "2x"},
            {"size": "256x256", "idiom": "mac", "filename": "icon_256.png", "scale": "1x"},
            {"size": "256x256", "idiom": "mac", "filename": "icon_512.png", "scale": "2x"},
            {"size": "512x512", "idiom": "mac", "filename": "icon_512.png", "scale": "1x"},
            {"size": "512x512", "idiom": "mac", "filename": "icon_1024.png", "scale": "2x"},
        ],
        "info": {"version": 1, "author": "lucentpdf-generate-assets"},
    }
    with open(os.path.join(APPICON_DIR, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)

    # --- ByLogo imageset (placeholder sustituible) ---
    by_svg = by_logo_svg()
    for scale, size in (("1x", 96), ("2x", 192), ("3x", 288)):
        with open(os.path.join(BYLOGO_DIR, f"bylogo_{scale}.png"), "wb") as f:
            f.write(render_png(by_svg, size))
    by_contents = {
        "images": [
            {"idiom": "universal", "filename": "bylogo_1x.png", "scale": "1x"},
            {"idiom": "universal", "filename": "bylogo_2x.png", "scale": "2x"},
            {"idiom": "universal", "filename": "bylogo_3x.png", "scale": "3x"},
        ],
        "info": {"version": 1, "author": "lucentpdf-generate-assets"},
        "properties": {"template-rendering-intent": "original"},
    }
    with open(os.path.join(BYLOGO_DIR, "Contents.json"), "w") as f:
        json.dump(by_contents, f, indent=2)

    # --- AppLogo imageset (icono usado dentro de la interfaz) ---
    for scale, size in (("1x", 256), ("2x", 512), ("3x", 768)):
        with open(os.path.join(APPLOGO_DIR, f"applogo_{scale}.png"), "wb") as f:
            f.write(render_png(icon_svg, size))
    applogo_contents = {
        "images": [
            {"idiom": "universal", "filename": "applogo_1x.png", "scale": "1x"},
            {"idiom": "universal", "filename": "applogo_2x.png", "scale": "2x"},
            {"idiom": "universal", "filename": "applogo_3x.png", "scale": "3x"},
        ],
        "info": {"version": 1, "author": "lucentpdf-generate-assets"},
        "properties": {"template-rendering-intent": "original"},
    }
    with open(os.path.join(APPLOGO_DIR, "Contents.json"), "w") as f:
        json.dump(applogo_contents, f, indent=2)

    # --- PNG de marca para docs ---
    with open(os.path.join(DOCS_ASSETS, "lucentpdf-icon-512.png"), "wb") as f:
        f.write(render_png(icon_svg, 512))
    with open(os.path.join(DOCS_ASSETS, "lucentpdf-wordmark.png"), "wb") as f:
        f.write(
            cairosvg.svg2png(
                bytestring=wordmark_svg().encode("utf-8"), output_width=760
            )
        )

    # --- .icns para el icono del volumen DMG ---
    icns_path = os.path.join(DOCS_ASSETS, "LucentPDF.icns")
    master = Image.open(io.BytesIO(render_png(icon_svg, 1024))).convert("RGBA")
    master.save(
        icns_path,
        format="ICNS",
        sizes=[(16, 16), (32, 32), (128, 128), (256, 256), (512, 512), (1024, 1024)],
    )

    print("Branding generado:")
    print(f"  AppIcon set : {APPICON_DIR}")
    print(f"  ByLogo set  : {BYLOGO_DIR}")
    print(f"  Docs assets : {DOCS_ASSETS}")
    print(f"  Volume icon : {icns_path}")


if __name__ == "__main__":
    main()
