// Real chat smoke — open existing conv, hit DeepSeek via send, watch SSE
// render in real time, capture screenshot at completion.
import { chromium } from "playwright";

const errors = [];

const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
const page = await ctx.newPage();

page.on("console", (msg) => {
  if (msg.type() === "error") errors.push(msg.text());
});
page.on("pageerror", (err) => errors.push("pageerror: " + err.message));

await page.goto("http://localhost:5173/", { waitUntil: "domcontentloaded", timeout: 15000 });
await page.waitForSelector(".sidebar", { timeout: 8000 });
await page.waitForTimeout(1500);

// Click the existing E2E DeepSeek test conversation in the sidebar.
console.log("→ click E2E conv");
await page.locator(".nav-item .label:has-text('E2E DeepSeek test')").first().click();
await page.waitForTimeout(1500);

// Verify messages rendered (the conv has 2 messages from earlier curl test).
const msgCount = await page.locator(".msg").count();
console.log("rendered messages:", msgCount);

await page.screenshot({ path: "/tmp/forgify-chat-history.png" });

if (msgCount < 2) {
  console.log("WARN: expected at least 2 messages from prior REST test");
}

// Compose a fresh message
console.log("→ type new message");
const ta = page.locator(".composer-textarea");
await ta.click();
await ta.fill("用一个emoji总结你的功能");
await page.waitForTimeout(300);
await page.screenshot({ path: "/tmp/forgify-composer-typed.png" });

// Send
console.log("→ send");
await page.locator(".send-btn:not(.is-stop):not(.is-disabled)").click();

// Wait for streaming to start (a streaming badge appears)
await page.waitForSelector(".badge.streaming", { timeout: 10000 }).catch(() => null);
await page.waitForTimeout(2000);
await page.screenshot({ path: "/tmp/forgify-chat-streaming.png" });
console.log("→ streaming captured");

// Wait for completion (streaming badge disappears).
console.log("→ wait for completion (up to 60s)");
await page.waitForFunction(
  () => !document.querySelector(".badge.streaming"),
  { timeout: 60_000 }
);
await page.waitForTimeout(800);

const finalMsgCount = await page.locator(".msg").count();
console.log("final messages:", finalMsgCount);

await page.screenshot({ path: "/tmp/forgify-chat-done.png" });

console.log("\n=== ERRORS (" + errors.length + ") ===");
errors.forEach((e) => console.log("  ", e));

await browser.close();
if (errors.length > 0) process.exit(1);
console.log("\n✓ chat e2e success");
