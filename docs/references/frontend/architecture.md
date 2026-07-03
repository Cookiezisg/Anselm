---
id: DOC-044
type: reference
status: active
owner: @weilin
created: 2026-06-22
reviewed: 2026-06-22
review-due: 2026-09-22
audience: [human, ai]
---

# 前端架构 —— Flutter 桌面端的物理结构（重建中）

> 前端已从 0 重建（见 git：`frontend-rebuild` 分支）。本篇是重建的**第 0 篇**:分层、文件住哪、纪律。
> 决策依据 [`ADR 0004`](../../decisions/0004-frontend-flutter-architecture.md)；工程规范见 [`CLAUDE.md`](../../../CLAUDE.md) 前端守则 + 设计原则。设计系统 / 契约 / SSE / shell 各篇随对应代码落地后填充。

## 1. 一句话

Go 后端作 **sidecar**,Flutter 桌面端是其纯客户端。**3-tier feature-first**:`core`(跨切共享)→ `features`(各域)→ `app`(装配根 + shell)。**无 use-case/domain 层**——Go 二进制即用例,DTO 都是后端投影。

## 2. 物理结构（`frontend/lib/`，当前 = 视觉地基 + 运行时骨干 [Phase 4.0 STEP 0–7 已落]）

```
main.dart                  # 入口:runZonedGuarded(binding 在内)→ scaled binding → installErrorHandlers → initWindow → 恢复缩放档 → runApp(ProviderScope(overrides:[goRouter←buildAppRouter], AnApp))
app/                       # 装配根
  app.dart                 # 根 widget(MaterialApp.router[routerConfig=goRouter] + 主题 + builder=AnOverlayHost→门控链[AppStartupGate→缩放快捷键→autofocus→WorkspaceGate→路由 child];绑 Cmd +/-/0)
  router.dart              # buildAppRouter[STEP 6]:两 location(/ + /entities/:kind/:id)共用同一常量 key 的 NoTransitionPage(AppShell)→壳永不重挂;坏 kind redirect 回首页;注入 core goRouterProvider 缝
  app_shell.dart           # 唯一壳组合 AppShell(哪个 feature 在哪个岛):make app 与 make demo 共用,只差数据源 + 启动(见 §6)
  app_startup_gate.dart    # 据 backend 单一 phase 门控:连接中 / 崩溃可重试 / 就绪显壳(整 app 单点门控,在 MaterialApp.router builder 里包路由 child、非 redirect)
  workspace_gate.dart      # 冷启动工作区门控(在 startup gate 之下、壳之上):解析 workspace 中显"准备工作区",就绪显壳
  gate_backdrop.dart       # 两道门控(startup + workspace)共用的满屏 canvas 底(GateBackdrop),内层 AnState 自居中/限宽
  window_setup.dart        # 桌面窗口:window_manager(尺寸/最小/居中 + hidden-at-launch:原生 order 钩子隐藏、show() 一次性显示、无启动闪烁)+ macos_window_utils(无边框 + 加高标题栏红绿灯)
core/                      # 跨切共享层(不依赖上层)
  runtime.dart             # DI 装配:activeWorkspace(+ activeWorkspaceName 底栏显示名)+ backendController/Startup(BackendState phase 桥) + dio/apiClient + sseGateway(就绪前 null)
  router/                  # 导航缝[STEP 6]:navigation.dart = rootNavigatorKeyProvider(GoRouter↔AnOverlayHost 共享根 navigator key)+ goRouterProvider(throw 默认,app 经 buildAppRouter override 注入;具体 router 认识壳+kind 故只能 app 装配、core 仅声明缝)
  workspace/               # 冷启动:workspace_bootstrap(后端就绪后 列/建 workspace + 设 activeWorkspace,否则全 API 401)
  contract/                # 后端投影 DTO(freezed/json,1:1 镜像后端):api_error(N1 信封 + AnselmErr 码) · page(N4 keyset/聚合) · workspace(+ModelRef) · entities/(Quadrinity ~22 DTO,见 contract.md)
  net/                     # api_client:唯一 HTTP 边界,标准契约只编码一次 + workspace/bearer(ANSELM_AUTH_TOKEN)拦截器
  sse/                     # 3 流地基:frame(线缆 + seq 派生 durable) · sse_parser · sse_connection(重连 + 410 续传 + full-jitter + bearer) · sse_gateway(per-scope/per-kind demux,Riverpod 之下)
  process/                 # backend_controller:sidecar 监督(抢端口 / health 门控 / 有界崩溃重启 / SIGTERM→kill 优雅关停 / 铸 ANSELM_AUTH_TOKEN)
  perf/                    # coalescing_notifier(L2:值同步无损、监听者每帧≤1 通知 —— 流式 firehose 防整页重建) · debouncer(尾沿防抖原语,run/dispose;rail 搜索框逐键防抖)
  state/                   # 框架无关 Riverpod 状态原语:bool_pref(BoolPrefNotifier:单 bool UI 偏好,toggle/set) · keyset_paging(两 mixin:KeysetQueryPaging=query-reset epoch 守卫[实体/对话 rail] · KeysetScopedPaging=autoDispose ref.mounted 守卫[版本/日志详情 tab])
  error/                   # error_boundary:installErrorHandlers(全局错误汇)+ 可恢复 ErrorWidget(构建抛错不灰屏)
  design/                  # tokens · colors · typography · theme —— 唯一值源,禁内联 px/hex/ms
  platform/                # OS 缝:host_platform(dart:io 收口) · window_zoom(应内 Cmd +/- 缩放)
  model/                   # 框架无关纯模型(无 Flutter import):status_state(状态折叠单源)
  messages/                # 框架无关纯模型:block_tree_reducer(折 open/delta/close→嵌套块树;run 终端 + Chat 4.2 共用,脱 widget 单测)
  graph/                   # 框架无关纯模型:graph_model(图→定位几何)+ graph_run_state(节点行→运行覆层)+ flowrun_timeline(节点行→甘特时段);全脱 widget 单测
  contract/messages/       # block_content(BlockKind 6 sealed + Text/ToolCall/ToolResult/Message Content,run 轨迹 / messages 块投影)
  ui/                      # An* 套件 G0–G6(49 原语:控件/行卡/导航壳/代码数据/浮层)+ 三岛壳;桶=ui.dart(见 design-system.md)
  overlay/                 # 命令式浮层派发(G6):AnOverlayController(NotifierProvider) + overlayProvider + AnOverlayHost
i18n/                      # slang:en/zh_CN 双语 + 生成 strings.g.dart（dart run slang,入库）
dev/                       # dev 工具:gallery_main（make gallery 组件画廊）· demo_main（make demo:真壳 AppShell + fixture override + 跳门控,零后端）
features/                  # ★中间层:每域 data+state+ui+model（随 feature 落地,Entities 起）
  entities/data/           # Entities feature 数据缝[Phase 4.1 STEP 1]:单一 EntityRepository(Live 接 ApiClient+SseGateway / Fixture 内存可脚本 / entityRepositoryProvider 单点 override) + EntityKind/EntityRow/EntitySignal + entity_labels(EntityKindLabels 扩展:type/verb i18n 标签唯一源,rail·海洋头·run 终端共用)
  entities/state/          # Entities 列表 state[STEP 2]:entityListProvider(首页 + loadMore via KeysetQueryPaging mixin + SSE patch) + railModelProvider + selectedEntityProvider(STEP 6 改:只读、单向派生自路由 delegate) + railSortProvider(最近活跃/最近创建/名称,与 chat rail 对齐) + railShowCountProvider(⚙ 显示分组计数)
  entities/state/detail/   # 详情 state[STEP 4]:entityDetail(双流订阅,durable 重取/ephemeral no-op) + versionList + logList(PageWithAggregate+workflow flowrun 懒取;分页 via KeysetScopedPaging mixin);全 autoDispose(离开实体释放 notifier+SSE 订阅,async 写前 ref.mounted 守卫;STEP 6 收口)
  entities/state/run/      # 运行 state[STEP 5]:run_terminal_controller(草稿→请求强转 + 流帧)+ run_fields(runInputFields/runMethods:表单渲染与 controller 强转的唯一字段源,防渲染≠强转的静默丢参)
  entities/ui/             # Entities UI[STEP 3]:EntityRail over AnSidebarList(4 kind 段 + 状态点;四态 via 共享 AnRailStates,布尔为 4-kind 聚合;首载 AnRailSkeleton + Debouncer 搜索)+ entity_rail_model(纯投影)+ entity_ocean[STEP 4 详情根]
  entities/ui/detail/      # 详情 UI[STEP 4]:EntityOcean=单一 AnPage 文档(头+tab+内容居中 720 一起滚,AnTabs flow)+ ocean_header(状态徽 + 动词 CTA)+ overview/{4 kind}(workflow 图推迟图编辑器阶段)+ version_tab(AnVersionDiff)+ log_tab + detail_sections + entity_ocean(详情海洋,STEP 3 占位/STEP 4 建)
  entities/data/entity_demo_fixture.dart  # demoEntityRepository():make demo 的零后端种子(STEP 4/5 续加版本/日志/flowrun)
```
**运行时骨干(Phase 4.0)**:sidecar 进程托管(`core/process`)+ 契约/net/SSE(`core/{contract,net,sse}`,PORT 自 main + 加固)+ Riverpod 装配(`core/runtime.dart`)+ 错误边界(`core/error`)+ 启动门控(`app/app_startup_gate.dart`)+ L0–L2 流式性能原语(`core/sse` demux + `core/perf` coalescer)。loopback 安全在后端(绑 127.0.0.1 + bearer + Host 校验,见 `references/backend/api.md`)。建造规范见 [`WRK-045`](../../archive/phase-4.0-runtime-backbone/README.md)。
**dev 工具**:截图夹具 `test/dev/capture_shell.dart` + `capture_demo.dart`(无头渲染 PNG;STEP 6 起预选 = deep-link 导航,非 provider override)+ 真跑 `test/dev/shot_app_real.sh`(真后端端到端);产物 `test/dev/out/` **gitignore**。**测试支撑**(`test/support/`):`router_harness`(路由化 widget 测:测试 GoRouter 镜像 app 两 location、`routedHost` 注入 goRouter+repository 缝)+ `five_batteries`(五电池矩阵 空/超长/海量/极值/注入,STEP 6 加固)。

