import { chromium } from 'playwright';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
const here = dirname(fileURLToPath(import.meta.url));
const dist = join(here, '..', 'dist', 'index.html');
const out = process.argv[2];
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1000, height: 900 }, deviceScaleFactor: 2 });
await p.goto('file://' + dist);
await p.waitForFunction(() => window.docEditor);
await p.evaluate(() => window.docEditor.setMarkdown('输入内容测试\n'));
await p.waitForTimeout(300);
await p.click('.ProseMirror');
await p.keyboard.press('End');
await p.keyboard.press('Enter');
await p.keyboard.type('/');
await p.waitForTimeout(500);
const menu = await p.evaluate(() => {
  const m = document.querySelector('.milkdown-slash-menu') || document.querySelector('[class*="slash"]');
  return m ? m.innerText : '(no slash menu found)';
});
console.log('=== slash menu text ===\n' + menu);
if (out) { await p.screenshot({ path: out }); console.log('shot →', out); }
await b.close();
