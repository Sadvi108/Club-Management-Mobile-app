// Regenerates the D-CLIX launcher, splash and notification icons.
//
//   node scripts/generate-icons.js [master.png] [outDir]
//   defaults: assets/branding/dclix-logo.png -> assets/images
//
// Run this after replacing assets/branding/dclix-logo.png (ideally with a >=1024px
// master — the current one is 436px, so the 1024px launcher icon is upscaled).
//
// Sizing rules that matter:
//  icon.png             iOS + generic. Must be OPAQUE — the App Store rejects an alpha
//                       channel — so the badge is flattened onto the brand black. An
//                       inscribed circle sits entirely inside iOS's squircle mask, so
//                       the badge can run close to the edge without being clipped.
//  adaptive-icon.png    Android foreground layer. The layer is 108dp but only the inner
//                       72dp is guaranteed visible, so the badge is scaled to exactly
//                       72/108 = 66.7% and centred on TRANSPARENT pixels; the black comes
//                       from android.adaptiveIcon.backgroundColor in app.json. At that
//                       size the round badge lines up exactly with a circular mask.
//  splash-image.png     Drawn at expo-splash-screen's imageWidth (200) over #000.
//  favicon.png          Web.
//  notification-icon.png Android status bar. See buildNotificationIcon below.
//
// Every fraction below is of the BADGE, not of the master file: the master carries ~5%
// transparent padding, so scaling the raw file to 66.7% left a visible dead ring inside
// the Android mask. The badge is auto-cropped to its alpha bounds first.
const Jimp = require("jimp-compact");
const { PNG } = require("pngjs");
const path = require("path");
const fs = require("fs");

const SRC = process.argv[2] || "assets/branding/dclix-logo.png";
const OUT_DIR = process.argv[3] || "assets/images";

const BRAND_BLACK = 0x0d0d0dff; // matches the badge interior, so the flatten is invisible
const ALPHA_FLOOR = 8; // ignore the badge's faint outer glow when measuring

// [file, canvas, badge fraction of canvas, background (null = transparent), keepAlpha]
const TARGETS = [
  ["icon.png", 1024, 0.88, BRAND_BLACK, false],
  ["adaptive-icon.png", 1024, 0.667, null, true],
  ["splash-image.png", 1024, 0.96, null, true],
  ["favicon.png", 256, 0.96, null, true],
];

/** Crop to the visible artwork, squared about its centre so the round badge stays round. */
function cropToBadge(img) {
  const { width: w, height: h, data } = img.bitmap;
  let x0 = w, y0 = h, x1 = -1, y1 = -1;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (data[(y * w + x) * 4 + 3] > ALPHA_FLOOR) {
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
      }
    }
  }
  if (x1 < 0) return img; // fully transparent — nothing to crop
  const cx = (x0 + x1 + 1) / 2, cy = (y0 + y1 + 1) / 2;
  const side = Math.min(Math.max(x1 - x0 + 1, y1 - y0 + 1), w, h);
  const sx = Math.max(0, Math.min(w - side, Math.round(cx - side / 2)));
  const sy = Math.max(0, Math.min(h - side, Math.round(cy - side / 2)));
  console.log(`  badge bbox ${x1 - x0 + 1}x${y1 - y0 + 1} -> square crop ${side}px at ${sx},${sy}`);
  return img.crop(sx, sy, side, side);
}

/**
 * Encode a Jimp bitmap to PNG.
 *
 * Alpha is dropped via pngjs, NOT via Jimp's `rgba(false)`: that writes a colorType-2
 * (RGB) header while leaving the 4-bytes-per-pixel RGBA data in place, so every decoder
 * reads the rows at the wrong stride and the image comes out as diagonal green garbage.
 * pngjs is told explicitly that the input has alpha and the output must not.
 */
