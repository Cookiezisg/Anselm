---
id: DOC-050
type: reference
status: active
owner: @weilin
created: 2026-07-05
reviewed: 2026-07-05
review-due: 2026-10-03
audience: [human, ai]
---

# Feature:Documents(文档海洋)—— 当前形态

> 用户第一手手编的本地 markdown 知识库,同一海洋并放两类 **file-like 知识**——**documents**(Notion 式页面树)与 **skills**(带 YAML frontmatter 的 SKILL.md)。与 Quadrinity 实体是两种物种:实体 AI-only/版本化/build-mirror;file-like 知识**用户直接编辑、无版本、原地覆盖**。当前落地 **P1–P2**(契约 + 数据缝 + 树 rail + 只读预览);Notion 编辑器(super_editor)是 **P3**。

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
| **rail(左岛)** | `features/documents/ui/document_rail.dart` | `DocumentRail` over [`AnSidebarList`]:一 group 两 `SidebarType`——**Documents**(递归页面树,`SidebarRow.children` 组树、有子即出折叠三角,无需 folder/file 判别符)+ **Skills**(扁平 slug 列,行 id 加 `skill:` 前缀防撞 `doc_` id)。客户端过滤(整棵有界树已载,`flattenSidebar` 内建,不接服务端搜索)。四态(骨架/错/空/列表)。选择 → `selectedDocProvider`(暂 provider 驱动,路由化 P5)。`buildDocumentsRailModel` 纯投影(脱 widget 单测)。 |
| **ocean(中心)** | `features/documents/ui/document_ocean.dart` | **P1/P2 只读预览**(Notion 编辑器 P3 替换):无选区=`pickTitle` 空态;文档=name 标题 + `AnMarkdown(content)`;skill=name + frontmatter 摘要行(context·source·N tools)+ `AnMarkdown(body)`。选中即 `getDocument`/`getSkill` 取全文。 |

## 数据缝 + state

- **唯一缝** `DocumentsRepository`(`features/documents/data/`):`LiveDocumentsRepository`(接 `ApiClient`,bounded 列表经 `getPage().items` 解 `{data:[…]}` 无 cursor)/ `FixtureDocumentsRepository`(内存可脚本,扁平节点按 parentId 组树 + skill 列;写就地改)/ `documentsRepositoryProvider` 单点 override(demo 换 `demoDocumentsRepository()`)。**documents 面**:`getTree`(`GET /tree` 元数据无 content)· `getDocument`(`GET /{id}` 带 content)· `listChildren`(`GET ?parentId=`)· `createDocument`(`POST`→201,名自动去重)· `updateDocument`(`PATCH` partial,存正文=PATCH content)· `deleteDocument`(`DELETE`→204,整子树)· `moveDocument`(`:move` cycle-guarded)· `duplicateDocument`(`:duplicate`→201)。**skills 面**:`listSkills`(`GET /skills` 无 body)· `getSkill`(`GET /{name}` 带 body+frontmatter)· `createSkill`(`POST`→201 严格冲突)· `replaceSkill`(`PUT` 全覆盖无 rename)· `deleteSkill`(`DELETE`→204)。
- **state**(`features/documents/state/document_state.dart`):`documentTreeProvider`(FutureProvider,整树)· `skillListProvider`(FutureProvider,全 skill)· `selectedDocProvider`(`NotifierProvider<DocSelection?>`,`DocSelection={isSkill,id}`)· `openDocumentProvider`/`openSkillProvider`(autoDispose.family,按需取全文)。

## 契约(镜像后端)

`core/contract/entities/document.dart` `DocumentNode`(一 DTO 兼服 `/tree`[省 content 默认空]与 `/{id}`,镜像 `document.go:21`)+ 护栏常量 `kDocumentMaxContentBytes`(1MB)/`kDocumentMaxNameLength`(256)。`skill.dart` `Skill`(外层)+ `Frontmatter`(name/description/allowedTools/context/agent/arguments/disableModelInvocation/userInvocable/whenToUse/model/effort/source,镜像 `skill.go:26/42`)+ 护栏 `kSkillMaxBodyBytes`(32KB)/`kSkillMaxDescriptionChars`(1024)/`kSkillNameRegex`(`^[a-z][a-z0-9_-]{0,63}$`)供 properties 面板预校验。

## 编辑器决策(P3,已定基座,spike 验证)

**Notion 式所见即所得编辑器基座 = `super_editor`**(pubspec 钉 `0.3.0-dev.40`——dev.41+ 需比项目 Flutter 3.41.9 新的 `TextInputStyle` IME API)。选型经 4-agent 评估:唯一 markdown 原生 + 块 + `@`(`StableTagPlugin`)/`/`(`ActionTagsPlugin`)+ 无样式可全主题化 + MIT 的 Flutter 基座(fleather 退路但无表格/嵌套列表;appflowy 死于 AGPL+有损往返;quill 死于 Delta)。**spike 结论**(`test/dev/spike/`):markdown 往返 13/14 稳(含嵌套列表/表格/**`[[id]]` wikilink 逐字存活**——后端 `pkg/wikilink`+`KindLink` relation 边已存在);代码围栏尾随空白漂移→交 `AnCodeEditor`+自定义序列化器;**中文 IME 真机验证通过**。**P3 编辑器铁律**:整套 stylesheet 走项目设计 token(MiSans + 两字重 w300/w400 经 `AnText.weight()` 带 wght 轴、禁 w500+ / `AnColors` / tokens 字号行高间距 / 代码块→`AnCodeEditor` / 只读→`AnMarkdown`),markdown 为真相(load→edit→serialize)。

## 后续(未落)

P3 编辑器(`AnDocEditor` facade + stylesheet + `@`/`/` + wikilink chip codec)· P4 skill frontmatter properties 面板(allowedTools chip+实体 picker)+ 文档 properties(description/tags)+ rail 新建/改名/移动/删/复制 + skill `:activate`· P5 路由化(`/documents/:id`·`/documents/skill/:name`)+ SSE 刷新(树走 notifications 流)· 反向链接/backlinks(后端 `link` 边已在,待查询面)。
