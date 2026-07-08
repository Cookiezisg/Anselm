---
id: DOC-052
type: reference
status: active
owner: @weilin
created: 2026-07-05
reviewed: 2026-07-08
review-due: 2026-10-06
audience: [human, ai]
---

# Feature:Documents(文档海洋)—— 当前形态

> 用户第一手手编的本地 markdown 知识库,同一海洋并放两类 **file-like 知识**——**documents**(Notion 式页面树)与 **skills**(带 YAML frontmatter 的 SKILL.md)。与 Quadrinity 实体是两种物种:实体 AI-only/版本化/build-mirror;file-like 知识**用户直接编辑、无版本、原地覆盖**。**全面已落**:树 rail 全 CRUD+拖拽 → 原生所见即所得编辑器(`core/editor/AnEditor`,super_editor 基座)→ 右岛大纲/属性/反链 → SSE 树自刷新 → go_router 路由化。
>
> 编辑器史(细节从 git 取):super_editor 首版 → Milkdown-in-webview 重做(WRK-060,已归档 [`archive/doc-editor-webview`](../../../archive/doc-editor-webview/README.md))→ **原生 super_editor 二次重做(现行)**——webview 只能 CSS 近似 An 原语,原生把每个块渲成真 Flutter widget、逐像素 1:1,且中文 IME 走 Flutter 自己的 IME 路径。

## 两类知识如何共存(后端逼出的诚实)

documents 与 skills 结构不同,**不能塞进一棵树**——故树数据层两分节、编辑体验层统一:

| | documents | skills |
|---|---|---|
| 身份 | `doc_<16hex>` id | **slug `name` 即身份**(无 id、无 rename) |
| 结构 | 树(`parentId`+`position`+`path`,节点既是页又是文件夹、无 isFolder 判别符) | **扁平** slug-keyed |
| 存储 | DB 表 | 磁盘 `skills/<name>/SKILL.md` |
| 元数据 | `description`+`tags` 独立**列**(正文无 frontmatter) | 真 YAML **frontmatter** |
| 动作 | CRUD + `:move`/`:duplicate`/`:iterate` | CRUD + `:activate` |

## 面

| 面 | 在哪 | 是什么 |
|---|---|---|
| **rail(左岛)** | `features/documents/ui/document_rail.dart` + `document_rail_model.dart` | `DocumentRail` over `AnSidebarList`:**Documents**(递归页面树)+ **Skills**(扁平 slug 列,行 id 加 `skill:` 前缀防撞)。**全 CRUD**:New page/New skill、行内改名(`AnInlineEdit`)、`:duplicate`、删除(danger 确认弹窗,文档=整子树级联提示)。**树内拖拽重排**:`_onDrop` → 纯函数 `planDocMove`(环/自落/skill 越界守卫,脱 widget 单测)→ `:move`。客户端过滤(整棵有界树已载)。四态(骨架/错/空/列表)。 |
| **ocean(中心)** | `features/documents/ui/document_ocean.dart` + `an_document_editor.dart` | 无选区=`pick` 空态。选中 → `AnDocumentEditor`:**同滚页**(CustomScrollView:头 sliver[面包屑+可改名 H1+描述+可编辑 tags chips] + `AnEditor` sliver[shrinkWrap]——大标题真滚走,浮层头折叠才诚实;720 阅读列=对称算距)。正文存 = `updateDocument` PATCH content(600ms 防抖、**不 invalidate** 保光标);头部改名/描述/tags → `onMetaChanged` → 分部 PATCH。skill 视图同款页:标题不可改名(slug 即身份)、无 @(后端只在 documents 解析 `[[id]]`)、存=PUT 全覆盖(写前取最新 frontmatter 读-改-写)。 |
| **inspector(右岛)** | `features/documents/ui/documents_inspector.dart` | 单列堆叠:**大纲**(`docOutlineProvider` 列表 + `docOutlineActiveProvider` 活跃行,点行 → `outlineJumpProvider` → 编辑器 `scrollToHeading`)→ **文件 meta**(path/size/modified)→ **backlinks**(`GET /relations?toKind=document&kind=link` 入向边,点文档行导航)。skill 则大纲 + `_SkillForm`(frontmatter 字段编辑,存=读-改-写 PUT 带回 body)。 |

