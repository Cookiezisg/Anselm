# EDGE-225 · 账本警报独立复审

本复审针对 `2026-08-31` 写入 EDGE-225 五级裁决后打开的两个统计警报，不改变阈值，也不把警报
当作产品通过证据。

## 复审对象

- `gap-too-fast`：五级裁决由同一正式 session 的已完成证据批量写入，账本写入间隔不能代表重新
  观察产品所需的时间；前置的真实 App、录屏、三路 SSE、LLM tap、backend/frontend journal 均已
  在写账前独立检查。
- `discovery-collapse`：本格没有红结果并不意味着全产品无红结果；该统计窗包含本批绿裁决，且
  前序真实测试已有红证据和 stop-and-fix 记录，故不是把本格绿裁决当作全局健康证明。

## 独立核对

- formal evidence=`EDGE-225-real-app-image-capability-honest-absence-20260831.md`
- session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-123648`
- `rig-check` 在裁决前通过，五通道均实际存在；`rig-down` 后进程归零，录屏和 journal 保留
- LLM wire 的工具 schema 没有 `generate_image`，且没有 `/v1/images/generations`；messages SSE 的
  durable close 与 App 最终文案一致；backend/frontend journal 无异常红线
- 首场不合格真实回合的错误引导被保留为反证，修复后的新 build 已重新运行并得到准确 Settings 路径

## 结论

两个警报都反映裁决节奏/样本窗的统计特征，而不是 EDGE-225 证据缺失或产品失败。复审没有发现
需要撤销的五级裁决，也没有理由改写警报规则；按警报协议 ack，并保留本文件作为独立重审证据。
