// Debug smoke - capture console errors immediately
import { chromium } from "playwright";

const errors = [];

const browser = await chromium.launch();
const page = await browser.newContext({ viewport: { width: 1440, height: 900 } }).then(c => c.newPage());

page.on("console", (msg) => {
  console.log(`[${msg.type()}]`, msg.text());
  if (msg.type() === "error") errors.push(msg.text());
});
page.on("pageerror", (err) => {
  console.log("[pageerror]", err.message);
  errors.push("pageerror: " + err.message);
});

await page.goto("http://localhost:5173/", { waitUntil: "domcontentloaded", timeout: 15000 });
await page.waitForTimeout(3000);

const root = await page.locator("#root").innerHTML().catch(() => "(empty)");
console.log("ROOT LENGTH:", root.length);

await page.locator(".nav-item .label:has-text('E2E DeepSeek test')").first().click().catch((e) => console.log("CLICK FAILED:", e.message));
await page.waitForTimeout(3000);

const rootAfter = await page.locator("#root").innerHTML().catch(() => "(empty)");
console.log("ROOT LENGTH AFTER CLICK:", rootAfter.length);

await page.screenshot({ path: "/tmp/forgify-debug.png" });

await browser.close();
console.log("\nTOTAL ERRORS:", errors.length);