## 原生编辑器(`lib/core/editor/`,super_editor 门面)

super_editor **钉 0.3.0-dev.40**(dev.41+ 引用本 Flutter 3.41.9 没有的 `TextInputConnection.updateStyle`;markdown 编解码随包内置)。**仅经 `core/editor/` 门面用**(原则 #8),八件:

- **`an_editor.dart`** — `AnEditor` 装配:裸 `SuperEditor`(sliver 协议、无盒包裹)+ IME 输入源(CJK 生命线)+ 桌面 mouse 手势 + An 块皮 ComponentBuilders + 三个文档 overlay 层(划选条/slash/@ picker)。`shrinkWrap` 由文档海洋设(同滚头);独立宿主(harness)自持滚动。`AnEditorState` 公开 `document`/`headingNodeIds`/`contentTopForNode`(大纲跳转/scroll-spy 的几何缝)。避坑铁律在类 doc(#2995 起手无选区 / 每 State 一把 layout key / overlay 走文档层不手管)。
- **`an_editor_components.dart`** — task/代码块/引用的 An 皮肤(值相等只揣 token 色,不逐帧重分配)。
- **`an_editor_stylesheet.dart`** — An prose 声全量样式表(正文 15/w300、标题 22/18/15 全 w400、两字重铁律)。
- **`an_editor_markdown.dart`** — codec 门面,内置序列化外补两件:①**mention 往返**(药丸 `MentionPlaceholder` ↔ `[[id]]` 逐字,后端 `pkg/wikilink` 建 link 边的契约)②**围栏语言标保真**(内置 codec 双向丢 ```` ```dart ````——载入按序盖进节点 metadata `codeLanguageKey`、存出按序回写围栏行,否则开档即存就弄脏文档)。`mentionIdsInDocument` 供建边/批解析。
- **`an_editor_slash_menu.dart`** — `/` 菜单 **11 命令**(正文/标题 1-3/引用/代码块/**表格**/无序/有序/待办/**分隔线**),标签走 slang `documents.slash.*`(`labelOf(Translations)`——顶层表拿不到 context,调用方传);关键词含拼音别名。插块型命令(分隔线/表格)按 `SlashContext.emptyAfterSubmit` 决定**空段替换/非空下插**(提交删 `/query` 前预判),尾随新段落收光标。
- **`an_editor_mention.dart`** — `@` picker(`StableTagPlugin` 词法 + caret 锚定 overlay + `AnMentionPanel` 复用 chat 件);选中插内联药丸(id/name/kind),数据缝=core `MentionSource` DIP。
- **`an_editor_toolbar.dart`** — 划选浮动格式条:**粗/斜/删/行内码/链接** 五键。链接键:选区已通贯带链→**去链**;否则原位换 **URL 输入条**(回车上链[裸域名补 https://]、Esc/外点取消[TapRegion]);会话**快照**选区+落点——输入夺焦清活选区、上链仍打在快照区间;关闭归还编辑器焦点。
- **`an_editor_syntax.dart`** — 代码块语法高亮,按 (nodeId, plainText) **记忆化** style phase(旧重建卡死首凶的解药)。

**大纲下标不变式**:右岛大纲=`extractDocOutline(markdown)`(纯正则、围栏感知、h4-6 并 3 级),跳转/scroll-spy=编辑器 `headingNodeIds`——共享键=**文档序下标**、不存偏移,两侧必须对「谁是标题」完全一致(编辑器侧因此 h1–h6 **六档全算**,漏任何一档全体错位)。`outline_alignment_test.dart` 用刁钻形状(围栏 #/引用 #/h4-6)锁死。同滚页下标题坐标经「编辑器 reveal 位(=头实测高)+内容 Y」在两空间换算。

## 数据缝 + state

- **唯一缝** `DocumentsRepository`(`features/documents/data/`):Live(`ApiClient`)/ Fixture(内存可脚本)/ `documentsRepositoryProvider` 单点 override(demo 换 `demoDocumentsRepository()`——5 文档嵌套树 + 2 skill,正文含 `[[doc_…]]` 互链 + 围栏代码 = round-trip 夹具)。documents 面:`getTree`/`getDocument`/`listChildren`/`createDocument`/`updateDocument`/`deleteDocument`/`moveDocument`/`duplicateDocument`/`listBacklinks`;skills 面:`listSkills`/`getSkill`/`createSkill`/`replaceSkill`/`deleteSkill`。
- **SSE 树自刷新**:`lifecycleSignals()`=notifications 流 durable `document.*` 帧 → `DocumentTreeList` 订阅、**400ms 去抖 → invalidateSelf** 重取 `/tree`;刻意不动 `openDocumentProvider`(保光标)。
- **state**(`document_state.dart`):`documentTreeProvider`(AsyncNotifier 自刷新)· `skillListProvider` · `selectedDocProvider`(URL 单向派生)· `openDocument`/`openSkill`(autoDispose.family)· `docOutlineProvider`+`docOutlineActiveProvider`+`outlineJumpProvider`(大纲三件)· `backlinksProvider` · `documentMentionNamesProvider`(载入前经 `extractEntityRefIds` 批解析 `[[id]]` 显示名)。
- **路由**:`/documents/:id` · `/documents/skill/:name`(选区单向派生自 URL)。

## 契约(镜像后端)

`core/contract/entities/document.dart` `DocumentNode`(一 DTO 兼服 `/tree`[省 content 默认空]与 `/{id}`)+ 护栏 `kDocumentMaxContentBytes`(1MB)/`kDocumentMaxNameLength`(256)。`skill.dart` `Skill`+`Frontmatter` + 护栏 `kSkillMaxBodyBytes`(32KB)/`kSkillMaxDescriptionChars`(1024)/`kSkillNameRegex`。`[[id]]` 逐字保真=后端关系边契约(`pkg/wikilink` 每次写重解析建 `link` 边;前端只 PATCH `{content}`)。

## 测试

`test/core/editor/an_editor_test.dart`(交互地板:挂载/打字/双三击/狂点不卡 + E2 样式阶梯 + E3 行内 + E4 slash[含分隔线替换/表格下插] + E5 @ + E6 划选条[含 link 上链/去链/外点消隐] + E7 高亮 + E8 表格 + E9 桥)· `an_editor_markdown_test.dart`(round-trip 矩阵:mention 逐字/幂等/表格/嵌套列表/引用+链接/HR/空文档/转义/**语言标**)· `test/features/documents/documents_test.dart`(rail/plan/inspector/SSE/双写者)· `outline_alignment_test.dart`(下标不变式)。真 CJK IME 组字自动化不了(Flutter #131510)→ 手验台 `lib/dev/editor_harness_main.dart`。

## 已裁决 / 剩余

- **后置大件**:行内**图片**(需后端文档图床——attachment 域的 CAS blob 管道可复用,缺 document→image 关联与回读 URL 方案 + 编辑器 image block)· **数学公式**(KaTeX 离线资产,低优)。
- **`:iterate`(AI 编辑本文档开对话)前端入口未接**(后端端点就绪、icons/来向线程处理已备,入口位置待拍板)。
- **需用户**:中文 IME 手动终验签字(渲染/交互真机已验,组字顺滑度需人手)。
- **已知取舍**:每次编辑全篇序列化 + 全大纲重算(调用方 600ms 防抖;文档 ≤1MB 护栏内可接受,超大文档是已知悬崖)· skill 双写者(中心 body/右岛 config)各自读-改-写,防抖窗口内并发有竞态窗(注释已声明)。
