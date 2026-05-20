// Conversation ActionMenu wiring — pin / rename / archive / delete via
// real backend PATCH + DELETE.
import { runCase } from "../lib/harness.mjs";
import { backend } from "../lib/backend.mjs";

async function freshConv(title) {
  return backend.createConv(title);
}

async function clickMore(page, convTitle) {
  const item = page.locator(`.nav-item-wrap:has(.label:has-text('${convTitle}'))`).first();
  await item.hover();
  await page.waitForTimeout(120);
  await item.locator("button.rel-more-btn").click({ force: true });
  await page.waitForSelector(".action-menu");
}

export default [
  ["pin → conv enters pinned section in sidebar", async ({ page, expect }) => {
    const title = "pin-test " + Date.now();
    await freshConv(title);
    await page.reload({ waitUntil: "domcontentloaded" });
    await page.waitForSelector(".sidebar");
    await page.waitForTimeout(500);
    await clickMore(page, title);
    await page.locator(".action-menu-item:has-text('置顶')").click();
    await page.waitForTimeout(800);
    // Backend should now have pinned=true
    const convs = await backend.conversations();
    const list = Array.isArray(convs) ? convs : convs?.items || [];
    const found = list.find((c) => c.title === title);
    expect.truthy(found?.pinned, "conv should be pinned in backend");
  }],

  ["archive → conv hidden from default sidebar list", async ({ page, expect }) => {
    const title = "archive-test " + Date.now();
    await freshConv(title);
    await page.reload({ waitUntil: "domcontentloaded" });
    await page.waitForSelector(".sidebar");
    await page.waitForTimeout(500);
    await clickMore(page, title);
    await page.locator(".action-menu-item:has-text('归档')").click();
    await page.waitForTimeout(800);
    // Default list endpoint filters out archived convs; success = absent here.
    const convs = await backend.conversations();
    const list = Array.isArray(convs) ? convs : convs?.items || [];
    const found = list.find((c) => c.title === title);
    expect.truthy(!found, "archived conv should be hidden from default list");
  }],

  ["delete (with confirm accept) removes the conv", async ({ page, expect }) => {
    const title = "del-test " + Date.now();
    await freshConv(title);
    await page.reload({ waitUntil: "domcontentloaded" });
    await page.waitForSelector(".sidebar");
    await page.waitForTimeout(500);
    // Auto-accept confirm dialog
    page.on("dialog", (d) => d.accept());
    await clickMore(page, title);
    await page.locator(".action-menu-item:has-text('删除')").click();
    await page.waitForTimeout(1000);
    const convs = await backend.conversations();
    const list = Array.isArray(convs) ? convs : convs?.items || [];
    const stillThere = list.find((c) => c.title === title);
    expect.truthy(!stillThere, "conv should be gone after delete");
  }],
].map(([name, fn]) => () => runCase("30-conv-actions · " + name, fn));
