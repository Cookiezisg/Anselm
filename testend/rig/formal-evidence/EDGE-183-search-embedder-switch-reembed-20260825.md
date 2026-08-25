# EDGE-183 换 embedder 重嵌

- 结论：`pass`（L1 model-key/cache contract + real HTTP settings regression）；L2-L5 按当前独立台架边界记 `na`。
- 预期：从 builtin 切到 Ollama 时，旧 model 的向量不能混入新 model；workspace vector cache 必须失效，
  缺新 model 向量的行由 backfill 重新计算。只换 Ollama base URL 而不换 model 时不应无谓丢弃模型账。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/search \
  -run '^(TestSettings_SwitchAndValidate|TestSettings_SwitchInvalidatesCacheAndSeparatesModels|TestSettings_PatchIsAtomicAndFansOutToIndexedWorkspaces)$' \
  -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/search 1.545s
```

新增 `TestSettings_SwitchInvalidatesCacheAndSeparatesModels` 先加载 `m1` cache，再切换到
`ollama:embeddinggemma`，断言旧 `m1` 向量不出现在新 model 集合、workspace 全扫次数由 1 增至 2。
相邻回归还验证 adapter factory 使用生效 URL/model，以及 settings 写成功后向每个已索引 workspace fan-out kick。

## real black-box regression

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestSearch_ReindexAndSettings$' -count=1 -v -timeout 600s
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 5.824s
```

真实 HTTP 场景创建可检索实体，验证 reindex 命中、`embedder=off` 后 lexical search 仍可用，随后将
Ollama 指向关闭端口，settings 仍应用且 search 继续返回 lexical hit。日志中的 `127.0.0.1:1` free-tier
warning 与搜索 fixture 无关，已作为刻意无网关环境披露。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成真实模型切换、重嵌与五通道 App 录制
L3 na: 没有本格独立切换后首个语义结果的 Computer Use 时序测量
L4 na: 没有本格独立搜索设置切换与重嵌状态的视觉成品与 craft 比对
L5 na: 没有本格独立新用户发现并理解重嵌进行中的 discoverability session
```
