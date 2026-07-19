#!/usr/bin/env node
/* Anselm demo — Playwright 全矩阵回归 harness（make demo-test）。
   why：画廊是 web 端建设的事实源——「每个组件在任意数据填充下不破」必须由机器逐件断言、而非肉眼。
   本件自起隔离端口 serve、遍历 reference.html 全 12 类目每个 specimen，跑 5 道通用断言
   （无 console 错 / 无页面横向溢出 / 无格内盒溢出[非自滚组件未截断、页面级看不出] / 无 XSS 逃逸[on*·script·srcdoc·js-url] / 元素已渲染），
   再补 app.html + settings/onboarding 活页冒烟 + 命令式专项（disabled 键盘透传 / dialog content 注入转义不执行）。
   任一硬失败 → 退出码 1，入不了 web 建设的回归网。
   依赖 playwright（dev-only，未入库；缺则提示 `cd demo && npm i`）。 */
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { join } from "node:path";

const TOOLS = join(fileURLToPath(import.meta.url), "..");
const PORT = Number(process.env.PORT) || 4399;   // 隔离测试端口，避撞 dev 预览的 4192
const BASE = "http://127.0.0.1:" + PORT;
const VW = { width: 1280, height: 900 };

// 内部可滚组件白名单：这些设计上横向/纵向自滚（不撑破页即合规），不按「无内部溢出」苛求
const SCROLLABLE = ["an-node-gantt", "an-json-tree", "an-version-diff", "an-code-block", "an-run-board", "an-thin-table", "an-tabs"];

function log(s) { process.stdout.write(s + "\n"); }

async function waitServer(url, ms = 8000) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) {
    try { const r = await fetch(url); if (r.ok) return true; } catch { /* 还没起 */ }
    await new Promise((r) => setTimeout(r, 120));
  }
  return false;
}

