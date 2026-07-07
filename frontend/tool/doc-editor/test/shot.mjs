// Headless render screenshot of the built editor — sanity-checks the design-token CSS (colors,
// spacing, headings, code block, co-scroll header). Fonts here are the OS defaults (the bundled
// Inter/MiSans/JetBrains Mono are injected at runtime by the Flutter host, absent in this harness).
import { chromium } from 'playwright';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const here = dirname(fileURLToPath(import.meta.url));
const dist = join(here, '..', 'dist', 'index.html');
const out = process.argv[2] || join(here, '..', 'render.png');
const theme = process.argv[3] || 'light';

const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1000, height: 1100}, deviceScaleFactor: 2 });
await p.goto('file://' + dist);
await p.waitForFunction(() => window.docEditor, { timeout: 20000 });
await p.evaluate((t) => document.documentElement.setAttribute('data-theme', t), theme);
await p.evaluate(() => window.docEditor.setMeta({ name: '产品需求文档', description: '一个连贯的 demo 文档,用来验证编辑器的排版节奏。', tags: ['需求', 'v1', '草稿'] }));
await p.waitForTimeout(400);
await p.screenshot({ path: out });
await b.close();
console.log('shot →', out);
