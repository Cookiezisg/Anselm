// resources.js — eager-glob 所有 locales JSON,组装成 i18next resources。
// 加新 namespace 文件后这里零改动。

const mods = import.meta.glob("./locales/**/*.json", { eager: true });

export const resources = {};
for (const [path, mod] of Object.entries(mods)) {
  const m = path.match(/\.\/locales\/([^/]+)\/([^/]+)\.json$/);
  if (!m) continue;
  const [, lng, ns] = m;
  (resources[lng] ||= {})[ns] = mod.default;
}
