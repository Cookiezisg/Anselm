---
id: WRK-060
type: working
status: archived
owner: @weilin
created: 2026-07-07
reviewed: 2026-07-08
review-due: 2026-10-05
audience: [human, ai]
landed-into: references/frontend/features/documents.md, references/frontend/design-system.md
---

# 文档编辑器完整重做 —— 建造规范(Milkdown-in-webview,已废弃归档)

> ⚰️ **2026-07-08 归档**:本页记录的 Milkdown-in-webview 线(A0–A6,曾全量落地)已被**原生 super_editor 编辑器**(`lib/core/editor/`,E0–E9 线)整体取代并**删尽死码**(`lib/core/doc_editor/`+`tool/doc-editor/`+`assets/editor/doc_editor.html`+Makefile 目标+webview_flutter 依赖)。pivot 理由:webview 只能 CSS 近似 An 原语、永远达不到逐像素 1:1,且中文 IME 在 WKWebView 是高危路径——原生 super_editor 把每块渲成真 Flutter widget、IME 走 Flutter 自身管线。当前形态见 [`features/documents.md`](../../references/frontend/features/documents.md)。本页仅存 webview 线的建造史(§1 后端契约与 §2 复用地图对原生线仍有参考价值)。
>
> **2026-07-07 拍板方向**(原文):现有 `AnDocEditor`(super_editor 0.3.0-dev.40,1378 行)bug 巨多(点两下卡死)+ 视觉不达标,**整块删了重做**。spike 已验证 **Milkdown-in-webview** 这条路(WYSIWYG 渲染 ✅ + round-trip 保真 ✅ + 窗口/加载 ✅;中文 IME 待真机终验)。本页 = A0 调研(6-agent 扇出)综合出的建造规范 + A1–A6 建造顺序。建造账落 [`chat.md`](chat.md) 同级;编辑器组件当前形态见 [`design-system.md`](../../references/frontend/design-system.md) 的 `AnDocEditor` 条(已同步为 webview 版)。
>
> **调研全文**:六份 agent 报告存 scratchpad `research/{1-fe-current-documents … 6-spike-inventory-and-design-tokens}.md`。

## 0. 核心结论(动手前必读)

1. **后端零改**。`document.content` 是不透明 markdown 字符串(`TEXT` 列 / Go `string`),后端从不解析成 block 模型;换编辑器一行后端不动。**唯一约束**:`[[id]]` wikilink 必须 round-trip **逐字保真**——后端每次写都重解析 `[[…]]` 维护 `link` 关系边,编辑器若改坏 `[[id]]`,关系边静默断。这是前端序列化保真要求,非后端契约。
2. **拆除面很干净**。全 `lib/` 只 **2 个文件** import super_editor(`core/ui/an_doc_editor.dart` + `_components.dart`)。**`features/documents/` 整层**(data/state/rail/ocean 骨架/inspector/大纲)编辑器无关、只通过 `initialMarkdown:String` 进 + `onChanged:ValueChanged<String>` 出两个 prop 缝对接。`[[id]]` codec、@ mention DIP(`MentionSource`)、大纲提取器(`extractDocOutline`,吃 markdown 字符串)全可复用。
3. **两处硬骨头**(Flutter 侧真正的重做工作):
   - **几何缝**:`document_ocean.dart` 的 `_DocPageChrome` 现在调 `editorKey.currentState.headingOriginsGlobal()`(大纲滚动高亮)+ `headingOriginGlobal(i)`(点大纲跳转)。webview 后这两个几何 API 要**改走 JS 桥**(`getBoundingClientRect` 逐标题 + `scrollIntoView`)。`doc_outline_spy_test.dart` 是契约。
   - **版式**:super_editor 以 **sliver** 渲染,现在页面是 `CustomScrollView`(头 sliver + 编辑器 sliver 同滚)。webview 是 **box**,`buildDocPage` 要重构(见 §4.3 版式决策)。
