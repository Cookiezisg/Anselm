# 首次启动 / 身份引导重做 — 设计

> Date: 2026-05-25 · Status: 待用户审 · Scope: 前端 first-run / 身份 bootstrap(就绪状态机 + 6 步引导 UI)+ 既有后端交互。后端**无改动**。
> 已批准 mockup:`.superpowers/brainstorm/.../onboarding-full.html`(split「舞台 + 步骤」布局,6 步)。

---

## 1. 背景与问题

身份 / 就绪生命周期当初没当成一个东西设计,散在 localStorage(settings)+ App.jsx 多个 effect + apiFetch 401 自愈 + 一半 query gate。一堆 bug 同根:

- **401 日志洪水(真 bug)**:`activeUserId` 脏(指向已删 user,如清库后 localStorage 残留)→ App.jsx 的 `resolvingUser` 闸门**只挡 `!activeUserId`(null),挡不住"非空但无效"** → AppShell 带脏 id 挂载 → user-scoped REST(**列表查询无 `enabled` gate**)+ SSE 全 401 → 自愈清 id → 账号切换 effect `invalidateQueries()` 级联重拉 → 又一轮 401 → 刷屏。
- **引导页**:5 步、视觉平庸、文案幼稚("点睛色 / 配一把钥匙 / 起个名字")—— 不符合 toB。
- **模型配置**:test 后**自动取 `modelsFound[0]`** 当 chat 模型(瞎猜 → 之前的 `deepseek-v4-flash` 配了跑不动),用户无法选模型。
- **搜索 API** 无处配置。
- **语言不读设备**(`DEFAULTS.lang` 硬编码 `"zh"`);前端无 i18n。

## 2. 目标

把"**首次启动 / 身份**"当**一个模块**重做:① 一个**显式的会话就绪状态机**根治"带未校验身份就开跑"的整类 bug;② 一套 **toB 级 6 步引导**,能配清模型(含选模型)/搜索,自动适配语言与明暗,主题色实时预览。

---

## 3. Part A — 身份就绪状态机(内在地基)

### 3.1 三态(一处拥有)

```
booting    — /users 加载中,或 activeUserId 待校验
onboarding — users.length === 0(fresh install)或 ?onboarding=1 强制
ready      — activeUserId 已"校验"(确在 /users 列表里)
```

收敛到一个 readiness 选择器 / hook(替代当前散在 App.jsx 的 `showOnboarding` / `resolvingUser` 拼装)。

### 3.2 铁律:不到 `ready`,任何 user-scoped 的东西都不准发

- **user-scoped REST 列表查询全部加 `enabled`(gate 在 ready 上)** —— 当前列表查询(useConversations / useFlowruns / useFunctions / useHandlers / useNotifications)裸跑,是洪水主因。detail 查询已有 `enabled: !!id`,列表查询补齐。
- **SSE** 已 gate 在 `activeUserId`(`sse/shared.js`:null 不连),保持。
- **脏 id 修复(核心)**:`activeUserId` 非空但**不在 /users 列表** → 视同未就绪(`booting`),先校验 + 自愈,**绝不带它挂 AppShell**。即就绪判定从"`activeUserId` 非空"改成"`activeUserId` ∈ users"。

### 3.3 自愈收敛(去掉抖动循环)

- /users 返回后:`activeId` 不在列表 → 清;无 `activeId` 且 `users.length≥1` → 选 `users[0]`。
- 这套只在 `booting` 跑;进 `ready` 后不再因 query 401 抖动 —— 因为 query 在 `ready` 前根本不发,且发的时候带的是已校验 id。
- 由此**"401 → 清 id → invalidateQueries → 重拉 → 再 401"的循环不再可能**。

---

## 4. Part B — 6 步引导 UI

布局:split「品牌舞台 + 旅程式步骤进度 + 内容区」(见已批准 mockup)。

| 步 | 名 | 内容 | 后端写入 |
|---|---|---|---|
| 1 | 欢迎 | 产品介绍 + 3 特性 | — |
| 2 | 工作空间 | 名称 → 创建 user | POST /users |
| 3 | 外观 | 主题色(实时)+ 语言 + 主题 | 仅本地 settings |
| 4 | 模型 | provider + API Key + **选模型** | POST /api-keys + :test + /model-configs |
| 5 | 搜索(可选)| 搜索服务商 + key,可跳过 | POST /api-keys(category=search)|
| 6 | 完成 | recap + 进入 | settings.onboarded=true |

**视觉锁定**(来自 mockup):左轨旅程式进度(done=✓ / active=accent 光圈 / 连接线);暖色舞台 + 淡 "F";provider 网格可滚动 + 底部渐隐;主题色用色块(无文字);完成步 recap 居中。
**文案 toB**:主题色 / 配置模型 / 配置 API Key / 创建工作空间 / 设置完成 —— 去幼稚词。

## 5. 自动识别 + 实时(实施硬要求)

