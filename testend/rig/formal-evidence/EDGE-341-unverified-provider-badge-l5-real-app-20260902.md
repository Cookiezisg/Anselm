# EDGE-341 · 未验证供应商诚实徽标 · real App L5

## 盲走路径

从真实 App 的 Settings 面板开始，仅以普通用户目标“添加一个 302.AI 密钥并检查连接”
寻找入口，不使用 coverage 编号、内部 ID 或测试脚本名：

1. 在左侧 Resources 下找到 `Models & keys`。
2. 在 `Model keys` 区找到 `Add key`。
3. 在供应商目录中看到 `302.AI`、模型数量和 `Untested` 徽标，选择该供应商。
4. 在表单填写名称和隔离测试 key，保留目录给出的 Base URL，点击 `Save & test`。
5. 失败后，页面明确给出“key 已保存但探针失败”，并说明这家供应商我们从未测试过；
   用户知道应检查自己的 key，同时也知道问题可能在产品侧。

## L5 判定（G1）

入口命名和位置与用户目标一致，不需要了解 `curated`、`models.dev`、`API_KEY_TEST_FAILED`
或 `302ai` 这些内部概念。`Untested` 徽标在用户投入密钥之前就给出风险预告，失败后的
诊断又把责任边界讲清楚，没有让用户盲目重复复制 key。添加、保存和重试入口都在用户
可理解的设置路径内。

真实录屏覆盖了从设置到供应商目录、表单和失败诊断的完整路径；使用的是隔离 fixture，
不含真实凭证，也没有把测试数据写入产品工作区。

## 五通道

- 帧：真实 App `screen.mov`、目录帧和失败稳定帧。
- backend：供应商目录 `200`、隔离 key 创建 `201`、探针 `422`，与页面事实一致。
- SSE：messages/entities/notifications 三流均连接并正常收台；本场景无 durable 业务帧。
- frontend：无未解释 Dart/Flutter/layout/runtime 红线；macOS IMK 提示是宿主噪声。
- LLM wire：managed challenge/install/models/quota=`200`；本路径不需要 completion。
