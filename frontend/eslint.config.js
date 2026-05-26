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
        { type: "shared-tmp", pattern: "src/{bridge,api,sse,store,hooks,motion,i18n,components/primitives}/**" },
        { type: "app-tmp",    pattern: "src/{App.jsx,main.jsx}" },
        { type: "feature-tmp", pattern: "src/{panes,components/{overlays,config,shared,layout}}/**" }
      ]
    },
    rules: {
      // Downgrade all react-hooks recommended rules to "warn" for migration baseline.
      // Phase 0 goal: quantity the violations, not block the build.
      ...Object.fromEntries(
        Object.entries(reactHooks.configs.recommended.rules).map(([k, v]) => [
          k,
          Array.isArray(v) ? ["warn", ...v.slice(1)] : "warn",
        ])
      ),
      "boundaries/element-types": ["warn", { default: "allow", rules: [{ from: "shared-tmp", disallow: ["feature-tmp", "app-tmp"], message: "shared 不能依赖上层" }] }],
      "no-unused-vars": "off",
      "@typescript-eslint/no-unused-vars": "off",
      "@typescript-eslint/no-explicit-any": "off",
      // Downgrade js/ts recommended rules that would cause exit 1 during migration baseline.
      "no-undef": "warn",
      "no-empty": "warn",
      "@typescript-eslint/no-require-imports": "warn"
    }
  }
);
