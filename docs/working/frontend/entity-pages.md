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

> 总纲:十实体逐个雕琢实体页(概览 hero 可视化 + 编辑草稿模式 + 版本结构化 diff + 右岛升级),每实体定稿后 revisit 其 chat 工具卡。顺序 function → (后续逐个聊)。共享原语下沉 `core/ui`、gallery-first。

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
| F2 | 写面(repository `patchFunctionMeta`/`revertVersion` kind 通用,Live+Fixture 双实现)+ **meta 就地编辑**(页头改名 `AnOceanHeader.onTitleChange` + 概览说明 `AnField editable` + 标签 `_TagsMetaField`,均 PATCH 不升版)+ 版本 tab 结构化签名 diff 小签(`functionVersionSummary` 纯函数)+「设为活跃版本」(`:revert`) | ✅ 已落(含 review 重写) |
| F2-fix | 概览 meta review 重写:①说明+标签同 `AnLeadValue` 几何(标签列对齐,原手搓 120px Row 弃)②标签读优先(静态只读药丸、hover 铅笔 → 可编辑 `AnTags`,不再常驻 ×/添加框)③版本 tab **diff 置顶**、摘要小签+「设为活跃」移到 diff **下方 footer**(选版本不再跳)④`setActive` 就地重算 active 标记(选区不回弹最新)+ 防重入 pending + 失败 toast ⑤`VersionRow` 升 freezed 值类型 + `selectedIndex` 防越界 | ✅ 已落(12 测 + 读态/版本双截图过;拍板:版本内容 AI-only、手工仅 meta) |
| F3 | 右岛结果按签名渲 + hero 活态接 run 流 | 待建 |

每批:gallery → 接线 → 截图过目 → fe-verify 绿 → 文档同步。
