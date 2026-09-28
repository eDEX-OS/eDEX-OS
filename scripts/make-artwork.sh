#!/usr/bin/env bash
# Render every raster/font asset from the SVG sources in branding/src into branding/generated
# (git-ignored). Needs rsvg-convert (librsvg), magick (imagemagick) and grub-mkfont (grub).
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SRC="$ROOT/branding/src"
OUT="${1:-$ROOT/branding/generated}"
for tool in rsvg-convert magick grub-mkfont; do
    command -v "$tool" >/dev/null || { echo "missing $tool" >&2; exit 1; }
done
FONT=$(fc-match -f '%{file}' 'DejaVu Sans Mono' 2>/dev/null || true)
[ -f "$FONT" ] || FONT=$(ls /usr/share/fonts/TTF/DejaVuSansMono.ttf /usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf 2>/dev/null | head -1)
[ -f "$FONT" ] || { echo "DejaVu Sans Mono font not found" >&2; exit 1; }
UNIFONT=$(ls /usr/share/fonts/misc/unifont.pcf.gz /usr/share/fonts/unifont/unifont.pcf.gz 2>/dev/null | head -1 || true)

mkdir -p "$OUT"/{plymouth,grub/icons,calamares,wallpapers,icons,syslinux,greeter}
svg() { rsvg-convert -w "$2" -h "$3" "$SRC/$1" -o "$4"; }

# Plymouth: logo, progress bar pieces
svg logo.svg 200 200 "$OUT/plymouth/logo.png"
magick -size 400x6 xc:'#00d4ff' "$OUT/plymouth/bar.png"
magick -size 400x6 xc:'#0d2430' "$OUT/plymouth/bar_bg.png"
magick -size 12x12 xc:none -fill '#00d4ff' -draw 'circle 6,6 6,1' "$OUT/plymouth/dot.png"

# GRUB: background, icon, fonts
svg hexgrid.svg 1920 1080 "$OUT/grub/background.png"
svg icon.svg 32 32 "$OUT/grub/icons/edex-os.png"
cp "$OUT/grub/icons/edex-os.png" "$OUT/grub/icons/edex.png"
for s in 14 18 24; do
    grub-mkfont -s "$s" -o "$OUT/grub/dejavu_sans_mono_$s.pf2" "$FONT" >/dev/null
done
if [ -n "$UNIFONT" ]; then
    grub-mkfont -o "$OUT/grub/unicode.pf2" "$UNIFONT" >/dev/null
else
    grub-mkfont -s 16 -o "$OUT/grub/unicode.pf2" "$FONT" >/dev/null
fi

# Calamares branding images
svg logo.svg 128 128 "$OUT/calamares/logo.png"
svg icon.svg 64 64 "$OUT/calamares/icon.png"
svg logo.svg 256 256 "$OUT/calamares/welcome.png"
svg hexgrid.svg 1280 720 "$OUT/calamares/slide-bg.png"

# Wallpapers, greeter/lock background, icons, syslinux splash
svg hexgrid.svg 1920 1080 "$OUT/wallpapers/edex-hexgrid-1080p.png"
svg hexgrid.svg 2560 1440 "$OUT/wallpapers/edex-hexgrid-1440p.png"
svg hexgrid.svg 3840 2160 "$OUT/wallpapers/edex-hexgrid-4k.png"
cp "$OUT/wallpapers/edex-hexgrid-1080p.png" "$OUT/greeter/background.png"
for s in 64 128 256; do svg icon.svg "$s" "$s" "$OUT/icons/edex-os-$s.png"; done
svg hexgrid.svg 640 480 "$OUT/syslinux/splash.png"
echo "artwork written to $OUT"
