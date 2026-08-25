# EDGE-178 搜索 embedder 缺席降级

- 结论：`pass`（L1 service/domain + real black-box search contract）；L2-L5 按当前独立台架边界记 `na`。
- 预期：embedder 被关闭，或语义 provider 不可用时，混合搜索必须透明降级到词法 BM25；设置请求成功，检索不报错、不丢 lexical hit，也不要求用户理解内部引擎故障。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/search \
  -run '^TestHybrid_DegradesWhenProviderFails$' -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/search 1.915s
```

`TestHybrid_DegradesWhenProviderFails` 先让 provider 返回错误，确认原有 lexical hit 仍返回且无 error；再将
`embedder` 设为 `off`，确认完全跳过融合后仍返回同一 lexical hit 且无 error。

## real black-box regression

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestSearch_ReindexAndSettings$' -count=1 -v -timeout 600s
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 4.679s
```

真实 testend 启动服务后创建可检索 function，验证 reindex 后命中；读取默认 settings；将 workspace 的
embedder 切换为 `off`，确认 engine status 为 `off`、另一 workspace 观察到同一机器级设置，且 lexical
query 仍命中。随后将 Ollama 指向关闭的本地端口，settings 仍成功应用，搜索继续返回 lexical hit；测试结束
时服务优雅关停。日志中的 free-tier install warning 是该场景刻意使用 `127.0.0.1:1` 的无网关 fixture，
与搜索断言无关，未把它当成产品绿证据。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成五通道 App 录制
L3 na: 没有本格独立 Computer Use 视觉时序与等待反馈测量
L4 na: 没有本格独立搜索降级 UI 的视觉成品与 craft 比对
L5 na: 没有本格独立新用户发现并理解语义搜索缺席状态的 discoverability session
```