4. **Crepe(`@milkdown/crepe`)全都能干**——slash 可完全定制+中文化、拖拽把手可单独关、划选气泡工具条可加按钮、CSS 变量+选择器 100% 贴 token、`markdownUpdated` 防抖存。@ 提及靠自定义 inline atom 节点 + `remark-wiki-link`。

## 1. 后端集成契约(code-verified,零改)

- **DTO**(wire camelCase):`id`(`doc_<16hex>`)、`parentId?`、`name`、`description`、`content`(**opaque markdown**)、`tags[]`、`position`、`path`、`sizeBytes`、`createdAt`、`updatedAt`。客户端可写:`name`/`parentId`(create only)/`description`/`content`/`tags`。服务器拥有:`path`/`position`/`sizeBytes`。
- **端点**(`/api/v1/documents`):`GET ?parentId=`(列子,**含 content**,N4 豁免不分页)· `GET /tree`(**不含 content**,N4 豁免)· `POST`(create,名字自动去重)· `GET /{id}`(读全)· `PATCH /{id}`(**存 = `{content}`;重命名 = `{name}`**;partial)· `DELETE /{id}`(级联软删)· `POST /{id}:move`(`{parentId?,position?}`)· `:duplicate` · `:iterate`(AI 编辑开对话)。**无独立 rename/save 端点**。
- **守卫**:content ≤ **1MB**(超 413 `DOCUMENT_CONTENT_TOO_LARGE`)· name ≤256、非空、无 `/`。
- **SSE**:文档生命周期走 **notifications 流**,`document.{created,updated,moved}` = Broadcast(⤳ 仅帧),`document.deleted` = Emit(⊞ 落收件箱)。**无 `document.tree` 事件**,树刷新靠收到任意帧后 refetch `/tree`。payload 带 `path` 非 `name`。**当前 documents feature 尚未订阅任何流**(fetch-on-select),重做可零 SSE 起步,刷新是后续 P5。
- **错误码**:HTTP 客户端只会见到 `DOCUMENT_{NOT_FOUND,INVALID_NAME,NAME_CONFLICT(仅 PATCH rename),CONTENT_TOO_LARGE,INVALID_PARENT,PARENT_NOT_FOUND}`。

## 2. 拆除 + 复用地图

**复用(原样,super_editor 无关)**:`data/document_repository.dart`(数据缝)· `state/document_state.dart`(providers,除 §5 mention 相关一行)· `model/doc_outline.dart`(`extractDocOutline`)· `ui/document_rail_model.dart` + `document_rail.dart`(左岛)· `ui/documents_inspector.dart`(右岛大纲/属性/backlinks)· `core/entity/mention_source.dart` + `app/entity_mention_source.dart`(@ DIP)· `core/ui/an_mention_picker.dart`(`AnMentionPanel`,可复用或 in-webview 重画)· `data/document_fixtures.dart` + demo fixture(注意:fixture 正文含 `[[doc_…]]` + 围栏代码 = round-trip 夹具)。

**重写/删除**:`core/ui/an_doc_editor.dart` + `_components.dart`(→ webview 版)· `core/ui/entity_ref_codec.dart`(`expandEntityRefs`/`collapseEntityRefs` 是 super_editor 的 link 伪装法,mention 走原生节点后可退休;`extractEntityRefIds` 保留)· `document_ocean.dart` 的 `_DocPageChrome`+`buildDocPage`(几何缝 + 版式)· `state` 里 `openDocumentContentProvider`(129–135,mention 原生化后可退休)。

**pubspec**:删 `super_editor 0.3.0-dev.40`、`super_text_layout 0.1.21`(dev)、`markdown 7.3.1`(仅 `_components.dart` 的围栏 converter 用,删后 `flutter pub deps` 验无传递依赖)。留 `webview_flutter`、`gpt_markdown`(chat 用,无关)。

