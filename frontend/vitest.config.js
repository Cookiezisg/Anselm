// Vitest config — co-located `*.test.{ts,tsx,js,jsx}` next to source.
// Coverage is opt-in via `npm run test:coverage`. setupFiles stubs the
// browser APIs we touch but jsdom doesn't ship.

import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import tsconfigPaths from "vite-tsconfig-paths";

export default defineConfig({
  plugins: [react(), tsconfigPaths()],
  esbuild: { jsx: "automatic" },
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./src/test-shim-storage.js", "./src/test-setup.js"],
    include: ["src/**/*.{test,spec}.{js,jsx,ts,tsx}"],
    exclude: ["tests/**", "node_modules/**", "dist/**"],
    coverage: {
      provider: "v8",
      reporter: ["text", "html", "lcov"],
      include: ["src/**/*.{js,jsx,ts,tsx}"],
      // Skip list — each excluded file has a documented reason:
      //   test infra — setup shims + query/fetch harnesses
      //   constants / tokens — no logic to test
      //   icon barrels — lucide-react re-exports
      //   composition shells — App, main: covered by Playwright e2e
      //   trivial wrappers — PaneCollapseToggle/BottomSheet/FloatingInspector/useCollapsible
      //   heavy editors — DocEditor (Tiptap), CodeBlockNode, WorkflowEditor
      //     (canvas DAG), RelGraph (force layout): full integration via Playwright
      exclude: [
        "src/**/*.{test,spec}.{js,jsx,ts,tsx}",
        "src/test-setup.js",
        "src/test-setup.d.ts",
        "src/test-shim-storage.js",
        "src/shared/lib/testHarness.ts",
        "src/shared/api/_testHarness.ts",
        "src/app/main.tsx",
        "src/app/App.tsx",
        "src/shared/lib/motion.ts",
        "src/shared/ui/Icon.tsx",
        "src/shared/ui/Spinner.tsx",
        "src/shared/ui/Kbd.tsx",
        "src/shared/ui/PaneCollapseToggle.tsx",
        "src/shared/ui/BottomSheet.tsx",
        "src/shared/ui/FloatingInspector.tsx",
        "src/shared/lib/useCollapsible.ts",
        "src/pages/library/ui/DocEditor.tsx",
        "src/pages/library/ui/CodeBlockNode.tsx",
        "src/features/workflow-edit/ui/WorkflowEditor.tsx",
        "src/widgets/rel-graph/RelGraph.tsx",
      ],
      // Thresholds: v8 counts every arrow inside JSX as a separate
      // function, so even comprehensively-tested components like
      // BlockRenderer often show ~40% function coverage despite >80%
      // branch + line coverage. Functions threshold accordingly held at
      // 75 — the more meaningful gates are branches + lines.
      //
      // Threshold —— v8 把 JSX 里每个箭头都算独立函数；BlockRenderer 这种
      // 即便实测全跑过函数覆盖率也只有 ~40%。分支/行覆盖才是真信号。
      thresholds: {
        statements: 80,
        branches: 75,
        functions: 75,
        lines: 80,
      },
    },
  },
});
