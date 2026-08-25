# EDGE-188 密文红线

- 结论：`pass`（L1 encrypted search redline + real HTTP black-box）；L2-L5 按当前独立台架边界记 `na`。
- 预期：API key 明文、trigger secret/config、MCP env/header 等经 Encryptor 落盘的值永不进入全文搜索投影；
  实体公开名称/描述仍可搜索，不能用“全不索引”掩盖投影损坏。

## real black-box regression

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestSearchR1_EncryptedRedline$' -count=1 -v -timeout 600s
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 6.086s
```

真实 HTTP 场景创建 API key `sk-redlinekeysecret`、webhook trigger 的 `redlinetrgsecret`、以及带
`redlinemcpsecret` env 的 scripted MCP server；先验证 trigger 明文名与 MCP 明文描述正控可搜，再逐一查询
三个 secret，均为零命中。该场景同时经过真实存储加密与 search projection，避免只测内存 source。
日志中的 `127.0.0.1:1` free-tier warning 是 testend 无网关 fixture，未影响本格搜索断言。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成真实 App 密文红线与五通道录制
L3 na: 没有本格独立搜索结果等待与零命中反馈的 Computer Use 时序测量
L4 na: 没有本格独立密文零命中与公开字段正控的视觉成品与 craft 比对
L5 na: 没有本格独立新用户发现并理解敏感字段不可搜索原因的 discoverability session
```
