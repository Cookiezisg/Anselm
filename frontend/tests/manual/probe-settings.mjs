// Manual browser walk of the new SettingsModal. Lands on AppShell as an
// existing user, opens settings via the sidebar gear, walks the accordion
// (single-open), the inline add-key panel, the appearance controls, and Esc.
//
// Run: `make dev` in another terminal, then `node tests/manual/probe-settings.mjs`.
// Screenshots → /tmp/forgify-set/.

import { chromium } from "playwright";
import { mkdirSync } from "fs";

const DIR = "/tmp/forgify-set";
mkdirSync(DIR, { recursive: true });
const FE = process.env.FRONTEND_URL || "http://localhost:5173";

const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 1280, height: 880 }, locale: "zh-CN" });
const page = await ctx.newPage();

const errors = [], unauth = [];
page.on("pageerror", (e) => errors.push("PAGEERR: " + e.message));
page.on("console", (m) => { if (m.type() === "error") errors.push("CONSOLE: " + m.text()); });
page.on("response", (r) => { if (r.status() === 401) unauth.push(r.url()); });
const log = (...a) => console.log(...a);
const shot = (n) => page.screenshot({ path: `${DIR}/${n}.png` });
const openSection = async (label) => {
  const h = page.locator(".set-sec-h", { hasText: label }).first();
  await h.scrollIntoViewIfNeeded();
  await h.click();
  await page.waitForTimeout(450);
};

try {
  await page.goto(`${FE}/`, { waitUntil: "domcontentloaded", timeout: 15000 });
  // Seed an existing user so we land on AppShell (settings is for existing users). /users is auth-exempt.
  const uid = await page.evaluate(async () => {
    const r = await fetch("/api/v1/users");
    const j = await r.json();
    const users = j.data?.items || j.data || [];
    const id = users[0]?.id || null;
    localStorage.setItem("forgify-settings", JSON.stringify({
      state: { onboarded: true, activeUserId: id, theme: "system", accent: "claude", density: "cozy", lang: "zh", reasoningDefault: "collapsed", leftPct: 50 },
      version: 1,
    }));
    return id;
  });
  log("seeded user:", uid);
  await page.reload({ waitUntil: "domcontentloaded" });
  await page.waitForTimeout(1600);

  const gear = page.locator(".sb-gear-btn");
  log("gear present:", await gear.count());
  await gear.first().click();
  await page.waitForTimeout(500);

  log(`[modal] scrim=${await page.locator(".set-scrim").count()} modal=${await page.locator(".set-modal").count()} sections=${await page.locator(".set-sec").count()}`);
  await shot("1-open-default");

  // accordion single-open: open 外观, then API Keys
  await openSection("外观");
  await shot("2-appearance");
  await openSection("网络搜索");
  await shot("3-search");
  await openSection("API Keys");
  // inline add-key
  const addBtn = page.locator(".set-addbtn");
  log("add button:", await addBtn.count());
  if (await addBtn.count()) { await addBtn.first().click(); await page.waitForTimeout(450); }
  log("provider cards in add panel:", await page.locator(".onb-prov").count());
  await shot("4-addkey");

  // Esc closes
  await page.keyboard.press("Escape");
  await page.waitForTimeout(400);
  log("[esc] modal gone:", (await page.locator(".set-modal").count()) === 0);

  log(`\n=== console errors: ${errors.length} ===`);
  errors.slice(0, 12).forEach((e) => log("  " + e));
  log(`=== 401 responses: ${unauth.length} ===`);
  unauth.slice(0, 8).forEach((u) => log("  " + u));
} catch (e) {
  log("PROBE FAILED:", e.message);
  await shot("ERROR");
} finally {
  await browser.close();
}
