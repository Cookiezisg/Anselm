# EDGE-339 · BYOK base URL 模板未填 · real App L4

## 现场与证据

- session=`/private/tmp/anselm-rig-formal-20260902-04/sessions/20260902-004134`
- 录屏：`screen.mov`，`3104x1848 / 60fps / 46.650000s`。
- 稳定帧与局部接触表：`evidence/form-contact-49.png`、
  `evidence/form-transition-141-156.png`。
- 提交前后的 60fps 局部变化仅落在 Base URL、反馈文案和按钮状态区域；没有整页闪烁、
  内容跳列、字段高度改变、裁切、重叠或不可逆的布局位移。

## L4 判定（C4）

Azure 表单把供应商身份、`Name`、`Key`、`Base URL` 和动作区按稳定纵向节奏排列。模板型地址
的说明直接贴在 Base URL 标签下：`Required — replace the placeholder: https://{resource}.openai.azure.com`；
提交失败后，地址字段仍可读，警告说明紧邻该字段，成功保存与探针失败使用不同层级，
`Save & test` 和 `Cancel` 的位置保持稳定。

逐帧复核代表帧显示：

- 模板提示没有被错误摘要覆盖；
- 失败说明没有遮住按钮或字段；
- 真实错误事实 `api key probe failed` 与可行动的人话建议分层呈现；
- 表单的宽度、对齐、圆角和留白在加载/失败稳定态一致。

局部差分（每通道容差 8）在提交转场只报告表单区域；稳定错误尾段没有超过阈值的持续
全局 reflow。该结论来自录屏帧和 `measure diff/latency`，不是单张截图印象。

## 五通道

- 帧：真实 App 连续录屏与抽帧。
- backend：真实 `PATCH 200`、探针 `422`，错误状态持久存在。
- SSE：三路独立 witness 均连接并正常收台。
- frontend：console 无应用级异常。
- LLM wire：受管线缆 ready，challenge/quota `200`；该设置路径不调用 completion。
