# EDGE-345 | 音色登记→指名说话全链 | L4 真实 App 视觉证据

## 判定

L4 通过，法典 `C4`：圆角遵循五档尺度阶梯，胶囊使用 pill；同心嵌套保持内半径与内缩关系。

## 证据范围

- 真实 App session：`/private/tmp/anselm-rig-formal-20260902-17/sessions/20260902-040120/`
- 主证据：封存后的 `screen.mov`，`3104x1848`、`60fps`、`361.696667s`
- 复核状态：上传音频后的 Chat、危险确认层、登记/合成进行中、完成后的 Settings → Models & keys、删除确认层、删除后的克隆音色空态

## 视觉复核

- Chat 中上传音频卡、用户消息气泡、工具执行行和底部 Composer 的层级清楚，工具执行期间没有把输入区挤出视口或留下 Live 残留。
- Models & keys 的 Free tier、Cloned voices 和 Model keys 卡片共享一致的卡片圆角、内缩和左右边界；克隆音色行的 hover Delete affordance 与行高对齐。
- 删除确认层在克隆音色卡内部展开，浅红色危险容器与外层卡片保持同心内缩，标题、说明、确认输入框和 Cancel/Delete 按钮均完整可见，没有文字溢出、裁切或按钮重叠。
- 删除完成后的 `No cloned voices yet` 空态保留同一卡片形状，图标、两行说明和 `2 of 2 slots free` 底部计数形成稳定层级；没有空白残片、跳变或墓碑式错误文案。
- 侧栏导航、设置标题和内容卡片的基线与间距在进入/退出设置时保持稳定；录屏稳定段没有自主位移或白闪。

## 数据与台架对证

- 五通道有效性沿用同场 L3 证据：backend 无应用级红线，frontend 只有已分类 macOS IMK 宿主诊断，SSE durable seq 单调，LLM wire 的登记、合成和删除响应成功，录屏由 `rig-down.sh` 正常封存。
- Settings 画面在登记后显示 `1 of 2 slots free`，删除确认层保持该事实；上游删除 `204` 和本地删除 `204` 后，画面显示 `2 of 2 slots free`，与后端列表为空一致。
- 本判定只针对本轮真实 App 的视觉 craft，不把单张截图或工具 wire 代替逐帧观察；没有修改 C4 标准或任何视觉阈值。
