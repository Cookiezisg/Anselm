import { chromium } from 'playwright';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
const here = dirname(fileURLToPath(import.meta.url));
const dist = join(here, '..', 'dist', 'index.html');
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1000, height: 1100 } });
await p.goto('file://' + dist);
await p.waitForFunction(() => window.docEditor);
await p.waitForTimeout(400);
const info = await p.evaluate(() => {
  const out = [];
  const walk = (el, depth) => {
    if (depth > 6) return;
    const cs = getComputedStyle(el);
    const bg = cs.backgroundColor;
    const bd = cs.border;
    const pad = cs.padding;
    const r = cs.borderRadius;
    const tag = el.tagName.toLowerCase();
    const cls = (el.className && el.className.baseVal !== undefined ? el.className.baseVal : el.className) || '';
    if (bg !== 'rgba(0, 0, 0, 0)' || bd !== '0px none rgb(0, 0, 0)' || r !== '0px')
      out.push(`${'  '.repeat(depth)}${tag}.${String(cls).split(' ').join('.')} | bg=${bg} border=${bd} radius=${r} pad=${pad}`);
    for (const c of el.children) walk(c, depth + 1);
  };
  const cb = document.querySelector('.milkdown-code-block') || document.querySelector('pre');
  if (cb) walk(cb, 0); else out.push('(no code block found)');
  return out.join('\n');
});
await b.close();
console.log(info);
