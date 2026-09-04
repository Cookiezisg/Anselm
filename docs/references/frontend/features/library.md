---
id: DOC-052
type: reference
status: active
owner: @weilin
created: 2026-07-07
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Feature：Library（知识海洋）——当前形态

> Library 是产品容器；document 与 skill 是其中两种 page。后端仍使用各自准确的 `document.*`、`skill.*` 契约，前端容器统一位于 `frontend/lib/features/library/`。

## 1. 产品面

| 面 | 当前事实 |
|---|---|
| 左岛 rail | Documents 递归树 + Skills 扁平列表；创建、重命名、复制、AI 编辑、删除；document 支持子页与拖拽重排。AI 编辑从文档行菜单打开带当前文档 mention 的 Chat 对话；复制是整棵子树深拷贝，成功后打开新根；拖到行中段重挂为子页，拖到上下缘按同级插入；后端拒绝的移动不改变当前树 |
| 中心 document | 无选中时是未落库草稿，首次真实编辑才创建；选中后为标题、简介、标签和正文同滚的原生编辑页 |
| 中心 skill | `SKILL.md` 清单编辑、附件文件树与按文件类型分派的预览/编辑；任意文件保留系统打开/Finder 逃生口 |
| 右岛 | document 的大纲、属性、反链；skill 的文件、绑定、属性、来源和当前文件大纲 |

规范路由是 `/library/:id` 与 `/library/skill/:name`；skill 的捆绑文件通过同一路由的 `?file=<相对路径>` 查询参数选中。当前选区只从 URL 派生；无选中状态不伪造 id。

## 2. 编辑器与文件能力

- `AnEditor` 是原生 Flutter WYSIWYG markdown 门面，后端保存 markdown 真相。
- 支持标题/列表/引用/分隔线/任务、行内格式与链接、slash 命令、`@` mention、可编辑表格和围栏代码块。
- 编辑器启用文档级 history；一次独立输入可由 undo 撤回并全量重建文档，宿主回归测试锁定撤回后的正文与无 Flutter 异常。macOS `Command+Z` 仍需在真实 App 台架中验证。
- `[[id]]` wikilink、代码围栏语言标与表格必须往返保真；代码块使用嵌入式 `AnCodeEditor`。
- document 正文以防抖 PATCH 保存，meta 分部 PATCH；保存不整体 invalidate 当前文档，避免光标跳动。右岛 live metrics 带文档身份，编辑时即时更新；旧 provider 重取不得覆盖当前编辑，切页时清空活值再从新页真相播种。
- document 结构性 SSE（尤其 `document.moved`）只去抖重取 metadata tree；打开页正文 provider 继续冻结以保住光标，但右岛 Path/Size/Modified 必须优先取最新 tree row，不能把打开时的旧路径继续展示。编辑器载入时的 live seed 只提供首帧字数/大小，不能伪造 Modified；真实编辑的乐观本地时间只有在晚于持久 row 时才生效。
- 同一页面的正文若因外部真相换代（例如已安装 skill 更新），只重置内部原生编辑器而保留页面滚动/大纲壳；正文未变的 meta 刷新不重置，旧实例的延迟保存也不得反写新正文。
- skill 清单以读—改—写 PUT 保存；附属 markdown 用只读/可编辑富文本，代码与文本用代码编辑器，图片/SVG/CSV/字体走专用预览。
- 文件读取有大小护栏；未知类型显示诚实信息卡，超限文件明确说明 `1 MB` 在线预览上限并保留系统打开/Finder 逃生口，绝不假装成功预览。

## 3. 数据与关系

- `LibraryRepository` 是唯一数据缝，Live/Fixture 实现同形；document 与 skill 共用一个 feature，但保留各自后端契约。
- document 树结构事件触发去抖重取；正文编辑采用权威响应与局部状态，不能被 lifecycle 回声打断。
- document 反链来自 relation `link` 入边；skill 的实体绑定来自 `equip` 关系。
- skill 的 `allowed-tools` 通过候选选择器编辑，可选择内置工具、Function/Handler、MCP 工具，也允许受约束的自由输入。
- skill 的 `context=fork` 属性提示明确列出区分大小写的 `Explore`、`Plan`、`general-purpose`；后端仍是最终校验源，未知值不能拖到激活时才暴露。
- skill 文件路径必须保持在该 skill 根目录内；系统打开只作用于后端返回的真实路径。

## 4. 关键不变量

1. Library 是容器名，Document/Skill 是资源语义；不得为统一 UI 重命名后端 wire。
2. 空草稿未编辑就离开时不落数据库。
3. markdown 是持久真相；富文本、代码块和预览只是不同投影。
4. document 树移动必须拒绝自落、环和 skill 越界。
5. 编辑器与 Chat markdown 对同一语料保持渲染语义一致。
6. 右岛只展示有真实数据的组；折叠不能卸载带防抖保存缓冲的 skill 属性表单。

## 5. 验证入口

- Library：`frontend/test/features/library/`
- 编辑器：`frontend/test/core/editor/`
- markdown 对齐：`frontend/test/core/ui/markdown_parity_test.dart`
- 人眼语料：`make -C frontend demo` 的 Markdown Kitchen Sink
