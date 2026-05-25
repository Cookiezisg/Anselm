# 前端全量 i18n 设计 — Frontend Full i18n

> 状态:设计稿(brainstorming 产物),**已获用户批准** → writing-plans → 实现
> 日期:2026-05-26
> 范围:`frontend/` 全部面向用户的静态 UI 文案

---

## 1. 目标

把目前 hardcode 的中文 UI 文案(~100 文件 / ~900 条)全量改造成 **中英双语**,由 `settings.lang` 驱动、切换即时重渲染。两个价值:

1. 用户能真正在中英之间切换(现在只有 onboarding 能切,其余切了不变)。
2. 中英文案集中成字典,**agent 以后改文案时一眼看到中英对应**,易维护。

---

## 2. 决策记录(选型 + 为什么)

| 决策 | 选择 | 理由 |
|---|---|---|
| 范围 | **全量一次铺完** | 用户明确「全都写了」;分批 commit 但目标是 100% 覆盖 |
| 库 | **react-i18next**(+ i18next 核心) | 事实标准;用法轻(provider 可省 + `useTranslation`);namespace 天然按模块拆;和 `settings.lang` 一行对接;agent 友好 |
| key 风格 | **结构化 key**(`t("handler.retryLabel")`) | key 稳定(改文案不动 key)、namespace 清晰、IDE 跳转友好;key 是英文 camelCase 不含 `.`/`:`,**可直接用 i18next 默认分隔符**(无需像自然 key 那样关分隔符) |
| 字典格式 | 按 namespace 拆 JSON,`zh/` `en/` 两套镜像 | 契合项目「按 feature 拆」;`import.meta.glob` 自动聚合,加 ns 零登记 |
| 加载 | **eager 全量打包** | ~900×2 条 JSON 仅百来 KB,不做 code-split,简单优先 |
| 英文翻译 | 实现时逐条翻,**风格对齐现有 onboarding en**(简洁、技术、句末标点克制) | 已有 onboarding en 是质量基线 |

> 注:这正式把项目早期「no i18n lib(hardcoded zh + scoped onboarding 双语)」的临时决策**升级为真·i18n**。`CLAUDE.md` / 记忆里的「no i18n lib」表述实现后需同步更正。

---

## 3. 架构 & 文件结构

```
frontend/src/i18n/
  index.js          # 配置并 init i18next,export 实例(import 即 side-effect init)
  resources.js      # import.meta.glob 聚合所有 locales/**/*.json → resources 对象
  locales/
    zh/  common.json sidebar.json settings.json conv.json forge.json
         execute.json library.json onboarding.json toast.json
    en/  (同名镜像,key 集合必须一致)
```

`i18n/index.js`(核心契约,实现照此):

```js
import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import { resources } from "./resources.js";
import { useSettings } from "../store/settings.js";

i18n.use(initReactI18next).init({
  resources,
  lng: useSettings.getState().lang,   // zustand persist 同步 hydrate;见 §5 时序
  fallbackLng: "zh",
  defaultNS: "common",
  interpolation: { escapeValue: false }, // React 已防 XSS
  returnNull: false,
});

export default i18n;
```

`resources.js`(自动聚合,加 namespace 不用改这里):

```js
const mods = import.meta.glob("./locales/**/*.json", { eager: true });
// 路径 ./locales/zh/sidebar.json → resources.zh.sidebar
export const resources = /* 由 mods 的路径解析 lang + ns 组装 */;
```

`main.jsx`:在渲染 `<App>` 之前 `import "./i18n";`(确保 init 早于任何 `useTranslation`)。

**调用约定**:每个组件 `const { t } = useTranslation("<本模块ns>")`,跨模块引用通用文案用 `t("common:save")`。

**含 JSX 的文案**(夹 `<b>`、链接、`<code>`):用 `<Trans i18nKey="..." />` 组件,不用 `t()`。

---

## 4. 字典组织 + key 命名规范

- **namespace = 模块**,初定 9 个:`common`(保存/取消/删除/确认/关闭/加载中/重试/复制/编辑/重命名…通用)、`sidebar`、`settings`、`conv`、`forge`、`execute`、`library`、`onboarding`、`toast`。plan 阶段可细调,但每个 ns 必须 zh/en 成对。
- **key = camelCase 语义名**,嵌套用对象:
  ```json
  // zh/forge.json
  { "handler": { "retryLabel": "重试", "newVersion": "新版本" } }
  ```
  调用 `t("handler.retryLabel")`。
- **插值**:`{{var}}`。例:`"convCount": "共 {{count}} 个"` → `t("convCount", { count: n })`。
- **复数**:英文用 i18next `_one`/`_other` 后缀;中文无复数,单 key 即可。

---

## 5. 与 settings.lang 对接(时序)

- `settings.lang` 已存在:首次设备探测(zh*/en)、zustand persist 持久化、写 `root.dataset.lang`。**全部照用,不改语义**。
- **init 初值**:`i18n` init 时取 `useSettings.getState().lang`。zustand persist 默认同步 hydrate,`main.jsx` 中 `import "./i18n"` 在 store import 之后即可拿到持久化值。
- **切换**:`App.jsx` 现有的 `applyTheme` effect(deps 已含 `settings.lang`)旁,新增一个监听 `settings.lang` 的 effect 调 `i18n.changeLanguage(settings.lang)` —— `changeLanguage` 触发所有 `useTranslation` 组件重渲染。
- `AppearanceSection` 的中英切换 UI **原样保留**(它只改 `settings.lang`,changeLanguage 由上面的 effect 统一驱动)。

