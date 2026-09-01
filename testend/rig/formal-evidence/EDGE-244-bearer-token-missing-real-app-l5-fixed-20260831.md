# EDGE-244 bearer token 缺失：真实 App L5 修复复验

- 正式 session=`/private/tmp/anselm-rig-formal-20260831-13/sessions/20260831-175540`，从普通 Anselm App 启动入口开始；用户不需要知道 `ANSELM_AUTH_TOKEN`、`UNAUTH_BAD_TOKEN`、workspace API 或任何台架命令。
- 认证负例触发后，Computer Use AX 树直接暴露一个可读的错误容器：`Restart the local engine`、说明引擎拒绝认证令牌、`Restart the backend, then retry.`，并有可直接点击的 `Retry`。
- 修复后的稳定尾帧没有 raw `ApiException`、HTTP 状态、bearer 文案或内部路径；用户能从标题和动作自然推断下一步，不需要阅读日志或开发文档。
- 同一 session 的录屏与 AX 树一致，错误态没有被 onboarding、空白面或不可操作的静态提示遮挡；Retry 是唯一明确的恢复动作。backend 仍保留真实 401 诊断供工程排错，未把诊断责任转嫁给用户。
- `rig-check.sh`/`rig-down.sh` 通过，五通道证据绑定同一 manifest；本证据只判定入口和恢复动作的可发现性，不把可发现性冒充功能成功。

## Verdict

- L5 `pass`，法条=`G1`：普通用户从启动后的错误入口即可发现原因类别和恢复路径，入口、文案与 Retry 动作均直接可见；无需内部知识。
