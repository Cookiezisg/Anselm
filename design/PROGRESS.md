# Foryx Design — 进度 / 背景 / 续接手册

> **开新对话先读这份 + [`SPEC.md`](SPEC.md),就有全部上下文,能直接续。**
> 本文 = 任务背景 + 关键决策 + 进度日志 + 当前状态 + 下一步 + 操作/续接须知。
> `SPEC.md` = 规范本身(宪法);本文 = "我们在哪、怎么到这、怎么继续"。

---

## 0. 一句话

把 `demo/`(旧名 Forgify 的形态草图)**干净重写**成 `design/`(新名 **Foryx**),核心是补上 demo 缺的那层——**统一布局语法 + 强制原语**,让"对齐/密度/排版"由模版结构保证、**漂移不可能**。

---

## 1. 任务背景

- **产品 = Foryx**(本地优先 agentic workflow 桌面 app,Flutter 目标 + Go sidecar)。改名自 Forgify;**`demo/` 仍叫 Forgify、维持不动;一切新代码(`design/`)用 Foryx**。
- **`demo/`** = 大骨架很好(海洋+三岛+六契约+Intent/Live+组件库),但**缺统一布局语法**:行高/间距/字阶/页骨架/交互全靠各海洋手搓 → 纷繁、必漂(同一种"行"写 5 遍、`sec/foldSec` 写 3 遍、行高 32/34 间距 4/5/8/9/11/15 乱飘、上帝组件 EntityCard 410 行、无数据 schema、`--cc-*` 遗留)。一次 12-agent 全量审计证实(THEME A 无布局语法 / B 同 UI 手搓 N 遍 / C 上帝组件 / D 无 schema / E 外壳生命周期洞)。
- **`design/`** = 在 demo 的好骨架**之上**新增第 7 层(布局语法),不是架构重写。心法 = **三件套**:文档(解释,SPEC)+ token(唯一值源,tokens.css)+ **原语(强制层,primitives/)**。「一致性 = 约束的副产品;规范的力量在拒绝什么,不在能表达什么」。

## 2. 用户拍板的关键决策

1. `design/` = **干净重写**(不在 demo 上打补丁;demo 留作参照)。
2. **选择性"万物皆文档"**:记录/列表/表单型面走统一语法;**运行图 / 编辑器画布走逃生舱**(自定义,但吃同套 token + 活在标准页骨架)。
3. **同时声明数据 schema**(KIND_SCHEMA/BEAT_SCHEMA,杀 if 级联)。
4. **单一规范密度**(由我定)。
5. **大骨架保留**,但设计时**狂优化**地基洞。

### 数系(三层数学,已定稿,详见 SPEC §2、可视化 tokens-preview.html)
- **密度阶梯 = 纯 2 的幂**:grid 4 · gap 8 · icon/lead 16 · row 32(2²·2³·2⁴·2⁵)。
- **布局 = 谐波 2:3:6**(音乐比例,u=120):侧栏 240(2u)· 右岛 360(3u)· 内容 720(6u);1440 窗 = 12u。读宽=对话宽统一 `--w-content` 720,宽块走 full-bleed 逃生。
- **字阶 = 模数**(≈大三度;display 16/20/24/32 落 4 网格);body 13 是锚、不入 2 幂;meta 12 是 UI 下限;角色命名 `--t-meta/body/strong/h3/h2/h1`。
- 圆角 4/8/12/16/20;`--cc-*` 全废。值经 **10 源行业实测**锚定(Foryx = Linear + macOS 紧凑桌面线;Notion/Primer/Material 偏宽是 web/触摸/读重,不照抄)。
- **密度路线(13px)不为纯度牺牲信息密度——数学放进关系,不强求每数是 2 幂。**

### 🔒 对齐铁律(模版化,错位结构上不可能)
- **行 = 三列网格** `grid-template-columns: var(--lead) 1fr auto`(行首固定列 / 标签 / 尾槽),**绝不靠 padding/width 手量对齐**。
- **行首槽 + 尾槽都"叠放同一格、`place-self:center`"**:① 行首 7px 点与 16px 图标**同心**;② 尾槽 meta 与动作共用中心 → hover swap 绕**光学中心**切换、**不平移**(实测 Δ=0)。
- **图标墨迹画在居中艺术板**(光学中心 ≈ 12,12),与点同心。
- **分组标签走邻近原则**(上 `sp-2` 分隔 / 下 `sp-1` 贴附)。
- 实测:同级 leading-center 与 label-left 像素相等。(SPEC §4 有此铁律全文)

### 其他既定规约
- hover 显隐/同槽互换 = **0ms 即时**(不入 transition):更脆 + 避开无头渲染器"未完成过渡冻初值"坑。
- 字色铁律:列表项默认 `--ink-2` 灰,hover/选中才 `--ink` 黑;meta `--ink-3`;accent 只落 主CTA/实时/选中点。
- 双语:打包 MiSans(一族覆盖中英)+ **永远显式 line-height**。

## 3. 进度日志(本轮提交,新→旧读也行)

