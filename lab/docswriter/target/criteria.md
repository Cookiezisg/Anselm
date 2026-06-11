# 判据 —— done = 干净 + 完整 + 精确

一篇文档「完成」当且仅当全过：

## 完整（covered）

- module 文档：`skeleton.md` 7 节（或地基的取节版）齐，无空节。
- 该模块的端点/表/码/事件**全部**进了对应索引（无遗漏）。
- 心智模型节写到位——读完能 get 这个模块「为什么这样」。

## 精确（parity，文档 = 代码）

- 索引每条对码逐字：端点 = 真实路由（method/path）；表+列 = 真实 schema；码 = 真实 `errorsdomain` sentinel + wire code；事件 = 真实 stream producer。
- **无多**：文档里没有代码里不存在的端点/表/码/字段（无投机、无前瞻）。
- **无错**：动词、状态码、前缀、类型对得上。

## 干净（反堆叠）

- **单源**：本篇没重复别处已枚举的（端点只在 api.md、schema 只在 database.md…）；module 文档只引用、不重列。
- **零历史**：无 R 轮次、无「原来…后来」、无演化叙述。
- **海拔纯**：索引=纯枚举；module 文档=纯设计/Why。无 What 灌水。
- 高密度：无 fluff；超长先疑重复/灌水。

## 门禁（机械）

- `make docs` 绿（frontmatter 合法 / 无孤儿链接 / INDEX≤50）。
- 提交含 module 文档 + 索引增量 + `rounds/NNNN/round.md`，同一提交。

## 反例（任一即未完成）

❌ 端点同时出现在 domain §6 和 api.md（重复）· ❌ 文档写了代码没有的端点（投机）· ❌ 出现「R0066」（历史）· ❌ domain 文档逐字段抄 struct（What 灌水）· ❌ schema DDL 抄进 domain 文档（该在 database.md）。
