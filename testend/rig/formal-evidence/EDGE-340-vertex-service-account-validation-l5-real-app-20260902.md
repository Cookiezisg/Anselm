# EDGE-340 · Vertex service-account 文件校验 · real App L5

## 盲走路径

从真实 App 的 Settings 面板开始，仅以普通用户目标“添加 Vertex service account 并
检查连接”寻找入口，不使用内部 ID、coverage 编号或测试脚本名：

1. 进入 `Models & keys`。
2. 在 `Model keys` 区找到 `Add key`。
3. 在供应商目录中选择 `Vertex`。
4. 选择 `Service account (JSON)` 文件；文件缺少必需字段时，表单直接说明需要
   `type`、`project_id` 和 `private_key`。
5. 选择合法结构文件后执行 `Save & test`；若连接探针失败，页面保留保存结果并给出
   检查 key 或 Base URL 的下一步，而不是只显示不可行动的内部错误码。

## L5 判定（G1）

入口、供应商名称和文件动作符合普通用户的目标。错误信息直接说明文件需要什么，用户
不需要理解 `serviceAccountBad`、`API_KEY_TEST_FAILED` 或后端 API。无效文件不能误保存，
合法文件才进入检查；连接失败也明确告诉用户下一步，且允许保留表单信息进行修复和重试。

真实录屏覆盖了从 Settings 到 Vertex 表单、文件选择、即时校验、合法文件提交和探针
失败反馈的可导航路径。凭证为隔离 fixture，`private_key` 不是真实密钥，不向外部服务
发送用户秘密。

## 五通道

- 帧：真实 App `screen.mov` 与动作抽帧证据。
- backend：供应商读取、保存和探针结果均有 journal，失败事实与用户反馈一致。
- SSE：messages/entities/notifications 三条 workspace stream 均连接并正常收台。
- frontend：无未解释 Dart/Flutter/布局异常。
- LLM wire：managed challenge/quota `200`；本场景不调用 completion，未把无调用冒充
  成模型成功。
