# EDGE-272 · 分组计数跨翻页不漂移

## L1 focused evidence

- `testend/scenarios/chat_workdir_group_test.go:TestChatWorkDirGroups_CountsDoNotDriftAcrossPaging` 通过。
- 同一 workspace 反复读取 rail 与 workdir groups，组头计数保持服务端 GROUP BY 结果，不随分页游标变化。

## 判定

L1=`F1`：列表行与组投影使用同一数据库真相，翻页不会改写计数。L2-L5 本批未启动真实 App，记 `na`。
