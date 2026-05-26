// i18n 走查:seed 一个已有用户,分别在 zh / en 下截图 AppShell + 设置弹窗,
// 双向找残留(en 模式看中文漏迁,zh 模式看英文硬编码漏迁)。
// Run: make dev 在跑,然后 node tests/manual/probe-i18n.mjs。截图 → /tmp/forgify-i18n/。

import { chromium } from "playwright";
import { mkdirSync } from "fs";

const DIR = "/tmp/forgify-i18n";
mkdirSync(DIR, { recursive: true });
const FE = process.env.FRONTEND_URL || "http://localhost:5173";

const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 1300, height: 880 }, deviceScaleFactor: 2, locale: "zh-CN" });
const page = await ctx.newPage();
const errs = [];
page.on("pageerror", (e) => errs.push("PAGEERR: " + e.message));
page.on("console", (m) => { if (m.type() === "error") errs.push("CONSOLE: " + m.text()); });

async function seed(lang) {
  await page.goto(`${FE}/`, { waitUntil: "domcontentloaded", timeout: 15000 });
  await page.evaluate(async (lang) => {
    const r = await fetch("/api/v1/users");
    const j = await r.json();
    const u = j.data?.items || j.data || [];
    const id = u[0]?.id || null;
    localStorage.setItem("forgify-settings", JSON.stringify({
      state: { onboarded: true, activeUserId: id, theme: "system", accent: "claude", density: "cozy", lang, reasoningDefault: "collapsed", leftPct: 50 },
      version: 1,
    }));
    return id;
  }, lang);
  await page.reload({ waitUntil: "domcontentloaded" });
  await page.waitForTimeout(1800);
}

try {
  await seed("zh");
  await page.screenshot({ path: `${DIR}/zh-shell.png` });
  await page.locator(".sb-gear-btn").first().click().catch(() => {});
  await page.waitForTimeout(500);
  await page.screenshot({ path: `${DIR}/zh-settings.png` });
  await page.keyboard.press("Escape").catch(() => {});

  await seed("en");
  await page.screenshot({ path: `${DIR}/en-shell.png` });
  await page.locator(".sb-gear-btn").first().click().catch(() => {});
  await page.waitForTimeout(500);
  await page.screenshot({ path: `${DIR}/en-settings.png` });
  await page.keyboard.press("Escape").catch(() => {});
  // 工坊列表(英文)
  await page.locator(".nav-item", { hasText: /Forge|工坊/ }).first().click().catch(() => {});
  await page.waitForTimeout(800);
  await page.screenshot({ path: `${DIR}/en-forge.png` });

  console.log("console/page errors:", errs.length);
  errs.slice(0, 12).forEach((e) => console.log("  " + e));
} catch (e) {
  console.log("PROBE FAILED:", e.message);
  await page.screenshot({ path: `${DIR}/ERROR.png` });
} finally {
  await browser.close();
}