## 3. 编辑器 bundle(Crepe 生产配置)

- **源码入库**:把 spike 的 Vite 工程从 scratchpad **搬进仓库** `frontend/tool/doc-editor/`(checked-in 源 + `make doc-editor` 目标重建 `assets/editor/doc_editor.html`),bundle 可复现、非 scratchpad 弃物。
- **feature 开关**(用户 0707 拍板:**功能全开,后端该补就补**):`CodeMirror`(围栏代码,**离线限定静态语言集**,不用全量 language-data 的动态 import)· `ListItem` · `LinkTooltip` · `Cursor` · `Table`(GFM 表格,开)· `ImageBlock`(**行内图片,开**——见 §3.1 后端图床)· `Latex`(**数学公式,开**——离线把 KaTeX CSS+字体打包成 data-URI 进 bundle)· `BlockEdit`(**`blockHandle.shouldShow:()=>false` 关拖拽把手、保 slash** + `.milkdown-block-handle{display:none}` 兜底)· `Toolbar`(划选气泡)· `Placeholder`。**仅 `TopBar`/`AI` 关**。
- **slash 菜单**(§A2):`featureConfigs.BlockEdit` 声明式重标+中文化内置组(文本:正文/标题1-3/引用/分割线,h4-6 置 null;列表:无序/有序/待办;高级:代码块/表格),`buildMenu(builder)` 加自定义组(如「@ 提及实体」)。图标传我们的 SVG 串。菜单按 label 过滤 → 中文可搜。
- **划选气泡工具条**(§A3):`featureConfigs.Toolbar` 换我们图标(粗/斜/删除线/码/链接),`buildToolbar(builder)` 可加按钮。
- **主题**:import `theme/common/style.css`(结构,保留),**不 import `frame.css`**,自供全套 `--crepe-*` 变量 + `.milkdown` 选择器覆盖(Crepe 只 token 化 color/font/shadow,**字号/行高/字重/间距/圆角必须选择器覆盖**)。
- **字体**:**运行时经桥注入**——Dart 读 `assets/fonts/{InterVariable,MiSansVF,JetBrainsMono}.ttf` → base64 → `@font-face`(MiSans 20MB 不入 HTML bundle,单一事实源、CJK 与产品 1:1)。
- **markdown IO**:`getMarkdown()` 拉 · `replaceAll(md)` 推 · `crepe.on(l=>l.markdownUpdated(...))` 防抖(JS 侧 300ms)存;**save↔push 回环守卫**(`programmatic` 旗标包住 `replaceAll`)。

### 3.1 行内图片 → 后端文档图床(新增,后端补)
`ImageBlock.onUpload(file)` 回调把图片字节经桥交给 Dart → Dart POST 到**新增后端端点**存本地 blob → 返回稳定本地 URL 写回 markdown `![](url)`。**不用 data-URI**(content 有 1MB 上限,真图片会瞬间爆)。后端按纪律加:blob 落盘(workspace 隔离目录)+ `POST /api/v1/documents/{id}/images`(或独立 attachments 域)返回可读回 URL 的端点 + `GET` 取图;同提交守 N/D/E/S/T + 文档 1:1(api.md/database.md/domains + `references/frontend/contract.md`)。**图片作为独立一小步(A5 内或专步),不阻塞 A1–A4 核心编辑器**。

## 4. Flutter 侧架构

