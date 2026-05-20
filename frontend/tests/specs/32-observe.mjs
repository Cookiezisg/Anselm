// Round 6 — Observe pane (RelGraph SVG).
import { runCase } from "../lib/harness.mjs";

export default [
  ["sidebar has 洞察 nav item", async ({ page, expect }) => {
    await page.goto("http://localhost:5173");
    await page.waitForSelector(".sidebar");
    const observe = await page.locator(".nav-item:has-text('洞察')").count();
    expect.equals(observe, 1, "sidebar should have Observe nav item");
  }],

  ["clicking 洞察 opens observe pane with RelGraph svg + filter chips", async ({ page, expect }) => {
    await page.goto("http://localhost:5173");
    await page.waitForSelector(".sidebar");
    await page.locator(".nav-item:has-text('洞察')").click();
    await page.waitForSelector(".pane[data-kind='observe']");
    await page.waitForTimeout(500);
    const filters = await page.locator(".rg-kind-filter").count();
    expect.gte(filters, 5, "Observe pane shows at least 5 kind filter chips");
    const svg = await page.locator(".rg-svg").count();
    expect.equals(svg, 1, "Observe pane mounts force-directed SVG canvas");
  }],

  ["observe pane shows node count and edge count in toolbar", async ({ page, expect }) => {
    await page.goto("http://localhost:5173");
    await page.locator(".nav-item:has-text('洞察')").click();
    await page.waitForSelector(".pane[data-kind='observe']");
    await page.waitForTimeout(1500);
    const toolbar = await page.locator(".rg-toolbar").first().textContent();
    expect.truthy((toolbar || "").includes("节点"), "toolbar shows node/edge counts (" + toolbar + ")");
  }],
].map(([name, fn]) => () => runCase("32-observe · " + name, fn));
