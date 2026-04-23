// Generate a PSD for a WILD back/detail/front view that matches the reference
// SIDE PSD's layer topology (WILD_SIDE_<...>.psd + WILD_<...>.layers.md).
//
// Usage: node make_wild_view_psd.mjs <view-dir>
//   <view-dir> basename must end in _back, _detail, or _front (case-insensitive).
//   View tag is derived from that suffix and used to resolve paint_masks_aov files.
//
// Output: <view-dir>.psd (sibling of <view-dir>), canvas 4100x2310.
//
// Produced top-level children in order:
//   Color Fill 1            (1x1 placeholder)
//   C1, C2                  86 layers each: 41 colors x (glossy,matte) + 4 specials
//   C3                      12 layers: titanium + pantone x (glossy,matte)
//   L1                      16 layers: subset of C1 with ' copy' suffix + titanium
//   L2                       5 layers: subset with ' copy 2' + 'Levels?' placeholder
//   L3                       6 layers: titanium subset
//   PaintMasks              15 layers: side_masks_* (+ 2 placeholder 'Layer 1/2')
//   M-TEAM_RS, M-TEAM_RS_mullet, MLTD_RS, MLTD_RS_MULLET,
//   m10, m10_mullet, m20, m20_mullet  (bike config groups)
//
// Frame-color source: one <*_frame_colors_v03> subfolder with files named
//   <stem>_nr_<N>.<glossy|matte>.png. The _nr_<N> infix is stripped from layer
//   names to match SIDE naming (e.g. '01_black_nr_01.glossy' -> '01_black.glossy').
//   Duplicates across C1/C2/L1/L2 reuse the same PNG (via canvas cache).
//
// PaintMasks source: paint_masks_aov/ with filenames of the form
//   paint_masks_aov.<VIEW>_X.png. Prefix is rewritten to 'side_masks_X' so the
//   layer names match the SIDE reference verbatim. Missing files -> placeholder.
//
// Bike-group ordering: the alphabetical order of source PNGs does NOT match
// SIDE's layer order. If a *.layers.md file is found alongside the view dir,
// the bike-group layer order from that file is applied. Source files not
// listed in the md are appended at the end with a warning. Fallback when no
// md is present: alphabetical.
//
// Placeholders (Color Fill 1, Levels?, Layer 1, Layer 2) are 1x1 transparent
// image layers because ag-psd does not emit Photoshop solid-fill / adjustment
// layers. Replace them manually in Photoshop if they need to be real.
//
// The source m10/ folder contains BOTH m10_side_* and m10_mullet_side_* files;
// the BIKE_GROUPS filter regexes split them into two groups. m10_mullet/ does
// not exist as its own folder.

