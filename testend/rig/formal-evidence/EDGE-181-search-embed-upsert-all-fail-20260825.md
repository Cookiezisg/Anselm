# EDGE-181 整批 embed upsert 全失败

- 结论：`pass`（L1 search backfill bounded-failure contract）；L2-L5 按当前独立台架边界记 `na`。
- 预期：向量表整批写入失败时，backfill 必须结束当前轮次，不能立即反复嵌入同一批形成热循环；缺失向量
  留待下一次 kick 重试，且不能把一次失败伪装成成功。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/search \
  -run '^TestEmbedWorker_PersistentUpsertFailureTerminatesRound$' -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/search 1.544s
```

fixture 让 `UpsertEmbedding` 对整批记录全部失败，backfill 在 3 秒预算内返回；计数器精确断言只
尝试这一批一次，未在当前轮次重新 embed 同一行。由于写入失败，测试保留缺失状态，下一次 kick 的
重试语义由生产 backfill 入口承担。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中制造真实盘满/表损并完成五通道 App 录制
L3 na: 没有本格独立整批写失败到可见终态的 Computer Use 时序测量
L4 na: 没有本格独立搜索错误/重试提示的视觉成品与 craft 比对
L5 na: 没有本格独立新用户发现并理解向量补算失败状态的 discoverability session
```
