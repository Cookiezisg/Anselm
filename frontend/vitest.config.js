// Vitest config — co-located `*.test.js` / `*.test.jsx` next to
// source. Coverage is opt-in via `npm run test:coverage`. setupFiles
// stubs the browser APIs we touch but jsdom doesn't ship.

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
      include: ["src/**/*.{js,jsx}"],
      // Skip list — each excluded file has a documented reason:
      //   constants / tokens — no logic to test
      //   icon barrels — lucide-react re-exports
      //   composition shells — App, AppShell, main: covered by Playwright e2e
      //   placeholder — Dashboard / PlaceholderPane: no logic
      //   heavy editors — DocEditor (Tiptap), WorkflowEditor (canvas DAG),
      //     RelGraph (force layout): full integration via Playwright instead
      //   ConfigPane — large form aggregate; per-field already tested via
      //     SettingsPopover/Onboarding; full e2e covers integration
      //   trivial helpers — PaneCollapseToggle, useCollapsible: 1-line wrappers
      //   DataViewerInspector — debug-only modal, internal
      //   _testHarness — vitest helpers
      exclude: [
        "src/test-setup.js",
        "src/test-setup.test.js",
        "src/**/*.{test,spec}.{js,jsx}",
        "src/shared/lib/testHarness.js",
        "src/app/main.jsx",
        "src/app/App.jsx",
        "src/shared/lib/motion.ts",
        "src/shared/ui/Icon.tsx",
        "src/shared/ui/Spinner.tsx",
        "src/shared/ui/Kbd.tsx",
        "src/shared/ui/PaneCollapseToggle.jsx",
        "src/shared/ui/BottomSheet.jsx",
        "src/shared/ui/FloatingInspector.jsx",
        "src/shared/lib/useCollapsible.js",
        "src/entities/document/ui/DocEditor.jsx",
        "src/pages/library/ui/CodeBlockNode.jsx",
        "src/features/workflow-edit/ui/WorkflowEditor.jsx",
        "src/widgets/rel-graph/RelGraph.jsx",
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