## 3. 依赖规则（三层，单向）

`app → features → core`。**features 互不依赖**(跨片走 core provider / 导航 intent);`core` 不依赖上层。UI 只用 `core/ui` + `core/design` 组合,**禁内联配色/度量**。

**路由(go_router,STEP 6)**:`MaterialApp.router(routerConfig=goRouterProvider)`。两 location `/`(无选区)与 `/entities/:kind/:id` **共用同一常量 key 的 `NoTransitionPage(AppShell)`** → Navigator 复用同一 Element → 三岛壳(rail/ocean/keepAlive run 终端/滚动位)**永不重挂**;选区由 `selectedEntityProvider` **单向派生**(监听 router delegate[`ChangeNotifier`]解析 URL→`EntityRef`,`ref.onDispose` 摘监听),rail 点击 = `context.go(entityLocation(...))`(rail 不 import ocean/inspector,只改 URL),ocean/inspector/detail 照旧 `ref.watch(selectedEntityProvider)` 零改动;deleted 信号 = `goRouter.go('/')` 清选区。坏 `:kind`(非四者)在 `/entities/:kind/:id` 的 **route-level redirect** 回首页(URL 大小写敏感天然强制小写枚举);`:id` 存在性路由层管不了→ ocean 错误态。**门控是 `MaterialApp.router(builder:)` 里包路由 child 的 widget(非 redirect)**:`AnOverlayHost → AppStartupGate → 缩放快捷键 → autofocus → WorkspaceGate → child`。builder 的 `child` 即 `Router` widget——门控扣住它时 Router 未挂载,门控开启时 Router 挂载并解析待决/初始路由(deep-link 仍正确落地、只是在门控开启时);门控须在 MaterialApp.router 内(非外裹)使路由配置开机即接上。未匹配路径经 `errorPageBuilder=同一常量页` 回壳(不触发会重挂壳的默认错误屏)。

