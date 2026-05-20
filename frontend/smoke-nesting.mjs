// Verify the Phase 11 hydrateConv fix: REST history puts tool_result
// blocks INSIDE their tool_call parent (not as siblings). Expand the
// first tool_call and assert its DOM contains a .tool-result element.
import { chromium } from "playwright";

const errors = [];
const browser = await chromium.launch();
const page = await (await browser.newContext({ viewport: { width: 1440, height: 900 } })).newPage();
page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
page.on("pageerror", (e) => errors.push("pageerror: " + e.message));

await page.goto("http://localhost:5173/");
await page.waitForSelector(".sidebar");
await page.waitForTimeout(1500);

// Open the verify conv
await page.locator(".nav-item .label:has-text('verify nesting')").click();
await page.waitForTimeout(1200);

const toolHeads = page.locator(".blk-tool .blk-tool-head");
const toolCount = await toolHeads.count();
console.log(`found ${toolCount} tool_call blocks in DOM`);

if (toolCount === 0) { console.log("✗ no tool_call rendered"); process.exit(1); }

// Expand each one and verify it has a .tool-result inside (NOT outside).
for (let i = 0; i < toolCount; i++) {
  const head = toolHeads.nth(i);
  await head.click();
  await page.waitForTimeout(300);
  const tool = page.locator(".blk-tool").nth(i);
  const innerResult = await tool.locator(".tool-result").count();
  const toolName = await tool.locator(".blk-tool-name code").textContent();
  console.log(`  tool[${i}] = ${toolName.trim()}  →  nested .tool-result count = ${innerResult}`);
  if (innerResult !== 1) {
    console.log(`  ✗ expected exactly 1 nested tool-result, got ${innerResult}`);
    process.exit(1);
  }
}

await page.screenshot({ path: "/tmp/forgify-nesting-verified.png", fullPage: true });
console.log("\n=== ERRORS (" + errors.length + ") ===");
errors.forEach((e) => console.log("  ", e));
await browser.close();
if (errors.length) process.exit(1);
console.log("\n✓ hydrateConv parentBlockId fix verified: every tool_call has its tool_result nested inside");
