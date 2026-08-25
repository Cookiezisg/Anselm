# EDGE-185 异查询游标

- 结论：`pass`（L1 cursor integrity + real HTTP pagination contract）；L2-L5 按当前独立台架边界记 `na`。
- 预期：cursor 绑定生成它的 query，拿 query A 的 cursor 翻 query B 必须返回 `SEARCH_CURSOR_INVALID`，
  不能静默切错窗口；合法 base64 padding 不应改变游标语义。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/search \
  -run '^(TestSearch_CursorPagination|TestSearch_CursorPaginationAcceptsPaddedCursor)$' \
  -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/search 1.283s
```

focused 测试验证 page 1→page 2 不重复、异 query cursor 返回 `ErrCursorInvalid`，并验证合法 padded
base64 cursor 仍能继续分页。

## real black-box regression

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestSearch_PaginationWindow$' -count=1 -v -timeout 600s
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 5.484s
```

真实 HTTP 场景创建 25 个 function，走 `10+10+5` 三页，total 稳定、id 无重复；复用 A query cursor
到 `q=different` 和坏 cursor 均返回 400 `SEARCH_CURSOR_INVALID`。日志中的 `127.0.0.1:1` free-tier
warning 是刻意无网关 fixture，已与搜索结论隔离。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成真实 App 分页与五通道录制
L3 na: 没有本格独立翻页与错误反馈的 Computer Use 时序测量
L4 na: 没有本格独立分页列表/错误状态视觉成品与 craft 比对
L5 na: 没有本格独立新用户发现并理解 cursor 失效原因的 discoverability session
```
