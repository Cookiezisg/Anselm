---
id: DOC-239
type: reference
status: active
owner: @weilin
created: 2026-05-27
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# entities/settings — 前端 slice 详细设计

**所属层**：entities（纯前端，无后端 domain 对位）
**状态**：✅ 已实现
**职责**：管理用户 UI 偏好（主题 / accent / 密度 / 语言 / reasoning 默认展开），持久化到 localStorage，并提供 `applyTheme` 将设置写入 `<html>` 的 `data-*` 属性。

**关联文档**：
- [`../frontend-design.md`](../frontend-design.md) — FSD 总规范
- CLAUDE.md 前端开发守则（绝对不改的 boilerplate 决策）

---

## 1. 职责边界

- 偏好状态持久化（Zustand persist，key: `forgify-settings`）
- 主题应用（`applyTheme` → `<html>` data-attrs）
- 语言切换（`lang` 驱动 react-i18next）
- 无 API 调用——纯本地偏好，不同步到后端

---

## 2. 类型 + Store（`model/settingsStore.ts`）

```ts
interface SettingsState {
  theme: "system" | "light" | "dark";
  accent: "claude" | "blue" | "ink" | "green" | "purple";
  density: "compact" | "cozy" | "comfortable";
  lang: "zh" | "en";
  reasoningDefault: "collapsed" | "expanded";
  set(patch: Partial<Omit<SettingsState, "set" | "reset">>): void;
  reset(): void;
}
```

默认值：`theme:"system"`, `accent:"claude"`, `density:"cozy"`, `lang: detectLang()`, `reasoningDefault:"collapsed"`。

`detectLang` 读 `navigator.language`（zh 前缀 → "zh"，其余 → "en"），避免 shared-tmp 依赖，内联在本 slice。

---

## 3. 辅助函数

```ts
// 将 "system" 解析为实际 "light"/"dark"（prefers-color-scheme）
function resolveTheme(theme: string): "light" | "dark"

// 将 theme/accent/density/lang 写入 <html> data-* 属性
// 幂等，每次 settings 变更后调用
function applyTheme(settings: Pick<SettingsState, "theme"|"accent"|"density"|"lang">): void
```

`applyTheme` 写：
- `document.documentElement.dataset.theme` = `resolveTheme(theme)`
- `document.documentElement.dataset.accent` = accent
- `document.documentElement.dataset.density` = density
- `document.documentElement.dataset.lang` = lang

CSS 通过 `html[data-theme="dark"]` 等选择器切换样式变量，无需 JS 注入 class。

---

## 4. 端到端数据流

```
用户在 Settings > Appearance 切换主题
  → features/settings → useSettingsStore.set({theme: "dark"})
      → Zustand persist 写入 localStorage "forgify-settings"
      → 订阅 settings 变更的 App 层 effect
      → applyTheme(settings) → html.dataset.theme = "dark"
      → CSS vars 实时生效

用户切换语言
  → useSettingsStore.set({lang: "en"})
      → app 层 i18n effect → i18n.changeLanguage("en")
      → react-i18next 刷新所有 t() 调用
```

---

## 5. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/entities/settings/model/settingsStore.ts` | useSettingsStore + 默认值 + detectLang + resolveTheme + applyTheme |
| `frontend/src/entities/settings/index.ts` | public API（store + 两个工具函数） |
