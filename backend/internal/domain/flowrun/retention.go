// Run-history retention (scheduler 工单⑬, 判决④) — the bounds of the periodic sweep that enforces
// the user's configured retention line. The line itself lives in <dataDir>/settings.json (machine
// level, app/settings); this file owns only what the ENGINE needs to know about purging.
//
// run 历史保留（scheduler 工单⑬、判决④）——执行用户配置的保留线的定期清理，其边界。线本身住在
// <dataDir>/settings.json（机器级，app/settings）；本文件只拥有**引擎**关于清理需要知道的东西。
package flowrun

// RetentionBatchSize bounds one purge transaction. The DB is single-connection (SetMaxOpenConns(1)),
// so an unbounded DELETE tx would block every other write for its duration — a sweep must never make
// the app look frozen. 200 runs (headers + their node and audit rows) is a small tx that commits in
// milliseconds; the app service loops batches until the line is clear, checking ctx between them.
//
// RetentionBatchSize 限定**一个**清理事务。DB 是单连接（SetMaxOpenConns(1)），故无界的 DELETE 事务会在
// 其整个时长里阻塞所有其他写——清理绝不能让 app 看起来卡死。200 个 run（头 + 它们的节点行与审计行）是个
// 毫秒级提交的小事务；app service 循环批次直到线清干净，其间逐批查 ctx。
const RetentionBatchSize = 200