### 4.1 `DocEditorSurface` DIP 端口 + 桥协议
- 定义 `DocEditorSurface` 端口(`ready`/`setMarkdown`/`getMarkdown`/`onChange`/`setTheme`/`headingRects`/`scrollToHeading`/mention 回调),macOS 用 `webview_flutter`(WKWebView)实现,Linux 降级只读(§4.4)。
- **健壮桥**(correlation-id 请求/响应):**一条 JS→Dart channel**(`AnselmHost`)承载 reply + event;Dart→JS 用 fire-and-forget `runJavaScript(window.__anselmDispatch(...))`;`{id}` + `Completer` 配对 + 5s timeout。payload 双重 JSON 编码防转义/注入。**ready 靠 JS 挂载后 `send({t:'ready'})` 握手,非 `onPageFinished`**。
- **生命周期**:`addJavaScriptChannel` + `NavigationDelegate` **先于** `loadFlutterAsset` → `await ready` → 注入字体 + 主题 → `setMarkdown(initial)` → JS 揭示(容器先 `visibility:hidden` 防空→满闪)。webview 背景设成 token bg 不透明防白闪。dispose 时 fail 所有 in-flight call。

### 4.2 `AnDocEditor` 组件契约(保持不变,让 feature 层零改)
`AnDocEditor({initialMarkdown, onChanged, mentionSource?, slashLabels?, focusNode?, autofocus})` + State 暴露 `headingOriginsGlobal()`/`headingOriginGlobal(int)` 的**等价桥实现**(或改 `_DocPageChrome` 走 provider 桥)。

### 4.3 版式决策(webview 是 box)——用户拍板:保留「标题+正文同滚」(产品特点)
**采用「标题/描述/标签做进 webview 页面内、位于编辑器正文上方、同一滚动容器」**:webview 是 box 但**整页在 webview 内自然同滚**,标题随正文一起滚(=保留现产品手感)。webview HTML 结构 = `<header>`(可编辑标题 + 描述 + tags 药丸)+ `#app`(Milkdown 编辑器),同一个 `overflow` 滚动容器。
- **标题/描述/tags 编辑**:header 里 contenteditable/输入 → 经桥 `onMetaChanged({name?,description?,tags?})` → Dart PATCH。标题是**独立 `name` 字段、非 content**,不进 markdown。
- **阅读列**:header 与 body 共用 720 居中列 + pageX 24,视觉连续。
- **大纲滚动高亮/跳转**:全在 webview 内——JS 侧 `IntersectionObserver`/`getBoundingClientRect` 逐标题算 active + 滚动事件经桥推 `docOutlineActiveProvider`;点大纲 → 桥 `scrollToHeading(i)` → 编辑器内 `scrollIntoView`。`doc_outline_spy_test.dart` 契约改由桥满足。
- `buildDocPage`/`_DocPageChrome` 简化:Flutter 侧不再自管滚动/头 sliver,改为 webview 填满海洋 + 浮层头 chrome(面包屑/红绿灯对齐)照旧浮在最上。`doc_page_alignment_test.dart` 重写(几何移入 webview)。
- **这块「辛苦努力设计」**:header 的排版节奏、标题字阶(page 标题 chrome 档 vs 正文 15 档)、可编辑态/占位、与正文的视觉接缝,都要精细打磨到和产品调性一致。

### 4.4 Linux 缺口
webview_flutter 只官方支持 macOS(WKWebView),Win/Linux 无后端。策略:`DocEditorSurface` 端口后 **macOS 先行完整交付**;Windows 用 `flutter_inappwebview`(WebView2,同 bundle 同桥);**Linux 降级只读渲染**(复用 `gpt_markdown`),tier-2 再评估 `webview_cef`。**绝不因 Linux 阻塞 macOS**。

