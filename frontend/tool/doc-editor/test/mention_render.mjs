import { chromium } from 'playwright';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
const here = dirname(fileURLToPath(import.meta.url));
const dist = join(here, '..', 'dist', 'index.html');
const out = process.argv[2];
const mode = process.argv[3] || 'pill';
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 900, height: 700 }, deviceScaleFactor: 2 });
p.on('pageerror', e => console.log('[pageerror]', e.message));
await p.goto('file://' + dist);
await p.waitForFunction(() => window.docEditor);
if (mode === 'pill') {
  await p.evaluate(() => window.docEditor.setMarkdown('相关实体:[[doc_mno345]] 和 [[fn_abc123]],还有 [[ag_ghi789]]。\n'));
  await p.waitForTimeout(500);
  const pills = await p.evaluate(() => Array.from(document.querySelectorAll('.an-mention')).map(e => ({kind:e.dataset.kind, text:e.innerText})));
  console.log('pills:', JSON.stringify(pills));
} else {
  await p.evaluate(() => window.docEditor.setMarkdown('输入 @ 试试:\n'));
  await p.waitForTimeout(300);
  await p.click('.ProseMirror');
  await p.keyboard.press('End');
  await p.keyboard.type(' @');
  await p.waitForTimeout(400);
  const menu = await p.evaluate(() => { const m = document.querySelector('.an-mention-menu'); return m ? m.innerText : '(no menu)'; });
  console.log('picker:', JSON.stringify(menu));
}
if (out) { await p.screenshot({ path: out }); console.log('shot →', out); }
await b.close();
