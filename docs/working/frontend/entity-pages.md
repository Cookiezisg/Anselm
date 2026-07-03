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

1. **编辑 = 显式草稿模式**(编辑 → 草稿态改 → 保存成新版本 / 放弃),**不做**就地失焦提交。
2. **代码默认收合 50 行 + 渐隐 + 展开**(签名为王,代码是实现细节)。
3. **先做实体页**,chat 卡等实体页全定稿后 revisit。

## 后端写面契约(核实 `references/backend/api.md`,零后端改动)

- `PATCH /functions/{id}` — meta(name/description/tags),**不升版本** → rename/说明/标签。
- `POST /functions/{id}:edit` — ops 构建新版本(function ops:`set_meta|set_code|set_inputs|set_outputs|set_dependencies|set_python_version`;空 ops = 仅重建 env)→ 草稿保存。
- `POST /functions/{id}:revert` — active 指针移到指定版本号 → 版本 tab「设为活跃」。
- `POST /functions/{id}:iterate` — 返 `conversationId` → AI 编辑入口(本轮暂缓,等 chat 卡轮)。

## Function 页 ideal(设计已过用户)

**心智:变换盒** `inputs → [Python] → outputs`,把本质画在页顶。

- **概览三段**:① hero 签名条 `AnTransformBox`(左 inputs 列 / 中心盒[名 + env 灯 + py·deps 徽] / 右 outputs 列,水平切线贝塞尔 hairline 连线——与 workflow 图同款边,首次落地;空签名显示虚线空槽;运行时活:输入亮→盒呼吸→输出亮/失败转红,数据源=右岛同 scope run 流)② 代码段(50 行渐隐收合)③ 环境卡(deps + py + venv 状态合一,envError 红字直出)。meta KV 收进 header 区。
- **编辑(草稿模式)**:header「编辑」进草稿态 → 签名字段增删改 + 代码可编 + deps/py 可改 → 底部粘条「保存(changeReason)/放弃」→ `:edit` ops diff 提交。repository 写面方法做 kind 通用签名。
- **版本 tab**:顶部结构化签名 diff 摘要(字段/依赖级对比)+ code LCS diff 照旧 + changeReason/builtInConversationId(跳对话)+「设为活跃版本」(`:revert`)。
- **右岛**:入参表单(+上次实参回填)→ 流式终端窗保留 → 结果按 outputs 签名逐字段渲(多余/缺字段诚实标出),耗时+logs 折叠。右岛=操作台,页 hero=仪表盘,同源两视角。

## 建造批次

| 批 | 内容 | 状态 |
|---|---|---|
| F1 | `AnTransformBox` + `AnFadeCollapse` 原语(gallery 7+2 specimens)+ function 概览重排(hero + 50 行渐隐代码 + 环境合卡 + envError callout) | ✅ 已落(gallery + demo 页截图过,输出列对齐 & 窄宿主 chip 溢出已修) |
| F2 | 写面(repository `patchFunctionMeta`/`editFunction` ops/`revertVersion` kind 通用,Live+Fixture 双实现)+ 草稿编辑模式(签名字段/代码/依赖/py 可改 → changeReason + 保存/放弃,diff 成 ops 走 `:edit`;无改动保存=放弃)+ 版本 tab 结构化签名 diff 小签(`functionVersionSummary` 纯函数)+「设为活跃版本」(`:revert`) | ✅ 已落(8 测 + 草稿/版本截图过;坑:AnField child 槽与 AutoGrid 均给子件无界宽,编辑行 Expanded/AnDropdown 须避开) |
| F3 | 右岛结果按签名渲 + hero 活态接 run 流 | 待建 |

每批:gallery → 接线 → 截图过目 → fe-verify 绿 → 文档同步。
