// Headless smoke — walks every pane, opens cmdk, captures screenshots,
// reports console errors.
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
await page.waitForTimeout(1200);

const sidebarVisible = await page.locator(".sidebar").first().isVisible();
console.log("sidebar visible:", sidebarVisible);

// Default state opens chat pane. Capture it.
const chatVisible = await page.locator(".pane[data-kind='chat']").first().isVisible().catch(() => false);
console.log("chat (default) visible:", chatVisible);
await page.screenshot({ path: "/tmp/forgify-chat-default.png" });

// Walk each non-chat pane: open, capture, close.
const otherPanes = [
  ["forge", "锻造"],
  ["execute", "执行"],
  ["documents", "文档"],
  ["skills", "Skills"],
  ["mcp", "MCP"],
  ["memory", "Memory"],
];

for (const [kind, label] of otherPanes) {
  console.log(`→ open ${kind}`);
  await page.locator(`button.nav-item:has-text("${label}")`).first().click();
  await page.waitForSelector(`.pane[data-kind="${kind}"]`, { timeout: 5000 });
  await page.waitForTimeout(400);
  await page.screenshot({ path: `/tmp/forgify-${kind}.png` });
  // close pane
  await page.locator(`button.nav-item:has-text("${label}")`).first().click();
  await page.waitForTimeout(300);
}

// cmdk
console.log("→ open cmdk");
await page.keyboard.press("Meta+k");
await page.waitForSelector(".cmdk", { timeout: 4000 });
await page.screenshot({ path: "/tmp/forgify-cmdk.png" });
await page.keyboard.press("Escape");
await page.waitForTimeout(200);

// notifications drawer (bell)
console.log("→ open notifs drawer");
await page.locator(".sidebar .user-pill button.icon-btn[title*='通知']").click();
await page.waitForTimeout(500);
await page.screenshot({ path: "/tmp/forgify-notifs.png" });
await page.keyboard.press("Escape");
await page.waitForTimeout(200);

// settings popover
console.log("→ open settings popover");
await page.locator(".sidebar .user-pill button.icon-btn[title*='主题']").click();
await page.waitForTimeout(500);
await page.screenshot({ path: "/tmp/forgify-settings.png" });

console.log("\n=== ERRORS (" + errors.length + ") ===");
errors.forEach((e) => console.log("  ", e));

await browser.close();
if (errors.length > 0) process.exit(1);
console.log("\n✓ all panes rendered without errors");