function write(img, file, keepAlpha) {
  const { width, height, data } = img.bitmap;
  const png = new PNG({ width, height });
  data.copy(png.data);
  const buf = PNG.sync.write(png, {
    width,
    height,
    inputColorType: 6, // RGBA in
    inputHasAlpha: true,
    colorType: keepAlpha ? 6 : 2, // RGBA or RGB out
    deflateLevel: 9,
    filterType: -1, // adaptive
  });
  fs.writeFileSync(file, buf);
  return buf.length;
}

/**
 * Android status-bar icon.
 *
 * Android discards the colours and paints the ALPHA channel white, so this cannot be the
 * badge: the badge's alpha is a filled circle, which renders as a featureless white dot.
 * Extracting the badge's orange ring was tried and reads as a faint specky outline at
 * 24dp. A geometric "D" is the one option that stays legible at 24dp AND identifies the
 * app, so the glyph is drawn here rather than derived from the artwork.
 *
 * Drawn at 8x and downscaled — that is where the antialiasing comes from.
 */
function buildNotificationIcon(size) {
  const SS = 8;
  // Stem + bowl, centred as a unit, spanning 80% of the height. The stroke is heavy
  // because a hairline disappears entirely at 24px.
  const stem = 0.155, a = 0.48, t = 0.16;
  const y0 = 0.1, y1 = 0.9;
  const x0 = 0.5 - (stem + a) / 2;
  const cx = x0 + stem, cy = (y0 + y1) / 2, b = (y1 - y0) / 2;
  const ai = a - t, bi = b - t;

  const inside = (u, v) => {
    const outer =
      v >= y0 && v <= y1 &&
      (u >= x0 && u <= cx ? true : u > cx && ((u - cx) / a) ** 2 + ((v - cy) / b) ** 2 <= 1);
    if (!outer) return false;
    const hole =
      v >= y0 + t && v <= y1 - t &&
      (u >= x0 + stem && u <= cx ? true : u > cx && ((u - cx) / ai) ** 2 + ((v - cy) / bi) ** 2 <= 1);
    return !hole;
  };

  const img = new Jimp(size, size, 0x00000000);
  const N = size * SS;
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      let hits = 0;
      for (let sy = 0; sy < SS; sy++) {
        for (let sx = 0; sx < SS; sx++) {
          if (inside((x * SS + sx + 0.5) / N, (y * SS + sy + 0.5) / N)) hits++;
        }
      }
      const i = (y * size + x) * 4;
      img.bitmap.data[i] = 255;
      img.bitmap.data[i + 1] = 255;
      img.bitmap.data[i + 2] = 255;
      img.bitmap.data[i + 3] = Math.round((255 * hits) / (SS * SS));
    }
  }
  return img;
}

(async () => {
  const master = await Jimp.read(SRC);
  console.log(`source: ${master.bitmap.width}x${master.bitmap.height}`);
  const badge = cropToBadge(master);

  for (const [name, canvas, frac, bg, keepAlpha] of TARGETS) {
    const size = Math.round(canvas * frac);
    const logo = badge.clone().resize(size, size, Jimp.RESIZE_BICUBIC);

    // An opaque background is flattened into the pixels BEFORE the alpha channel is
    // dropped, so the badge's soft shadow stays soft.
    const out = new Jimp(canvas, canvas, bg == null ? 0x00000000 : bg);
    const off = Math.round((canvas - size) / 2);
    out.composite(logo, off, off);

    const file = path.join(OUT_DIR, name);
    const bytes = write(out, file, keepAlpha);
    console.log(
      `  ${name.padEnd(22)} ${canvas}x${canvas}  badge ${size}px (${Math.round(frac * 100)}%)  ${(bytes / 1024).toFixed(1)} KB`
    );
  }

  // 192px source; the expo-notifications plugin rescales to 24/36/48/72/96.
  const notif = buildNotificationIcon(192);
  const notifFile = path.join(OUT_DIR, "notification-icon.png");
  const notifBytes = write(notif, notifFile, true);
  console.log(`  ${"notification-icon.png".padEnd(22)} 192x192   white-on-transparent "D"  ${(notifBytes / 1024).toFixed(1)} KB`);
})().catch((e) => {
  console.error("FAILED:", e);
  process.exit(1);
});