---

## 6. onboarding-strings.js 迁移(特例)

现有 `src/components/overlays/onboarding-strings.js` 含两类东西,迁移要分开:

1. **`STRINGS.zh` / `STRINGS.en`** → 拆进 `locales/{zh,en}/onboarding.json`。其中**函数式文案**转插值:
   - `keyLabel: (p) => \`${p} API Key\`` → `"keyLabel": "{{provider}} API Key"`,调用 `t("model.keyLabel", { provider: p })`。
   - `availHint: (list) => ...` → `"availHint": "可用模型:{{list}}(下拉切换)"`,调用方先 `list.join(" · ")` 再传入。
2. **非文案常量**(`ACCENTS`、`LLM_HINTS`、`SEARCH_HINTS`、`PROVIDER_DEFAULT_MODEL`)**不进 i18n** —— 留在 `onboarding-strings.js`(或更名为 `onboarding-constants.js`)。
3. `Onboarding.jsx` 改 `useTranslation("onboarding")`,删除 `const t = STRINGS[settings.lang]` 旧逻辑。**两套不并存**。

---

## 7. 测试策略(关键:决定连带工作量)

- **`test-setup.js` 同步 init i18n**(在现有 jsdom stub 区旁):`lng: "zh"`、resources eager 加载。react-i18next 在 resources 同步就绪时 `t()` **同步返回**译文。
- 因此现有 709 测试里大量 `getByText("新对话")` 类断言 → **渲染输出仍是中文 → 基本不用改**。只有极少数直接比对 DOM textContent 的需微调。
- **新增测试**:
  1. **key 完整性**(最重要):遍历每个 namespace,断言 `zh` 与 `en` 的 key 集合**完全一致**(杜绝缺翻、拼错、多余 key)。
  2. 语言切换:`changeLanguage("en")` 后某组件渲染英文。
  3. 插值正确性(`convCount` 等带 `{{}}` 的 key)。

---

## 8. 全量迁移分 9 批(每批一个 commit + push)

| 批 | 内容 | 验证 |
|---|---|---|
| 1 | **基建**:装包 + `i18n/index.js` + `resources.js`(glob)+ `main.jsx` import + test-setup init + App 的 changeLanguage effect + `common.json` | build + 全量测试绿;切 en 时 common 文案变 |
| 2 | **onboarding 迁移**(替换 STRINGS,处理函数文案 + 常量分离) | 现有 onboarding 测试全绿 |
| 3 | **sidebar + 导航 + settings 全区**(ApiKeys/Search/Appearance/System + 账号区) | settings 测试全绿 |
| 4 | **conversation/chat 区** | conv 测试全绿 |
| 5 | **forge 区**(ForgeList/FunctionDetail/HandlerDetail/WorkflowEditor) | forge 测试全绿 |
| 6 | **execute 区**(ExecuteOverview/RunDrawer/FlowRun) | execute 测试全绿 |
| 7 | **library 区**(DocumentsPane/DocEditor/RelGraph) | library 测试全绿 |
| 8 | **其余**(toast/共享组件/空态/杂项) | 全量测试绿 |
| 9 | **收尾**:grep 兜底扫残留 hardcode 中文 + 全量 en 校对 + key 完整性闸门 + PRD/CLAUDE.md 文档同步 | 验收标准全过 |

每批节奏:抽文案 → 建 zh/en key → 组件改 `useTranslation`+`t()` → 跑该模块测试 → commit + push。

---

## 9. 范围边界

- **范围内**:前端硬编码的静态 UI 文案。
- **范围外(本期不做)**:后端返回的动态内容、`error` message、notification 文本 —— 后端来的中文照原样显示。若以后要,另起一期按 error code 在前端映射。
- **不动**:`settings.lang` 的探测/持久化语义、`AppearanceSection` 切换 UI、所有非文案常量(品牌色、provider abbr 等)。

---

## 10. 工程量(诚实预估)

- ~100 文件改造(加 `useTranslation` + `t()` 包裹)。
- ~900 key × 中英 = ~1800 条 JSON。
- ~900 条英文翻译(实现时逐条,风格对齐 onboarding en)。
- 测试:大部分中文断言因 test 默认 zh 不动;新增 key 完整性 + 切换 + 插值测试。
- 本前端阶段最大单项工程,拆 9 批、几十个 subagent 任务连续跑。

---

## 11. 验收标准

- [ ] 切 `settings.lang` 后全 app 文案即时切换,无残留反向语言。
- [ ] `rg "\p{Han}"` 兜底:`src/` 下除 `locales/`、注释、非文案常量外,无 hardcode 中文 UI 文案。
- [ ] 每个 namespace 的 `zh`/`en` key 集合一致(完整性测试通过)。
- [ ] 全量测试绿(709 + 新增),`npm run build` 干净。
- [ ] bundle 增量合理(i18next + 字典 < ~150KB)。
- [ ] `CLAUDE.md` / PRD §17 的「no i18n lib」表述同步更正为 react-i18next。