## 5. @ 提及 → 带图标实体卡片
- 自定义 **inline atom 药丸节点**(`$node('mention')`:`inline:true`+`atom:true`+attrs `{id,kind,label}`)+ `$view` 渲染(图标 by kind + label,`ignoreMutation:()=>true`)。
- **`[[id]]` round-trip**:`$remark` 包 `remark-wiki-link`(原则 #8 不手搓 micromark)+ 节点 `parseMarkdown`(wikiLink→mention)/`toMarkdown`(mention→wikiLink,序列化成真 `wikiLink` mdast 非裸文本,否则 remark-stringify 会转义 `\[\[`)。**只有 `id` 进 markdown**;`kind`/`label` 是 transient,由 Dart 经 `window.AnMentionCache` 推入 + cache-miss 回调解析 → 重命名/换图标不脏文档。
- **@ 触发**:`slashFactory` 复用(`@` 而非 `/`),`shouldShow` 匹配 caret 前 `@query`,异步候选走桥 `flutterMentionSearch(q)`(debounce + seq-guard 防乱序),接现有 `MentionSource` DIP。picker 渲染 in-webview(避免跨边界 caret 锚定)。
- 挂到 `crepe.editor.use(...).config(...)` **在 `crepe.create()` 之前**(schema 创建后冻结)。

## 6. 视觉 token 映射(编辑器 = content-workspace 15 体系)
- **颜色**(light):ink `#1D1D1F` / muted `#6E6E73` / surface `#FFF` / sunken `#ECECEF`(代码块+内联码底) / accent **`#0071E3`**(非 spike 的 `#3b6cff`) / 选区 `rgba(0,113,227,.10)`。**内联码覆盖成 ink**(Crepe 默认红 `#ba1a1a` → 改 ink on sunken,产品约定 mono ink 不用红)。围栏语法高亮走 `SyntaxColors`(One Light/Dark)。
- **字重两档**:body **w300** / 强调+标题 **w400**,**禁 w500+**。ProseMirror 默认 bold 700 → **必须覆盖** `strong`/`b`/所有 heading 到 w400。层级靠字号+颜色。
- **字号**:prose **15/1.6/w300** · H1 22 · H2 18 · H3 15(h4-6 = 15/w400) · 代码块 mono **13/1.6** · 内联码 13 · 内容内标签 13(**不掉到 12**)。
- **间距**:块间距统一 **12** · li 4 · heading 上 24(非对称) · h3 上 16 · heading→body 12 · 阅读列 pageX 24 · 代码块内边距 12/16 · **阅读列 max 720 居中**。
- **圆角**:内联码 4 · 代码块容器 8 · @ 药丸 999(或 chip 12) · 弹窗 12-16。(island/card 16/20 归 Flutter chrome,不入编辑器 body。)
- **light/dark**:`:root[data-theme=dark]` 切换,由 Flutter `Brightness` 经桥驱动。

## 7b. 进展(landed / 待用户手动关)
- **A0 ✅ 调研 + 规范 + 拍板**(本页 §1–§6,六份 agent 报告)。
- **A1 ✅ webview 基座**:`tool/doc-editor/`(入库 Crepe 工程:`index.html` CSP+同滚容器 / `theme.css` 全套设计 token / `bridge.js` correlation-id 桥 / `main.js` Crepe 配置 / `mention.js`)+ `make doc-editor`/`make doc-editor-rt` → `assets/editor/doc_editor.html`;Flutter `lib/core/doc_editor/{doc_bridge,an_doc_editor}.dart` + 运行时字体注入 + 手动验证台 `lib/dev/doc_editor_harness_main.dart`。真 WKWebView 渲染成功(修 2 bug:spike 无窗口=没调 initWindow;macOS `setBackgroundColor` 未实现→try/catch)。代码块双灰框→单层井、标题裁切、正文左对齐(覆盖 Crepe reset 的 120px 把手槽)均修。
- **A2 ✅ slash 全功能中文化**:`textGroup`(正文/标题1-3/引用/分割线,h4-6 移除)/ `listGroup`(无序/有序/待办)/ `advancedGroup`(代码块/表格;图片·数学随特性开启显现)。拖拽把手 `blockHandle.shouldShow:()=>false` 关。headless 验菜单全中文。
- **A3 ✅ 划选气泡工具条**:Crepe Toolbar(粗/斜/删除线|码/链接)+ 主题贴 token。headless 验划选弹条。
- **A4 ✅ @ 提及带图标卡片 + `[[id]]` 保真**:`$nodeSchema` inline atom 药丸(per-kind SVG 图标 + label 由 `AnMentionCache` 重水合,只 id 进 md)+ `remark-wiki-link` 解析 + **自写 stringify 覆盖**(remark-wiki-link 原生会转义 `_`→`\_` 且加空 `|` alias 破坏保真 → 覆盖成裸 `[[value]]`)+ `slashFactory` @ picker(候选走 `flutterMentionSearch` 桥,独立运行用样本实体)。**round-trip 7/7 全绿含 `[[id]]` 逐字**。headless 验药丸渲染 + picker 内容。
- **关键坑**:report 4 说的 `$node(...).node` 实为 undefined,须用 `$nodeSchema`(有 `.node`/`.id`/`.type`)。
- **A4 picker 定位 bug 已修**:`.an-mention-menu` 缺 `position:absolute`(SlashProvider 只写 left/top、靠 CSS 定位上下文)→ 菜单落底,补上即锚 caret。
- **门禁绿**:`make verify` 2442 测全绿。**顺手修了上个会话遗留的 pre-existing 违规**(旧 `lib/dev/milkdown_spike_main.dart` 裸字号字面早已让 type-scale guard 红、但没跑过 verify)——删旧 spike 台 + orphan `assets/spike/`(S22),新台 `doc_editor_harness_main.dart` 的 readback 用 `AnText.code`。
- **待用户手动关(A1–A4 一并验,真机)**:①中文 IME(粗体后中文 / 组合中 Enter)②狂点狂划不卡死 ③slash/划选/@ 手感。CJK 现走系统 PingFang SC(MiSans 20MB 未注入,Latin/代码注入了 Inter/JetBrains Mono)。

### A5 分析(读 document_ocean.dart 后:非机械 swap,是特性重构)
现 `_DocPageChrome` 把 **Flutter 自有 ScrollController** 深耦合到:①浮层头折叠(scroll.offset>阈值)②大纲 scroll-spy(`editorKey.currentState.headingOriginsGlobal()` 全局 y 比对头带)③sliver 版式(super_editor 渲成 sliver);props(描述/tags)是标题下的 Flutter `AnKv` 面板。**webview 自持滚动 + 标题/描述/tags 在 webview 内(co-scroll 决策)** → A5 须重构:
- 版式:`buildDocPage` 的 CustomScrollView/sliver → webview 填满海洋;标题/描述/tags 移进 webview header(已建)。
- 浮层头折叠:webview 滚动 offset 经桥 → `shellHeadProvider.setCollapsed`(需 bridge 加 scroll-offset 事件)。面包屑(Documents/Skills)仍 Flutter 浮层头,只是大标题进 webview。
- 大纲:`headingRects`(已建)经桥 → `docOutlineActiveProvider`;`outlineJumpProvider` → 桥 `scrollToHeading`(已建)。
- props:webview header 的 desc/tags 编辑 → `onMeta` 桥 → PATCH;右岛只留大纲/文件 meta/backlinks。
- @ 候选:桥加「JS→Dart 带响应」(picker `flutterMentionSearch` → `mentionSearch` 事件带 reqId → Dart `MentionSource.search` → `mentionResolve(reqId,res)`);harness 现用样本 stub。
- **测试**:`documents_test.dart` 的 super_editor 机器人组(`SuperEditorInspector`/`typeImeText`/`BlinkController`)失效;AnDocEditor 在 headless widget-test 会创建真 WebViewController 抛异常 → **须 `DocEditorSurface` DIP**(默认 WKWebView 实现 / 测试注入 Noop)才能保 `make verify` 绿。
- **决策自足**:上述皆从 co-scroll 决策推出、可自行决定;主要风险是重构 churn(全可 git 回退,未提交)。

### A5 进展(gate-green 分步)
- **A5-foundation ✅**(core/doc_editor,不碰 live feature,`make verify` 2442 绿):
  - 桥:@ 候选走桥「JS→Dart 带响应」(`flutterMentionSearch`→`mentionSearch{query,reqId}` 事件→Dart `MentionSource.search`→`resolveMention(reqId,results)`)· `primeMentionCache` 灌 `[[id]]` 标签 · `scroll` 偏移事件(浮层头)· `outline` rects 事件。
  - `mention.js`:药丸 kind 由 id 前缀派生(`fn/hd/ag/wf/doc`→kind),裸 [[id]] 也出对图标。
  - `AnDocEditor`:接 `mentionSource`(@ 搜 + 载入 `resolveNames` 灌缓存)· `onScroll`/`onOutline` 回调 · **`debugDisableWebview` 无头测试开关**(测试渲占位不建真 WebViewController)· nullable controller/bridge。
- **A5 ✅ 全落地 + 真机验(demo 真壳截图确认)**:
  - `document_ocean.dart` **重写**:webview `AnDocEditor` 填满海洋;floating-head 靠 `onScroll`→`setCollapsed`;大纲 live-focus 靠 `onActiveHeading`(JS 侧算 active index)+ 跳转 `scrollToHeading`;回顶 `scrollToTop`;标题/描述在 webview header 编辑→`onMetaChanged`→PATCH(name/description)。桥新增 `active`/`scroll`/`scrollToTop` + mention「JS→Dart 带响应」+ `primeMentionCache`。webview header 加 `#doc-crumb`(面包屑)+ `nameEditable`(skill 名不可改)。
  - **决策**:tags 走 webview header **只读展示**(inspector 明确「无属性表单」,不塞回);**可编辑 tags = 小 follow-up**(webview header chip UI)。
  - **测试**:删 super_editor 机器人组(@ mentions group + `doc_outline_spy`/`doc_page_alignment` + capture_doc_{slash,chip,mention,editor,page} + capture_md_parity + 旧 super_editor spike);`documents_test.dart` 编辑器组改成断言 `AnDocEditor` props(`AnDocEditor.debugDisableWebview=true` 无头占位);`capture_documents` 同置。
  - **删 super_editor**:`core/ui/an_doc_editor.dart`+`_components.dart`(~1378 LOC)+ pubspec `super_editor`/`super_text_layout`/`markdown` 全删,`pub get` 重解析、full analyze 净。`entity_ref_codec`(`extractEntityRefIds` 新编辑器用)保留;`openDocumentContentProvider`+`expand/collapseEntityRefs` 现无用(留待清理)。
  - **门禁**:`make verify` **2414 测全绿**。**demo 真壳截图确认**:新编辑器接进真 documents 海洋,同滚头 + WYSIWYG + @ 药卡(Concepts/Deploy/Setup 从 [[id]] 经 MentionSource 解析带图标)+ 右岛大纲/属性/反链,视觉贴 token。
- **可编辑 tags ✅**(0707 补):webview header 标签改成 chip + × 删 + add-input,改动经 `onMetaChanged({tags})` → PATCH(skill 名不可改故其 tags 也不编辑);门禁仍 2414 绿。
- **死码清理 ✅**:删无用 `openDocumentContentProvider`(super_editor 时代富化 provider)+ document_state 两个随之无用的 import。`entity_ref_codec` 的 `expand/collapseEntityRefs` 现仅其自测用(留待后续,`extractEntityRefIds` 新编辑器在用)。
- **A6 Linux 守卫 ✅**(0707):`AnDocEditor` 加平台守卫——`_webviewEnabled = !debugDisableWebview && HostPlatform.isMacOS`;非 macOS(Linux/Windows,无 `webview_flutter` 后端、建 `WebViewController` 会崩)走 `_degradeReadOnly`(720 列 + crumb/title/desc + `AnMarkdown` 只读渲染正文,不可编辑)。build 三径:test 占位 / 非 macOS 只读降级 / macOS webview。macOS+测试路径不变(门禁 2414 绿);**降级路径 macOS 测不了,待 Linux 环境验**。
- **待做**:A6 剩(Linux 真机验降级 + round-trip 测试矩阵补边界)· **图片**(需给后端加文档图床)· **数学**(需打包 KaTeX 离线资产,低优)· 清 `entity_ref_codec` 的 expand/collapse(仅自测用)。**用户手动 IME 终验仍建议**(渲染真机已完美,IME 顺滑度需人手最终确认)。

## 7. 建造顺序(A1–A6,每步真开 app 手动验)
- **A1 · webview 基座**:搬源码入库 + `make doc-editor` + 生产 Crepe 配置(主题 CSS + 字体注入 + 桥协议)+ `AnDocEditor` 薄组件 + `DocEditorSurface` 端口。**验**:加载、渲染贴 token、中文 IME 不卡不丢(打「粗体后紧接中文 + 组合中按 Enter」这一 WebKit 高危流)、无卡死。
- **A2 · slash 全功能 + 禁拖拽**。**验**:`/` 弹中文菜单、每项生效、无左侧拖拽把手。
- **A3 · 行内格式 + 划选气泡**。**验**:划选弹条、每键生效、中文选区正确。
- **A4 · @ 卡片带图标**。**验**:@ 弹选、插入药丸带正确 kind 图标、`[[id]]` round-trip 逐字存活、重命名不脏文档。
- **A5 · 接进 documents + 版式重构 + round-trip 全矩阵 + 删 super_editor**。**验**:代码块含语言标/有序号/多行引用/表格/嵌套/`[[id]]` 全保真;大纲高亮+跳转经桥工作;super_editor 依赖清除、`fe-verify` 绿。
- **A6 · Linux gap + 测试矩阵 + 文档同步**。

## 8. 拍板结论(2026-07-07 用户已定)
1. **版式**:✅ **保留「标题+正文同滚」**(产品特点,要精心设计)。做法见 §4.3:标题/描述/tags 做进 webview 页面内、正文上方、同一滚动容器。
2. **功能范围**:✅ **全开**——表格 + 行内图片 + 数学公式,后端该补就补(图片需新增后端图床,见 §3.1)。仅 TopBar/AI 关。
3. **@ picker 外观**:定 **in-webview 原生 picker 样式贴产品**(规避跨边界 caret 锚定)。

## 9. 测试矩阵(入 make -C frontend verify)
- **round-trip 保真**(`roundtrip.mjs` 升级 + Dart 侧):围栏含语言标 / 有序号 / 多行引用 / 表格 / 嵌套列表 / task / `[[id]]` 逐字 / 空文档 / 超长 / 海量块 / 极值 / 中文。
- **feature 层复用测试**保留(rail/plan/SSE/inspector);**AnDocEditor + DocumentOcean-editor 组**重写(super_editor test robot API 消失,webview 无头驱动难 → 变薄无头面 + 手动/集成)。
- **entity_ref_codec 测试**:codec 存活期间保留。

## 10. 风险
- **中文 IME(最高危)**:ProseMirror 在 Safari/WebKit(=WKWebView)有 CJK 组合态 bug(粗体旁打中文可能丢字/光标错位,Milkdown #1542)。缓解:钉最新 `prosemirror-view`(Crepe 7.21 已含多个组合修复,不降级)、避免组合中变异的 input-rule、**A1 把「粗体后中文 + 组合中 Enter」列为必过验收**。
- **webview 键盘焦点丢失**(flutter#147844,macOS/Windows):与 Flutter chrome 交互后 webview 收不到键。缓解:`Focus`/`FocusScope` 包裹 + 点击/回车重夺焦点 + 编辑器聚焦时避免全局 `Shortcuts` 吞键。
- **CSP 锁死**(local-first 隐私):HTML `<head>` 加 `connect-src 'none'` 等严格 CSP,保证编辑器无法外泄文档。
