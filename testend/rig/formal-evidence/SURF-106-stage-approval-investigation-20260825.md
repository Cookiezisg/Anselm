# SURF-106 · stage/approval 调查与五级判定依据

日期：2026-08-25
前线：`SURF-106 stage/approval`
正式 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-085143`

## 结论

本格在 stop-and-fix 后正式通过。真实 App 通过受管 Anselm 网关创建 `SURF106-approval-clean` v1，展开 Activity 中的审批预览卡片，用户可直接看到模板插值、`2h` 超时、`2h 后自动拒绝`、`可填备注` 与批准/拒绝动作。无布局溢出、内容跳变、重复 mutation 或错误成功色。

首轮同一台架中，Computer Use 的 AX 输入桥把模板截断并污染了旧对话；随后模型在旧实体上走了 edit 路径。两者均不是本格的产品正向证据，保留在原 session 日志中但不计入绿判。重新开启干净对话并用可见输入框键盘路径输入后，正向路径只创建一次目标实体，以下证据均以该干净场次为准。

## Stop-and-fix

静态审查发现托管模型的兼容形状没有被前端完整消费：`allowReason` 和 `timeout` 可能是闭合 JSON 中的字符串，timeout 以秒数表示；原实现只认原生布尔值和原始 timeout 字符串，导致审批预览的备注开关和人话时长可能缺失。修复内容：

- `frontend/lib/features/chat/ui/tool_card_control_approval.dart` 统一读取原生/字符串化 scalar，并把整秒转换为 `m/h/d/w`；无效或零值不显示成 `0w`。
- `frontend/lib/features/chat/ui/stages/approval_stage.dart` 复用同一解析 seam，live stage 与 settled card 不分叉。
- `frontend/test/features/chat/ui/tool_card_control_approval_test.dart` 锁定 `"true"`、`"7200"`、`2h`、备注 chip，以及零值 `0s`。

Focused Flutter：`22/22`（含 `tool_card_control_approval_test.dart`、`stages_w3_test.dart`、`stage_alignment_test.dart`）。

## 五通道

### 1. 画面与 AX

干净对话消息为创建目标，右侧 Activity 展开后 AX 同时呈现：

- `审批人将看到`
- 模板正文，`amount` 与 `vendor` 为独立内联高亮 capsule
- `2h`
- `2h 后自动拒绝`
- `可填备注`
- `批准` / `拒绝`

最终画面保存在 session 的录屏中；Computer Use 采集的展开态截图在本回合复核。没有卡片重叠、截断、横向溢出或非用户触发的滚动跳变。录屏封口总时长：`362.563333s`。

### 2. Backend journal

后端 PID=`6955`，D1 归属与 health 通过。目标创建返回成功，随后 GET detail 返回同一实体：

- approval=`apf_df59b6227e75ab34`
- version=`apfv_5bad23076ff05907`
- name=`SURF106-approval-clean`
- inputs=`amount:number`、`vendor:string`
- `allowReason=true`
- `timeout=2h`
- `timeoutBehavior=reject`

backend journal 没有应用级 `WARN/ERROR/panic/fatal`。手工核验期间曾对缺少 workspace header 的 `/api/v1/approvals` 发起一次未授权请求，返回 `401 UNAUTH_NO_WORKSPACE`，这是观测器探针，不是 App 请求，也不计作产品错误。

### 3. SSE witness

独立 ssetap 同时监听三条流：

| stream | durable seq | 唯一 | 单调 | 关键事实 |
|---|---:|---|---|---|
| messages | `1..53` | 是 | 是 | create tool call、tool result、assistant close |
| notifications | `1..7` | 是 | 是 | `approval.created` 与自动标题 |
| entities | `1..2` | 是 | 是 | 实体索引更新 |

其中 messages `seq=45` 是带完整 stringified scalar 参数的 `create_approval` tool call，`seq=48` 是成功 tool result；没有重复 durable seq 或缺口。

### 4. Frontend console

frontend journal 只有 Dart VM 启动信息和已知 macOS `IMKCFRunLoopWakeUpReliable` 平台噪声；未发现 Flutter/Dart exception、RenderFlex/布局溢出、Unhandled rejection 或死循环。`rig-check`、`rig-down` 通过，收台无残留。

### 5. LLM wire

managed gateway challenge/install/models 与本格 9 次 chat completion 均 HTTP `200`。最终成功请求的 tool call 参数在 `llm.jsonl` 与对应 body/response 文件中可重取，关键字段为：

```json
{
  "name": "SURF106-approval-clean",
  "allowReason": "true",
  "timeout": "7200",
  "timeoutBehavior": "reject"
}
```

本请求仅一次 `create_approval`，后端返回 `activeVersionId`，没有隐式 retry 或重复创建。

## 五级判定

- L1 achieved：`E2`，真实创建目标审批表单并在 App 中可继续使用。
- L2 truth：`F2`，画面、REST/backend、SSE、LLM wire、frontend console 五通道互证。
- L3 smooth：`B2`，live/settled 共用解析 seam，timeout 有人话标签，失败态不冒充成功态；focused stage alignment 通过。
- L4 craft：`C4`，插值胶囊等高、规则 chip 同层、动作行稳定，无 clipping/overlap/reflow。
- L5 discoverability：`G1`，右侧 Activity 触点明确标出实体名与“创建”，展开后直接给出审批人视角和下一步动作。

账本写入时使用本文件作为 L1/L3/L4/L5 证据，使用 session evidence 作为 L2 证据。
