---
id: WRK-054
type: working
status: active
owner: @weilin
created: 2026-07-03
reviewed: 2026-07-03
review-due: 2026-10-01
audience: [human, ai]
---

# 实体页雕琢 — 逐实体 ideal 形态(function 首站)

> 总纲:十实体逐个雕琢实体页(概览 hero 可视化 + 编辑草稿模式 + 版本结构化 diff + 右岛升级),每实体定稿后 revisit 其 chat 工具卡。顺序 function → **workflow(第二站,2026-07-03 用户 pivot,专属规范 [`workflow-page.md`](workflow-page.md) WRK-055)** → (后续逐个聊)。共享原语下沉 `core/ui`、gallery-first。function 的 F3 批(右岛按签名渲结果 + hero 活态)暂缓、排在 workflow 站之后。

## 已拍板(2026-07-03)

1. ~~编辑 = 显式草稿模式~~(已被 #4 取代)。
2. **代码默认收合 50 行 + 渐隐 + 展开**(签名为王,代码是实现细节)。
3. **先做实体页**,chat 卡等实体页全定稿后 revisit。
4. **版本内容 AI-only,手工只编 meta**:签名/代码/依赖/py 等版本内容**不开手工编辑**(签名与代码强关联、手编必劈叉;AI 建/改时两者同脑产出)——改动一律走 AI(`:iterate`,入口后续设计,当前不加按钮);手工可编的只有 meta(名字[页头就地改名]/描述/标签[概览就地编辑],PATCH 不升版)。

## 后端写面契约(核实 `references/backend/api.md`,零后端改动)

- `PATCH /functions/{id}` — meta(name/description/tags),**不升版本** → rename/说明/标签。
- `POST /functions/{id}:edit` — ops 构建新版本(function ops:`set_meta|set_code|set_inputs|set_outputs|set_dependencies|set_python_version`;空 ops = 仅重建 env)→ 草稿保存。
- `POST /functions/{id}:revert` — active 指针移到指定版本号 → 版本 tab「设为活跃」。
- `POST /functions/{id}:iterate` — 返 `conversationId` → AI 编辑入口(本轮暂缓,等 chat 卡轮)。

## Function 页 ideal(设计已过用户)

**心智:变换盒** `inputs → [Python] → outputs`,把本质画在页顶。

- **概览三段**:① hero 签名条 `AnTransformBox`(左 inputs 列 / 中心盒[名 + env 灯 + py·deps 徽] / 右 outputs 列,水平切线贝塞尔 hairline 连线——与 workflow 图同款边,首次落地;空签名显示虚线空槽;运行时活:输入亮→盒呼吸→输出亮/失败转红,数据源=右岛同 scope run 流)② 代码段(50 行渐隐收合)③ 环境卡(deps + py + venv 状态合一,envError 红字直出)。meta KV 收进 header 区。
- **编辑**:版本内容只读(拍板 #4,AI-only);手工=meta 就地编辑(页头改名 + 概览描述/标签,PATCH 不升版)。
- **版本 tab**:顶部结构化签名 diff 摘要(字段/依赖级对比)+ code LCS diff 照旧 + changeReason/builtInConversationId(跳对话)+「设为活跃版本」(`:revert`)。
- **右岛**:入参表单(+上次实参回填)→ 流式终端窗保留 → 结果按 outputs 签名逐字段渲(多余/缺字段诚实标出),耗时+logs 折叠。右岛=操作台,页 hero=仪表盘,同源两视角。

## 建造批次

| 批 | 内容 | 状态 |
|---|---|---|
| F1 | `AnTransformBox` + `AnFadeCollapse` 原语(gallery 7+2 specimens)+ function 概览重排(hero + 50 行渐隐代码 + 环境合卡 + envError callout) | ✅ 已落(gallery + demo 页截图过,输出列对齐 & 窄宿主 chip 溢出已修) |
| F2 | 写面(repository `patchFunctionMeta`/`revertVersion` kind 通用,Live+Fixture 双实现)+ **meta 就地编辑**(页头改名 `AnOceanHeader.onTitleChange` + 概览说明/标签走**成熟 `AnKv` 编辑模式**,PATCH 不升版)+ 版本 tab 结构化签名 diff 小签(`functionVersionSummary` 纯函数)+「设为活跃版本」(`:revert`) | ✅ 已落(含 review 重写) |
| F2-fix | 概览 meta review 重写:①**说明 + 标签 = 一个可编辑 `AnKv`**(拍板:AnKv 是本页成熟 KV 编辑件,与 venv 段同件;`AnField` 直用 + 手搓 `_TagsMetaField` 均弃,消除对齐/半高/卡编辑态等 review 缺陷)②版本 tab **diff 置顶**、摘要小签 +「设为活跃」移到 diff **下方 footer**(选版本不再跳)③`setActive` 就地重算 active 标记(选区不回弹最新)+ 防重入 pending + 失败 toast ④`VersionRow` 升 freezed 值类型 + `selectedIndex` 防越界 | ✅ 已落 |
| F2-primitive | 拍板反馈「KV 编辑按钮该在最右、标签该是 ➕/✕ 而非文本」→ **增强 core 原语**:`AnEditableValue` 铅笔↔取消/保存移到 **value 最右单锚**;新增 **`AnKvRow.tags`** | ✅(被 F2-cleanup 重写取代) |
| F2-cleanup | 用户再指「value 不贴右了、标签交互不舒服(该是点 ➕ 才出输入框)、没垂直居中、原语乱」→ **3-agent 审计 + 全量重写**:①KV value **贴右还原**(wrap 降为行级只读参数,assert 拦 editable+wrap;编辑值恒单行贴右)②**统一触点轨契约**(controlSm 最右轨:铅笔/➕/select 缩进/只读占位,`_railed` 一处判定;替换 `_hasEditAffordance` 补丁)③**标签行重做**:静态净药丸贴右垂直居中(非 wrap 几何)、hover→✕/➕、**按 ➕ 才挂自聚焦输入框**(`AnTags.showAddField` 三态受控 + `onAddDismissed`;Enter 连加[`AnInput.onEditingComplete` 透传压 Enter 失焦]、Esc 弃草稿、失焦非空提交后收、草稿每次清)④修审计 bug:键盘/读屏死角(➕ opacity-0 常驻可达)、草稿泄漏、flash 按 label、select 行右缘、agent skill 双标题、handler timeout 硬编码、AnSection 子件自加边距、空态统一 insetEmpty;version_tab footer 走 AnTwoZone+AnActionGroup。坑:Wrap 里裸 `Align` 撑满整行(须 widthFactor:1) | ✅ 已落(fe-verify **1347 绿**;静态/hover/添加中三截图过) |
| 后续(审计遗留,并入 F3/后续批) | run 岛四缺口:AnInspector head 加 actions/meta 槽(RunTerminal 停止手搓头)· AnFormField(竖排 label+control 表单原语,run_input_form 的 16px strong 手搓标签归位)· AnDivider hairline · 终端 mono 面统一 `AnText.code`;version/log load-more 走 AnActionGroup;desc 行四 kind 统一 | ⏳ |
| F3 | 右岛结果按签名渲 + hero 活态接 run 流 | 待建 |

每批:gallery → 接线 → 截图过目 → fe-verify 绿 → 文档同步。