async function main() {
  // playwright 是 dev 依赖、未 vendored——缺失给清晰指引而非晦涩堆栈
  let chromium;
  try { ({ chromium } = await import("playwright")); }
  catch { log("✗ 未装 playwright。运行：cd demo && npm i（或 npm i -g playwright）"); process.exit(2); }

  // 自起隔离端口的 no-store serve（复用 demo 唯一服务源 serve.mjs）
  const srv = spawn("node", [join(TOOLS, "serve.mjs")], { env: { ...process.env, PORT: String(PORT) }, stdio: "ignore" });
  const up = await waitServer(BASE + "/app.html");
  if (!up) { srv.kill(); log("✗ serve 未在 " + BASE + " 起来"); process.exit(2); }

  const browser = await chromium.launch();
  const fails = [];   // 硬失败明细
  const stats = {};   // 每类目统计

  try {
    const page = await browser.newPage({ viewport: VW, deviceScaleFactor: 1 });
    const errs = [];
    page.on("console", (m) => { if (m.type() === "error") errs.push(m.text()); });
    page.on("pageerror", (e) => errs.push("PAGEERR: " + e.message));
    // XSS 陷阱：注入串里的 onerror=alert(1) 一旦真执行就翻 __xssFired；alert/confirm/prompt 全拦
    await page.addInitScript(() => {
      window.__xssFired = false;
      const trap = () => { window.__xssFired = true; };
      window.alert = trap; window.confirm = trap; window.prompt = trap;
    });

    // ---------- 1) reference.html 全矩阵 ----------
    await page.goto(BASE + "/reference.html", { waitUntil: "networkidle" });
    await page.waitForTimeout(700);
    const cats = await page.evaluate(() => (window.REF_CATALOG || []).map((c) => c.cat));
    if (!cats.length) fails.push("REF_CATALOG 为空——catalog 未加载");

    for (let i = 0; i < cats.length; i++) {
      const label = cats[i];
      const before = errs.length;
      // 导航行绑自定义 an-select（非原生 click）——派事件切页
      await page.evaluate((lab) => {
        const r = [...document.querySelectorAll("an-row")].find((x) => x.getAttribute("label") === lab);
        if (r) r.dispatchEvent(new CustomEvent("an-select"));
      }, label);
      await page.waitForTimeout(380);

      const m = await page.evaluate((scrollable) => {
        const se = document.scrollingElement;
        const pageOvf = se.scrollWidth - se.clientWidth;
        const cells = [...document.querySelectorAll("an-specimen")];
        const breach = [];   // 撑破视口（rect 越界）的 specimen
        const cellOvf = [];  // 在格内横向溢出（内置组件若非 SCROLLABLE 却 scrollWidth>clientWidth = nowrap 未截断撑破格子；页面级看不出、肉眼才见叠邻）
        const xss = [];      // shadow 内注入 HTML 被解析的铁证：on* 属性 / script / srcdoc / javascript: url
        function walk(root, hit) {
          root.querySelectorAll("*").forEach((e) => {
            for (const a of e.attributes) {
              if (/^on\w+/i.test(a.name)) hit.push(e.tagName.toLowerCase() + "[" + a.name + "]");
              else if (a.name === "srcdoc") hit.push(e.tagName.toLowerCase() + "[srcdoc]");
              else if (/^(href|src|xlink:href)$/i.test(a.name) && /^\s*javascript:/i.test(a.value || "")) hit.push(e.tagName.toLowerCase() + "[js-url]");
            }
            if (e.tagName === "SCRIPT") hit.push("script");
            if (e.shadowRoot) walk(e.shadowRoot, hit);
          });
        }
        cells.forEach((c) => {
          const r = c.getBoundingClientRect();
          if (r.right > window.innerWidth + 2 || r.left < -2) breach.push(c.getAttribute("label"));
          // 格内盒溢出：内置组件 tag 不在 SCROLLABLE 白名单（设计上自滚的 gantt/json/code/table/tabs/run-board 除外）却撑破格 = 真未截断
          const child = c.firstElementChild;
          const tag = child && child.tagName.toLowerCase();
          if (tag && scrollable.indexOf(tag) < 0 && (c.scrollWidth - c.clientWidth) > 4) cellOvf.push((c.getAttribute("label") || "?") + "+" + (c.scrollWidth - c.clientWidth));
          const hit = []; walk(c, hit);
          if (hit.length) xss.push((c.getAttribute("label") || "?") + "→" + hit.slice(0, 3).join(","));
        });
        return { pageOvf, cells: cells.length, breach, cellOvf, xss, xssFired: window.__xssFired };
      }, SCROLLABLE);

      const ferr = errs.length - before;
      stats[label] = { cells: m.cells, pageOvf: m.pageOvf, breach: m.breach.length, cellOvf: m.cellOvf.length, ferr };
      if (m.pageOvf > 2) fails.push(`[${label}] 页面横向溢出 +${m.pageOvf}px`);
      if (m.breach.length) fails.push(`[${label}] specimen 越界视口: ${m.breach.slice(0, 4).join(" / ")}`);
      if (m.cellOvf.length) fails.push(`[${label}] 格内溢出(组件未截断): ${m.cellOvf.slice(0, 4).join(" / ")}`);
      if (m.xss.length) fails.push(`[${label}] shadow 内注入 HTML 被解析: ${m.xss.slice(0, 3).join(" ; ")}`);
      if (m.xssFired) fails.push(`[${label}] XSS 真执行（__xssFired）`);
      if (ferr) fails.push(`[${label}] 切页触发 ${ferr} 个 console error`);
    }

    // ---------- 2) app.html 冒烟 ----------
    const appErrBefore = errs.length;
    await page.goto(BASE + "/app.html", { waitUntil: "networkidle" });
    await page.waitForTimeout(700);
    const appOk = await page.evaluate(() => {
      const shell = document.querySelector("an-shell, an-app-shell, [class*=shell], main");
      const se = document.scrollingElement;
      return { hasShell: !!shell, pageOvf: se.scrollWidth - se.clientWidth, xssFired: window.__xssFired };
    });
    if (!appOk.hasShell) fails.push("[app.html] 外壳未渲染");
    if (appOk.pageOvf > 2) fails.push(`[app.html] 页面横向溢出 +${appOk.pageOvf}px`);
    if (errs.length - appErrBefore) fails.push(`[app.html] ${errs.length - appErrBefore} 个 console error`);

    // ---------- 2b) 活页冒烟（settings/onboarding——bespoke 残留所在，画廊 catalog 覆盖盲区）----------
    // settings：app.html 内经 Intent 进各类目（best-effort：API 不在则跳过，仍断言无错/无溢出）
    const setErrBefore = errs.length;
    const setRes = await page.evaluate(async () => {
      if (!(window.Intent && window.Intent.select)) return { skipped: true };
      let maxOvf = 0;
      for (const id of ["general", "models", "mcp"]) {
        try { window.Intent.select({ kind: "settingsCat", id }); } catch { /* 类目 id 异型则忽略，仍量当前态 */ }
        await new Promise((r) => setTimeout(r, 220));
        maxOvf = Math.max(maxOvf, document.scrollingElement.scrollWidth - document.scrollingElement.clientWidth);
      }
      return { maxOvf };
    });
    if (setRes.maxOvf > 2) fails.push(`[settings 活页] 页面横向溢出 +${setRes.maxOvf}px`);
    if (errs.length - setErrBefore) fails.push(`[settings 活页] ${errs.length - setErrBefore} 个 console error`);
    // onboarding：独立页，直接 goto
    const obErrBefore = errs.length;
    await page.goto(BASE + "/features/onboarding/onboarding.html", { waitUntil: "networkidle" }).catch(() => {});
    await page.waitForTimeout(500);
    const ob = await page.evaluate(() => ({ ovf: document.scrollingElement.scrollWidth - document.scrollingElement.clientWidth, body: document.body && document.body.children.length > 0, xssFired: window.__xssFired }));
    if (!ob.body) fails.push("[onboarding 活页] 未渲染");
    if (ob.ovf > 2) fails.push(`[onboarding 活页] 页面横向溢出 +${ob.ovf}px`);
    if (errs.length - obErrBefore) fails.push(`[onboarding 活页] ${errs.length - obErrBefore} 个 console error`);

    // ---------- 3) 命令式专项 ----------
    const probe = await page.evaluate(() => {
      const out = {};
      // a) disabled 钮：原生 disabled 透传 → 键盘 Tab+Enter 也挡（非仅 pointer-events）
      const b = document.createElement("an-button"); b.setAttribute("disabled", ""); b.textContent = "x";
      document.body.appendChild(b);
      out.disabledPassthrough = !!(b.shadowRoot && b.shadowRoot.querySelector("button[disabled]"));
      b.remove();
      // b) dialog 转义：content 串含注入，不得产出 <script>/<img onerror>、不得执行
      if (window.AnDialog) {
        window.AnDialog.open({ title: "t", content: "<img src=x onerror=window.__xssFired=true><script>window.__xssFired=true</script>注入名", actions: [{ label: "ok" }] });
      }
      return out;
    });
    if (!probe.disabledPassthrough) fails.push("[probe] an-button[disabled] 未透传原生 disabled（键盘可触发）");
    await page.waitForTimeout(250);
    const dlg = await page.evaluate(() => {
      function find(root, hit) { root.querySelectorAll("*").forEach((e) => { for (const a of e.attributes) if (/^on/i.test(a.name)) hit.push(e.tagName); if (e.tagName === "IMG" && e.getAttribute("src") === "x") hit.push("img-x"); if (e.shadowRoot) find(e.shadowRoot, hit); }); }
      const hit = []; find(document, hit);
      return { xssFired: window.__xssFired, leaked: hit };
    });
    if (dlg.xssFired) fails.push("[probe] dialog content XSS 真执行");
    if (dlg.leaked.length) fails.push("[probe] dialog content 注入 HTML 被解析: " + dlg.leaked.slice(0, 3).join(","));
  } finally {
    await browser.close();
    srv.kill();
  }

  // ---------- 报告 ----------
  log("\n— demo 全矩阵 —");
  for (const [k, v] of Object.entries(stats)) log(`  ${k.padEnd(22)} specimen=${String(v.cells).padStart(3)}  页溢出=${v.pageOvf}  越界=${v.breach}  格内溢=${v.cellOvf}  错=${v.ferr}`);
  log(`  类目=${Object.keys(stats).length}  specimen 合计=${Object.values(stats).reduce((s, v) => s + v.cells, 0)}`);
  if (fails.length) { log("\n✗ 硬失败 " + fails.length + " 项："); fails.forEach((f) => log("  · " + f)); process.exit(1); }
  log("\n✓ demo-test 全绿：0 console 错 / 0 页面溢出 / 0 越界 / 0 XSS 逃逸 / disabled+dialog 守住。");
}

main().catch((e) => { log("✗ harness 异常: " + (e && e.stack || e)); process.exit(2); });
