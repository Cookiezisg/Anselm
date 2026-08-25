# EDGE-339 · BYOK base URL 模板未填占位

## L1 focused evidence

- `frontend/test/features/settings/provider_market_test.dart` 通过：Azure 等模板型供应商进入表单时显示 catalog 的 base URL hint，用户自填地址的认证失败会明确指向 base URL 字段。
- 非模板/用户自定义地址不会被客户端静默改写；失败面保留可操作字段提示。

## 判定

L1=`E1`：用户能看懂哪一个地址仍需替换、下一步是什么，避免把模板占位误当成可用配置。L2-L5 本批未启动真实 App，记 `na`。
