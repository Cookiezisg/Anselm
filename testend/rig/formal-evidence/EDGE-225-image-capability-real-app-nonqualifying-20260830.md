# EDGE-225 能力工具诚实缺席 · 真实 App 非放行记录

- 日期：2026-08-30
- 判定：**不放行**；本记录不是 `L2-L5` 通过证据

## 已观察事实

在隔离数据目录中删除所有生成能力 key，仅保留一个文本模型路由后，启动真实 Anselm App。应用完成一次真实对话回合，界面显示“没有可用的图像工具。”，没有出现 `generate_image` 工具卡或生成产物。

同一 session 的 LLM wire body 显示工具列表只有 13 个驻地工具：`Read`、`Write`、`Edit`、`LS`、`Glob`、`Grep`、`Bash`、`BashOutput`、`KillShell`、`ask_user`、`todo_write`、`todo_read`、`search_tools`；`generate_image` 不在列表中。SSE 三条流均建立，messages durable seq 连续记录回合完成，backend/frontend journal 未发现应用级 panic、Flutter/Dart、RenderFlex、Unhandled 或 `LLM_STREAM_ERROR`。

## 放行阻断

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-055055` 的 `rig-check.sh` 明确失败：`SecurityAgent` 与 `CoreServicesUIAgent` 系统窗口覆盖了 Anselm 录屏区域。因此不能满足录屏无外部遮挡的正式 L2 条件，也不能把这次 session 写成真实视觉或逐帧放行证据。

此外，Computer Use 输入桥把本轮原本的中文请求记录成了异常的 `，，`。因此界面中的中文“没有可用的图像工具”只能证明缺图像能力时的诚实反馈被观察到，不能作为干净中文用户意图下的完整目的达成结论。

本次使用的是临时兼容上游，不是受管 Anselm 网关；没有真实生成调用、没有花费生成配额。因此本记录只保留为非放行现场记录，L2-L5 继续未完成并转入人工尾队。
