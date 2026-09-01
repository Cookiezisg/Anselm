# EDGE-339 · BYOK base URL 模板未填 · real App L5

## 盲走路径

从真实 App 的 Settings 面板开始，仅以普通用户目标“添加一个 Azure 模型密钥并检查连接”
寻找入口，没有使用 `EDGE-339`、内部 ID 或测试脚本名：

1. 进入 `Models & keys`。
2. 在 `Model keys` 区找到 `Add key`。
3. 在供应商目录中找到 `Azure` 并打开添加表单。
4. 表单将 Base URL 直接标为 `Required`，并给出可照抄的模板及“替换占位符”动作指引。
5. 提交后，错误状态同时说明保存结果、探针失败事实和“检查 key 或 Base URL”的下一步。

## L5 判定（G1）

入口名称与用户目标一致，供应商目录有清晰的厂商身份，模板提示回答了“占位符在哪里替换”，
失败后没有让用户盲目反复复制 key，而是把 Base URL 作为同等可能原因点名。用户无需知道
`baseUrlTemplateHint`、`API_KEY_TEST_FAILED` 或任何后端协议即可继续修正表单。

真实录屏覆盖了从 Settings 到 Azure 表单、占位地址、保存与失败反馈的完整可导航路径；
最终没有留下测试数据在产品环境，本次凭证只存在于隔离 acceptance 数据目录。

## 五通道

- 帧：真实 App `screen.mov` 与抽帧证据。
- backend：供应商目录读取、凭证更新和探针结果均有 journal。
- SSE：三条 workspace stream 均在线。
- frontend：无未解释 Dart/Flutter/布局红线。
- LLM wire：managed challenge/quota `200`，本目标不需要 completion，未把无调用写成成功调用。
