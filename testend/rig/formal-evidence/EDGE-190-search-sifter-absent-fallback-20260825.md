# EDGE-190 sifter 缺席回退

- 结论：`pass`（L1 utility-sifter absence fallback + real HTTP/LLM black-box）；L2-L5 按当前独立台架边界记 `na`。
- 预期：utility 模型不可用时 `search_blocks` 不报错、不返回空结果，回退纯索引排序；同时维持六类
  可接线积木范围，document/skill 等不可接线实体不能泄漏，handler method ref 必须可接线。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/search \
  -run '^TestSearchBlocks_TierThree_SiftFailureFallsBack$' \
  -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/search 1.553s
```

## real black-box regression

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestSearchLLM_BlocksTier3AndScope$' -count=1 -v -timeout 600s
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 4.486s
```

真实场景不配置 utility model，日志确认 tier-1 与 tier-2 sifter 均因 `MODEL_NOT_CONFIGURED` 失败后回到
index ranking；结果仍包含 function 与 `hd_<id>.flush` handler-method ref，且同名 document/skill 诱饵不出现在
`search_blocks` 返回中。测试同时验证了真实对话消息→工具执行→结果回喂线缆。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成 utility 缺席与五通道 App 录制
L3 na: 没有本格独立 fallback 等待、错误反馈与结果回喂的 Computer Use 时序测量
L4 na: 没有本格独立 fallback 结果卡、ref 形状与 scope 成品的视觉 craft 比对
L5 na: 没有本格独立新用户发现并理解 utility 缺席仍可检索的 discoverability session
```
