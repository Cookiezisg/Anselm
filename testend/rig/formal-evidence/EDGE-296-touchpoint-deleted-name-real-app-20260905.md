# EDGE-296 · 触点 deleted 行借名 · 真实 App 五通道证据

## 场景

在真实 macOS Anselm App 中创建一个仅用于本场景的 Agent，名称为
`EDGE296 deleted-name 1788553425`，在新对话中让 Anselm 删除它。该 Agent 在此
对话此前没有任何触点，因此删除时不存在可借用的历史名称。

## 五通道结果

- **App/录屏**：真实 App 完成搜索、危险操作确认、删除和最终收尾；打开 Chat 的
  Activity 面板后显示 `ag_d0e39f802d114fca` 与 `Deleted`，没有伪造或借用的实体名称。
  录屏帧见同一 session 的 `evidence/activity-final.png`，完整录像为 `screen.mov`。
- **后端/REST**：`GET /conversations/cv_4272cd53c40f0f9b/touchpoints` 返回一条
  `itemKind=agent`、`verb=deleted`、`count=1` 的记录，且 `itemName` 为空；被删
  Agent 的详情请求返回 `AGENT_NOT_FOUND`。
- **SSE**：同一 session 的 `sse.jsonl` 记录了删除后的 `agent.deleted` 通知、
  `deleted` touchpoint signal、tool result close 和完整 message close，durable
  seq 单调，没有孤立删除帧。
- **前端终端**：`frontend.log` 没有 Flutter/Dart 异常、布局异常或应用 panic；唯一
  error 文本是已知 macOS 输入法 mach-port 日志。`rig-check.sh` 在收台前通过五通道
  物理归属检查。
- **LLM wire**：`llm.jsonl` 与 `llm-bodies/00006_v1_chat_completions.bin` /
  `llm-responses/00006_v1_chat_completions.bin` 属于同一真实回合；工具结果报告
  `deleted=true`、历史保留且关系边数量为 0，最终文本与执行结果一致。

## 判定

- **L1 = F1**：与既有 focused 测试共同证明未触碰实体的删除行保持诚实空名，不从
  无关兄弟借名。
- **L2 = F1**：真实 App、REST、SSE、前端终端、LLM wire 与最终 Activity 呈现均来自
  session `20260905-042111`，五通道事实一致。
- **L3 = A4**：删除动作在确认等待期间有明确状态，完成后 Activity 与 transcript
  收尾，没有无反馈的长等待或重复操作。
- **L4 = C4**：最终 Activity island、删除行和 transcript 的间距、圆角和层级连续，
  未见截断、跳变、重叠或不一致的交互反馈。
- **L5 = G1**：操作完成后 Activity 入口在 Chat 顶部可见；打开后以单行计数和实体
  状态呈现结果，删除实体不要求用户猜测一个不存在的名称。

## 旁观观察

测试名称含数字后缀时，受管网关生成的最终自然语言把该后缀改写成了英文短语；
请求体、搜索 thought、删除结果和 Activity 台账仍保留真实值。这不改变本边界的
空名判定，但应作为后续自然语言保真度回归的独立观察，不能被当作成功文本证据掩盖。
