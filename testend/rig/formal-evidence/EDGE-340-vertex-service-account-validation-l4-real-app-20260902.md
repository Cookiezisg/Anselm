# EDGE-340 · Vertex service-account 文件校验 · real App L4

## 现场与证据

- session=`/private/tmp/anselm-rig-formal-20260902-06/sessions/20260902-010913`
- 录屏：`screen.mov`，`3104x1848 / 60fps / 168.698333s`。
- 稳定抽帧：`evidence/vertex-frames-60fps/`；动作抽帧：
  `evidence/vertex-action2-60fps/`、`evidence/vertex-save-60fps/`，并生成对应 contact
  sheet。
- 代表最终状态帧：`evidence/vertex-save-60fps/frame-0168.png`。

## L4 判定（C4）

Vertex 表单清楚区分供应商、名称、`Service account (JSON)` 文件输入、Base URL 和
动作区。无效文件选择后，错误说明紧贴凭证字段，且 `Save & test` 被禁用；没有让用户
先提交一个必然失败的请求。合法结构文件选择后，错误消失，字段高度、按钮位置和表单
宽度保持稳定。

保存后的探针失败状态仍保持同一表单节奏：名称和 Base URL 可读，反馈明确区分“key
已保存”和“connectivity probe failed”，并给出检查 key 或 Base URL 的下一步。服务账号
输入在保存后回到 `Leave empty to keep the current key` 占位，表示已有密钥可重试，不是
把保存成功隐藏掉，也不是绕过无效文件校验。

逐帧复核与局部差分显示：

- 文件选择器切换、无效文件反馈和合法文件反馈均在预期交互区域内；没有整页闪烁、列
  跳变、字段高度改变、裁切或重叠。
- 保存动作局部差分：`frame-0165→0166` changedFrac=`0.00729`，框
  `(1200,1182)-(1681,1238)`；`frame-0167→0168` changedFrac=`0.04265`，框
  `(1200,689)-(2168,1350)`；后续变化仍局限于反馈区。
- `measure latency`：action=`165`，feedback=`167`，`33.3ms`；不是用截图主观推断
  响应速度。

## 五通道

- 帧：连续录屏、60fps 动作抽帧与最终稳定帧。
- backend：凭证保存 `PATCH 200`，伪造 PEM 的真实探针 `422`，错误状态可解释且可重试。
- SSE：三条独立流连接/断开完整，设置路径无 durable 业务帧。
- frontend：console 无未解释应用异常或布局红线。
- LLM wire：managed challenge/quota `200`；此路径没有 completion。