**命令式浮层派发(G6,跨 feature 共享的命令式 UI 副作用)**:dialog/toast 经 `core/overlay` 的 **`overlayProvider`**(经典 **`NotifierProvider`**,非 legacy `ChangeNotifierProvider`)派发——feature 在 SSE/async 回调里**无 BuildContext** 也能 `ref.read(overlayProvider.notifier).showToast(...)` / `confirm(...)→Future<bool>`(后者经装配根 `AnOverlayHost`[挂在 `MaterialApp.router` 的 `builder`]在 `initState` 注册的 **root navigator key** push `RawDialogRoute`)。STEP 6 起该 key = `rootNavigatorKeyProvider`,**由 `GoRouter(navigatorKey:)` 与 `AnOverlayHost(navigatorKey:)` 两端共享**(go_router 持 root navigator;`MaterialApp.router` 无 `navigatorKey` 参数,key 不传给它)。这是「跨 feature 走 core provider」在命令式副作用上的落地——**非**全局 `navigatorKey` 单例(app 建 key + widget 树注入 host + ref 接入 controller、可 override 测、合 [`ADR 0004`](../../decisions/0004-frontend-flutter-architecture.md))。toast 层渲在内容之上(z 序偏离已拍板,详见 design-system.md)。完整建造规范见 [`WRK-041`](../../archive/g6-overlays/README.md)。

