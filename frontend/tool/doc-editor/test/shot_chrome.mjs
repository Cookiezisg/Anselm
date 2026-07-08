// Screenshot the restyled Crepe chrome (slash menu / @ picker / code block / selection toolbar) to
// eyeball the design-token alignment. Fonts are OS defaults here (Flutter host injects the bundle).
import { chromium } from 'playwright';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const here = dirname(fileURLToPath(import.meta.url));
const dist = join(here, '..', 'dist', 'index.html');
const outDir = process.argv[2] || here;
const theme = process.argv[3] || 'light';

const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 820, height: 760 }, deviceScaleFactor: 2 });
await p.goto('file://' + dist);
await p.waitForFunction(() => window.docEditor, { timeout: 20000 });
await p.evaluate((t) => document.documentElement.setAttribute('data-theme', t), theme);

async function reset(md) {
  await p.evaluate((m) => window.docEditor.setMarkdown(m), md);
  await p.waitForTimeout(250);
  await p.click('.ProseMirror');
}

// 1) SLASH menu
await reset('产品需求文档正文\n');
await p.keyboard.press('End');
await p.keyboard.press('Enter');
await p.keyboard.type('/');
await p.waitForTimeout(600);
await p.screenshot({ path: join(outDir, `chrome_slash_${theme}.png`) });

// 2) @ mention picker (the trigger regex needs @ after whitespace/start → type a space first)
await reset('给这个功能指派\n');
await p.keyboard.press('End');
await p.keyboard.type(' @');
await p.waitForTimeout(600);
await p.screenshot({ path: join(outDir, `chrome_mention_${theme}.png`) });

// 3) code block (fenced) + inline code + heading rhythm
await reset('## 实现要点\n\n先归一时区,再按季度聚合,行内 `date.quarter` 取季度。\n\n```py\n# 归一到本位时区再聚合\ndef bucket(ts, tz):\n    return ts.astimezone(tz).quarter\n```\n\n> 跨年边界上 Q4 与次年 Q1 不能混桶。\n');
await p.waitForTimeout(400);
await p.screenshot({ path: join(outDir, `chrome_code_${theme}.png`) });

// 4) selection toolbar (bubble)
await reset('选中这段文字会浮出格式工具条,用来加粗或转成其它格式。\n');
await p.click('.ProseMirror');
// select the whole first paragraph
await p.evaluate(() => {
  const el = document.querySelector('.ProseMirror p');
  const r = document.createRange();
  r.selectNodeContents(el);
  const s = window.getSelection();
  s.removeAllRanges();
  s.addRange(r);
  document.dispatchEvent(new Event('selectionchange'));
});
await p.mouse.move(300, 300);
await p.waitForTimeout(700);
await p.screenshot({ path: join(outDir, `chrome_toolbar_${theme}.png`) });

await b.close();
console.log('chrome shots →', outDir);
