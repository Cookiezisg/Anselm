# EDGE-184 短词 LIKE 回退

- 结论：`pass`（L1 lexical routing/store contract）；L2-L5 按当前独立台架边界记 `na`。
- 预期：短于 trigram 窗口的 token 不能因 FTS/MATCH 零命中而消失；纯短词走 LIKE，长短混合时长 token
  负责 FTS 收窄、短 token 继续以 LIKE 叠加过滤，结果必须是合取而不是任一词命中。

## focused regression

```text
cd backend && mise exec -- go test ./internal/infra/search ./internal/domain/search \
  -run '^(TestSearch_ShortQueryLikeFallback|TestSearch_MixedTokensAreConjunctive|TestParseQuery_TokenRouting)$' \
  -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/infra/search 1.668s
ok  github.com/sunweilin/anselm/backend/internal/domain/search 2.040s
```

`TestSearch_ShortQueryLikeFallback` 用两字符中文标题验证 LIKE 命中、snippet 高亮和 title score；
`TestSearch_MixedTokensAreConjunctive` 用一个长 token 加一个短 token 验证 FTS+LIKE 叠加后只保留
同时满足两者的文档；`TestParseQuery_TokenRouting` 锁住两字符中英文都进入 short bucket。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成真实 App 短词/混合搜索与五通道录制
L3 na: 没有本格独立输入查询到首个结果的 Computer Use 时序测量
L4 na: 没有本格独立短词高亮与混合过滤结果的视觉成品与 craft 比对
L5 na: 没有本格独立新用户发现并理解短词搜索回退的 discoverability session
```
