# EDGE-351 | 429 不动钱 | L4 真实 App 证据

## 判定

L4 通过，法典 `C4`：限流错误态的文案、错误卡、Retry 菜单和 Composer 在真实窗口中保持清晰、稳定、可操作。

## 视觉复核

真实 App 的错误消息完整显示为 `The model service is temporarily busy. Please try again shortly.`，没有泄漏
`429`、`RATE_LIMITED` 或内部网关细节。错误卡与用户消息保持正常垂直节奏，Composer 没有被遮挡或锁死；点击
Retry 后菜单可见，选择入口不会制造重复用户消息、白屏或布局跳变。窗口录屏保持 `3104x1848 / 60fps`，
没有发现 RenderFlex、溢出、残留 Live 状态或异常焦点转移。

## 五通道与台架

- 录屏=`/private/tmp/anselm-rig-formal-20260902-31/sessions/20260902-053825/screen.mov`，`234.080000s`。
- llmtap 的真实 response body 明确为 `RATE_LIMITED`；旧错误 fixture 的红证据单独保留，未覆盖最终现场。
- `rig-check.sh`、`rig-down.sh` 通过，backend、三路 SSE、frontend console 均无应用级红线，owned processes 已收台。

## 结论

最终视觉状态准确表达“暂时繁忙”，既不夸大为额度耗尽，也不通过隐藏错误或缩短文案来掩盖失败。