| 阶段 | 内容 |
|---|---|
| **Phase 0** | `SPEC.md`(宪法 8 节)+ `README.md`;数值经 10 源行业实测锚定 |
| **数系定稿** | `core/tokens.css`(唯一值源,每值带数学注释)+ `tokens-preview.html`(可视化) |
| **Phase 1 起步** | 管线 `reset/cssload/dom(单一 esc)/icons(单一 stroke)` + 原语 Button/StatusDot/Row/Section + `reference.html` 活体规格台 |
| **对齐模版化** | Row 改三列网格 + 行首叠放居中;新增 **SidebarList**;图标重画居中(修点/图标/New/Search 错位,实测同级 x 相等) |
| **Phase 1 续** | Field/KV · Input · Badge · Tabs |
| **swap+间距修** | 尾槽叠放居中(swap 绕光学中心,Δ=0)+ 分组间距邻近原则 |
| **Phase 1 收官 + Phase 2 样板** | 页骨架 OceanHeader/Page/RightIsland + **`entity.html`**(三岛外壳 240/720/360 + 全程原语拼装的实体页) |

## 4. 当前状态(已落 + 已验证)

**原语成套**(`core/primitives/`,`fy-` 前缀,自载 CSS,只读 token,`html()`+`mount()` 契约):
`Button(4 变体) · StatusDot(5 态) · Row(核心) · SidebarList · Section · Field/KV · Input · Badge · Tabs · OceanHeader · Page · RightIsland`。

**目录**:
```
design/
├── README.md · SPEC.md · PROGRESS.md      # 规范 + 本文
├── tokens-preview.html                     # 数系可视化
├── reference.html                          # 原语活体规格台(showcase)
├── entity.html                             # Phase 2 样板:全原语拼的实体页
└── core/
    ├── tokens.css                          # 唯一值源(数学注释)
    ├── reset.css cssload.js dom.js icons.js
    └── primitives/  *.js + *.css(13 个原语)
```

**验证手段(每步都做)**:预览渲染 + **测量对齐**(同级 leading-center / label-left 像素相等;swap metaCenter==actsCenter)+ 截图 + 0 console 错误。
- entity.html 实测:三岛宽全 = token(240/720/360)、5 段 4 字段 4 tab、近零 bespoke CSS(仅代码块本地皮)、0 错误。

## 5. 下一步(Phase 1 尾 + Phase 2/3/4)

- **补原语**:Menu/Floating(弹层,SidebarList 排序菜单要它)· CodeEditor(代码块,现 entity.html 用本地皮顶着)· Toolbar/ActionGroup。
- **补地基洞**(SPEC §7):Shell `onUnmount` 生命周期钩子(替代 chat runId 补丁)· `headExtra`→OceanHeader 已做 · 右岛 oceanId=feature id · 公共件抽核(diff/syntaxTokenize/动画)。
- **数据 schema**(SPEC §5):`mock/*_schema.js` + KIND_SCHEMA/BEAT_SCHEMA,实体页改 schema 驱动渲染。
- **Phase 3 铺其余海洋**:对话流(块流)· **运行图(逃生舱:自定义但吃 token)** · 文档(编辑器逃生舱)· 设置 · 通知。
- **Phase 4**:布局语法进 `contracts.md` 第 7 契约 + 绑 Flutter(token→ThemeExtension,原语解剖→Widget)。

## 6. 操作 / 续接须知(重要)

**预览**(`design/` 静态页,无后端):
- `.claude/launch.json` 已加 `design` server(端口 **4191**,no-cache;该文件 gitignored)。
- 起:`preview_start name=design` → 开 `/entity.html`(样板)、`/reference.html`(原语台)、`/tokens-preview.html`(数系)。

**无头渲染器两个坑(踩过)**:
1. **过渡冻结**:未完成的 `opacity/color/width/transform` 过渡会冻在起点 → 默认态错乱。**对策**:凡"默认态须正确渲染"的属性不进 transition;hover 揭示一律即时。
2. **视口会塌成 1px**:eval 量布局偶尔得到全 0 宽(`innerWidth:1`)→ 不是 CSS bug。**对策**:量之前 `preview_resize 1440 900`。截图渲染正常、不受影响。
- 截图工具有时把视口钉在某区域;要看下方内容,可临时把目标卡 `insertBefore` 提到 `.wrap` 顶部再截。

**工程纪律(本仓约定)**:
- 中文回复;代码/路径/英文 commit 半句保持原样。
- commit **不加** `Co-Authored-By: Claude` 尾注。
- **每次 commit 后立刻 push origin/main**(投资人可见)。
- **只在 main 开发、不开分支**;用精确 `git add design/` 隔离(别 `git add -A`)。
- `demo/` 是别人的域 + 维持 Forgify 不动;`design/` 是本工作区、用 Foryx。
- 改 token 一处、全系统跟着变(零成本);改原语 = 改 `core/primitives/<x>.{js,css}`。

**心法复诵**:文档解释、token 定值、**原语强制**;对齐/密度**靠模版结构、不靠手量**;能用原语拼就别写自有 CSS。
