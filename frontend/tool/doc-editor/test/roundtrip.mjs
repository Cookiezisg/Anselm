// Headless round-trip fidelity harness: load the built single-file bundle, push a hard markdown
// sample, read it back, assert per-feature survival. This is the A5/A6 fidelity gate's basis.
// Run: npm run roundtrip  (after `npm run build`). 无头 round-trip 保真:推样本→回读→逐特性存活断言。
import { chromium } from 'playwright';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const here = dirname(fileURLToPath(import.meta.url));
const dist = join(here, '..', 'dist', 'index.html');

const SAMPLE = `# 项目说明

这是 **重点**,还有 *强调* 和 \`内联代码\`。

## 步骤

1. 第一步
2. 第二步
3. 第三步

- 无序 A
  - 嵌套 B

\`\`\`dart
void main() {
  print("你好,世界");
}
\`\`\`

| 列 A | 列 B |
| --- | --- |
| 1 | 2 |

> 引用第一行
> 引用第二行

- [ ] 待办未完成
- [x] 待办已完成

参见 [[doc_abc123]] 与 [[fn_def456]]。`;

const b = await chromium.launch();
const p = await b.newPage();
p.on('console', (m) => {
  if (m.type() === 'error') console.log('  [console.error]', m.text());
});
await p.goto('file://' + dist);
await p.waitForFunction(() => window.docEditor && typeof window.docEditor.getMarkdown === 'function', {
  timeout: 20000,
});
await p.evaluate((md) => window.docEditor.setMarkdown(md), SAMPLE);
await p.waitForTimeout(500);
const out = await p.evaluate(() => window.docEditor.getMarkdown());
await b.close();

console.log('===== ROUND-TRIP OUTPUT =====\n' + out + '\n===== END =====\n');
const has = (s) => out.includes(s);
const checks = [
  ['代码块内容+语言标', has('void main') && has('print("你好,世界")') && has('dart')],
  ['有序列表编号', /\n2\. /.test(out) && /\n3\. /.test(out)],
  ['表格', has('列 A') && has('列 B') && has('|')],
  ['引用两行', has('引用第一行') && has('引用第二行')],
  ['待办 checkbox', has('[ ]') && (has('[x]') || has('[X]'))],
  ['嵌套列表', has('嵌套 B')],
  ['wikilink [[id]] 逐字', has('[[doc_abc123]]') && has('[[fn_def456]]')],
];
let ok = true;
console.log('--- 保真检查 ---');
for (const [name, pass] of checks) {
  console.log((pass ? '✅' : '❌') + ' ' + name);
  ok = ok && pass;
}
process.exit(ok ? 0 : 1);
