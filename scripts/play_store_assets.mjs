// Generates the Play Store listing graphics (icon, feature graphic) and
// frames raw phone screenshots into 1080x1920 (9:16) store images.
//
// The output images are NOT committed — they're reproducible from this
// script, and the screenshots may show real account data. Keep the finals
// in the company Google Drive. See docs/PLAY_CONSOLE.md → "Store listing".
//
// Usage (from scripts/):
//   node play_store_assets.mjs graphics <outDir>
//   node play_store_assets.mjs screenshots <outDir> <captions.json>
//
// captions.json: [{"file": "/path/shot.jpg", "line1": "...", "line2": "..."}]
// Screenshots are expected at 1080x2340 (Galaxy S23); the status bar and
// gesture bar are cropped off before framing.

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const LOGO = join(ROOT, 'assets/icon/logo_1024.png');
const FONTS = join(ROOT, 'assets/fonts');

// Brand colors, from lib/theme/colors.dart (dark theme).
const BG = '#16130F'; // darkBackground
const GLOW = '#1F4732'; // darkPrimaryContainer
const PRIMARY = '#7FCB9E'; // darkPrimary
const INK = '#F5F1EA'; // darkInkPrimary
const INK2 = '#C9C2B4'; // darkInkSecondary

// librsvg (used by sharp for SVG text) resolves fonts through fontconfig,
// so point it at the app's bundled Fraunces/Work Sans before sharp loads.
const fcDir = join(tmpdir(), 'dindin-play-fonts');
mkdirSync(fcDir, { recursive: true });
writeFileSync(join(fcDir, 'fonts.conf'), `<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig><dir>${FONTS}</dir><include ignore_missing="yes">/etc/fonts/fonts.conf</include><cachedir>${fcDir}/cache</cachedir></fontconfig>`);
process.env.FONTCONFIG_FILE = join(fcDir, 'fonts.conf');
const { default: sharp } = await import('sharp');

const glow = (cx, cy, r) => `<defs><radialGradient id="g" cx="${cx}" cy="${cy}" r="${r}">
  <stop offset="0" stop-color="${GLOW}" stop-opacity="0.9"/><stop offset="1" stop-color="${BG}" stop-opacity="0"/></radialGradient></defs>`;

async function graphics(out) {
  const logo = await sharp(LOGO).trim().toBuffer();
  const fit = (size) => sharp(logo).resize(size, size, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } }).toBuffer();

  // Icon 512x512: full-bleed dark square (Play applies its own mask).
  await sharp({ create: { width: 512, height: 512, channels: 4, background: BG } })
    .composite([{ input: await fit(360), gravity: 'center' }])
    .removeAlpha().png().toFile(join(out, 'icone-512.png'));

  // Feature graphic 1024x500 (Play rejects alpha here).
  const svg = `<svg width="1024" height="500" xmlns="http://www.w3.org/2000/svg">${glow(0.22, 0.5, 0.6)}
    <rect width="1024" height="500" fill="${BG}"/><rect width="1024" height="500" fill="url(#g)"/>
    <text x="440" y="235" font-family="Fraunces 72pt" font-weight="600" font-size="104" fill="${INK}">Dindin</text>
    <text x="444" y="298" font-family="Work Sans" font-weight="500" font-size="34" fill="${PRIMARY}">Controle financeiro por caixinhas</text>
    <text x="444" y="345" font-family="Work Sans" font-size="24" fill="${INK2}">por Café Labs</text></svg>`;
  await sharp(Buffer.from(svg))
    .composite([{ input: await fit(300), left: 100, top: 100 }])
    .removeAlpha().png().toFile(join(out, 'grafico-destaque-1024x500.png'));
}

async function screenshots(out, captionsPath) {
  const items = JSON.parse(readFileSync(captionsPath, 'utf8'));
  const W = 1080, H = 1920, CROP_TOP = 120, CROP_BOTTOM = 100, SHOT_H = 1500, R = 36;
  let i = 1;
  for (const { file, line1, line2 } of items) {
    const { width, height } = await sharp(file).metadata();
    const shot = await sharp(file)
      .extract({ left: 0, top: CROP_TOP, width, height: height - CROP_TOP - CROP_BOTTOM })
      .resize({ height: SHOT_H }).toBuffer({ resolveWithObject: true });
    const sw = shot.info.width;
    const mask = Buffer.from(`<svg width="${sw}" height="${SHOT_H}"><rect width="${sw}" height="${SHOT_H}" rx="${R}" fill="#fff"/></svg>`);
    const rounded = await sharp(shot.data).composite([{ input: mask, blend: 'dest-in' }]).png().toBuffer();
    const left = Math.round((W - sw) / 2), top = H - SHOT_H - 90;
    const bg = `<svg width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg">${glow(0.5, 0.1, 0.8)}
      <rect width="${W}" height="${H}" fill="${BG}"/><rect width="${W}" height="${H}" fill="url(#g)"/>
      <text x="540" y="155" text-anchor="middle" font-family="Fraunces 72pt" font-weight="600" font-size="72" fill="${INK}">${line1}</text>
      <text x="540" y="245" text-anchor="middle" font-family="Fraunces 72pt" font-weight="600" font-size="72" fill="${PRIMARY}">${line2}</text>
      <rect x="${left - 3}" y="${top - 3}" width="${sw + 6}" height="${SHOT_H + 6}" rx="${R + 3}" fill="#3A332A"/></svg>`;
    await sharp(Buffer.from(bg)).composite([{ input: rounded, left, top }])
      .removeAlpha().png().toFile(join(out, `${String(i++).padStart(2, '0')}.png`));
  }
}

const [cmd, out, captions] = process.argv.slice(2);
if (!out || (cmd === 'screenshots' && !captions) || !['graphics', 'screenshots'].includes(cmd)) {
  console.error('usage: node play_store_assets.mjs graphics <outDir>\n       node play_store_assets.mjs screenshots <outDir> <captions.json>');
  process.exit(1);
}
mkdirSync(out, { recursive: true });
await (cmd === 'graphics' ? graphics(out) : screenshots(out, captions));
console.log(`written to ${out}`);
