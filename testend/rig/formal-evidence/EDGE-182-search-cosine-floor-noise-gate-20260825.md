# EDGE-182 cosineFloor 噪声闸

- 结论：`pass`（L1 hybrid-search noise-gate contract）；L2-L5 按当前独立台架边界记 `na`。
- 预期：自然语言乱码的 semantic-only 向量若低于 cosine floor 不得污染结果；identifier-shaped 乱码即使
  cosine 高于 floor，也不得在没有 lexical evidence 时召回实体。真实语义匹配在 floor 以上仍必须保留，不能
  用噪声闸牺牲 recall。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/search \
  -run '^(TestHybrid_CosineFloorAdmitsGenuineMatch|TestHybrid_IdentifierQueryRejectsSemanticOnlyNoise)$' \
  -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/search 1.288s
```

`TestHybrid_CosineFloorAdmitsGenuineMatch` 同时放入 cosine `0.62` 的真实匹配和 cosine `0.53` 的乱码，
断言前者命中、后者被 `0.55` floor 拦截；`TestHybrid_IdentifierQueryRejectsSemanticOnlyNoise` 用 opaque
identifier-shaped query 验证即使 cosine `0.63` 高于 floor、且没有词法证据，也不产生 semantic-only agent hit。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成真实语义检索与五通道 App 录制
L3 na: 没有本格独立乱码检索到首个可见结果的 Computer Use 时序测量
L4 na: 没有本格独立搜索结果噪声/空结果视觉成品与 craft 比对
L5 na: 没有本格独立新用户发现并理解搜索噪声过滤的 discoverability session
```