import { writePsdBuffer, initializeCanvas } from 'ag-psd';
import { createCanvas, loadImage } from '@napi-rs/canvas';
import { readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { join, basename, extname, dirname } from 'node:path';

initializeCanvas(createCanvas);

const target = process.argv[2];
if (!target) {
  console.error('Usage: make_wild_view_psd.mjs <view-dir>');
  process.exit(1);
}

const CANVAS_W = 4100;
const CANVAS_H = 2310;

const FRAME_COLORS = [
  '01_black', '3_metalic_white_chic', '6_blue_stone', '09_pure_red',
  '15_metalic_navy_blue', '19_cosmic_carbon_view', '26_sky_blue',
  '28_metallic_cinnamon', '32_metallic_jade_green', '33_metallic_power_pink',
  '34_metallic_cobalt_blue', '35_burning_ashes_carbon_view',
  '36_noctiluca_carbon_view', '37_escape_green_carbon_view', '38_carbon_raw',
  '44_seaweed', '47_metalic_sunset', '48_iris_white', '56_mango',
  '59_lichen_green', '67_galactic_rainbow', '70_cream_white', '71_wild_orange',
  '72_rocket_red', '73_royal_plum', '74_metallic_lemon', '75_mintalized',
  '76_racing_green', '77_beetle_green', '78_tanzanite_evo_carbon_view',
  '79_diamond_carbon_view', '80_spaceship_green', '81_anthracite_glitter',
  '82_metalic_spark_silver', '83_spicy_lime', '85_metalic_golden_sand',
  '86_orange_cloud', '88_cotton_pink', '89_lilac', '92_digital_lavender',
  '93_metalic_mulberry',
];

const FRAME_SPECIALS = [
  ['escape_green_mintalized', 'glossy'],
  ['gama_royal_plum_noctiluca', 'glossy'],
  ['magic_gold_matt', 'matte'],
  ['smoot_silver_matt', 'matte'],
];

function expandC1() {
  const out = [];
  for (const c of FRAME_COLORS) {
    out.push([c, 'glossy']);
    out.push([c, 'matte']);
  }
  for (const s of FRAME_SPECIALS) out.push(s);
  return out;
}

const C3_LIST = [
  ['3K_TITANIUM_GOLD', 'glossy'], ['3K_TITANIUM_GOLD', 'matte'],
  ['3L_TITANIUM_PURPLE', 'glossy'], ['3L_TITANIUM_PURPLE', 'matte'],
  ['3M_METALLIC_RED', 'glossy'], ['3M_METALLIC_RED', 'matte'],
  ['45_TITANIUM', 'glossy'], ['45_TITANIUM', 'matte'],
  ['PANTONE_2281_LIME', 'glossy'], ['PANTONE_2281_LIME', 'matte'],
  ['PANTONE_4245_C_MATT', 'matte'], ['PANTONE_4245_C_MATT', 'glossy'],
];

const L1_LIST = [
  ['01_black', 'glossy', ' copy'], ['01_black', 'matte', ' copy'],
  ['81_anthracite_glitter', 'glossy', ' copy'], ['81_anthracite_glitter', 'matte', ' copy'],
  ['3_metalic_white_chic', 'glossy', ' copy'], ['3_metalic_white_chic', 'matte', ' copy'],
  ['83_spicy_lime', 'glossy', ' copy'], ['83_spicy_lime', 'matte', ' copy'],
  ['3K_TITANIUM_GOLD', 'glossy'], ['3K_TITANIUM_GOLD', 'matte'],
  ['3L_TITANIUM_PURPLE', 'glossy'], ['3L_TITANIUM_PURPLE', 'matte'],
  ['3M_METALLIC_RED', 'glossy'], ['3M_METALLIC_RED', 'matte'],
  ['45_TITANIUM', 'glossy'], ['45_TITANIUM', 'matte'],
];

const L2_LIST = [
  ['01_black', 'matte', ' copy 2'],
  ['3_metalic_white_chic', 'matte', ' copy 2'],
  { placeholder: 'Levels?' },
  ['PANTONE_2281_LIME', 'glossy'],
  ['PANTONE_2281_LIME', 'matte'],
];

const L3_LIST = [
  ['3K_TITANIUM_GOLD', 'glossy'], ['3K_TITANIUM_GOLD', 'matte'],
  ['3L_TITANIUM_PURPLE', 'glossy'], ['3L_TITANIUM_PURPLE', 'matte'],
  ['45_TITANIUM', 'glossy'], ['45_TITANIUM', 'matte'],
];

const PAINT_MASKS_ORDER = [
  { src: 'WILD_TOP', layer: 'side_masks_WILD_TOP' },
  { src: 'WILD_TOP_SMALL', layer: 'side_masks_WILD_TOP_SMALL' },
  { placeholder: 'Layer 1' },
  { src: 'SEAT_POST_PATTERN_smooth_silver1', layer: 'side_masks_SEAT_POST_PATTERN_smooth_silver1' },
  { src: 'SEAT_POST_PATTERN_smooth_silver', layer: 'side_masks_SEAT_POST_PATTERN_smooth_silver' },
  { src: 'SEAT_POST_PATTERN_royal_plum', layer: 'side_masks_SEAT_POST_PATTERN_royal_plum' },
  { src: 'SEAT_POST_PATTERN_magic_gold', layer: 'side_masks_SEAT_POST_PATTERN_magic_gold' },
  { src: 'SEAT_POST_MASK', layer: 'side_masks_SEAT_POST_MASK' },
  { src: 'ORBEA_LOGO', layer: 'side_masks_ORBEA_LOGO' },
  { src: 'FRAME_PATTERN', layer: 'side_masks_FRAME_PATTERN' },
  { src: 'ESCAPE_GREEN_PATTERN', layer: 'side_masks_ESCAPE_GREEN_PATTERN' },
  { src: 'STEEP_N_DEEP', layer: 'side_masks_STEEP_N_DEEP' },
  { src: 'STEEP_N_DEEP_ARROWS', layer: 'side_masks_STEEP_N_DEEP_ARROWS' },
  { src: 'ATTITUDE_ADJUST', layer: 'side_masks_ATTITUDE_ADJUST' },
  { placeholder: 'Layer 2' },
];

const BIKE_GROUPS = [
  { name: 'M-TEAM_RS', folder: 'M-TEAM_RS' },
  { name: 'M-TEAM_RS_mullet', folder: 'M-TEAM_RS_mullet' },
  { name: 'MLTD_RS', folder: 'MLTD_RS' },
  { name: 'MLTD_RS_MULLET', folder: 'MLTD_RS_MULLET' },
  { name: 'm10', folder: 'm10', filter: /^m10_+side_/i },
  { name: 'm10_mullet', folder: 'm10', filter: /^m10_mullet_side_/i },
  { name: 'm20', folder: 'm20' },
  { name: 'm20_mullet', folder: 'm20_mullet' },
];

const isPng = (f) => extname(f).toLowerCase() === '.png';

function listPngs(dir) {
  try {
    return readdirSync(dir)
      .filter((f) => isPng(f) && statSync(join(dir, f)).isFile())
      .sort();
  } catch { return []; }
}

function findSubdir(root, pattern) {
  return readdirSync(root)
    .filter((f) => statSync(join(root, f)).isDirectory())
    .find((f) => pattern.test(f));
}

const viewMatch = basename(target).match(/_(back|detail|front)$/i);
if (!viewMatch) {
  console.error(`Cannot determine view from folder name: ${basename(target)}`);
  process.exit(1);
}
const VIEW = viewMatch[1].toUpperCase();

const frameColorsName = findSubdir(target, /_frame_colors_v03$/i);
if (!frameColorsName) {
  console.error(`No *_frame_colors_v03 folder in ${target}`);
  process.exit(1);
}
const frameColorsPath = join(target, frameColorsName);
const paintMasksPath = join(target, 'paint_masks_aov');

const canvasCache = new Map();
async function loadToCanvas(path) {
  if (canvasCache.has(path)) return canvasCache.get(path);
  const img = await loadImage(path);
  const c = createCanvas(img.width, img.height);
  c.getContext('2d').drawImage(img, 0, 0);
  const entry = { canvas: c, width: img.width, height: img.height };
  canvasCache.set(path, entry);
  return entry;
}

function centeredBox(w, h) {
  const left = Math.floor((CANVAS_W - w) / 2);
  const top = Math.floor((CANVAS_H - h) / 2);
  return { left, top, right: left + w, bottom: top + h };
}

async function imgLayer(path, name) {
  const { canvas, width, height } = await loadToCanvas(path);
  return { name, ...centeredBox(width, height), canvas };
}

function placeholderLayer(name) {
  const c = createCanvas(1, 1);
  return { name, left: 0, top: 0, right: 1, bottom: 1, canvas: c };
}

function escapeRe(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function resolveFrameColor(stem, variant) {
  const files = listPngs(frameColorsPath);
  const rx = new RegExp(`^${escapeRe(stem)}_nr_\\d+\\.${variant}\\.png$`);
  const match = files.find((f) => rx.test(f));
  if (!match) throw new Error(`frame_colors: no file matches ${stem}.${variant}`);
  return join(frameColorsPath, match);
}

async function frameColorLayer(stem, variant, suffix = '') {
  const path = resolveFrameColor(stem, variant);
  return imgLayer(path, `${stem}.${variant}${suffix}`);
}

async function buildFrameGroup(name, list) {
  const children = [];
  for (const entry of list) {
    if (entry && entry.placeholder) {
      children.push(placeholderLayer(entry.placeholder));
      continue;
    }
    const [stem, variant, suffix = ''] = entry;
    children.push(await frameColorLayer(stem, variant, suffix));
  }
  console.log(`group: ${name} (${children.length} layers)`);
  return { name, opened: false, children };
}

async function buildPaintMasks() {
  const children = [];
  for (const entry of PAINT_MASKS_ORDER) {
    if (entry.placeholder) {
      children.push(placeholderLayer(entry.placeholder));
      continue;
    }
    const file = join(paintMasksPath, `paint_masks_aov.${VIEW}_${entry.src}.png`);
    try {
      statSync(file);
      children.push(await imgLayer(file, entry.layer));
    } catch {
      console.warn(`paint_masks: missing ${file}, placeholder substituted`);
      children.push(placeholderLayer(entry.layer));
    }
  }
  console.log(`group: PaintMasks (${children.length} layers)`);
  return { name: 'PaintMasks', opened: false, children };
}

function parseLayersMd(path) {
  const groups = new Map();
  let current = null;
  for (const raw of readFileSync(path, 'utf8').split('\n')) {
    const grpMatch = raw.match(/^- \*\*(.+)\*\*\/$/);
    if (grpMatch) {
      current = grpMatch[1];
      groups.set(current, []);
      continue;
    }
    const layerMatch = raw.match(/^  - (.+)$/);
    if (layerMatch && current) groups.get(current).push(layerMatch[1]);
  }
  return groups;
}

function findLayersMd(dir) {
  try {
    const f = readdirSync(dir).find((n) => n.toLowerCase().endsWith('.layers.md'));
    return f ? join(dir, f) : null;
  } catch { return null; }
}

const layersMdPath = findLayersMd(dirname(target));
const layersMdGroups = layersMdPath ? parseLayersMd(layersMdPath) : new Map();
if (layersMdPath) console.log(`order source: ${layersMdPath}`);

async function buildBikeGroup(grp) {
  const dir = join(target, grp.folder);
  let files = listPngs(dir);
  if (!files.length) {
    console.warn(`bike group ${grp.name}: folder ${dir} missing or empty`);
    return { name: grp.name, opened: false, children: [] };
  }
  if (grp.filter) files = files.filter((f) => grp.filter.test(f));
  const expected = layersMdGroups.get(grp.name);
  if (expected && expected.length) {
    const byName = new Map(files.map((f) => [basename(f, '.png'), f]));
    const ordered = [];
    for (const name of expected) {
      if (byName.has(name)) { ordered.push(byName.get(name)); byName.delete(name); }
      else console.warn(`${grp.name}: layer ${name} not found in source`);
    }
    for (const remaining of byName.values()) {
      console.warn(`${grp.name}: extra source file ${basename(remaining)} appended`);
      ordered.push(remaining);
    }
    files = ordered;
  }
  const children = [];
  for (const f of files) {
    children.push(await imgLayer(join(dir, f), basename(f, '.png')));
  }
  console.log(`group: ${grp.name} (${children.length} layers)`);
  return { name: grp.name, opened: false, children };
}

const children = [];
children.push(placeholderLayer('Color Fill 1'));
children.push(await buildFrameGroup('C1', expandC1()));
children.push(await buildFrameGroup('C2', expandC1()));
children.push(await buildFrameGroup('C3', C3_LIST));
children.push(await buildFrameGroup('L1', L1_LIST));
children.push(await buildFrameGroup('L2', L2_LIST));
children.push(await buildFrameGroup('L3', L3_LIST));
children.push(await buildPaintMasks());
for (const grp of BIKE_GROUPS) children.push(await buildBikeGroup(grp));

const psd = { width: CANVAS_W, height: CANVAS_H, children };
const buf = writePsdBuffer(psd);
const outPath = join(dirname(target), `${basename(target)}.psd`);
writeFileSync(outPath, buf);
console.log(`wrote: ${outPath} (${(buf.length / 1024 / 1024).toFixed(2)} MB)`);
