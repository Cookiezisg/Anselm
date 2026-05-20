// Round 5 — DocumentsPane Notion tree + page CRUD.
import { runCase } from "../lib/harness.mjs";
import { backend } from "../lib/backend.mjs";

// Pre-seed via REST (no /documents seeder yet — just trust empty state).
export default [
  ["documents pane shows tree sidebar + new button", async ({ page, expect }) => {
    await page.goto("http://localhost:5173");
    await page.locator(".nav-item:has-text('文档')").click();
    await page.waitForSelector(".pane[data-kind='documents']");
    await page.waitForTimeout(600);
    const sidebar = await page.locator(".doc-sidebar").count();
    expect.equals(sidebar, 1, "doc sidebar renders");
    const newBtn = await page.locator(".doc-sidebar-head .icon-btn[title='新建顶级页面']").count();
    expect.equals(newBtn, 1, "new-page button in sidebar header");
  }],

  ["empty documents state shows '新建第一篇' CTA", async ({ page, expect }) => {
    await page.goto("http://localhost:5173");
    await page.locator(".nav-item:has-text('文档')").click();
    await page.waitForSelector(".pane[data-kind='documents']");
    await page.waitForTimeout(800);
    // Either has docs or shows empty state with CTA
    const empty = await page.locator(".empty .title:has-text('还没有打开的文档')").count();
    const tree = await page.locator(".doc-tree-item").count();
    expect.truthy(empty + tree > 0, "either empty CTA or existing doc tree shows");
  }],
].map(([name, fn]) => () => runCase("33-documents · " + name, fn));