## 4. 设计系统 + UI 套件（`core/design` + `core/ui`）

- 令牌(`core/design`,单一值源):`tokens.dart`(`AnSpace`/`AnRadius`/`AnSize`/`AnMotion`)· `colors.dart`(`AnColors` ThemeExtension,明暗双值 + lerp,镜像 demo `tokens.css`)· `typography.dart`(`AnText`)· `theme.dart`(`ThemeData`)。
- **中性 chrome + toB 蓝 accent + 功能色**:`accent`=蓝(demo `#0071e3`,主动作/选中/run 显蓝);状态语义 ok/warn/danger。
- **字体**:UI=**随包 MiSans VF**(wght 150–700,Latin+简中、全平台同字面),**渲染压细**(正文 Light w300);代码=**JetBrains Mono**(随包)。详见 [`design-system.md`](design-system.md)。
- **套件 + i18n**:An\* 组件 + 图标(Lucide)/品牌图/状态折叠/交互基座 + slang i18n —— 详见 [`design-system.md`](design-system.md)(随套件逐组填充)。

## 5. 三岛 shell 骨架（`core/ui/an_shell.dart`）

无边框**不透明白窗**:左岛(`AnIsland` 卡,**弹性 240–400 默认 320、可拖 + 可收起**)· 敞开海洋(窗体白面、无卡,内容列**弹性 480–720**)· 右岛(`AnIsland` 卡,**固定 320**);四周 8px + 岛间 8px(左岛 grip 兼间距、右岛纯间距)。**状态由 app 持有、props 喂入,`AnShell` 不沾 Riverpod**(`shellChromeProvider` 左收起/宽度[持久化,demo 键 `fy.side.collapsed/w`]· `shellHeadProvider` 浮层头面包屑 · `rightPanelCollapsedProvider` 右收起 · `selectedOceanProvider`/`notificationsOpenProvider` 左岛两轴 · `activeWorkspaceNameProvider` 底栏名)。
  - **左岛内容(`app_shell.dart` 装配,自上而下,均 gallery-first 的 kit 原语)**:chrome bar(红绿灯 + 收起钮)→ **海洋切换器 `AnOceanSwitcher`**(顶部 4 海洋 chat/entities/scheduler/documents 图标钮,选中展开标签;**matched-geometry 滑动药丸**[单药丸滑动+变宽、旧收新展、整行回流,无水珠收颈];`selectedIndex=-1` 无选中态;横滚不裁)→ **中段**(当前海洋的 rail,或铃开时换成通知托盘)→ **底栏 `AnSidebarFooter`**(`AnWorkspaceButton` workspace 快捷菜单[`AnMenu matchAnchorWidth` 与钮等宽下拉:切换/新建/工作区设置] | 设置格 | 通知格[红点])。**左岛两条独立轴**:① **选中海洋** `selectedOceanProvider`(顶部 4 + 齿轮进的 `settings`,驱动 rail + 中心;在 settings 时顶部切换器无选中、齿轮高亮)② **通知托盘** `notificationsOpenProvider`(正交,铃 toggle,**接管左岛中段 rail、不动中心**;**点任一海洋[顶部 4 或齿轮]即收起**)。**仅 `entities` 已建**(真 EntityRail/EntityOcean),其余海洋 + 通知托盘 = 「即将推出」占位;workspace 名经 `activeWorkspaceNameProvider`(冷启动 bootstrap 设、底栏显,空回退默认标签)。**海洋切换暂走 provider(未路由化,后续并入 go_router)**。
  - **左岛收起**:顶栏 chrome bar 的收起钮(panel-left)→ `_LeftReveal` 整岛 + 间距 0↔width 滑走(OverflowBox 保满宽不重排、仅滑动中裁、reduced 即时);收起后 reopen 钮迁到海洋浮层头。grip 拖本地宽、松手 `onLeftWidthCommitted` 提交持久化。
  - **海洋浮层头**(`_OceanRegion` 内 `Stack`):top 0 的 44px 透明带 + 渐隐 scrim(island→透明,IgnorePointer、正文从其下滚过、仅角落可点);左→右 = reopen(仅左收起时)· **面包屑 `OceanBreadcrumb`**(大标题滚到头下时淡入、点击回顶,`Expanded+Align` 占中、把右钮顶到最右)· panel-right(仅有选中右岛时)。面包屑折叠由 `EntityOcean` 的 `ScrollController` 据测得大头高算阈值 → `shellHeadProvider.setCollapsed`(只重建浮层头、不动正文)。
  - **右岛按需揭示**——`inspectorOpen` 驱动 `_RightReveal`(0↔320 滑入/滑走,内容满宽不重排,reduced 即时,收起态彻底惰化)。Entities feature 把 run 终端放右岛、**强链选中实体**(`RunTerminal` 自读 `selectedEntityProvider`、`runTerminalProvider` **autoDispose** family by EntityRef、随选区重绑;动词 CTA 直接执行、close 钮 sticky 收起;选中未运行离开即释放[防泄漏]、运行起 `keepAlive` 钉住后台续流、收尾释放)。
  - **顶控对齐红绿灯**:顶控(收起钮/面包屑/右切换,均 md 尺寸=rail 搜索图标)中心经 `_controlInset = titlebar/2 - shellPad - control/2` 落到红绿灯水平线——灯在 `AnSize.titlebar`(52,= macos_ui `_kToolbarHeight`)带居中(灯心 logical 26),`AnIsland` 左岛去顶 pad 使 chrome 抵岛顶。**真机迭代纠正**(调研 wf `w2ah4v0ll`):`WindowManipulator.getTitlebarHeight()` 返整 title+toolbar 带(~66)、偏低(33)——灯只在 52 标题栏段居中(26),故用验证常量、不用运行时查询(#8 + verify-by-real-run)。红绿灯仍 `macos_window_utils` OS 画(不抄假点);**左岛收起后** `_OceanRegion` 在 reopen 前置 `AnWindowControls`(留 72 灯位)→ reopen 落红绿灯之后。⌘B 切左岛 / ⌘\ 切右岛(`app_shell.dart` `CallbackShortcuts`,meta+control 双绑;app.dart autofocus 锚使开机即生效)。
- **尺寸(逻辑点,`window_manager` 管 → scale 正确、resize 不炸)**:**最小** = 保证即便左岛拖到 max、海洋仍有最小内容列 `内距 + 左岛max(400) + 间距 + 海洋min(480) + 间距 + 右岛(320) + 内距` = **1232×761**(黄金比例高)。**默认** ≈ 1280×791(居中、1512 屏上留余量)。海洋是弹性区,内容列在 480–720 间随窗伸缩(更宽则 720 居中)。
- **红绿灯**:macOS 由 `macos_window_utils`(成熟包)**加高标题栏**(`addToolbar` + unified 风格)→ OS 把灯纵向居中到更低位、**仍在可点击的标题栏层**(Apple 旗舰做法)。**绝不**把原生按钮挪进内容区(会被全尺寸内容视图吃掉点击)、**绝不手搓**(见设计原则 #8)。Windows/Linux 此位放产品标 + 名(`AnWindowControls`)。
- **缩放(两种,别混)**:① **系统显示档**(设置→显示器)——全用**逻辑点**即自动适配,无需特殊处理;② **应内 Cmd +/-/0**(`core/platform/window_zoom.dart`)——用 `scaled_app`(`ScaledWidgetsFlutterBinding` 重写视图配置)**整体重排式**缩放(非 Transform/textScaler),默认 100%、离散档持久化,变更时窗口最小值同步 ×zoom。**zoom-in 受屏幕容量管控**(`maxFactor` = 屏可容 / 设计min,逐轴取小):到顶即停、**绝不撑破布局**;持久化档恢复时也按当前屏可容上限收敛。**不手搓**(原则 #8)。

## 6. 工具链与门禁

- 工具链 = **mise**(go + flutter,仓库根 `mise.toml`)。
- **三个启动面(规范,永不增 per-feature 入口)**:
  - `make gallery` — 组件画廊(`lib/dev/gallery_main.dart`):看每个 An* 原语全态。**视觉**面,与 app/demo 正交。
  - `make app` — 真 app(`lib/main.dart`):**真壳 + 真后端**,热重载(`test/dev/run_app.sh`:自动起后端[`make server`,后台常驻,`make stop` 关]+ dev-attach `ANSELM_BACKEND_URL`)。**生产的 spawn-打包-sidecar 路径**(发行版的 .app 自带签名 Go 二进制、无需 `make server`)是发行阶段任务(WRK-043);裸 `flutter run` 会走 spawn → 找不到未打包的二进制而崩,故 dev 走 attach。
  - `make demo` — 真 app 壳 + **假数据**(`lib/dev/demo_main.dart`):看真实形态、零后端。
  - **铁律:app 与 demo 共用唯一壳组合 [`app/app_shell.dart`](`AppShell`)**——哪个 feature 在哪个岛只写一次。二者**只差两点**:① 数据源(app 接 Live repository / demo 用 `ProviderScope` override 成 fixture,见 `features/*/data/*_demo_fixture.dart`)② 启动(app 走 `AppStartupGate` 等后端 / demo 跳门控直接进壳)。**新 feature 接进 `AppShell` 一次,app 与 demo 同时拥有**——**绝不为单个 feature 加 `make <feature>` 入口**(碎片化、必不 sync)。截图同理:`test/dev/capture_demo.dart` 截整 `AppShell`,不做 per-feature 截图。
- 门禁 `make fe-verify`(= `cd frontend && make verify`)= codegen(`dart run slang` + `dart run build_runner`)+ `flutter analyze` 净 + `flutter test` 绿。codegen 产物入库(deterministic,fresh checkout 直接 analyze)。

## 7. 文档纪律

`references/frontend/` 随骨架 / feature **同提交**重写填充,与代码逐字同步(CLAUDE.md #9)。