- **明暗自动**:`theme` 默认 `"system"`;`resolveTheme` 读 `prefers-color-scheme`(已工作)。外观步"主题"默认高亮"跟随系统"。
- **语言自动(新)**:首次启动 `lang` 默认**读 `navigator.language`**(`zh*` → `zh`,否则 `en`)。整个引导从第 1 屏起按该语言渲染。改 `settings.js` 的默认值计算(仅首次、无持久化时)。
- **主题色实时**:外观步点色 → `applyTheme({ ...settings, accent })` 立即生效(已有机制,沿用)。
- **Wails**:`navigator.language` + `matchMedia('(prefers-color-scheme: dark)')` 在系统 webview 原生可用,桌面包无障碍。

## 6. 双语引导(scoped i18n)

- 引导 6 屏文案存 **zh / en 两份**(一个 onboarding-strings 模块,按 `settings.lang` 取),引导按检测语言渲染。
- **全 app i18n = 未来单独模块**;本次只双语引导(短期"引导双语、其余中文"可接受,用户已确认)。

## 7. 模型选择流程(修 `modelsFound[0]` 瞎猜)

```
选 provider → 填 API Key → POST /api-keys → POST /api-keys/{id}:test(返 modelsFound)
  → 「模型」下拉用 modelsFound 填充,默认选推荐项
  → 继续 → POST /model-configs { scenario:"chat", provider, modelId:选中值 }
```

- test **返** models 的(deepseek/openai/qwen…):下拉列真实列表。
- test **不返** models 的(如 anthropic):用 curated 默认列表(沿用现有 `PROVIDER_DEFAULT_MODEL` 思路,值必须真实可用)。
- 只配 **chat** 场景;其它场景(autoTitle 等)默认复用 chat,设置里单独改 —— 不在引导堆场景矩阵。
- **核心改动:模型对用户可见可改。** 下拉默认选第一个 / 推荐项,但用户能看到并切换 —— 不再像现在那样 test 后**静默**取 `modelsFound[0]` 直接写库(用户没参与,配错了也不知道,就是 `deepseek-v4-flash` 那个 bug)。

## 8. 搜索(可选)+ 承接

- 第 5 步:选搜索服务商(`category=search`:博查 / Brave / Serper / Tavily)+ key → POST /api-keys。**可跳过**(跳过按钮显式)。
- **承接(任何没配的能力)**:
  - 设置 `ConfigPane`(API Keys / Model tab)随时补配 —— 已存在。
  - agent 用 WebSearch 但无搜索 key → tool_result 返**可操作提示**("配置搜索 API 即可联网 → 设置")。
  - 无 chat model → `NoModelGate` 已引导(本次不动)。

## 9. 后端交互(全已存在,本次**不改后端**)

- `/users`(create,exempt)· `/providers`(list,exempt;含 `category` llm/search)· `/api-keys`(create + `:test` → `modelsFound`)· `/model-configs`(写 chat)。
- 唯一可能的后端补充:搜索 tool 的"无 key → 可操作提示"承接(若现状不够友好,作为小改;否则纯前端)。

## 10. 错误处理

- 引导各步后端写入失败 → toast + 停在该步(不前进、不丢已填)。
- 模型 `:test` 失败 → 保留 key,不写 model-config + 提示;`NoModelGate` 后续接力。
- 搜索可跳过;配置失败不阻断完成。
- `booting` 期 /users 失败 → 重试 + 友好 booting 占位,不闪 AppShell。

## 11. 测试

- **状态机**:booting/onboarding/ready 转换;**脏 id → 不挂 AppShell + 自愈到有效 user + 无 user-scoped 请求发出**(query gate 生效);ready 后无抖动。
- **引导**:6 步流转;语言检测(mock `navigator.language` = en → 引导英文 / zh → 中文);主题色点击实时 applyTheme;模型选择(test → 填充列表 → 选 → 写 model-config 用选中值,非 [0]);搜索跳过 + 配置两条路。
- **承接**:无搜索 key 时 WebSearch 的提示文案。
- 前端 `npm run build` + vitest 全绿。

## 12. 不做 / Out of scope

- **全 app i18n**(未来单独模块);本次只双语引导。
- **后端 endpoint 改动**(全部已存在)。
- **多工作空间管理 UI**(引导只建第一个 workspace;切换/新增在设置,已存在)。

## 13. 文档同步(§S14 / F1)

- `frontend-prd.md`:onboarding 章节重写(6 步 + 就绪状态机 + 语言/明暗检测 + 模型选择 + 搜索);§16 记录修过的相关项。
- `DESIGN.md`:split「舞台 + 步骤」若成为新约定 → §11 补;问候/文案 toB 化原则若需 → 对应章。
- `progress-record.md`:dev log(401 根因 + 状态机 + 引导重做 + 检测)。

## 14. 待你拍板(spec review gate)

1. **双语只覆盖引导**,全 app i18n 留以后 —— 确认?(你已选 A)
2. **模型只配 chat 场景**,其它复用 + 设置改 —— 确认?
3. **搜索作为可跳过的第 5 步** —— 确认?
4. 状态机收敛进 App.jsx 一个 readiness 选择器(而非新建大文件)—— 同意这个落点?
