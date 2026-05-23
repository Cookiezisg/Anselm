// Vitest config — co-located `*.test.js` / `*.test.jsx` next to
// source. Coverage is opt-in via `npm run test:coverage`. setupFiles
// stubs the browser APIs we touch but jsdom doesn't ship.

import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./src/test-setup.js"],
    include: ["src/**/*.{test,spec}.{js,jsx}"],
    exclude: ["tests/**", "node_modules/**", "dist/**"],
    coverage: {
      provider: "v8",
      reporter: ["text", "html", "lcov"],
      include: ["src/**/*.{js,jsx}"],
      exclude: [
        "src/test-setup.js",
        "src/**/*.{test,spec}.{js,jsx}",
        "src/main.jsx",
        "src/motion/tokens.js",
        "src/components/primitives/Icon.jsx",
        "src/components/shared/lowlightInstance.js",
      ],
      thresholds: {
        statements: 80,
        branches: 75,
        functions: 80,
        lines: 80,
      },
    },
  },
});
