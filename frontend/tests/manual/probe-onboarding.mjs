// Manual browser walk of the 6-step onboarding. Verifies the split layout
// renders, language auto-detect (locale zh-CN → zh copy), live accent/theme,
// step navigation, and entering the app with no 401 flood.
//
// Run: `make dev` in another terminal, then `node tests/manual/probe-onboarding.mjs`.
// Screenshots → /tmp/forgify-onb/.

import { chromium } from "playwright";
import { mkdirSync } from "fs";

const DIR = "/tmp/forgify-onb";
mkdirSync(DIR, { recursive: true });
const FE = process.env.FRONTEND_URL || "http://localhost:5173";

const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 1280, height: 820 }, locale: "zh-CN" });
const page = await ctx.newPage();

const errors = [];
const unauthorized = [];
page.on("pageerror", (e) => errors.push("PAGEERR: " + e.message));
page.on("console", (m) => { if (m.type() === "error") errors.push("CONSOLE: " + m.text()); });
page.on("response", (r) => { if (r.status() === 401) unauthorized.push(r.url()); });

const log = (...a) => console.log(...a);
const shot = (n) => page.screenshot({ path: `${DIR}/${n}.png` });
const text = (sel) => page.locator(sel).first().innerText().catch(() => "(none)");
async function clickBtn(re) {
  await page.getByRole("button", { name: re }).first().click();
  await page.waitForTimeout(400);
}

try {
  await page.goto(`${FE}/?onboarding=1`, { waitUntil: "domcontentloaded", timeout: 15000 });
  await page.waitForTimeout(1200);

  // STEP 1 — welcome (zh expected from locale detection)
  const cardN = await page.locator(".onb-card").count();
  const journeyN = await page.locator(".onb-jstep").count();
  log(`[1] welcome — .onb-card=${cardN} journeySteps=${journeyN} title="${await text(".onb-pane .onb-title")}"`);
  await shot("1-welcome");

  await clickBtn(/开始/);
  // STEP 2 — workspace
  log(`[2] workspace title="${await text(".onb-pane .onb-title")}"`);
  await page.locator(".onb-input").first().fill("probe-" + Date.now().toString(36));
  await shot("2-workspace");
  await clickBtn(/继续/); // creates user
  await page.waitForTimeout(700);

  // STEP 3 — appearance + live accent / lang / dark
  log(`[3] appearance title="${await text(".onb-pane .onb-title")}"`);
  await shot("3a-appearance");
  await page.locator(".onb-swatch").nth(0).click(); // claude (orange) — proves live recolor
  await page.waitForTimeout(200);
  const accentVal = await page.evaluate(() => ({
    attr: document.documentElement.dataset.accent,
    color: getComputedStyle(document.documentElement).getPropertyValue("--accent").trim(),
  }));
  log(`    accent after claude swatch → dataset.accent=${accentVal.attr} --accent=${accentVal.color}`);
  await page.getByText("English", { exact: true }).click();
  await page.waitForTimeout(200);
  log(`    after English → title="${await text(".onb-pane .onb-title")}" lang=${await page.evaluate(() => document.documentElement.dataset.lang)}`);
  // dark theme
  await page.getByText(/Dark/i).first().click();
  await page.waitForTimeout(200);
  const themeAttr = await page.evaluate(() => document.documentElement.dataset.theme);
  log(`    after Dark → dataset.theme=${themeAttr}`);
  await shot("3b-appearance-blue-en-dark");
  // back to light + zh for the rest
  await page.getByText(/System/i).first().click();
  await page.getByText("中文", { exact: true }).click();
  await page.waitForTimeout(200);

  await clickBtn(/继续/);
  // STEP 4 — model
  log(`[4] model title="${await text(".onb-pane .onb-title")}" providerCards=${await page.locator(".onb-prov").count()}`);
  await page.getByText("DeepSeek", { exact: true }).click();
  await page.waitForTimeout(200);
  const keyInputN = await page.locator(".onb-kinput input").count();
  const verifyBtnN = await page.getByRole("button", { name: /验证/ }).count();
  log(`    picked DeepSeek → keyInput=${keyInputN} verifyBtn=${verifyBtnN}`);
  await shot("4-model");

  await clickBtn(/继续/); // skip verify (model optional)
  // STEP 5 — search
  log(`[5] search title="${await text(".onb-pane .onb-title")}" searchCards=${await page.locator(".onb-prov").count()}`);
  await shot("5-search");
  await clickBtn(/跳过/);

  // STEP 6 — done
  log(`[6] done title="${await text(".onb-pane .onb-title")}" recapCards=${await page.locator(".onb-recap-card").count()}`);
  await shot("6-done");

  await clickBtn(/进入/);
  await page.waitForTimeout(1500);
  const onbGone = (await page.locator(".onb-card").count()) === 0;
  const shellN = await page.locator(".app-shell, .sidebar, [class*='shell']").count();
  log(`[enter] onboardingGone=${onbGone} shellEls=${shellN}`);
  await shot("7-app");

  log(`\n=== console errors: ${errors.length} ===`);
  errors.slice(0, 15).forEach((e) => log("  " + e));
  log(`=== 401 responses: ${unauthorized.length} ===`);
  unauthorized.slice(0, 10).forEach((u) => log("  " + u));
} catch (e) {
  log("PROBE FAILED:", e.message);
  await shot("ERROR");
} finally {
  await browser.close();
}
