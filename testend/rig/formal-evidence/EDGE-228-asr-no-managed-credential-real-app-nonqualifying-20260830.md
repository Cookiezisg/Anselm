# EDGE-228 ASR sidecar 无受管凭证 · 真实 App 非放行记录

- 日期：2026-08-30
- 判定：**不放行**；本记录不是 `L2-L5` 通过证据

## 已观察事实

在隔离工作区删除受管 Anselm 凭证、保留文本模型路由后，真实 Anselm App 成功启动。Composer 的可访问性树只有 `Mention an entity`、`Attach files` 和文本输入框，没有语音输入按钮；画面中的空 Chat 也没有语音入口。该状态符合“无受管凭证时不展示注定失败的 ASR 入口”的产品事实。

本次 session 的独立 SSE witness、LLM tap 和后端均已启动，`rig-check` 确认 backend health、三条 SSE 连接、LLM tap 归属和 App 进程归属正常；没有执行语音请求，也没有调用 BYOK 适配。

## 放行阻断

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-060148` 的 `rig-check.sh` 明确失败：`SecurityAgent` 与 `CoreServicesUIAgent` 系统窗口覆盖 Anselm 录屏区域。因此不能满足正式 L2 的无遮挡录屏条件，也不能把本次观察写成完整五通道产品证据或 L3-L5 结论。

本次只验证了无凭证状态的入口缺席，不验证真实受管 ASR、麦克风授权或语音错误反馈。L1 保留既有 focused evidence，L2-L5 继续未完成并转入人工尾队。

