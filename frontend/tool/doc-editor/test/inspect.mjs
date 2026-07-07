import { chromium } from 'playwright';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
const here = dirname(fileURLToPath(import.meta.url));
const dist = join(here, '..', 'dist', 'index.html');
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1000, height: 1100 } });
await p.goto('file://' + dist);
await p.waitForFunction(() => window.docEditor);
await p.waitForTimeout(300);
const info = await p.evaluate(() => {
  const rect = (sel) => { const e = document.querySelector(sel); if(!e) return sel+': (none)'; const r = e.getBoundingClientRect(); const cs = getComputedStyle(e); return `${sel}: left=${Math.round(r.left)} width=${Math.round(r.width)} padL=${cs.paddingLeft} maxW=${cs.maxWidth} marL=${cs.marginLeft} cls="${e.className}"`; };
  return [
    rect('#doc-header'), rect('#app'), rect('.milkdown'),
    rect('.ProseMirror'), rect('.ProseMirror > h1'), rect('.ProseMirror > p'),
  ].join('\n');
});
await b.close();
console.log(info);
