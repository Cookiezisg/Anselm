import { chromium } from 'playwright';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
const here = dirname(fileURLToPath(import.meta.url));
const dist = join(here, '..', 'dist', 'index.html');
const out = process.argv[2];
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1000, height: 700 }, deviceScaleFactor: 2 });
await p.goto('file://' + dist);
await p.waitForFunction(() => window.docEditor);
await p.evaluate(() => window.docEditor.setMarkdown('选中这一段文字来测试划选浮动工具条的样子。\n'));
await p.waitForTimeout(300);
// select a run of text inside the first paragraph
await p.evaluate(() => {
  const pnode = document.querySelector('.ProseMirror p');
  const range = document.createRange();
  range.setStart(pnode.firstChild, 2);
  range.setEnd(pnode.firstChild, 10);
  const sel = window.getSelection(); sel.removeAllRanges(); sel.addRange(range);
  document.querySelector('.ProseMirror').dispatchEvent(new Event('mouseup', {bubbles:true}));
});
await p.waitForTimeout(600);
const tb = await p.evaluate(() => {
  const t = document.querySelector('.milkdown-toolbar') || document.querySelector('[class*="toolbar"]');
  return t ? { text: t.innerText, html: t.className } : null;
});
console.log('toolbar:', JSON.stringify(tb));
if (out) { await p.screenshot({ path: out }); console.log('shot →', out); }
await b.close();
