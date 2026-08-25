# EDGE-341 · 未验证供应商诚实徽标

## L1 focused evidence

- `frontend/test/features/settings/provider_market_test.dart` 通过：未 curated 的 provider 显示 `unverified` 数量与诚实 hint；从未测试的 provider 失败时给出先核对 base URL/供应商的诊断方向。
- 已 curated provider 不显示多余的“未验证”怀疑文案，避免对真实探测结果反向降级。

## 判定

L1=`E4`：能力目录对“目录存在”和“本机已验证”做诚实区分，不把未验证供应商伪装成可靠路由。L2-L5 本批未启动真实 App，记 `na`。
