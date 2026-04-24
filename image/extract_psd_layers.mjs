import { readPsd } from 'ag-psd';
import { readFileSync, writeFileSync } from 'node:fs';
import { basename, extname, dirname, join } from 'node:path';

const target = process.argv[2];
if (!target) {
  console.error('Usage: extract_psd_layers.mjs <file.psd>');
  process.exit(1);
}

const buf = readFileSync(target);
const psd = readPsd(buf, { skipLayerImageData: true, skipCompositeImageData: true, skipThumbnail: true });

const lines = [];
lines.push(`# ${basename(target)}`);
lines.push('');
lines.push(`Canvas: ${psd.width}x${psd.height}`);
lines.push('');

function walk(nodes, depth) {
  if (!nodes) return;
  for (const n of nodes) {
    const indent = '  '.repeat(depth);
    const isGroup = Array.isArray(n.children);
    const prefix = isGroup ? '- **' : '- ';
    const suffix = isGroup ? '**/' : '';
    lines.push(`${indent}${prefix}${n.name ?? '(unnamed)'}${suffix}`);
    if (isGroup) walk(n.children, depth + 1);
  }
}

walk(psd.children, 0);

const outPath = join(dirname(target), `${basename(target, extname(target))}.layers.md`);
writeFileSync(outPath, lines.join('\n') + '\n');
console.log(`wrote: ${outPath}`);
