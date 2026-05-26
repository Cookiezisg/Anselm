import js from "@eslint/js";
import globals from "globals";
import tseslint from "typescript-eslint";
import reactHooks from "eslint-plugin-react-hooks";
import boundaries from "eslint-plugin-boundaries";

export default tseslint.config(
  { ignores: ["dist", "coverage", "node_modules", "**/*.test.{js,jsx,ts,tsx}"] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ["src/**/*.{js,jsx,ts,tsx}"],
    languageOptions: { globals: { ...globals.browser } },
    plugins: { "react-hooks": reactHooks, boundaries },
    settings: {
      "boundaries/elements": [
        // FSD 正式 6 层(阶段4b 全部落地)
        { type: "shared",   pattern: "src/shared/**" },
        { type: "entities", pattern: "src/entities/*", capture: ["slice"] },
        { type: "features", pattern: "src/features/*", capture: ["slice"] },
        { type: "widgets",  pattern: "src/widgets/**" },
        { type: "pages",    pattern: "src/pages/*",    capture: ["slice"] },
        { type: "app",      pattern: "src/app/**" },
      ]
    },
    rules: {
      // Downgrade react-hooks recommended rules to "warn" for migration baseline.
      ...Object.fromEntries(
        Object.entries(reactHooks.configs.recommended.rules).map(([k, v]) => [
          k,
          Array.isArray(v) ? ["warn", ...v.slice(1)] : "warn",
        ])
      ),
      "boundaries/dependencies": ["error", {
        default: "allow",
        rules: [
          // shared 层强制:不得依赖任何上层代码
          { from: { type: "shared" }, disallow: { to: { type: ["entities", "features", "widgets", "pages", "app"] } }, message: "shared 不能依赖上层" },
          // entities 层:只允许 import shared;禁止上层及同层跨 slice
          // (跨 slice 通过 @x barrel 协议豁免,eslint-boundaries 无法感知 @x;
          //  结构违规由 steiger 负责;eslint 只守住更粗粒度的单向规则)
          { from: { type: "entities" }, disallow: { to: { type: ["features", "widgets", "pages", "app"] } }, message: "entities 不能依赖上层" },
          // features 层:只允许 import shared + entities;禁止上层及同层
          { from: { type: "features" }, disallow: { to: { type: ["widgets", "pages", "app"] } }, message: "features 不能依赖 widgets/pages/app" },
          // widgets 层:不得依赖 pages + app(导航走 shared/lib/navigation DIP)
          { from: { type: "widgets" }, disallow: { to: { type: ["pages", "app"] } }, message: "widgets 不能依赖 pages/app" },
          // pages 层:不得依赖 app(状态由 AppShell 经 props 传入)
          { from: { type: "pages" }, disallow: { to: { type: ["app"] } }, message: "pages 不能依赖 app" },
        ]
      }],
      "no-unused-vars": "off",
      "@typescript-eslint/no-unused-vars": "off",
      "@typescript-eslint/no-explicit-any": "off",
      "no-undef": "warn",
      "no-empty": "warn",
      "@typescript-eslint/no-require-imports": "warn"
    }
  }
);
