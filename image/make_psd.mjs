import { writePsdBuffer, initializeCanvas } from 'ag-psd';
import { createCanvas, loadImage } from '@napi-rs/canvas';
import { readdirSync, statSync, writeFileSync } from 'node:fs';
import { join, basename, extname, dirname } from 'node:path';

initializeCanvas(createCanvas);

const target = process.argv[2];
if (!target) {
  console.error('Usage: make_psd.mjs <target-dir>');
  process.exit(1);
}

const isPng = (f) => extname(f).toLowerCase() === '.png';

function listPngs(dir) {
  return readdirSync(dir)
    .filter((f) => isPng(f) && statSync(join(dir, f)).isFile())
    .sort()
    .map((f) => join(dir, f));
}

function listSubdirs(dir) {
  return readdirSync(dir)
    .filter((f) => statSync(join(dir, f)).isDirectory())
    .sort()
    .map((f) => join(dir, f));
}

async function pngToLayer(path, canvasW, canvasH) {
  const img = await loadImage(path);
  const c = createCanvas(img.width, img.height);
  c.getContext('2d').drawImage(img, 0, 0);
  const left = Math.floor((canvasW - img.width) / 2);
  const top = Math.floor((canvasH - img.height) / 2);
  return {
    name: basename(path, extname(path)),
    left,
    top,
    right: left + img.width,
    bottom: top + img.height,
    canvas: c,
  };
}

const rootPngs = listPngs(target);
const subdirs = listSubdirs(target);

const allPngs = [
  ...rootPngs,
  ...subdirs.flatMap((d) => listPngs(d)),
];

if (allPngs.length === 0) {
  console.error(`No PNGs found under: ${target}`);
  process.exit(1);
}

const firstImg = await loadImage(allPngs[0]);
const W = firstImg.width;
const H = firstImg.height;
console.log(`Canvas: ${W}x${H} (from ${basename(allPngs[0])})`);

const children = [];

for (const png of rootPngs) {
  children.push(await pngToLayer(png, W, H));
}

for (const sub of subdirs) {
  const pngs = listPngs(sub);
  if (pngs.length === 0) continue;
  const groupChildren = [];
  for (const png of pngs) {
    groupChildren.push(await pngToLayer(png, W, H));
  }
  console.log(`group: ${basename(sub)} (${groupChildren.length} layers)`);
  children.push({
    name: basename(sub),
    opened: true,
    children: groupChildren,
  });
}

const psd = { width: W, height: H, children };
const buf = writePsdBuffer(psd);

const outPath = join(dirname(target), `${basename(target)}.psd`);
writeFileSync(outPath, buf);
console.log(`wrote: ${outPath} (${(buf.length / 1024 / 1024).toFixed(2)} MB)`);
