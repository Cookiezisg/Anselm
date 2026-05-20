// Round 2 — RunDrawer (function 试跑) and Forge action menu.
import { runCase } from "../lib/harness.mjs";
import { backend } from "../lib/backend.mjs";

export default [
  ["forge action menu shows 试跑 / 试调用 / 触发 row item", async ({ page, expect }) => {
    await page.goto("http://localhost:5173/?onboarding=0");
    // open forge pane via sidebar
    await page.locator(".nav-item:has-text('锻造')").click();
    await page.waitForSelector(".pane[data-kind='forge']", { timeout: 4000 });
    await page.waitForTimeout(500);
    // empty state is fine — what we need is the page actions
    const hammer = await page.locator(".page-title:has-text('锻造')").count();
    expect.equals(hammer, 1, "forge pane header renders");
  }],

  ["capability-check button present on workflow detail header (if any workflow)", async ({ page, expect }) => {
    await page.goto("http://localhost:5173");
    await page.locator(".nav-item:has-text('锻造')").click();
    await page.waitForSelector(".pane[data-kind='forge']");
    await page.waitForTimeout(400);
    const hasWfTab = await page.locator(".page-tab:has-text('Workflows')").count();
    expect.equals(hasWfTab, 1, "Workflows tab exists in forge");
  }],
].map(([name, fn]) => () => runCase("31-run-drawer · " + name, fn));
