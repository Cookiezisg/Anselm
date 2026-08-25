# SURF-108 stage/subagent investigation

## Scope

验收 `stage/subagent`：一席一卡；卡头使用 `args.prompt` 首行；live 期间显示 ReAct 当前尾与内联终端；settle 期间显示状态、token/stop 元数据；界面、后端、SSE、LLM wire、前端日志五通道一致。

## Static contract

- `frontend/lib/features/chat/ui/stages/subagent_stage.dart` 的 `subagentTaskLabel` 从真实 schema `{subagent_type,prompt}` 读取 `prompt` 首行。
- `SubagentStageBody` 只消费本行 `StageScene`，不会把导演器全局 channels 重复渲染。
- live 判定走 execution phase 的 tool-result bracket，不把参数 close 当成分身终态。
- `_liveProgressTail` 只取当前打开工具的 progress，并由 `tailLines(..., 10)` 封顶。
- settle 元数据同时读取 live nested message close 与 reload 后 tool-call lifted fields。

## Real run

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-093437`
- workspace: `ws_ef0727b1f151cce9`
- conversation: `cv_645739837b596390`
- app window: `2044`, backend `12095`, ssetap `12115`, llmtap `12077`
- LLM requests crossed the real upstream `https://api.anselm.website`

### Positive path

用粘贴保留下划线的请求执行了真实 `general-purpose` Subagent：

1. SSE `messages` durable frames 记录 `Subagent` tool call，参数为 `subagent_type=general-purpose`。
2. 嵌套 assistant message 带 `subagent:true`，并以父 tool-call block 建立关系。
3. 子代理调用 `Bash`，progress 与 tool_result 依次写入 SSE；终端输出为三行 `SURF108 terminal probe 1/2/3`，退出码 0。
4. 真实界面 live AX 显示“正在派子代理… general-purpose”，活动区显示“实时聆听中 · 落定以真相为准”。
5. 结算后侧幕单卡显示任务名、`Bash`/ReAct 尾、终端输出与绿色结算；对话正文同样显示三行结果和退出码 0。
6. 视觉帧留存于 `sessions/20260825-093437/evidence/SURF-108-stage-subagent-settled.png`，分辨率 `2784x1808`。

### Negative paths deliberately retained

- 第一条输入经逐字输入桥丢失 `_`，模型按无效 `subagenttype` 退成 `Explore`；SSE 证明 Explore 只读白名单，Bash 被诚实拒绝。该结果不能计绿，但证明输入桥和能力边界没有被隐藏。
- 同一请求中的错误文件名 `subagentstage.dart` 被子代理如实报不存在；顶层回复引用正确路径只是模型上下文补偿，不把失败伪装成子代理成功。
- backend journal 仅有两条工具层 fallback WARN（Grep context canceled），没有 panic、fatal 或前端 Dart exception；IMK 的 macOS 平台噪声仍是已知非产品红线。

## Verdict basis

正向 general-purpose 路径满足任务名、ReAct、真实 Bash、progress、tool_result、nested subagent、settle 双源和前端展示；Explore/错误路径按负证据保留。提交 judge 前必须先 `rig-down.sh` 结束录屏，使 `screen.mov` 完整落盘。
