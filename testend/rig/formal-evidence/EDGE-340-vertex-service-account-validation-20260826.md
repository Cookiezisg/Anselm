# EDGE-340 · Vertex service-account 文件校验

## L1 focused evidence

- `frontend/test/features/settings/s2_models_keys_test.dart` 的 provider/form 状态机回归通过；后端 model/key resolver 与 API key package 通过 backend targeted tests。
- 服务账号字段校验在提交前拒绝缺少 `type`、`project_id` 或 `private_key` 的 JSON，合法结构才进入探测/保存路径。

## 判定

L1=`E1`：结构错误在用户输入面被明确拒绝，不把上游认证异常延迟成难以排查的调用失败。L2-L5 本批未启动真实 App，记 `na`。
