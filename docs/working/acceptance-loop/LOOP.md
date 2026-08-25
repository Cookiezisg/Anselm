---
id: WRK-093
type: working
status: active
owner: "@weilin"
created: 2026-08-01
reviewed: 2026-08-09
reviewed: 2026-08-14
review-due: 2026-10-30
audience: [human, ai]
landed-into:
---

# WRK-093 · 验收循环执行协议

## 当前前线覆盖声明（2026-08-26 · EDGE-190 已收口 · 批次六十六已提交 · 批次六十七 0/50）

## 2026-08-26 · 批次六十六收口与提交

- `EDGE-181..190` 共 50 格逐格登记，统一长门禁全绿；收口证据=`testend/rig/formal-evidence/batch-66-unified-gate-20260825.md`，提交=`1be292f9`（`test(rig): close batch 66 search edges`）。提交后工作树 clean，formal journal=`3436`（2300 baseline + 1136 live），COVERAGE=`848/687/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次六十七从=`0/50` 开始，下一原子前线=`EDGE-191`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-190 sifter 缺席回退

- focused + 真实 LLM/HTTP 回归通过：utility 未配时两级 sifter fallback 到 index ranking，function/handler-method ref 可接线，document/skill 诱饵不泄漏；真实 App 五通道未执行，L2-L5 如实 na。
- 正式证据=`testend/rig/formal-evidence/EDGE-190-search-sifter-absent-fallback-20260825.md`；五级=`measure:edge190-search-sifter-absent-fallback/na/na/na/na`；formal journal=`3436`（2300 baseline + 1136 live），COVERAGE=`848/687/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-190-ledger-alarm-reaudit-20260825.md`。
- 批次六十六已达到=`50/50`；统一长门禁全绿，随后已提交。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-189 Changed 队满丢事件

- focused `-race` 回归通过：1024 队列填满后 `Changed` 仍在 100ms 内返回；随后 stamps reconcile 恢复被丢的 live entity 并清理 orphan；真实 App 五通道未执行，L2-L5 如实 na。
- 正式证据=`testend/rig/formal-evidence/EDGE-189-search-changed-queue-reconcile-20260825.md`；五级=`measure:edge189-search-changed-queue-reconcile/na/na/na/na`；formal journal=`3431`（2300 baseline + 1131 live），COVERAGE=`848/686/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-189-ledger-alarm-reaudit-20260825.md`。
- 批次六十六当前=`45/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-190`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-188 密文红线

- 真实 HTTP 黑盒通过：API key 明文、webhook trigger secret、MCP env secret 均零搜索命中；trigger 明文名与 MCP 描述正控可搜；真实 App 五通道未执行，L2-L5 如实 na。
- 正式证据=`testend/rig/formal-evidence/EDGE-188-search-encrypted-redline-20260825.md`；五级=`measure:edge188-search-encrypted-redline/na/na/na/na`；formal journal=`3426`（2300 baseline + 1126 live），COVERAGE=`848/685/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-188-ledger-alarm-reaudit-20260825.md`。
- 批次六十六当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-189`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-187 fts_schema_version 不匹配

- focused `-race` 回归通过：旧 schema 版本启动时只执行一次全量清理，当前版本写入，live source 重建恢复；旧 lexical hit 与旧 embedding 均不残留；该包完整 race 回归通过。真实 App 五通道旧库启动未执行，L2-L5 如实 na。
- 正式证据=`testend/rig/formal-evidence/EDGE-187-search-schema-version-rebuild-20260825.md`；五级=`measure:edge187-search-schema-version-rebuild/na/na/na/na`；formal journal=`3421`（2300 baseline + 1121 live），COVERAGE=`848/684/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-187-ledger-alarm-reaudit-20260825.md`。
- 批次六十六当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-188`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-186 :reindex 并发与就地重建

- focused + 真实 HTTP reindex 回归通过：同 ws 单飞、异 ws 不阻塞、force-reconcile 不 purge、204 后命中恢复；真实 App 五通道未执行，L2-L5 如实 na。
- 正式证据=`testend/rig/formal-evidence/EDGE-186-search-reindex-singleflight-inplace-20260825.md`；五级=`measure:edge186-search-reindex-singleflight-inplace/na/na/na/na`；formal journal=`3416`（2300 baseline + 1116 live），COVERAGE=`848/683/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-186-ledger-alarm-reaudit-20260825.md`。
- 批次六十六当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-187`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-185 异查询游标

- focused + 真实 HTTP 分页回归通过：10+10+5 无重复、total 稳定，异 query/坏 cursor 返回 `SEARCH_CURSOR_INVALID`；真实 App 五通道未执行，L2-L5 如实 na。
- 正式证据=`testend/rig/formal-evidence/EDGE-185-search-cursor-query-binding-20260825.md`；五级=`measure:edge185-search-cursor-query-binding/na/na/na/na`；formal journal=`3411`（2300 baseline + 1111 live），COVERAGE=`848/682/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-185-ledger-alarm-reaudit-20260825.md`。
- 批次六十六当前=`25/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-186`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-184 短词 LIKE 回退

- focused `-race` tokenizer/LIKE/MATCH 回归通过：两字符中文 LIKE 命中并高亮，长短混合保持合取；真实 App 五通道未执行，L2-L5 如实 na。
- 正式证据=`testend/rig/formal-evidence/EDGE-184-search-short-token-like-fallback-20260825.md`；五级=`measure:edge184-search-short-token-like-fallback/na/na/na/na`；formal journal=`3406`（2300 baseline + 1106 live），COVERAGE=`848/681/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-184-ledger-alarm-reaudit-20260825.md`。
- 批次六十六当前=`20/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-185`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-183 换 embedder 重嵌

- focused model-key/cache 回归与真实 HTTP settings/reindex 对照通过：切换后旧向量不混用、cache 重扫、kick fan-out 与 lexical fallback 均正确；真实 App 五通道未执行，L2-L5 如实 na。
- 正式证据=`testend/rig/formal-evidence/EDGE-183-search-embedder-switch-reembed-20260825.md`；五级=`measure:edge183-search-embedder-switch-reembed/na/na/na/na`；formal journal=`3401`（2300 baseline + 1101 live），COVERAGE=`848/680/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-183-ledger-alarm-reaudit-20260825.md`。
- 批次六十六当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-184`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-182 cosineFloor 噪声闸

- focused `-race` 双守卫通过：cosine `0.53` 自然噪声被 `0.55` floor 拦截；identifier-shaped query 即使 cosine `0.63` 也不能纯语义召回；cosine `0.62` genuine match 保留。
- 正式证据=`testend/rig/formal-evidence/EDGE-182-search-cosine-floor-noise-gate-20260825.md`；五级=`measure:edge182-search-cosine-floor-noise-gate/na/na/na/na`；formal journal=`3396`（2300 baseline + 1096 live），COVERAGE=`848/679/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-182-ledger-alarm-reaudit-20260825.md`。
- 批次六十六当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-183`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-181 整批 embed upsert 全失败

- focused `-race` 回归通过：整批 `UpsertEmbedding` 故意失败时 backfill 有界结束，只尝试该批一次，不热循环；真实盘满/表损与 App 五通道未执行，L2-L5 如实 na。
- 正式证据=`testend/rig/formal-evidence/EDGE-181-search-embed-upsert-all-fail-20260825.md`；五级=`measure:edge181-search-embed-upsert-all-fail/na/na/na/na`；formal journal=`3391`（2300 baseline + 1091 live），COVERAGE=`848/678/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-181-ledger-alarm-reaudit-20260825.md`。
- 批次六十六当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-182`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-180 embedder 孤儿回收

- Unix `-race` focused 回归通过：记录的 `embedder.pid` survivor 被杀，缺失文件/垃圾 pid 安全 no-op；真实 kill-9/App 重启未执行，L2-L5 如实 na。
- 正式证据=`testend/rig/formal-evidence/EDGE-180-search-embedder-orphan-reap-20260825.md`；五级=`measure:edge180-search-embedder-orphan-reap/na/na/na/na`；formal journal=`3386`（2300 baseline + 1086 live），COVERAGE=`848/677/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-180-ledger-alarm-reaudit-20260825.md`。
- 批次六十五当前=`50/50`；统一长门禁全绿，收口证据=`testend/rig/formal-evidence/batch-65-unified-gate-20260825.md`，本批已提交=`1f16b056`；下一原子前线=`EDGE-181`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-179 首用下载途中关停

- focused `-race` 回归用无限首用 installer 模拟模型下载：`Builtin.Close` 在预算内返回，取消 installer context 并释放锁，不让关停阻塞在下载上。
- 当前没有真实 600MB 下载中的 App/SIGTERM 黑盒，未伪造 L2-L5 绿证据。
- 正式证据=`testend/rig/formal-evidence/EDGE-179-search-first-download-shutdown-20260825.md`；五级=`measure:edge179-search-first-download-shutdown/na/na/na/na`；formal journal=`3381`（2300 baseline + 1081 live），COVERAGE=`848/676/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-179-ledger-alarm-reaudit-20260825.md`。
- 批次六十五当前=`45/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-180`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-178 搜索 embedder 缺席降级

- focused provider-failure/off 回归均通过：provider 不可用或 `embedder=off` 时 lexical hit 保留且无 error。
- 真实 `TestSearch_ReindexAndSettings` 通过：reindex 后命中，`off` 状态在跨 workspace 一致，词法搜索继续可用；Ollama 死端口软降级不打断搜索。
- 正式证据=`testend/rig/formal-evidence/EDGE-178-search-embedder-off-fallback-20260825.md`；五级=`measure:edge178-search-embedder-off-fallback/na/na/na/na`；formal journal=`3376`（2300 baseline + 1076 live），COVERAGE=`848/675/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-178-ledger-alarm-reaudit-20260825.md`。
- 批次六十五当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-179`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-177 无可跑 package

- focused unsupported-runtime fixture 与 curated catalog plannability 门禁均通过：no-runnable 返回 `MCP_NO_RUNNABLE_PACKAGE` 且不落 server 半行；正式白名单不暴露此状态。
- 正式证据=`testend/rig/formal-evidence/EDGE-177-mcp-no-runnable-package-20260825.md`；五级=`measure:edge177-mcp-no-runnable-package/na/na/na/na`；formal journal=`3371`（2300 baseline + 1071 live），COVERAGE=`848/674/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-177-ledger-alarm-reaudit-20260825.md`。
- 批次六十五当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-178`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-176 MCP 市场缺必填 env

- focused missing detail/零持久化与真实 marketplace 均通过：Firecrawl 空 env 在下载前返回 `422 MCP_ENV_MISSING`，body 点名 `FIRECRAWL_API_KEY`。
- 正式证据=`testend/rig/formal-evidence/EDGE-176-mcp-marketplace-missing-env-20260825.md`；五级=`measure:edge176-mcp-marketplace-missing-env/na/na/na/na`；formal journal=`3366`（2300 baseline + 1066 live），COVERAGE=`848/673/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-176-ledger-alarm-reaudit-20260825.md`。
- 批次六十五当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-177`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-175 MCP 失败附 stderr 尾

- focused byte-cap 与真实 MCP lifecycle 均通过：失败详情带 `server-level, may predate this call` 标注和 stderr 尾，helper 保留最新 8 KiB。
- 正式证据=`testend/rig/formal-evidence/EDGE-175-mcp-stderr-tail-20260825.md`；五级=`measure:edge175-mcp-stderr-tail/na/na/na/na`；formal journal=`3361`（2300 baseline + 1061 live），COVERAGE=`848/672/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-175-ledger-alarm-reaudit-20260825.md`。
- 批次六十五当前=`25/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-176`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-174 MCP 进度关联

- infra `-race` 与真实 HTTP 并发场景均通过：两个 progress token 分别回到 alpha/beta 调用，两个 durable `mcp_calls` 详情无串台。
- 正式证据=`testend/rig/formal-evidence/EDGE-174-mcp-progress-correlation-20260825.md`；五级=`measure:edge174-mcp-progress-correlation/na/na/na/na`；formal journal=`3356`（2300 baseline + 1056 live），COVERAGE=`848/671/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-174-ledger-alarm-reaudit-20260825.md`。
- 批次六十五当前=`20/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-175`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-173 MCP name-or-id 双键 purge

- focused service 与真实 HTTP relation 场景均通过：`RemoveServer` 同时 purge `mcp_` ID 和 server name 两类键；真实挂载后的 agent 邻域在删除 MCP 后不再包含 `relmcp`，server 读接口返回 404。
- 正式证据=`testend/rig/formal-evidence/EDGE-173-mcp-name-id-purge-20260825.md`；五级=`measure:edge173-mcp-name-id-purge/na/na/na/na`；formal journal=`3351`（2300 baseline + 1051 live），COVERAGE=`848/670/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-173-ledger-alarm-reaudit-20260825.md`。
- 批次六十五当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-174`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-172 无 uploader 时的 MCP 媒体

- 同一 focused 回归比较 uploader 已接线与 `nil`：无 uploader 时 MCP media call 成功、原始占位保留、不伪造 attachment receipt；能力缺席被诚实表达。
- 正式证据=`testend/rig/formal-evidence/EDGE-172-mcp-media-no-uploader-20260825.md`；五级=`measure:edge172-mcp-media-no-uploader/na/na/na/na`；formal journal=`3346`（2300 baseline + 1046 live），COVERAGE=`848/669/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-172-ledger-alarm-reaudit-20260825.md`。
- 批次六十五当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-173`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-171 MCP 媒体逐件 best-effort

- focused 三件 PNG/MP3/JPEG 中间件故意失败一件：调用仍成功，两件成功项有 `mcp_media` receipts，失败项保留原始占位；真实 stdio→attachment→vision wire 证明图片原字节进入 native image part，无 uploader 降级也通过。
- 正式证据=`testend/rig/formal-evidence/EDGE-171-mcp-media-best-effort-20260825.md`；五级=`measure:edge171-mcp-media-best-effort/na/na/na/na`；formal journal=`3341`（2300 baseline + 1041 live），COVERAGE=`848/668/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-171-ledger-alarm-reaudit-20260825.md`。
- 批次六十五当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-172`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-170 MCP 连接失败仍落盘

- focused reconnect 与真实 HTTP error paths 均通过：坏 stdio/不可达 remote PUT 保留 `failed` + `lastError`，`:reconnect` 可重试但不伪报成功，failed server 调用明确 `MCP_SERVER_DOWN`；失败通知带 outcome status。
- 正式证据=`testend/rig/formal-evidence/EDGE-170-mcp-failed-persists-20260825.md`；五级=`measure:edge170-mcp-failed-persists/na/na/na/na`；formal journal=`3336`（2300 baseline + 1036 live），COVERAGE=`848/667/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-170-ledger-alarm-reaudit-20260825.md`。
- 批次六十四已达到=`50/50`；统一长门禁已通过，收口证据=`testend/rig/formal-evidence/batch-64-unified-gate-20260825.md`，本批代码/测试/证据已提交=`50c1c9c4`；下一原子前线暂为=`EDGE-171`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-169 MCP degraded 态

- focused bridge 与真实 HTTP MCP lifecycle 均通过：三次失败 → `degraded`，degraded 仍可调用；entities ephemeral `status` signal 从 `ready` 变 `degraded`，成功后恢复 `ready`；mcp_calls、stderr、reconnect 和删除后的 404 一并核对。
- 正式证据=`testend/rig/formal-evidence/EDGE-169-mcp-degraded-20260825.md`；五级=`measure:edge169-mcp-degraded/na/na/na/na`；formal journal=`3331`（2300 baseline + 1031 live），COVERAGE=`848/666/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-169-ledger-alarm-reaudit-20260825.md`。
- 批次六十四当前=`45/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-170`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-168 每租户模板 URL

- Glean 类 catalog plan 暴露唯一必填 URL env；真实 `InstallFromRegistry` 先展开 `{MCP_URL}`，再以展开后的租户 `/mcp` 完成 OAuth discovery/DCR/PKCE/loopback/token，落盘 URL 与 OAuth resource 均为展开值。
- 正式证据=`testend/rig/formal-evidence/EDGE-168-mcp-tenant-url-template-20260825.md`；五级=`measure:edge168-mcp-tenant-url-template/na/na/na/na`；formal journal=`3326`（2300 baseline + 1026 live），COVERAGE=`848/665/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-168-ledger-alarm-reaudit-20260825.md`。
- 批次六十四当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-169`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-167 自带客户端固定端口被占

- 真实占住 `127.0.0.1:47100` 后 callback server 成功退到随机 loopback 端口，code/state 正常交付；固定 redirect 便利不再成为 OAuth 单点故障。
- 正式证据=`testend/rig/formal-evidence/EDGE-167-mcp-oauth-port-fallback-20260825.md`；五级=`measure:edge167-mcp-oauth-port-fallback/na/na/na/na`；formal journal=`3321`（2300 baseline + 1021 live），COVERAGE=`848/664/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-167-ledger-alarm-reaudit-20260825.md`。
- 批次六十四当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-168`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-166 OAuth refresh 失效

- 新增 revoked refresh 401/`invalid_grant` focused `-race` 回归通过：token source 返回 `ErrOAuthReauthRequired`，不使用死 token；正常轮换与无 refresh token 边界仍通过。
- 正式证据=`testend/rig/formal-evidence/EDGE-166-mcp-oauth-refresh-revoked-20260825.md`；五级=`measure:edge166-mcp-oauth-refresh-revoked/na/na/na/na`；formal journal=`3316`（2300 baseline + 1016 live），COVERAGE=`848/663/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-166-ledger-alarm-reaudit-20260825.md`。
- 批次六十四当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-167`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-165 MCP OAuth 全流程

- 受控 OAuth server full-flow 与 infra `-race` 全通过：401→RFC 9728/8414→DCR→PKCE/state→loopback→token/refresh，BYO client 与无DCR拒绝均明确；不冒充第三方浏览器视觉证据。
- 正式证据=`testend/rig/formal-evidence/EDGE-165-mcp-oauth-full-flow-20260825.md`；五级=`measure:edge165-mcp-oauth-full-flow/na/na/na/na`；formal journal=`3311`（2300 baseline + 1011 live），COVERAGE=`848/662/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-165-ledger-alarm-reaudit-20260825.md`。
- 批次六十四当前=`25/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-166`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-164 被取消的 subagent 落终态

- focused annotation 与真实 HTTP parent-cancel 双路径通过：父/子消息均落 terminal，detached finalize 发 `message_stop`，没有 pending/streaming 孤儿；30 秒故意 stall 的 httptest 收台 warning 原样披露，不是 sidecar 残留。
- 正式证据=`testend/rig/formal-evidence/EDGE-164-subagent-cancel-terminal-20260825.md`；五级=`measure:edge164-subagent-cancel-terminal/na/na/na/na`；formal journal=`3306`（2300 baseline + 1006 live），COVERAGE=`848/661/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-164-ledger-alarm-reaudit-20260825.md`。
- 批次六十四当前=`20/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-165`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-163 get_subagent_trace 隔离

- focused trace list/detail/错误输入与真实 HTTP parent/child isolation 双路径通过：父可读自己的 subagent trace，子工具面剔除 `get_subagent_trace`/`Subagent`，不泄漏其它子运行，子树仍保留 `SubagentID`。
- 正式证据=`testend/rig/formal-evidence/EDGE-163-subagent-trace-isolation-20260825.md`；五级=`measure:edge163-subagent-trace-isolation/na/na/na/na`；formal journal=`3301`（2300 baseline + 1001 live），COVERAGE=`848/660/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-163-ledger-alarm-reaudit-20260825.md`。
- 批次六十四当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-164`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-162 subagent 深度守卫

- focused filter/recursion 与真实 HTTP 子树均通过：所有 subagent 工具面剔除 `Subagent`/`get_subagent_trace`，已有 subagent context 的 `Spawn` 明确拒绝；真实子请求工具列表无递归工具，结果仍回父树。
- 正式证据=`testend/rig/formal-evidence/EDGE-162-subagent-depth-guard-20260825.md`；五级=`measure:edge162-subagent-depth-guard/na/na/na/na`；formal journal=`3296`（2300 baseline + 996 live），COVERAGE=`848/659/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-162-ledger-alarm-reaudit-20260825.md`。
- 批次六十四当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-163`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-161 subagent 墙钟

- focused 与真实 HTTP 子树双路径通过：无父回合 deadline 的 `Spawn` 自带 `ChatTurnSec`，永不返回的 provider 在 1 秒内被切断，子 message 落 `cancelled`，截断原因回传父层；真实子树的 `SubagentID`、结果回喂和深度 1 工具裁剪均正确。
- 正式证据=`testend/rig/formal-evidence/EDGE-161-subagent-wall-clock-20260825.md`；五级=`measure:edge161-subagent-wall-clock/na/na/na/na`；formal journal=`3291`（2300 baseline + 991 live），COVERAGE=`848/658/0`，anchors=`10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-161-ledger-alarm-reaudit-20260825.md`。
- 批次六十四当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-162`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-160 agent 墙钟压过自报终态

- focused 与真实 HTTP timeout 双路径通过：1 秒/2 秒 invocation deadline 切断阻塞流，结果非 OK 且 durable execution 为 `timeout`；真实 testend PATCH limits、stall LLM、查询 execution 与优雅 shutdown 均收口。
- 正式证据=`testend/rig/formal-evidence/EDGE-160-agent-wall-clock-terminal-20260825.md`；五级=`measure:edge160-agent-wall-clock-terminal/na/na/na/na`；formal journal=`3286`（2300 baseline + 986 live），COVERAGE=`848/657/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按 focused/HTTP timeout 双路径与 L2-L5 na 边界复核 ack）。
- 批次六十三 `EDGE-151..EDGE-160` 已达到=`50/50`；统一长门禁全绿，收口证据=`testend/rig/formal-evidence/batch-63-unified-gate-20260825.md`，代码/证据提交=`3e02e4ff`；下一原子前线=`EDGE-161`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-159 sys: 能力工具无路由

- sys resolver/health 与真实 HTTP agent 创建双路径通过：没有图像路由时 `sys:generate_image` 不可解析且 mount-health unhealthy；真实 agent 创建返回 `422 AGENT_MOUNT_INVALID`，响应带 `no usable route` 和配置 capable key/free tier 的方向。
- 正式证据=`testend/rig/formal-evidence/EDGE-159-agent-sys-image-no-route-20260825.md`；五级=`measure:edge159-agent-sys-image-no-route/na/na/na/na`；formal journal=`981` live（2300 baseline），COVERAGE=`848/676/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按 resolver/HTTP 双路径与 L2-L5 na 边界复核 ack）。
- 批次六十三当前=`50/50`，正在执行统一长门禁，未收口前不提交；P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-158 agent 非 OK 终态置空输出

- declared-output agent 的非 OK focused 回归通过：provider error 后状态非 OK 且 `Output=nil`，不会让 partial narration 冒充结构化对象；loop 层 max-steps/tool-error-storm 终止码已有独立回归。
- 正式证据=`testend/rig/formal-evidence/EDGE-158-agent-non-ok-output-null-20260825.md`；五级=`measure:edge158-agent-non-ok-output-null/na/na/na/na`；formal journal=`976` live（2300 baseline），COVERAGE=`848/671/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按 non-OK output 边界与 L2-L5 na 边界复核 ack）。
- 批次六十三当前=`45/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-160`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-157 agent 声明输出回解析

- parser/terminal `-race` 与真实 HTTP agent seat 均通过：declared output 的 JSON/fenced JSON 正确回解析，多字段 prose 大声失败，非 OK 终态 `Output=nil`；真实 prompt 明确要求单一 JSON object。
- 正式证据=`testend/rig/formal-evidence/EDGE-157-agent-declared-output-parse-20260825.md`；五级=`measure:edge157-agent-declared-output-parse/na/na/na/na`；formal journal=`971` live（2300 baseline），COVERAGE=`848/666/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按 parser/terminal/HTTP 三面与 L2-L5 na 边界复核 ack）。
- 批次六十三当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-159`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-156 agent 离线 MCP 挂载归因

- 真实 agent seat 先挂载 ready MCP，再制造 server offline：mount-health 与 invoke 都准确报 `not connected`，invoke 在 LLM 前 fail-fast；恢复 server 后挂载健康、工具真调成功并记 agent 台账。
- 正式证据=`testend/rig/formal-evidence/EDGE-156-agent-offline-mcp-attribution-20260825.md`；五级=`measure:edge156-agent-offline-mcp-attribution/na/na/na/na`；formal journal=`966` live（2300 baseline），COVERAGE=`848/661/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按 offline/reconnect/tool-call 双路径与 L2-L5 na 边界复核 ack）。
- 批次六十三当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-158`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-155 agent 挂载目标被删

- 真实 agent 删除 function 后再次 invoke 明确失败并保留 `not found` 原因；focused 回归同时锁住 dangling knowledge/tool 的 create/edit 拒绝与 knowledge 删除后的 mount-health unhealthy 行，绝不静默成功。
- 正式证据=`testend/rig/formal-evidence/EDGE-155-agent-deleted-mount-target-20260825.md`；五级=`measure:edge155-agent-deleted-mount-target/na/na/na/na`；formal journal=`961` live（2300 baseline），COVERAGE=`848/656/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按真实删除目标与 focused 双路径及 L2-L5 na 边界复核 ack）。
- 批次六十三当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-157`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-154 agent 挂载撞名

- 真实 agent invoke 与 mount-health 场景均通过：function/handler 合成同名工具时 create/invoke 大声拒绝，不静默覆盖；mount-health 保持第一挂载健康，仅把第二个冲突挂载标为 unhealthy 并带 `collides`。
- 正式证据=`testend/rig/formal-evidence/EDGE-154-agent-mount-name-collision-20260825.md`；五级=`measure:edge154-agent-mount-name-collision/na/na/na/na`；formal journal=`956` live（2300 baseline），COVERAGE=`848/651/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按 invoke/mount-health 双路径与 L2-L5 na 边界复核 ack）。
- 批次六十三当前=`25/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-156`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-153 env 在用时删除

- focused `-race` 锁住 running PID、env row、owner lock 和批量原子性；真实 HTTP 先把真实 env 标成 resident，DELETE 返回 `409 SANDBOX_ENV_IN_USE` 且 env 仍可读，释放后 DELETE 才 `204`，重复删除 `404`。
- 正式证据=`testend/rig/formal-evidence/EDGE-153-sandbox-env-delete-in-use-20260825.md`；五级=`measure:edge153-sandbox-env-delete-in-use/na/na/na/na`；formal journal=`951` live（2300 baseline），COVERAGE=`848/650/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按 resident 拒删/恢复双路径与 L2-L5 na 边界复核 ack）。
- 批次六十三当前=`20/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-155`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-152 uvx/npx 孙进程整组杀

- 真实 `npx` 官方 filesystem MCP 完成 runtime 启动、工具发现、文件读取、产品 DELETE 与删除后 404；sandbox `-race` 回归再证明 wrapper 同组孙进程和 manifest survivor 都被 boot reaper 收割。
- 正式证据=`testend/rig/formal-evidence/EDGE-152-sandbox-uvx-npx-process-group-reap-20260825.md`；五级=`measure:edge152-sandbox-uvx-npx-process-group-reap/na/na/na/na`；formal journal=`946` live（2300 baseline），COVERAGE=`848/649/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按真实 npx 产品路径、进程组证据与 L2-L5 na 边界复核 ack）。
- 批次六十三当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-154`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-151 boot 回收 run_in_background 孤儿

- 真实 `run_in_background` 进程组、zombie leader、PID 被无辜进程复用三条回归，以及 bootstrap 应用装配层回归均通过；boot 按 pid 清单整组回收并清理旧记录，不误杀复用 PID。
- 正式证据=`testend/rig/formal-evidence/EDGE-151-shell-boot-reap-background-orphans-20260825.md`；五级=`measure:edge151-shell-boot-reap-background-orphans/na/na/na/na`；formal journal=`3241`，COVERAGE=`848/648/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按真实进程组证据与 L2-L5 na 边界复核 ack）。
- 批次六十三当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-153`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · 批次六十二已提交

- `EDGE-141..EDGE-150` 已完成 `50/50`；统一长门禁全绿，证据=`testend/rig/formal-evidence/batch-62-unified-gate-20260825.md`，代码/证据提交=`ed269a1e`。
- 批次六十三已从 `0/50` 开始并收口 `EDGE-151..EDGE-152`，下一原子前线=`EDGE-153`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-150 boot 回收残留 running_pid

- 真实进程回归通过：boot 收割 manifest 中记录的 survivor、清零 `running_pid`，并通过同组 grandchild 模拟证明整组 SIGKILL 不留 wrapper 孙进程。
- 正式证据=`testend/rig/formal-evidence/EDGE-150-sandbox-boot-reclaim-running-pid-20260825.md`；五级=`measure:edge150-sandbox-boot-reclaim-running-pid/na/na/na/na`；formal journal=`3236`，COVERAGE=`848/647/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按单 PID/整组收割与 L2-L5 na 边界复核 ack）。
- 批次六十二已完成=`50/50`；统一门禁证据=`testend/rig/formal-evidence/batch-62-unified-gate-20260825.md`，根验证、完整 testend、rig 51 项、backend verify、coverage/anchors/alarms、语法、diff、进程收台全绿；现在只剩本批提交。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-149 sandbox bootstrap 失败 degraded

- focused service 真实把 sandbox root 变成普通文件：Bootstrap 错误、ready=false、错误保留；移除障碍后 RetryBootstrap 恢复目录/ready/无错误。真实 HTTP governance 同时验证 `:retry-bootstrap` 200 + `{ok}`。
- 正式证据=`testend/rig/formal-evidence/EDGE-149-sandbox-bootstrap-degraded-retry-20260825.md`；五级=`measure:edge149-sandbox-bootstrap-degraded-retry/na/na/na/na`；formal journal=`3231`，COVERAGE=`848/646/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按失败/恢复双路径与 L2-L5 na 边界复核 ack）。
- 批次六十二当前=`45/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-150`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-148 沙箱运行时首用直装

- 全新 `t.TempDir()` 的真实上游 e2e 通过：UV/Node/Python 下载、checksum、staging 解压、定位、`--version` 执行及二次幂等 Install 均成功；一次错误自然语言 row key 被 sequence gate 正确拒绝，改用 COVERAGE 精确键后登记。
- 正式证据=`testend/rig/formal-evidence/EDGE-148-sandbox-first-use-direct-install-20260825.md`；五级=`measure:edge148-sandbox-first-use-direct-install/na/na/na/na`；formal journal=`3226`，COVERAGE=`848/645/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按 fresh-runtime 证据与 L2-L5 na 边界复核 ack）。
- 批次六十二当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-149`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-147 handler 同实例并发调用串扰

- focused fan `-race` 与真实 HTTP 并发通过：两个调用共享同一 resident instance，RPC 串行、stderr 窗口可重叠；两条 call detail 都保留自己的 start/end，窗口额外行按契约接受，30ms grace 的迟到尾行没有丢。
- 正式证据=`testend/rig/formal-evidence/EDGE-147-handler-concurrent-stderr-windows-20260825.md`；五级=`measure:edge147-handler-concurrent-stderr-windows/na/na/na/na`；formal journal=`3221`，COVERAGE=`848/644/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按窗口重叠语义与 L2-L5 na 边界复核 ack）。
- 批次六十二当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-148`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-146 handler 产物目录 chdir 恢复

- 真实生成 Python driver 回归先让带 `out` 的方法异常，再删除 `out-first`；驻留进程随后成功完成 `out-second` 调用，最后无 `out` 调用回到启动 cwd 且清除 `ANSELM_OUT`。真实 HTTP 产物场景同时证明两次调用各自产生独立附件 receipt。
- 正式证据=`testend/rig/formal-evidence/EDGE-146-handler-chdir-restore-20260825.md`；五级=`measure:edge146-handler-chdir-restore/na/na/na/na`；formal journal=`3216`，COVERAGE=`848/643/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按异常后续调用覆盖与 L2-L5 na 边界复核 ack）。
- 批次六十二当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-147`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-145 handler 纯 meta edit 不重启

- focused service 与真实 HandlerResident 黑盒通过：PATCH 与全 set_meta edit 均不增加 spawn、不铸版本，内存计数继续增长，name/description 落在 Handler 行。
- 正式证据=`testend/rig/formal-evidence/EDGE-145-handler-meta-edit-no-restart-20260825.md`；五级=`measure:edge145-handler-meta-edit-no-restart/na/na/na/na`；formal journal=`3211`，COVERAGE=`848/642/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按两类 meta 路径与 L2-L5 na 边界复核 ack）。
- 批次六十二当前=`25/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-146`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-144 handler 空 ops edit 抹内存态

- focused service 与真实 HTTP/notification 通过：空 ops 不铸版本，重建 active env、重启 resident、发 `handler.env_rebuilt`，真实计数器重置；失败 env 只 provision 一次、停旧实例、不发假成功通知。
- 正式证据=`testend/rig/formal-evidence/EDGE-144-handler-empty-ops-rebuild-20260825.md`；五级=`measure:edge144-handler-empty-ops-rebuild/na/na/na/na`；formal journal=`3206`，COVERAGE=`848/641/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按双路径与 L2-L5 na 边界复核 ack）。
- 批次六十二当前=`20/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-145`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-143 handler 注入 secret 掩码三面

- 首轮真实 HTTP/后端 journal 抓到明文 sensitive token，停止修复 `captureStderr` 绕过调用级 scrub 的 zap journal 入口；修复后 focused observer 与真实 HTTP 三面重跑通过，`handler.stderr`、即时错误、审计 error/logs 都只保留 `********`。
- 正式证据=`testend/rig/formal-evidence/EDGE-143-handler-secret-masked-three-surfaces-20260825.md`；五级=`measure:edge143-handler-secret-masked-three-surfaces/na/na/na/na`；formal journal=`3201`，COVERAGE=`848/640/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按首轮缺陷与修复后重跑复核 ack）。
- 批次六十二当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-144`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-142 handler traceback 不被剥

- focused `infra/handler -race` 与真实 Handler HTTP 黑盒通过：异常仍保留结构化错误分类，即时 502、calls 列表与 call detail 均含 Python cause 和 traceback，不再只给 `call failed`。
- 正式证据=`testend/rig/formal-evidence/EDGE-142-handler-traceback-surfaces-20260825.md`；五级=`measure:edge142-handler-traceback-surfaces/na/na/na/na`；formal journal=`3196`，COVERAGE=`848/639/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按反向失败面与 L2-L5 na 边界复核 ack）。
- 批次六十二当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-143`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-141 handler generator 终值两写法

- 新增 focused `-race` 回归启动真实 `python3`，把正式 `DriverScript` 与生成 Handler 类放进临时目录，通过 stdio 行 JSON 断言 `yield` 终值和 `StopIteration.value` 两条终值协议；既有包内回归与真实 HTTP `TestContractEntities_HandlerResidentSemantics` 同样通过。
- 正式证据=`testend/rig/formal-evidence/EDGE-141-handler-generator-finals-20260825.md`；五级=`measure:edge141-handler-generator-finals/na/na/na/na`；formal journal=`3191`，COVERAGE=`848/638/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按共享证据包与 L2-L5 na 边界复核 ack）。
- 批次六十二当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-142`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-140 handler ctx 取消 = 管道脏

- 真实 stdio pipe 与 app manager `-race` 通过：取消 RPC 等待后 client 标记 crashed，后续调用拒绝复用，manager 下一次 Call 重生 resident；当前没有可控真实 HTTP handler 断连台架，未伪造该证据。
- 正式证据=`testend/rig/formal-evidence/EDGE-140-handler-cancel-dirties-pipe-20260825.md`；五级=`measure:edge140-handler-cancel-dirties-pipe/na/na/na/na`；formal journal=`3186`，COVERAGE=`848/637/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按证据边界复核 ack）。
- 批次六十一已达到=`50/50`；统一门禁证据=`testend/rig/formal-evidence/batch-61-unified-gate-20260825.md`，全绿并已提交=`91fcbacb`；下一原子前线=`EDGE-141`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-139 handler config 不完整

- focused service `-race` 与真实 HTTP 通过：缺必填 init arg 不 spawn，返回 `HANDLER_CONFIG_INCOMPLETE` 并留下 failed call；补回配置后恢复，真实 config 查询暴露 `missingConfig`。
- 正式证据=`testend/rig/formal-evidence/EDGE-139-handler-config-incomplete-20260825.md`；五级=`measure:edge139-handler-config-incomplete/na/na/na/na`；formal journal=`3181`，COVERAGE=`848/636/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按证据边界复核 ack）。
- 批次六十一当前=`45/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-140`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-138 handler 孤儿 config key

- focused filter `-race` 与真实 handler HTTP 通过：active schema 只接收声明参数且不改写持久 config；v2 删除 token schema 后仍能 spawn，revert v1 后保留 token 恢复生效，无 `__init__` TypeError。
- 正式证据=`testend/rig/formal-evidence/EDGE-138-handler-orphan-config-filter-20260825.md`；五级=`measure:edge138-handler-orphan-config-filter/na/na/na/na`；formal journal=`3176`，COVERAGE=`848/635/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按证据边界复核 ack）。
- 批次六十一当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-139`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-137 handler spawn 单飞

- manager `-race` 与真实 handler HTTP 通过：5 个并发冷调用只建立一个 resident，5 行调用台账共享唯一 `instanceId`，没有重复 env/process/`__init__`。
- 正式证据=`testend/rig/formal-evidence/EDGE-137-handler-spawn-singleflight-20260825.md`；五级=`measure:edge137-handler-spawn-singleflight/na/na/na/na`；formal journal=`3171`，COVERAGE=`848/634/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按证据边界复核 ack）。
- 批次六十一当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-138`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-136 无 uploader 时的产物声明

- focused `-race` 通过：nil uploader 时 `$media` 原样透传、notes 为空，调用前不存在的 output 目录调用后仍不存在，没有附件或失败副作用；该项刻意没有可伪造的真实 product HTTP uploader 证据。
- 正式证据=`testend/rig/formal-evidence/EDGE-136-function-artifact-no-uploader-20260825.md`；五级=`measure:edge136-function-artifact-no-uploader/na/na/na/na`；formal journal=`3166`，COVERAGE=`848/633/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按证据边界复核 ack）。
- 批次六十一当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-137`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-135 产物四道闸逐件失败

- focused 组合回归与真实 function HTTP 通过：正常 PNG 成功成为附件，40 MiB 超限文件和 shell 伪装 PNG 各自留在原 `$media` 声明并写 logs，普通结果不失败，收台无残留。
- 正式证据=`testend/rig/formal-evidence/EDGE-135-function-artifact-per-item-failures-20260825.md`；五级=`measure:edge135-function-artifact-per-item-failures/na/na/na/na`；formal journal=`3161`，COVERAGE=`848/632/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按证据边界复核 ack）。
- 批次六十一当前=`25/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-136`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-134 产物路径逃逸

- focused 安全回归与真实 function HTTP 通过：`../outside.png` 在读取前被 containment 拒绝；原 `$media` 声明保留、无 `attachmentId`，logs 给出拒绝原因，收台无 sandbox 残留。
- 正式证据=`testend/rig/formal-evidence/EDGE-134-function-artifact-path-escape-20260825.md`；五级=`measure:edge134-function-artifact-path-escape/na/na/na/na`；formal journal=`3156`，COVERAGE=`848/631/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按证据边界复核 ack）。
- 批次六十一当前=`20/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-135`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-133 function 媒体产物声明

- focused collector `-race` 与真实 function HTTP 通过：`$media` 声明在 `chart` 原键就地替换为 MediaRef，`source=function_artifact`，同级字段保留；两次真实运行的附件 ID 与下载字节均独立且正确。
- 正式证据=`testend/rig/formal-evidence/EDGE-133-function-media-artifact-20260825.md`；五级=`measure:edge133-function-media-artifact/na/na/na/na`；formal journal=`3151`，COVERAGE=`848/630/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按证据边界复核 ack）。
- 批次六十一当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-134`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-132 function 超时清洗

- focused `-race` 与真实 function HTTP 通过：1 秒墙钟返回 `504 FUNCTION_RUN_TIMEOUT`，durable execution 为 `timeout`，错误用 wall-clock 语义，sandbox 收台无残留。
- 正式证据=`testend/rig/formal-evidence/EDGE-132-function-timeout-cleanup-20260825.md`；五级=`measure:edge132-function-timeout-cleanup/na/na/na/na`；formal journal=`3146`，COVERAGE=`848/629/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按证据边界复核 ack）。
- 批次六十一当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-133`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-131 revert 到很老版本后再 trim

- focused store 与真实 HTTP 通过：active 为最老 v1 时底层 trim 保留 v1、只裁 v2 env；真实 revert v1 后 edit v51 则新 v51 成为 active，版本集合收敛到 cap=50，新的 active 不被误删。
- 正式证据=`testend/rig/formal-evidence/EDGE-131-revert-old-version-trim-20260825.md`；五级=`measure:edge131-revert-old-version-trim/na/na/na/na`；formal journal=`3141`，COVERAGE=`848/628/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按证据边界复核 ack）。
- 批次六十一当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-132`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · 批次六十收口：EDGE-130 已提交

## 2026-08-25 · EDGE-130 版本 cap 50 trim 回收 venv

- focused `-race` 与真实 51 次 edit 通过：cap=50，最老非 active 版本被 trim，关联 venv 由 `DestroyEnv` 回收，active version 保留；REST 版本/env 列表对账成立，收台无残留句柄。
- 正式证据=`testend/rig/formal-evidence/EDGE-130-version-cap-trim-reclaims-env-20260825.md`；五级=`measure:edge130-version-cap-trim-reclaims-env/na/na/na/na`；formal journal=`3136`，COVERAGE=`848/627/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按证据边界复核 ack）。
- 批次六十已达到=`50/50`；统一门禁证据=`testend/rig/formal-evidence/batch-60-unified-gate-20260825.md`，根验证、完整 testend、rig 自测、backend verify、覆盖/锚点/警报、格式和残留进程审计全绿，已提交=`759c17c8`。批次六十一从 `0/50` 开始，当前下一原子前线为 `EDGE-132`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-129 env 被 GC 后重试一次

- 真实 function 生命周期通过：GC 回收 env 后下一次 `:run` 命中 `ErrEnvNotFound`，重建同一 active version 并透明重试一次，最终 `200` 成功且无新版本。
- 正式证据=`testend/rig/formal-evidence/EDGE-129-env-gc-retry-once-20260825.md`；五级=`measure:edge129-env-gc-retry-once/na/na/na/na`；formal journal=`3131`，COVERAGE=`848/626/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按证据边界复核 ack）。
- 批次六十当前=`45/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-130`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-128 空 ops edit 重建 env

- 应用回归与真实 function HTTP 通过：failed env 的空 ops 失败不发 `function.env_rebuilt`；正常 env 保持 `version=1`、只发一条重建通知，版本列表仍一行。
- 正式证据=`testend/rig/formal-evidence/EDGE-128-empty-ops-rebuild-env-20260825.md`；五级=`measure:edge128-empty-ops-rebuild-env/na/na/na/na`；formal journal=`3126`，COVERAGE=`848/625/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按证据边界复核 ack）。
- 批次六十当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-129`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-127 env failed 仍创建成功

- 真实 function HTTP 路径通过：不存在依赖不阻断 `201` 创建，active version 明确 `envStatus=failed`/`envError`，运行时才返回 `422 FUNCTION_ENV_NOT_READY`。
- 正式证据=`testend/rig/formal-evidence/EDGE-127-env-failed-create-visible-20260825.md`；五级=`measure:edge127-env-failed-create-visible/na/na/na/na`；formal journal=`3121`，COVERAGE=`848/624/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按证据边界复核 ack）。
- 批次六十当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-128`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-126 未配 utility 模型时的 envfix

- focused `-race` 与真实 function HTTP 生命周期通过：未配 utility 时只尝试一次，失败原因留在 History，function 保持 failed，运行时返回 `FUNCTION_ENV_NOT_READY`，不造假成功。
- 正式证据=`testend/rig/formal-evidence/EDGE-126-envfix-no-utility-20260825.md`；五级=`measure:edge126-envfix-no-utility/na/na/na/na`；formal journal=`3116`，COVERAGE=`848/623/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按证据边界复核 ack）。
- 批次六十当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-127`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-125 envfix 拒绝丢包修复

- focused `-race` 回归通过：utility 返回缩减依赖时被拒绝，不发生第二次安装，env 保持 failed，原始声明与真实安装错误保留，避免假 ready 后才暴露运行时缺包。
- 正式证据=`testend/rig/formal-evidence/EDGE-125-envfix-reject-dep-drop-20260825.md`；五级=`measure:edge125-envfix-reject-dep-drop/na/na/na/na`；formal journal=`3111`，COVERAGE=`848/622/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已按证据边界复核 ack）。
- 批次六十当前=`25/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-126`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-124 envfix 自愈循环

- focused `-race` envfix 回归与真实 function 生命周期通过：失败依赖经 utility 修正后第二次安装成功；真实未配置 utility 的路径诚实停在 failed/`FUNCTION_ENV_NOT_READY`，不造假绿 env。
- 正式证据=`testend/rig/formal-evidence/EDGE-124-envfix-repair-loop-20260825.md`；五级=`measure:edge124-envfix-repair-loop/na/na/na/na`；formal journal=`3106`，COVERAGE=`848/621/0`，anchors=`10/10`，`alarms.py check` clean（机械警报已复核 ack）。
- 批次六十当前=`20/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-125`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-123 暂停时 `nextFireAt` 缺席

- 应用与真实 cron HTTP 路径通过：暂停投影为 `paused=true/listening=false` 且缺席 `nextFireAt`；跨硬重启无 run，resume 后真实 cron run 成功。
- 正式证据=`testend/rig/formal-evidence/EDGE-123-paused-next-fire-absent-20260825.md`；五级=`measure:edge123-paused-next-fire-absent/na/na/na/na`；formal journal=`3101`，COVERAGE=`848/620/0`，anchors=`10/10`，`alarms.py check` clean（机械警报已复核 ack）。
- 批次六十当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-124`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-122 fsnotify 秒桶去重

- 新增秒桶 dedup-key 回归并通过；真实 fsnotify HTTP 路径证明过滤后的 create 只产生一条 run，modify/不匹配事件不新增执行。
- 正式证据=`testend/rig/formal-evidence/EDGE-122-fsnotify-second-dedup-20260825.md`；五级=`measure:edge122-fsnotify-second-dedup/na/na/na/na`；formal journal=`3096`，COVERAGE=`848/619/0`，anchors=`10/10`，`alarms.py check` clean（机械警报已复核 ack）。
- 批次六十当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-123`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-121 webhook 分钟桶去重

- 真实 webhook 重试路径通过：同一分钟同 body 两次请求只形成一条 firing/run；不同 body 形成第二条独立 firing/run。
- 正式证据=`testend/rig/formal-evidence/EDGE-121-webhook-minute-dedup-20260825.md`；五级=`measure:edge121-webhook-minute-dedup/na/na/na/na`；formal journal=`3091`，COVERAGE=`848/618/0`，anchors=`10/10`，`alarms.py check` clean（机械警报已复核 ack）。
- 批次六十当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-122`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-120 webhook HMAC 不匹配

- 真实 contract 通过：HMAC 正签名 `202`，错误签名/错误 header `401` 纯文本；明文 secret 缺失/错误同样 `401`，拒绝不进入 workflow。
- 正式证据=`testend/rig/formal-evidence/EDGE-120-webhook-hmac-mismatch-20260825.md`；五级=`measure:edge120-webhook-hmac-mismatch/na/na/na/na`；formal journal=`3086`，COVERAGE=`848/617/0`，anchors=`10/10`，`alarms.py check` clean（机械警报已复核 ack）。
- 批次五十九已达到=`50/50`；统一长门禁已通过，证据=`testend/rig/formal-evidence/batch-59-unified-gate-20260825.md`，已提交 `49baf1c9`。批次六十从 `0/50` 开始，下一前线=`EDGE-121`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-119 webhook 路径改后旧路径

- 真实 contract 通过：Edit 改 `config.path` 后旧 webhook 路径 `404`，新路径 `202`，前后事件各完成一个 run，catch-all registry 无旧路由残留。
- 正式证据=`testend/rig/formal-evidence/EDGE-119-webhook-old-path-404-20260825.md`；五级=`measure:edge119-webhook-old-path-404/na/na/na/na`；formal journal=`3081`，COVERAGE=`848/616/0`，anchors=`10/10`，`alarms.py check` clean（机械警报已复核 ack）。
- 批次五十九当时=`45/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-120`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-118 暂停期间的 Edit 何时生效

- 应用回归与真实 sensor HTTP 路径通过：暂停期 Edit 不热挂 source，暂停/重启窗口无 run，resume 按当前编辑配置重新注册并触发新 sensor-origin run。
- 正式证据=`testend/rig/formal-evidence/EDGE-118-edit-config-takes-effect-on-resume-20260825.md`；五级=`measure:edge118-edit-config-takes-effect-on-resume/na/na/na/na`；formal journal=`3076`，COVERAGE=`848/615/0`，anchors=`10/10`，`alarms.py check` clean（机械警报已复核 ack）。
- 批次五十九当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-119`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-117 `Edit` 与 `:pause` 并发/暂停期配置生效

- 应用层 `-race` 与真实 sensor HTTP 路径通过：暂停期编辑不热挂 source，硬重启后暂停窗无 run，resume 读取编辑后的目标并恢复 sensor-origin run。
- 正式证据=`testend/rig/formal-evidence/EDGE-117-edit-while-paused-defers-20260825.md`；五级=`measure:edge117-edit-while-paused-defers/na/na/na/na`；formal journal=`3071`，COVERAGE=`848/614/0`，anchors=`10/10`，`alarms.py check` clean（机械警报已复核 ack）。
- 批次五十九当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-118`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-116 `resume` 的 Register 失败回滚

- focused `-race` regression 通过：首次 Resume 注册失败时返回错误、持久状态回滚为 paused、竞态报告不造 firing；source 恢复后重试 Resume 成功并恢复唯一 firing。
- 正式证据=`testend/rig/formal-evidence/EDGE-116-resume-register-rollback-20260825.md`；五级=`measure:edge116-resume-register-rollback/na/na/na/na`；formal journal=`3066`，COVERAGE=`848/613/0`，anchors=`10/10`，`alarms.py check` clean（机械警报已复核 ack）。
- 批次五十九当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-117`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-115 暂停时 `:fire` 大声拒

- 暂停源头与真实产品路径均通过：app regression 断言暂停后 `onReport` 不产生 firing/activation、`FireManual` 返回 `ErrPaused`；真实 HTTP `:fire` 返回 `422 TRIGGER_PAUSED`，硬重启跨 cron 边界不产生 run，resume 后下一次真实 cron run 成功。
- 正式证据=`testend/rig/formal-evidence/EDGE-115-paused-fire-rejected-20260825.md`；五级=`measure:edge115-paused-fire-rejected/na/na/na/na`；formal journal=`3061`，COVERAGE=`848/612/0`，anchors=`10/10`，`alarms.py check` clean（两条机械警报已复核 ack）。
- 批次五十九当前=`25/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-116`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-114 trigger 暂停在源头注销

- 新增四源 pause 护栏并通过：cron/webhook/fsnotify/sensor 都调用 source `Unregister`；真实 fsnotify/sensor pause→重启→resume 路径通过。
- 正式证据=`testend/rig/formal-evidence/EDGE-114-pause-unregisters-source-20260825.md`；五级=`measure:edge114-pause-unregisters-source/na/na/na/na`；formal journal=`3056`，COVERAGE=`848/611/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十九当前=`20/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-115`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-113 sensor 电平触发风暴

- 新增 level-triggered regression 并通过：连续三轮 sustained-true probe 都 fired；真实 HTTP sensor → workflow 路径也通过，activation 保留 probe return value。
- 正式证据=`testend/rig/formal-evidence/EDGE-113-sensor-level-trigger-storm-20260825.md`；五级=`measure:edge113-sensor-level-trigger-storm/na/na/na/na`；formal journal=`3051`，COVERAGE=`848/610/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十九当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-114`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-112 shed 孤儿 firing

- scheduler regression 通过：workflow 删除后的 pending firing 首次 drain 进入 `shed`，再次 drain 不重试、不造 flowrun。
- 正式证据=`testend/rig/formal-evidence/EDGE-112-shed-orphan-firing-20260825.md`；五级=`measure:edge112-shed-orphan-firing/na/na/na/na`；formal journal=`3046`，COVERAGE=`848/609/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十九当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-113`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-111 AppendFiring 撞键返已存在行

- trigger service regression 通过：真实 fire 撞上 missed dedup key 后救回原行为唯一 pending，activation 计数与 `activation_id` 血缘正确。
- 正式证据=`testend/rig/formal-evidence/EDGE-111-append-firing-requeues-missed-20260825.md`；五级=`measure:edge111-append-firing-requeues-missed/na/na/na/na`；formal journal=`3041`，COVERAGE=`848/608/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十九当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-112`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-110 睡醒伪 fire 吸附/丢弃

- cron infra regression 通过：准时与容差内迟到回调吸附到合法刻度，超容差 wake artifact 被丢弃，不隐式补跑。
- 正式证据=`testend/rig/formal-evidence/EDGE-110-wake-artifact-snap-or-drop-20260825.md`；五级=`measure:edge110-wake-artifact-snap-or-drop/na/na/na/na`；formal journal=`3036`，COVERAGE=`848/607/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十八已达到=`50/50`；统一长门禁已通过，证据=`testend/rig/formal-evidence/batch-58-unified-gate-20260825.md`，已提交 `64bc55fd`。下一前线=`EDGE-111`，批次五十九从 `0/50` 开始。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-109 misfire 台账双封顶

- trigger service regression 通过：weekly 稀疏全年精确、daily 受 30 天窗口约束、minutely 恰好 200 条封顶，第二次 sweep 无新增。
- 正式证据=`testend/rig/formal-evidence/EDGE-109-misfire-double-cap-20260825.md`；五级=`measure:edge109-misfire-double-cap/na/na/na/na`；formal journal=`3031`，COVERAGE=`848/606/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十八当前=`45/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-110`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-108 catchup_one 崩溃窗不重跑

- trigger service regression 通过：fan-out 已提交、水位未推进的崩溃重查不新增 activation，pending catch-up 保持一个。
- 正式证据=`testend/rig/formal-evidence/EDGE-108-catchup-one-crash-window-20260825.md`；五级=`measure:edge108-catchup-one-crash-window/na/na/na/na`；formal journal=`3026`，COVERAGE=`848/605/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十八当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-109`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-107 catchup_one 补一个

- trigger service regression 通过：多个错过刻度只补最近一个，较早刻度保持 missed，二次 sweep 不重复补跑。
- 正式证据=`testend/rig/formal-evidence/EDGE-107-catchup-one-exactly-once-20260825.md`；五级=`measure:edge107-catchup-one-exactly-once/na/na/na/na`；formal journal=`3021`，COVERAGE=`848/604/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十八当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-108`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-106 暂停期间的错过不算 misfire

- trigger service regression 通过：暂停期间 sweep 不记 missed；`:resume` 闭合暂停窗口，后续 sweep 仍不产生 missed。
- 正式证据=`testend/rig/formal-evidence/EDGE-106-pause-not-misfire-20260825.md`；五级=`measure:edge106-pause-not-misfire/na/na/na/na`；formal journal=`3016`，COVERAGE=`848/603/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十八当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-107`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-105 AttachReplay 零值纪元

- trigger service regression 通过：同一 cron 上，boot `AttachReplay` 的旧 workflow 记入缺口，实时 `Attach` 的新 workflow 不被追溯记账；引用集与 listener 共享关系正确。
- 正式证据=`testend/rig/formal-evidence/EDGE-105-attach-replay-zero-epoch-20260825.md`；五级=`measure:edge105-attach-replay-zero-epoch/na/na/na/na`；formal journal=`3011`，COVERAGE=`848/602/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十八当前=`25/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-106`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-104 hotSince 下界

- trigger service regression 通过：AttachReplay 后做旧约 90 秒，重启 entry 的 `hotSince` 下界令死刻度立即记 missed、不进 pending，不等两分钟 live 容差。
- 正式证据=`testend/rig/formal-evidence/EDGE-104-hot-since-lower-bound-20260825.md`；五级=`measure:edge104-hot-since-lower-bound/na/na/na/na`；formal journal=`3006`，COVERAGE=`848/601/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十八当前=`20/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-105`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-103 窗口上界留容差尾带

- trigger service regression 通过：尾带之前的 gap 记账，`MisfireTolerance` 内仍可能迟到的刻度不被抢先记 `missed`，watermark 不越界。
- 正式证据=`testend/rig/formal-evidence/EDGE-103-misfire-tolerance-upper-bound-20260825.md`；五级=`measure:edge103-misfire-tolerance-upper-bound/na/na/na/na`；formal journal=`3001`，COVERAGE=`848/600/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十八当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-104`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-102 睡眠期 misfire（进程仍活）

- `SweepMisfires` 时间状态 regression 通过：活 listener 睡过墙钟时，尾带前记账，`MisfireTolerance` 尾带不被偷占，watermark 不越界；不伪造实际一小时睡眠录像。
- 正式证据=`testend/rig/formal-evidence/EDGE-102-live-misfire-tolerance-band-20260825.md`；五级=`measure:edge102-live-misfire-tolerance-band/na/na/na/na`；formal journal=`2996`，COVERAGE=`848/599/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十八当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-103`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-101 misfire 记账不补跑

- 真实 HTTP `SIGKILL` 跨分钟重启场景通过：boot 记 `missed=1`，missed 行无 flowrun、不进 pending、不重复；firing/workspace/window/stats 读侧全通过。trigger focused `-race` 的幂等、重启死刻度、活进程尾带也通过。
- 正式证据=`testend/rig/formal-evidence/EDGE-101-misfire-missed-accounting-20260825.md`；五级=`measure:edge101-misfire-missed-accounting/na/na/na/na`；formal journal=`2991`，COVERAGE=`848/598/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十八当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-102`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-100 LLM 工具 flowrun 节点封顶

- 新增 2001-row scale regression 与真实 25 轮 loop HTTP 分页通过：LLM 投影封顶 80 行，保留 failure/parked 与最近 completed 尾巴，`nodeSummary` 总数正确；REST 全量分页、每轮唯一、执行审计 join 完整。
- 正式证据=`testend/rig/formal-evidence/EDGE-100-flowrun-node-cap-20260825.md`；五级=`measure:edge100-flowrun-node-cap/na/na/na/na`；formal journal=`2986`，COVERAGE=`848/597/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十七已达到=`50/50`；统一长门禁已通过，证据=`testend/rig/formal-evidence/batch-57-unified-gate-20260825.md`，已提交 `d52047b4`；下一前线=`EDGE-101`，批次五十八从 `0/50` 开始。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-099 flowruns 两种分页互斥

- handler `-race` 单测与真实 HTTP offset-pagination scenario 通过：`cursor` 与 `offset` 同时出现时先报 `422 FLOWRUN_LIST_CURSOR_OFFSET_CONFLICT`；单独坏 offset 仍是参数错误，offset/cursor 两种分页及负值边界保持契约。
- 正式证据=`testend/rig/formal-evidence/EDGE-099-flowruns-cursor-offset-conflict-20260825.md`；五级=`measure:edge099-flowruns-cursor-offset-conflict/na/na/na/na`；formal journal=`2981`，COVERAGE=`848/596/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十七当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-100`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-098 activity 排队段负值

- Flutter `66` 项 scheduler timing/run tests、后端 activity `-race` 与真实 HTTP activity scenario 通过：负 queue span 钳零，缺真相戳诚实缺席，真实双 agent queue stamp/执行窗一致。
- 正式证据=`testend/rig/formal-evidence/EDGE-098-activity-queue-negative-clamp-20260825.md`；五级=`measure:edge098-activity-queue-negative-clamp/na/na/na/na`；formal journal=`2976`，COVERAGE=`848/595/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十七当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-099`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-097 matrix 多迭代最坏处置

## 2026-08-25 · EDGE-097 matrix 多迭代最坏处置

- store `-race` 三个 rank/iteration regression 与真实 HTTP matrix scenario 通过：failed 压过 completed，parked 压过 completed，cancelled 中性不误报。
- 正式证据=`testend/rig/formal-evidence/EDGE-097-flowrun-matrix-worst-iteration-20260825.md`；五级=`measure:edge097-flowrun-matrix-worst-iteration/na/na/na/na`；formal journal=`2971`，COVERAGE=`848/594/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十七当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-098`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-096 flowrun-matrix 未知 id

## 2026-08-25 · EDGE-096 flowrun-matrix 未知 id

- store `-race`、app guard 与真实 HTTP scenario 通过：异 workspace/未知 id 静默缺席，混合只返回已知，全未知为空三列表；空参数、上限、去重和裸 ctx 隔离边界通过。
- 正式证据=`testend/rig/formal-evidence/EDGE-096-flowrun-matrix-unknown-id-20260825.md`；五级=`measure:edge096-flowrun-matrix-unknown-id/na/na/na/na`；formal journal=`2966`，COVERAGE=`848/593/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十七当前=`25/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-097`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-095 flowrun-stats 倒挂窗

## 2026-08-25 · EDGE-095 flowrun-stats 倒挂窗

- store `-race` 与真实 HTTP scenario 通过：`until <= since` 静默给空窗口，recent/lastRunAt 保留；正常上界、未来 since、超限和坏参数也通过。port-1 free-tier warning 是隔离 harness 预期关闭端口。
- 正式证据=`testend/rig/formal-evidence/EDGE-095-flowrun-stats-inverted-window-20260825.md`；五级=`measure:edge095-flowrun-stats-inverted-window/na/na/na/na`；formal journal=`2961`，COVERAGE=`848/592/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十七当前=`20/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-096`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-094 mode=0 老库升级

## 2026-08-25 · EDGE-094 mode=0 老库升级

- 真实落盘 SQLite `-race` focused 通过：mode=0 Compact 后回收死空间、`migrated=true`、行完整；重开旧 DSN 仍为 INCREMENTAL；第二次 Compact `migrated=false`，相邻成功/app seam 也通过。
- 正式证据=`testend/rig/formal-evidence/EDGE-094-mode0-compact-migration-20260825.md`；五级=`measure:edge094-mode0-compact-migration/na/na/na/na`；formal journal=`2956`，COVERAGE=`848/591/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十七当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-095`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-093 手动 VACUUM 压缩失败

## 2026-08-25 · EDGE-093 手动 VACUUM 压缩失败

- storage app `-race` focused 通过：只读 SQLite 模拟文件写入拒绝，稳定映射 `STORAGE_COMPACT_FAILED`，文件大小与 probe 行数不变；成功 Compact 路径同组通过。真实 ENOSPC 不在开发机制造，证据已明确标注替身边界。
- 正式证据=`testend/rig/formal-evidence/EDGE-093-storage-compact-failure-20260825.md`；五级=`measure:edge093-storage-compact-failure/na/na/na/na`；formal journal=`2951`，COVERAGE=`848/590/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十七当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-094`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-092 磁盘回收闸；批次五十七开始

- 真实落盘 SQLite `-race` focused 通过：49.3MB 死空间越过比例门后实际缩文件、3000 行存活；约 5% routine churn 低于比例与 128MiB 两道门，回收 0 且文件不动；Stat/app storage 映射通过，无生产逻辑改动。
- 正式证据=`testend/rig/formal-evidence/EDGE-092-disk-reclamation-gate-20260825.md`；五级=`measure:edge092-disk-reclamation-gate/na/na/na/na`；formal journal=`2946`，COVERAGE=`848/589/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十七当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-093`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · 批次五十六已提交

## 2026-08-25 · EDGE-091 保留清理后的孤儿深链；批次五十六收满

- Flutter scheduler focused `77` 项通过：孤儿 run host 404、墓碑、无图 fallback、不可解析深链均诚实渲染，不白屏、不伪造当前图。
- 正式证据=`testend/rig/formal-evidence/EDGE-091-retention-orphan-deep-link-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-091-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge091-retention-orphan-deep-link/na/na/na/na`；formal journal=`2941`，COVERAGE=`848/588/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十六达到=`50/50`；统一长门禁已通过，证据=`testend/rig/formal-evidence/batch-56-unified-gate-20260825.md`，已提交 `b93d228c`；下一前线=`EDGE-092`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-090 run 历史保留清理

- Boot wiring + store cascade/boundary/batch/workspace focused 通过；30d 清理旧 completed，running 与永久保留存活。
- 正式证据=`testend/rig/formal-evidence/EDGE-090-run-retention-purge-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-090-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge090-run-retention-purge/na/na/na/na`；formal journal=`2936`，COVERAGE=`848/587/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十六当前=`45/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-091`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-089 draining 最后一个 run 结算

- `:deactivate` 先 draining，不杀在途 run；run 结算后 workflow 才 inactive；真实 HTTP 场景通过。
- 正式证据=`testend/rig/formal-evidence/EDGE-089-draining-last-run-settles-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-089-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge089-draining-last-run-settles/na/na/na/na`；formal journal=`2931`，COVERAGE=`848/586/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十六当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-090`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-088 per-run 单飞 + redrive

- 同一 run 三次 advance 只执行节点一次；中途信号走 redrive；scheduler `-race` 通过。
- 正式证据=`testend/rig/formal-evidence/EDGE-088-per-run-single-flight-redrive-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-088-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge088-per-run-single-flight-redrive/na/na/na/na`；formal journal=`2926`，COVERAGE=`848/585/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十六当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-089`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-087 sendJob 撞已关队列

- 关闭 queue 上的迟到 send 被 recover，dedup 槽清掉，进程不崩；scheduler `-race` 通过。
- 正式证据=`testend/rig/formal-evidence/EDGE-087-send-job-closed-queue-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-087-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge087-send-job-closed-queue/na/na/na/na`；formal journal=`2921`，COVERAGE=`848/584/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十六当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-088`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-086 advClosing 关停不跑缓冲 run

- Shutdown 置 `advClosing` 后跳过队列里的 run，run 保持 running 等 Recover；scheduler `-race` 通过。
- 正式证据=`testend/rig/formal-evidence/EDGE-086-adv-closing-skips-buffered-run-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-086-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge086-adv-closing-skips-buffered-run/na/na/na/na`；formal journal=`2916`，COVERAGE=`848/583/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十六当前=`25/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-087`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-085 pin 闭包冻结在途 run

- 真实 HTTP 场景验证 function/control 的 run pin：编辑后原 run 仍走旧版本，新 run 才走新 active 版本。
- 正式证据=`testend/rig/formal-evidence/EDGE-085-pin-closure-inflight-run-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-085-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge085-pin-closure-inflight-run/na/na/na/na`；formal journal=`2911`，COVERAGE=`848/582/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十六当前=`20/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-086`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-084 菱形 join 未守 has()

- 未选 control 分支的缺字段读取以 `no such key` 失败；新增 scheduler regression，只增加护栏、不改逻辑。
- 正式证据=`testend/rig/formal-evidence/EDGE-084-diamond-join-missing-key-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-084-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge084-diamond-join-missing-key/na/na/na/na`；formal journal=`2906`，COVERAGE=`848/581/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十六当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-085`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-083 MaxIterations 栅栏

- 永真回边跑到 `iteration 0..1000` 共 1001 行后失败，错误写明 `MaxIterations (1000)`；focused scheduler `-race` 通过。
- 正式证据=`testend/rig/formal-evidence/EDGE-083-max-iterations-fence-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-083-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge083-max-iterations-fence/na/na/na/na`；formal journal=`2901`，COVERAGE=`848/580/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十六当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-084`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-082 replay 与保留清理竞速

- 保留清理父表删除重新检查终态；`:replay` 的 guarded UPDATE 赢时，清理输；stale replay 返回 `ErrNotReplayable`。
- 正式证据=`testend/rig/formal-evidence/EDGE-082-replay-retention-race-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-082-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge082-replay-retention-race/na/na/na/na`；formal journal=`2896`，COVERAGE=`848/579/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十六当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-083`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-081 并发 :replay 守卫；批次五十五收满

- `WHERE status='failed'` 只允许一个 replay 逆转；输家 `FLOWRUN_NOT_REPLAYABLE`，新终态不被复活，`replay_count=1`；普通、`-race`、完整 store 全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-081-replay-concurrent-guard-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-081-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge081-replay-concurrent-guard/na/na/na/na`；formal journal=`2891`，COVERAGE=`848/578/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十五已达到=`50/50`；统一长门禁已通过，证据=`testend/rig/formal-evidence/batch-55-unified-gate-20260825.md`，待本批提交，不推进下一前线。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-080 :replay 只收 failed

- cancelled run 是终局，`:replay` 返回 `FLOWRUN_NOT_REPLAYABLE` 且不改状态；普通、`-race`、黑盒全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-080-replay-only-failed-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-080-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge080-replay-only-failed/na/na/na/na`；formal journal=`2886`，COVERAGE=`848/577/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十五当前=`45/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-081`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-079 恢复后排队戳是新起点

- 恢复 walk 为未落行节点铸造新的 `ready_at`，不回填原创建时间；普通与 `-race` timing 全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-079-recovery-ready-at-new-origin-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-079-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge079-recovery-ready-at-new-origin/na/na/na/na`；formal journal=`2881`，COVERAGE=`848/576/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十五当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-080`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-078 崩溃恢复 Recover

- Recover 入池而非内联；完成节点跳过、丢失节点重跑、慢 recovered run 不阻塞其它 run；普通与 `-race` 全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-078-crash-recovery-rewalk-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-078-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge078-crash-recovery-rewalk/na/na/na/na`；formal journal=`2876`，COVERAGE=`848/575/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十五当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-079`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-077 被打断的在飞节点不落行

- 在飞 agent 被取消后，run=`cancelled`，节点不落 `flowrun_nodes`/`failed`，后续 run 可继续；普通、`-race`、黑盒全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-077-cancel-interrupted-node-no-row-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-077-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge077-cancel-interrupted-node-no-row/na/na/na/na`；formal journal=`2871`，COVERAGE=`848/574/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十五当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-078`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-076 收割闸与永久停滞子图

- first-wins 输家保留 failed run 的 parked approval，不执行收割，避免 replay 无法清理的混合子图；普通与 `-race` 全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-076-cancel-loser-must-not-sweep-parked-subgraph-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-076-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge076-cancel-loser-must-not-sweep-parked-subgraph/na/na/na/na`；formal journal=`2866`，COVERAGE=`848/573/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十五当前=`25/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-077`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-075 取消赢家收割 parked 审批

- 取消 parked run 时只有 header guard winner 才收割 approval；node=`cancelled`、inbox 清空、无 false `failed`，普通/race/黑盒全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-075-cancel-winner-sweeps-parked-approval-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-075-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge075-cancel-winner-sweeps-parked-approval/na/na/na/na`；formal journal=`2861`，COVERAGE=`848/572/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十五当前=`20/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-076`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-074 run 取消竞态输家

- 自然终态先赢头守卫时，`:cancel` 返回 `FLOWRUN_NOT_CANCELLABLE`，自然 failed 头与 parked 行保持不变，取消方不发第二条 `run_terminal`；普通、`-race` 与黑盒全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-074-flowrun-cancel-natural-terminal-loser-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-074-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge074-flowrun-cancel-natural-terminal-loser/na/na/na/na`；formal journal=`2856`，COVERAGE=`848/571/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十五当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-075`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-073 approval 版本 resolve 失败

- 钉死 approval 版本解析失败时，inbox 行保留 flowrun/workflow 身份并继续可决策，只省略 `deadline`；focused 普通与 `-race` scheduler 全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-073-approval-version-resolve-failure-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-073-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge073-approval-version-resolve-failure/na/na/na/na`；formal journal=`2851`，COVERAGE=`848/570/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十五当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-074`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-072 approval 显式零时长

- `0s`/`0ms`、非法 duration、非空 timeout 缺 behavior 均在创建前返回 422 `APPROVAL_INVALID_TIMEOUT`；`""` 仍代表永不超时。领域、应用层和黑盒契约场景全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-072-approval-explicit-zero-duration-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-072-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge072-approval-explicit-zero-duration/na/na/na/na`；formal journal=`2846`，COVERAGE=`848/569/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十五当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-073`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-071 approval 三种超时行为；批次五十四收满

- timeout reject/approve/fail 分别落 no/yes/failed，publish 的 0/1/0 副作用与 durable node/run 状态均已断言；focused 普通/race/full scheduler 全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-071-approval-timeout-behaviors-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-071-ledger-alarm-reaudit-20260825.md`。
- 五级=`measure:edge071-approval-timeout-behaviors/na/na/na/na`；不伪造真实 App 五通道、帧时延、视觉或导航证据。formal journal=`2841`，COVERAGE=`848/568/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十四已达到=`50/50`；统一长门禁已通过，证据=`testend/rig/formal-evidence/batch-54-unified-gate-20260825.md`，待本批提交，不推进下一前线。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-070 approval 人工 vs 超时 first-wins

- 人工 YES 与 timeout sweep 并发争抢同一 parked node 时只一方写入，输家 `ErrNodeNotParked`，run/下游分支与记录一致，后续重复决策拒绝。
- focused 普通、focused `-race` 与完整 scheduler 包全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-070-approval-human-timeout-first-wins-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-070-ledger-alarm-reaudit-20260825.md`。
- 五级=`measure:edge070-approval-human-timeout-first-wins/na/na/na/na`；不伪造真实 App 五通道、帧时延、视觉或导航证据。formal journal=`2836`，COVERAGE=`848/567/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十四当前=`45/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-071`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-069 ClaimFiring 事务崩溃回滚

- 注入 callback 在 claim 后、commit 前写 partial flowrun 关联并返回错误；事务回滚，firing 仍 pending 且无关联，不留 claimed-but-no-run。
- focused 普通、focused `-race` 与完整 trigger store 包全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-069-claim-firing-rollback-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-069-ledger-alarm-reaudit-20260825.md`。
- 五级=`measure:edge069-claim-firing-rollback/na/na/na/na`；不伪造真实 App 五通道、帧时延、视觉或导航证据。formal journal=`2831`，COVERAGE=`848/566/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十四当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-070`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-068 两阶段 drain 背靠背触发

- 同批两个 firing 先全量 claim/seed、再统一 advance；serial 留 pending、skip 标 skipped、replace 一取消一成功、buffer_one supersede 旧 firing 只跑最新。
- 普通、`-race` 与完整 scheduler 包全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-068-two-phase-drain-same-batch-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-068-ledger-alarm-reaudit-20260825.md`。
- 五级=`measure:edge068-two-phase-drain-same-batch/na/na/na/na`；不伪造真实 App 五通道、帧时延、视觉或导航证据。formal journal=`2826`，COVERAGE=`848/565/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十四当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-069`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-067 手动 :trigger 绕过 overlap

- HTTP `:trigger` 与 chat `trigger_workflow` 走共享手动 `StartRun`，replace/buffer_one 下两个并发手动 run 都进入 action 并完成；real-firing inbox 才应用 overlap。
- focused 普通、focused `-race`、trigger_workflow 契约与完整 scheduler 包全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-067-manual-trigger-bypasses-overlap-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-067-ledger-alarm-reaudit-20260825.md`。
- 五级=`measure:edge067-manual-trigger-bypasses-overlap/na/na/na/na`；不伪造真实 App 五通道、帧时延、视觉或导航证据。formal journal=`2821`，COVERAGE=`848/564/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十四当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-068`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-066 overlap allow_all 并发

- 高频 inbox 一次灌入 8 条 allow_all firing，8 个 run 全部 seed；前四个慢 action 占满 `advanceWorkers=4`，第五个被池自然阻挡，释放后 8 个全部完成且 action 各一次。
- 首轮失败来自测试夹具 gate 键名与图输入字段不一致，修正后重跑；生产池上限未放宽。
- focused 普通、focused `-race`、allow_all/pool 回归与完整 scheduler 包全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-066-overlap-allow-all-pool-cap-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-066-ledger-alarm-reaudit-20260825.md`。
- 五级=`measure:edge066-overlap-allow-all-pool-cap/na/na/na/na`；不伪造真实 App 五通道、帧时延、视觉或导航证据。formal journal=`2816`，COVERAGE=`848/563/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十四当前=`25/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-067`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-065 overlap replace 抢占

- 在途 run 被新 `replace` firing 以 guarded terminal transition 取消后，firing 被消费并创建唯一 successor；旧 run 为 `cancelled`，successor 完成，action 只执行一次。同批替换回归仍通过。
- 首轮诊断暴露测试夹具缺 `start.orderId`，已补齐输入而非放宽断言；生产代码未改。
- focused 普通、focused `-race` 与完整 scheduler 包全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-065-overlap-replace-preempts-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-065-ledger-alarm-reaudit-20260825.md`。
- 五级=`measure:edge065-overlap-replace-preempts/na/na/na/na`；不伪造真实 App 五通道、帧时延、视觉或导航证据。formal journal=`2811`，COVERAGE=`848/562/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十四当前=`20/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-066`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-064 overlap buffer_one 收敛

- 三个真实 firing 在途期间收敛为两个 `superseded` + 最新 `pending`，不提前 dispatch；run 结束后下一 drain 只执行最新一个 successor/action。
- focused 普通/race、store supersede 与完整 scheduler 包全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-064-overlap-buffer-one-converges-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-064-ledger-alarm-reaudit-20260825.md`。
- 五级=`measure:edge064-overlap-buffer-one-converges/na/na/na/na`；不伪造真实 App 五通道、帧时延、视觉或导航证据。formal journal=`2806`，COVERAGE=`848/561/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十四当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-065`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-063 overlap skip 丢弃

- 已验证 skip overlap：在途 run 时新 firing 直接落中性 `skipped` 审计行，不留 pending、不建 successor、不 dispatch；与 serial 排队分离。
- focused 普通/race 与完整 scheduler 包全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-063-overlap-skip-neutral-disposition-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-063-ledger-alarm-reaudit-20260825.md`。
- 五级=`measure:edge063-overlap-skip-neutral-disposition/na/na/na/na`；不伪造真实 App 五通道、帧时延、视觉或导航证据。formal journal=`2801`，COVERAGE=`848/560/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十四当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-064`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-062 overlap serial 推迟

- 已验证真实 firing 的 serial 语义：在途 run 存在时新 firing 保持 pending、不建并发 run；前一 run 结算后下一次 drain 消费它，successor/action 各一个；与 skip 对照明确分离。
- focused 普通/race 与完整 scheduler 包全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-062-overlap-serial-defers-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-062-ledger-alarm-reaudit-20260825.md`。
- 五级=`measure:edge062-overlap-serial-defers/na/na/na/na`；不伪造真实 App 五通道、帧时延、视觉或导航证据。formal journal=`2796`，COVERAGE=`848/559/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十四当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-063`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-061 transcriptResync 不可与 lifecycleResync 互顶

- messages 与 notifications 的 410 语义严格分离；对话列表同时订阅两者，transcript 只订 messages。新增反向回归证明 notifications resync 不会清掉 live transcript，messages resync 才能从 durable head 收口。
- 对话流、人在环、列表、transcript、touchpoint 和 jump 相关 Flutter 测试共 `104 passed`。
- 正式证据=`testend/rig/formal-evidence/EDGE-061-transcript-resync-boundary-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-061-ledger-alarm-reaudit-20260825.md`。
- 五级=`measure:edge061-transcript-resync-boundary/na/na/na/na`；不伪造真实 App 五通道、帧时延、视觉或导航证据。formal journal=`2791`，COVERAGE=`848/558/0`，anchors=`10/10`，`alarms.py check` clean。
- 批次五十三已达到=`50/50`；统一长门禁、完整 testend、rig 自测、覆盖/锚点/警报和残留进程审计均通过，证据=`testend/rig/formal-evidence/batch-53-unified-gate-20260825.md`；本批次随后提交。下一前线=`EDGE-062`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-060 lifecycleResync 六处配对

- notifications 流 410 的同流 resync 已由 chat rail、对话头、实体列表、实体详情、Library 文档树和 Skill 列表六类消费者接线；源码守卫阻止未来漏接。
- 定向 Flutter 守卫、对话 rail 410 重取、对话头、实体列表/详情和 Library 测试共 `115 passed`。
- 正式证据=`testend/rig/formal-evidence/EDGE-060-lifecycle-resync-six-pairing-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-060-ledger-alarm-reaudit-20260825.md`。
- 五级=`measure:edge060-lifecycle-resync-six-pairing/na/na/na/na`；不伪造真实 App 五通道、帧时延、视觉或导航证据。formal journal=`2786`，COVERAGE=`848/557/0`，anchors=`10/10`，`alarms.py check` clean。
- 当前批次=`45/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-061`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-059 ephemeral delta 丢弃不背压

- 真实 Bus 对慢订阅者灌 100,000 个 ephemeral delta 在 bounded guard 内完成，后续 durable seq 仍从 1 开始；普通/race/full stream 全绿，无实现红线。
- 正式证据=`testend/rig/formal-evidence/EDGE-059-ephemeral-delta-drop-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-059-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge059-ephemeral-delta-drop/na/na/na/na`，不伪造真实 App 五通道/视觉/导航证据。formal journal=`2781`，COVERAGE=`848/556/0`，anchors=`10/10`，`alarms.py check` clean。当前批次=`40/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-060`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-058 durable buffer 满断开卡死订阅者

- 真实 Bus 对只读订阅者灌满 durable channel 后在 bounded guard 内完成发布并断开卡死订阅者；普通/race/full stream 全绿，无实现红线。
- 正式证据=`testend/rig/formal-evidence/EDGE-058-durable-buffer-wedged-subscriber-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-058-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge058-durable-buffer-wedged-subscriber/na/na/na/na`，不伪造真实 App 五通道/视觉/导航证据。formal journal=`2776`，COVERAGE=`848/555/0`，anchors=`10/10`，`alarms.py check` clean。当前批次=`35/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-059`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-057 续传游标三来源

- 真实 handler 测试证明 `Last-Event-ID` > `fromSeq` > 缺失/非法归零，环外仍映射 410；普通/race/full handlers 全绿，无实现红线。
- 正式证据=`testend/rig/formal-evidence/EDGE-057-sse-cursor-sources-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-057-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge057-sse-cursor-sources/na/na/na/na`，不伪造真实 App 五通道/视觉/导航证据。formal journal=`2771`，COVERAGE=`848/554/0`，anchors=`10/10`，`alarms.py check` clean。当前批次=`30/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-058`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-056 SSE 410 SEQ_TOO_OLD 重放

- backend Bus 与真实 HTTP/SSE targeted scenario 均证明环外 cursor 返回 410 `SEQ_TOO_OLD`；L1 通过，因无独立 formal rig 五通道 session，L2-L5 严格 na；普通/race/full stream 与 targeted e2e 全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-056-sse-seq-too-old-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-056-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge056-sse-seq-too-old/na/na/na/na`，不伪造真实 App 五通道/视觉/导航证据。formal journal=`2766`，COVERAGE=`848/553/0`，anchors=`10/10`，`alarms.py check` clean。当前批次=`25/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-057`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-055 最近 2 条 message 的 durable 底线

- 真实两条超长 durable message 证明 persistent compaction 不越过最近两条：无 summary/archive/anchor/demote；独立 checkpoint 投影仍通过；普通/race/full contextmgr 全绿，无实现红线。
- 正式证据=`testend/rig/formal-evidence/EDGE-055-recent-two-durable-floor-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-055-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge055-recent-two-durable-floor/na/na/na/na`，不伪造真实 App 五通道/视觉/导航证据。formal journal=`2761`，COVERAGE=`848/552/0`，anchors=`10/10`，`alarms.py check` clean。当前批次=`20/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-056`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-054 附件跨压缩水位

- 真实 contextmgr 路径证明旧附件回合跨水位时 summary 只保留 opaque ID、旧 block 归档，后续通过 `read_attachment` 重读；普通/race/full contextmgr 全绿，无实现红线。
- 正式证据=`testend/rig/formal-evidence/EDGE-054-attachment-across-compaction-watermark-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-054-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge054-attachment-across-compaction-watermark/na/na/na/na`，不伪造真实 App 五通道/视觉/导航证据。formal journal=`2756`，COVERAGE=`848/551/0`，anchors=`10/10`，`alarms.py check` clean。当前批次=`15/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-055`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-053 demote 只动 tool_result

- 真实混合长回合证明 demote 只给 tool-result 分配 hot/warm/cold，user 大粘贴与 assistant 解释文本原文和 hot 状态不变；普通/race/full contextmgr 全绿，无实现红线。
- 正式证据=`testend/rig/formal-evidence/EDGE-053-demote-only-tool-results-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-053-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge053-demote-only-tool-results/na/na/na/na`，不伪造真实 App 五通道/视觉/导航证据。formal journal=`2751`，COVERAGE=`848/550/0`，anchors=`10/10`，`alarms.py check` clean。当前批次=`10/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-054`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-052 压缩读过滤被取代回合

- 真实 `MaybeCompact` 入口证明旧 assistant 版本不进入 summary prompt，当前版本进入压缩并推进水位；普通/race/full contextmgr 全绿，无实现红线。
- 正式证据=`testend/rig/formal-evidence/EDGE-052-compaction-filters-superseded-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-052-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge052-compaction-filters-superseded/na/na/na/na`，不伪造真实 App 五通道/视觉/导航证据。formal journal=`2746`，COVERAGE=`848/549/0`，anchors=`10/10`，`alarms.py check` clean。当前批次=`5/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-053`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-051 压缩水位幂等键

- contextmgr 的 crash-window 测试证明 `SetSummary` 写完 watermark 后崩溃，恢复重跑不二次摘要、不重复 archive/anchor，仍 hot 的 fixture block 不影响水位过滤；普通/race/full contextmgr 全绿，无实现红线。
- 正式证据=`testend/rig/formal-evidence/EDGE-051-compaction-watermark-idempotency-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-051-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge051-compaction-watermark-idempotency/na/na/na/na`，不伪造真实 App 五通道/视觉/导航证据。formal journal=`2741`，COVERAGE=`848/548/0`，anchors=`10/10`，`alarms.py check` clean。统一长门禁=`testend/rig/formal-evidence/batch-52-unified-gate-20260825.md` 已通过：根验证、完整 testend、rig、docs、清册、锚点、警报、格式、diff 与进程收台审计全绿。当前批次=`50/50`，门禁已通过并提交=`8ed36a5e`；下一前线=`EDGE-052`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-050 fork 血缘源被删

- 真实 SQLite conversation service 证明删除 source 后 source GET 为 not-found，fork 仍存活，两个血缘列保持历史指针，列表只显示 fork；无级联抹除或指针改写；普通/race/full conversation 全绿，无实现红线。
- 正式证据=`testend/rig/formal-evidence/EDGE-050-fork-source-deleted-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-050-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge050-fork-source-deleted/na/na/na/na`，不伪造真实 App 五通道/视觉/导航证据。formal journal=`2736`，COVERAGE=`848/547/0`，anchors=`10/10`，`alarms.py check` clean。当前批次=`45/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-051`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-049 fork parent_block_id 跨消息 remap

- 真实 messages store fixture 证明跨消息 subagent 子树的 block 级与 message 级父指针都 remap 到 fork 自己的 tool-call block；预铸 ID、连续重排、源树不变且无指针逃逸；普通/race/full chat 全绿，无实现红线。
- 正式证据=`testend/rig/formal-evidence/EDGE-049-fork-parent-block-remap-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-049-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge049-fork-parent-block-remap/na/na/na/na`，不伪造真实 App 五通道/视觉/导航证据。formal journal=`2731`，COVERAGE=`848/546/0`，anchors=`10/10`，`alarms.py check` clean。当前批次=`40/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-050`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-048 fork 版本指针 remap

- 真实 SQLite fork fixture 证明完整 fork 将 `superseded_by` 与 `attrs.retryOf` 双向重映射到 fork 自己的 message ID；切在旧版本时，窗口外取代者清零、悬空 `retryOf` 丢弃；普通与 focused `-race` 全绿，无实现红线。
- 正式证据=`testend/rig/formal-evidence/EDGE-048-fork-version-pointer-remap-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-048-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge048-fork-version-pointer-remap/na/na/na/na`，不伪造真实 App 五通道/视觉/导航证据。formal journal=`2726`，COVERAGE=`848/545/0`，anchors=`10/10`，`alarms.py check` clean。当前批次=`35/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-049`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-047 fork 切在水位之前不带 summary

- 真实 fork/store 在 summary watermark 之前切分，summary 与 watermark 双双丢弃，LLM 只见自身前缀，不收到描述不存在历史的摘要；普通/race/full chat 全绿，无实现红线。
- 正式证据=`testend/rig/formal-evidence/EDGE-047-fork-summary-drop-before-watermark-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-047-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge047-fork-summary-drop-before-watermark/na/na/na/na`，不伪造真实 App 五通道/视觉/导航证据。formal journal=`2721`，COVERAGE=`848/544/0`，anchors=`10/10`，`alarms.py check` clean。当前批次=`30/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-048`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-046 fork summary 水位重定基

- 真实 fork/store 在摘要水位之后切压缩线程，摘要随 fork 且 watermark 重定基到 fork 自己的 block seq，LLM 投影准确隐藏已折叠块；普通/race/full chat 全绿，无实现红线。
- 正式证据=`testend/rig/formal-evidence/EDGE-046-fork-summary-rebase-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-046-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge046-fork-summary-rebase/na/na/na/na`，不伪造真实 App 五通道/视觉/导航证据。formal journal=`2716`，COVERAGE=`848/543/0`，anchors=`10/10`，`alarms.py check` clean。当前批次=`25/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-047`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-045 retry 的 modelOverride 逐回合

- recording resolver 真实记录首轮默认、retry 显式 override、下一轮默认；retry 行记录真实 model id，conversation head 不变。普通/race/full chat 全绿，无实现红线。
- 正式证据=`testend/rig/formal-evidence/EDGE-045-retry-model-override-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-045-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge045-retry-model-override/na/na/na/na`，不伪造真实 App 五通道/视觉/导航证据。formal journal=`2711`，COVERAGE=`848/542/0`，anchors=`10/10`，`alarms.py check` clean。当前批次=`20/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-046`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-044 retry 非终态尾巴

- 内存阻塞 provider 与真实 durable `streaming` 尾巴两道 retry 闸均返回 `STREAM_IN_PROGRESS`，不追加 user/assistant，原线程不变；普通/race/full chat 全绿，无实现红线。
- 正式证据=`testend/rig/formal-evidence/EDGE-044-retry-nonterminal-tail-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-044-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge044-retry-nonterminal-tail/na/na/na/na`，不伪造真实 App 五通道/视觉/导航证据。formal journal=`2706`，COVERAGE=`848/541/0`，anchors=`10/10`，`alarms.py check` clean。当前批次=`15/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-045`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-043 retry 写序中断留重复问句

- 真实 messages store 在新 user 提交后、旧 supersede 指针写入前故障，retry 返回错误但原 user、原回答、编辑 user 均留存，LLM history 不静默丢交流；普通/race/full chat 全绿，无实现红线。
- 正式证据=`testend/rig/formal-evidence/EDGE-043-retry-write-order-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-043-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge043-retry-write-order/na/na/na/na`，不伪造真实 App 五通道/视觉/导航证据。formal journal=`2701`，COVERAGE=`848/540/0`，anchors=`10/10`，`alarms.py check` clean。当前批次=`10/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-044`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-042 retry 尾巴是无回答的 user 行

- 真实 service/store 构造 assistant 尚未铸出即崩溃的 user-only 尾巴；boot `SweepOrphans` 后空 retry 走既有 queue 补出缺失回答，不新增 user、不伪造 `retryOf`，耐久线程为一个 user + 一个 assistant，普通/race/full chat 全绿，无实现红线。
- 正式证据=`testend/rig/formal-evidence/EDGE-042-retry-bare-user-tail-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-042-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge042-retry-bare-user-tail/na/na/na/na`，不伪造真实 App 五通道/视觉/导航证据。formal journal=`2696`，COVERAGE=`848/539/0`，anchors=`10/10`，`alarms.py check` clean。当前批次=`5/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-043`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-041 retryOf 在 close 快照里

- retry assistant 的 `message_stop` close 快照经真实 JSON 带 `retryOf`，晚连客户端或 410 replay 仅凭 close 即可重建版本链；普通回合 close 不带指针。open companion、普通/race focused 全绿，无实现红线。
- 正式证据=`testend/rig/formal-evidence/EDGE-041-retry-close-snapshot-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-041-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge041-retry-close-snapshot/na/na/na/na`，不伪造真实 App 五通道/视觉/导航证据。formal journal=`2691`，COVERAGE=`848/538/0`，anchors=`10/10`，`alarms.py check` clean。批次统一长门禁=`testend/rig/formal-evidence/batch-51-unified-gate-20260825.md` 已通过：根 `make verify`、完整 backend `testend=274.381s`、rig=`51/51`、docs、清册、锚点、警报、格式、diff 和进程收台审计全绿。当前批次=`50/50`，门禁已通过，待提交。下一前线暂不推进。P12 400+ Journey 继续按用户裁定推迟二期。

## 2026-08-25 · EDGE-040 superseded 指针只挡 LLM 视图

- 真实 chat service + messages store 验证：普通 older cursor 找回旧 assistant，`around=<oldId>` 以旧行作目标并保留当前版本，`dir=newer` 沿窗口游标到达更晚回合；只有 `LoadThreadForLLM` 过滤旧正文。普通、focused `-race`、完整 chat 包全绿。首稿因两行记录没有 newer cursor 而停下，补真实后续回合后修正测试假设。
- 正式证据=`testend/rig/formal-evidence/EDGE-040-superseded-reads-20260825.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-040-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge040-superseded-reads/na/na/na/na`，不伪造真实 App 五通道/视觉/导航证据。formal journal=`2686`，COVERAGE=`848/537/0`，anchors=`10/10`，`alarms.py check` clean。当前批次=`45/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-041`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-039 `:retry` 编辑重发分支

- 非空 retry 同时 supersede 原 user/assistant，落编辑后的 user 并保留原附件，模型只读编辑后的回合且不继承旧 @ snapshot；普通/race
  focused 全绿，无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-039-retry-edit-resend-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-039-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge039-retry-edit-resend/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2681`，coverage=`848/536/0`，anchors=`10/10`，警报 clean。
  当前批次=`40/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-040`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-038 `:retry` 重生成分支

- 空 retry payload 只 supersede 末 assistant，旧回答/blocks 保留可读、不新增 user 问题，新答案走既有 queue，LLM 视图只见现行版本；
  普通/race focused 全绿，无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-038-retry-regenerate-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-038-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge038-retry-regenerate/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2676`，coverage=`848/535/0`，anchors=`10/10`，警报 clean。
  当前批次=`35/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-039`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-037 归档对话发消息自动解档

- chat Send 对 archived thread 先尝试 `Unarchive`；成功照常生成，失败按软失败仍让消息落盘并完成 assistant close。两路径普通/race
  focused 全绿，无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-037-archived-send-unarchive-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-037-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge037-archived-send-unarchive/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2671`，coverage=`848/534/0`，anchors=`10/10`，警报 clean。
  当前批次=`30/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-038`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-036 只发生过一轮的对话标题丢失

- 发现并修复真实缺口：`SetAutoTitle` 首次失败不再让一轮对话永久停在 `New chat`；保留已生成标题，在 detached lifecycle
  中做一次有界 fresh-budget 重试。测试第一次失败、第二次成功，复用同一标题且无第二次模型调用；完整 chat 普通/race 全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-036-autotitle-single-turn-retry-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-036-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge036-autotitle-single-turn-retry/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2666`，coverage=`848/533/0`，anchors=`10/10`，警报 clean。
  当前批次=`25/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-037`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-035 自动标题双预算

- 现有双预算回归把慢标题生成缩短并让 provider 每次无视取消、吃完整生成预算；生成出的标题仍通过 detached lifecycle context
  新取的五秒持久化预算落盘。普通/race focused 全绿，无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-035-autotitle-dual-budget-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-035-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge035-autotitle-dual-budget/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2661`，coverage=`848/532/0`，anchors=`10/10`，警报 clean。
  当前批次=`20/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-036`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-034 硬崩溃孤儿回合清扫

- 以 crash-shaped `pending`/`streaming` message 与 streaming block 验证 boot `SweepOrphans`：目标 workspace 全部变为
  `cancelled/StopReasonCancelled`，block 同步收尾；另一个 workspace 保持原状。普通/race focused 全绿，无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-034-sweep-orphans-workspace-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-034-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge034-sweep-orphans-workspace/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2656`，coverage=`848/531/0`，anchors=`10/10`，警报 clean。
  当前批次=`15/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-035`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-033 关页不留 streaming 孤儿

- 新增真实 chat service 取消回归：provider 流式已开始后调用 conversation cancel，Detached `WriteFinalize` 仍落
  `cancelled/StopReasonCancelled` 并发 `message_stop`；store 终态可读，queue 不再 active。普通/race focused 全绿，无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-033-cancel-stream-finalize-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-033-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge033-cancel-stream-finalize/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2651`，coverage=`848/530/0`，anchors=`10/10`，警报 clean。
  当前批次=`10/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-034`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-032 convQueue 5 分钟自毁后重建

- 生产 idle 策略仍为五分钟；测试 seam 只缩短时长以确定性验证：首回合结束后队列从 registry 消失，后续 Send 创建新队列并正常
  `message_stop`。拆卸/投递共用 `q.mu`，没有死 channel；测试发现并修复两处 timer reset 写死常量的问题，生产默认行为不变。普通/race
  chat 全包绿，无 stop-and-fix 遗留。
- 正式证据=`testend/rig/formal-evidence/EDGE-032-convqueue-idle-recreate-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-032-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge032-convqueue-idle-recreate/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2646`，coverage=`848/529/0`，anchors=`10/10`，警报 clean。
  当前批次=`5/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-033`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-031 回合收尾期单槽缓冲

- 可见收尾后同步 compaction 仍在进行时，running 已释放，恰一条后续 Send 可进单槽但不提前启动；compaction
  释放后才运行。blocking compactor + provider barrier 回归普通/race 全绿，无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-031-compaction-single-slot-buffer-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-031-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge031-compaction-single-slot-buffer/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2641`，coverage=`848/528/0`，anchors=`10/10`，
  警报 clean。批次五十=`50/50`；统一长门禁证据=`testend/rig/formal-evidence/batch-50-unified-gate-20260825.md`，`make verify`、完整
  `make -C backend testend`=`266.081s`、rig 51 tests、脚本/格式/清册/锚点/警报和进程审计全绿；本批随后提交；下一前线=`EDGE-032`。
  P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-030 生成中再 Send

- 第一条 assistant turn 已进入 provider stream 后，下一条同对话 Send 立即 `STREAM_IN_PROGRESS`，不排队；
  回归改为 stream entry barrier 后精确发送一次，普通/race 全绿，无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-030-send-while-generating-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-030-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge030-send-while-generating/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2636`，coverage=`848/527/0`，anchors=`10/10`，
  警报 clean。批次五十=`45/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-031`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-029 重复 resolve interaction

- 真实 chat ask interaction 首次 resolve 后，再次 resolve 同一 conversation/toolCallId 返回 `NO_PENDING_INTERACTION`，
  不重放、不二次转移；broker unknown id 也安全。新增 chat service 回归，普通/race 全绿，无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-029-duplicate-resolve-interaction-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-029-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge029-duplicate-resolve-interaction/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2631`，coverage=`848/526/0`，anchors=`10/10`，
  警报 clean。批次五十=`40/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-030`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-028 interaction 枚举外 action

- 枚举外 resolve action（如 `aprove`）在查 conversation/pending 前返回 `INTERACTION_INVALID_ACTION`，details
  带完整 `approve/approve_always/deny/accept/decline` 集合，不静默变成 deny；新增 chat structured-error
  回归，普通/race 全绿，无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-028-invalid-interaction-action-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-028-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge028-invalid-interaction-action/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2626`，coverage=`848/525/0`，anchors=`10/10`，
  警报 clean。批次五十=`35/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-029`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-027 ask_user 无交互用户

- workflow/agent 等无 broker context 中，ask_user 立即返回 `ASK_NO_INTERACTIVE_USER`，不等待、不伪造回答；
  新增 ask tool focused/race 全绿，无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-027-ask-no-interactive-user-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-027-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge027-ask-no-interactive-user/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2621`，coverage=`848/524/0`，anchors=`10/10`，
  警报 clean。批次五十=`30/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-028`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-026 allowed-tools 变更重置信任门

- installed skill 更新时 allowed-tools 集合改变会重置旧授权；只改正文/description 且集合不变则保留授权，
  local drift 非 force 仍拒绝。skill update 普通/race 全绿，无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-026-skill-allowed-tools-reset-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-026-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge026-skill-allowed-tools-reset/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2616`，coverage=`848/523/0`，anchors=`10/10`，
  警报 clean。批次五十=`25/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-027`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-025 skill 信任门未批时预授权为空

- installed skill 的 allowed-tools 在 `:approve-tools` 前只是 requested grant：激活仍注入正文并记 active
  skill，但预授权集为空，未覆盖的危险工具仍逐次过人闸；显式批准后才预授权。skill trust gate 与 loop
  gate 普通/race 全绿，无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-025-skill-trust-gate-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-025-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge025-skill-trust-gate/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2611`，coverage=`848/522/0`，anchors=`10/10`，
  警报 clean。批次五十=`20/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-026`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-024 驻地只闸写不闸读

- 驻地是 zoom、不是 jail：挂载 work directory 后，Read 与 Grep 读取驻地外绝对路径仍直接执行，不弹
  humanloop。workdir gate 回归扩展覆盖两个非写工具，普通/race 全绿，无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-024-read-outside-workdir-no-gate-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-024-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge024-read-outside-workdir-no-gate/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2606`，coverage=`848/521/0`，anchors=`10/10`，
  警报 clean。批次五十=`15/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-025`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-023 越界判定路径解不开

- 首轮发现真实缺口：驻地下 Write args 畸形/缺 `file_path` 时，旧实现因无法判定越界而让 safe 自报静默
  通过，且畸形 JSON 可能让批准 prompt 为空。stop-and-fix 增加不可判定目标状态：先走普通 danger 闸、不
  错标 `outsideWorkDir`；合法 args 保持对象、非法 JSON 以字符串显示；批准后真实 Write validator 返回
  `file_path is required`。新增 focused/race 回归全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-023-undeterminable-workdir-target-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-023-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge023-undeterminable-workdir-target/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2601`，coverage=`848/520/0`，anchors=`10/10`，
  警报 clean。批次五十=`10/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-024`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-022 驻地越界写人闸

- 挂载驻地后，`Write` 自报 safe 但目标在驻地外时强制 humanloop，payload 带 `outsideWorkDir=true`，拒绝
  不执行；approve_always 与 skill allowed-tools 预授权均不可绕过，驻地内 safe write 不额外设闸。现有
  workdir gate 测试族普通/race 全绿，无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-022-outside-workdir-gate-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-022-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge022-outside-workdir-gate/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2596`，coverage=`848/519/0`，anchors=`10/10`，
  警报 clean。批次五十=`5/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-023`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-021 白名单随对话删除清除

- conversation-delete cascade 通过实际 `chat.Service.ForgetConversation` 钩子清掉被删除对话全部
  `approve_always` 授权，同时保留另一存活对话的授权。新增 chat hook 回归，并与 humanloop broker prefix
  清理测试一起通过普通与 `go test -race`，无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-021-forget-conversation-grants-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-021-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge021-forget-clears-grants/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2591`，coverage=`848/518/0`，anchors=`10/10`，
  警报 clean。批次四十九=`50/50`；统一长门禁证据=`testend/rig/formal-evidence/batch-49-unified-gate-20260825.md`，`make verify`、完整
  `make -C backend testend`=`270.240s`、rig 51 tests、脚本/格式/清册/锚点/警报和进程审计全绿；本批随后提交。下一前线=`EDGE-022`。
  P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-020 approve_always 会话白名单

- approve_always 只作用于同一 `(conversation, tool)`；同键第二次直通，换工具/换会话仍 gate，越界事实闸不
  受白名单豁免。新增 loop gate 三路径回归与 race，全绿无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-020-approve-always-scope-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-020-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge020-approve-always-scope/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2586`，coverage=`848/517/0`，anchors=`10/10`，
  警报 clean。批次四十九=`45/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-021`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-019 危险工具人闸阻塞

- dangerous call 在 approval pending 时阻塞且不执行，显式 approve 后才放行；静态 danger floor 不能被模型
  自报 safe 绕过。新增时序回归锁住 surface→未执行→approve→执行，相关 loop/race 全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-019-danger-gate-blocking-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-019-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge019-danger-gate-blocking/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2581`，coverage=`848/516/0`，anchors=`10/10`，
  警报 clean。批次四十九=`40/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-020`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-018 sanitizer 孤儿 tool_call 补 stub

- `SanitizeMessages` 保留已完成 result，为取消/缺失 call 按 assistant 原序补 interrupted stub，丢弃 stray
  tool；新增多调用批次回归并通过 llm/provider 与 `go test -race`，无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-018-sanitizer-orphan-tool-call-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-018-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge018-sanitizer-orphan-tool-call/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2576`，coverage=`848/515/0`，anchors=`10/10`，
  警报 clean。批次四十九=`35/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-019`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-017 DeepSeek 全文本 parts 坍缩

- DeepSeek wire 在无媒体幸存时把全文本 parts 按 `\n\n` 拼成 JSON string content；有媒体仍保留 parts array。
  新增回归解析真实 request body，锁住 string 类型、顺序和精确分隔符；普通测试与 `go test -race` 全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-017-deepseek-text-parts-collapse-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-017-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge017-deepseek-text-parts-collapse/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2571`，coverage=`848/514/0`，anchors=`10/10`，
  警报 clean。批次四十九=`30/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-018`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-016 生成族产地过滤

- MediaRef 不再按 `source=generate_*` 做 producer veto；生成 receipt 与 function/MCP artifact 一样进入
  MediaExpander，并按 producing tool call 分组，字节仍由能力/信封 gate 决定。现有 loop/mediaref 与 race
  回归全绿，无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-016-generation-no-producer-veto-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-016-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge016-generation-no-producer-veto/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2566`，coverage=`848/513/0`，anchors=`10/10`，
  警报 clean。批次四十九=`25/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-017`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-015 MCP 非纯 JSON 结果里的 receipt

- MCP `[image: image/png]` 占位文本加嵌入 JSON receipt 的混合结果不再被整段 JSON gate 丢弃；loop 保留文本，
  `mediaref.Collect` 解析合法 `att_<16hex>` 并按 producing tool call 分组。新增混合形状回归，普通
  loop/mediaref 测试与 `go test -race` 全绿，无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-015-mcp-embedded-receipt-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-015-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge015-mcp-embedded-receipt/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2561`，coverage=`848/512/0`，anchors=`10/10`，
  警报 clean。批次四十九=`20/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-016`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-014 MediaExpander 当轮回喂

- MediaRef 按 producing tool call 分组，只在下一次 provider request 追加原生 content part；生成图与
  function/MCP artifact 共用消费咽喉，无 expander/模态不支持时保留 receipt。临时 user 消息不进 finalized blocks。
  新增回归锁住首次/后续 request、产地归属、无媒体不展开和持久隔离，普通测试与 `go test -race` 全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-014-media-expander-same-turn-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-014-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge014-media-expander-same-turn/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2556`，coverage=`848/511/0`，anchors=`10/10`，
  警报 clean。批次四十九=`15/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-015`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-013 ObjectMap 字符串化对象参数

- `run_function.args` 通过公共 `tool.ObjectMap` 接受原生 object 与 JSON 字符串承载的同一 object；数组、数字、
  普通非 JSON 字符串和字符串化数组拒绝。新增公共边界回归，普通测试与 `go test -race` 全绿，无 stop-and-fix。
- 正式证据=`testend/rig/formal-evidence/EDGE-013-objectmap-stringified-object-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-013-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge013-objectmap-stringified-object/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2551`，coverage=`848/510/0`，anchors=`10/10`，
  警报 clean。批次四十九=`10/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-014`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-012 danger 非枚举值 fail-open

- 标准字段剥离器对未知/缺失 `danger` 回落 `safe`；工具的静态危险 floor 仍不可绕过，会把真实不可逆
  操作抬回 `dangerous`。现有实现正确，无 stop-and-fix；focused tool/loop 和 race suite 全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-012-invalid-danger-fail-open-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-012-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge012-danger-fail-open/na/na/na/na`，
  不伪造真实 App 五通道/视觉/导航证据。formal journal=`2546`，coverage=`848/509/0`，anchors=`10/10`，
  警报 clean。批次四十九=`5/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-013`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-011 execution_group 并发与下标拍平

- 现有 loop 已按输入下标收集同组并发结果；新增屏障测试强制两个工具同时启动，再断言拍平顺序仍为
  输入序；普通 focused test 与 `go test -race` 均通过。实现没有发现需修复的产品缺陷，测试锁住并发
  退化风险。
- 正式证据=`testend/rig/formal-evidence/EDGE-011-execution-group-parallel-order-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-011-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge011-parallel-index-order/na/na/na/na`，
  不伪造真实 App 五通道/视觉时延/可发现性证据。formal journal=`2541`，coverage=`848/508/0`，anchors=`10/10`，
  警报 clean。批次四十八=`51/50`，统一长门禁已解锁；P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-010 tool_result 256 KiB 最终硬封顶

- 静态复核发现旧实现把截断提示追加到 256 KiB 原文之后，失败分支拼接错误文本后也可能超限；已停止并
  修复为最终结果总长度封顶。成功结果保留头部并在 UTF-8 字符边界截断，失败结果保留输出头部、错误尾部
  和收窄提示，三者共同计入 `ToolResultCapKB`。
- `go test ./internal/app/loop -count=1`、前端 `chat_tool_card_test.dart` 全测、`make analyze` 全绿；
  回归明确验证成功/失败长度、错误保留、UTF-8 和收窄提示。reference 已同步。
- 正式证据=`testend/rig/formal-evidence/EDGE-010-tool-result-cap-investigation-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-010-ledger-alarm-reaudit-20260825.md`。五级=`measure:edge010-tool-result-cap/na/na/E1/na`，
  不伪造真实超大 Grep/MCP 五通道 session。formal journal=`2536`，coverage=`848/507/0`，anchors=`10/10`，
  警报 clean。批次四十八=`46/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-011`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-009 Chat 回合总墙钟语义止损修复

- ChatTurnSec 到期原先被共享 loop 当成普通 `cancelled`，用户无法区分系统保护性截断和主动取消；已改为
  chat-owned `DeadlineExceeded` → `error/CHAT_TURN_TIMEOUT`，explicit Cancel 与其它宿主保持 cancelled。
- 终态给出发送后续消息或简化任务的可行动提示；前端映射本地化文案并隐藏内部 code/detail。错误码、loop/chat
  契约同步，chat/loop/agent/subagent/reqctx focused suites、transcript widget 与 analyzer 全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-009-chat-turn-wall-clock-stop-fix-20260825.md`；警报复审=
  `testend/rig/formal-evidence/EDGE-009-ledger-alarm-reaudit-20260825.md`。五级=`E1/na/na/E1/na`，不冒充
  真实 stall 五通道流；formal journal=`2531`，coverage=`848/506/0`，anchors=`10/10`，警报 clean。批次
  四十八=`41/50`，不提前跑统一长门禁、不提交；下一前线=`EDGE-010`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-008 MaxSteps 终态错误用户体验止损修复

- 产品复核发现 `MAX_STEPS_REACHED` 原先会在“达到步骤上限”后继续显示 durable code 和内部 detail；已
  改为中英文可行动文案，告诉用户发送后续消息或简化任务继续，并将该 code 纳入 transcript 的屏蔽映射。
- focused widget regression 覆盖 `MAX_STEPS_REACHED`、`TOOL_ERROR_STORM`、`CONTEXT_INPUT_TOO_LARGE`，
  断言文案存在且 raw code/detail 不出现；frontend analyzer 与 Go MaxSteps/tool-storm focused suite 全绿。
- 正式证据=`testend/rig/formal-evidence/EDGE-008-max-steps-ux-stop-fix-20260825.md`，警报复审=
  `testend/rig/formal-evidence/EDGE-008-ledger-alarm-reaudit-20260825.md`。五级=`E1/na/na/E1/na`，不冒充
  真实 MaxSteps 五通道流；formal journal=`2526`，coverage=`848/505/0`，anchors=`10/10`，警报 clean。
  批次四十八=`36/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-009`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-007 loop 终态错误用户体验止损修复

- 产品复核发现 `TOOL_ERROR_STORM` 与 `CONTEXT_INPUT_TOO_LARGE` 会把 durable error code 和内部 detail
  直接显示在 Chat transcript 主文案中，违反 CODEX E1。已停止推进并修复为中英文本地化、可行动提示：
  工具连续失败时建议检查输入并重试，内容过大时建议拆分最新附件或内容后重试。
- 新增 focused widget regression，断言两种用户文案出现且原始 code/detail 不出现；`make -C frontend analyze`
  与 loop regressions 全绿。正式证据=`testend/rig/formal-evidence/EDGE-007-loop-terminal-error-ux-stop-fix-20260825.md`。
- EDGE-005 的历史 L4 `na` 已用 `judge.py --revalidate --law E1` 重验为 pass。EDGE-007 五级=`E1/na/na/E1/na`，
  不冒充真实 storm 五通道 session；L2/L3/L5 的 na 理由、L4 产品表面证据均落盘。formal journal=`2521`，
  coverage=`848/504/0`，anchors=`10/10`，统计警报复审 ack 后 clean。批次四十八=`31/50`，未满 50 格不跑
  统一长门禁、不提交；下一前线=`EDGE-008`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-006 DeepSeek active tool chain 正式入账

- deterministic checkpoint 在 DeepSeek-like 活跃组上只在完整 assistant/tool group 之前切分；
  `reasoning_content`、`reasoningSignature`、tool call 与配对 result 全保留。新增协议回归及 DeepSeek
  provider build/request/parse/round-trip focused tests 全部通过。
- 调查=`testend/rig/formal-evidence/EDGE-006-deepseek-tool-chain-investigation-20260825.md`；账本复审=
  `testend/rig/formal-evidence/EDGE-006-ledger-alarm-reaudit-20260825.md`。这是 prompt-only compatibility
  invariant，无 UI/DB/SSE/真实网关表面，五级=`measure:deepseek-active-tool-group/na/na/na/na`。
- formal journal=`2516`（2300 baseline + 216 live），coverage=`848/503/0`，anchors=`10/10`；统计警报
  复审 ack 后 clean。批次四十八=`26/50`，不提前跑统一长门禁、不提交；下一前线=`EDGE-007`。P12 400+
  Journey 继续推迟二期。

## 2026-08-25 · EDGE-005 CONTEXT_INPUT_TOO_LARGE 终态正式入账

- 新回归构造“首次 `context_length` 拒绝、checkpoint 成功、同一步 retry 再拒绝、第二个有界恢复
  周期结束”的边界；实际四次 provider/checkpoint 调用，最终 result/finalize 均为 error，精确码为
  `CONTEXT_INPUT_TOO_LARGE`，并含不可拆输入与 split 指引。
- loop 与 LLM provider focused regression 通过；没有伪装成功、裸 `LLM_STREAM_ERROR` 或无界重试。
- 调查=`testend/rig/formal-evidence/EDGE-005-context-too-large-investigation-20260825.md`；账本复审=
  `testend/rig/formal-evidence/EDGE-005-ledger-alarm-reaudit-20260825.md`。真实 provider-error 视觉面由
  EDGE-001 覆盖，重复 rejection 是 harness 注入，五级=`E1/na/na/na/na`。
- EDGE-007 后该格的历史 L4 `na` 已按 `--revalidate --law E1` 重验为 pass，当前五级=`E1/na/na/E1/na`；
  formal journal=`2516`（2300 baseline + 216 live），coverage=`848/503/0`，anchors=`10/10`；三条统计警报
  复审 ack 后 clean。批次四十八首次入账仍=`21/50`，重验不重复计数；下一前线=`EDGE-006`。P12 400+ Journey
  继续推迟二期。

## 2026-08-25 · EDGE-004 authoritative context_length recovery 正式入账

- 生产 loop 已有精确回归：provider 在零 assistant block 时返回结构化 `context_length`，loop 做隔离
  semantic checkpoint、缩小 prompt、透明重试同一个逻辑步并完成，不泄漏中间错误；checkpoint 请求不带
  tools，调用次数严格受控。
- `TestRun_ProviderContextOverflowCompactsAndRetriesSameStep`、`TestChat_CompactionWatermark`、
  `TestPromptR6_PostCompactionView` 与 loop/contextcheckpoint/contextmgr 定向测试通过；HTTP/SSE 黑盒补证
  learned budget、durable summary/watermark、压缩后模型视图和完整最近协议组。
- 调查=`testend/rig/formal-evidence/EDGE-004-context-overflow-recovery-investigation-20260825.md`；
  账本复审=`testend/rig/formal-evidence/EDGE-004-ledger-alarm-reaudit-20260825.md`。强制 rejection 是
  harness 注入，真实 managed 504 不冒充本格，五级=`H3/na/na/na/na`。
- formal journal=`2505`（2300 baseline + 205 live），coverage=`848/501/0`，anchors=`10/10`；统计警报
  复审 ack 后 clean。批次四十八=`16/50`，不提前跑统一长门禁、不提交；下一前线=`EDGE-005`。P12 400+
  Journey 继续推迟二期。

## 2026-08-25 · EDGE-003 semantic compaction 双失败正式入账

- 这是 loop 内部故障注入，不是可由真实网关稳定制造的用户旅程。Host utility compactor 被强制失败，
  primary checkpoint 请求随后以不可重试 `invalid_request` 失败；同一逻辑步第三次采样成功。
- `TestRun_ContextOverflowFallsBackToDeterministicCheckpointWhenSemanticCompactorsFail` 通过：utility
  恰调用一次、无无界重试、最终 completed、没有中间错误泄漏；retry prompt 含明确的
  `deterministic-emergency` 与 re-fetch 警告，最近完整 tool group 保持配对。
- 正式调查=`testend/rig/formal-evidence/EDGE-003-deterministic-checkpoint-investigation-20260825.md`；
  账本复审=`testend/rig/formal-evidence/EDGE-003-ledger-alarm-reaudit-20260825.md`。该 prompt-only 投影
  不产生 UI/DB/SSE/真实网关表面，故五级=`H3/na/na/na/na`，不借用 EDGE-002 session 冒充五通道事实。
- formal journal=`2500`（2300 baseline + 200 live），coverage=`848/500/0`，anchors=`10/10`；两条统计
  警报复审 ack 后 clean。批次四十八=`11/50`，不提前跑统一长门禁、不提交；下一前线=`EDGE-004`。
  P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-002 continuation checkpoint 正式五级入账

- 真实 App 通过实体选择器选中临时 `edge002_checkpoint_chunk`，同一对话连续四次真实 Function
  调用，独立三路 SSE 记录四组完整 `run_function → tool_result`，App 活动显示 `执行 ×4`，无孤儿
  tool_call；第五次大请求 body=`1,116,940` bytes，受管网关在 semantic checkpoint 前返回
  `error code: 504`，该边界保留为红证据，不冒充压缩绿证据。
- 真正用户面显示修复后的可行动双语错误文案，不显示 `LLM_PROVIDER_ERROR` 或 `provider error (504)`。
  frontend 的重复 `accessibility_bridge` AXTree 行按既有 Computer Use snapshot churn 事实保留，未
  静默过滤；rig-down 无残留进程，临时 Function 已 DELETE=204。
- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-115619`；正式证据=`sessions/20260825-115619/evidence/EDGE-002-five-channel.md`；账本复审=`testend/rig/formal-evidence/EDGE-002-ledger-reaudit-20260825.md`。
  `TestChat_CompactionWatermark`、`TestChatFork_SummaryTwoBranches` 及 loop/contextmgr/contextcheckpoint 定向测试通过，证明 80%→55% structured checkpoint、最近完整工具组保留、协议配对和 durable watermark。
- 五级=`G1/F2/A5/C4/G2`；formal journal=`2495`（2300 baseline + 195 live），coverage=`848/499/0`，
  anchors=`10/10`，两条统计警报按复审记录 ack 后 `alarms.py check` clean。批次四十八=`6/50`，不提前
  跑统一长门禁、不提交；下一正式前线=`EDGE-003`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · EDGE-001 上下文 marker 正式五级入账

- 真实 App + 受管网关 + 五通道 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-113116`。
  连续大 tool_result 触发两次 context edit，backend 记录清除 `528723` 与 `524292` bytes；LLM tap 的
  四个真实请求 body 含 `7/7/9/9` 个 prompt-only marker；durable REST 历史保留完整输出且 marker=0。
- 真实 504 画面先冻结为红并停止计绿；前端把 `LLM_PROVIDER_ERROR` 主文案改为双语可操作提示，focused
  transcript regression=`32/32`。原始 504 帧继续作为红边界，不冒充修复后真实绿帧。
- 正式证据=`sessions/20260825-113116/evidence/EDGE-001-five-channel.md`；账本复审=
  `testend/rig/formal-evidence/EDGE-001-ledger-alarm-reaudit-20260825.md`；五级=`G1/F2/A5/C4/G2`，
  `alarms.py check` 在独立复审后 clean。COVERAGE 从 497→498 carried judgments，批次四十八=`1/50`；
  未到 50 格不跑统一长门禁、不提交，sequence gate 下一前线=`EDGE-002`。

## 2026-08-25 · SURF-114 stage/generic 通用舞台与 poll 终态正式五级入账

- `_GenericStage` 是共同 host，不是额外工具族：共享诚实丝带、kind 量身体、live/settling/failed 与 settled 摘要；无 stage route 的 `search_tools`、conversation、attachment 保持诚实缺席。`trigger_workflow` 的 202 只代表入队，必须等匹配 `flowrunId` 的 durable `run_terminal`。
- 真实 App 通过实体提及选择 disposable `surf114_poll`，只调用一次 `trigger_workflow`，flowrun=`fr_b71eebde4adf9919`，8.12 秒后 completed；通用 workflow 图从运行卷收为 settled touchpoint 摘要。两次直接输入带下划线 ID 的失败是 Computer Use 输入桥负边界，保留但不计绿；提及路径精确成功。fixture 已在收台前删除。
- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-105440`，screen=`699.328333s / 2784x1808 / 60fps`；结果帧=`sessions/20260825-105440/evidence/frames/surf114-generic-settled.png`。messages durable=`66..74`，entities=`run_started → run tick → run_terminal`，flowrun id 一致；backend/frontend 无应用红线，LLM 正向 wire 全`200`，rig-check/rig-down 通过且无残留。正式调查=`testend/rig/formal-evidence/SURF-114-stage-generic-investigation-20260825.md`，L2=`sessions/20260825-105440/evidence/SURF-114-stage-generic-five-channel.md`。
- 新增真实时序 focused test：`tool_result open → run_terminal → tool_result close`，通过。五级=`E2/F2/B2/C4/G1`；formal journal=`2485`（2300 baseline + 185 live），coverage=`848/497/0`，anchors=`10/10`。两条统计警报按 `SURF-114-ledger-alarm-reaudit-20260825.md` 独立复审并串行 ack，最终 `alarms.py check` clean；批次四十七=`50/50` 后统一长门禁已通过并提交 `467e12e7`：根 `make verify`、完整 `make -C backend testend`=`312.506s`、rig=`50/50`、格式/覆盖/锚点/警报/进程审计全绿，记录=`testend/rig/formal-evidence/batch-47-gate-20260825.md`。sequence gate 下一原子前线=`EDGE-001 上下文水位 80% 触发 tool_result 换 marker`，批次四十八=`0/50`。P12 400+ Journey 继续推迟二期。

## 2026-08-25 · SURF-113 stage/mcp 接线现场与类型化工具货架正式五级入账

- 静态反查确认 MCP 舞台只投影 install/reconnect/create 的 typed `tools[].name`，环境键遮罩、货架最多 12 项并显示总数；install 是危险动作必须经过一次性人闸，reconnect 是安全动作，不能把任意执行参数冒充发现结果。
- 真实 App 搜索并安装 marketplace `microsoftdocs/mcp`，一次性允许后只调用一次 install；舞台显示已连接、3 工具与 `microsoft_docs_search`、`microsoft_code_sample_search`、`microsoft_docs_fetch` 三个 chip。随后只调用一次 reconnect，正确解释已安装实例名 `mcp` 与 marketplace 名称的差异，无重复安装/卸载/retry。
- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-104412`，screen=`202.041667s / 2784x1808 / 60fps`，抽帧=`sessions/20260825-104412/evidence/frames/surf113-mcp-125.png`、`surf113-mcp-175.png`；messages=`1..44`、notifications=`16..19` 连续唯一，entities `disconnected→connecting→ready` 两次，backend/frontend/LLM 五通道无未解释红线，managed wire 全`200`，rig-down 无残留。调查=`testend/rig/formal-evidence/SURF-113-stage-mcp-investigation-20260825.md`，L2=`sessions/20260825-104412/evidence/SURF-113-stage-mcp-five-channel.md`。
- focused Flutter=`30` 项、Go MCP app/tool/infra 全绿。五级=`E2/F2/B2/C4/G1`；formal journal=`2480`（2300 baseline + 180 live），coverage=`848/496/0`，anchors=`10/10`。两条统计警报按 `SURF-113-ledger-alarm-reaudit-20260825.md` 独立复审并串行 ack，未改阈值/算法/CODEX/锚点/gate，最终 `alarms.py check` clean；批次四十七由 `40→45/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`SURF-114 stage/generic`。P12 400+ Journey 继续按用户裁定推迟二期。

## 2026-08-25 · SURF-112 stage/memory 记忆笺与用户图钉边界正式五级入账

- 静态反查确认 Memory 舞台只读 slug、摘要和正文，落定显示结果条；pin/unpin 不在舞台出现，只走用户 REST。`write_memory` 不暴露 pinned/source，更新已有记忆必须保留用户既有 pin 与作者归属。
- 真实 App 通过受管网关一次 `read_memory` 读取 `handoff-note`，舞台显示 slug、来源和完整正文；随后一次 `search_tools` 激活并一次 `write_memory` 更新用户置顶的 `release-rule`，无 retry/重复 mutation。REST 证明 description 不变、`pinned=true`、`source=user`，正文为新值；REST pin/unpin `handoff-note` 均 200，SSE 仅 frame-only `memory.updated`。
- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-103249`，screen=`257.440000s / 2696x1720 / 60fps`，抽帧=`sessions/20260825-103249/evidence/frames/surf112-memory-read.png`、`surf112-memory-write-170.png`；messages=`1..36`、notifications=`16..22` 连续唯一，backend/frontend/LLM 五通道无未解释红线，managed wire 全`200`，rig-down 无残留。调查=`testend/rig/formal-evidence/SURF-112-stage-memory-investigation-20260825.md`，L2=`sessions/20260825-103249/evidence/SURF-112-stage-memory-five-channel.md`。
- 五级=`E2/F2/B2/C4/G1`；formal journal=`2475`（2300 baseline + 175 live），coverage=`848/495/0`，anchors=`10/10`。两条统计警报按 `SURF-112-ledger-alarm-reaudit-20260825.md` 独立复审并串行 ack，未改阈值/算法/CODEX/锚点/gate，`alarms.py check` clean；批次四十七由 `35→40/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`SURF-113 stage/MCP`。P12 400+ Journey 继续按用户裁定推迟二期。

## 2026-08-25 · SURF-111 stage/skill 正文、占位符与安装信任门正式五级入账

- 静态反查确认 Skill 舞台为 metadata header + 真 Markdown prose；installed skill 的 `allowedTools` 在 `toolsApproved=false` 时只能显示中性“信任门未批,确认仍逐次”，批准后才显示琥珀预授权；`activate_skill` 的四类占位符和目录锚点语义已锁定。
- 真实 App 创建 `surf111runbook` 后保留输入桥丢 `$`/下划线的负事实；精确 body 经 REST 真相面落盘，再由 App `get_skill` 读取并由 App `activate_skill` 以 `daily/review` 验证 `$1`、`$ARGUMENTS`、真实目录和 session 展开。另用本地 tarball 安装 `surf111-installed`，App 真实观察未批与批准后的两种 stage。
- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-101708`，screen=`531.340000s / 2784x1808`，帧=`sessions/20260825-101708/evidence/frames/surf111-400s.png`；messages=`1..75`、notifications=`16..28` 连续唯一，backend 无应用红线，frontend 仅已知 IMK 平台噪声，LLM 观测响应全`200`，rig-down 无残留。调查=`testend/rig/formal-evidence/SURF-111-stage-skill-investigation-20260825.md`，L2=`sessions/20260825-101708/evidence/SURF-111-stage-skill-five-channel.md`。
- 五级=`E2/F2/B2/C4/G1`；formal journal=`2470`（2300 baseline + 170 live），coverage=`848/494/0`，anchors=`10/10`。两条统计警报按 `SURF-111-ledger-alarm-reaudit-20260825.md` 独立复审并串行 ack，阈值/算法/CODEX/锚点/gate 未改，`alarms.py check` clean；批次四十七由 `30→35/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`SURF-112 stage/memory`。P12 400+ Journey 继续按用户裁定推迟二期。

## 2026-08-25 · SURF-110 stage/agent 四槽创建与局部编辑正式五级入账

- 静态反查确认 Agent 舞台同时消费 `prompt`、`tools`、`knowledge`、`modelOverride`；live 阶段未触槽保留旧真相，settled 阶段四槽回全墨，prompt 为有界视口；`create_agent` 与 `edit_agent` 的真实参数形状已冻结。
- 真实 App 保留 knowledge 字符串化、缺 `apiKeyId` 两个失败路径和一次取消收尾 WARN；修正后只创建 `surf110-planner` v1，挂载 greet function、上手指南文档和 `anselm-auto`，随后只改 prompt 成 v2，其他字段保持不变。
- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-100206`，screen=`572.313333s / 2784x1808`，截图=`sessions/20260825-100206/evidence/SURF-110-stage-agent-settled.png`；REST/UI/SSE/LLM 一致，messages=`1..77`、entities=`7..10`、notifications=`16..19` 连续唯一，LLM 观测响应全`200`，backend/frontend 无未解释运行时红线，rig-down 无残留。调查=`testend/rig/formal-evidence/SURF-110-stage-agent-investigation-20260825.md`，L2=`sessions/20260825-100206/evidence/SURF-110-stage-agent-five-channel.md`。
- 五级=`E2/F2/B2/C4/G1`；formal journal=`2465`（2300 baseline + 165 live），coverage=`848/493/0`，anchors=`10/10`。两条统计警报按 `SURF-110-ledger-alarm-reaudit-20260825.md` 独立复审并串行 ack，阈值/算法/CODEX/锚点/gate 未改，`alarms.py check` clean；批次四十七由 `25→30/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`SURF-111 stage/skill`。P12 400+ Journey 继续按用户裁定推迟二期。

## 2026-08-25 · SURF-109 stage/handler 生命周期与 RFC-7396 编辑正式五级入账

- 静态反查确认 Handler 舞台真实契约：`set_init_args_schema(args)`、`set_init(initBody)`、`add_method(method)`、`update_method(name + patch)`、`set_shutdown(shutdownBody)`；timeout 由毫秒落盘、以秒钟词展示，sensitive init arg 掩码。focused Flutter=`12/12`，Go handler/tool 定向测试通过。
- 真实 App 先保留模型错误 `set_method`、非法名称和 nested `method` 编辑形状的失败卡；后端与 SSE error close 诚实可见。模型自纠后创建 `surf109_notifier` v1，再用正确 RFC-7396 patch 编辑为 v2：`send` 从 `30s/sent` 变为 `45s/updated`，输入输出、init/shutdown 和 `apikey ••••`/`region` 保持不变。重新查看实体后右侧舞台展示 v2，v1 仍作为历史。
- 五通道 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-095228`，screen=`334.810000s / 2784x1808 / 60fps`，截图=`sessions/20260825-095228/evidence/SURF-109-stage-handler-settled.png`；REST/SSE/entities/LLM/UI 均给出 v2、`timeout=45000`、`status:'updated'`、env ready/runtime running；backend 仅三条刻意失败 WARN，frontend 仅 IMK 平台噪声，managed completion 全`200`；rig-down 无残留。调查=`testend/rig/formal-evidence/SURF-109-stage-handler-investigation-20260825.md`，L2=`sessions/20260825-095228/evidence/SURF-109-stage-handler-five-channel.md`。
- 五级=`E2/F2/B2/C4/G1`；formal journal=`2460`（2300 baseline + 160 live），coverage=`848/492/0`，anchors=`10/10`。两条统计警报按 `SURF-109-ledger-alarm-reaudit-20260825.md` 独立复审并串行 ack，阈值/算法/CODEX/锚点/gate 未改，`alarms.py check` clean；批次四十七由 `20→25/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`SURF-110 stage/agent`。P12 的 400+ Journey 仍推迟二期。

## 2026-08-25 · SURF-108 stage/subagent 一席一卡与真实终端活窗正式五级入账

- 静态反查确认 `SubagentStageBody` 只消费本行 `StageScene`；`subagentTaskLabel` 从真实 `{subagent_type,prompt}` schema 取 `prompt` 首行；execution phase 才判 live，ReAct 尾和 progress 终端分别封顶 6/10 行，settle 元数据支持 nested close 与 lifted fields 双源。既有 focused Flutter 与 Go subagent/tool tests 通过。
- 真实 App 先保留输入桥丢 `_` 导致的 Explore 负路径：只读白名单拒绝 Bash；随后用精确输入跑 `general-purpose`，真实 Bash 输出三行 `SURF108 terminal probe 1/2/3`、退出码 0；第三次短请求输出 `SURF108 LIVE 1/2/3`。AX live 显示 `正在派子代理… general-purpose` 与 `实时聆听中 · 落定以真相为准`，settling 显示 `正在落定`，settled 侧幕展开为单卡并显示 Bash、输出、退出码。负路径不计绿但留存。
- 五通道 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-093437`，screen=`842.563333s / 2784x1808`，截图=`sessions/20260825-093437/evidence/SURF-108-stage-subagent-settled.png`；SSE 含 `Subagent`、`subagent:true`、Bash、progress、tool_result 和有序终端输出；LLM 经真实 `https://api.anselm.website` 且 completion 全`200`；backend 无 panic/fatal，只有故意失败路径的两条 Grep fallback WARN；frontend 仅已知 IMK 噪声；rig-down 封口无残留。调查=`testend/rig/formal-evidence/SURF-108-stage-subagent-investigation-20260825.md`，L2=`sessions/20260825-093437/evidence/SURF-108-stage-subagent-five-channel.md`。
- 五级=`E2/F2/B2/C4/G1`；formal journal=`2455`（2300 baseline + 155 live），coverage=`848/491/0`，anchors=`10/10`。两条统计警报按 `SURF-108-ledger-alarm-reaudit-20260825.md` 独立复审并串行 ack，阈值/算法/CODEX/锚点/gate 未改，`alarms.py check` clean；批次四十七由 `15→20/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`SURF-109`。P12 的 400+ Journey 仍推迟二期。

## 2026-08-25 · SURF-107 stage/trigger 四脸与 nextFireAt 真相正式五级入账

- 首轮真实读取 `SURF107-cron` 暴露产品红：通用 ISO 脱敏器把明确的 `nextFireAt` 替成“相应时间”，造成 REST/LLM wire 与最终 App 答案不一致；停止计绿。修复 `backend/internal/app/loop/redact.go` 的字段级窄保护，覆盖 direct field、翻译 table row 和 streaming chunk，普通 `createdAt`/`updatedAt` 仍脱敏；后端 `Test(Redact|TextRedactor)` 与 trigger focused=`21/21` 通过。
- 修复后 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-092425`，真实 App + managed gateway + Computer Use 只读重跑；App/AX、REST、SSE close、LLM wire 均显示 `2026-08-26 09:00:00 (UTC+8)`，`listening=true`、`paused=false`、`refCount=1`，而 `最后更新`继续显示“相应时间”。四脸 setup 取自前置 session=`20260825-090642`，不把旧画面冒充修复后画面；嵌套 sensor target、畸形 ID 和输入桥残缺请求保留为负向事实。
- 五通道：screen=`336.175000s / 2784x1808`，固定截图=`sessions/20260825-092425/evidence/SURF-107-fixed-next-fire.png`；backend 无应用红线；SSE 三流连接，messages=`1..21`、notifications=`1..2` 单调唯一、entities 无本路径业务 durable 帧；LLM managed wiring/chat 全`200`；frontend 仅已知 IMK 平台噪声，无 Flutter/Dart/布局/Unhandled 红线；rig-down 无残留。调查=`testend/rig/formal-evidence/SURF-107-stage-trigger-investigation-20260825.md`，L2=`sessions/20260825-092425/evidence/SURF-107-stage-trigger-five-channel.md`。
- 五级=`E2/F2/B2/C4/G1`；formal journal=`2450`（2300 baseline + 150 live），coverage=`848/490/0`，anchors=`10/10`。两条统计警报按 `SURF-107-ledger-alarm-reaudit-20260825.md` 独立复审并串行 ack，阈值/算法/CODEX/锚点/gate 未改，`alarms.py check` clean；批次四十七由 `10→15/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`SURF-108 stage/subagent`。P12 的 400+ Journey 仍推迟二期。

## 2026-08-25 · SURF-106 stage/approval 审批预览正式五级入账

- 静态反查发现 hosted gateway 的 `allowReason`/`timeout` 可能是字符串 scalar，timeout 为秒数；原 stage 只认 native 值。stop-and-fix 让 live stage 与 settled preview 共用 scalar seam，整秒转 `m/h/d/w`，并锁定 `"true"`、`"7200"`、`2h`、备注 chip 与零值 `0s`；focused Flutter=`22/22`。
- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-085143`。AX 输入桥污染的首轮与旧对话 edit 路径排除；干净对话真实只调用一次 `create_approval`，创建 `SURF106-approval-clean` v1。Computer Use 展开 Activity 逐帧确认模板、amount/vendor 琥珀插值、`2h`、`2h 后自动拒绝`、`可填备注` 与批准/拒绝动作，未见 clipping/overlap/reflow/非用户跳变；REST active v1 对账一致。
- 五通道 screen=`362.563333s`；backend 仅观测器缺 workspace 探针的 401，无应用红线；SSE durable=`messages 1..53 / notifications 1..7 / entities 1..2`，均唯一单调；LLM managed proof/install/models 与 9 次 completion 全 `200`，frontend 仅已知 IMK 噪声；rig-check/rig-down 通过且无残留。调查=`testend/rig/formal-evidence/SURF-106-stage-approval-investigation-20260825.md`，L2=`sessions/20260825-085143/evidence/SURF-106-stage-approval-five-channel.md`。
- 五级=`E2/F2/B2/C4/G1`；formal journal=`2445`（2300 baseline + 145 live），coverage=`848/489/0`，anchors=`10/10`。两条统计警报按 `SURF-106-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，阈值/算法/CODEX/锚点/gate 未改，`alarms.py check` clean；批次四十七=`10/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`SURF-107 stage/trigger`。P12 的 400+ Journey 仍推迟二期。

## 2026-08-25 · SURF-105 stage/control 决策梯正式五级入账，批次四十七 5/50

- 静态反查发现 control stage 只读原生 `branches` 数组，无法消费真实托管模型产生的闭合 JSON 字符串数组；stop-and-fix 增加窄兼容 `controlBranchItems`，原生数组优先，合法闭合字符串才解码，部分/畸形流保持空集并按 session 缓存。新增回归后 focused Flutter=`20/20`。
- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-083508` 的真实 App 先遇到 AX 输入层残缺请求，模型澄清、后端在 mutation 前拒绝坏 inputs；随后唯一 `SURF105` v1 创建成功。Computer Use 展开成功 stage，逐帧确认 hot/normal/otherwise 三段顺序、连续高度、独立“否则”徽记和明确“透传”幽灵；REST active v1 与 UI/正文一致。观察器输入负路径保留，不计产品红绿。
- 五通道录屏总时长=`540.676667s`；backend 仅故意 validation WARN；SSE messages=`1..33`、notifications=`1..3`、entities=`1..2` 各自单调；LLM managed proof/install/models 与业务 completion 全 `200`；frontend 无 Flutter/Dart/布局/Unhandled 红线，仅已知 IMK 噪声；rebind 后 `rig-check`/`rig-down` 通过且无残留。调查=`testend/rig/formal-evidence/SURF-105-stage-control-investigation-20260825.md`，L2=`sessions/20260825-083508/evidence/SURF-105-stage-control-five-channel.md`。
- 五级=`E2/F2/B2/C4/G1`；formal journal=`2440`（2300 baseline + 140 live），coverage=`848/488/0`，anchors=`10/10`。两条统计警报按 `testend/rig/formal-evidence/SURF-105-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，`alarms.py check` clean；批次四十七当时=`5/50`，下一前线已由上方 SURF-106 整体重述接管。P12 的 400+ Journey 仍推迟二期。

## 2026-08-25 · SURF-104 stage/workflow 工作流图生长正式五级入账，批次四十六 50/50

- 首轮真实 provider 的字符串化 `ops` 被前端误判为 metadata-only，后端真相却已写入 `+1 节点/+1 边`；红证据保留，不计绿。修复后 `workflowOpsFromArgs` 统一兼容原生数组与闭合合法 JSON 数组字符串，focused Flutter=`41/41`。
- 绿色 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-080352` 的真实 App 活动卡显示 `+1 节点 · +1 边`；Computer Use 打开活动侧幕并展开 `surf104_graph`，真实画布显示 `节点 2 · 边 1` 与 `start/触发 → run/动作`。后端 v2、触点、摘要、画布一致，无重复 mutation。
- 五通道 screen=`243.491667s`；backend 无应用红线；SSE 三流连接，messages=`1..15`、notifications=`16..19` 单调无 gap，entities 已连接；LLM proof/install/models 与 4 次 chat completion 全 `200`；frontend 无 Flutter/Dart/布局/Unhandled 红线，仅已知 IMK 平台噪声；rig-check/rig-down 通过且无残留。调查=`testend/rig/formal-evidence/SURF-104-stage-workflow-investigation-20260825.md`，L2=`sessions/20260825-080352/evidence/SURF-104-stage-workflow-five-channel.md`。
- 五级=`E2/F2/B2/C4/G1`；formal journal=`2435`（2300 baseline + 135 live），coverage=`848/487/0`，anchors=`10/10`。两条统计警报按 `testend/rig/formal-evidence/SURF-104-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，`alarms.py check` clean；批次四十六=`50/50` 已通过统一长门禁并提交 `4baec1b7`，记录=`testend/rig/formal-evidence/batch-46-gate-20260825.md`；下一正式前线=`SURF-105 stage/control`，批次四十七=`0/50`。P12 的 400+ Journey 仍推迟二期。

## 2026-08-25 · SURF-103 stage/document 文档编辑舞台正式五级入账，批次四十六 45/50

静态反查确认文档舞台冻结 baseline，公共前缀增量快进、书脊、metadata-only 防假幕、失败残稿、UTF-8 全量替换徽和 `[[id]]` mention seam 均有实现；focused Flutter=`26/26`。

真实 App 的矛盾 probe 产生过可见 `编辑 ×2`（未知正文却禁止读取的故意约束），最终正文正确但不计绿；干净正向 probe 给出完整目标正文，真实 App 单次 `edit_document` 成功，文档名、正文和右侧舞台一致，无重复卡片/跳变/溢出。调查=`testend/rig/formal-evidence/SURF-103-stage-document-investigation-20260825.md`，L2=`sessions/20260825-075245/evidence/SURF-103-stage-document-five-channel.md`。

五通道 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-075245`：screen=`119.876667s`、backend=`249`、frontend=`4`、SSE=`420`、LLM=`28`；durable=`messages 1..48 / notifications 16..22 / entities 7..8` 单调无 gap，LLM 全 `200`，frontend 仅已知 IMK 平台噪声，rig-check/rig-down 通过且无残留。

五级=`E2/F2/B2/C4/G1`；formal journal=`2430`（2300 baseline + 130 live），coverage=`848/486/0`，anchors=`10/10`。两条统计警报按 `testend/rig/formal-evidence/SURF-103-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，`alarms.py check` clean；下一正式前线=`SURF-104 stage/workflow`，当前批次=`45/50`，未到 50 格不跑统一长门禁、不提交。P12 的 400+ Journey 仍推迟二期。

## 2026-08-25 · SURF-102 stage/function 函数编辑舞台正式五级入账，批次四十六 40/50

静态反查确认编辑舞台冻结编辑前真相，live 依次呈现旧地层、中性 OpTicker、同壳活代码窗，settle 计算真实 before/after `+n/−m`；失败态不染成功色。focused Flutter 阶段套件=`40/40`，覆盖窄帧地层、OpTicker、live editor、同壳 settle、diff 与布局对齐。

真实 App 使用新数据目录、managed gateway、Computer Use、三路 SSE witness、LLM tap 和连续录屏。短编辑场次真实把临时函数 v4→v5 以单一 `set_code` 成功落定；另一场观察到 `正在修改函数…`、`edit_function 进行中`、`实时聆听中 · 落定以真相为准`，随后打开落定代码舞台，未见跳变、溢出或布局红线。窄中间帧由 focused 测试补足，不冒充 App 画面。

长代码 probe 中模型先发错误形状调用再成功重试，backend WARN 与重进场红失败卡片均如实保留；这不是被隐藏的错误，后续单列为模型工具遵循/重试呈现边界，不吞掉失败事实。

五通道 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-073701`：backend=`883`、SSE=`1211`，messages=`1..162`、notifications=`16..43`、entities=`7..28` 单调无 gap，LLM 全 `200`，frontend 仅已知 IMK 平台噪声，rig-check/rig-down 通过且无残留。调查=`testend/rig/formal-evidence/SURF-102-stage-function-investigation-20260825.md`，L2=`sessions/20260825-073701/evidence/SURF-102-stage-function-five-channel.md`。

五级=`E2/F2/B2/C4/G1`；formal journal=`2425`（2300 baseline + 125 live），coverage=`848/485/0`，anchors=`10/10`。两条统计警报按 `testend/rig/formal-evidence/SURF-102-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，`alarms.py check` clean；下一正式前线=`SURF-103 stage/document`，当前批次=`40/50`，未到 50 格不跑统一长门禁、不提交。P12 的 400+ Journey 仍推迟二期。

## 2026-08-25 · SURF-101 i18n/markdown 图片占位与长 URL 稳定性正式五级入账，批次四十六 35/50

静态反查确认中英文 `markdown.imageNotLoaded` 分别为 `image not loaded` 与 `图片未加载`；`AnMarkdown` 的 markdown 图片统一走不发起网络请求的 `_imagePlaceholder`，显示本地化文案、图标和单行 ellipsis URL。新增双语 locale 回归，既有 markdown widget test 锁定零 `Image` widget，focused Flutter=`32/32`。

真实 App 在全新数据目录中完成 onboarding，以真实 managed gateway 返回精确 markdown，Computer Use 打开 durable transcript，覆盖短 URL 和 298 字符长 URL。首条 Computer Use 直接输入因输入桥损坏 markdown 标点而排除，不算产品绿证据；随后真实 REST 只负责写入精确内容，最终仍由 App 渲染。画面与 AX 都显示 `图片未加载`，长 URL 保持单行并省略，联系表复核无持续跳变、溢出或历史内容重排。证据=`sessions/20260825-072409/evidence/SURF-101-i18n-markdown-five-channel.md`，调查=`testend/rig/formal-evidence/SURF-101-i18n-markdown-investigation-20260825.md`。

五通道：screen=`225.711667s`、backend=`347`、frontend=`5`、SSE=`170`、LLM=`22`；三路 SSE 各连接一次，messages durable=`1..24`、notifications durable=`1..4`，entities 无业务 durable 帧；LLM 带状态记录全 `200`；frontend 仅披露已知 macOS IMK 平台噪声，无 Flutter/Dart/布局/Unhandled 红线；`rig-check`/`rig-down` 通过且无残留。

五级=`E2/F2/B2/C4/G1`；formal journal=`2420`（2300 baseline + 120 live），`gen_coverage.py --check`=`848 rows / 484 carried / 0 tombstones`，anchors=`10/10`。两条统计警报按 `testend/rig/formal-evidence/SURF-101-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。批次四十六当前=`35/50`，未到 50 格不跑统一长门禁、不提交；下一正式前线=`SURF-102 stage/function`。P12 的 400+ Journey 仍推迟二期。

## 2026-08-25 · 历史收口：SURF-100 i18n/appName 产品名与 onboarding wordmark 正式五级入账，批次四十六 30/50

静态反查确认 `appName` 在中英文 locale 均为 `Anselm`，窗口标题、onboarding wordmark、launch-at-login、通知标题和窗口控制无障碍语义均有生成 locale 调用点；onboarding 的 `toUpperCase()` 是明确的品牌排版。新增双语精确回归，focused Flutter=`12/12`。

真实 App 用全新数据目录完成 onboarding。右上角真实显示 `ANSELM`，图形标记与字标同带、无截断/重叠/异常跳位；输入 `SURF-100 品牌检查` 创建 workspace 后回到中文 Chat，产品名没有翻译漂移，workspace 名作为独立用户值显示。帧=`sessions/20260825-071353/evidence/frames/SURF-100-app-name-onboarding.png`、`SURF-100-app-name-final.png`，证据=`sessions/20260825-071353/evidence/SURF-100-i18n-app-name-five-channel.md`，调查=`testend/rig/formal-evidence/SURF-100-i18n-app-name-investigation-20260825.md`。

五通道：screen=`75.223333s`、backend=`136`、frontend=`4`、SSE=`8`、LLM=`10`；三路 SSE 各连接一次，本确定性 onboarding 路径没有业务实体，故没有 durable business frame，不虚构 seq；backend 无应用红线，frontend 仅披露 macOS IMK 平台日志，managed proof/install/models 成功。`rig-check`/`rig-down` 通过且无残留进程。

五级=`E2/F2/B2/C4/G1`；formal journal=`2415`（2300 baseline + 115 live），`gen_coverage.py --check`=`848 rows / 483 carried / 0 tombstones`，anchors=`10/10`。两条统计警报按 `testend/rig/formal-evidence/SURF-100-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。该条为历史收口；批次四十六随后推进至=`35/50`，下一前线=`SURF-102`。P12 的 400+ Journey 仍推迟二期。

## 2026-08-25 · 历史收口：SURF-099 i18n/tree JSON 树真实截断与无障碍正式五级入账

首轮静态审查发现中文 JSON tree 无障碍标签使用半角逗号；修为 `JSON 树，$count 项`，重新生成 slang，并补中英文、invalid/circular/more-items 回归。真实 App 用 2100 项列表经 Workflow → Flowrun → Scheduler 右岛检查器走通，末端实际显示 `1993..1998` 与 `… 101 项已省略`，与 2000 节点上限严格一致；最终帧=`sessions/20260825-065746/evidence/frames/SURF-099-i18n-tree-final.png`。

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-065746`，screen=`451.910000s`、backend=`670`、SSE=`348`、frontend=`4`、LLM=`43`；三路 SSE 均连接，durable=`notifications 16..26 / messages 1..76 / entities 7..24`，LLM HTTP 全 `200`。frontend 唯一 error 文本为已披露的 macOS IMK 平台日志，不是 Flutter/Dart/布局/Unhandled 错误；`rig-check`/`rig-down` 全通过，无残留进程。证据=`sessions/20260825-065746/evidence/SURF-099-i18n-tree-five-channel.md`，调查=`testend/rig/formal-evidence/SURF-099-i18n-tree-investigation-20260825.md`。

五级=`E2/F2/B2/C4/G1`；formal journal=`2410`（2300 baseline + 110 live），`gen_coverage.py --check`=`848 rows / 482 carried / 0 tombstones`，anchors=`10/10`。写账后的两条统计警报按 `testend/rig/formal-evidence/SURF-099-ledger-alarm-reaudit-20260825.md` 独立复核并 ack，阈值/算法/法典/锚点/gate 未改，最终 `alarms.py check` clean。该条为历史收口；当前批次已推进至=`30/50`，下一前线=`SURF-101`。P12 的 400+ Journey 仍推迟二期。

## 2026-08-25 · 历史收口：SURF-098 i18n/status 五态日志词 stop-and-fix 后正式五级入账

首轮真实日志观察发现明细行泄漏 raw `manual · failed`，与已本地化的聚合 `2 完成 / 1 失败` 不一致。停止后 `log_list_provider.dart` 对 function/handler/agent/workflow 四类用户主行统一使用 `AnStatus.fromRaw` → `t.status.*`，detail rows 继续保留 raw status 作为诊断 chrome；双语 provider 回归与既有状态/动画测试全绿。

真实修复后 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-064736`、workspace=`ws_4c8a6c08c07f6523`，Computer Use 走 Entities → `surf041_terminal_function` → 日志，最终显示 `manual · 完成`、`manual · 失败`、`manual · 完成`，聚合 `2 完成 / 1 失败`，无 raw 英文泄漏。录屏帧=`sessions/20260825-064736/evidence/frames/SURF-098-i18n-status-final.png`，正式证据=`sessions/20260825-064736/evidence/SURF-098-i18n-status-five-channel.md`，调查=`testend/rig/formal-evidence/SURF-098-i18n-status-investigation-20260825.md`。

五通道：screen=`71.558333s`；backend=`207` 行无应用红线；SSE=`192` 行，三流真实连接并含成功/失败 durable close；frontend=`3` 行无 Flutter/Dart/布局/Unhandled 红线；llmtap=`13` 行，managed proof/install/models 全 `200`，本格不伪造 chat completion；`rig-check`/`rig-down` 通过。fixture workflow 的 `entry.body.count` 失配仍由 SSE 原样记录，作为后续执行契约红事实保留。

五级=`G1/F1/B2/C4/G1`；formal journal=`2405`（2300 baseline + 105 live），`gen_coverage.py --check`=`848 rows / 481 carried / 0 tombstones`，anchors=`10/10`。两条统计警报按 `testend/rig/formal-evidence/SURF-098-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，`alarms.py check` clean；该条为历史收口，当前批次已推进至=`30/50`，下一前线=`SURF-101`。

## 2026-08-25 · 历史收口：SURF-097 i18n/graph 工作流图节点词正式五级入账

真实 App 进入 `surf041_terminal_workflow` 图编辑器，Computer Use 观察添加节点菜单 `触发/动作/智能体/分支/审批`，并分别选择 `entry` 与 `inspect` 验证检查器的 `触发`/`动作` 标签；未保存、未改变图。focused Flutter=`14/14`，帧=`sessions/20260825-062648/evidence/frames/SURF-097-graph-menu.png`、`SURF-097-graph-final.png`，无 clipping/overlap/reflow/非用户跳变。`未知` fallback 由双语测试覆盖，不伪造 UI 操作。

五通道 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-062648`：screen=`270.311667s`，backend=`375` 行无应用红线，SSE 三流真实连接，frontend=`3` 行无 Flutter/Dart/布局/Unhandled 红线，llmtap challenge/install/models/chat completion 全 `200`；`rig-check`/`rig-down` 通过。fixture 执行真实暴露 `entry.body.*` 与当前 payload 不匹配，SSE 原样记录 `no such key: body`，保持为后续执行契约红事实。正式证据=`sessions/20260825-062648/evidence/SURF-097-i18n-graph-five-channel.md`，调查=`testend/rig/formal-evidence/SURF-097-i18n-graph-investigation-20260825.md`。

五级=`G1/F1/B2/C4/G1`；formal journal=`2400`（2300 baseline + 100 live），`gen_coverage.py --check`=`848 rows / 480 carried / 0 tombstones`，anchors=`10/10`。两条统计警报按 `testend/rig/formal-evidence/SURF-097-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。该条为历史收口；当前批次=`20/50`，下一前线=`SURF-099`。

## 2026-08-25 · 历史收口：SURF-096 i18n/startup 启动门控 stop-and-fix 后正式五级入账

首轮 App-first 红测真实发现启动崩溃页泄露 raw backend URL/英文内部错误；停止后移除启动门 `AnState.detail` 绑定，保留日志诊断，focused Flutter=`12/12`。修复后 `sessions/20260825-061312` 的无 workspace 真实 App 只显示本地化错误标题/提示/重试，点击真实重试恢复创建工作区；第二轮 `sessions/20260825-061754` 预置 workspace 重跑，三路 SSE 真实连接，重试后进入实体总览壳。

五通道：第一轮 screen=`73.485000s`、backend=`61`、frontend=`3`，无 workspace 所以无业务 SSE durable 帧且不伪造；第二轮 screen=`86.055000s`、backend=`84`、SSE 三流连接/EOF、frontend=`3`、llmtap=`10`。两轮均无应用红线，`rig-check`/`rig-down` 通过且无残留；本启动路径无 chat completion，不伪造 LLM completion。正式证据=`sessions/20260825-061312/evidence/SURF-096-i18n-startup-five-level.md`，L2 补证=`sessions/20260825-061754/evidence/SURF-096-i18n-startup-five-channel.md`，调查=`testend/rig/formal-evidence/SURF-096-i18n-startup-investigation-20260825.md`。

五级=`G1/F1/B2/C4/G1`；formal journal=`2395`（2300 baseline + 95 live），`gen_coverage.py --check`=`848 rows / 479 carried judgments / 0 tombstones`，anchors=`10/10`。两条统计警报按 `testend/rig/formal-evidence/SURF-096-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。该条为历史收口；当前批次=`20/50`，下一前线=`SURF-099`。

## 2026-08-25 · SURF-095 i18n/diff 差异查看动作语言正式五级入账，批次四十六 5/50

首轮静态审查发现中文差异菜单把内部术语 `diff` 直出，且 `只显变更`偏电报化、半角括号不符合中文排版。stop-and-fix 将七个键修为 `新增/删除/… 省略 $n 行/展开全部（$n 行）/仅显示变更/展开差异/收起差异`，重新生成 slang，并新增双语精确回归；聚焦 Flutter=`43/43`。

真实中文 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-060117` 在实体版本页实际构造并查看 v1→v2 差异，Computer Use 打开 v1 菜单验证 `收起差异/展开全部（3 行）/设为活跃版本`，切换整份后再验证 `收起差异/仅显示变更/设为活跃版本`。最终帧=`sessions/20260825-060117/evidence/frames/SURF-095-final.png`，无 clipping/overlap/reflow/非用户跳变。正式证据=`sessions/20260825-060117/evidence/SURF-095-i18n-diff-five-level.md`，调查=`testend/rig/formal-evidence/SURF-095-i18n-diff-investigation-20260825.md`。

五通道：screen=`139.673333s / 2784x1808 / H.264`；backend=`249` 行无应用红线且 D1/health 通过；SSE=`14` 行，notifications durable=`16..18`、entities=`7..8` 连续，三流 clean EOF；frontend=`19` 行无 Dart/Flutter/布局/Unhandled 应用红线，固定 AXTree bridge 观察器签名以 `evidence/frontend-ax-review.md` 审阅；llmtap=`10` 行，真实 managed gateway challenge/install/models 全 `200`，本确定性路径无 completion 不伪造。`rig-check`/`rig-down` 全绿且无残留进程。

五级=`G1/F1/B2/C4/G1`；formal journal=`2390`（2300 baseline + 90 live），`gen_coverage.py --check`=`848 rows / 478 carried judgments / 0 tombstones`，anchors=`10/10`。两条统计警报按 `testend/rig/formal-evidence/SURF-095-i18n-diff-investigation-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。当前批次=`5/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`SURF-096 i18n/startup`。

## 2026-08-25 · 历史快照：批次四十五已提交，前线曾推进至 SURF-095

批次四十五 `SURF-085` 至 `SURF-094` 已完成 50/50 并提交 `f0a4aa11`。统一 `make verify`、backend `testend=300.030s`、rig 自测 `50/50`、coverage=`848/477/0`、anchors=`10/10`、alarms=`85 live clean`、gofmt/diff 和进程审计均通过；提交前的覆盖清册和中文 onboarding 测试漂移已修复并纳入批次。下一前线=`SURF-095 i18n/diff`，批次四十六=`0/50`。

## 2026-08-25 · SURF-094 i18n/action 通用动作词正式五级入账，批次四十五 50/50

`SURF-094 i18n/action` 的八个动作键 `编辑/取消/保存/复制/展开/收起/自动换行/删除` 已完成双语资源静态核对、完整 locale 回归 `6/6` 和真实 App 走查。实体详情展示 `复制/自动换行`，文库更多操作展示 `展开全部/收起全部`，MCP 手动添加表单展示 `添加/取消`；`编辑/保存/删除` 由生成调用点与既有实体/编辑器/确认框测试覆盖，无英文旁路。

绿色 session=`sessions/20260825-052544`：screen=`166.140000s / 2784x1808`，backend=`260`、SSE=`8`、frontend=`17`、llmtap=`10`。五通道物理接线、D1、health、三流 SSE 和 managed wiring 通过；后端/LLM 无应用红线。前端 journal 保留 Computer Use 快速 AX 树切换产生的 Flutter `accessibility_bridge.cc` 桥接消息，后续 AX 读取与画面均正常，正式证据不隐藏该边界。无 Chat completion 的动作只读路径不伪造 completion 或 durable 业务帧。正式证据=`sessions/20260825-052544/evidence/SURF-094-i18n-action-five-level.md`，调查=`testend/rig/formal-evidence/SURF-094-i18n-action-investigation-20260825.md`。

五级=`G1/F1/B2/C4/G1`；formal journal=`2385`（2300 baseline + 85 live），`gen_coverage.py --check`=`848 rows / 477 carried judgments / 0 tombstones`，anchors=`10/10`。两条统计警报已按 `testend/rig/formal-evidence/SURF-094-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate。批次已到 `50/50`，统一长门禁已通过，记录=`testend/rig/formal-evidence/batch-45-gate-20260825.md`；提交前只剩 staged diff 审计，提交后前进到 `SURF-095`。

## 2026-08-25 · SURF-093 i18n/coldStart 首启与语言轴正式五级入账，批次四十五 45/50

首轮 `RIG_SEED=0` 冷启动发现 onboarding 后释放到空白 Chat 时泄漏四个英文键：`What should we dig into?`、`Auto`、`Mention an entity`、`Attach files`；红 session=`sessions/20260825-051818` 不计入判断。stop-and-fix 补齐 `coldStart` 全组文案与四个同屏 Chat 键，重新生成 slang，并以 focused suite=`11/11` 锁定完整冷启动 11 键与 Chat 4 键。

绿色 session=`sessions/20260825-052124`：空 workspace 首帧、输入态、`正在准备工作区…` 创建态和释放后 Chat 均真实走通；AX/画面一致显示中文 `工作 №001`、`创建工作区`、`工作区名称`、`自动`、`想从哪里开始？`、`提及实体`、`添加附件`、`想聊点什么？`，过渡无卡死/clipping/overlap/非用户跳变。五通道 screen=`46.655000s / 2784x1808`，backend=`108`，SSE=`8`，frontend=`4`，llmtap=`10`；三流 clean EOF，本路径无 Chat completion，未伪造业务 durable 帧。正式证据=`sessions/20260825-052124/evidence/SURF-093-i18n-coldStart-five-level.md`，调查=`testend/rig/formal-evidence/SURF-093-i18n-coldStart-investigation-20260825.md`。

五级=`G1/F1/B2/C4/G1`；formal journal=`2380`（2300 baseline + 80 live），`gen_coverage.py --check`=`848 rows / 476 carried judgments / 0 tombstones`，anchors=`10/10`。两条统计警报按 `testend/rig/formal-evidence/SURF-093-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，最终 `alarms.py check` clean。下一前线=`SURF-094`；当前批次=`45/50`，未到 50 格不跑统一长门禁、不提交。

## 2026-08-25 · SURF-092 i18n/ref 引用类型与真实执行正式五级入账，批次四十五 40/50

静态反查确认 `AnRefPill` 的 11 个类型分支全部经过 `entityKindWord`；新增双语完整集合回归，focused locale/ref suite=`12/12`。真实 App 走过实体、文库、MCP 设置和 Chat mention picker；选择 `sync_inventory` 后插入引用并发送最小问题，模型正确识别函数引用、执行一次并返回 `synced=42`，消息区和 Activity 侧幕一致。

绿色 session=`sessions/20260825-051028`：screen=`102.840000s / 2784x1808`，backend=`228`、SSE=`76`、frontend=`4`、llmtap=`19`；三流 durable message open/tool close/message close 与 notification signal 真实可见，seq 单调、delta=`seq=0`，managed proof/install/models/chat 穿过 tap，前端无 Flutter/Dart/布局/Unhandled 红线。正式证据=`sessions/20260825-051028/evidence/SURF-092-i18n-ref-five-level.md`，调查=`testend/rig/formal-evidence/SURF-092-i18n-ref-investigation-20260825.md`。

五级=`G1/F1/B2/C4/G1`；formal journal=`2375`（2300 baseline + 75 live），`gen_coverage.py --check`=`848 rows / 475 carried judgments / 0 tombstones`，anchors=`10/10`。两条统计警报按 `testend/rig/formal-evidence/SURF-092-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，最终 `alarms.py check` clean。下一前线=`SURF-093`；当前批次=`40/50`，未到 50 格不跑统一长门禁、不提交。

## 2026-08-25 · SURF-091 i18n/shell 壳层状态与原生可达性正式五级入账，批次四十五 35/50

首轮真实 AX 树发现顶部四海洋中三个折叠图标槽是无名按钮；红场不计入判断。stop-and-fix 在 `an_ocean_switcher.dart` 为每个槽增加本地化 `semanticLabel` 与 `semanticFocusable`，新增语义回归；修复后 focused suite=`35/35`。

绿色 session=`sessions/20260825-050144`：真实 AX 暴露 `对话/实体/调度/文库` 并逐一切换；设置、workspace 菜单 `新建工作区/工作区设置`、通知托盘接管左岛、侧栏 `收起侧栏/展开侧栏` 均真实走通。`comingSoonTitle/Hint` 在当前五个 `OceanKind` 全 built 下结构性不可达，证据明确记录而非伪造点击。五通道 screen=`112.400000s / 2784x1808`，backend=`198`，SSE=`4`，frontend=`4`，llmtap=`10`，无应用红线；正式证据=`sessions/20260825-050144/evidence/SURF-091-i18n-shell-five-level.md`，调查=`testend/rig/formal-evidence/SURF-091-i18n-shell-investigation-20260825.md`。

五级=`G1/F1/B2/C4/G1`；formal journal=`2370`（2300 baseline + 70 live），`gen_coverage.py --check`=`848 rows / 474 carried judgments / 0 tombstones`，anchors=`10/10`。两条统计警报按 `testend/rig/formal-evidence/SURF-091-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，最终 `alarms.py check` clean。下一前线=`SURF-092 i18n/ref`；当前批次=`35/50`，未到 50 格不跑统一长门禁、不提交。

## 2026-08-25 · SURF-090 i18n/attach 正式五级入账，批次四十五 30/50

首轮真实 App AX 走查发现附件 chip/失败重试虽然可见，但没有进入原生 AX 树；红场不计入判断。stop-and-fix 在 `an_attachment_chip.dart`、`an_composer.dart`、`an_interactive.dart` 增加文件名/状态/动作语义边界，focused Flutter=`36/36`；视觉布局保持不变。

最终 session=`sessions/20260825-044311`：AX 可读准备中、取消准备、失败和重试；无效 PNG 真实失败并重试，有效 JPEG 经受管网关上传、视觉调用和 Chat 完成。取消动作已可达，但无效 worker 约 1 秒内完成，本次未捕获取消 HTTP 请求；该竞态已如实记录，后端取消场景有回归覆盖，未伪造端到端成功。正式证据=`sessions/20260825-044311/evidence/SURF-090-i18n-attach-five-level.md`，调查=`testend/rig/formal-evidence/SURF-090-i18n-attach-investigation-20260825.md`。

五通道：screen=`363.483333s / 2784x1808`，backend=`491`，SSE=`76`，frontend=`4`，llmtap=`43`；gateway proof/install/media/chat=`200/201`，三流 SSE 无 gap，前端无 Flutter/Dart/布局/Unhandled 红线。五级=`G1/F1/B2/C4/G1`；formal journal=`2365`（2300 baseline + 65 live），`gen_coverage.py --check`=`848 rows / 473 carried judgments / 0 tombstones`，anchors=`10/10`，警报复审 ack 后 `alarms.py check` clean。下一前线=`SURF-091 i18n/shell`；当前批次=`30/50`，未到 50 格不跑统一长门禁、不提交。

## 2026-08-25 · SURF-089 i18n/a11y 修复后正式五级入账，批次四十五 25/50

首轮真实 AX 检查发现 inline editor 只暴露匿名 `text field (settable)`；第一次原生桥实验又因多余的 `setAccessibilityElement(true)` 把角色变成 `unknown`，两次红场均不计绿。最终修复只给 Flutter 内部原生 `FlutterTextField` 设置 `accessibilityLabel`，不改变角色、输入协议或视觉布局。

绿色 session=`sessions/20260825-040519`：真实 AX 树进入编辑后显示 `text field (settable) 描述`，输入后显示 `Description: 描述, Value: Native AX`，取消后回到 `添加简介…`。五通道与 storage 封口通过，正式证据=`sessions/20260825-040519/evidence/SURF-089-i18n-a11y-five-level.md`，首轮调查=`testend/rig/formal-evidence/SURF-089-i18n-a11y-investigation-20260825.md`。

`judge.py` 已串行写入 `G1/F1/B2/C4/G1`，COVERAGE=`848 rows / 472 carried judgments / 0 tombstones`，`gen_coverage.py --check` clean；写账后的两条统计警报由 `testend/rig/formal-evidence/SURF-089-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，最终 `alarms.py check` clean。未到 50 格不跑统一长门禁、不提交。下一原子前线=`SURF-090 i18n/attach`。

## 2026-08-25 · SURF-088 i18n/feedback 已入账

`SURF-088 i18n/feedback` 已完成真实 App 五级 `G1/F1/B2/C4/G1`。首轮发现 seed `greet` 的必填 `name` 参数缺少输入声明；修复 seed 后，第二轮又发现流式 traceback 泄漏进主输出终端。两次红场分别为 `sessions/20260825-025554` 与 `sessions/20260825-030052`，均不入账；修复后以 entity format=`3/3`、run terminal=`8/8` 回归锁定。

绿色 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-030446`：真实中文 App 走通 seed greet 成功运行、临时失败 Function、中文人话摘要、`技术详情` 展开/收起、Copy=`已复制` 和删除后列表回基线。screen=`2696x1720 / 224.743333s`，backend=`330`、SSE=`25`、frontend 仅正常启动/Dart VM、llmtap proof/install/models 全 200；三流 SSE 连接/EOF、实体成功/失败 open-close durable、gap=`0`；SQLite integrity=`ok`、foreign-key check 为空、执行=`1 ok + 1 failed`。正式证据=`sessions/20260825-030446/evidence/SURF-088-i18n-feedback-five-level.md`，独立警报复核=`testend/rig/formal-evidence/SURF-088-ledger-alarm-reaudit-20260825.md`。

正式 journal=`2360`（2300 baseline + 60 live），`gen_coverage.py --check`=`848 rows / 472 carried judgments / 0 tombstones`；SURF-089 五格已入账，下一前线=`SURF-090 i18n/attach`。当前批次=`25/50`，未到 50 格不跑统一长门禁、不提交；P12 400+ Journey 继续按用户裁定推迟二期。

## 2026-08-25 · SURF-087 i18n/run 已入账

`SURF-087 i18n/run` 已完成真实 App 五级 `G1/F1/B2/C4/G1`。首轮运行卷宗走查发现失败 fallback 泄漏英文 `Execution failed.`，修复 scheduler run model、三处 UI projection、双语 i18n 与 focused Flutter 回归 `65/65` 后重建；修复后的真实重跑又发现重放确认标题 `重放这个 run?` 混合中英文，进一步修为 `重放这次运行？` 并同步批量重放/不可重放文案，重新生成并在真实 modal 复验。

绿色 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-024808`，最终 screen=`2784x1808 / 45.240s`，backend=`115`、SSE=`16`、frontend=`3`、llmtap=`1`；backend/frontend 无应用红线，SQLite integrity=`ok`、foreign-key check 为空，flowruns=`5 completed / 6 failed / 2 running`，nodes=`30`。正式证据=`sessions/20260825-024808/evidence/SURF-087-i18n-run-five-level.md`，独立警报复核=`testend/rig/formal-evidence/SURF-087-ledger-alarm-reaudit-20260825.md`。

正式 journal=`2350`（2300 baseline + 50 live），`gen_coverage.py --check`=`848 rows / 470 carried judgments / 0 tombstones`；anchors=`10/10`，`gap-too-fast` 与 `discovery-collapse` 已独立复审并 ack，最终 `alarms.py check` clean，未改阈值、算法、法典、锚点或 gate。当前批次=`15/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`SURF-088 i18n/feedback`。P12 400+ Journey 继续按用户裁定推迟二期。

## 2026-08-25 当前前线重述

`SURF-086 i18n/notifications` 已完成真实 App 五级 `G1/F1/B2/C4/G1`。全新 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-022809` 真实走通通知入口、今天分组、9 条通知、单条已读、仅未读、组头全部已读/全部未读、deploy 搜索、收展与 hover 标为已读；最终中文通知托盘稳定，无 clipping/overlap/非用户跳变。正式证据=`sessions/20260825-022809/evidence/SURF-086-i18n-notifications-five-level.md`，AX 复核=`sessions/20260825-022809/evidence/frontend-ax-review.md`，告警复核=`testend/rig/formal-evidence/SURF-086-ledger-alarm-reaudit-20260825.md`。

五通道 rig-check/rig-down 全绿：screen=`2784x1808 / 281.475s`，backend=`380` 行无应用红线，SSE=`8` 行且三流真实连接/EOF，frontend=`45` 行只含已审阅 AXTree tooling churn 与 IMK/CapsLock 宿主行，llmtap=`10` 行 readiness/managed gateway，REST unread-count/list=`9/9`，SQLite integrity=`ok`。正式 journal=`2345`（2300 baseline + 45 live），`gen_coverage.py --check`=`848 rows / 469 carried judgments / 0 tombstones`；`gap-too-fast` 独立复审并 ack，`alarms.py check` clean。当前批次=`10/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-087 i18n/run`。P12 400+ Journey 继续按用户裁定推迟二期。

`SURF-085 i18n/library` 已完成真实 App 五级 `G1/F1/B2/C4/G1`。首轮真实场景发现中文 Chat composer 泄漏英文 `Ask anything…`；红 session=`sessions/20260825-021142` 不计入判断。stop-and-fix 修改 `zh_CN.i18n.json` 为 `想聊点什么？`，重新生成 slang，并补双语 locale 回归 `3/3`；绿场重新构建，未复用红场。

绿色 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-021948` 真实走过文库 rail 五篇文档、Skill rail 三项 Skill、文档检查器正文/大纲/属性/反链/展开全部、Skill 四文件/两绑定表单，并回到 Chat 通过真实受管网关查询文库与 Skill 数量。最终 UI 显示中文 composer `想聊点什么？`，活动卡 `已列文档 · 5 个`，完整中文表格准确给出文档 `5`、技能 `3` 及名称；画面无 clipping/overlap/非用户跳变。正式证据=`sessions/20260825-021948/evidence/SURF-085-i18n-library-five-level.md`，告警复核=`testend/rig/formal-evidence/SURF-085-ledger-alarm-reaudit-20260825.md`。

五通道 rig-check/rig-down 全绿：screen=`2784x1808 / 148.115s`，backend=`281` 行无应用红线，SSE=`132` 行且 messages/entities/notifications durable 序列单调，frontend=`4` 行仅正常启动/VM 与已知 IMK host noise，llmtap=`19` 行且真实 gateway challenge/install/models/chat 全 200，SQLite integrity=`ok`。正式 journal=`2340`（2300 baseline + 40 live），`gen_coverage.py --check`=`848 rows / 468 carried judgments / 0 tombstones`；`gap-too-fast` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，`alarms.py check` clean。当前批次=`5/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-086 i18n/notifications`。P12 400+ Journey 继续按用户裁定推迟二期。

`SURF-084 i18n/scheduler` 已完成五级 `G1/F1/B2/C4/G1`。首轮真实 scheduler 走查发现失败 run 速览卡直接暴露 Python `Traceback`、本地路径、节点 ID 与运行时包装原文；红 session=`sessions/20260825-014625` 排除。修复 `scheduler_run_model.dart` 的 traceback 用户投影，保留最终异常原因并移除技术包装，focused Flutter=`26/26`；绿色 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-014850` 为修复后重建的 App。

真实覆盖 scheduler 总览 KPI、空 cron 状态、approval `通过`、running/failed lane、失败 peek、Graph/Open/full detail、钉版节点图、甘特、节点台账、运行卷宗与失败节点 `重放`。速览和详情均只显示 `SURF-029 deliberate failure 1`；重放确认准确显示“重跑 1 个失败节点 · 复用 1 个已完成结果”，重放后的失败状态、钉版 v1 与成功节点复用均诚实保留。最终帧视觉检查通过，无 clipping/overlap/非用户跳变或未解释 scheduler 英文。

五通道 rig-check/rig-down 全绿，screen=`2784x1808 / 188.261667s`，backend=`318` 行无应用红线，SSE=`57` 行含 run/approval/replay durable 终态，frontend=`3` 行仅正常启动/VM，llmtap challenge/install/models 全 200。证据=`sessions/20260825-014850/evidence/SURF-084-i18n-scheduler-five-level.md`，告警复核=`testend/rig/formal-evidence/SURF-084-ledger-alarm-reaudit-20260825.md`。正式 journal=`2335`（2300 baseline + 35 live），`gen_coverage.py --check`=`848 rows / 467 carried judgments / 0 tombstones`，当前批次=`50/50`；`gap-too-fast` 按原阈值独立复审并 ack，未改阈值/算法/法典/锚点/gate。统一长门禁已通过（`make verify`、`make -C backend testend`=`314.193s`、rig=`50/50`、gofmt/compile/diff/process audit 全绿），本批已提交 `0177b9cf`；下一前线为 `SURF-085 i18n/library`，P12 400+ Journey 继续按用户裁定推迟二期。

`SURF-083 i18n/entities` 已完成五级 `G1/F1/B2/C4/G1`。首轮真实实体走查发现函数空输出执行在同一详情页运行后，右侧终端更新但 Logs provider 不刷新；红 session=`sessions/20260825-012354` 排除。修复共享 `entitystream.Writer.Close` 使空运行也发 durable `open → close`，保留重复收尾幂等，并补 backend 与 Flutter 回归。绿色 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-013336` 在同一页面复验后立即出现 `1 完成 / 0 失败` 与 `manual · ok`，SSE 见同一 block id 的 `open`/`close completed`。同 session 真实覆盖总览/关系图、函数/处理器/智能体/工作流、控制/审批/触发器详情及运行/日志/版本/空态。

证据=`sessions/20260825-013336/evidence/SURF-083-i18n-entities-five-level.md`，告警复核=`testend/rig/formal-evidence/SURF-083-ledger-alarm-reaudit-20260825.md`。五通道 rig-check/rig-down 全绿，backend 448 行无应用红线，SSE 103 行，frontend 仅正常启动/VM 行，llmtap challenge/install/models/chat 全 200，终帧只含 Anselm。`gap-too-fast` 按原阈值独立复审并 ack，未改阈值、算法、法典、锚点或 gate；正式 journal=`2330`（2300 baseline + 30 live），`gen_coverage.py --check`=`848 rows / 466 carried judgments / 0 tombstones`，当前批次=`45/50`；50 格前不跑统一门禁、不提交。下一前线由 formal sequence gate 决定，P12 400+ Journey 继续按用户裁定推迟二期。

`SURF-082 i18n/settings` 已完成五级 `G1/F1/B2/C4/G1`。首轮真实设置走查发现中文 Models & keys 的
`Agent` 泄漏，修复三处 locale 文案为 `智能体` 系列并重新生成产物、补双语回归；红 session=
`sessions/20260825-010946` 明确排除。修复后真实 App 逐一走过 13 个设置面板、偏好/资源/系统三段目录、
动态空态与模型场景行；切换 English 后真实键盘搜索 `model` 命中 `Models & keys`，`proxy` 命中 Network
及三个代理项。中文 grouping/hint 由纯函数/widget 门禁覆盖；Computer Use paste 不派发 Flutter
`onChanged`，归类为观察器限制而非产品缺陷。

绿色 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-011352`，证据=`sessions/20260825-011352/evidence/SURF-082-i18n-settings-five-level.md`，告警复核=`testend/rig/formal-evidence/SURF-082-ledger-alarm-reaudit-20260825.md`。五通道 rig-check/rig-down 全绿，最终帧只含 Anselm，frontend 仅已知 IMK host noise；focused locale=`3/3`、settings search=`all passed`。

五级写账触发的 `gap-too-fast` 已按原阈值独立复审并 ack，未改阈值、算法、法典、锚点或 gate。正式 journal=`2325`（2300 baseline + 25 live），`gen_coverage.py --check`=`848 rows / 465 carried judgments / 0 tombstones`，该格完成时批次=`40/50`；SURF-083 已在上方整体重述并推进到 `45/50`，50 格前不跑统一门禁、不提交。P12 的 400+ Journey 继续按用户裁定推迟二期。

`SURF-081 i18n/chat` 已完成五级 `G1/F1/B2/C4/G1`。真实中文 Chat 首轮发现 reasoning UI 标签误显英文
`thought`/`thinking`，先保留红 session、修复双语源为 `思考`/`思考中`、重新生成 slang 并补回归；修复后
重建真实 App，English/简体中文 Chat rail、composer、历史回答、流式思考态和 turn actions 均通过，真实
回答 `acceptance-ping`/`live-ping` 收口。证据=`sessions/20260825-010531/evidence/SURF-081-i18n-chat-five-level.md`，
红 session=`sessions/20260825-005929` 不计入判断；`gap-too-fast` 复审=`testend/rig/formal-evidence/SURF-081-ledger-alarm-reaudit-20260825.md`，未改阈值、算法、法典、锚点或 gate。

focused locale=`3/3`，最终 journal=`2320`（2300 baseline + 20 live），`gen_coverage.py --check`=`848 rows / 464 carried judgments / 0 tombstones`，当前批次=`35/50`；50 格前不跑统一门禁、不提交。P12 的 400+ Journey 继续按用户裁定推迟二期。

`SURF-080 settings/detail-push` 已完成五级 `G1/F1/B2/C4/G1`：真实 App 逐一到达 12 个 detail kind
（`addKey/editKey/sandboxInstall/mcpServer/mcpAdd/mcpImport/mcpMarket/mcpInstall/addMemory/memory/
addWorkspace/workspace`），并用本地可删除夹具补齐已有实体路径。MCP registry 的短暂 Loading 在 15 秒
超时后正常落到内置 102 条快照；没有第三方安装、真实凭证或 fixture 残留。证据=`sessions/20260825-004915/evidence/SURF-080-settings-detail-push-five-level.md`，
补充 session=`sessions/20260825-002854`；最终 REST=`1 workspace / 1 managed key / 0 MCP / 0 memory`。

本格发现并修复台架 stale recorder：App 重启时 macOS window ID 变化但 geometry 不变，`rig-rebind-app.sh`
现在仍切换录制段，`test_screen_recording.py` 新增回归；修复后 window `760→769` 的 live rebind 和五通道
`rig-check` 全绿。静态台架回归=`37/37`，最终 journal=`2315`（2300 baseline + 15 live），
`gen_coverage.py --check`=`848 rows / 463 carried judgments / 0 tombstones`；`gap-too-fast` 已由
`testend/rig/formal-evidence/SURF-080-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值、算法、法典、锚点或 gate；当前批次=`30/50`；50 格前不跑统一门禁、不提交。P12 的 400+ Journey 继续按用户裁定推迟二期。

历史 runtime journal 不可恢复，但用户已明确裁定不回头重验已提交 COVERAGE。`rebuild_ledger.py` 将 `2300` 个 carried 单格恢复为明确标注 `source=coverage-baseline` 的历史基线并生成 `ledger-baseline.json`；基线排除实时漂移曲线，真实 `judge.py` 裁决继续追加，baseline 单格集合由 gate 硬校验为当前清册子集。连续性审计=`testend/rig/formal-evidence/ledger-continuity-audit-20260825.md`。

`SURF-078 settings/panel-shortcuts` 已写入 `G1/F1/B2/C4/G1`，session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260824-233028`，真实手动 `⌘J` 改绑、持久化、冲突拒绝、Escape、Reset all 和 Chat 左岛切换均通过；该格后 `COVERAGE=848 rows / 461 carried judgments`。

`SURF-079 settings/panel-about` 已写入 `G1/F1/B2/C4/G1`。真实 App 验证版本、Engine、字体许可、GitHub Releases 404/no-release 诚实态、`Checking…` 加载反馈、诊断 clipboard 和 `Copied` 通知；无产品/视觉 defect。session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-001953`，证据=`sessions/20260825-001953/evidence/SURF-079-settings-panel-about-five-level.md`，窗口级 `screencapture -l 643` 录屏=`2784x1808 / H.264 / 49.323333s`。旧 `-R` 矩形 session 因终帧捕获 Codex 宿主被拒绝，现已把首次录制、rebind 和 rig-check 统一到 window ID 捕获，未知遮挡仍硬失败；理由已同步 `testend/rig/README.md`。

SURF-079 五通道封口：backend 无应用红线，SSE 三流连接并 clean EOF，frontend 无 Flutter/Dart/布局红线，llmtap challenge/install/models 全 200；确定性设置路径无 durable business frame 或模型 completion，不虚构。写账触发的 `gap-too-fast` 已以 `testend/rig/formal-evidence/SURF-079-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值、算法、法典、锚点或 gate；`alarms.py check`=`10 live / 2300 baseline excluded` clean。正式 journal=`2310`，`gen_coverage.py --check`=`848 rows / 462 carried judgments / 0 tombstones`，当前批次=`20/50`，下一前线为 `SURF-080`；50 格前不跑统一门禁、不提交。P12 400+ Journey 继续按用户裁定推迟二期。

`SURF-075 settings/panel-storage` 已完成真实 App + managed gateway 五级验收。真实覆盖 Storage & logs 的数据目录、磁盘/数据库/附件统计、诊断复制、Run 历史保留、数据库压缩、Reset local preferences，以及用户明确确认后的不可逆 Factory reset。用户输入 `Anselm` 并点击 `Erase everything & relaunch` 后，旧 App/sidecar 优雅停止，replacement App 回到 `Create a workspace` onboarding，旧 workspace 没有幽灵残留。

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260820-121523`，旧 App/sidecar=`57551/57583`，replacement App/sidecar=`57682/57684`，replacement port=`58408`；录屏原段=`322.903333s`，重启后段=`17.951667s`，合并=`340.870000s / 2560x1584 / H.264 / 60fps`；证据=`sessions/20260820-121523/evidence/SURF-075-settings-panel-storage-five-level.md`，警报复审=`sessions/20260820-121523/evidence/SURF-075-ledger-alarm-reaudit.md`。五通道：backend=`119` 行、SSE=`966` 行、frontend=`227` 行、llmtap=`10` 行；三路 SSE 各真实连接、无 gap，managed challenge/install/models 全 `200`，应用红线扫描 clean。窗口重启后仅发生 1px 几何变化，conductor 封存旧段并原子切换新 crop，未使用 stale crop。

五级=`G1/F1/B2/C4/G1`，formal ledger=`2325 judgments`，COVERAGE=`848 rows / 458 judged / 0 tombstones`，anchors=`10/10`，alarms=`clean`。写账触发的 `gap-too-fast`/`discovery-collapse` 已按独立 session、外部 backend 红尝试、App-owned rebind、五通道 journal 和 10/10 anchor calibration 逐条复审并 ack，未改阈值、算法、法典、锚点或 gate。批次四十三=`50/50`；统一长门禁已通过：root `make verify` frontend/backend/docs/demo 全绿、Flutter=`5376 tests`、`make -C backend testend`=`288.411s`、rig=`44/44`、gofmt/diff/process audit 全绿。提交前只剩最终 staged diff 审计，下一前线为 `SURF-076`。P12 400+ Journey 按用户裁定推迟二期。

`SURF-076 settings/panel-limits` 已完成五级 `G1/F1/B2/C4/G1`：真实 App 中打开 Advanced limits，确认机器级范围、17 个 schema 字段和五组滚动布局，真实修改与非法回滚均可由用户目的驱动完成；PATCH/GET、Reset 结果与 backend/REST 真相一致，编辑、滚动、错误回滚和确认收口没有观察到非用户触发的内容跳变；scope badge、group hierarchy、row descriptions、units、range copy、modified-row reset affordance 和 destructive confirmation 的视觉层级清楚且一致，新用户从 Settings 侧栏可自行找到入口。正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260820-133336`，证据=`sessions/20260820-133336/evidence/SURF-076-settings-panel-limits-five-level.md`；五通道已封口，anchors=`10/10`，alarms=`clean`。formal ledger=`2325→2330 judgments`，COVERAGE=`848 rows / 459 judged / 0 tombstones`，批次四十四=`5/50`。L5 后统计警报按原阈值打开，已独立重审并 ack，未改阈值/算法/法典；下一格为 `SURF-077`。

`SURF-077 settings/panel-network` 已完成五级 `G1/F1/B2/C4/G1`：真实 App 从 Settings 侧栏进入 Network，看到 machine scope、三字段、Save 和重启注记；空值直连与填写/清空两条用户目的均可达；两次整体 PATCH、返回值、离开重进的持久化状态和最终 `{}` 均与 backend/REST 真相一致；字段编辑、离开重进、保存提示和清空收口没有观察到非用户触发的内容跳变；scope badge、purpose hint、label-above rhythm、mono inputs、restart warning callout 和 primary Save hierarchy 清楚克制，新用户不读文档也能找到入口并理解重启后生效。正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260820-134625`，证据=`sessions/20260820-134625/evidence/SURF-077-settings-panel-network-five-level.md`；五通道已封口，formal ledger=`2330→2335 judgments`，COVERAGE=`848 rows / 460 judged / 0 tombstones`，批次四十四=`10/50`。L5 后统计警报按原阈值打开，已独立重审并 ack，未改阈值/算法/法典；下一格为 `SURF-078`。

`SURF-078 settings/panel-shortcuts` 已完成一次真实 App 五通道走查，但尚未裁决。入口、六条全局命令、逐键帽、录制态、无修饰键提示、Escape 取消与 Reset all 均真实观察；session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260820-135637`，screen=`376.895000s`，journals=`backend 450 / SSE 9 / frontend 3 / LLM 10`，无应用红线。正式证据=`sessions/20260820-135637/evidence/SURF-078-settings-panel-shortcuts-blocked.md`。Computer Use `sky.press_key` 的 macOS 注入没有产生 Flutter 所需的 `meta/control` 状态，App 因而正确拒绝所有尝试并显示无修饰键提示；成功改绑、冲突、持久化、单项 Reset 和改绑后全局快捷键不能诚实完成，仓内 S6 测试 `8/8` 只能作支持证据，不能代替真实 App。formal ledger/COVERAGE/批次保持 `2335 / 848·460 / 10/50`；下一动作是恢复真实 Command 注入后原地续跑，本格未绿前不前进、不跑 50 格门禁、不提交。

SURF-075 出厂重置复核没有新增判决。外接 backend 的 `child=null`、App sandbox 拒绝 `/private/tmp`、直接 exec 同 bundle 不留 replacement 三个前置问题均 stop-and-fix；最终改用 App-owned + 默认 `.anselm` 容器数据根及 `open -n <bundle>`，真实 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260820-132029` 完成旧 App/sidecar graceful stop、数据目录消失、replacement onboarding、App/sidecar rebind 和五通道 `rig-check`。这条历史记录已被当前前线覆盖，不能用于当前计数。

### 历史快照: SURF-073 settings/panel-sandbox

`SURF-073 settings/panel-sandbox` 已完成真实 App + managed gateway 五级验收。真实覆盖健康门健康态与 degraded 失败/Retry 恢复、机器级磁盘字节、Python 3.13 安装与删除、被环境引用的 Python 3.12 删除保护、未引用运行时删除取消/确认、五 owner tab、环境删除和 GC 两步确认。真实键盘输入非法 dotnet 版本立即得到可执行版本提示；`set_value` 未触发 Flutter `onChanged` 的仪器观察已排除并清理，不算产品缺陷。

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260820-001124`，录屏=`572.355000s`；证据=`sessions/20260820-001124/evidence/SURF-073-settings-panel-sandbox-five-level.md`，警报复审=`sessions/20260820-001124/evidence/SURF-073-ledger-alarm-reaudit.md`。五通道全封口：backend=`726` 行（唯一 WARN 为故意 degraded 注入），SSE=`11` 行并捕获 `sandbox.env_deleted`，frontend=`4` 行仅正常/已知 host noise，llmtap=`10` 行 managed bootstrap 全 `200`，focused Flutter=`47/47`，`rig-check`/`rig-down` 通过。

五级=`G1/F1/B2/C4/G1`，formal ledger=`2315 judgments`，COVERAGE=`848 rows / 456 judged / 0 tombstones`，anchors=`10/10`，alarms=`clean`。告警按原阈值打开后由 SURF-073 独立复审逐条 ack，未改阈值、算法、法典、锚点或 gate。批次四十三=`40/50`，下一前线为 `SURF-074 settings/panel-workspaces`；50 格前不统一门禁、不提交。P12 400+ Journey 按用户裁定推迟二期。

### 历史快照: SURF-072 settings/panel-memory

`SURF-072 settings/panel-memory` 已完成真实 App + managed backend 五级验收。真实覆盖空态/名册、All/Pinned、搜索命中与无匹配、新建 slug 失败与合法值恢复、创建并置顶、编辑锁名、内容保存、未保存面包屑离开保护、删除取消和最终物理删除。首轮发现合法输入残留旧错误、面包屑绕过 dirty guard 两个产品缺陷并停下修复；修复后新 App 重跑通过，`Keep editing` 保留详情、`Discard` 才离开，合法值即时清错。

修复 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-235804`，删除收口 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260820-000144`，录屏=`121.830000s + 84.088333s`；正式证据=`sessions/20260820-000144/evidence/SURF-072-settings-panel-memory-five-level.md`，警报复审=`sessions/20260820-000144/evidence/SURF-072-ledger-alarm-reaudit.md`。修复前红 session=`sessions/20260819-234423` 不计绿。五通道 `rig-check`/`rig-down` 两轮通过；backend=`186/139` 行无应用红线，SSE 捕获 `memory.created`/`memory.deleted`，frontend=`4/3` 行仅正常启动与已知 host noise，llmtap wiring 通过且无伪造 completion，focused Flutter=`68/68`。

五级=`G1/F1/B2/C4/G1`，formal ledger=`2310 judgments`，COVERAGE=`848 rows / 455 judged / 0 tombstones`，anchors=`10/10`，alarms=`clean`。统计告警按原阈值打开后由 SURF-072 独立复核逐条 ack，未改阈值、算法、法典、锚点或 gate。批次四十三=`35/50`，下一前线为 `SURF-073 settings/panel-sandbox`；50 格前不统一门禁、不提交。P12 400+ Journey 按用户裁定推迟二期。

### 历史快照: SURF-071 settings/panel-mcp

`SURF-071 settings/panel-mcp` 已完成真实 App + managed gateway 五级验收。空态市场、102 条 marketplace、真实关键词搜索、计划页、手动 stdio 失败态、SSE/Streamable HTTP 表单切换、Tools/Call history/stderr 三个详情标签、有效 mcp.json 导入、重复导入跳过和 soft-delete 均已逐帧走通；外部 API key 未提交，失败服务器显示具体 sandbox 错误，没有产品级 stop-and-fix 缺陷。

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-232740`，录屏=`564.475000s`；正式证据=`sessions/20260819-232740/evidence/SURF-071-settings-panel-mcp-five-level.md`，警报复审=`sessions/20260819-232740/evidence/SURF-071-ledger-alarm-reaudit.md`。五通道 `rig-check`/`rig-down` 全通过；backend=`660` 行无应用红线，SSE 捕获实体失败与 `mcp.installed`/`mcp.removed` 事实帧，frontend=`5` 行只有已知 macOS IMK host noise，llmtap managed bootstrap 全 `200`，focused Flutter=`47/47`。

五级=`G1/F1/B2/C4/G1`，formal ledger=`2305 judgments`，COVERAGE=`848 rows / 454 judged / 0 tombstones`，anchors=`10/10`，alarms=`clean`。告警按原阈值打开后已由独立 SURF-071 复核逐条 ack，未改阈值、算法、法典、锚点或 gate。批次四十三=`30/50`，下一前线为 `SURF-072 settings/panel-memory`；50 格前不统一长门禁、不提交。P12 400+ Journey 按用户裁定推迟二期。

`SURF-070 core/media-viewer` 已完成真实 App + managed gateway 五级验收。真实图片从生成工具卡进入全尺寸查看器；真实 3 秒视频从海报进入原生播放器，画面、时间轴、暂停、重播、进度定位、共享 live controller 全屏和关闭回归均通过。首轮非洁净会话的 App PID 归属被门禁拒绝后，已用同一数据重启洁净台架并通过五通道 `rig-check`，没有把初始化灰海报误判成失败。focused=`35/35`，正式证据=`sessions/20260819-231808/evidence/SURF-070-core-media-viewer-five-level.md`，警报复审=`testend/rig/formal-evidence/SURF-070-ledger-alarm-reaudit.md`。

五级=`G1/F1/B2/C4/G1`，formal ledger=`2300 judgments`，COVERAGE=`848 rows / 453 judged / 0 tombstones`，anchors=`10/10`，alarms=`clean`。洁净 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-231808`，录屏=`261.528333s`；上一轮 session 保留生成回合的 LLM wire 与 SSE business frames。批次四十三=`25/50`，下一前线为 `SURF-071 settings/panel-mcp`；50 格前不统一长门禁、不提交。P12 400+ Journey 按用户裁定推迟二期。

`SURF-069 settings/panel-models-keys` 已完成真实 App + managed gateway 五级验收。全新 workspace onboarding 后进入 Settings → Models & keys，真实覆盖受管免费档卡、音色库存空态、受管密钥行、六类场景默认模型和 Search keys 空态；六个 Change 入口逐一展开/关闭，quota 与 model list refresh 均经真实后端和网关返回 `200`，最终面板稳定且没有配置漂移。音色卡的 `2 of 2 slots free` 与附件登记引导明确表达库存位不是日配额；没有产品级 stop-and-fix 缺陷。

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-224143`，workspace=`ws_b3a9e6654c009416`，录屏=`518.718333s / 2560x1584 / H.264 / 60fps`。五通道：backend=`593` 行无 WARN/ERROR/panic/FATAL；ssetap=`8` 行，workspace 创建后自动发现并连接三流，设置纯读路径无业务 durable 帧；frontend=`4` 行仅正常启动/VM/已知 macOS host noise；llmtap=`16` 行，managed proof/install/models/quota wire 全部经 tap 且响应 `200`；`rig-check`/`rig-down`、focused=`55/55`、coverage、diff、进程审计通过。关键帧=`sessions/20260819-224143/evidence/SURF-069-models-keys-top.jpeg`、`SURF-069-models-keys-scenarios.jpeg`，正式证据=`sessions/20260819-224143/evidence/SURF-069-settings-panel-models-keys-five-level.md`，警报复审=`testend/rig/formal-evidence/SURF-069-ledger-alarm-reaudit.md`。

五级=`G1/F1/B2/C4/G1`，formal ledger=`2295 judgments`，COVERAGE=`848 rows / 452 judged / 0 tombstones`，anchors=`10/10`，alarms=`clean`。批次四十三=`20/50`，下一前线由 formal sequence gate 决定；50 格前不统一长门禁、不提交。P12 400+ Journey 按用户裁定推迟二期。

### 历史快照: SURF-068 settings/panel-chat

`SURF-068 settings/panel-chat` 已完成真实 App + managed gateway 五级验收。真实验证 Chat 设置的右岛自动登台三档、发送键两档、Web fetch workspace 持久化和默认对话模型跳转行；真实聊天返回 `OK.`，真实 Glob 工具活动在 UI/后台/SSE 中可见，点击 Stop 后 UI、API 和 SSE 一致收为 cancelled。Glob 按产品定义不属于 stage-worthy 集合，因此不自动打开右岛不是缺陷；模型把“当前工作目录”解释为 `~` 导致递归搜索等待约 53 秒，已作为后续工具意图/workdir 引导观察项保留，没有伪装成绿格缺陷。

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-221915`，workspace=`ws_02acc0a8ce4f704e`，录屏=`963.813333s / 2560x1584 / H.264 / 60fps`。五通道：backend=`1063` 行无 WARN/ERROR/panic/FATAL；ssetap=`79` 行且三流真实连接；frontend=`5` 行仅正常启动/VM/已知 macOS host noise；llmtap=`25` 行，managed proof 与 chat wire 经过 tap 且响应 `200`；`rig-check`/`rig-down`、SQLite `web_fetch_mode=local`、focused=`97/97`、coverage、diff、进程审计通过。正式证据=`sessions/20260819-221915/evidence/SURF-068-settings-panel-chat-five-level.md`，警报复审=`testend/rig/formal-evidence/SURF-068-ledger-alarm-reaudit.md`。

五级=`G1/F1/B2/C4/G1`，formal ledger=`2290 judgments`，COVERAGE=`848 rows / 451 judged / 0 tombstones`，anchors=`10/10`，alarms=`clean`。批次四十三=`15/50`，下一前线由 formal sequence gate 决定；50 格前不统一长门禁、不提交。P12 400+ Journey 按用户裁定推迟二期。

### 历史快照: SURF-067 settings/panel-notifications

`SURF-067` 的正式五级证据、三次真实 approval run、通知分类门控和恢复默认结果保留在下方历史记录；当前执行依据已由 SURF-068 整体重述取代。

### 历史快照: SURF-066 settings/panel-general

`SURF-066 settings/panel-general` 已完成真实 App + managed gateway 五级验收。真实验证主题三档、屏幕上限下的缩放六档、字体三轴、语言 UI/工作区双写、记住窗口、开机自启与自动更新；不可容纳的 `1.25×/1.5×` 档真实点击不改变当前 `1.1×`，没有静默假成功。所有偏好最终恢复默认，没有产品级 stop-and-fix 缺陷。

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-214739`，workspace=`ws_60c1fd52053065b7`，录屏=`673.656667s / 2560x1584 / H.264 / 60fps`。五通道：backend=`744` 行无应用红线；ssetap 三流真实连接且本路径无业务耐久帧不虚构；frontend=`4` 行仅正常启动/VM/已知 IMK host warning；llmtap managed proof/install/models 全 `200`，无设置 completion；`rig-check`/`rig-down`、SQLite `language=en`、focused=`38/38 + 12/12`、coverage、diff、进程审计通过。正式证据=`sessions/20260819-214739/evidence/SURF-066-settings-panel-general-five-level.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-066-ledger-alarm-reaudit.md`。

五级=`G1/F1/B2/C4/G1`，formal ledger=`2280 judgments`，COVERAGE=`848 rows / 449 judged / 0 tombstones`，anchors=`10/10`，alarms=`clean`。批次四十三=`5/50`，下一前线为 `SURF-067 settings/panel-notifications`；50 格前不统一长门禁、不提交。P12 400+ Journey 按用户裁定推迟二期。

### 历史快照: SURF-065 settings/rail-search

`SURF-065 settings/rail-search` 已完成真实 App + managed gateway 五级验收。全新工作区真实验证空查询三段目录、`zzzz` 无匹配、真实退格清空恢复、`zoom` 跨面板结果、面板头跳转、具体项滚动定位与等高蓝色洗亮；所有输入均为真实键盘事件，没有产品级 stop-and-fix 缺陷。

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-212554`，workspace=`ws_53a147068c051721`，录屏=`127.786667s / 2560x1584 / H.264 / 60fps`。五通道：backend=`176` 行无应用红线；ssetap 三流连接且本路径无聊天/实体业务耐久帧不虚构；frontend=`5` 行仅正常启动/VM/已知 IMK host warning；llmtap managed proof/install/models=`200`，设置搜索路径无 completion；rig-check/rig-down、settings focused=`42/42`、Dart analyze、coverage check、进程审计通过。证据=`sessions/20260819-212554/evidence/SURF-065-settings-rail-search-five-level.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-065-ledger-alarm-reaudit.md`。

五级=`G1/F1/B2/C4/G1`，formal ledger=`2275 judgments`，COVERAGE=`848 rows / 448 judged / 0 tombstones`，anchors=`10/10`，alarms=`clean`。批次四十二=`50/50`；统一长门禁已通过：rig Python=`42/42`、`make verify` 四门全绿、`make -C backend testend` 全量黑盒=`283.748s`、gofmt/diff/process-listener audit 全绿。下一前线为 `SURF-066 settings/panel-general`，本批工作树审计后提交。P12 400+ Journey 按用户裁定推迟二期。

`SURF-064 settings/rail-system` 已完成真实 App + managed gateway 五级验收。System 段真实打开 Storage & logs、Advanced limits、Network、Shortcuts、About：sidecar 数据目录/磁盘真相、schema limits、proxy restart 提示、六个快捷键、About 更新错误与 `Copied` 回执均通过；没有执行不可逆 factory reset，也没有产品级 stop-and-fix 缺陷。

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-212039`，workspace=`ws_b34dfc17c20ccd09`，录屏=`116.973333s / 2560x1584 / H.264 / 60fps`。五通道：backend=`171` 行无应用红线；ssetap 三流连接且本路径无聊天/实体业务耐久帧不虚构；frontend=`4` 行仅正常启动/VM/已知 IMK host warning；llmtap managed proof/install/models=`200`，系统设置路径无 completion；rig-check/rig-down、系统 focused suite=`26/26`、Dart analyze、coverage check、进程审计通过。证据=`sessions/20260819-212039/evidence/SURF-064-settings-rail-system-five-level.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-064-ledger-alarm-reaudit.md`。

五级=`G1/F1/B2/C4/G1`，formal ledger=`2270 judgments`，COVERAGE=`848 rows / 447 judged / 0 tombstones`，anchors=`10/10`，alarms=`clean`。批次四十二=`45/50`，未满 50 格不跑统一长门禁、不提交；下一前线为 `SURF-065 settings/rail-search`。P12 400+ Journey 按用户裁定推迟二期。

`SURF-063 settings/rail-resources` 已完成真实 App + managed gateway 五级验收。Resources 段真实打开 Models & keys、MCP servers、Memory、Sandbox、Workspaces：managed free-tier / scenario defaults / empty voices、MCP loading→`0-100 of 102` marketplace、Memory/Sandbox 诚实空态、当前 workspace/Current 均通过；没有产品级 stop-and-fix 缺陷。

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-211359`，workspace=`ws_627041276bc74cad`，录屏=`133.883333s / 2560x1584 / H.264 / 60fps`。五通道：backend=`196` 行无应用红线；ssetap 三流连接且本路径无聊天/实体业务耐久帧不虚构；frontend=`4` 行仅正常启动/VM/已知 IMK host warning；llmtap managed proof/install/models=`200`，资源路径无 completion；rig-check/rig-down、资源 focused suite=`77/77`、Dart analyze、coverage check、进程审计通过。证据=`sessions/20260819-211359/evidence/SURF-063-settings-rail-resources-five-level.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-063-ledger-alarm-reaudit.md`。

五级=`G1/F1/B2/C4/G1`，formal ledger=`2265 judgments`，COVERAGE=`848 rows / 446 judged / 0 tombstones`，anchors=`10/10`，alarms=`clean`。批次四十二=`40/50`，未满 50 格不跑统一长门禁、不提交；下一前线为 `SURF-064 settings/rail-system`。P12 400+ Journey 按用户裁定推迟二期。

`SURF-062 settings/rail-prefs` 已完成真实 App + managed gateway 五级验收。全新工作区 onboarding 后进入 Settings，左岛真实展示 `Preferences` 下的 `General`、`Notifications`、`Chat` 三面板；真实键盘输入 `theme` 与 `login` 分别完成设置项结果、跨面板定位、搜索清空、浮层头带下滚动和一次性洗亮。`Launch at login` 真实 off→on→off，AX/画面回读一致且默认恢复动作正确；没有产品级 stop-and-fix 缺陷。

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-210545`，workspace=`ws_54a9a9eaa18dc054`，录屏=`257.628333s / 2560x1584 / H.264 / 60fps`。五通道：backend=`297` 行无应用红线；ssetap 三流连接且本路径无业务耐久帧不虚构；frontend=`5` 行仅正常启动/VM/已知 IMK host warning；llmtap managed proof/install/models=`200`，设置路径无 completion；rig-check/rig-down、设置 focused suite=`42/42`、Dart analyze、coverage check、进程审计通过。证据=`sessions/20260819-210545/evidence/SURF-062-settings-rail-prefs-five-level.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-062-ledger-alarm-reaudit.md`。

五级=`G1/F1/B2/C4/G1`，formal ledger=`2260 judgments`，COVERAGE=`848 rows / 445 judged / 0 tombstones`，anchors=`10/10`，alarms=`clean`。批次四十二=`35/50`，未满 50 格不跑统一长门禁、不提交；下一前线为 `SURF-063 settings/rail-resources`。P12 400+ Journey 按用户裁定推迟二期。

`SURF-061 scheduler/run-inspector-node` 已完成真实 App + managed gateway 五级验收。真实 loop workflow 让 `work` 节点产生 3 个 durable iterations；旗舰节点表显示 `work ×3`、`route ×3`、`7 nodes · Completed 7`。选中 `work` 后右岛检查器提供 `#0/#1/#2` 迭代切换，输出 `index=0/1/2` 与 execution log 坐标随轮次变化；真实失败节点同时显示全文 traceback、无结果诚实态、执行日志和 `Replay the failed nodes`。没有产品级 stop-and-fix 缺陷。

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-205412`，workspace=`ws_7a9b6f127158cb3c`，run=`fr_2d4323570cff2460`，录屏=`333.648333s / 2560x1584 / H.264 / 60fps`。五通道：backend=`578` 行无应用红线；ssetap entities durable=`7..58`、notifications durable=`16..57` 单调，目标 run 每轮 ephemeral node frame 与 terminal close 均有；frontend=`4` 行仅正常启动/VM/已知 IMK host warning；llmtap proof/install/models 全 `200`，无伪造 completion；SQLite 7 行节点、UI、REST/SSE 对账一致，收台无残留进程。构造阶段的整数 CEL fixture 错误保留且在公开 control edit 后修正，不计产品 defect。证据=`sessions/20260819-205412/evidence/SURF-061-run-inspector-node-five-level.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-061-ledger-alarm-reaudit.md`。

五级=`G1/F1/B2/C4/G1`，formal ledger=`2255 judgments`，COVERAGE=`848 rows / 444 judged / 0 tombstones`，anchors=`10/10`，alarms=`clean`。批次四十二=`30/50`，未满 50 格不跑统一长门禁、不提交；下一前线为 `SURF-062 settings/rail-prefs`。P12 400+ Journey 按用户裁定推迟二期。

`SURF-060 scheduler/run-inspector-dossier` 已完成 stop-and-fix 后的真实 App + managed gateway 五级验收。红跑发现失败运行右岛 dossier 缺少入口 payload；后端证实入口数据持久化在 trigger 节点 result。修复后 dossier 在 Error 前增加 `Entry payload` JSON 区段，真实显示 `body.index=5`、`body.mode=fail`，并补 focused Flutter regression 与 Scheduler 文档。

绿 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-204650`，红 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-204243`，workspace=`ws_0204dbcd6673da77`，录屏=`206.026667s / 2560x1584 / H.264 / 60fps`。真实 App 从 Scheduler → Inactive → `surf052_failed` → failed run → `Open` 进入 dossier，同时展示状态、pinned version、replay history、Entry payload、Error 全文、Pinned refs 和 AI triage；点击 AI triage 后真实受管网关 Chat 完成，回答准确还原 payload → function → RuntimeError → failed 的因果链。绿证据=`sessions/20260819-204650/evidence/SURF-060-run-inspector-dossier-five-level.md`，红帧=`sessions/20260819-204243/evidence/SURF-060-red-dossier-missing-payload.png`。

五通道封口：录屏已正常收束；backend=`366` 行无应用红线；ssetap=`270` 行，messages durable=`1..22`、notifications durable=`1..12` 单调；frontend=`3` 行仅正常 Dart VM service；llmtap challenge 与三次 chat completion 均 `200`，body 已封存；rig-check 报告 five channels physically observing，收台后无残留进程。focused `scheduler_run_test.dart`=`39/39`、analyze、rig-check/rig-down、ffprobe/process leak audit 通过。

五级=`G1/F1/B2/C4/G1`，formal ledger=`2250 judgments`，COVERAGE=`848 rows / 443 judged / 0 tombstones`，anchors=`10/10`，alarms=`clean`。警报独立复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-060-ledger-alarm-reaudit.md`。批次四十二=`25/50`，未满 50 格不跑统一长门禁、不提交；下一前线为 `SURF-061`。P12 400+ Journey 按用户裁定推迟二期。

`SURF-059 scheduler/rail-inactive` 已完成 stop-and-fix 后的真实 App + managed gateway 五级验收。红跑真实停用带失败历史的 workflow 后，Inactive 展开行错误显示红色 live dot；修复后 inactive 行只保留历史时间，不占当前状态点位，并补 model regression 与 Scheduler 文档。绿跑 Computer Use 展开 `Inactive 2` 看到 `surf052_failed 5m ago`、`surf052_inactive —` 且无红点；Display options 隐藏/恢复停用区也通过。

绿 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-203404`，红 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-203033`，workspace=`ws_64f76fe1fdf9aa85`，录屏=`209.260000s / 2560x1584 / H.264 / 60fps`。五通道封口：backend=`324` 行无应用红线；ssetap 三流真实连接并记录 settle lifecycle；frontend=`3` 行仅 VM 启动；llmtap ready 且确定性路径无 completion；rig-down 后无进程残留。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-203404/evidence/SURF-059-rail-inactive-five-level.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-059-ledger-alarm-reaudit.md`。

五级=`G1/F1/B2/C4/G1`，formal ledger=`2245 judgments`，COVERAGE=`848 rows / 442 judged / 0 tombstones`，anchors=`10/10`，alarms=`clean`；focused provider=`13/13`、model=`15/15`、Dart analyze、rig-check/rig-down/ffprobe/process leak audit 通过。批次四十二=`20/50`，未满 50 格不跑统一长门禁、不提交；下一前线为 `SURF-060 scheduler/run-inspector-dossier`。P12 400+ Journey 继续按用户裁定推迟二期。

`SURF-058 scheduler/rail-never-ran` 已完成真实 App + managed gateway 的五级验收。全新工作区首屏在 Scheduler rail 显示 `Never ran 1` 且子项初始折叠；展开后只出现唯一真实 `surf052_never_ran`，随后启动真实 completed run `fr_da9efc70f9a08841`，durable refresh 将该行提升到无头主段并按活动排序，`Never ran` 段消失，`Inactive 1` 保持独立。初始/展开/迁移帧与同 session 五通道证据已封存。

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-201947`，workspace=`ws_625a6279a8161d46`，录屏=`346.326667s / 2560x1584 / H.264 / 60fps`。backend=`572` 行无应用红线；ssetap 三流连接，entities durable=`1..44`、notifications=`1..33` 单调；frontend 无 Flutter/Dart/RenderFlex/RenderBox/assertion/Unhandled/Exception 红线，仅已知 IMK host 噪声；llmtap managed challenge/install/models 全 `200`，确定性路径不伪造 completion。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-201947/evidence/SURF-058-rail-never-ran-five-level.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-058-ledger-alarm-reaudit.md`。

五级=`G1/F1/B2/C4/G1`，formal ledger=`2240 judgments`，COVERAGE=`848 rows / 441 judged / 0 tombstones`，anchors=`10/10`，alarms=`clean`。focused Scheduler provider=`13/13`、model=`14/14`，rig-check/rig-down/ffprobe/process leak audit 通过；批次四十二=`15/50`，未满 50 格不跑统一长门禁、不提交。P12 400+ Journey 按用户裁定推迟二期。

`SURF-057 scheduler/rail-main` 已完成 stop-and-fix 后的正式五级验收。首轮真实 App 通过真实 `:pause` 后 REST/SSE 已确认 trigger 无 `nextFireAt`，rail 却残留 `in 3h`；修复 `SchedulerRailController` 只监听 `entities/trigger` 的 `status` signal，保留 activation/firing telemetry 不重取的边界，并补正负 provider regression。重建 App 后暂停态回落上次运行，resume 回到 `in 3h`，真实 completed run 后 Recent activity 顺序稳定，Show next fire 开关可落到 last-run 并恢复，Name/Recent activity 镜头可切换，Never ran/Inactive 始终沉底。

红 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-200109`，绿 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-200757`，workspace=`ws_751c44f801a46d07`，绿录屏=`200.778333s / 2560x1584 / H.264 / 60fps`。五通道：绿 backend 无应用红线，ssetap 三流连接并观察 trigger status/run/approval/settle，frontend 无 Flutter/Dart/RenderFlex/RenderBox/assertion/Unhandled/Exception 红线，llmtap journal 非空且无伪造 completion；红 stale 帧与修复证据均保留。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-200757/evidence/SURF-057-rail-main-five-level.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-057-ledger-alarm-reaudit.md`。

五级=`G1/F1/B2/C4/G1`，formal ledger=`2235 judgments`，COVERAGE=`848 rows / 440 judged / 0 tombstones`，anchors=`10/10`，alarms=`clean`。focused Scheduler provider=`13/13`、model=`14/14`，docs verify、rig `42/42`、ffprobe/process leak audit 通过；批次四十二=`10/50`，未满 50 格不跑统一长门禁、不提交。P12 400+ Journey 按用户裁定推迟二期。

`SURF-056 scheduler/rail-overview-row` 已完成正式五级验收。真实 App 在 Scheduler rail 验证无数据时固定首行 Overview；构造真实 parked approval 后，Overview 琥珀等待点与右缘 `1`、中心 `Waiting 1`、右上审批卡和 Waiting on you 同时出现。点击 Approve 后 durable refetch 收敛为无等待徽标与 `Waiting 0`；选中工作流再返回 Overview，中心与选中态均无 stale detail；第二次 parked run 重新把计数拉回 1。真实数据来自同一 flowrun inbox，不是 fixture 文本投影。

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-194527`，workspace=`ws_83b4627329714f23`，录屏=`593.678333s / 2560x1584 / H.264 / 60fps`。五通道：backend `705` 行无应用红线，ssetap `113` 行连接 notifications/entities/messages 三流并观察 approval pending 与 durable run signals，frontend 只有已知 macOS IMK host 噪声，llmtap managed challenge/install/models 全 `200`；证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-194527/evidence/SURF-056-overview-five-level.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-056-ledger-alarm-reaudit.md`。

五级=`G1/F1/B2/C4/G1`，formal ledger=`2230 judgments`，COVERAGE=`848 rows / 439 judged / 0 tombstones`，anchors=`10/10`，alarms=`clean`。focused Scheduler=`57/57`，rig-check/rig-down/ffprobe/process leak audit 通过；批次四十二=`5/50`，未满 50 格不跑统一长门禁、不提交。P12 400+ Journey 继续按用户裁定推迟二期。

`SURF-055 scheduler/run-relay` 已完成正式五级验收。真实 App 从 Scheduler workflow home 的 run terminal 点击生产 `Open run page →`，实际穿过 `/scheduler/runs/:frId` id-only relay，并交棒 `/scheduler/w/{workflowId}/runs/{flowrunId}` 旗舰；终帧显示 `Done`、pinned version、2 nodes completed、Timeline、Run dossier 和 pinned refs。故意 dead-id 负路径返回 `FLOWRUN_NOT_FOUND`，不是空白页；Computer Use rail 搜索 Return 的驱动限制已记录为仪器边界，不计产品绿。

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-191759`，primary run=`fr_4cc81cf274f208f2`，录屏=`262.258333s / 2560x1584 / H.264 / 60fps`。五通道证据：backend 最终 `408` 行无未解释应用红线，REST 与 UI 对账；ssetap `15` 行，目标 flowrun durable `1→2→3→4`，`seq=0` delta 不推进游标；frontend 无 Flutter/Dart/RenderFlex/RenderBox/Unhandled/Exception/assertion 红线，仅已知 macOS IMK host 噪声；llmtap readiness/managed proof wiring 通过，确定性路径无 completion 不伪造。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-191759/evidence/SURF-055-run-relay-five-channel.md`。

五级=`G1/F1/B2/C4/G1`，formal ledger=`2225 judgments`，COVERAGE=`848 rows / 438 judged / 0 tombstones`，anchors=`10/10`，alarms=`clean`。统一长门禁已通过：rig=`42/42`、focused Scheduler=`80/80`、`make verify`、全量 `make -C backend testend`、shell/py_compile/diff/process leak audits 均通过。批次四十一已 `50/50`，记录与批次提交完成后继续按 formal sequence gate 推进；P12 400+ Journey 按用户裁定推迟二期。

`SURF-054 scheduler/run-flagship` 已完成正式五级验收。首轮真实画面发现五节点横向钉版图在右岛打开时不可读，第二轮确认旧 Flutter bundle 复用；两轮均保留，stop-and-fix 增加只读 `reflowPinned`，第三轮新构建 App 用纵向展示同一钉版图，完整图、节点标签和连线均可读。

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-185802`，workspace=`ws_c170fe14c137fee5`，workflow=`wf_40a2b65d4d430fbc`，completed=`fr_f66380fb2e86dc6d`，failed comparison=`fr_f464c9dc989c810c`。真实 App 完成 Scheduler workflow→run URL、卷宗头、图/甘特/台账和跨入口单选；REST/SQLite 5 节点 completed 与 activity `206/150/149/150ms` 对账，failed comparison 的 `stage_validate` 失败由 backend/SSE 同时观察。

五通道封口：录屏 `231.118333s`，backend 无应用红线，ssetap `47` 行，frontend 无 Flutter/Dart/overflow/assertion 红线（已知 macOS IMK host 噪声原样保留），llmtap managed challenge/install/models 全 `200`；focused Flutter=`74/74`，anchors=`10/10`，formal ledger=`2220 judgments`，COVERAGE=`848 rows / 437 judged / 0 tombstones`，alarms clean。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-185802/evidence/SURF-054-run-flagship-green.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-054-ledger-alarm-reaudit.md`。批次四十一=`49/50`，未满 50 格不跑统一长门禁、不提交；下一前线由 formal sequence gate 决定。P12 的 400+ Journey 继续按用户裁定推迟二期。

`SURF-053 scheduler/workflow-home` 已完成真实 App + managed gateway + Computer Use 的多入口 Run now 旅程。首轮 `invalid or ambiguous trigger entry node` 红路径已保留并 stop-and-fix：后端与前端贯通 `entryNode`，真实 Webhook 入口 run 完成，五通道证据与遮挡门均通过；目标 flowrun=`fr_c851c8fc46870084`，正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-182815/evidence/SURF-053-scheduler-workflow-home-five-channel.md`。

当前正式 ledger=`2220 judgments`，COVERAGE=`848 rows / 437 judged / 0 tombstones`，anchors=`10/10`，`alarms.py check`=`clean`；批次四十一=`49/50`，未满 50 格不跑统一长门禁、不提交，下一前线由 formal sequence gate 决定。P12 的 400+ Journey 按用户裁定推迟二期。

`SURF-038 entities/rail-control` 已完成真实 App + managed gateway 的 Control rail、详情与版本路径；五格=`G1/F1/B2/C4/G1`，证据与警报复审均已封存，最终 `alarms.py check`=`clean (2140 judgments)`。

`SURF-039 entities/rail-approval` 已完成 stop-and-fix：首轮红 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-022010` 发现搜索 `refund` 后 rail 与中心详情错位；修复 `entity_rail.dart` 的选择一致性并新增 route-backed widget regression。绿色 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-022641` 逐帧覆盖 Approval 三种规则形态、搜索排除与清空、空结果、详情、Versions、折叠/展开和稳定终帧。五通道：录屏 `214.663333s / 2560x1584 / H.264 / 60fps`，backend `369` 行无应用红线，frontend 无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception，ssetap 三流连接且 durable `16..18` 无 gap，llmtap managed proof/install/models 全 `200`，SQLite integrity=`ok`；正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-022641/evidence/SURF-039-entities-rail-approval-five-channel-green.md`，五格=`G1/F1/B2/C4/G1`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-039-ledger-alarm-reaudit.md`，最终 `alarms.py check`=`clean (2145 judgments)`。

`SURF-040 entities/rail-trigger` 已在全新数据目录 `/private/tmp/anselm-data-surf040-20260819-r1`、workspace=`ws_fbb258b6f3edf39a`、正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-024530` 完成。真实 App + Computer Use 覆盖 cron/webhook/fsnotify/sensor 四种 Trigger：hot cron 的蓝点、Listening、Fire CTA 与 active workflow，cold webhook/sensor 的 Idle，paused fsnotify 的 Paused 与禁用 Fire，四类配置/payload、Overview、搜索 `hot`/`cold`/`zzzz`、清空及最终稳定帧。真实 Fire 产生 activation=`tra_bc6fe650e5ee155e`、dispatch 和 flowrun=`fr_db91b4fc0799d77a`；UI 显示 `run started`，REST/SQLite 对账到最终 `completed`，语义无误。无 stop-and-fix defect。

五通道：`screen.mov`=`286.338333s / 2560x1584 / H.264 / 60fps`，最终帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-024530/final-frame.png`；backend/frontend journal 均无应用红线；ssetap 三流真实连接，notifications durable=`16..24`、entities durable=`7,8,9,10` 严格有序并含 `run_started→run_terminal(completed)`，messages 本路径没有 chat turn 故无 durable frame；llmtap managed proof/install/models 全 `200`，无伪造 completion；SQLite integrity=`ok` 且 Trigger/Workflow/Activation/Firing/Flowrun 与 UI 对账。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-024530/evidence/SURF-040-entities-rail-trigger-five-channel-green.md`；警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-040-ledger-alarm-reaudit.md`，并记录并行 ack 重写被 gate 发现后改为串行 ack，最终 `alarms.py check`=`clean (2150 judgments)`。

`SURF-041 entities/run-terminal` 已在全新数据目录 `/private/tmp/anselm-data-surf041-20260819-r1`、workspace=`ws_61fa03f0cc98ae73`、正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-031703` 完成。首轮真实 App 发现 Handler Code 卡漏掉 `label` 参数；stop-and-fix 更新 `frontend/lib/features/entities/data/entity_format.dart`，新增 formatter regression，修复后二进制显示 `def inspect(self, label):`。随后用真实鼠标键入 `ui-correct` 完成 Handler Call，真实受管 gateway Agent Invoke 完成，Workflow 用 Webhook `body.label/count` 触发 v4，最终 flowrun=`fr_d521c9d0e7525126` 在 Scheduler dossier 显示 pinned/completed；旧错误 fixture 的失败历史保留。

五通道：录屏=`665.585000s / 2560x1584 / H.264 / 60fps`；backend/frontend 无未解释应用红线；ssetap 三流真实连接，entities durable=`1..12`、notifications durable=`1`、messages 本路径无 durable chat frame，ephemeral seq=`0` 未推进游标；llmtap 有受管 gateway 与真实 Agent wire，未把无模型的 Function/Handler/Workflow 路径虚构成 completion；SQLite integrity=`ok`，API/SQLite/SSE/UI 对账一致。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-031703/evidence/SURF-041-entities-run-terminal-five-channel.md`；警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-041-ledger-alarm-reaudit.md`，两条统计警报串行 ack 后 `alarms.py check`=`clean (2155 judgments)`。

`SURF-042 entities/workflow-editor-inspector` 已在重新构建的真实 App、managed gateway、Computer Use 和五通道台架上完成正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-040751`，workspace=`ws_2998f557f8cc1e2b`，workflow=`wf_9d05754c871a12c5`。逐帧覆盖 graph editor 空 inspector、Action 的 Function/Handler/MCP 引用族、Handler target/method、input mapping、Retry、Max attempts、Save/Discard、右岛关闭/重开与 8 节点/8 边画布。MCP 无 server 的空白浮层被 stop-and-fix 为明确 `No MCP servers configured yet` 空态；共享 `AnDropdown` 现在对无选项面不可打开或显示不可选解释行，NodeRefPicker 的 MCP/Handler/通用空态均双语化，组件与 picker regression 已通过。

真实键盘输入 Max attempts=`5` 后画面出现 `Unsaved changes`，按用户已确认的 Save 动作后显示 `New version saved`。REST active version=`wfv_76f014eeabf70d23`/v3，`functionAction.retry.maxAttempts=5`，capability-check 结构与引用均 resolved；backend 真实 `:edit 200`，ssetap 三流连接并收到 notifications durable `workflow.edited` version 3，frontend/backend 红线为空，llmtap 仅记录 ready、不虚构本路径 LLM completion。录屏=`236.961667s / 2560x1584 / H.264 / 60fps`，证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-040751/evidence/SURF-042-entities-workflow-editor-inspector-five-channel.md`，关键帧为同目录 `SURF-042-mcp-empty-state.jpeg` 与 `SURF-042-retry-saved.jpeg`；五格=`G1/F1/B2/C4/E4`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-042-ledger-alarm-reaudit.md`，最终 `alarms.py check`=`clean (2160 judgments)`。

`SURF-043 entities/graph-entity-card` 已在全新数据目录 `/private/tmp/anselm-data-surf043-20260819-r1`、workspace=`ws_ebf2131f32f3925d`、正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-042026` 完成。真实 fixture 通过公共 API 创建带描述/v1 的 Function，并由 Agent 与 deactivated Workflow 真实引用；关系图返回 8 节点/5 边，Function 有两条 incoming `equip` 边。Computer Use 逐帧覆盖 Overview graph preview → full graph explore → Function 右岛实体卡：kind 字形、名称、`v1`、描述、`REFERENCED BY` 两个 hydrated relation pills 和 `Open in detail` 均可见；点击 Workflow pill 后卡片正确切换为 Workflow 的 `EQUIPS` 组，再回到 Function 并打开真实 Function detail，名称/版本/描述/code/interface/env ready 与卡片一致。无 stale inspector、空白卡、白闪、裁切、重排或未解释跳变，无 stop-and-fix defect。

五通道：录屏=`167.395000s / 2560x1584 / H.264 / 60fps`；backend 无应用 WARN/ERROR/panic/fatal，REST relgraph/Function detail/workflow capability-check 与 UI 对账，`structurallyValid=true,resolved=true`；ssetap 三流真实连接，notifications durable=`16..21`，entities durable=`7,8` 且中间 delta=`seq=0`，messages 本路径无 chat turn 故无 durable frame；frontend 无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 红线；llmtap managed proof/install/models 全 `200`，deterministic read path 无 completion 不虚构。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-042026/evidence/SURF-043-entities-graph-entity-card-five-channel.md`，五格=`G1/F1/B2/C4/G1`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-043-ledger-alarm-reaudit.md`；anchors=`10/10` 重校，最终 `alarms.py check`=`clean (2165 judgments)`。

`SURF-044 library/draft` 在正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-043243` 完成。真实 App 无选区进入 Library 后显示 `Untitled`、`Add a description…`、`Add a tag`、`Start writing` 四个空态引导；点击正文只聚焦不 POST。真实键入正文只创建一次 `doc_ba3237feabbeeb4b`，先 adopt 再导航，树刷新后左 rail 唯一选中，右岛与 REST/SQLite 显示 `17 chars / 19 B /Untitled`；追加 `!` 后正文仍在同一编辑器末尾，右岛更新 `18 chars / 20 B`。五通道录屏=`378.571667s / 2560x1584 / H.264 / 60fps`，backend/frontend 红线为空，notifications durable=`16..17`，messages/entities 无本路径 durable frame，llmtap proof/install/models 六个状态全 `200`，SQLite integrity=`ok`；正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-043243/evidence/SURF-044-library-draft-five-channel.md`，五格=`G1/F1/B2/C4/G1`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-044-ledger-alarm-reaudit.md`，anchors=`10/10`，最终 `alarms.py check`=`clean (2170 judgments)`。

`SURF-045 library/document` 在全新数据目录 `/private/tmp/anselm-data-surf045-20260819-r2`、workspace=`ws_be21c75959fb9fd0`、正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-045509` 完成。真实 App + managed gateway + Computer Use 逐帧覆盖 Library 长文档头部/正文/Outline 同滚页、Outline 跳转、连续滚动到底和末尾边界。首轮点击 `5. Review` 后标题落入固定 shell scrim，判为产品级遮挡缺陷；stop-and-fix 修改 `an_document_editor.dart`，跳转现在扣除固定 head band 与呼吸间距，并由 `library_test.dart` 锁定。focused Flutter=`56/56`；重建 App 后标题完整落在 scrim 下方，active outline 在继续滚动后正确跟随，底部无白缝或异常跳变。

五通道：`screen.mov`=`102.518333s / 2560x1584 / H.264 / 60fps`；backend/frontend 红线为空，REST/SQLite 文档字段对账且 `PRAGMA integrity_check=ok`；ssetap 三流真实连接，notifications durable=`16` 对应 `document.created`，messages/entities 本路径无对应 durable frame；llmtap managed proof/install/models 全 `200`，本路径无 completion 不虚构；正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-045509/evidence/SURF-045-library-document-five-channel.md`，测量帧和原始 Computer Use 帧均保留。五格=`G1/F1/B2/C4/G1`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-045-ledger-alarm-reaudit.md`，anchors=`10/10`，最终 `alarms.py check`=`clean (2175 judgments)`。

`SURF-053` 加入五格绿；EP-230–EP-251、EP-220 及既有绿色项保持五格绿；EP-252–EP-257 debug-only 五格为 L1–L3 绿、L4/L5 按边界记 `na`。当前正式 ledger=`2215 judgments`，COVERAGE=`848 rows / 436 judged rows / 0 tombstones`，anchors=`10/10`，alarms=`clean`；批次四十一为 `48/50`，未满 50 格不跑统一长门禁、不提交。下一原子前线为 `SURF-054`，继续按覆盖矩阵推进，不以 Journey 数量替代覆盖真相源；P12 的 400+ Journey 按用户裁定推迟二期。

`SURF-050 library/inspector-doc` 已完成正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-064339`，隔离数据=`/private/tmp/anselm-data-surf050-20260819-r1`、workspace=`ws_79a21da22bcaa327`。真实 App + managed gateway + Computer Use 覆盖文档 inspector 身份头、glance、Outline/Properties/Backlinks 三折叠组、Expand all/Collapse all、组级折叠、backlink 跳转、关闭/重开和稳定终帧；fixture `seed_surf050.py` 构造目标文档、三层标题与两个 backlink，REST/SQLite/UI 逐字段一致，无 stop-and-fix defect。

五通道：录屏=`291.300000s`；backend=`391` 行无应用红线，SQLite integrity=`ok`；ssetap 三流真实连接，notifications durable=`1..3` 严格递增，本路径无 chat/entity durable frame 不虚构；frontend journal 仅正常启动，无 Flutter/Dart/RenderFlex/RenderBox/Unhandled/Exception/AX 红线；llmtap managed proof/install/models 全 `200`，无 completion 伪声明。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-064339/evidence/SURF-050-library-inspector-doc-five-channel.md`，关键帧在同 session `evidence/`，focused Library/skill-preview=`62/62`，rig-check/rig-down/fixture compile/ffprobe 通过。五格=`G1/F1/B2/C4/G1`，formal ledger=`2195→2200 judgments`，COVERAGE=`848 rows / 432→433 judged rows / 0 tombstones`，anchors=`10/10`；警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-050-ledger-alarm-reaudit.md`，最终 `alarms.py check`=`clean (2200 judgments)`。批次四十一由 `44→45/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-051`。P12 的 400+ Journey 按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-051 library/inspector-skill` 已完成正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-071515`，隔离数据=`/private/tmp/anselm-data-surf051-20260819-r1`、workspace=`ws_2c7c72b9a7052756`。真实 App + managed gateway + Computer Use 逐帧覆盖 skill inspector 文件树/绑定、Properties、allowed-tools picker、Arguments、调用开关、Provenance、Outline、More actions、manifest 编辑后的用户确认 `Save` 和稳定终帧；最终显示 `4 files · 2 bindings` 与 `Pre-approval active`。

首轮上游更新使用保留 `.anselm-install.json` 的非法候选，暴露旧后端先擦除 installed skill 再失败的 destructive-update 缺陷；该红路径保留、不计绿。stop-and-fix 在 `backend/internal/app/skill/install.go` 的 destructive land 前增加保留 sidecar 校验，新增 `TestUpdateInstalled_InvalidSourcePreservesInstallation`；前端 `library_inspector.dart` 透传后端原因并同步双语失败文案。修复后真实 good → invalid → good 更新顺序分别显示成功、`Update failed: invalid skill file path`、成功，绑定/文件/provenance 未被破坏，最后重新批准预授权工具。Go skill package 与 focused Flutter Library/preview=`62/62` 通过。

五通道：录屏=`308.643333s / 2560x1584`，最终帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-071515/evidence/SURF-051-inspector-final.jpeg`；backend=`317` 行无应用红线，REST/SQLite 对账为 `source=installed`、`toolsApproved=true`、4 files、2 equip bindings、integrity=`ok`；ssetap 三流连接，notifications durable=`1,2,3` 严格递增，messages/entities 本确定性 Library 路径无业务 durable frame 不虚构；frontend journal 仅正常启动，无 Flutter/Dart/RenderFlex/RenderBox/Unhandled/Exception；llmtap readiness/managed wiring 经 `rig-check` 指向真实 `https://api.anselm.website`，无 completion 伪声明。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-071515/evidence/SURF-051-library-inspector-five-channel.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-051-ledger-alarm-reaudit.md`。

五格=`G1/F1/B2/C4/G1`；formal ledger=`2200→2205 judgments`，COVERAGE=`848 rows / 433→434 judged rows / 0 tombstones`，anchors=`10/10`。两条统计警报按红绿 stop-and-fix、同一 sealed session、五通道原始 journal 和未变 anchors 独立复审并串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2205 judgments)`；`gen_coverage.py --check` clean。批次四十一由 `45→46/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-052`。P12 的 400+ Journey 按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-052 scheduler/overview` 已完成正式五级收口。正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-074544`，数据目录=`/private/tmp/anselm-data-surf052-20260819-r2`，workspace=`ws_373809e601b29e62`；真实 App + managed gateway + Computer Use 覆盖 Scheduler KPI/时间线、六类 workflow lane、approval、failed peek 的 Graph/Open/full detail/return、空 workspace 首用教育卡和回切 populated workspace。首轮红 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-073545` 暴露用户错误卡泄露 `/private/tmp/.../main.py` 的产品/隐私缺陷；stop-and-fix 完成四个 scheduler display projection 的路径脱敏，focused Flutter=`43/43`，绿色复跑只显示 `File "main.py"`，原始 journal/API 保留完整 traceback。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-074544/evidence/SURF-052-scheduler-overview-five-channel.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-052-ledger-alarm-reaudit.md`。

五通道封口：录屏=`516.450000s / 2560x1584 / H.264 / 60fps`；backend=`602` 行无应用红线且 settle 后无 running flowrun；ssetap 三流真实连接，populated workspace entities durable=`1,2,3` 严格有序，ephemeral=`seq=0`，无 gap；frontend journal 仅正常启动；llmtap managed proof/install/models 全 `200`，本确定性路径无 completion 不虚构；REST/SQLite/UI 对账一致。五格=`G1/F1/B2/C4/G1`，formal ledger=`2205→2210 judgments`，COVERAGE=`848 rows / 434→435 judged rows / 0 tombstones`，anchors=`10/10`，最终 `alarms.py check`=`clean (2210 judgments)`，`gen_coverage.py --check` clean。批次四十一由 `46→47/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-053`。P12 的 400+ Journey 按用户裁定推迟二期。

`SURF-046 library/skill-manifest` 已在全新数据目录 `/private/tmp/anselm-data-surf046-20260819-r2`、workspace=`ws_19d5f0d92fc7d646`、正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-051820` 完成。真实 App + managed gateway + Computer Use 覆盖 manifest raw source 编辑、用户确认后的 Save、保存后 source 预览和 rich view/Outline 回读。首轮发现真实缺陷：后端 `PUT /api/v1/skills/surf046-manifest/files/SKILL.md` 已成功但 mounted preview 仍读旧 `skillFileTextProvider` 缓存；stop-and-fix 在 durable write 后 invalidate 当前文件文本 provider，并以 `library_test.dart` 锁定。修复后二进制真实复跑显示 raw source=`33` 行、新 `Evidence note` 和 rich view Outline=`5` 项；focused suite=`58/58`。

五通道封口：录屏=`254.645000s`，原始 Computer Use 帧与正式证据均保留在 session；backend PUT=`204`、后续 GET=`200`、SQLite `integrity_check=ok`，文件系统和 REST 与 UI 对账；ssetap 三流独立连接，最终 notifications durable=`seq=19 skill.updated/SKILL.md`，本路径无聊天/实体业务 frame 不虚构；frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception 红线；llmtap managed proof/install/models 全 `200`，无本路径 completion 不虚构。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-051820/evidence/SURF-046-library-skill-manifest-five-channel.md`。

五格=`G1/F1/B2/C4/G1`；formal ledger=`2175→2180 judgments`，COVERAGE=`848 rows / 428→429 judged rows / 0 tombstones`，anchors=`10/10`。警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-046-ledger-alarm-reaudit.md`，两条统计警报按原阈值独立复审并串行 ack，最终 `alarms.py check`=`clean (2180 judgments)`；未改阈值、算法、法典、锚点或 gate。批次四十一由 `40→41/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-047`。P12 的 400+ Journey 按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-047 library/skill-file-preview` 已在全新数据目录 `/private/tmp/anselm-data-surf047-20260819-r2`、workspace=`ws_34aee3e308220323`、正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-053819` 完成。fixture `testend/rig/seed_surf047.py` 经公共 API 幂等构造 8 个文件；真实 App + managed gateway + Computer Use 逐帧覆盖 Markdown 富文本、Python 代码、PNG、SVG、CSV、字体、未知/二进制信息卡，以及 `Open with system` / `Reveal in Finder` 逃生口。

首轮点击真实 PNG 暴露 `AnPage` 纵向滚动体内 `Flexible` 的无界高度 RenderFlex 缺陷，红 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-053242` 和红帧均保留；stop-and-fix 将图片/SVG 预览改为有界媒体框，并在 `skill_tree_preview_test.dart` 锁定回归。绿色 session 重新跑完全部分支，无空白预览、布局红线、路径丢失、source/preview stale 或逃生口异常。

五通道封口：录屏=`304.250000s / 2560x1584 / H.264 / 60fps`，backend=`407` 行且状态仅 `200/201/204`、无应用红线，SQLite `integrity_check=ok`；ssetap 三流连接，notifications durable=`16..23`，messages/entities 本路径无 chat/entity durable frame 不虚构；frontend 无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception，llmtap managed proof/install/models 全 `200` 且无本路径 completion。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-053819/evidence/SURF-047-library-skill-file-preview-five-channel.md`。

五格=`G1/F1/B2/C4/G1`；formal ledger=`2180→2185 judgments`，COVERAGE=`848 rows / 429→430 judged rows / 0 tombstones`，anchors=`10/10`。警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-047-ledger-alarm-reaudit.md`，两条统计警报按原阈值独立复审并串行 ack，最终 `alarms.py check`=`clean (2185 judgments)`；未改阈值、算法、法典、锚点或 gate。批次四十一由 `41→42/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-048`。P12 的 400+ Journey 按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-048 library/rail-documents` 已在全新数据目录 `/private/tmp/anselm-data-surf048-20260819-r2`、workspace=`ws_c876681cc3c2d2dc`、正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-061413` 完成。fixture `testend/rig/seed_surf048.py` 只经公共 API 幂等构造空/已写根页、递归子树、空叶和拖拽目标；真实 App + managed gateway + Computer Use 逐帧覆盖 Documents rail 的 `[+]` 子页创建、确认 `Save`、`Rename`、单页 `Duplicate`、整树 deep duplicate、hover `[⋯]` 菜单、拖拽入树、同级重排、空/已写 icon 和带确认的子树删除。首轮红场只暴露 Computer Use 的全选键盘序列误差，造成输入观测偏差；按真实焦点与 `ctrl+a` + `shift+End` 重做后，green session 与 REST 均收敛为精确 `SURF-048 Created Child`，不计产品红。

五通道：录屏=`452.713333s / 2560x1584 / H.264`，最终帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-061413/evidence/SURF-048-library-rail-documents-final.png`；backend=`584` 行无应用 WARN/ERROR/panic/fatal，SQLite integrity=`ok` 且 foreign-key check 为空；ssetap 三流真实连接，notifications durable=`1..13` 严格递增，messages/entities 本路径无对应业务 mutation 不虚构；frontend 无 Dart/Flutter/RenderFlex/overflow/Unhandled/Exception 红线，134 条精确 AXTree stale-node 已由同 session `evidence/frontend-ax-review.md` 逐场审阅，未知 AX pattern 仍硬失败；llmtap managed proof/install/models 全 `200`，本确定性 Library 路径无 completion 不虚构。REST 最终清册恰有 8 行，复制树及其后代无残留，父子关系、path 和 position 与 UI 一致；`rig-check`、`rig-down`、ffprobe、fixture compile、focused Flutter `62/62` 通过。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-061413/evidence/SURF-048-library-rail-documents-five-channel.md`。

五格=`G1/F1/B2/C4/G1`；formal ledger=`2185→2190 judgments`，COVERAGE=`848 rows / 430→431 judged rows / 0 tombstones`，anchors=`10/10`。警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-048-ledger-alarm-reaudit.md`，`gap-too-fast`/`discovery-collapse` 按原阈值独立复审并串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2190 judgments)`；批次四十一由 `42→43/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-049`。P12 的 400+ Journey 按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-049 library/rail-skills` 已在全新数据目录 `/private/tmp/anselm-data-surf049-20260819-r1`、workspace=`ws_099053bde6cf3739`、正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-062938` 完成。fixture `testend/rig/seed_surf049.py` 通过公共 API 幂等创建同名 Document 与两个 user Skill，验证 `skill:` 行 ID 防撞、Skills 扁平列段和本地搜索。真实 App + managed gateway + Computer Use 逐帧确认同名文档/技能分区、不同 glyph、正确详情路由、beta flat/no-drag、过滤与清空可逆且中心详情不漂移；没有产品 defect，不需要 stop-and-fix。

五通道：录屏=`211.728333s`；backend=`302` 行无 WARN/ERROR/panic/fatal，REST/SQLite identity 与 UI 对账且 integrity=`ok`；ssetap 独立连接三流，notifications durable=`1..3` 严格递增，本确定性 Library 路径无 chat/entity durable frame；frontend 无 Dart/Flutter/RenderFlex/RenderBox/Unhandled/Exception/AX 红线；llmtap managed proof/install/models 全 `200`，无 completion 伪声明；`rig-check`/`rig-down`、ffprobe、fixture compile、focused Library/skill-preview=`62/62` 通过。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-062938/evidence/SURF-049-library-rail-skills-five-channel.md`。

五格=`G1/F1/B2/C4/G1`；formal ledger=`2190→2195 judgments`，COVERAGE=`848 rows / 431→432 judged rows / 0 tombstones`，anchors=`10/10`。写账后的 `gap-too-fast`/`discovery-collapse` 由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-049-ledger-alarm-reaudit.md` 独立复审并串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2195 judgments)`；批次四十一由 `43→44/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-050`。P12 的 400+ Journey 按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-033 entities/rail-overview-row` 已在真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-000301` 完成：冷启动无选中实体时固定无头 `Overview` 行位于搜索框下方并高亮；选择 `greet` 后再点击 `Overview` 返回总览，移开指针并等待稳定后仅 Overview 保留选中态。最终五通道封口为录屏 `221.181667s`、backend `310` 行、frontend `3` 行无应用红线、ssetap 三流真实连接、llmtap bootstrap `200`；SQLite `integrity_check=ok`，Function/Handler/Agent/Workflow=`2/1/1/0`，focused Flutter `33/33`、analyze、rig-check/rig-down 通过。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-000301/evidence/SURF-033-entities-rail-overview-row-five-channel.md`，最终帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-000301/evidence/SURF-033-final-overview-frame.jpeg`，五格=`G1/F1/B2/C4/G1`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-033-ledger-alarm-reaudit.md`，最终 `alarms.py check`=`clean (2115 judgments)`；批次四十由 `25→30/50`，下一原子前线为 `SURF-034 entities/rail-function`。

`SURF-034 entities/rail-function` 已在真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-001201` 完成：Function 段展开显示 `sync_inventory`/`greet` 与精确计数 `2`；折叠只隐藏子行，重新展开后顺序稳定。选中 `greet` 后折叠 Function，详情路由保持，重新展开后 `greet` 恢复唯一选中态。最终五通道封口为录屏 `256.505000s`、backend `344` 行、frontend `3` 行无应用红线、ssetap 三流真实连接、llmtap bootstrap `200`；SQLite `integrity_check=ok`，Function/Handler/Agent/Workflow=`2/1/1/0`，focused Flutter `33/33`、analyze、rig-check/rig-down 通过。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-001201/evidence/SURF-034-entities-rail-function-five-channel.md`，最终帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-001201/evidence/SURF-034-final-function-frame.png`，五格=`G1/F1/B2/C4/G1`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-034-ledger-alarm-reaudit.md`，最终 `alarms.py check`=`clean (2120 judgments)`；批次四十由 `30→35/50`，下一原子前线为 `SURF-035 entities/rail-handler`。

`SURF-035 entities/rail-handler` 已在真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-003246` 完成：Handler `order_desk` 从 stopped 灰点开始，真实调用 `place` 后详情为 `running`、右岛结果为 `{ "ok": true }`，rail 同步为蓝色运行点；返回 Overview、折叠与重新展开后计数、顺序、蓝点和路由均稳定。首轮 session=`20260819-002301` 抓到详情与 rail 分裂，`20260819-002838` 证明前端单修仍失败；stop-and-fix 补齐后端 `GET /handlers` 列表 `runtimeState` 投影与前端 call 收尾列表重读。正式录屏 `220.095000s / 2560x1584 / H.264 / 60fps`，backend `311` 行无应用红线，frontend `3` 行正常启动，ssetap 三流连接，llmtap challenge/install/models 全 `200`，SQLite integrity=`ok`，focused Flutter `45/45`、Dart analyze、Go handler/HTTP tests、rig-check/rig-down 通过。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-003246/evidence/SURF-035-entities-rail-handler-five-channel.md`，最终帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-003246/evidence/SURF-035-final-handler-frame.png`，五格=`G1/F1/B2/C4/G1`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-035-ledger-alarm-reaudit.md`，最终 clean=`2125 judgments`；批次四十由 `35→40/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-036 entities/rail-agent`。P12 400+ Journey 继续按用户裁定推迟二期。

`SURF-032 entities/workflow-editor` 已在真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-234952` 完成：新增 Agent 节点落在现有图下方且无重叠，Ref 选中真实 `surf032_editor_agent`，Save 由后端诚实拒绝不可达 Agent，Discard 后草稿回到干净状态。首轮 stop-and-fix 修正当前 family 重选清空 target、固定新增坐标造成卡片重叠；复跑又修正 workflow editor notice 压住 toolbar 边缘。最终五通道封口为录屏 `78.313333s`、backend `136` 行无应用红线、frontend `3` 行无应用红线、ssetap 三流连接且无业务 frame 被伪造、llmtap readiness；REST/SQLite 对账为 v2、无临时 Agent 与 v3，focused tests/analyze/rig-check/rig-down/diff check 均通过。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-234952/evidence/SURF-032-entities-workflow-editor-five-channel.md`，五格=`G1/F1/B2/C4/G1`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-032-ledger-alarm-reaudit.md`，最终 `alarms.py check`=`clean (2110 judgments)`；批次四十由 `20→25/50`，下一原子前线为 `SURF-033 entities/rail-overview-row`。

`SURF-031 entities/tab-dispatch` 已在真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-230255` 完成：cold `Idle`、prepare `Listening / 4 listeners`、Dispatch 五种 firing disposition、状态筛选、展开详情、Activity `Fired only`、产品内 Fire 通知/回执，以及 settle 后 `Idle` 均已观察。首轮红证据的 terminal-filter race 与 stale-listening 已 stop-and-fix，最终以 fire signal 有界 REST reconciliation 和 workflow lifecycle durable refresh 修复。五通道封口为录屏 `486.651667s`、backend `975` 行无应用红线、frontend `3` 行无应用红线、ssetap `145` 条三流记录无 durable gap、llmtap readiness；REST/SQLite 对账 `shed9/skipped14/started54/superseded11`、`51 completed+3 cancelled`、`23 activations`，focused Flutter `35/35`、analyze、rig-down、diff check 均通过。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-230255/evidence/SURF-031-entities-tab-dispatch-five-channel.md`，五格=`G1/F1/B2/C4/G1`，ledger=`2100→2105`，COVERAGE=`848/413→414/0`，anchors=`10/10`；警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-031-ledger-alarm-reaudit.md`，最终 clean。批次四十由 `15→20/50`，下一原子前线为 `SURF-032 entities/workflow-editor`。

`SURF-030 entities/tab-activity` 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-220939`；真实 App 观察 sensor Activity 的 All activity/Fired only、分页、Load more 和 fired/not-fired 展开详情。真实 handler probe 产生 `25` 条 activation（`22 fired / 3 not-fired`），workflow 完成 `22` 次。首轮发现普通 boxed dropdown 横跨阅读列、像输入框而非筛选器；stop-and-fix 将 Activity 与 Dispatch 过滤器改为紧凑 ghost control，并补 focused widget test 与实体文档。录屏 `255.085000s / 2560x1584 / H.264 / 60fps`，backend `239` 行、frontend `3` 行无应用红线，ssetap `9` 行三流连接且无 gap，llmtap readiness 保留；REST/SQLite/UI 对账一致，`PRAGMA integrity_check=ok`。Focused Trigger Flutter `14/14`、AnDropdown `7/7`、`flutter analyze`、rig compile/check/down 通过。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-220939/evidence/SURF-030-entities-tab-activity-five-channel.md`，五格 `G1/F1/B2/C4/G1` 入账，formal ledger `2095→2100 judgments`，COVERAGE=`848/412→413/0`，anchors=`10/10`；警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-030-ledger-alarm-reaudit.md`，最终 `alarms.py check`=`clean (2100 judgments)`。批次四十由 `10→15/50`，未到第 50 格不跑统一长门禁、不提交；下一正式前线为 `SURF-031 entities/tab-dispatch`。P12 400+ Journey 按用户裁定推迟二期。

`SURF-027 entities/tab-versions` 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-195700`；真实 App 创建 v1/v2/v3 版本历史，首屏展开 v3、双开 v2、菜单 `Show all/Only changes` 与真实 `Set active` 均通过；关闭 Run 面板后全宽阅读列无裁切、重排、重叠或视觉跳变。录屏 `292.063333s / 2560x1584 / H.264 / 60fps`；backend 409 行无应用红线，SSE notifications `16..25`（含 `function.reverted`）与 entities `7..12` 连续，frontend 只有 session-reviewed AXTree tooling noise、无 Dart/Flutter/RenderFlex/Unhandled 应用红线，llmtap readiness/proof/install/models 全 `200` 且无本路径 completion；REST/SQLite/UI/SSE 最终均指向 v2。五格 `G1/F1/B2/C4/G1` 已写入，证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-195700/evidence/SURF-027-entities-tab-versions-five-channel.md`，告警复审=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-195700/evidence/SURF-027-ledger-alarm-reaudit.md`，anchors=`10/10`，最终 `alarms.py check`=`clean (2085 judgments)`。P12 400+ Journey 继续按用户裁定推迟二期。

批次三十九统一收口结果：根 `make verify` 首轮只发现本轮新增 LOG 分隔线造成的 frontmatter 误读，修正文档后第二轮 `backend/frontend/docs/demo` 全绿并输出 `workspace verified`；backend 非缓存全量 Go 全绿，完整 `make -C backend testend` 的 `testend/scenarios` 全绿（`302.949s`），台架 Python 回归 `42/42`、Python compile、Shell syntax、`gen_coverage.py --check`、anchors `10/10`、`alarms.py check`、`git diff --check` 全通过。收台审计确认 conductor/App/录屏器/SSE tap/LLM tap/`llama-server` 进程与 `9032/8900` 监听端口均为零；批次三十九已完成 50 格后的统一门禁并解锁 `SURF-028`。批次四十当前 `5/50`，本批次统一长门禁与提交仍锁定到第 50 格。本段状态与 `README.md` §5.2、`LOG.md` 同步。

`SURF-028 entities/tab-logs` 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-205447`；真实 App 覆盖 Function、Handler、Agent 的 ok/failed 聚合、Load more、展开详情和当前会话新增执行。首轮 Function 失败行暴露 stderr traceback 与业务日志重复，stop-and-fix 接入 `splitFunctionStderr`：新失败行 Error 只保留 traceback，Logs 只保留 print/debug；旧 durable 行不重写且已记录迁移边界，新增 Go 回归并同步 Function domain 文档。

五通道封口：录屏 `548.238333s / 2560x1584 / H.264 / 约57fps`，关键帧 `frame-210`、`frame-235`、`frame-500`；backend `634` 行无应用红线，frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线，ssetap 三流 durable 序列单调并记录 `seq=0` delta，llmtap 本轮真实 completion HTTP `200`；REST/SQLite 对账为 Function `21 ok/5 failed`、Handler `6 ok/2 failed`、Agent `3 ok/0 failed`，SQLite integrity=`ok`，稳定 ROI `measure diff` 无异常输出。focused Function Go tests 与 entities Flutter `12/12` 通过。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-205447/evidence/SURF-028-entities-tab-logs-five-channel.md`，告警复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-028-ledger-alarm-reaudit.md`；五格按 `G1/F1/B2/C4/G1` 入账，写账后的两条统计警报已独立复审并 ack，最终 `alarms.py check`=`clean (2090 judgments)`，未改阈值、算法、法典、锚点或 gate。P12 400+ Journey 按用户裁定推迟二期；下一原子前线为 `SURF-029 entities/tab-runs`。

`SURF-029 entities/tab-runs` 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-213748`；真实 App Runs 驾驶舱完成 completed、parked approval、failed/replay 三态，inline `Approve` 将 parked run 真实决策为 `completed/decision=yes`。首轮红证据发现 replay 后把人工检查间隔并入 `Elapsed`，且 action node 显示虚假 `0ms`；stop-and-fix 增加 flowrun activity 分页与 execution audit 聚合，UI 拆分 `Run lifetime`/`Execution`，节点优先显示最新 activity。修复后失败重放真实显示 `1m34s / 179ms`，approved run 显示 `6m11s / 29ms`，生命周期与函数执行不再混淆。

五通道封口：录屏 `475.108333s / 2560x1584 / H.264 / 约57fps`；backend `583` 行、frontend `3` 行无应用红线，ssetap `57` 行且 notifications `16..29`、entities `7..23` 连续、无 gap，llmtap challenge/install/models 全 `200`；REST/SQLite 对账为 `2 completed + 1 failed`、integrity=`ok`，实体 Flutter `16/16`、Function Go、rig-check/rig-down 通过。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-213748/evidence/SURF-029-entities-tab-runs-five-channel.md`；五格 `G1/F1/B2/C4/G1` 入账，formal ledger `2090→2095 judgments`，COVERAGE=`848/411→412/0`，anchors=`10/10`。写账后的 `gap-too-fast` 与 `discovery-collapse` 以 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-029-ledger-alarm-reaudit.md` 复审并 ack，最终 clean，未改阈值、算法、法典、锚点或 gate。批次四十由 `5→10/50`，未到 50 格不跑统一长门禁、不提交；下一正式前线为 `SURF-030`。P12 400+ Journey 按用户裁定推迟二期。

`SURF-026 entities/tab-overview` 的正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-194016`，真实 App 检查七类实体 Overview；64 行 Function 的 `Show all/Collapse`、Workflow 2-node/1-edge 图英雄区与 cron/webhook/fsnotify/sensor 四源模板均真实打开并封存。录屏 `496.695000s`，backend 655 行无应用红线，SSE 三流 13 frame events/12 durable，frontend console 无应用红线，llmtap readiness 与真实网关 200 响应可追溯；稳定段 `measure diff` 无异常变化，五格 `G1/F1/B2/C4/G1` 已入账。告警已按原规则复审并 ack，anchors=`10/10`，最终 clean；P12 400+ Journey 继续按用户裁定推迟二期。

`SURF-025 entities/detail` 的正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-192253`，真实 App 覆盖 Function、Agent、Workflow、Control、Approval、Trigger、Flowrun 详情与一次成功的两节点 workflow run；首轮发现并修复 Function/Agent 空 Interface 重复标题问题，focused tests `16/16` 与 `flutter analyze` 通过。五通道证据已封存：录屏 `396.623333s`，backend 553 行无应用红线，SSE 三流 15 行/6 durable frames，frontend console 无应用红线，llmtap readiness 与真实网关 200 响应可追溯；五格 `G1/F1/B2/C4/G1` 已入账。`gap-too-fast` 与 `discovery-collapse` 已完成不改规则的独立复审并 ack，anchors=`10/10`，告警最终 clean。P12 400+ Journey 继续按用户裁定推迟二期。

SURF-005 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-203105`；真实 App 通过 workspace footer 菜单完成长名 workspace 创建/切换、Settings Workspaces、Notifications tray 和返回 Chat，app-region 录像包含 OverlayPortal。五个 settled 60fps 窗口无 diff，SQLite `notifications=9/unread=9` 与 `Today 9` 对齐，五通道干净，focused Flutter `90/90`、rig `42/42` 通过。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-005-contract-matrix.md` 及 session L2/global L3/L4/L5；警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-005-ledger-alarm-reaudit.md`。

SURF-006 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-205331`；真实 App 完成 Entities/Function 的浮层面包屑、回顶、右 inspector 收起/恢复、左 sidebar 收起/重开，以及切到 Scheduler/Library/文档/Settings 后旧头清理。录屏 `248.645000s / 2560x1584 / H.264 MOV`，源 `60/1`，五通道同一 manifest，backend/frontend 无应用红线，ssetap 三流连接并 clean EOF，llmtap challenge/install/models 全 `200`，focused Flutter `128/128`、rig `42/42`、anchors `10/10` 通过。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-006-contract-matrix.md` 及 session L2/global L3/L4/L5；诊断中的指针/外部系统通知已明确隔离，不冒充 App 内容跳变；警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-006-ledger-alarm-reaudit.md`。

SURF-007 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-211204`；真实 App 完成真实失败 workflow→顶带 failure capsule、parked approval→approval block、失败队列尾与 `+1`、`Clear all 4 top notifications`、Notifications `Needs you 1`、Reject 和 REST 对账。录屏 `510.650000s / 2560x1584 / H.264 MOV`，源 `60/1`；five-channel journals、fresh AX、settled measure ROI、focused Flutter `44/44` 与 rig `42/42` 通过。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-007-contract-matrix.md` 及 session L2/global L3/L4/L5；外部指针/caret/host overlay 已在证据中隔离；警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-007-ledger-alarm-reaudit.md`。

SURF-008 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-215802`；真实 App 完成三时段折叠展开、搜索/清空、Unread only、reload、每组读/未读动作、滚动和固定后的折叠过渡。最终 SQLite `17/15 unread` 与 UI `Today 11 / Yesterday 3 / Earlier 3` 对齐；录屏 `816.771667s / 2560x1584 / H.264 MOV / 60fps`，固定过渡 `measure latency` 首反馈 `16.7ms`，中间帧不再出现被高度裁切的字形残片。五通道同一 manifest：backend `904` 行无应用红线，ssetap 三流连接且 durable 序列单调、delta `seq=0`，frontend 仅已分类 AX bridge 观测噪声，llmtap challenge/install/models 全 `200`；focused Flutter `31/31`、analyze、rig/anchors/gen_coverage 全通过。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-008-contract-matrix.md` 及 session L2/global L3/L4/L5；警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-008-ledger-alarm-reaudit.md`。

SURF-009 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-225238`；真实 App 让两个真实 flowrun 停在同一 approval，托盘显示 `Needs you 2` 与两张完整审批卡，先 REST 决定第一条，再在 App 点击第二条 `Approve`，计数真实经历 `2→1→0`，两条 flowrun 均完成且 inbox 为空。录屏 `211.723333s / 2560x1584 / H.264 MOV / 60fps`；源分辨率逐帧复核 `t166–t170`、`t180–t183`，无按钮/问题文本/边框裁切或跳位。首次实现发现的 approval-capsule 尾部裁切已 stop-and-fix 为内容先淡出、shell 后收缩，并补 enter/exit geometry regression。五通道同一 manifest：backend `46,966` 字节无应用红线，frontend 仅正常启动行，ssetap 三流连接且 notifications `16..19`、entities `7..10` 单调、run delta `seq=0`、clean EOF，llmtap challenge/install/models 全 `200` 且无 completion；focused approval-capsule `11/11`、notification-tray `15/15`、analyze、rig/coverage/anchors/alarms 全通过。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-225238/evidence/SURF-009-contract-matrix.md`；警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-009-ledger-alarm-reaudit.md`。

SURF-015 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-053707`，隔离数据=`/private/tmp/anselm-data-surf015-run-dossier-20260818-r51`；真实 App 经受管网关找到 `audit_logger`、无参数执行，并打开 `get_function_execution` 的完整审计卷宗。首轮静态/真实回合复核发现 durable close 退回通用脱敏会重新露出 `the requested item`，且空的中文溯源表会留下无信息表壳；stop-and-fix 让 durable close 与 live delta 共用 context-aware redactor，并把空溯源段明确指向邻近执行卡，补 Go 回归与 chat reference 同步。修复后二进制真实回合的执行记录为 `fne_0988429b9c11bcda`、`ok`、`{}`、`{"items":[1,2,3],"ok":true}`、日志 `audit-start/audit-finish`、`158ms`；structured card 展示状态、触发方式、I/O、日志、时间和 `Conversation`/`Copy message`/`Copy Tool call` 三个溯源控件。录屏 `695.765000s / 2784x1808 / 60fps` 封口可读，Computer Use 展开态截图与 AX 均确认三枚精确关联控件；五通道 journal、REST/SQLite、LLM wire 与 UI 对账一致，backend/frontend 无未解释红线。固定 `240px` JSON tree viewport 是既有 bounded-tree 设计，不是数据隐藏或溢出；最终没有残留产品缺陷。正式按 `G1 / F2 / A5 / C4 / G1` 写入 `COVERAGE SURF-015=✓✓✓✓✓`，formal ledger `2020→2025 judgments`，`gen_coverage.py --check`=`848 rows / 398 judged rows / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已由同一 sealed session、展开态截图、原始五通道 journal、静态回归和锚点独立复审后按原阈值 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2025 judgments)`。本批次由 `25→30/50`，未到 50 格不跑统一长门禁、不提交；下一正式前线为 `SURF-016 chat/nested-run-pane`。P12 的 400+ Journey 扩写继续按用户裁定推迟二期。

EP-257 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-183216` 由同一 conductor 托管真实 Flutter App、dev backend、录屏、frontend console、三路独立 SSE 和真实受管网关。全新 onboarding 创建 `EP257 Stats Lab`，managed challenge/install/models 与 provision/probe 均为真实 200；四类 query 均返回精确十字段 runtime JSON，`heapObjects` 随实时请求变化，POST/OPTIONS 405，native HEAD 200 且读取 body 为 0；无 `ANSELM_DEV` 的同版 backend 对 stats/pprof 均为 404。

五通道事实：EP-257 录屏 `182.813333s / 2784x1808 / 60fps`，稳定 Chat frame 的 `measure diff` 无输出，onboarding→ready 过渡逐张复核无白闪、布局破坏、focus jump、clipping、overlap、reflow 或 overlay；backend/frontend 无应用红线；ssetap 的 notifications/messages/entities 三流均连接并以 EOF 干净收台；llmtap challenge/install/models 全 `200`。L2 证据严格绑定该 session 的 manifest、backend/frontend/SSE/LLM journal、生产负向探针、native HEAD 证据与封口 `screen.mov`；L1/L2/L3 通过，L4/L5 是书面理由充分的 `na`。

SURF-001 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-184628`；真实 App-first 延迟启动记录 connecting→crashed+Retry→onboarding→Chat，录屏 `112.231667s / 2784x1808 / 60fps`，稳定 Chat frames 的 diff 无输出，五通道均归属同一 manifest，focused Flutter tests `14/14`，SQLite 工作区与最终 UI 一致。

SURF-002 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-185542`；app-only proxy 将 `GET /api/v1/workspaces` 延迟 `60.002898s`，真实 App 在此期间稳定显示 `Setting up your workspace…`，释放后进入空工作区 onboarding，真实创建后进入完整 Chat 壳。录屏 `194.130000s / 2784x1808 / 60fps`，稳定 `t180/t182/t184/t186/t188/t190/t192` 的 diff 无输出；五通道同一 manifest 对证，focused startup/process Flutter `14/14`、workspace gate/bootstrap/create/switch Flutter `12/12`、appproxy/proxycore Go 与 rig `42/42` 通过。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-002-contract-matrix.md` 及 session L2/L3/L4/L5。

SURF-004 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-190835`；真实 App fresh AX 走完 `Chat → Entities → Chat → Entities → Scheduler → Library → Settings → Notifications tray → Chat`，Settings/通知托盘无顶部选中药丸且只替换预期左岛中段。录屏 `152.468333s / 2784x1808 / 60fps`，两次切换首反馈 `16.7ms/66.7ms`，settled groups diff 无输出；五通道同一 manifest 对证，SQLite 与 Entities UI 对齐，ocean/shell/router Flutter `52/52`、appproxy/proxycore Go 与 rig `42/42` 通过。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-004-contract-matrix.md` 及 session L2/L3/L4/L5。

SURF-016 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-060616`，隔离数据=`/private/tmp/anselm-data-surf016-nested-run-20260818-r2`；真实 App 先 search `nested_review_agent`，再真实 invoke 两次，Computer Use 观察到 live bounded nested pane 与 settled final answer。r1=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-055959` 首次暴露 plain-text `invoke_agent.input` 在旧严格边界被拒并留下红色失败活动，保留为 discovery、不计绿；stop-and-fix 只加 agent input 的 object/stringified-object/plain-task 窄兼容，数组/数字/布尔仍拒绝。r2 新二进制真实 wire 实际覆盖 stringified-object 与 native-object 两种形状，两个 execution 均 `ok`，无 validation failure/retry；live rail 显示 `Ran · Live`/`Listening live · settle follows the truth`，settled 卡显示 `Completed`、steps/tokens/elapsed、agent id、copy chip 与最终答案。录屏 `355.461667s` 封口可读；SSE messages durable `1..44` 连续，child blocks 以 `parentId` 挂在 invoke tool-call 下，delta 均 `seq=0`，三流 clean EOF；LLM managed challenge/install/models/chat 全 `200`，backend/frontend 无应用红线。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-060616/evidence/SURF-016-nested-run-pane-green.md`，`judge.py` 按 `G1/F2/A5/C4/G1` 写入五格；警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-016-ledger-alarm-reaudit.md`，原阈值 ack 后 `alarms.py check`=`clean (2030 judgments)`。

SURF-017 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-145523`，隔离数据=`/private/tmp/anselm-data-surf017-tool-cards-20260801-r88`；r83–r87 真实托管模型回合逐次冻结为红，技术 ID、生命周期/目录猜测和残余占位词泄入用户文案；stop-and-fix 在完整耐久 assistant close 边界加入窄匹配 canonicalization，只改用户叙事，不改工具卡、审计面或 LLM wire，并补 loop 守卫测试与 chat reference。r88 真实 App 先 `search_tools` 激活 `get_function`，再只调用一次合法格式但不存在的 `fn_0000000000000000`；一张失败工具卡保留精确 ID，正文为稳定中文解释，无 retry、重复回答或 mutation。封口 `screen.mov`=`130.230000s / 2560x1584 / H.264`，稳定帧 measure diff 无 changed-region；backend 只有预期 not-found WARN，SSE `96` 帧且 messages durable `1..20` 单调无 gap，frontend 只有正常 Dart VM 行，llmtap challenge/install/models 与四次 chat completion 全真实 `200`。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-145523/evidence/SURF-017-r88-five-channel.md`，三张 stable frames 与红证据均保留。

SURF-018 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-153747`，隔离数据=`/private/tmp/anselm-data-surf018-20260818-r1`；真实 App 在两个不同 residency workDir 分别 Pin Alpha/Beta，验证 Pinned 优先、跨 residency 聚合、计数与排序；真实 Unpin Beta 后回到原 residency，再重新 Pin 并按 Name 排序。封口 `screen.mov`=`339.851667s / 2560x1584 / H.264 / 60fps`，REST/SQLite/SSE/前端/LLM 五通道对账一致；frontend 仅已分类 AX tree 观察噪声且静置无增长，无应用红线。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-153747/evidence/SURF-018-rail-pinned-five-channel.md`，AX 分类=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-153747/evidence/frontend-ax-review.md`。

SURF-018 五格按 `G1 / F2 / B2 / C4 / G1` 写入，formal ledger `2035→2040 judgments`，COVERAGE=`848 rows / 401 judged rows / 0 tombstones`，anchors=`10/10`；`gap-too-fast` 与 `discovery-collapse` 已以 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-018-ledger-alarm-reaudit.md` 复审并 ack，未改任何门禁机制，最终 `alarms.py check`=`clean (2040 judgments)`。批次三十九当前 `5/50`，下一正式前线为 `SURF-019 chat/rail-residency`。
SURF-019 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-161005`，隔离数据=`/private/tmp/anselm-data-surf019-20260818-r1`；真实 App 构造 Gamma=3、Beta=4、Alpha=34、Recents=1 的 residency fixture，冷启动只展开 Gamma，折叠组不渲染行/页脚；Beta 终页一次加载 4 条，Alpha 首页 30 条、尾部第二页 4 条，backend/API/cursor/total-count 对账确认第二页属于 Alpha，不是 Beta 重取。录屏 `168.121667s`，rail 稳定帧与转场测量封存，未见 clipping、overlap、white flash、reflow 或 input jump；backend/frontend 无应用红线，ssetap 三流 clean EOF，llmtap ready 且无本路径 completion。focused `conversation_list_provider_test.dart`=`33/33`。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-161005/evidence/SURF-019-rail-residency-five-channel.md`，五格按 `G1/F2/B2/C4/G1` 入账，formal ledger=`2045 judgments`，COVERAGE=`848/402/0`，anchors=`10/10`；三条统计警报按 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-019-ledger-alarm-reaudit.md` 复审后 clean。批次三十九由 `5→10/50`，未到 50 格不跑统一长门禁、不提交，下一前线为 `SURF-020`。
SURF-020 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-163901`，隔离数据=`/private/tmp/anselm-data-surf020-20260818-r2`；真实 App 冷启动观察 Recents 活动排序，打开 Display options 切换 Recently created 与 Name，选中 `Alpha Created Recent` 后恢复活动排序。四条 unmounted/unpinned 线程三种顺序与 API/SQLite 对齐：activity=`Zulu, Middle, Bravo, Alpha`、created=`Alpha, Middle, Bravo, Zulu`、name=`Alpha, Bravo, Middle, Zulu`；Pinned 与 `anselm-surf020-mounted` 始终在 Recents 外。录屏 `289.803333s / 2560x1584 / H.264 / 60fps`，backend 无应用红线，ssetap 三流 clean EOF，frontend 仅已分类 AXTree 观察噪声，llmtap ready 且无本路径 completion；focused rail/provider=`51/51`。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-163901/evidence/SURF-020-rail-recents-five-channel.md`，五格按 `G1/F2/B2/C4/G1` 入账，formal ledger=`2050 judgments`，COVERAGE=`848/403/0`，anchors=`10/10`；`gap-too-fast`/`discovery-collapse` 按 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-020-ledger-alarm-reaudit.md` 复审后 clean。批次三十九由 `10→15/50`，未到 50 格不跑统一长门禁、不提交，下一前线为 `SURF-021`。
SURF-021 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-170406`，隔离数据=`/private/tmp/anselm-data-surf021-20260818-r3`；真实 App 依次观察 skeleton、有限两次 `503` 后的 error+retry、恢复列表、空 rail 和新建 durable row 列表。注入只作用于两个并行 conversations GET，后续请求全部 forward；空态保留完整 rail chrome 而不造墓碑。录屏 `74.766667s / 2560x1584 / H.264 / 60fps`，五状态帧与 `measure diff` 已封存；backend/frontend 无应用红线，ssetap 三流连接且 notifications durable `16/17` 对应 delete/create 后 clean EOF，llmtap 真实 challenge/install/models 全 `200` 且本路径无 completion，录屏光标/点击光晕明确归类为 `screencapture -C` 观测器痕迹。REST/SQLite/UI/SSE 对账一致，focused Flutter=`62/62`，appproxy `go test -race`、shell、coverage、diff checks 通过。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-170406/evidence/SURF-021-rail-states-five-channel.md`；五格按 `G1/F2/B2/C4/G1` 入账，formal ledger=`2055 judgments`，COVERAGE=`848/404/0`，anchors=`10/10`。三条统计警报已由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-021-ledger-alarm-reaudit.md` 复审并 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2055 judgments)`。批次三十九由 `15→20/50`，未到 50 格不跑统一长门禁、不提交，下一前线为 `SURF-022 chat/sidestage`。

SURF-022 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-173028`，隔离数据=`/private/tmp/anselm-data-surf022-20260818-r1`；真实 App 右岛完成 50→54 条历史触点 load-more、Tasks 1/3→2/2、真实 `sync_inventory` 成功执行、真实 `surf022_slow` live→settled，以及关闭/重开后的服务端重水合。录屏 `237.825000s / 2560x1584 / H.264`；backend/frontend 无应用红线，ssetap 三流 durable `messages 1..61`、`notifications 1..3`、`entities 1..2` 单调，llmtap 18 个带状态请求全 `200`，SQLite 56 触点和两个 completed todo 对账；focused Flutter=`45/45`。首轮缺 sandbox env 的准备 session 保留为红证据、不计绿；正式五级按 `G1/F2/B2/C4/G1` 入账，COVERAGE=`848/404→405/0`，anchors=`10/10`，两条统计警报按独立证据复审后 clean，未改门禁机制。批次三十九由 `20→25/50`，未到 50 格不跑统一长门禁、不提交，下一前线为 `SURF-023 entities/overview`。P12 的 400+ Journey 扩写继续按用户裁定推迟二期。

SURF-023 正式 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-181700`，隔离数据=`/private/tmp/anselm-data-surf023-20260818-r3`；真实 App 总览五计数牌、8 节点/5 关系图和最近五行均与 REST/SQLite 对账。首轮 `20260818-180043` 暴露 framed graph 被 wheel scale 缩坏，修复后预览关闭 pan/scale、全屏探索保留平移缩放；回归覆盖 trackpad/mouse-wheel。录屏 `447.845000s`，顶部/下滚/恢复帧与 `measure compare changedFrac=0.00613 pass=true` 封存，三路 SSE、backend/frontend、LLM readiness 均归同一 manifest，focused Flutter=`19/19`。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-181700/evidence/SURF-023-entities-overview-five-channel.md`；五格按 `G1/F1/B2/C4/G1` 入账，formal ledger=`2065 judgments`，COVERAGE=`848/406/0`，anchors=`10/10`。三条统计警报已由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-023-ledger-alarm-reaudit.md` 复审并 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2065 judgments)`。批次三十九由 `25→30/50`，下一前线为 `SURF-024 entities/graph`。

正式账本=`2070 judgments`，COVERAGE=`848 rows / 407 judged rows / 0 tombstones`，EP-251=`✓✓✓✓✓`、EP-252=`✓✓✓~~`、EP-253=`✓✓✓~~`、EP-254=`✓✓✓~~`、EP-255=`✓✓✓~~`、EP-256=`✓✓✓~~`、EP-257=`✓✓✓~~`、SURF-001=`✓✓✓✓✓`、SURF-002=`✓✓✓✓✓`、SURF-004=`✓✓✓✓✓`、SURF-005=`✓✓✓✓✓`、SURF-006=`✓✓✓✓✓`、SURF-007=`✓✓✓✓✓`、SURF-008=`✓✓✓✓✓`、SURF-009=`✓✓✓✓✓`、SURF-015=`✓✓✓✓✓`、SURF-016=`✓✓✓✓✓`、SURF-017=`✓✓✓✓✓`、SURF-018=`✓✓✓✓✓`、SURF-019=`✓✓✓✓✓`、SURF-020=`✓✓✓✓✓`、SURF-021=`✓✓✓✓✓`、SURF-022=`✓✓✓✓✓`、SURF-023=`✓✓✓✓✓`、SURF-024=`✓✓✓✓✓`，anchors=`10/10`，alarms=`clean`，`gen_coverage.py --check`=`clean`。SURF-024 写账后的 `gap-too-fast`、`discovery-collapse` 已按原阈值独立复审并销账；未改阈值、算法、法典、锚点或 gate。批次三十九当前 `35/50`，未到 50 格不跑统一长门禁、不提交，下一正式前线为 `SURF-025 entities/detail`。SURF-003 已是既有五格绿。P12 的 400+ Journey 扩写继续按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

批次三十七统一门禁的首轮根 `make verify` 真实冻结在 frontend gallery 的 `relation.dependency_broken` 窄 rail overflow；stop-and-fix 将长动词改为可省略弹性段并补 `8/8` focused regression。随后 gallery bucket 1=`219/219`、frontend 全量=`5369 tests`、根 `make verify` 四门、backend 非缓存全量 Go、完整 `make -C backend testend`=`278.817s` 全绿；process/port/fixture/worktree 审计清零。首轮红、修复与重跑证据=`/private/tmp/anselm-rig-formal-20260801-3/evidence/batch-37-unified-gate-20260817.md`。批次三十七已收口，下一格尚未启动。

### 历史快照（EP-250，已由上方当前声明接管）

EP-250 `GET /api/v1/entities/stream` 已在当前源码、真实 Flutter macOS App、真实受管 Anselm 网关和正式五通道台架下完成五级验收。绿色 mirror=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-163104`，由同一 conductor 封口；EP-230–EP-249、EP-220 及既有绿色项保持五格绿，不删除、不重跑，早先候选和第一次 wiring fail-closed 启动只保留历史。

真实产品路径是普通 Entities：创建 `ep250_entities_stream_probe_r2` 后 Overview/rail 从 3 到 4，详情显示 `env ready`、Python `3.12` 和完整代码；Computer Use 点击右岛 Run，真实 App 显示 `Done · 74ms`、Output、Result、Logs 与 Recent Manual。REST/SQLite 对同一 Function/version/execution 对账为 `ok`、`manual`、`entities-stream-r2`。协议矩阵覆盖 `fromSeq` 回放、`Last-Event-ID` 优先、坏 cursor live-only、缺 workspace `401` 和错方法 `405`。

五通道均已收台：录屏 `196.013333s / 2788x1808 / 60fps`，55 张稳定帧无 clipping/overlap/white flash/reflow/button drift/input jump；backend/frontend 无应用红线；entities durable `seq=1..4` 单调、build/run 各自 `open→close`、delta 保持 `seq=0`，notifications `1..3`，messages 无业务帧符合 direct Function 路径；llmtap wiring 真实通过但无 chat completion，符合不经过 LLM 的路由事实。后端与台架 fail-closed 边界均如实保留，未被隐藏。

正式账本=`1945 judgments`，COVERAGE=`848 rows / 382 carried / 0 tombstones`，EP-250=`✓✓✓✓✓`，laws=`F1/F2/B2/C5/G1`，anchors=`10/10`，alarms=`clean`。两条统计警报已按封存录屏、协议/REST/SQLite、五通道 journal、wiring、focused Go tests、rig `42` 项和锚点复审后逐项 ack，未改阈值、法典、锚点或 gate；`gen_coverage.py --check` 已通过。本批次从 `46/50` 跨到 `51/50` 后，最终源码上的根 `make verify`（backend/frontend/docs/demo）、非缓存全量 Go 测试和完整 `make -C backend testend`（`294.064s`）均通过。门禁发现的 S6 405 直接写 envelope 已修为共享 `ErrMethodNotAllowed` 并经 `FromDomainError`，同步错误码 reference 后重跑全绿；conductor-owned 进程/监听器清零，陈旧 EP-208 fixture 已清理。本批已提交为 `117e2567`，提交后工作树干净；下一原子前线为 EP-251 `GET /api/v1/notifications/stream`，现已解锁。P12 的 400+ Journey 扩写继续按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

## 历史前线覆盖声明（2026-08-13 15:31）

`SURF-008 shell/notification-tray` 已完成真实通知托盘候选复验。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-150645`，完整候选证据为
`sessions/20260813-150645/evidence/SURF-008-notification-tray-real-app-candidate-r1.md`；录屏
`2784x1808 / 60fps / 1380.481667s` 可读，最终帧保存在该 session 的 `evidence/`。

真实 App 从 Today 28 条通知进入托盘；隔离数据只用一次 REST `mark-read` 制造可辨识读状态，随后真实通知行点击进入精确 Workflow 详情，观察期间托盘与 REST 未读数一致为 27。真实搜索 `SURF007 failure queue 2` 得到 5 条匹配行并将 Today 计数变为 5；重新打开托盘后以真实键盘输入 `zzzz-not-found`，稳定帧只剩搜索栏，分组和通知行消失，中心工作流详情保持不变。Today 组头真实折叠后只剩 `Today 28`，展开后恢复行；Unread only 真实切换并重算加载状态的分组计数。

Computer Use 期间出现过 AX 语义树、Flutter 编辑事件和截图采集时序短暂错位；重开托盘并用真实键盘路径复核后稳定通过，证据将其分类为工具观测问题而非产品缺陷。settled frame 未见 clipping、overlap、stale center、white flash、reflow、overlay 或 input jump。

五通道已封口：backend 无应用级 WARN/ERROR/panic/FATAL，SSE 两 workspace 三流连接并 clean EOF，frontend 无 Dart/Flutter/RenderFlex/overflow/Unhandled/unknown AX 红线，llmtap 真实 readiness/proof/quota 均 `200` 且无 completion，`rig-down` 已停止所有 conductor-owned 进程。通知托盘 focused Flutter suite `50/50` 通过，`rig-check`、`gen_coverage.py --check`、`alarms.py check` 和 `git diff --check` 通过。

本轮仍是候选观察，不调用 `judge.py`，不修改 formal ledger/COVERAGE/anchors/alarms；正式账本 `1790`，清册 `848/351/0 tombstones`，alarms clean，批次三十四 `27/50`。EP-220 当前对象 action-time 永久删除序列门继续关闭。

`SURF-007 shell/notice-band` 已完成真实顶带消息舞台候选复验。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-144241`，完整候选证据为
`sessions/20260813-144241/evidence/SURF-007-notice-band-real-app-candidate-r1.md`；录屏
`2788x1808 / 60fps / 727.596667s` 可读，真实帧保存在该 session 的 `evidence/`。

真实失败 Function → workflow run 让 App 顶带显示失败胶囊；真实 `trigger → approval` run 让 App 显示不自动消失的审批块。fresh AX 每步都重新读取：审批块有可理解的问题、`Approve`、`Reject`，拒绝后真实 run 终态为 `completed / decision=no`。审批驻留期间制造真实失败队列，AX 暴露 `Clear all 4 top notifications`，录屏抽帧看到审批卡居中、右缘两颗队列提示点和 `+1` 溢出。

点击清场后，顶带展示副本按反向动画收回，REST 的 parked approval 没有被删除或自动决策；Notifications 入口显示 `Needs you 1`，同一审批仍可操作。第二个临时 approval 从收件箱拒绝后，两个测试 run 均 `completed`、节点结果均 `decision=no`、`flowrun-inbox` 为空。清场因此验证为“清展示、不改事实”，本轮未发现需要 stop-and-fix 的产品缺陷。

五通道已封口：backend 无应用级 WARN/ERROR/panic/FATAL，SSE 真实收到 `workflow.run_failed` 与 `workflow.approval_pending` 并 clean EOF，frontend 无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 红线，llmtap 仅 readiness/probe 无 completion，`rig-down` 已停止所有 conductor-owned 进程并封口录屏。聚焦回归、文档、清册、警报和 diff 检查在本轮完成后同步记录。

本轮仍是候选观察，不调用 `judge.py`，不修改 formal ledger/COVERAGE/anchors/alarms；正式账本 `1790`，清册 `848/351/0 tombstones`，alarms clean，批次三十四 `27/50`。EP-220 当前对象 action-time 永久删除序列门继续关闭。

`SURF-006 shell/ocean-breadcrumb-head` 已完成真实 Settings 长页标题折叠、紧凑浮层头出现和点击回顶候选复验。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-141915`，完整证据为
`sessions/20260813-141915/evidence/SURF-006-ocean-breadcrumb-real-app-candidate-r1.md`。

Computer Use fresh AX/frame 观察到：顶部态没有紧凑标题；Models & keys 长页小步滚动到大标题离开正文视口后，浮层头出现并可点击；点击后回到页面顶部。一次大步滚动未出现浮层头被保留为过渡/settling 探索，不作为缺陷；受控小步路径稳定重现。录屏 `2788x1808 / 60fps / 539.996667s` 可读，稳定帧已封存，未见 clipping、overlap、stale title、white flash、reflow、overlay 或 input jump。

五通道均已封口：backend 无应用级 WARN/ERROR/panic/FATAL，SSE 两 workspace 三流连接并 clean EOF，frontend 无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 应用红线，llmtap readiness 请求均 200 且无 completion；`rig-down` 已停止所有 conductor-owned 进程。`ocean_breadcrumb_test.dart`、`shell_chrome_test.dart`、`settings_shell_test.dart` 全部通过。

本轮仍是候选观察，不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；正式账本 `1790`，清册 `848/351/0 tombstones`，alarms clean，批次三十四 `27/50`。EP-220 当前对象 action-time 永久删除序列门继续关闭。

EP-220 当前对象 `EP220 Delete Trial` 的确认层候选复验已安全收台，但 action-time 永久删除动作仍未执行。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-140938`，完整证据为
`sessions/20260813-140938/evidence/EP-220-voice-delete-confirm-r6-awaiting-action.md`。

Computer Use fresh AX/frame 确认确认层显示完整对象、永久移除/费用不退还/释放库存位说明、Cancel 和 Delete permanently；空输入未放行。
本轮按不可逆 Computer Use 边界没有输入对象名、没有点击最终按钮，只点击 Cancel；目标行和 `1 of 2 slots free` 保持不变。EP-213
`UI Delete Positive` 的历史确认不转移。

五通道均已封口：录屏 `2784x1808 / 60fps / 244.693333s` 可读，backend 无 voice DELETE，llmtap 无 voice-delete 上游请求，SSE 两 workspace
三流连接并 clean EOF，frontend 无应用级红线，conductor-owned 进程均已停止。本轮仍是候选边界，不调用 `judge.py`，不改 formal ledger/
COVERAGE/anchors/alarms；正式账本 `1790`，清册 `848/351/0 tombstones`，alarms clean，批次三十四 `27/50`。EP-220 序列门继续关闭。

`SURF-005 shell/sidebar-footer` 已完成真实 App 的 workspace 快捷菜单、Settings/Notifications 底栏格、通知托盘接管候选复验，并在首次路径发现产品缺陷后 stop-and-fix、补守卫测试、重新构建真实 App 验证。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-140149`，完整证据为
`sessions/20260813-140149/evidence/SURF-005-sidebar-footer-real-app-candidate-r2.md`。

首轮真实点击 `Workspace settings` 只收起菜单、中心仍停 `Models & keys`；这是产品语义与结果不一致的真实缺陷，不计通过。修复
`frontend/lib/app/app_shell.dart` 让该命令选 `SettingsPanel.workspaces`、清 detail 后进入 Settings，
`frontend/test/app/workspace_switcher_test.dart` 增加回归断言。修复后二次真实 App fresh AX 明确显示 `Settings / Workspaces`、`New workspace` 和当前工作区行，旧 Models & keys 消失。

同一会话还验证 Notifications 格打开/关闭：托盘只替换左岛中段，Settings 中心不变，第二次点击恢复 Settings rail；工作区菜单展开项完整，未观察到 stale menu、重复壳、白闪、clipping、overlap、reflow、overlay 或 input jump。五通道与 `rig-check` 全绿，录屏 `2784x1808 / 60fps / 44.393333s` 可读，抽帧已封存。

修复后 `workspace_switcher_test.dart` `2/2`、SURF-005 focused Flutter suite `93/93`、`git diff --check` 通过。仍是候选观察，不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；正式账本 `1790`，清册 `848/351/0 tombstones`，alarms clean，批次三十四 `27/50`。EP-220 当前 action-time 永久删除序列门仍关闭。

`SURF-004 shell/ocean-switcher` 已完成真实 App 的四海洋切换、Settings 无选中、通知托盘接管和返回 Chat 候选复验。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-134257`，完整证据为
`sessions/20260813-134257/evidence/SURF-004-ocean-switcher-real-app-candidate-r1.md`。

Computer Use 每次操作后 fresh AX 观察到 `Entities → Chat → Entities → Scheduler → Library → Settings → Notifications tray → Chat`。
Chat、Entities、Scheduler、Library 的 rail/center 内容与目的相符；Scheduler 空态提供 `Open Entities` 与 `Open the conversation`；Settings
和通知托盘时四个顶部海洋均收成图标且没有顶部药丸，通知托盘只接管左侧中段，返回 Chat 后托盘关闭。未观察到 stale center/rail、重复壳、
白闪、clipping、overlap、reflow、overlay 或 input jump。

源码实现与观察一致：`app_shell.dart` 在 Settings/托盘路径传 `-1`，`an_ocean_switcher.dart` 使用单共享药丸、固定较宽 resting layout、
token 几何和单一 `AnMotion.mid` forward controller。本轮没有发现需要 stop-and-fix 的产品缺陷。录屏 `2784x1808 / 60fps / 132.210000s`
经 ffprobe 可读，contact sheet 与抽帧已封存；但粗粒度抽帧/scene detector 未可靠隔离 sub-240ms 动画中间帧，因此本轮只证明交互及 settled
geometry，不宣称逐帧动画曲线或 transition latency 的数字证据，该 follow-up 已明确写入证据。

backend/frontend 无应用级红线；ssetap 三流连接并 clean EOF、无该只读路径预期外业务帧；llmtap 仅 readiness、proof challenge/quota、无
completion；frontend 唯一 `IMKCFRunLoopWakeUpReliable` 已分类为 macOS input-host 噪声。台架收台时 conductor-owned App/backend/taps/recorder
均已停止。focused Flutter `51/51`、appproxy/proxycore Go、scope/channel-5 Python `24/24`、文档、清册和 alarms 均通过。

本轮仍是候选观察，不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；正式账本 `1790`，清册 `848/351/0 tombstones`，alarms
clean，批次三十四 `27/50`。SURF-004 不能越过 EP-220 当前对象的 action-time 永久删除序列门写正式五级绿格。

`SURF-002 shell/workspace-gate` 已完成真实 App 的延迟工作区名册候选复验。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-132649`，完整证据为
`sessions/20260813-132649/evidence/SURF-002-workspace-gate-real-app-candidate-r1.md`。

App 通过 conductor 直接启动真实 macOS binary，代理只延迟 `GET /api/v1/workspaces`；首个目标请求
`05:27:16.175969Z→05:28:16.178388Z`，实测 `60.002419s`，后端仍由 `:8927` 直接持有，App 走 `:8790` 代理，
其余请求透明转发。Computer Use/frame 在起始、20 秒、释放前真实看到居中的 `Setting up your workspace...`，
无 shell、旧 workspace、半成品 onboarding 或重复 Router；释放后进入完整 Entities Overview。

测量器给出等待段 `changedFrac=0.00010`（编码噪声级），释放转场 `changedFrac=0.79082`、box=`(112,77)-(2672,1660)`，
ready 稳定帧之间无超过阈值变化；录屏 `2784x1808 / 60fps / 168.611667s` 可读，无白闪、clipping、overlap、reflow、
overlay 或 input jump。backend/frontend 无应用级红线，ssetap 三路连接且无该路径预期外业务帧，llmtap 仅 ready 无 completion。

本轮候选已完成五通道核对、`14/14` workspace 聚焦 Flutter、appproxy/proxycore Go、scope/channel-5 Python `24/24`、
`make -C docs verify`、`gen_coverage.py --check` 和 `alarms.py check`；不调用 `judge.py`，不改 formal ledger/COVERAGE/
anchors/alarms。正式账本 `1790`，清册 `848/351/0 tombstones`，alarms clean，批次三十四 `27/50`。SURF-002 仍是候选，
EP-220 当前对象 action-time 永久删除确认仍未获得。

`SURF-001 shell/startup-gate` 已完成真实 App 的 starting、crashed、Retry、ready 三态候选复验。第一场 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-124951`，第二场 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-125132`，完整证据为
`sessions/20260813-125132/evidence/SURF-001-startup-gate-real-app-candidate-r1.md`。

8 秒延迟场真实看到 `Connecting to the local engine…`，backend ready 后进入完整 Entities Overview；25 秒延迟场真实落入
`Can't reach the local engine` 错误态，AX 暴露 `Retry`，点击后恢复到完整 Entities Overview。崩溃帧和 Retry 后稳定帧分别保存在
`evidence/frames/surf001-crashed.png` 与 `evidence/frames/surf001-ready.png`；后者已确认不是 Retry 前的错误态。两场录像均已
`rig-down` 封口且 ffprobe 可读，owned processes 已清零。

五通道复核无应用级 backend/frontend 红线；三路 SSE 均连接且无启动路径业务帧；llmtap 仅 ready、无 completion。Flutter 聚焦测试
`14/14`、台架 Python 测试 `24/24`、文档校验、清册生成器和 alarms 均通过。本轮仍不调用 `judge.py`，不改 formal ledger/
COVERAGE/anchors/alarms；正式账本 `1790`，清册 `848/351/0 tombstones`，alarms clean，批次三十四 `27/50`。SURF-001
只是候选观察；EP-220 当前对象的 action-time 永久删除确认仍未获得。

EP-257 `GET /debug/stats` 已完成真实 dev backend + App 的 dev-only 运行时快照候选复验，但仍不能越过 EP-220 顺序门写正式裁决。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-123812`，完整证据为
`sessions/20260813-123812/evidence/EP-257-debug-stats-real-app-candidate-r1.md`。

五次连续读取均返回完整 10 字段 JSON，字段均为非负整数，`gomaxprocs/numCPU` 为正，`heapSysMB >= heapAllocMB`，实时对象数按请求自然变化；任意 query string 不改变快照语义。POST `405`，无 `ANSELM_DEV` 的独立 backend `404`。

真实 App、三路 SSE 和前端 console 在读取期间稳定，backend/frontend 无应用级红线，llmtap 无 completion；录屏封口 `52.981667s`，owned processes 已清零。本轮仍不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；正式账本仍 `1790`，清册仍 `848/351/0`，alarms clean，批次三十四仍 `27/50`。EP-220 当前对象仍未获得 action-time 永久删除确认；EP-257 仅形成候选观察。

EP-256 `GET /debug/pprof/trace` 已完成真实 dev backend + App 的 dev-only 执行 trace 候选复验，但仍不能越过 EP-220 顺序门写正式裁决。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-123331`，完整证据为
`sessions/20260813-123331/evidence/EP-256-pprof-trace-real-app-candidate-r1.md`。

显式 `seconds=1` 返回 `24,405` bytes 的 `go 1.25 trace`，`go tool trace -pprof=sched` 和 `go tool pprof -top` 成功解析；`seconds=0.25` 也返回非空 trace，`seconds=0/-1/非法` 按标准库回落到 1 秒。POST `405`，无 `ANSELM_DEV` 的独立 backend `404`。

真实 App、三路 SSE 和前端 console 在 trace 请求期间稳定，backend/frontend 无应用级红线，llmtap 无 completion；录屏封口 `95.851667s`，owned processes 已清零。本轮仍不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；正式账本仍 `1790`，清册仍 `848/351/0`，alarms clean，批次三十四仍 `27/50`。EP-220 当前对象仍未获得 action-time 永久删除确认；EP-256 仅形成候选观察。

EP-255 `GET /debug/pprof/symbol` 已完成真实 dev backend + App 的 dev-only 符号解析候选复验，但仍不能越过 EP-220 顺序门写正式裁决。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-122653`，完整证据为
`sessions/20260813-122653/evidence/EP-255-pprof-symbol-real-app-candidate-r1.md`。

dev GET 对空、未知、零和混合非法地址均返回 `200 text/plain / num_symbols: 1`；从同一进程 CPU profile 取得的 live PC `0x102e4a7ec` 成功解析为 `runtime.(*mspan).heapBitsSmallForAddr`，证明正向符号解析。POST `405`、HEAD `200`，无 `ANSELM_DEV` 的独立 backend 对相同路径 `404`。

真实 App fresh AX/frame 保持 Entities Overview 可读，三路 SSE 保持连接且无业务帧符合只读 debug 路径；backend/frontend 无应用级红线，llmtap 无 completion。录屏封口 `159.461667s`，owned processes 已清零。本轮仍不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；正式账本仍 `1790`，清册仍 `848/351/0`，alarms clean，批次三十四仍 `27/50`。EP-220 当前对象仍未获得 action-time 永久删除确认；EP-255 仅形成候选观察。

EP-254 `GET /debug/pprof/profile` 已完成真实 dev backend + App 的 CPU profile 候选复验，但仍不能越过 EP-220 顺序门写正式裁决。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-121944`，完整证据为
`sessions/20260813-121944/evidence/EP-254-pprof-profile-real-app-candidate-r1.md`。

显式 `seconds=3` 采样在有界 health/workspaces 负载期间返回可解析 gzip pprof：`3.03s / 66 nodes / 50ms samples`，`go tool pprof` 看到实际 backend/sqlite/logger 栈；POST `405`。标准 pprof 的 `seconds<=0` 回落 30 秒已实测并写成台架调用约束（显式正 duration + client timeout），不是静默盖绿。无 `ANSELM_DEV` 独立 backend 对相同路径 `404`。

真实 App、三路 SSE 和前端 console 在采样期间稳定，backend/frontend 无应用级红线，llmtap 无 completion；录屏封口 `179.023333s`，owned processes 已清零。本轮仍不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；正式账本仍 `1790`，清册仍 `848 rows / 351 carried judgments / 0 tombstones`，alarms clean，批次三十四仍 `27/50`。EP-220 当前对象仍未获得 action-time 永久删除确认；EP-254 仅形成候选观察。

EP-253 `GET /debug/pprof/cmdline` 已完成真实 dev backend + App 的 dev-only 观测候选复验，但仍不能越过 EP-220 顺序门写正式裁决。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-121610`，完整证据为
`sessions/20260813-121610/evidence/EP-253-pprof-cmdline-real-app-candidate-r1.md`。

dev GET 返回 `200 text/plain`、body 仅是当前可执行文件路径，无 gateway/proof 环境值；POST `405`。独立无 `ANSELM_DEV` 进程对相同路径返回 `404`，bootstrap dev-only 单测通过。真实 App、三路 SSE 和前端 console 在读取后稳定，backend 无应用级红线，llmtap 无 completion；录屏封口 `56.331667s`，owned processes 已清零。

本轮仍不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；正式账本仍 `1790`，清册仍 `848 rows / 351 carried judgments / 0 tombstones`，alarms clean，批次三十四仍 `27/50`。EP-220 当前对象 `EP220 Delete Trial` 仍未获得 action-time 永久删除确认；EP-253 仅形成候选观察。

EP-252 `GET /debug/pprof/` 已完成真实 dev backend + App 的开发期观测候选复验，但仍不能越过 EP-220 顺序门写正式裁决。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-121053`，完整证据为
`sessions/20260813-121053/evidence/EP-252-pprof-index-real-app-candidate-r1.md`。

`ANSELM_DEV=1` 下 pprof index 返回 `200 text/html` 并列出 10 类标准 Go profile；named profiles、`goroutine?debug=2`、短 CPU profile、trace 均真实 `200`。`/debug/stats` 返回可解析 runtime JSON。独立无 `ANSELM_DEV` 进程中 `/debug/stats` 与 `/debug/pprof/` 均严格 `404`，bootstrap dev-only 单测通过。

真实 App 在 profile/trace 请求期间保持稳定，三路 SSE 接通但无业务帧，backend/frontend 无应用级红线，llmtap 无 completion 符合该本地观测路径。录屏封口 `147.978333s`，owned processes 已清零。一次未加引号 URL 的 zsh glob 错误已与产品结果区分并写入证据。

本轮仍不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；正式账本仍 `1790`，清册仍 `848 rows / 351 carried judgments / 0 tombstones`，alarms clean，批次三十四仍 `27/50`。EP-220 当前对象 `EP220 Delete Trial` 仍未获得 action-time 永久删除确认；EP-252 仅形成候选观察。

EP-251 `GET /api/v1/notifications/stream` 已完成完整 runtime 隔离副本上的真实 App + Notifications tray 候选复验，但仍不能越过 EP-220 顺序门写正式裁决。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-120142`，完整证据为
`sessions/20260813-120142/evidence/EP-251-notifications-stream-real-app-candidate-r1.md`。

真实 App 从通知托盘初始 `Today 9` / REST unread `9` 出发；正式创建
`ep251_notifications_stream_probe` 后，Entities rail 从 2 个 Function 刷新到 3 个，Notifications tray 收到
`function.created` 与 `environment ready`，显示 `Today 11`，REST unread 为 `11`。点击 `function.created` 后中心深链到精确
Function 详情，后端 `:mark-read=204`，REST/SQLite unread/read_at 回到一致的 `10`/已读。总行数与未读数没有混淆，长名称在 rail 内安全省略。

独立 notifications witness 的 durable 序列为 `1 function.created → 2 installing → 3 ready`；installing 无 `inbox`、不落账，其他两条与 REST/SQLite 对齐。三流均连接，entities 相关 build 正常，messages 无业务帧符合 direct Function 路径；backend/frontend 应用红线为 0，llmtap 无 completion 符合本路径不经过 LLM。台架录屏已封口 `230.041667s`，owned processes 已清零。

候选与形式边界保持不变：不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；正式账本仍 `1790`，清册仍 `848 rows / 351 carried judgments / 0 tombstones`，alarms clean，批次三十四仍 `27/50`。EP-220 当前对象 `EP220 Delete Trial` 仍未获得 action-time 永久删除确认；EP-251 仅形成候选观察。

EP-250 `GET /api/v1/entities/stream` 已完成修复台架夹具后的真实 App + Function 调试台候选复验，但仍不能越过 EP-220 顺序门写正式裁决。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-114944`，完整证据为
`sessions/20260813-114944/evidence/EP-250-entities-stream-real-app-candidate-r1.md`。

真实 App 在完整 runtime 基线的隔离 workspace 中创建 `ep250_entities_stream_probe` 后，实体 rail 自动从 2 个 Function 刷新为 3 个；进入新 Function 详情显示 `v1`、`env ready`、Python 3.12。Computer Use 点击右岛 `Run` 后，右岛显示 `Done · 122ms`、Output、Result、Logs 与 Recent `Manual`，结果和日志均为探针预期内容，录屏 `208.976667s / 2784x1808 / 60fps`，未发现 clipping、overlap、reflow、按钮漂移或输入跳变。

独立 entities witness 记录创建的 `build` 生命周期 `open(seq=1) → delta(seq=0) → close(seq=2)`，以及运行的 `run` 生命周期 `open(seq=3) → delta(seq=0) → close(seq=4)`；durable seq `1..4` 连续，两个 delta 保持 ephemeral。notifications durable `1..3` 对齐 `function.created` 和环境 `installing → ready`；messages 没有业务帧，因为直接 Function 调试台不创建 Chat 回合。REST 与 SQLite 同时确认执行 `fne_809a4ee53163ceca`、`status=ok`、`triggeredBy=manual`、`output.status=entities-stream`、`elapsedMs=124` 和日志原文；frontend 应用红线 0，直接 Function 路径无 LLM 请求符合路由事实。

前置复制副本的 `env failed` 已归因并隔离为夹具红：旧副本只有悬挂 runtime 链接；另一端口不匹配由 channel-5 preflight fail-closed。有效重跑使用含真实 Python Mach-O runtime 的完整基线，五通道 `rig-check`/`rig-down` 均通过。

本轮不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；ledger `1790`，COVERAGE `848/351/0`，alarms clean，批次三十四 `27/50`。EP-220 当前对象 `EP220 Delete Trial` 的 action-time 永久删除确认仍未释放序列门；EP-250 目前是候选，不是正式五级绿格。

EP-249 `GET /api/v1/messages/stream` 已完成修复后源码的真实 App + 协议候选复验，但仍不能越过
EP-220 顺序门写正式裁决。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-113400`，完整证据为
`sessions/20260813-113400/evidence/EP-249-messages-stream-real-app-candidate-r1.md`。

真实 App 在现有 workspace 中发送 `Reply with exactly EP-249 stream smoke passed.`；发送后立即出现
`thinking` 和新会话，终态精确显示 `EP-249 stream smoke passed.`，composer、动作区和 transcript 均稳定。
messages witness 的 durable seq 连续 `1..8`，顺序为 `open → delta/close` 对应的 user、assistant、reasoning、
text、message 生命周期；entities/notifications 也保持独立连接，未把没有发生的实体帧算入证据。

只读 SSE 协议复核：`fromSeq=1` 回放 `2..8`；`Last-Event-ID:7` 优先于 `fromSeq=1`，只回放 `8`；非法游标
回到 live-only；缺 workspace 返回 `401 UNAUTH_NO_WORKSPACE`。REST 与 SQLite 同时确认一条 completed user、
一条 `completed/end_turn` assistant 及其 reasoning/text blocks。录屏 `174.295000s / 2784x1808 / 60fps`，
frontend 应用红线 0，llmtap challenge 和四个 chat completion 均 `200`。一次只读 SQLite 探针误用不存在的
列名，未产生写入，随后已按真实 schema 完成核对。

本轮不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；ledger `1790`，COVERAGE `848/351/0`，
alarms clean，批次三十四 `27/50`。EP-220 当前对象 `EP220 Delete Trial` 的 action-time 永久删除确认仍未释放
序列门；EP-249 目前是候选，不是正式五级绿格。

EP-248 `POST /api/v1/executions/{id}:triage` 已完成修复后二进制的真实 App 五通道候选复验，但仍不能
越过 EP-220 顺序门写正式裁决。完整 stop-and-fix 链为：空 body 的 handler `400` → body 可省略修复；
旧 managed install `INVALID_INSTALL` 和 quota 自动 retry 遮蔽 Repair CTA → 显式 repair/retry 修复；
真实 triage 输出中的“a requested function_missing + 孤立反引号”→ triage system prompt 增加 opaque id 原样保留
和 Markdown 成对校对硬约束。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-112345`，完整候选证据为
`sessions/20260813-112345/evidence/EP-248-triage-real-app-candidate-r3.md`。

修复后真实 App 通过 fresh AX 打开既有 `Please diagnose this execution`，重新点击嵌套 `Retry` 才真正
启动回合；最终回答完整保留 `EP-248 Triage Failure Probe`、`boom` 和 `fn_ep248_missing`，根因、
失败证据、结论和下一步均可读，最终 Markdown code spans 成对，无截断 id、孤立反引号、clipping、
overlap、reflow 或 composer 跳变。录屏已封口 `161.148333s / 2784x1808 / 60fps`；messages durable
`1..31`；backend 业务请求只有 `200/202/204`，隔离 fixture 的 lexical fallback/残留 handler env
仅为已解释 INFO；frontend 应用红线 0；真实 llmtap chat completion 响应均 `200`。

本轮不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；ledger `1790`，COVERAGE
`848/351/0`，alarms clean，批次三十四 `27/50`。EP-220 当前对象 `EP220 Delete Trial` 的
action-time 永久删除确认仍未释放序列门；EP-248 目前是修复后候选，不是正式五级绿格。

EP-221 `GET /api/v1/read-aloud/availability` 已完成正负两端真实 App 候选观察，但仍不能越过 EP-220
顺序门写正式裁决。可用态 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-103321`
经真实受管 `llmtap :8805 → https://api.anselm.website`，REST 返回 `available=true`，已有回答的 action row
显示 `Read aloud`，fresh AX/frame 无 clipping、overlap、reflow 或输入跳变；本轮未点击朗读，EP-222 的 TTS
不在本格重复计数。缺席态 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-104154`
使用隔离副本和关闭上游 `llmtap :8807 → http://127.0.0.1:9`，active API key 为 `0`，provision 只留
可解释 warning，REST 返回 `available=false`，真实 App 的回答 action row 隐藏 `Read aloud`，没有空按钮或
错误红屏。两次五通道 conductor session 均正常封口，证据分别为
`sessions/20260813-103321/evidence/EP-221-read-aloud-availability-available-candidate-r1.md` 和
`sessions/20260813-104154/evidence/EP-221-read-aloud-availability-absent-candidate-r1.md`。

本轮仍不调用 `judge.py`；formal ledger `1790`，COVERAGE=`848/351/0`，alarms clean，批次三十四 `27/50`
不变。EP-220 当前对象 `EP220 Delete Trial` 的 action-time 永久删除确认仍未释放序列门。

EP-213 `EP-213 UI Delete Positive` 的用户授权删除已在既有正式 mutation 中完成，本轮由 conductor 使用独立 fixture
`/private/tmp/anselm-data-ep213-ui-positive-20260811-r3` 重新启动真实 App 和完整五通道台架做幂等终态复核。fresh AX/frame 显示
`No cloned voices yet` 与 `2 of 2 slots free`，SQLite 显示两个同名 mock 行均为 `deleted_at` tombstone；目标已不存在，故没有重造对象或
再次发出 DELETE。backend 只有列表读取，LLM wire 只有 ready/proof/quota，三路 SSE 均连接，frontend 无应用级红线，录屏已封口；有效 session
为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-102639`，完整证据为
`sessions/20260813-102639/evidence/EP-213-ui-delete-idempotent-final-r6.md`。本轮不是新的正式五级裁决，不重复计入 formal ledger/COVERAGE。

EP-220 当前对象 `EP220 Delete Trial` 的 r5 真实确认层已复核：正确 workspace、目标名称、库存余量、永久删除文案、精确输入
提示和 `Cancel/Delete permanently` 均在 fresh AX/frame 中完整可见；空输入不放行。本轮没有获得该对象的 action-time 永久删除确认，
因此未输入名称、未点击最终按钮，点击 Cancel 后目标行和库存保持不变。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-100250`，五通道收台正常；backend 无 voice DELETE，LLM wire 仅
proof/quota，SQLite 按实际 `voices` schema 确认目标硬删除前仍存在。候选证据为
`sessions/20260813-100250/evidence/EP-220-voice-delete-confirm-r5-awaiting-action.md`。

本轮不写正式裁决；formal ledger `1790`，COVERAGE=`848/351/0`，alarms clean，批次三十四 `27/50` 不变。EP-220 仍等待
当前对象的 action-time 永久删除确认；EP-213 的历史授权不转移。

EP-213 `EP-213 UI Delete Positive` 的精确对象删除指令已完成幂等收口核验：独立 fixture
`/private/tmp/anselm-data-ep213-ui-positive-20260811-r3` 重新启动真实 App 和完整五通道台架后，fresh AX/frame 与 SQLite
均确认同名目标已处于 `deleted_at` tombstone，当前 Model keys 列表只剩受管 `Anselm Free`。本轮没有恢复对象、没有再次发出
`DELETE`，backend journal 仅有列表读取，LLM wire 仅有 proof/quota，`rig-check`/`rig-down` 均通过。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-095524`，边界证据为
`sessions/20260813-095524/evidence/EP-213-ui-delete-idempotent-reaudit.md`；真实 mutation 仍以既有授权 session 为准。
这不是新的正式五级裁决，不重复计入 ledger/COVERAGE。

EP-221–EP-224 已在真实 App + 受管 `llmtap :8805` 下完成一轮 stop-and-fix 后的非破坏性候选复验：上一轮 SQLite
取证发现 `speech_cache.last_used_at` 对旧行和新行都可能落成 Go 零时间，前线先停下；现已由 `Put` 显式盖当前时间，
并在 bootstrap migration 后幂等把旧零值回填为各行 `created_at`。真实旧库启动后 4 条缓存全非零，既有命中时间保持，
新行也非零。真实 App 的未命中朗读 `Preparing read-aloud… → Read aloud` 和同文本命中均在原动作位稳定收敛，只有一次
上游 `/v1/audio/speech` 请求。有效 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-093429`，
录屏 `173.830000s`，五通道已封口，修复后候选证据为
`sessions/20260813-093429/evidence/EP-221-224-readaloud-capabilities-repair-r1.md`。

本轮不写正式裁决；formal ledger `1790`，COVERAGE=`848/351/0`，alarms clean，批次三十四 `27/50` 不变。EP-220
`EP220 Delete Trial` 的 action-time 永久删除确认仍未释放序列门。

台架自身的通道五接线门已完成 stop-and-fix：`rig-up.sh` 在 ssetap、Flutter 和录制器启动前读取每个已有 workspace
的 managed key，只有无 workspace/无 managed key 才允许 onboarding pending；已有 key 必须精确指向本轮 llmtap，坏响应、
缺地址、错误端口和前缀碰撞直接拒绝启动。判定实现为 `testend/rig/channel5_wiring.py`，`rig-check.sh` 复用同一实现；
8 个边界单测、shell 语法检查和 `git diff --check` 已通过。本次是台架修复，不改变 formal ledger、COVERAGE、anchors、
alarms 或批次计数。

EP-220 当前对象 `EP220 Delete Trial` 已在正确持久化网关接线 `llmtap :8805` 下完成真实确认层复核，但仍未收到该对象的
action-time 永久删除确认。有效 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-085330`，录屏
`291.678333s` 可读；五通道自检、quota `200`、目标 SQLite 保留和“无 voice DELETE”均已封口。确认层证据为
`sessions/20260813-085330/evidence/EP-220-voice-delete-confirm-r4-awaiting-action.md`。

本轮没有点击 `Delete permanently`，不写正式裁决；formal ledger 仍 `1790`，COVERAGE=`848/351/0`，alarms clean，批次三十四仍
`27/50`。前一次错误使用 `8796` 的 session 已由 `rig-check` 拒收并正常收台，不能作为产品证据。EP-213 的历史授权不转移到 EP-220。

EP-243–EP-247/EP-251 通知中心 r12 已完成真实 App、Computer Use、backend/frontend journal、三路独立 SSE witness 和
真实受管 llmtap 的产品路径观察：单条已读导航、Unread only、Today 折叠/展开、组头批量已读均完成，UI/REST/SQLite
未读真相一致。有效 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-082016`，录屏
`653.243333s / 2784x1808 / 60fps`，候选证据和 stable frame 已封存。formal ledger 仍 `1790`，COVERAGE=`848/351/0`，
alarms clean。

EP-223 `GET /api/v1/model-capabilities` 的 r11 已在新二进制上完成真实 App、Computer Use、backend/frontend journal、
三路独立 SSE witness 和真实受管 llmtap 的修复后复验：Dialogue 选择器完整显示 `Anselm Auto / Gateway-managed`，
无 ellipsis/reflow，真实 Anselm Auto 对话精确完成。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-080900`，录屏 `286.278333s / 2784x1808 / 60fps`。
五通道均已封口，formal ledger 仍 `1790`，COVERAGE=`848/351/0`，alarms clean。

EP-220 当前对象 `EP220 Delete Trial` 只完成非破坏性确认层边界复验，仍等待该对象的 action-time 永久删除确认；
已删除 EP-213 的历史确认不转移。批次三十四现为 `27/50`，未到 50 格前不运行统一长门禁、不提交；所有真实观察仍是
按序待入账候选，不把候选观察冒充正式五级裁决。EP-213 本轮精确对象授权删除已由真实 App 完成并重启复核，但属于已绿
单元的授权闭环，不重复计格；批次三十四现为 `27/50`。

### 最新 stop-and-fix：EP-243–EP-247/EP-251 通知中心 r12 真实观察

真实 App 通过受管网关创建两个 Function 并产生四条通知。点击 beta 行后，该行标记已读并深跳到 Function；Unread only
从四行收敛为三行；Today 组折叠/展开保持组头；hover 组头的 `More actions` 提供 `Mark all read / Mark all unread`，
执行后 UI、`GET /notifications/unread-count` 和 SQLite 都为 `unread=0`，审计行不消失。session
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-082016` 的 durable SSE 为 messages `1..40`、entities
`1..8`、notifications `1..8`，llmtap 有 18 个 HTTP 200；frontend/backend 无应用级红线，AX stale-node 依本 session
review 分流。`rig-check`/`rig-down` 通过，候选全文为 `sessions/20260813-082016/evidence/EP-243-247-251-notification-center-r12.md`。

本轮不调用 `judge.py`、不改 formal ledger/COVERAGE/anchors/alarms；正式账本 `1790`、清册 `848/351/0`、alarms clean，
批次由 `26/50` 推进到 `27/50`。EP-220 仍是当前破坏性序列门，不能套用 EP-213 授权。

### 最新授权闭环：EP-213 UI Delete Positive

用户明确确认的精确对象为 `EP-213 UI Delete Positive`。真实 App 在正确 workspace 的新鲜 AX/frame 中重新核对
`This deletes “EP-213 UI Delete Positive” permanently.` 后点击最终 `Delete`；列表和重启后列表均不再出现目标。backend
记录 `DELETE .../aki_b67e840525785925=204`，重复 DELETE=`404 API_KEY_NOT_FOUND`，SQLite tombstone 保留身份但清空
密文/probe 材料。第一次复用夹具的 session 因持久化 `8788` 与新 tap `8794` 不一致被 `rig-check` 拒绝，未伪造全通道绿；
随后用持久化 `8788` 重启，完整 `rig-check` 通过并完成 post-delete 复核。证据为
`sessions/20260813-083330/evidence/EP-213-ui-delete-authorized-rerun.md`。不重复正式裁决、不推进批次、不外推授权。

EP-223 `GET /api/v1/model-capabilities` 的 r10 已完成真实 App、Computer Use、backend/frontend journal、
三路独立 SSE witness 和真实受管 llmtap 的模型目录、刷新、模型选择器与真实聊天路径复验：唯一受管能力项、
UI、REST、SSE、LLM wire、SQLite/消息与前端画面一致，正式五级按序待入账。EP-220 当前对象
`EP220 Delete Trial` 的 r3 已完成非破坏性危险边界复验，但永久删除 action-time 确认尚未收到；不能使用已删除
EP-213 的历史确认。formal ledger `1790`，COVERAGE=`848/351/0`，批次三十四 `25/50`。EP-222 r9、
EP-243/EP-244/EP-251 r8、EP-221 及其他真实观察保留为按序候选，不提前写正式账本。

本页是持久 Goal 的执行协议。Goal 保存不可变的最终目标与完成定义；本页规定每次 loop 唤醒时只做
什么；`README.md`、`LOG.md`、`COVERAGE.md`、`JOURNEYS.md`、`CODEX.md`、`ANCHORS.md` 和
`testend/rig/README.md` 保存规则、前线、证据账和台架操作事实。三者不互相复制长清单。

## 批次边界

`BATCH_SIZE = 50`，单位是 COVERAGE 中的**单格裁决**，不是旅程数量，也不是“看起来测过”的页面数。
每一格仍必须独立具备真实用户路径、五通道证据、适用法条/测量值和产品判断；发现问题仍在当格立即
冻结、修复、复验和同类横扫，不能把缺陷拖到批次末尾。只有累计完成第 50 格后，才统一执行一次：
收台封存录像、`alarms.py check`、完整 `make verify`、完整 `go test ./...`、已修场景回归、工作树
审计和 git commit。批次中允许运行针对单个修复的快速守卫测试，但不重复执行这套长门禁。

批次计数写入 `LOG.md`。跨上下文恢复先读取批次计数；若上一次在批次中途结束，继续同一批，不重置
计数、不提前提交。第一批可以包含当前已完成但尚未提交的 Day 0 台架与协议建设，提交时一并固化。

### 账本作用域门

`rig-up.sh`、`rig-check.sh`、`rig-down.sh`、`judge.py`、`alarms.py` 和 `anchors.py` 是验收台架入口，必须在
同一 shell 中显式绑定绝对 `RIG_HOME`；缺失、相对路径和 `~` 路径均 fail-closed，不能回落到个人默认目录。
只有 `--help` 这种只读用法不要求台架作用域。此前一次未绑定作用域的健康检查误读了个人默认账本，已作为
仪器审计记录，不计入产品裁决；formal ledger、阈值、锚点和 COVERAGE 均未被改写。入口行为由
`testend/rig/test_scope.py` 覆盖，不能依赖操作者记忆。

## 历史状态快照（2026-08-13 08:40，已被上方当前声明取代）

以下内容保留用于审计追溯；其中的“当前前线”、EP-220 待确认和批次计数均不再是执行依据。

### 最新 stop-and-fix：Anselm Auto 二级文案修复后 r11 真实五通道收口（2026-08-13 08:16）

EP-223 r10 的真实画面发现 `Gateway-managed routing and reasoning` 在固定单行 meta 轨道中被截断；现已收紧为英文
`Gateway-managed`、中文「网关托管」，并同步源文案、生成物、文档和测试。r11 session
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-080900` 用真实 App 完成 onboarding、打开 Dialogue
选择器，AX/frame 均确认完整文案；再经 Anselm Auto 真实网关完成精确回复 `EP-223 R11 smoke passed.`。录屏
`286.278333s / 2784x1808 / 60fps`，持久帧为 `evidence/frames/ep223-dialogue-picker-r11.png`、
`ep223-chat-r11.png`。

backend、SSE、llmtap、SQLite 与 frontend console 交叉核对一致：challenge/install/models/quota 与 chat completion 全
`200`；messages durable `1..8`、notifications `1..2` 单调，entities 已连接；消息持久化为 completed、provider/model
为 `anselm/anselm-auto`、assistant output tokens=`47`；frontend 只有正常 runner/DevTools/已知 IMK 宿主噪声，
应用级 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception marker 为 `0`。`rig-check`、`rig-down` 均通过并已清零 owned
进程。本轮只形成候选，不调用 `judge.py`、不改 formal ledger/COVERAGE/anchors/alarms；批次由 `25/50` 推进到 `26/50`。

### 最新 stop-and-fix：Anselm Auto 受管模式二级文案必须完整可读（2026-08-13 08:05）

EP-223 r10 的真实模型选择器画面显示，`Gateway-managed routing and reasoning` 在 `AnRow` 的固定单行
meta 轨道中被省略号截断。虽然没有产生 Flutter overflow，但这违反产品模式身份完整可读的 craft bar。已直接
收紧为英文 `Gateway-managed`、中文「网关托管」，同步 i18n 源、slang 生成物、设置参考和可见性测试；
定向 `s2_models_keys_test.dart` 22/22、Dart format 与 `git diff --check` 通过。下一步用新构建做完整五通道
EP-223 r11 真实复验，确认没有省略号、reflow、布局漂移或错误状态；正式账本/COVERAGE 仍冻结。

EP-213 本轮只打开真实确认层并点击 `Cancel`：对象名和永久性文案精确匹配，但没有输入名称或点击最终 `Delete`，
没有任何目标 DELETE，台架已正常收台。正式 ledger/COVERAGE/anchors/alarms 和批次三十四 `25/50` 保持不变。

### 最新补充：EP-223 `GET /api/v1/model-capabilities` r10 真实五通道候选复验（2026-08-13 07:38）

- 有效 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-072852`，数据目录为 `/private/tmp/anselm-data-ep223-capabilities-20260813-r10`，workspace=`ws_fef1b753c43faaa7`。全新数据目录由真实 App 完成 onboarding 创建 workspace；Settings → Models & keys 显示受管免费档、配额、受管 key、六个场景默认槽位和 `Refresh model list`，刷新后保持稳定。
- Dialogue 的 Change 和聊天头部 Auto 菜单均只显示真实的 `Auto` 与 `anselm-auto · Anselm Free`；没有虚假模型或不可用旋钮。真实发送 `Reply with exactly EP-223 R10 smoke.` 后得到 `EP-223 R10 smoke`，聊天完成帧中 user bubble、assistant 文本、动作行和 composer 对齐，无 clipping/overlap/reflow/按钮漂移/输入跳变。持久帧为 `evidence/frames/ep223-settings-r10.png`、`ep223-chat-r10.png`、`ep223-model-menu-r10.png`。
- REST `/api/v1/model-capabilities=200` 的唯一项为受管 `anselm/anselm-auto`，能力胶囊为 `vision=true/video=true/tools=true/knobs=null`，原始响应为 `evidence/model-capabilities-rest.json`；backend 无应用红线。SSE messages durable `1..8`、notifications `1..2`，entities 已连接无 durable mutation，seq=0 delta 不推进游标，三流无 gap。llmtap challenge/install/models/quota 与两次 chat completion 全 `200`；frontend 仅已知 runner/IMK 宿主噪声，应用级 marker 为 `0`。
- 完整候选证据为 `sessions/20260813-072852/evidence/EP-223-model-capabilities-r10-current-candidate.md`。本轮不调用 `judge.py`、不修改 formal ledger/COVERAGE/anchors/警报阈值；账本 `1790`、清册 `848/351/0`、alarms clean、批次三十四 `25/50`。EP-220 当前对象 action-time 永久删除确认仍未完成，EP-213 历史确认不外推；序列门释放后才按 CODEX 逐格复审。

### 最新补充：EP-220 当前对象非破坏性边界复验 r3（2026-08-13 07:24）

- 有效 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-072031`，数据目录为 `/private/tmp/anselm-data-ep220-voice-delete-20260812-r2`；真实对象为 `EP220 Delete Trial`，workspace=`ws_4389dec386259764`。conductor 托管真实 App、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness 和真实受管 `llmtap`；`rig-check` 前后通过，`rig-down` 正常收台，录屏 `138.095000s / 2784x1808`。
- Cloned voices 显示 `EP220 Delete Trial`、`1 of 2 slots free`、`Delete`；危险层完整显示永久移除、费用不退还、释放库存位和精确输入提示。空输入时 `Delete permanently` 禁用；点击 `Cancel` 后危险区收起，目标行和库存不变。持久确认层帧为 `evidence/frames/ep220-confirm-r3.png`。
- backend 只有 `GET /api/v1/voices=200`，无 voice DELETE；llmtap 无 voice-delete；两个 workspace 的三路 SSE 仅连接、无实体 durable 变更；frontend journal 19 行，应用级异常 marker 为 0。REST/SQLite 目标音色仍存在、未产生 tombstone。
- 完整证据为 `sessions/20260813-072031/evidence/EP-220-voice-delete-boundary-r3.md`。这轮不调用 `judge.py`、不修改 formal ledger/COVERAGE；正式账本 `1790`、清册 `848/351/0`、alarms clean、批次三十四 `25/50`。当前对象的永久删除仍等待明确 action-time 确认。

### 最新补充：EP-222 Read Aloud r9 真实路径复验（2026-08-13 07:13）

- 有效 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-070347`，数据目录为 `/private/tmp/anselm-data-ep222-readaloud-20260813-r9`；workspace=`ws_dee542a1628a82f3`，conversation=`cv_331c44605a891767`。conductor 托管真实 App、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness 和真实受管 `llmtap`；`rig-check` 前后通过，`rig-down` 正常收台，录屏 `211.478333s / 2784x1808 / 60fps`。
- 真实点击 `Read aloud` 后，AX 立即报告 `Preparing read-aloud…`；固定动作槽位的 spinner 帧已固化为 `evidence/frames/ep222-r9-preparing.png`，没有跳变、重排、裁剪或按钮漂移。合成完成后同槽位为 `Stop`，停止回到 `Read aloud`；再次点击进入播放态但没有再次合成。稳定帧为 `ep222-r9-90s.png`、`ep222-r9-105s.png`、`ep222-r9-195s.png`，候选全文为 `evidence/EP-222-read-aloud-r9-current-candidate.md`。
- backend read-aloud 请求为 `200/13976ms` 与 `200/0ms`；llmtap 仅有一次 `/v1/audio/speech`，响应 `200`、`1286444` bytes。第二次 REST 返回 `cached:true` 并复用同一 attachment；SQLite 的 speech cache、attachment 与 UI 一致。messages SSE durable=`[1..8]`，notifications=`[1,2]`，entities 已连接但本轮无实体 durable 帧，三流无 gap。
- frontend journal 共 18 行，应用级异常 marker scan 为 0；仅剩正常 runner、macOS IMK 宿主噪声和收台行。定向 read-aloud/attachment/http handler Go tests 通过。
- r9 只形成候选观察，不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/警报阈值；账本 `1790`，清册 `848/351/0`，alarms clean，批次三十四 `25/50`。EP-220 当前对象尚未获得动作时确认，因此没有执行删除，EP-213 的历史确认不转移；序列门释放后才按证据逐格入账。

### 历史补充：EP-243/EP-244/EP-251 r8 环境失败重建路径真实复验（2026-08-13 06:57）

- 有效 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-064314`，数据目录为 `/private/tmp/anselm-data-ep243-env-copy-fix-20260813-r8`；conductor 托管真实 Flutter App、Computer Use、窗口录制、backend journal、frontend console、三路独立 SSE witness 和真实受管 `llmtap`。`rig-check` 前后均通过，`rig-down` 正常收台，录制时长 `634.308333s`。
- stop-and-fix 只收紧工具契约与 AI 引导：失败环境且定义不变时，`edit_handler`/`edit_function` 必须用 `ops: []`，`restart_handler` 明确只重置 ready resident、不安装环境。真实 Handler 与 Function 的自然语言请求均产生匹配 `edit_*`，没有 `restart_handler`，不铸新版本；三次有界安装失败后，SSE、REST、SQLite、实体终端和用户回复保持失败真相一致，没有 `handler.env_rebuilt`/成功假象。
- Handler 最终为同一 v1、`envStatus=failed`、`runtimeState=stopped`、`configState=ready`；Function 最终为同一 v1、失败环境，代码/依赖/config 不变。App 画面显示人话失败摘要、下一步和尝试结果，而不是暴露原始 SDK/URL；这证明“失败可行动且诚实”，不把失败环境判成功。
- frontend console 最终 `1,256` 行，其中 `1,238` 行为已知 accessibility bridge stale-node 形态，未知 AXTree 形态为 `0`；最后一次 Computer Use 交互后静置 5 秒无增长，没有 Dart/Flutter/RenderFlex/overflow/unhandled/panic。一次早期仪器误触 Handler `Call method` 后立即取消，仅产生失败 ping 且无实体变更，保留为操作噪声而不纳入产品路径结果。
- 本轮只形成候选观察，不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/警报阈值；formal ledger `1790`，清册 `848/351/0`，alarms clean，批次三十四 `25/50`。当前仍等待 EP-220 `EP220 Delete Trial` 的动作时确认和 EP-220→EP-221 序列释放；不能把已删除 EP-213 的历史确认外推到 EP-220。

## 历史前线快照（2026-08-13 05:55，以下 r6 候选内容保留用于追溯）

### 最新补充：EP-243/EP-244/EP-251 环境失败终态与重建路径修复后真实复验（2026-08-13 05:55）

前置红 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-042809` 已证明耐久终态正确，但逐帧发现主 Callout 把 `sandboxapp.EnsureEnv`、GitHub runtime URL 和 `context canceled: runtime install failed` 作为主文案；该红证据为 `sessions/20260813-042809/evidence/EP-243-244-251-handler-env-raw-error-red.md`，不计绿。

修复包括共享 `EnvironmentFailure` 人话/下一步投影、主动 `Technical details` 原错展开与 4000 字符上限，以及 Handler 空 ops/代码编辑只允许一个有界环境 build；新环境失败时停止旧 resident，避免重复 install/spawn 和旧类继续服务。r4 的重复 rebuild 红证据为 `sessions/20260813-052238/evidence/EP-243-244-251-handler-duplicate-rebuild-red.md`。

r5 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-053930` 发现 utility 的“解释文字 + fenced JSON”没有被旧 `parseDeps` 消费，红证据为 `EP-243-244-251-envfix-fenced-response-red.md`。已修复为候选顺序解析整段、fenced block 和 prose 中平衡 JSON 对象，并复用 `jsonrepair` 清理尾逗号；新增 envfix/jsonrepair 回归，坏响应仍诚实失败。

r6 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-054714` 真实复验：Function 一次空编辑最终 failed；Handler 一次空编辑最终 `failed/stopped/ready`，约 16.6s；单一 entities build block 内出现 attempts 1–3 和一次 `handler.env_rebuilt`，没有第二 build block、重复 resident spawn 或 parser warning。五通道均有记录：Computer Use 收起/展开态与 AX 状态完整，SSE/SQLite/REST 一致，backend action window 无 workspace/panic/parser 红线，llmtap challenge/completions 全 200，frontend marker scan 无 Flutter/Dart/RenderFlex/Unhandled/assertion。

`screen.mov` 封口为 `168.361667s / 2784x1808 / 60fps`；末尾黑帧属于 rig-down 后的非产品画面，稳定 Computer Use 截图临时文件在会话结束后清理，因此不伪造持久 PNG，证据以当时的 AX/截图观察和过程录像为准。r6 是产品绿候选，不是正式账本绿。

正式事实不变：未调用 `judge.py`，formal ledger `1790`，COVERAGE=`848/351/0`，alarms clean，批次三十四 `25/50`；EP-220/EP-221 序列门仍在前。

### 最新补充：EP-234–EP-242 系统、网络、保留与存储真实观察完成（2026-08-13 03:18）

有效 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-030420` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness 和真实受管 llmtap；workspace=`ws_e1b28e8f091e830c`。录屏已封口 `744.840000s / 2784x1808 / 60fps`，`rig-check` 前后通过，`rig-down` 后 owned processes/listeners 归零。证据为 `sessions/20260813-030420/evidence/EP-234-242-system-storage-real.md`，Storage/About 原尺寸稳定帧已独立抽取复核。

真实 App 完成 Storage & logs、Network、About。Network 通过真实表单写入临时 `example.test`，再用真实键盘清空保存；最终 UI、REST 和 `settings.json` 均为 `network={}`。Retention 真实往返 `90 → 30 → 90`，UI/REST/配置文件最终一致，三段 settings 未丢失。Compact database 真实点击返回 `reclaimedBytes=0,migrated=false`，storage-stat 和 SQLite 页计数不变；About 显示 App `0.1.0`、Engine `dev`。抽帧无 clipping、overlap、reflow 或按钮漂浮。

后端健康、frontend 应用红线、三路 SSE 和受管 llmtap 均符合台架要求；无 workspace 探针得到 `401 UNAUTH_NO_WORKSPACE`，带正确 workspace 后系统读面均为 `200`。Focused Flutter `32/32`、backend 定向套件、`git diff --check` 通过；formal alarms=`clean (1790)`，清册=`848/351/0`。

该轮是“真实观察完成、正式五格待序入账”，未调用 `judge.py`，未改 formal ledger/COVERAGE/anchors/警报阈值；批次三十四保持 `25/50`。下一步准备 EP-220 当前对象的 action-time 确认；EP-213 的历史对象授权不外推到 EP-220。

### 最新补充：EP-226/227 关系邻域与全图真实路径修复后完成观察（2026-08-13 02:47）

首个冷启动 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-023718` 暴露 `depth` query 的产品契约缺陷：参数存在但为 `foo`/`1.5` 时静默按默认深度处理并返回 `200`，错误会伪装成空邻域。该 session 不计绿；已冻结并修复 HTTP 解析，缺席默认 `2`，出现时必须是单个十进制整数，空/重复/浮点/文字返回 `400 INVALID_REQUEST`，范围外仍返回 `400 REL_DEPTH_LIMIT`；新增 handler 单测并同步 API/domain 文档。

修复后二进制有效 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-024157` 的 REST 证据为：缺省/1/2/3 正常返回，`0/4` 为 `REL_DEPTH_LIMIT`，`foo/1.5/空` 为带 `param/depth/got/want` 的 `INVALID_REQUEST`，`GET /relgraph` 返回 `4 nodes / 2 hydrated edges`。真实 App 走完 Overview -> Explore -> greet -> `REFERENCED BY deploy-helper` -> Skill `EQUIPS greet` -> provenance -> Document 隐藏/恢复 -> Fit；隐藏端点时节点、标签和相连边闭合消失，恢复后完整图回归，未发现新的产品红线。稳定帧是 `sessions/20260813-024157/evidence/ep226-227-provenance.png` 与 `ep226-227-final-graph.png`，全文证据是 `EP-226-227-relations-observed-fixed.md`。

五通道已封口：录屏 `243.980000s / 2784x1808 / 60fps` 可读，rig-check 前后通过并正常收台；backend 无 WARN/ERROR/panic/FATAL，frontend 无应用级 Flutter/Dart/RenderFlex/Unhandled/Exception 红线，SSE 三流接通，llmtap challenge/install/models 全 `200`。relation handler/app/domain 与关系图/总览/widget 定向测试通过；`gen_coverage.py --check`=`848/351/0`、formal alarms=`clean (1790)`、diff check 通过。

EP-226/227 仍按 EP-220/EP-221 序列门不调用 `judge.py`、不修改 formal ledger/COVERAGE；账本 `1790`、清册 `848/351/0`、批次三十四 `25/50` 保持不变。正式入账前不能宣称五格绿。

### 最新补充：EP-228/229 catalog 与工具目录真实路径（2026-08-13 02:30）

正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-021557` 已完成真实 App + 受管 gateway + Computer Use
的 EP-228/229 产品路径。新建 `catalog-lab-skill-r3` 的修复后 ASCII 请求只产生一次 `create_skill`，App、Library、REST、
SQLite 事实和 `skill.created`/touchpoint SSE 信号一致；`GET /api/v1/catalog` 返回 summary 与 structured coverage，
`GET /api/v1/tools` 返回 117 个 descriptor。真实打开 Skill properties 的 `Add a tool` 弹窗，Builtin 分组与 name/summary
可读，视觉证据为 session `evidence/ep228-skill-detail.png` 和 `ep229-tool-picker.png`。

首试的输入观察器破坏了中文/引号和 `create_skill` 下划线，导致缺 description 与 absent-skill 错误路径；这份红证据保留，
没有把失败伪装成绿。stop-and-fix 加强 chat critical rule 与 create_skill tool description 的新建意图消歧，补 chat/skill
contract tests 和领域文档；修复后成功路径只调用一次、没有 retry/search/activate/edit。picker 搜索因 `type_text`/`set_value`
的 Computer Use 输入语义限制不计产品结论，完整 picker suite `7/7` 通过。

五通道封口：live `rig-check` 全绿，`rig-down` 正常收台，录屏 `758.688333s / 2784x1808 / 60fps`；messages `1..37`、
entities `1..2`、notifications `1..3` durable 序列连续；llmtap observed responses 全 `200`；frontend 无 Flutter/Dart/
RenderFlex/overflow/Unhandled/Exception 应用红线，backend 仅两条已解释负路径 WARN。完整证据为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-021557/evidence/EP-228-229-catalog-tools-observed-fixed.md`。

EP-228/229 仍按 EP-220/EP-221 序列门暂不调用 `judge.py`、不改 formal ledger/COVERAGE；账本 `1790`、清册 `848/351/0`、
alarms clean、批次三十四 `25/50` 不变。正式入账前不能宣称五格绿。

### 最新补充：EP-230–233 限额真实 App 路径与 stop-and-fix（2026-08-13 01:56）

首轮限额真实 session `20260813-013937` 暴露一次回车造成两次相同 `PATCH /api/v1/limits` 的产品缺陷；根因是 `_LimitRow`
同时自定义 `onSubmitted` 与 `onEditingComplete` 调用 `_commit()`。stop-and-fix 保留 `onSubmitted`、恢复 Flutter 默认
`editingComplete` 行为，点按移出仍显式提交；fixture 增加 PATCH 计数，`s5_storage_limits_test.dart` 锁定一次 done 只有一次
PATCH。定向 Flutter suite `12/12`、focused analyze 全绿。

修复后二进制真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-015207` 完成 onboarding → Settings
→ Advanced limits；Computer Use 逐帧确认机器级说明、Reset all、五组和 18 个 schema 字段，修改 `agent.maxSteps` 到 `32`
后按一次回车，画面稳定显示 modified 状态。backend 精确记录一条 `PATCH=200` + 权威 GET；Reset all 的确认文案为
`Reset every limit to its default?`，确认后精确一条 `POST :reset=200` + 权威 GET 恢复 `25` 等默认值。

五通道封口：backend `290` 行无应用红线，frontend `20` 行无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 产品红线，
ssetap 接通三流，llmtap proof/install/models 全 `200`，`rig-check` 五通道通过，录屏 `216.715000s / 2784x1808 / 60fps`
可读。完整证据为 `sessions/20260813-015207/evidence/EP-230-233-limits-real.md`，稳定帧为该 session 的
`limits-top-fixed.jpg` 和 `limits-tail-fixed.jpg`。

该观察覆盖 EP-230–233，但正式序列仍由 EP-220/EP-221 占住；不调用 `judge.py`、不改 formal ledger/COVERAGE，账本 `1790`、
清册 `848/351/0`、alarms clean、批次三十四 `25/50` 保持不变。`20260813-013331` 的 seed 卡住仅作为台架启动边界保留。

### 最新补充：EP-224 场景枚举真实 App 五通道路径（2026-08-13 01:25）

新隔离 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-011852` 使用真实 App、受管 gateway、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness 和 llmtap。Settings → Models & keys 的 Scenario default models 真实画面逐帧显示六个 canonical 槽位：Dialogue、Utility、Agent、Image generation、Speech synthesis、Video generation；六个 Change 入口、生成场景说明和尾部 Search keys 均完整可读，无 clipping、overlap、overflow 或 reflow。录屏 `135.281667s / 2784x1808 / 60fps`，稳定终帧 `ep224-final-scenarios.png`。

同一 session 的 REST 交叉核对：有/无 workspace 的 `GET /api/v1/scenarios` 都是 `200`，恰返回六项 `dialogue, utility, agent, image, speech, video`；`POST` 是 `405 METHOD_NOT_ALLOWED`，`Allow: GET, HEAD`。五通道封口为 backend `220` 行无应用红线、frontend `18` 行仅已知 launcher 噪声、ssetap 三流接通、llmtap proof/install/models/quota `200`；GET-only 路径没有伪造 completion。证据 `sessions/20260813-011852/evidence/EP-224-scenarios-real.md`。

EP-224 真实观察没有发现产品缺陷；同步把设置 panel 的过时“三行”注释修正为六行，并由抽取清册生成器同步 `COVERAGE.md` 的 EP-224 六槽描述。按序暂不调用 `judge.py`、不修改 formal ledger、不改变 `COVERAGE` 五格 verdict，仍保持 `1790`、`848/351/0`、alarms clean、批次三十四 `25/50`；EP-220/EP-221 序列门先处理。

### 最新补充：EP-225 关系图真实五通道路径与 stop-and-fix（2026-08-13 01:03）

静态路径覆盖 `/api/v1/relations`、`/relations/neighborhood`、`/relgraph` 及前端总览/全页探索/右岛关系 pill。首轮真实 session `20260813-004244` 发现：涟漪透明度误伤远端实体标签；图例隐藏节点后仍留下相连边；热重载新增 painter 字段时还出现旧实例 `Null` 异常。三项均停下修复，关系图专测现为 `15/15`：点/边过滤闭合、标签不继承点 alpha、CustomPainter 隐藏/边签名可触发重绘，旧字段 nullable 兼容热重载过渡。

全新数据目录冷启动有效 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-005927` 已用 Computer Use 完成总览、全页图、节点选择、关系跳转、provenance、Fit、返回和详情入口；隐藏 Document 的真实画面/AX 树无残边，恢复后图完整。四个关系 REST 响应与 UI/SQLite 对齐，录屏 `115.818333s / 2784x1808`，前后 rig-check 通过，frontend/backend 无应用红线，llmtap 6 个响应全 `200`，三路 SSE 连接；证据 `sessions/20260813-005927/evidence/EP-225-relations-real.md`。失败 session 不计绿且保留作仪器边界。

EP-225 尚未调用 `judge.py` 或修改 COVERAGE，因 EP-220/EP-221 序列门尚未收口；formal ledger `1790`、清册 `848/351/0`、alarms clean、批次三十四保持 `25/50`。继续按序，不提前把真实观察写成正式五级裁决。

### 最新补充：EP-224 场景枚举六槽门禁补强（2026-08-13 00:41）

`GET /api/v1/scenarios` 的 domain/handler 已提供六项，但原黑盒测试只检查前三项，存在新增生成槽静默漏测风险。现已收紧
为恰好六项及 canonical 顺序 `dialogue, utility, agent, image, speech, video`，并同步 handler 注释与 API 文档；gofmt、diff check、
后端 handler/domain 单测和 `TestPlatform_ModelConfig` 全绿。EP-224 仍未进行真实 App/五通道验证，formal ledger、COVERAGE、警报和批次计数不变。

### 最新补充：EP-223 last-good 组件守卫与语音 fail-closed 回归（2026-08-13 00:37）

EP-223 的三态实现再收紧一层：`ModelPickerPanel` 自身只在 `caps` 为空时显示 loading/error，已有能力目录在刷新
期间仍保留可操作的 key/model；新增 loading/error + 非空 last-good widget 回归。语音输入用 pending/error provider 状态回归确认
fail-closed：未成功读取匹配的 `anselm-auto` 能力时不亮录音入口。相关完整串行套件 `83/83`、`flutter analyze`、Dart format、
`git diff --check` 全绿。该补强尚未写 formal ledger/COVERAGE，账本 `1790`、清册 `848/351/0`、警报 clean、批次三十四仍 `25/50`。

### 最新补充：EP-223 模型能力目录三态修复与真实台架（2026-08-13 00:30）

静态审计发现 `modelCapabilitiesProvider` 的 loading/error 被设置、聊天头部和重试菜单的 `.value ?? []` 吞掉，
后端故障会伪装成“没有模型/添加 key”。stop-and-fix 已把共享消费契约收紧为：成功空数组才是 settled-empty；已有目录
刷新失败展示 last-good；首次加载失败展示可读错误和单一 Retry；聊天菜单仍保留 Auto、当前回合操作与刷新入口。
对应设置/聊天 i18n、widget 回归和模型选择契约已同步；串行定向回归 `73/73`，`flutter analyze` 和 Dart format 通过。
语音输入在能力未知时仍 fail-closed，不虚报可用。

真实 App 第一轮 session `20260813-001238` 完成 onboarding、Models & keys、刷新、Chat、受管网关聊天和 Retry 菜单；第二轮有效
session `20260813-002350` 复用 workspace 验证能力/默认一致性和 `Anselm Auto · Gateway-managed routing and reasoning` 边界。
两轮五通道由 conductor 托管，`/model-capabilities=200`，聊天 wire=200，messages durable seq `1..8` 单调，SQLite/UI 对齐，
前端无应用级红线。`20260813-002140` 因复用数据目录的持久化 tap 仍为 `8788`、临时 tap 起在 `8794` 被 `rig-check` 正确排除。
真实证据在两个 session 的 `evidence/EP-223-*` 文件；该产品证据尚未写 formal ledger/COVERAGE，正式账本仍 `1790`，清册
`848/351/0`，警报 clean，批次三十四仍 `25/50`，继续等待 EP-220/EP-221 序列门。

### 最新补充：EP-213 已授权对象删除与确认原语代际守卫（2026-08-12 23:45）

用户明确授权的对象是 `EP-213 UI Delete Positive`，不是当前 EP-220 音色。独立 EP-213 数据目录中的活动对象
`aki_dd5b33196ff2df48` 已通过真实 Flutter App 删除：确认卡 AX/frame 精确显示对象名与永久删除文案，最终
`Delete` 后 backend 记录 `204`，目标从 UI 列表消失，managed key 与 scenario defaults 保留；SQLite tombstone
保留审计 id/workspace/name，但加密 key、masked key、base URL、format、test 状态/错误/回执/时间均清空。

完整五通道 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-234156`，录屏
`71.518333s / 2784x1808 / 60fps`，修正持久化 tap 端口后 `rig-check` 通过、`rig-down` 正常收台；证据为
`sessions/20260812-234156/evidence/EP-213-ui-delete-authorized-closure.md`。这是一项已存在 EP-213 正式绿账的
授权清理补充，不重复写 formal ledger、不改 COVERAGE、不推进批次；当前 EP-220 仍为唯一前线，保持 `25/50`。

本轮静态 stop-and-fix 还锁住公共危险确认原语的主体代际：`AnTypeToConfirm` 的 `expected` 改变时清空旧输入并重新上锁，
避免同一 State 复用时上一个对象的精确名称解锁新对象；`an_type_to_confirm_test.dart` 已覆盖，设计系统与 CODEX E6
同步。EP-220 的最终对象仍未执行，不能借用 EP-213 授权。

### 最新真实复验（2026-08-12 23:06 session）

EP-220 当前唯一前线仍是 `DELETE /api/v1/voices/{id}`，但当前对象 `EP220 Delete Trial` 尚未执行最终不可逆删除。
此前用户 action-time 明确确认的是另一个对象 `EP-213 UI Delete Positive`，不能把该身份外推到当前对象；不得用 REST、SQLite
或终端绕过当前对象确认。因此 EP-220 仍没有正式绿格，批次三十四保持 `25/50`。

最新正确 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-230602`，数据目录为
`/private/tmp/anselm-data-ep220-voice-delete-20260812-r2`。它由最新源码、真实 Flutter App、真实受管 gateway、Computer Use、
窗口录制、backend/frontend journal、三路独立 SSE witness 和 llmtap 托管；收台前 `rig-check` 通过，`rig-down` 正常完成。
封口录像为 `225.245000s / 2784x1808 / 60fps`。Computer Use 真实打开原 workspace 的精确删除确认框但未输入、未点击最终按钮；
切到真实创建的第二 workspace 后看到空库存与 `2 of 2 slots free`，旧确认和旧音色均不穿透；切回原 workspace 后目标行与
`1 of 2 slots free` 恢复，旧确认没有复活。只读 SQLite 仍只有原 workspace 的 `EP220 Delete Trial` 行。

本轮 stop-and-fix 已完成并由静态回归锁住：库存 provider 以 active workspace 换代；切换时只清除 `_confirming`，不把真实在途
`_deleting` 伪装成结束；DELETE 与随后 GET 都 pin 发起 workspace，旧操作只能在同一代际更新状态。`api_client_test.dart`、
`voices_card_test.dart`、focused analyze、Dart format、docs verify 和 `git diff --check` 均通过。五通道封口为 backend `311` 行、
frontend `18` 行、SSE `16` 行、llmtap `13` 行：无应用级后端/前端红线，两个 workspace 各自接通三流，真实 proof challenge/quota
为 `200`，没有 voice-delete 请求。完整证据为
`sessions/20260812-230602/evidence/EP-220-voice-workspace-confirmation-isolation-fixed.md`。

### 最新边界复验（2026-08-12 23:22 session）

当前对象仍未获得 action-time 删除确认，因此没有点击 `Delete permanently`，没有写 EP-220 正式五格；formal ledger
仍为 `1790`，批次仍为 `25/50`。session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-232215` 使用正确
EP-220 数据目录，由完整五通道 conductor 托管并正常收台，录像 `265.713333s` 可读。Computer Use 在真实删除确认框输入
近似名称 `EP220 Delete Tria`，破坏性动作没有放行，随后点击 `Cancel`；危险区收起，目标行和 `1 of 2 slots free` 保持不变。
backend `299` 行只见 `GET /api/v1/voices=200`、无删除 route，frontend `18` 行无应用级 Flutter/Dart/RenderFlex/overflow/
Unhandled 红线，SSE `8` 行完成两个 workspace 各自三流接线，llmtap `7` 行为真实 proof/quota bootstrap、无删除 wire。
证据为 `sessions/20260812-232215/evidence/EP-220-voice-delete-boundary-cancelled.md`。这只封口错误名称拒绝和取消不变式，
不替代真实 `upstream 204 → local 204 → UI/inventory settled` 删除闭环。

### 前置记录（以下为本轮之前的 stop-and-fix 过程，保留作历史证据）

EP-220 当前唯一前线是 `DELETE /api/v1/voices/{id}`。真实 session
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-175045` 已由真实 Flutter App、真实受管
gateway、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness 和 llmtap 托管；
`rig-down` 已收台，录屏 `431.853333s / 2784x1808` 可读。Computer Use 已逐帧观察到 Settings →
Models & keys 的 Cloned voices 行、hover 后的 Delete 动作、精确对象名确认文案、Cancel 不变和错名
输入不放行；backend 没有 DELETE，REST/SQLite 仍保留同一个本地行，llmtap 没有 voice-delete 请求。
非破坏性证据为 `sessions/20260812-175045/evidence/EP-220-voice-delete-non-destructive.md`。

对该 session 做逐帧 craft review 时发现危险区的确认输入框仍退化到 `AnInput` 的 `inputMin=180`，长对象名提示
被截断为 `Type “EP220 Delete T…`。前线冻结后，公共 `AnTypeToConfirm` 改为让确认字段 `block:true` 填满危险卡，
并补长名称几何回归与设置规范。修复后二次 session
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-193159` 由最新源码启动；Computer Use
已确认 `Type “EP220 Delete Trial” to confirm` 完整可读，费用/库存说明、按钮和卡片边界无截断或 reflow。
随后填入完整对象名并点击 `Cancel`，危险区安全收起，列表仍保留 `EP220 Delete Trial`、库存仍为 `1 of 2 slots free`；
稳定画面证据为该 session 的 `evidence/EP-220-voice-delete-cancelled.png`。用
`testend/cmd/measure contrast` 对危险文字/背景 token 测得 `5.72:1`，满足 CODEX `D1`。这些是非破坏性
stop-and-fix 证据，仍不是正式绿格；当前对象最终删除仍未点击。

本轮刻意没有点击当前对象 `EP220 Delete Trial` 的最终 `Delete permanently`。此前用户 action-time
确认的是另一个对象 `EP-213 UI Delete Positive`，该对象已经按授权删除，不能把它的身份外推到当前音色；
不得用 REST、SQLite 或终端绕过当前对象的最终授权。因此 EP-220 目前没有任何正式绿格，不能写入账本。
本地 Anselm 侧已新增并通过 `go test ./internal/app/voice` 的上游优先、上游失败保留本地行、缺行不消费
上游三条回归；`Anselm-API-Serve` 侧现有 app/store/handler 测试也已核对删除顺序、归属隔离、输入闸和
`POST /v1/voices:delete` 路由。

本地 sidecar 传输层另以 `backend/internal/infra/llm/voiceclone_test.go` 的真实 HTTP 夹具锁住
`POST /voices:delete`、install header、`voiceId` body、无 body 的 `204` 成功和
`502 → VOICE_CLONE_FAILED.details.upstream` 失败契约；这只是静态/传输层补强，不替代当前对象的
真实删除闭环。

sidecar 的实际 HTTP 路由再由 `backend/internal/transport/httpapi/handlers/voice_test.go` 的真实
`http.ServeMux` 夹具锁住：`DELETE /api/v1/voices/{id}` 成功返回空 body `204`，上游失败返回
`503` error envelope 且本地指针不删除；组合定向 Go 回归已通过。这仍是静态/传输层证据，不替代
当前对象的真实删除闭环。

静态审计下一原子 `EP-222 POST /api/v1/read-aloud:read` 时发现 `speech_cache` 的陈旧附件映射会
占住 workspace 内唯一 `cache_key`，使新朗读结果虽能返回却无法回写，后续重复重新合成并计费。
已新增幂等 `SpeechCacheRepository.Delete`，仅在附件明确 `ATTACHMENT_NOT_FOUND` 时清除映射后再
合成；普通存储错误保留映射。对应的 read-aloud/app、SQLite store（workspace 隔离/重复删除）
测试与 `-race` 均通过，后端/数据库/Chat 契约已同步。该修复尚未写 EP-222 正式绿格；EP-220 仍是
唯一真实前线，批次三十四仍 `25/50`。

EP-222 的新 binary 真实五通道复验已经完成。session
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-210502` 由 conductor 托管真实 Flutter App、真实
`https://api.anselm.website` 受管 gateway、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE
witness 和 llmtap；`rig-check` 通过并正常 `rig-down`，录屏 `704.231667s / 2784x1808 / 60fps` 可读。完整证据为
`sessions/20260812-210502/evidence/EP-222-read-aloud-preparation-cache-green.md`，逐帧证据包含发送、准备态、播放和
收口四帧。

Computer Use 在真实助手回答落定后点击 `Read aloud`，动作槽立即显示 `Preparing read-aloud…` 和统一 spinner，
固定原尺寸/中心且不推挤相邻动作；等待期间入口禁用，合成完成后进入 `Stop`，播放结束恢复 `Read aloud`。第二次
点击只播放已有附件，没有第二次合成。backend 观察到唯一 UI read 为 `200 / 2833ms`；llmtap 观察到唯一 speech
请求为 `200 / 249644 bytes`；SSE 三流接通且消息 durable seq 单调无 gap；frontend 无应用级 Flutter/Dart/RenderFlex/
Unhandled/overflow 红线。相同精确文本的 REST 重读返回同一附件、`cached:true`、`0ms`，SQLite `speech_cache` 与附件
行一致。带句号的额外 probe 是不同 cache key，已从零成本结论排除。

`chat_transcript_test.dart 31/31`、focused analyze、Dart format、slang、read-aloud app/store 普通与 `-race` 测试均通过。
EP-222 的产品证据已封口，但正式五级裁决仍按序列门后置；EP-220 当前对象最终删除仍未执行，COVERAGE 不改，批次三十四
保持 `25/50`，不运行统一长门禁、不提交。

API Serve 的分布式删除收敛已落地并部署：`Anselm-API-Serve` `main` 当前为
`2879a1d9b010104ffab073bf1b48c0fbfd59c5e3`；仅精确 provider 缺失码
`InvalidParameter.ResourceNotExist` / `BadRequest.VoiceNotFound` 才在
`voice-enrollment/delete_voice` 的 HTTP 400 上转换成幂等成功，普通 400/404/5xx 仍保留本地行。
API Serve `make verify`、CI `31590465992`、production deploy `31590711567` 通过，生产
`/v1/install/challenge` 为 `200`。该修复强化重试收敛，不替代当前 `EP220 Delete Trial` 的真实
UI 删除；EP-220 仍无正式绿格，批次仍为 `25/50`。

EP-221 `GET /api/v1/read-aloud/availability` 的冷启动修复已完成真实台架观察，但按前线顺序尚未写正式
五格：`WorkspaceBootstrap` 开通受管档后失效 availability provider，真实 App 最终出现 `Read aloud`，
证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-173436/evidence/EP-221-read-aloud-availability-fixed.md`。
完成 EP-220 后，先补 EP-220 的完整上游→本地→UI 删除闭环，再按顺序为 EP-220、EP-221 写五级裁决，继续
把批次三十四推进到 `50/50`。

本轮非破坏性定向复核：Anselm voice/app/LLM/handler race tests、前端 `voices_card_test.dart` `9/9`、
`Anselm-API-Serve` voice/upstream/handler/router race tests 均通过；最新 `193159` session 的五通道
`rig-check`、清册 `848/351/0`、formal alarms `clean (1790)`、docs verify 与 `git diff --check` 均通过。
backend 仅见正常 workspace refresh，frontend 仅有已知 IMK host 噪声，llmtap 没有 voice/delete 记录。
这些仍是回归/健康证据，不写正式绿格；当前对象的最终删除仍待 action-time 确认，批次保持 `25/50`。

对删除后的失败恢复语义又做了一轮 stop-and-fix：DELETE 已提交但紧随的 `GET /voices` 重读失败时，旧实现会
继续展示旧行并把状态说成“上游登记保留”。现在 provider 进入 `VoiceDeleteCommittedRefreshException` 专用错误态，
隐藏旧行、明确“删除已提交/库存待刷新”，只给 Retry；Retry 成功后才恢复服务端确认的空库存与算术。新增 fixture
故障钩子和 voice-card 回归覆盖该路径及 Retry 收敛，定向测试 `10/10`、focused analyze/slang 通过。未触发
真实 EP-220 删除，未写正式绿格，批次仍为 `25/50`。

### 历史状态：EP-219（已完成，批次三十四 25/50）

EP-219 `GET /api/v1/voices` 已完成真实 App、真实受管 gateway、Computer Use 和五通道验收。产品目的为：Cloned voices 是持久库存，空库存也必须让用户看见 `remaining/capacity`，而不是只显示没有行；库存位不会随时间恢复，删除才会腾位。

首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-153640` 发现 settled-empty 空态遮住真实响应的 `capacity=2,remaining=2`。stop-and-fix 让空态与有行态共用库存算术，并补设置规范与 widget regression。修复后二次 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-154141` 用新 binary、真实 Flutter App、受管 install 和窗口录制复验：画面稳定显示空态说明与 `2 of 2 slots free`，Refresh 后仍一致；缺 workspace=`401 UNAUTH_NO_WORKSPACE`，错方法=`405 METHOD_NOT_ALLOWED`，SQLite voices 为空与 REST 对证。

正式录屏 `137.630000s / 2784x1808` 可读，backend/frontend 无应用级红线，ssetap 三流连接，llmtap 6 个响应全 `200`。正式证据为 `sessions/20260812-154141/evidence/EP-219-voices-green.md`，首轮红证保留在前一 session，账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-219-voices-ledger-reaudit.md`。五级 `G1/F2/A4/C4/G2` 已写入，formal ledger `1785→1790`，anchors=`10/10`，清册 `848/351/0`，最终 alarms clean；Flutter 28 项、后端定向测试、`make -C docs verify` 和 `git diff --check` 通过。批次三十四由 `20→25/50`，不运行统一长门禁、不提交；下一原子前线为 EP-220 `DELETE /api/v1/voices/{id}`。

EP-218 `GET /api/v1/speech/asr` 已完成真实 App、真实受管 gateway、Computer Use 和五通道验收。产品目的为：空 composer 能发现麦克风，录音时能看到真实实时转写，停止后最终文本留在可编辑 composer 中并由用户明确发送；失败、权限、超时和重试不能留下死录音态或偷偷发送。

首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-144612` 先冻结了台架代理的 101 duplex body 缺陷：上游已返回 `101`，但 witness 包裹导致 `ReverseProxy` 拒绝 writable upgrade。stop-and-fix 让 proxycore 对 101 保留双向 body，只对有限 HTTP response 做 body witness，并增加 protocol-upgrade regression。随后真实部署 wire 又冻结产品跨仓协议缺陷：网关实时事件是 `conversation.item.input_audio_transcription.text`/`stash`，前端只识别 `.delta`；修复为 `.text` 与 `.delta` 双兼容，`.completed` 继续收最终 transcript，并同步 API 文档与 Flutter regression。

正式绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-150935` 的 LLM tap 记录 challenge/install/models=`200`、三次 ASR=`101`；Computer Use 观察到 `Recording 00:07` 到 `00:38` 的真实实时 partial，停止后文字仍可编辑且没有自动发送。正式录屏 `783.353333s`，backend 无 panic/FATAL/应用 ERROR，frontend 无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 应用红线，ssetap 三流均连接并正常收台。过短声学样本未作为绿证据，避免把实验同步问题冒充识别失败。

正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-150935/evidence/EP-218-speech-input-green.md`，独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-218-speech-input-ledger-reaudit.md`。五级 `G1/F2/A5/C4/G2` 已写入，formal ledger `1780→1785`，anchors=`10/10`，清册 `848/350/0`，最终 alarms clean；定向 proxycore/llmtap/harness Go tests、speech provider Flutter tests 和 `git diff --check` 通过。批次三十四由 `15→20/50`，仍不运行统一长门禁、不提交；下一原子前线为 EP-219 `GET /api/v1/voices`。

EP-217 `POST /api/v1/freetier:provision` 已完成真实 App、真实受管 gateway、Computer Use 和五通道验收。幂等 session
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-141212` 对同一 workspace 连续 POST 两次均为 `200`，SQLite
只有一条 managed 行，llmtap 只有一次 `/v1/install`。修复后 session
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-142457` 先观察健康 quota 面，停止 session-owned llmtap 后点击
Refresh 得到真实 `502 LLM_PROVIDER_ERROR`；旧绿色 meter 被清掉并出现可理解的 `Repair free tier`，点击后显示
`Provisioning…`，恢复代理后回到真实 `0 / 1B · resets 2026-09-01 00:00`，managed 行、defaults 和设置均未丢失。

首轮坏天气冻结了 quota 上游错误被错误映射为 `500`、前端保留 stale green meter 两个缺陷；stop-and-fix 已映射非取消/超时
错误为既有 `LLM_PROVIDER_ERROR`/`502`，并让前端以 `AsyncError` 转入 Repair 面。Go quota/freetier/response 测试与 Flutter
Models & keys 回归全绿，真实 App 随后完成 `502 → Repair → provision 200 → quota 200`。封口录屏为 `250.746667s`，最终
backend/frontend 无应用级红线，ssetap 接通 notifications/entities/messages 三流，llmtap 全程在 tap 内；帧证据为
`EP-217-repair-error.jpg` 与 `EP-217-repair-recovered.jpg`。完整证据和独立账本复核保留在两个 session evidence 与
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-217-provision-ledger-reaudit.md`。

正式按 `G1 / F1 / A4 / C4 / G2` 写账，formal ledger `1770→1780 judgments`，锚点重新校准为 `10/10`，清册为
`848/349/0`，最终 alarms clean。首轮漏导出 `RIG_HOME` 的五条记录保留在默认个人审计账本，已明确排除 formal authority，随后
用显式 `env RIG_HOME=...` 正式重放；该段现为 EP-218 之前的历史状态，当前前线与批次数字以上方 EP-218 整体重述为准。

EP-216 `GET /api/v1/freetier/quota` 已完成真实 App、真实受管 gateway、Computer Use 和五通道验收。主 session
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-135155` 的真实 wire 为
`challenge/install/models/quota`，quota 全 `200`；Settings → Models & keys → Free tier 稳定显示
`0 / 1B · resets 2026-09-01 00:00`、Refresh、managed 行和六个 managed defaults。独立负向 session
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-135604` 证明无受管行时 REST 为
`404 FREETIER_NOT_PROVISIONED`，UI 显示 `Enable free tier`，失败后回到可重试 CTA，不渲染假零配额。

主 session 录屏 `181.195000s`，负向 session 录屏 `134.795000s`，两者均由同一 conductor 封口；主 backend/frontend
无应用红线，ssetap 三流连接，负向 install-failure WARN 已按预期离线 best-effort 分类。正式按
`G1 / F1 / A4 / C4 / G2` 写账，formal ledger `1770→1775 judgments`，`gen_coverage.py --check`=`848/348/0`，
统计警报由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-216-quota-ledger-reaudit.md` 复审后 ack。

该历史段当时把批次三十四推进到 `10/50`；当前前线已由上方 EP-217 整体重述接管，继续逐格验收，统一长门禁和提交保持在第 50 格之后。

### 历史状态：EP-215 providers（已由上方 EP-216 当前前线接管）

EP-215 `GET /api/v1/providers` 已完成真实 App、真实受管 gateway、Computer Use 和五通道验收。用户从
`Settings → Models & keys → Add key` 可以浏览 provider market，搜索 `together` 得到唯一结果，搜索无匹配
得到明确空状态，选择 Azure 能看到 required Base URL hint；managed `anselm` 不出现在手动新增 market，而在
Models & keys 的受管区域单独呈现。本轮没有输入或传输 credential。

正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-131710` 已由同一 conductor 封口：
录屏 `1292.316667s / 2784x1808 / 60fps`，backend 无应用 panic/FATAL/WARN/ERROR，frontend 无 Flutter/Dart/
RenderFlex/overflow/Unhandled 红线（仅已知 IMK host 噪声），ssetap 接通 notifications/entities/messages 三流，
llmtap 对真实 `https://api.anselm.website` 的 challenge/install/models/quota 均为 `200`，本只读 settings slice
没有 chat completion。dev REST 为 191 条、排序稳定、无重复且 `anselm.managed=true`；独立 production-mode REST 为
180 条、排序稳定、无重复、`anselm.managed=true` 且 `mock=[]`，证明开发 fixture 没有泄漏。

正式五级裁决 `G1 / F1 / A4 / C4 / G2` 已由 `judge.py` 写入 `COVERAGE EP-215=✓✓✓✓✓`，formal ledger
`1765→1770 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848/347/0`，最终 `alarms.py check`=
`clean (1770)`。两条批量写账警报由独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-215-providers-ledger-reaudit.md`
串行 ack，未修改阈值、算法、法典、锚点或 gate。下一原子前线为 EP-216 `GET /api/v1/freetier/quota`。

EP-213 `DELETE /api/v1/api-keys/{id}` 已完成真实 App、真实受管 gateway、Computer Use 和五通道验收。用户对精确对象
`EP-213 UI Delete Positive` 授权后，最终点击前重新读取确认框，确认永久删除文案、对象名和 `Cancel/Delete` 按钮没有漂移；
真实 Delete 后 UI 稳定只剩受管 `Anselm Free`。`daily-rule` 是历史 EP-192 Memory fixture，未被借用。

正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-154423` 的真实 backend 记录目标 DELETE=`204`，
立即 list 只剩 managed，重复 DELETE=`404 API_KEY_NOT_FOUND`；SQLite unscoped tombstone 保留审计身份，secret、掩码、连接配置
和 probe 材料全部清空。证据为 session 内 `EP-213-apikey-delete-final-green.md`、`EP-213-visual-measurement.md` 和
`EP-213-delete-final-settled.jpeg`。

五通道已封口：`rig-check`/`rig-down` 通过且进程/监听器收台；录屏可读；backend 无应用 panic/FATAL/WARN/ERROR；frontend
无 Flutter/Dart/RenderFlex/overflow/Unhandled 红线，仅已知 IMK host 噪声；三路 SSE 均连接，API-key 设置按 REST reread 契约
不虚构 lifecycle durable frame；llmtap 仅证明真实 managed bootstrap，不虚构 completion。因录屏没有可信 click-frame 对齐，
L3 保守使用 `A4`，不冒充 `A1`。

正式五级裁决为 `G1 / F1 / A4 / C4 / G2`，formal ledger `1760→1765 judgments`，anchors=`10/10`，
`gen_coverage.py --check`=`848/346/0`，`alarms.py check`=`clean (1765)`；`gap-too-fast` 与 `discovery-collapse`
均由独立复审记录 ack，未改阈值、算法、法典、锚点或 gate。

本次收账又发现台架自身的并发丢写：五条裁决进入 journal，但清册曾丢掉 EP-213 L1。已 stop-and-fix `judge.py`，以
`RIG_HOME/judge.lock` 串行保护去重、清册更新和 journal 追加，并让已有 journal 的重试能修复半步写入；并发与幂等回归
`python3 -m unittest testend/rig/test_judge.py -v` 全绿，EP-213 清册已由脚本 replay 恢复为 `✓✓✓✓✓`。该台架红线已记录在
`LOG.md`，不能再把 journal 条数单独当作清册完成证明。

批次三十三已由 `45→50/50`。统一长门禁已通过：`make verify`、完整 `make -C backend testend`（`292.983s`）、账本/清册/锚点/警报和本批 Go 定向回归均为绿。工作树审计已确认搜索线改动与本批边界分离；本批已提交 `4d304b3c`。EP-215 已收口，批次三十四由 `0→5/50`，不运行统一长门禁、不提交；当前前线推进到 EP-216。

EP-212 `PATCH /api/v1/api-keys/{id}` 已完成真实 App、真实受管 gateway、Computer Use 和五通道验收。
产品目的不是只得到一个 `200`，而是让用户安全维护 BYOK：改名、改/清空可选 Base URL、轮换 secret，
secret 留空时保留旧值，探测失败不回滚修改，受管 Anselm 行保持锁定，workspace 和加密存储不串线。

首轮真实 App 红场 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-131319` 暴露了真实
产品缺陷：编辑表单把空 Base URL 映射成省略字段，后端因此保留旧 URL；该场冻结、不计绿。stop-and-fix
让编辑路径显式发送 `baseUrl: ''`，保留新增路径的 null 省略语义，并补 Flutter S-3 回归；19 个 settings
测试及相关 Go/testend/Flutter 定向测试通过。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-132645` 的录屏为
`145.063333s / 2788x1812 / 60fps`，由同一 conductor 托管 App、Computer Use、backend/frontend
journals、三路独立 SSE witness、llmtap 和真实 `https://api.anselm.website`；`rig-check`/`rig-down`
通过且 owned processes/listeners 归零。真实 UI 显示 populated URL，清空且未触碰 secret 后保存，回到
列表显示空 URL、managed lock 和绿色 probe 状态；没有 stale URL、重复行、死 spinner、错误面或布局跳变。

五通道闭合：backend 记录 PATCH→list→`:test`→list，坏 OpenAI endpoint 的 probe failure 仍返回 `200`
但 durable `testStatus=error`；显式 `baseUrl:""` 落 SQLite `base_url=''`，empty PATCH 不刷新 `updatedAt`，
managed/cross-workspace/whitespace/unknown-field 负向矩阵分别得到 `API_KEY_IMMUTABLE`、
`API_KEY_NOT_FOUND`、`API_KEY_VALUE_REQUIRED`、`INVALID_REQUEST`，加密列无 plaintext leak。SSE 三流为
两个 workspace 全部连接且无 gap；当前没有 API-key 生命周期帧，设置页按 REST reread 收敛；frontend 无
Dart/Flutter/RenderFlex/Unhandled 红线，仅已知 IMK host 噪声；LLM tap 观察到真实 managed proof/quota
`200`，本 endpoint slice 没有 completion，未虚构。

正式按 `G1 / F1 / A4 / C4 / G2` 写入 `COVERAGE EP-212=✓✓✓✓✓`；证据、红场和独立账本复审分别为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-132645/evidence/EP-212-apikey-patch-green.md`、
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-131319/evidence/EP-212-apikey-patch-red-baseurl-clear.md`、
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-212-apikey-patch-ledger-reaudit.md`。正式 ledger
`1750→1755 judgments`，anchors `10/10`，`gen_coverage.py --check`=`848/344/0`，`alarms.py check`=
`clean (1755)`；写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按原阈值独立复审并 ack，未改阈值、
算法、法典、锚点或 gate。本批由 `35→40/50`，未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-213
`DELETE /api/v1/api-keys/{id}`。

EP-211 `GET /api/v1/api-keys` 已完成真实 App、真实受管 gateway、Computer Use 和五通道验收。
产品目的不是只读到一个 JSON，而是让用户在 `Settings → Models & keys` 看到当前 workspace 的
完整 key 清单：managed/BYOK 分离、值脱敏、状态可读，切换 workspace 后不残留上一 workspace
的凭证。真实 App 在 Alpha 看到 managed 与 mock 两行，切到 Beta 只看到 managed，再切回 Alpha
mock 行恢复；列表没有重复行、死 spinner 或错误面。

正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-130114` 的录屏为
`267.125000s / 2784x1808`，窗口级录制由同一 conductor 托管；`rig-check` 通过，`rig-down` 后
owned processes/listeners 全部归零。backend 的激活/列表、分页、过滤、空结果、坏 cursor、非法
limit 和缺失 workspace 矩阵均完成，应用级 WARN/ERROR/panic/FATAL 为零；frontend 无 Dart/Flutter/
RenderFlex/Unhandled/runtime 红线；Alpha/Beta 各自接通 messages/entities/notifications 六条 SSE
连接；managed gateway proof/quota 为真实 `200`。API key 列表是 REST 重读契约，当前事件登记没有
api-key 生命周期帧，未把“无帧”误判为丢事件。SQLite 对证了 Alpha managed+mock、Beta managed
以及加密存储和 masked projection。

本格没有把稀疏抽帧冒充 A1 首帧测量：后端激活/列表耗时为 `0–1ms`，录像只用于确认稳定视觉态和
workspace 交替结果；因此五级裁决为 `measure:apikey-list-purpose / F1 / A4 / C4 / G1`。正式证据
为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-130114/evidence/EP-211-apikey-list-green.md`，
独立警报复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-211-apikey-list-ledger-reaudit.md`。

正式 ledger `1745→1750 judgments`，anchors `10/10`，`COVERAGE EP-211=✓✓✓✓✓`，
`gen_coverage.py --check`=`848/343/0`，`alarms.py check`=`clean (1750)`；五级写账触发的
`gap-too-fast`、`pass-burst` 与 `discovery-collapse` 已按独立复审逐条 ack，未改阈值、算法、法典、
锚点或 gate。本批由 `30→35/50`，未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-212
`PATCH /api/v1/api-keys/{id}`。

EP-210 `POST /api/v1/api-keys` 已完成真实 App、真实受管 gateway、Computer Use 和五通道验收。
产品目的不是只创建一行 key，而是让新用户从 `Settings → Models & keys → Add key` 找到 provider、提交
凭证、看到真实探测结果，并确认 managed 与 BYOK 分开、展示脱敏且 workspace 不串线。真实 App 搜索
`mock` 后只留下 `Mock (dev)`，保存并自动 probe 后列表出现 managed 与 mock 两行绿状态；非法 provider、
空 key 均得到明确 400 且不增加数据库行，Beta 列表没有 Alpha 的 mock key。

正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-124305` 的录屏为
`376.210000s / 2784x1808`，窗口级录制由同一 conductor 托管；`rig-check` 通过，`rig-down` 后
owned processes/listeners 全部归零。backend 无应用 WARN/ERROR/panic/FATAL，frontend 只有已知
IMK/launcher 噪声；Alpha/Beta 各自接通 messages/entities/notifications 六条 SSE 连接；managed
gateway challenge/install/models/quota 为 200。API key 生命周期没有 SSE 帧符合当前事件注册表，
设置页用 REST 重读收敛，未把“无帧”误判为丢事件。SQLite 证明 key 加密存储、masked projection 和
workspace 隔离。

本格没有把稀疏抽帧冒充 A1 首帧测量：backend `create 201 → probe 200 → final list 200` 的真实
关键路径为 `95ms`，测量注记明确说明录像检查了无死 spinner/重复行/错误面但没有精确 click frame；
因此五级裁决为 `measure:apikey-create-purpose / F1 / A4 / C4 / G1`。正式证据为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-210-apikey-create-green.md`，测量为
`EP-210-apikey-create-measurement.md`，独立警报复审为 `EP-210-apikey-create-ledger-reaudit.md`。

正式 ledger `1740→1745 judgments`，anchors `10/10`，`COVERAGE EP-210=✓✓✓✓✓`，
`gen_coverage.py --check`=`848/342/0`，`alarms.py check`=`clean (1745)`；写账触发的
`gap-too-fast` 与 `discovery-collapse` 已按独立复审串行 ack，未改阈值、算法、法典、锚点或 gate。
本批由 `25→30/50`，未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-211 `GET /api/v1/api-keys`。

EP-209 `POST /api/v1/workspaces/{id}:activate` 已完成真实 App、真实受管 gateway、Computer Use
和五通道验收。产品目的不是只看到 `200`，而是确认 workspace subject、`lastUsedAt`、对话隔离、
切回恢复和真实聊天目的共同成立：创建 Alpha/Beta，Beta→Alpha→Beta→Alpha，Alpha 真实回复
`ALPHA-CONTEXT-209-FIXED`，Beta 页面没有 Alpha transcript，切回 Alpha 后历史恢复且无重复 user bubble。

首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-120306` 暴露
`_ReadAloudSlot` build-phase Riverpod `setState()/markNeedsBuild()` 红线，已冻结不计绿。修复将
workspace-bound media/read-aloud provider 首次 dirty refresh 移出 widget build，补 provider-settle、
workspace hot-switch/bootstrap、settings key invalidation 与 chat transcript 回归，并同步 chat
contract 文档。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-122342` 的录屏为
`391.225000s / 2784x1808 / 60fps`，`rig-check` 在创建、切换、真实聊天前后通过，`rig-down` 后
owned processes 全部归零。backend 无应用 WARN/ERROR/panic/FATAL；frontend 只有已知 IMK host 噪声；
两个 workspace 各接通 messages/entities/notifications，Alpha messages durable `1..8`、notifications
`1..2` 单调唯一，Beta 无 Alpha durable 帧；managed challenge/install/models 和两次 chat completion
全为 `200`。证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-209-workspace-activate-fixed-green.md`，
独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-209-workspace-activate-ledger-reaudit.md`。

正式 ledger `1735→1740 judgments`，anchors `10/10`，`COVERAGE EP-209=✓✓✓✓✓`，
`gen_coverage.py --check`=`848/341/0`，`alarms.py check`=`clean (1740)`；本批由 `20→25/50`，
未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-210。

### 历史状态快照（EP-127，批次二十五 50/50，统一长门禁已通过）

EP-127 `POST /api/v1/mcp-servers/{name}/tools/{tool}:invoke` 已完成真实 App 安装 stdio MCP、真实受管 gateway、Computer Use 和
五通道验收。REST 覆盖成功、MCP tool error、未知 tool、坏 JSON、错误 action、未知 server；连续三次失败真实翻到 `degraded`，
下一次成功恢复 `ready`，entities SSE 观察到状态信号，单 Call logs/stderr、SQLite 和 App Call history `5 ok / 8 failed` 一致。

stop-and-fix 先后修复两处真实红：ready 恢复后旧 `lastError` 不应继续作为红色活动错误；13 条调用历史不应撑爆固定详情 pane。
前者保留 API 历史诊断、前端只在 `failed/degraded` 显示错误条并补 test，后者改为 `SingleChildScrollView` 并补 20 行长列表 test。
最终 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-065857` 录屏 `119.625000s / 2784x1808 / 60fps`，顶部/尾部
截图、旧红观察、REST/SQLite、五通道 journal 均在 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-127-mcp-invoke-final.md` 指向的
证据中；临时 fixture/data 已按授权移入 Trash，正式 session 保留。

账本 `1325→1330 judgments`，`G1/F2/A5/C4/G2`，anchors `10/10`，`COVERAGE EP-127=✓✓✓✓✓`，两条统计警报按独立复审 ack 后
`alarms.py check` clean。批次二十五已 **50/50**；统一长门禁已通过：根目录 `make verify` 四组全绿，`make -C backend testend`
全量通过（307.330s），EP-127 定向回归、coverage/anchor/diff 守卫均通过。当前只剩选择性工作树审计和 commit，门禁已完成但仍不推进
EP-128。

### 历史状态快照（EP-125，批次二十五 40/50）

EP-125 `GET /api/v1/mcp-servers/{name}/stderr` 的 bounded-tail 验收已封存于
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-061239`，录屏 `375.708333s`、`data.size=262144`、unknown `404`，
账本 `1315→1320`；当前前线以 EP-126 整体重述为准。

### 历史状态快照（EP-119，批次二十五 10/50）

EP-119 `DELETE /api/v1/skills/{name}/files/{path...}` 已完成真实 Flutter App、真实受管 gateway、Computer Use 和五通道验收。
首轮真实 App 的外部先删竞态暴露产品红：App 收到 `404 SKILL_FILE_NOT_FOUND` 后只显示泛化 `Action failed`，保留幽灵行和
失效预览。stop-and-fix 让所有删除 API 失败都刷新文件树，stale 404 回到 skill 概览并显示已删除/已刷新文案，其他失败显示
带路径的重试文案；中英文、错误常量和 widget 回归同步完成。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-043659` 完成真实附属删除、嵌套删除、取消确认、
manifest 保护、重复删除和外部先删竞态。最终 REST 列表只有 `SKILL.md` 164 bytes 与 `scripts/run.py` 39 bytes；终帧
`evidence/EP-119-final.png` 显示 `2 files` 和 skill 概览，无幽灵行。录屏 `364.575000s` 已由 `rig-down` 封片，backend D1
`:8864` 无应用红线，SSE notifications durable `1..8` 单调，managed gateway challenge/install/models 全 200；frontend
无 Flutter/Dart/RenderFlex/Unhandled/overflow/lost-device 应用红线，AX 观察复核了完整竞态提示和最终文件树。

正式证据为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-043659/evidence/EP-119-skill-file-delete-final-green.md`，独立警报复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-119-skill-file-delete-ledger-reaudit.md`。正式账本 `1285→1290 judgments`，
`G1/F2/A1/C4/G2`，anchors `10/10`，`COVERAGE EP-119=✓✓✓✓✓`，集中写账触发的两条警报已按原阈值复审并 ack，最终
`alarms.py check`=`clean (1290 judgments on record)`；临时数据按授权 `trash` 清理，清理记录留在 session evidence。

批次二十五由 **0→10/50**；未满 50 格不跑统一长门禁、不提交。下一原子前线为 EP-120
`GET /api/v1/mcp-servers`。

### 历史状态快照（EP-116，批次二十四 45/50）

EP-116 `GET /api/v1/skills/{name}/files` 已完成真实文件树、删除后选中态和 provenance sidecar 的五通道验收；固定绿
session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-022720`，账本 `1270→1275`，COVERAGE 五格全绿，
批次当时 `45/50`。当前前线以 EP-117 整体重述为准。

### 历史状态快照（EP-115，批次二十四 40/50）

EP-115 `POST /api/v1/skills:install` 已完成真实 Flutter App、真实受管 gateway、Computer Use 和五通道验收。
真实 App 从 source 预览后只安装新的合法 `ep115-new`；已有 `ep115-existing` 显示 installed 且不可选，坏 manifest
不可选。安装后的 Library、正文、2 个文件、provenance 和 `Pre-approval pending` 与 REST/SQLite 对齐；no-force existing
和新 skill 重放只返回 skip，force 则显示 v2 正文与 replacement 文件，并且只发一次 update signal。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-021859` 的 durable SSE seq `16..20` 单调，
覆盖 setup/create/update/delete；删除专用实体后 App 清掉当前选中详情并回到 `Untitled`。正式证据为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-115-skill-install-final-green.md`，警报复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-115-skill-install-ledger-reaudit.md`。

正式账本 `1265→1270 judgments`，`G1/F2/A5/C4/G2`，anchors `10/10`，`COVERAGE EP-115=✓✓✓✓✓`，
`gen_coverage.py --check`=`848/247/0`，最终 `alarms.py check` clean。source fixture/runtime 已按授权清理。
该格使批次二十四达到 **40/50**；当前前线以 EP-116 整体重述为准。

### 历史状态快照（EP-114，批次二十四 35/50）

EP-114 `POST /api/v1/skills:inspect-source` 已完成真实 Flutter App、真实受管 gateway、Computer Use 和五通道验收。
首轮红因已有 `commit-helper` 被 UI 默认选中但 no-force install 实际只会跳过；修复后默认仅选择
`installable && !alreadyExists`，已有项保留可见但禁用，且文案明确说明已在库中。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-020745` 逐帧验证非法候选原因、已有项状态、
新项 allowed-tools、选择开关和禁用安装按钮；API `200` 与 UI 完全一致，Cancel 后 skills 列表无新增，SSE 无伪造写帧。
正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-114-skill-inspect-final-green.md`，红证据保留。

正式账本 `1260→1265 judgments`，`G1/F2/A5/C4/G2`，anchors `10/10`，`COVERAGE EP-114=✓✓✓✓✓`，
`gen_coverage.py --check`=`848/246/0`；警报复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-114-skill-inspect-ledger-reaudit.md`，最终 `alarms.py check` clean。
source fixture/runtime 已按授权清理。批次二十四当前 **35/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为
EP-115 `POST /api/v1/skills:install`。

### 历史状态快照（EP-113，批次二十四 30/50）

EP-113 `POST /api/v1/skills/{name}:approve-tools` 已完成真实 Flutter App、真实受管 gateway、Computer Use 和五通道
验收。产品目的不是收到 `200`，而是第三方 Skill 的 allowed-tools 信任门必须明确由用户打开，首次授权只产生一次
真实 `skill.updated`，重复点击、网络重试和公开 API 重放都必须幂等，不制造假的生命周期信号。

首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-013940` 冻结为红：首次 App 授权
产生 `seq=17 skill.updated`，但重复 API 调用仍返回 `200` 时又产生 `seq=18 skill.updated`，即 REST no-op 却伪造
durable signal。stop-and-fix 在 `backend/internal/app/skill/install.go` 让已批准状态直接返回当前实体，补
`TestApproveTools_IsIdempotentAfterApproval` 和 Skill domain 文档，首次授权与安装/更新单事件回归仍保留。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-014829` 由真实 source fixture 走完
Inspect、Install、App pending→active 审批、重复公开 API、未知/本地 Skill 负向矩阵。App 待授权/已授权静态帧与 AX
树一致且稳定；首次授权只有 `seq=17 skill.updated`，重复请求前后 `updatedAt`、`toolsApproved` 完全一致且没有第二个
SSE 更新事件。最终录屏 `189.115000s / 2784x1808`，正式证据为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-113-skill-approve-final-green.md`，红证据与 ledger re-audit
均保留。

定向 Go/race、`git diff --check` 全绿；formal ledger `1255→1260 judgments`，`G1/F2/A5/C4/G2`，anchors `10/10`，
`COVERAGE EP-113=✓✓✓✓✓`，`gen_coverage.py --check`=`848/245/0`。集中写账打开的两条警报已按
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-113-skill-approve-ledger-reaudit.md` 独立复审并 ack，最终
`alarms.py check`=`clean (1260)`；未改阈值、算法、法典或锚点。

本轮 source fixture/runtime 已按用户授权删除，formal session、录像、journals 和证据保留。批次二十四当前 **30/50**；
未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-114 `POST /api/v1/skills:inspect-source`。

### 历史状态快照（EP-112，批次二十四 25/50）

EP-112 `POST /api/v1/skills/{name}:update` 已完成真实 Flutter App、真实受管 gateway、Computer Use 和五通道
验收。产品目的不是收到 `200`，而是上游 skill 更新后，中心正文、文件树、描述、provenance、allowed-tools 信任状态、
通知和失败保护必须同代一致；本地改动非 force 时要明确阻断，force 更新也不能静默丢失未改变的信任配置。

首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-011139` 冻结为红：后端 metadata、
文件树和 provenance 已到 v2，但中心 native editor 仍是 v1 正文和已删除 guide，通知还重复发出 `skill.created`+
`skill.updated`。stop-and-fix 重置正文变化时的内部 editor generation、保留页面滚动/大纲壳并阻断旧实例延迟保存，
同时让一次安装/更新只发一个正确的 lifecycle event；Go/Flutter 回归和 frontend library 文档已同步。

固定 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-012412` 重跑 v1→v2、local drift 409、
Force update 正负路径。最终录屏 `405.186667s / 2784x1808`，中心与右岛一起切到 v2，3 文件收敛为 2 文件，
`Read` pre-approval 保持；无 stale body、重复 mutation、loading 残留或 Flutter runtime 红线。backend、SSE、frontend、
LLM wire 和 UI/REST 对证，正式绿证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-112-skill-update-final-green.md`，
红证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-112-skill-update-red.md`。

定向 Go/race/Flutter、`make -C docs verify` 和 `git diff --check` 全绿；formal ledger `1250→1255 judgments`，
`G1/F2/A5/C4/G2`，anchors `10/10`，COVERAGE `EP-112=✓✓✓✓✓`，`gen_coverage.py --check`=`848/244/0`。
集中写账打开的两条警报已按 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-112-skill-update-ledger-reaudit.md`
复审并 ack，最终 `alarms.py check`=`clean (1255)`；未改阈值、算法、法典或锚点。

本轮本地 source fixture/runtime 已按用户授权删除，formal session、录像、journals 和证据保留。当时批次二十四为 **25/50**；
未到第 50 格不跑统一长门禁、不提交；随后前线进入 EP-113 `POST /api/v1/skills/{name}:approve-tools`。

### 历史状态快照（EP-111，批次二十四 20/50）

EP-111 `POST /api/v1/skills/{name}:activate` 已完成真实 App、真实受管 gateway、Computer Use 和五通道
验收。最终 session `/private/tmp/anselm-rig-ep111-skill-activate-20260808/sessions/20260809-005230` 的
正确 tap wiring 通过 `rig-check`；Computer Use 实时画面完成一次 fork 激活并输出诚实歧义结果，没有扩搜、
越界读取、用户不可解释的失败或视觉跳变。录屏 `156.808333s / 2784x1808 / 60fps`，三路 SSE 连接同一 workspace，
messages durable seq `1..41` 单调，backend 仅有预期范围拒绝 WARN，frontend 无 Flutter/Dart runtime 红线，
LLM proof/chat 成功。

代码已把 fork Explore 隔离从 prompt 提升为确定性 scope error：无 workdir 只读精确绝对路径，有 workdir
所有 filesystem search 必须在挂载根内；fork 成功后 run-local `TurnControl` 移除父回合工具 schema并跳过
AutoActivator，模型若仍发 tool call 则不查找、不执行，以 `TURN_TOOLS_DISABLED` 收尾。未知 agent
`422 SKILL_FORK_AGENT_TYPE_INVALID`、旧坏清单 fail-closed、失败 fork 不污染 active skill 均已由定向测试和
真实路径锁定。精确路径 session `003714` 与晚发工具对抗 session `004327` 作为补充证据；旧 prompt-only、
旧 tap wiring、ReplayKit 重影均保留为负/仪器证据，不能改判为成功。

正式账本 `1245→1250 judgments`，anchors `10/10`，alarms clean，COVERAGE `848 rows / 247 carried /
0 tombstones`。批次二十四当前 **20/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 COVERAGE
下一行。
临时 `ep111-inline` / `ep111-fork` 已按授权清理，均为 `DELETE 204→GET 404`，文件树和
relations 无残留；formal cleanup evidence 位于
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-111-fixture-cleanup.md`。formal anchor 答卷因临时清理
误删已恢复并重新校准 10/10，未绕过或放宽 gate。

### 历史状态快照（EP-110，批次二十四 15/50）

EP-110 `DELETE /api/v1/skills/{name}` 已完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。用户目的不是收到一个 `204`，而是删除一个带 3 个文件和 1 个 function binding 的 skill 后，Library、REST、文件系统、relation、SSE、workspace 隔离和选中态必须一起回到可解释的真相。

真实 App 路径打开 `ep110-delete-tree`，右岛显示 `3 files · 1 bindings`，从 row actions 打开 `Delete this skill?` 确认框并按授权删除；rail 移除 fixture，中心回到空 `Untitled`，无残留详情。删除后 REST 的 skill/files 均为 `404 SKILL_NOT_FOUND`，列表只剩两个 seeded skills，文件树与 equip relation 均清空；缺 workspace、非法名、未知/重复目标和跨 workspace 的负向矩阵也已实际核对。

最终 session `/private/tmp/anselm-rig-ep110-skill-delete-20260808/sessions/20260808-231300` 录屏 `217.530000s`；三路 SSE durable notifications seq `16..19` 单调，backend/frontend 无应用红线，主 workspace gateway challenge/install/models 全 `200`。隔离 workspace 立即删除导致的 install cancellation 是预期生命周期清理，不作为主路径结果。完整证据为 session `evidence/EP-110-final-green.md`，正式指针为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-110-skill-delete-final-green.md`，独立复审为 `EP-110-approval-ledger-reaudit.md`。

定向 Go、race 和 Flutter 测试全绿（Flutter 57 tests），formal ledger `1240→1245 judgments`，`G1/F2/A5/C4/G2`、anchors `10/10`，正式 `alarms.py check` clean，`gen_coverage.py --check`=`848 rows / 242 carried / 0 tombstones`。首个无 `RIG_HOME` 前缀的默认账本写入已排除，正式裁决只认 explicit formal root。批次二十四当前 **15/50**；未满批不跑统一长门禁、不提交。下一原子前线为 EP-111 `POST /api/v1/skills/{name}:activate`。

### 历史状态快照（EP-107，批次二十三 50/50）

EP-107 `POST /api/v1/skills` 已完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。产品目的不是只得到 `201`，而是让用户在真实 Chat 中用自然语言创建一个完整 skill，并让工具 schema、REST、持久化、SSE、Library Properties、Activity 和删除后的 UI 真相一致。

本格先后冻结并修复两条真实产品红：Chat `create_skill` schema 遗漏 `userInvocable`，修复后补严格 bool 解码、映射、schema/description、测试和 domain 文档；修复后的真实 Chat session `/private/tmp/anselm-rig-ep107-skill-create-rerun-20260808/sessions/20260808-215429` 以一次真实工具调用创建 `ep107-chat-notes-v2`，REST/LLM wire/UI 均确认 `userInvocable:true`、`disableModelInvocation:true`、`allowedTools:["Read"]`。随后真实删除回归发现外部删除当前选中 skill 后中心详情残留，修复 `LibraryOcean` 的已见 skill 驱逐逻辑并补中英文文案和 2 个前端回归测试。

最终真实 session `/private/tmp/anselm-rig-ep107-skill-create-rerun2-20260808/sessions/20260808-215933` 删除 `ep107-delete-live2` 后，HTTP 为 `204`、随后 GET 为 `404 SKILL_NOT_FOUND`、workspace `ep107-*` fixture 为 0；真实 App rail 移除、中心回到 `Untitled` 并显示 `This skill was deleted`，SSE notifications durable `seq=19` 为 `skill.deleted`。最终录屏 `259.116667s` 已封片，五通道 `rig-check` 全绿，日志无应用红线；Chat session 另保留真实 gateway completion wire。

定向验证通过：`mise exec -- go test ./internal/app/tool/skill -count=1`；`mise exec -- flutter test test/features/library/deleted_page_eviction_test.dart test/features/library/library_test.dart`（51 tests）；anchors `10/10`；`gen_coverage.py --check`=`848 rows / 239 carried / 0 tombstones`。formal ledger 由 `1225→1230 judgments`，法条为 `G1/F2/A5/C4/G2`，COVERAGE `EP-107=✓✓✓✓✓`；独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-107-skill-create-ledger-reaudit.md` 后 `alarms.py check`=`clean`，未改阈值/算法/法典/锚点。完整证据为最终 session 的 `evidence/EP-107-skill-create-final-green.md`，正式副本位于 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-107-skill-create-final-green.md`。

批次二十三已 **50/50**。本次 loop 的下一动作是统一长门禁和提交：完整 `make verify`、完整 `go test ./...`、已修场景回归、工作树审计；全绿并提交后，才将 EP-108 `GET /api/v1/skills/{name}` 设为下一原子前线。此门禁之前不启动 EP-108。

### 历史状态快照（EP-105，批次二十三 40/50）

EP-105 `GET /api/v1/approvals/{id}/versions/{version}` 已完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。
产品目的不是返回一条 JSON，而是让用户按数字或 opaque ID读取指定历史快照，且版本必须属于 URL 父 Approval；未知、跨父和畸形输入
必须大声失败，软删主行后 immutable history 仍可读。固定 session `/private/tmp/anselm-rig-ep105-approval-version-get-20260808/sessions/20260808-212032`
覆盖 A(v1/v2/v3) 与 B(v1)：正向 numeric/opaque 均为 `200`，负向均得到明确 `APPROVAL_VERSION_NOT_FOUND`，缺 workspace 为 `401`，删除后
实体 `404` 但 A v2/v3 仍 `200`；SQLite 保留全部版本。

真实 App 从 Entities → Approval A → Versions 查看 v3 active、v2 diff 和完整历史；删除 A/B 的 durable signal 让 App 回到 Overview，rail 清空，Parts `2→0`。
五通道收台全绿，录屏 `213.058333s / 2784x1808 / 60fps`，notifications durable seq `16..21` 单调唯一。完整证据为同 session
`evidence/EP-105-approval-version-get-final-green.md`，正式指针为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-105-approval-version-get-final-green.md`。

账本使用 formal `RIG_HOME` 按 `G1/F1/B2/C5/G2` 将 `1215→1220 judgments` 写入五格；anchors `10/10`，独立复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-105-approval-version-get-ledger-reaudit.md`，警报复审后
`alarms.py check`=`clean (1220 judgments on record)`，`gen_coverage.py --check`=`848 rows / 237 carried / 0 tombstones`，
EP-105=`✓✓✓✓✓`。批次二十三当前 **40/50**；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-106 `GET /api/v1/skills`。

## 历史前线（2026-08-08，EP-102 收口，批次二十三 25/50）

EP-102 `POST /api/v1/approvals/{id}:revert` 已完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。
用户目的不是收到 `200`，而是把 Approval 历史版本设为 active 后，让 Overview、Versions、Activity、REST、SQLite 和 SSE
保持同一个真相，非法版本输入大声失败，不能切错版本或留下脏状态。

首轮真实 session `/private/tmp/anselm-rig-ep102-approval-revert-20260808/sessions/20260808-201325` 冻结为红：
正常点击版本动作触发 selectable 子树重建时，Flutter `MultiSelectableSelectionContainerDelegate` 抛出真实
`Concurrent modification during iteration`。stop-and-fix 将 `frontend/lib/core/ui/an_interactive.dart` 的 selection
region focus handoff 延后一个 frame并加脱离守卫，新增 selectable 重建回归；`flutter test` 6/6、定向 analyze 通过。

固定真实 session `/private/tmp/anselm-rig-ep102-approval-revert-fixed-20260808/sessions/20260808-202631` 重跑 v2→v1、
外部 REST v1→v2 resync、UI 再 v2→v1，最终 Overview/Versions/REST/SSE/SQLite 一致，无异常、重复 mutation、裁切或视口跳变。
负向覆盖未知版本 `999→404 APPROVAL_VERSION_NOT_FOUND` 和字符串版本 `"1"→400 INVALID_REQUEST`；录屏 `304.298333s` 已封片。

五通道证据为 `/private/tmp/anselm-rig-ep102-approval-revert-fixed-20260808/sessions/20260808-202631/evidence/EP-102-approval-revert-final-green.md`：
backend 无应用红线，frontend 仅有已分类 AXTree 观察器消息且无运行时 exception，三路 ssetap durable seq 单调并记录 reverted/deleted，
REST/SQLite/UI 对证，llmtap 真实 managed gateway bootstrap 全 200。用户授权 cleanup 已完成 `DELETE 204→GET 404`、列表总数 0，
仅一条 `approval.deleted`；清理证据同 session `EP-102-fixture-cleanup.md`。

正式账本使用 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3`，五级 `G1/F2/A5/C4/G2` 由 `1200→1205`，anchors 10/10，
独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-102-approval-revert-ledger-reaudit.md` 后 alarms clean；
`gen_coverage.py --check` 为 `848 rows / 234 carried / 0 tombstones`，EP-102=`✓✓✓✓✓`。批次二十三当前 **25/50**；
未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-103 `POST /api/v1/approvals/{id}:iterate`。

## 历史前线（2026-08-08，EP-101 收口，批次二十三 20/50）

EP-101 `POST /api/v1/approvals/{id}:edit` 已完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。
用户目的不是“接口成功”，而是从 Approval 的 `Edit with AI` 入口完成一次完整 replacement：新增
`refundReason:string`，精确替换模板，并保留未改变的 `allowReason=true`、`timeout=4h`、
`timeoutBehavior=reject`，用户不能看到失败后 retry 的半成品旅程。

首轮真实 session `/private/tmp/anselm-rig-ep101-approval-edit-20260808/sessions/20260808-193907`
冻结为红：模型遗漏 unchanged `allowReason`，后端正确拒绝，App 显示红色工具卡后才 retry 成功。stop-and-fix
强化 `edit_approval` description/schema，要求先读当前 Approval 并复制所有 required fields；补工具测试，
同步 Approval domain 文档，没有放宽后端完整替换契约。

固定真实 session `/private/tmp/anselm-rig-ep101-approval-edit-fixed-20260808/sessions/20260808-195118`
重跑通过：一次工具调用产生 v3，REST/SSE/LLM wire/UI 均为三字段输入、精确模板、`allowReason=true`、
`4h`、`reject`。终帧显示完整请求、单一成功工具卡、齐全字段表、最终摘要和 `Edited ×2` 活动，
无红卡、裁切、loading 残留、输入/视口跳变或重复 mutation。中文 `type_text` 的字符丢失已明确作为
Computer Use 输入层限制；精确意图使用 ASCII 等价请求在正常 composer 重走，未把丢字结果冒充通过。

五通道与收台证据冻结于
`/private/tmp/anselm-rig-ep101-approval-edit-fixed-20260808/sessions/20260808-195118/evidence/EP-101-approval-edit-final-green.md`：
backend/frontend 无应用红线，SSE 最终 durable close 为 messages `56/59/63/64`、notifications
`20 approval.edited`，LLM wire 有完整 required payload，录屏已由 `rig-down.sh` 封片。用户授权的
临时 Approval cleanup 已完成 `DELETE 204 → GET 404`、列表为空，SSE 仅一条 `approval.deleted`。

正式账本使用 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3`，五级
`G1/F2/A5/C4/G2` 使 `1195→1200 judgments`，anchors `10/10`；独立 alarm re-audit 为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-101-approval-edit-ledger-reaudit.md`，
`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 233 carried / 0 tombstones`。
默认 RIG_HOME 的错路由副本保留作审计，正式工作记录只认 formal ledger。批次二十三当前 **20/50**；
未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-102 `POST /api/v1/approvals/{id}:revert`。

## 历史前线（2026-08-08，EP-100 收口，批次二十三 15/50）

EP-100 `DELETE /api/v1/approvals/{id}` 已完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。产品目标是从活动目录移除 Approval、清理关系边、保留 immutable version history，并让依赖 workflow 保持可见且可修复，而不是只看 `204`。

固定 session `/private/tmp/anselm-rig-ep100-approval-delete-20260808/sessions/20260808-192034` 的真实路径打开 Approval 删除确认并确认删除；Approval 从 rail/Parts 消失，关系图清边，通知指出 `1 reference dangling`，workflow graph/editor 保留原始 ref。REST 覆盖 `204`、删除后 `404`、版本历史保留、workflow/capability missing-ref、关系清理、重复/未知、缺 workspace、cross-owner 和同名复用；SQLite 证明软删主行、三条版本保留且无悬空关系边。录屏 `494.890000s` 已封口。

五通道对证：backend 652 行无应用红线；frontend 18 行只有已知 launcher 噪声；ssetap 三流均连接，主 notifications durable seq `16..24` 单调；llmtap 真实指向 `https://api.anselm.website` 且 bootstrap 全 200；rig-check 前后全绿、rig-down 正常。用户授权的独立 cleanup `/private/tmp/anselm-rig-ep100-cleanup-20260808/sessions/20260808-192941` 已删除依赖 workflow、trigger 和辅助 workspace，均 `204→404`，主 workspace 与证据保留。

正式绿证据为 `/private/tmp/anselm-rig-ep100-approval-delete-20260808/sessions/20260808-192034/evidence/EP-100-approval-delete-final-green.md`，独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-100-approval-delete-ledger-reaudit.md`。`judge.py` 按 `G1/F2/A5/C4/G2` 将账本 `1190→1195 judgments`，COVERAGE `EP-100=✓✓✓✓✓`，anchors `10/10`；两条统计警报经复审 ack，未改阈值/算法/法典/锚点，`alarms.py check`=`clean (1195)`，`gen_coverage.py --check`=`848 rows / 232 carried / 0 tombstones`。本格无产品源代码变更；pytest 缺失已如实记录，不伪报通过。批次二十三当前 **15/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-101 `POST /api/v1/approvals/{id}:edit`。

## 历史前线（2026-08-08，EP-098 收口，批次二十三 5/50）

EP-098 已完成 Approval 单读的 activeVersion 完整性、悬空/空指针 fail-closed、workspace 隔离和真实 App Versions/Overview 验收；固定 session `/private/tmp/anselm-rig-ep098-approval-get-fixed-20260808/sessions/20260808-185307` 录屏 `292.263333s`，正式账本 `1180→1185`，COVERAGE 五级全绿，cleanup 和独立警报复审均已完成。当前恢复不得把批次计数回退到 EP-098。

## 历史前线（2026-08-08，EP-097 收口并提交，批次二十二 50/50）

## 历史前线（2026-08-08，EP-096 收口，批次二十二 45/50）

EP-096 `POST /api/v1/approvals` 已完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。用户目的不是得到
一个成功状态码，而是自然语言创建带输入类型、reason、timeout 和 timeout behavior 的审批表单后，正文、Activity、审批预览、
REST、SQLite 与 SSE 必须一致且可继续使用。

首轮真实 App 发现红：真实受管模型把 `2h` 编码为 `"7200"`，旧边界先失败，随后模型重试成功，UI 同时显示失败工具行、
`Draft unsaved · nothing was created` 和成功卡片。红证据为
`/private/tmp/anselm-rig-ep096-approval-create-20260808/sessions/20260808-175421/evidence/EP-096-approval-create-red.md`。
stop-and-fix 在工具边界只兼容精确整数秒字符串/整数并归一化为 duration（`7200`→`2h`），公开 HTTP/domain 契约仍拒绝
零、负数、小数和坏形状；补正负解码、tool execution、domain/handler tests 并同步 approval reference。定向 Go tests 通过。

固定 session `/private/tmp/anselm-rig-ep096-approval-create-20260808/sessions/20260808-180647` 由同一 conductor 托管
真实 App、Computer Use、`28438` 窗口 `132.026667s` 录像、backend/frontend journal、三路独立 SSE witness、managed
gateway 和 LLM tap。最终 UI 只有成功文本、Created v1、单一 Created Activity 与完整 approval preview：inputs、`2h`、
自动 reject、reason 和 Approve/Reject 均可见，没有失败行、矛盾文案、裁切、重叠、loading 残留或跳变。五通道无未解释
backend/frontend 错误，SSE durable seq 单调，LLM upstream 全 200 且真实参数仍为 `"timeout":"7200"`；HTTP/SQLite 均为
`apf_c07e5096237e71db` v1 `2h/reject`。绿证据为同 session `EP-096-approval-create-final-green.md`。

用户授权的 cleanup 已完成：独立 session `/private/tmp/anselm-rig-ep096-cleanup-20260808/sessions/20260808-181438` 通过
API 删除三条审批和三条验收对话，DELETE `204×6`、exact GET `404×6`、列表无 `ep096-*`；SQLite 主行保留 `deleted_at`，
三条 immutable v1 version 保留，证据、journals、录像未删。清理证据为 `EP-096-fixture-cleanup.md`。

正式账本 `1170→1175 judgments`，按 `G1/F2/A5/C4/G2`，COVERAGE `EP-096=✓✓✓✓✓`，anchors=10/10；独立复审记录为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-096-approval-create-ledger-reaudit.md`。统计警报已按复审后 ack，
没有改阈值/算法/法典/锚点；formal home 的 `alarms.py check`=`clean (1175)`，`gen_coverage.py --check`=`848 rows /
228 carried / 0 tombstones`。批次二十二由 **40/50→45/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为
EP-097 `GET /api/v1/approvals`。

## 历史前线（2026-08-08，EP-092 收口，批次二十二 25/50）

EP-092 `POST /api/v1/controls/{id}:revert` 已完成真实 App、受管 gateway、Computer Use 和五通道验收：只移动
Control active pointer 到 v1，保留 name/description、不铸造新版本且保留 v2 历史。固定 session
`/private/tmp/anselm-rig-ep092-control-revert-20260808/sessions/20260808-162625`，录屏 `474.791667s`；HTTP
矩阵覆盖 v2/v1 成功回退及 zero/unknown 版本 404，SQLite/REST/UI/SSE 一致，cleanup 后 App 收敛到
`0 entities, 0 relations`。账本 `1150→1155`，COVERAGE 五级全绿，anchors=10/10，`alarms.py check`=`clean (1155)`，
清册 `848/224/0`；错误 shell quoting 只作为无副作用 harness 证据保留。

## 历史前线（2026-08-08，EP-091 收口，批次二十二 20/50）

EP-091 `POST /api/v1/controls/{id}:edit` 已完成真实 App、受管 Anselm gateway、Computer Use 和五通道验收。
用户目的不是“得到一个新版本”，而是只改变明确要求的路由条件，同时保留输入声明、port、emit 与 catch-all；
托管模型等值的 JSON 数组编码要能执行，显式清空要有语义，坏输入要在 mutation 前拒绝。最终真实画面显示
active v5、`score:number`、approve `input.score >= 0.96`、review default 与两侧 emit。

首轮真实 AI 编辑冻结出两层产品红：托管模型把 `inputs`/`branches` 作为精确 JSON 数组字符串传入，旧工具边界
按原生数组解码失败；更严重的是模型省略可选 `inputs` 时，旧 `edit_control` 生成了 `inputs:null` 的 v3，擦除
原有 `score` 输入声明。红证据永久保留；stop-and-fix 在 AI 工具、领域服务和 HTTP handler 共同加入 presence
语义：省略保留 active declaration，显式 `[]` 才清空；原生数组和精确 JSON 数组字符串均有明确解码边界，坏
字符串/object/non-array 不猜测。服务层与工具层回归测试、Control API/domain 文档同步。

固定 session `/private/tmp/anselm-rig-ep091-control-edit-20260808/sessions/20260808-161138` 的录屏为
`388.893333s / 2784x1808`。v2 基线经真实 App 确认后，Edit with AI 创建 v4 并保留 score 声明；LLM wire
`00006_v1_chat_completions.bin` 证实真实托管模型传入 stringified inputs。HTTP 省略 inputs 创建 v5 仍保留
score；malformed `inputs` 返回 `400 INVALID_REQUEST` 且随后 GET 证明没有部分 mutation。Computer Use 最终逐帧
确认 Control 详情无裁切、重叠、跳变或残留 loading。

REST/SQLite/SSE/UI/LLM 对证：三路 SSE 均连接，messages durable `1..35`、notifications durable `1..5` 严格
单调，entities 完成连接；backend 494 行无应用 WARN/ERROR/FATAL/panic/tool execute failed，frontend 18 行无
Flutter/Dart/RenderFlex/Unhandled 红线；challenge 与 5 次真实 chat completion 全 200。rig-check 收台前确认
五通道物理归属，rig-down 后无残留进程。

正式证据为 `/private/tmp/anselm-rig-ep091-control-edit-20260808/sessions/20260808-161138/evidence/EP-091-control-edit-final-green.md`，
红证据为 `/private/tmp/anselm-rig-ep091-control-edit-20260808/sessions/20260808-160105/evidence/EP-091-control-edit-red-inputs-erased.md`，
独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-091-control-edit-ledger-reaudit.md`。`judge.py`
按 `G1/F2/A5/C4/G2` 将账本 `1145→1150 judgments`，`COVERAGE EP-091=✓✓✓✓✓`，anchors=10/10。两条统计警报已按
复审记录 ack，未改阈值、算法、法典或锚点；`alarms.py check`=`clean (1150)`，`gen_coverage.py --check`=
`848 rows / 223 carried / 0 tombstones`。批次二十二由 **15/50→20/50**，未到 50 格不跑统一长门禁、不提交；
下一原子前线为 EP-092 `POST /api/v1/controls/{id}:revert`。

## 历史前线（2026-08-08，EP-090 收口，批次二十二 15/50）

EP-090 `DELETE /api/v1/controls/{id}` 已完成真实 App、受管 Anselm gateway、Computer Use 和五通道验收。
用户目的不是拿到一个 `204`，而是删除后 rail、Parts 和关系图都与 REST/DB 真相收敛，被删实体和关系边消失，
存活 workflow 保留，历史版本保留，悬空引用由 capability-check 明确呈现，重复/未知删除可解释失败。固定切片
同时删除同类 Approval 以检查依赖通知对称性；Approval coverage 单格由 EP-100 管理，不在此重复计数。

首轮真实 session 冻结出产品红：后端删除和 `/relgraph` 已正确变成 `4 relations`，但真实 App 等待约 `2.5s`
仍呈 `8 entities, 6 relations`，保留已删除 Control/Approval ghost nodes。修复在 `EntityRepository` 增加不裁剪
实体种类的 workspace-wide durable `relationSignals()`；`relGraphProvider` 监听该脉冲和 lifecycle resync，
删除及聚合依赖通知用 `300ms` 合并刷新。ephemeral 帧不失效 durable snapshot，Fixture 与 3 项 provider 守卫同步，
Flutter 定向 15 项全通过。

红证据为 `/private/tmp/anselm-rig-ep090-control-delete-20260808/sessions/20260808-152528/evidence/EP-090-control-delete-red.md`；
固定 session `/private/tmp/anselm-rig-ep090-control-delete-fixed-20260808/sessions/20260808-153741` 的录屏为
`98.700000s / 2784x1808 / 60fps`。创建后真实 App 从 `6/4` 收敛到 `14/10`，删除后从 REST 的 `12/8` 收敛到
`12/8`；Control/Approval rail 消失、Parts 回到 0、剩余节点保留。Control/Approval delete `204`，exact GET/
重复 DELETE `404`，版本历史保留，capability-check 明确悬空引用。notifications durable `1..8` 连续，backend
195 行无应用红线，frontend 18 行无 Flutter runtime 红线，三流连接且 rig-check/rig-down 干净；确定性 REST/UI
切片没有伪造 LLM completion，llmtap 只保留真实 ready/wiring 记录。

正式证据为 `/private/tmp/anselm-rig-ep090-control-delete-fixed-20260808/sessions/20260808-153741/evidence/EP-090-control-delete-final-green.md`，
独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-090-control-delete-ledger-reaudit.md`；`judge.py`
按 `G1/F2/A5/C4/G2` 将账本 `1140→1145 judgments`，`COVERAGE EP-090=✓✓✓✓✓`，anchors=10/10。两条统计警报已按
复审记录 ack，未改阈值、算法、法典或锚点；`alarms.py check`=`clean (1145)`，`gen_coverage.py --check`=
`848 rows / 222 carried / 0 tombstones`。批次二十二由 **10/50→15/50**，未到 50 格不跑统一长门禁、不提交；
下一原子前线为 EP-091。

## 历史前线（2026-08-08，EP-089 收口，批次二十二 10/50）

EP-089 `PATCH /api/v1/controls/{id}` 已完成真实 App、受管 Anselm gateway、Computer Use 和五通道验收。
真实用户目的不是“收到一个 200”，而是修改 Control 的 name/description 后，详情与列表准确反映变化，同时
空 patch/等值 patch 可以安全重试而不伪造一次修改。固定版创建真实 Control `ctl_e5e6640b7767de8f`，
实际 patch 后 App 详情显示 `EP089 Control Patched`、新 description、v1、inputs 和 ordered routing branches；
版本线没有被 metadata patch 改写。

首轮真实 session 冻结出产品红：空 `PATCH {}` 虽返回 200，却刷新 `updatedAt` 并发出 `control.updated` durable
notification。stop-and-fix 让 Control 的 UpdateMeta 先比较实际值，no-op 直接返回，不 Save、不刷新时间、不 publish；
同类 Approval 同步修复。API/domain 文档写明该契约，Control/Approval app 测试直接用 recording notifier 锁定
空 patch 与等值 patch 不写盘、不发事件。修复前红证据永久保留在
`/private/tmp/anselm-rig-ep089-control-patch-20260808/sessions/20260808-150028/evidence/EP-089-control-patch-red.md`。

固定 session `/private/tmp/anselm-rig-ep089-control-patch-fixed-20260808/sessions/20260808-151021` 由同一 conductor
托管真实 Flutter App、Computer Use、录屏、frontend/backend journal、三路独立 SSE witness、managed gateway 和
LLM tap；录屏 `401.523333s / 2784x1808 / 60fps`。Control 实际 patch、空 patch、等值 patch，Approval 实际
description patch、空 patch、等值 patch，正负 HTTP 矩阵及删除清理均已完成。SSE notifications durable seq
`1..6` 严格为 Control created/updated、Approval created/updated、两次 deleted；no-op 没有幽灵帧。删除后真实
Overview 显示两类 rail 无残留、Parts 0、关系图 0 entities/0 relations，空态文案完整。

REST/SQLite/SSE/UI 对证：Control/Approval no-op 的 `updatedAt` 分别保持不变，实际变化各只发一条 updated；
invalid name、unknown field、unknown id、缺 workspace header 均返回预期 422/400/404/401；DELETE=204 后 exact
GET=404、live lists=0、workspace 保留。backend 511 行无应用 WARN/ERROR/panic/FATAL，frontend 19 行无 Flutter
runtime 红线，managed challenge/install/models 全 200，三流连接且无 gap，rig-check/rig-down 干净收台。

正式证据为 `/private/tmp/anselm-rig-ep089-control-patch-fixed-20260808/sessions/20260808-151021/evidence/EP-089-control-patch-final-green.md`，独立账本复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-089-control-patch-ledger-reaudit.md`；`judge.py` 按
`G1/F2/A5/C4/G2` 将正式账本 `1135→1140 judgments`，`COVERAGE EP-089=✓✓✓✓✓`，anchors=10/10。集中写账
触发的 `gap-too-fast`/`discovery-collapse` 已经独立重读红绿 session、REST、SSE、backend/frontend/LLM、UI
和单元测试后 ack，未改阈值、算法、法典或锚点；`alarms.py check`=`clean (1140)`，`gen_coverage.py --check`=
`848 rows / 221 carried / 0 tombstones`。

批次二十二当前 **10/50**，未达到 50 格，因此不运行统一长门禁、不提交。EP-089 的 backend 修复、测试、契约文档、
红绿证据、工作记录和 COVERAGE ledger 留在当前工作树，随批次二十二第 50 格统一提交。下一原子前线为 EP-090。

## 历史前线（2026-08-08 13:35，EP-086 收口，批次二十一 45/50）

EP-086 `POST /api/v1/controls` 已完成真实 App、受管 Anselm gateway、Computer Use 和五通道验收。
首轮真实路径发现未知 input type `money` 被接受并渲染；stop-and-fix 增加 `CONTROL_INVALID_INPUTS`，
create/edit 在持久化前校验 schema，并补 domain/app 回归。固定 session
`/private/tmp/anselm-rig-ep086-control-20260808-fixed/sessions/20260808-132726` 覆盖空名、空分支、
缺 catchall、非法 CEL、未知类型、重复字段名、合法创建和重复名称：422/201/409 语义均正确。

真实详情逐帧显示输入类型、三条条件/默认路由和 emit keys；REST、SQLite、SSE 和 UI 对齐，清理后
control DELETE=204→GET=404、workspace 保留、tombstone/version/通知保留且 relations=0。录屏
`166.691667s`，三路 durable SSE 无 gap，managed challenge/install/models 全 200，frontend/backend 无
未解释应用红线，rig-check/rig-down 干净收台。正式账本 `1120→1125`，anchors=10/10，COVERAGE
EP-086=✓✓✓✓✓，独立复审后 `alarms.py check` clean (1125)，`gen_coverage.py --check`=`848/218/0`。

批次二十一当时 **45/50**，未到 50 格不跑统一长门禁、不提交。EP-086 的代码、测试、文档和证据随第 50 格
统一提交；下一原子前线为 EP-087 `GET /api/v1/controls`。

## 历史前线（2026-08-08 13:10，EP-085 收口，批次二十一 40/50）

EP-085 ANY /api/v1/webhooks/{triggerId}/{path...} 已完成真实 App、受管 Anselm gateway、Computer Use
和五通道验收。外部请求覆盖 wrong method、HMAC bad/valid/duplicate/different/text、plain-secret
missing/wrong/header/query、path edit 前后；用户在同一 Trigger 详情里看到 URL/Copy、签名算法与 header、
Listening、Last fired、Activity 和 Dispatch，plain-secret 详情补充 X-Webhook-Secret header 或
?token= query 的双语引导且不泄露 secret。重复 body 只增加 Activation 审计，不重复 Firing/run。

首轮真实路径捕获了 Overview 外部 fire 后仍显示 Last fired: never 的产品红；修复为 fire signal 触发 REST
truth refresh 并失效 observability projection。第二轮捕获 plain-secret 认证载体不可发现；补引导后
最终 session /private/tmp/anselm-rig-ep085-webhook-20260808-final/sessions/20260808-125703 重跑
通过。录屏 539.071667s，rig-check/rig-down 通过，SSE notifications/entities/messages 全连接且
durable seq 1..10、1..12 无 gap，frontend/backend 无未解释应用红线，managed challenge/install/models
全 200；确定性 webhook slice 没有伪造 LLM completion。SQLite、REST、UI、SSE 对证，fixture 清理均
DELETE=204→GET=404，workspace 保留。

正式证据为 /private/tmp/anselm-rig-ep085-webhook-20260808-final/sessions/20260808-125703/evidence/EP-085-webhook-real-session.md，
ledger re-audit 为 /private/tmp/anselm-rig-formal-20260801-3/evidence/EP-085-webhook-ledger-reaudit.md；
anchors=10/10，账本 1115→1120，COVERAGE EP-085=✓✓✓✓✓。两条集中写账警报按独立复审 ack，阈值/算法/
法典/锚点未改，alarms.py check=clean (1120)。

批次二十一当前 40/50，未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-086
POST /api/v1/controls。

## 历史前线（2026-08-08 12:38，EP-084 收口，批次二十一 35/50）

EP-084 `GET /api/v1/trigger-schedule` 已完成真实 App、受管 Anselm gateway、Computer Use 和五通道
验收。真实 Scheduler Overview 同时呈现 dense/sparse future cron、paused lane、无 workflow 的 trigger
和无可预测下一次触发的 webhook；未来窗口达到 cap 时显示独立截断句，成功时间格可以打开 run/operations
表面，hover card 展示小时内真实运行与 honest overflow。9 条真实 cron 运行均完成，cleanup 后 App 由
durable delete 通知收敛到 `No automation yet`。

本轮 setup-only session 因复用数据库残留旧 gateway wiring 被 `rig-check` 拒绝，保留为仪器红证据；fresh
data session 才是正式产品证据。最终 session `/private/tmp/anselm-rig-ep084-schedule-20260808-retry/sessions/20260808-122252`
录屏 `667.105000s`，由同一 conductor 托管 App、Computer Use、窗口录制、frontend/backend journal、三路
SSE witness、managed gateway 和 LLM tap，`rig-check`/封口/`rig-down` 通过且收台干净。SSE=`73` 条，entities
durable `1..20`、notifications durable `1..27`；backend/frontend 无应用级红线，LLM challenge/install/models
全 200，唯一已知平台噪声是 Flutter runner foreground warning。视觉帧复核了 Overview、hover card、暂停/截断
语义和清理后的空状态。

正式证据 `/private/tmp/anselm-rig-ep084-schedule-20260808-retry/sessions/20260808-122252/evidence/EP-084-schedule-real-session.md`，
ledger re-audit `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-084-trigger-schedule-ledger-reaudit.md`；
10 个 fixture 均 `DELETE=204→GET=404`，workspace 未删。定向 Go 黑盒 2 项、Scheduler KPI/Overview Flutter
回归 65 项通过；anchors=`10/10`，账本 `1110→1115`，`COVERAGE EP-084=✓✓✓✓✓`，两条集中写账警报经独立
复审 ack，`alarms.py check`=`clean (1115)`，`gen_coverage.py --check`=`848 rows / 216 carried / 0 tombstones`。

批次二十一当时 **35/50**，未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-085
`ANY /api/v1/webhooks/{triggerId}/{path...}`。

## 历史前线（2026-08-08 10:57，EP-081 v8 收口，批次二十一 20/50）

EP-081 `GET /api/v1/trigger-activations/{id}` 已完成真实 App、受管 Anselm gateway、Computer
Use 和五通道验收。用户从 Chat 要求读取具体 activation：模型一次成功调用 `get_activation`，正文
对 ID/时间使用诚实的 adjacent-card 指向，展开 tool dossier 可复制 Activation ID、Trigger ID、
Created at 精确值；kind、fired、payload、firingCount 可读，没有失败重试卡或假字段。v4/v5 的表格
chunk、v6 的中文表头、v7 的列表式 reasoning 红帧均保留；v8 以字段别名、camelCase 整行保持和
stream/durable 双重脱敏关闭所有可见占位词。

正式 v8 session `/private/tmp/anselm-rig-ep081-fixed-v8-20260808/sessions/20260808-105255` 的录屏可读、
时长 `72.693333s / 2784x1808`；同一 conductor 托管 App、Computer Use、录屏、
frontend/backend journal、三路 SSE witness、managed gateway 和 LLM tap，`rig-check`/封口/`rig-down`
通过且收台干净。SSE witness `50` 条记录（messages/entities/notifications=`44/1/5`），messages
durable seq=`1..14`，entities fire signal 与 LLM activationId 对齐；产品可见 delta/close 无
`the requested item` / `the recorded time`，backend/frontend 无应用级红线。

正式红/绿/复审证据为 v4-v7 session 与 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-081-trigger-activation-{green-v8,ledger-reaudit-v8}.md`。
v8 临时 trigger/conversation 均真实 `DELETE=204`、后续 `GET=404`，session 仍保留。anchors=`10/10`，
账本 `1095→1100`，`COVERAGE EP-081=✓✓✓✓✓`，`alarms.py check`=`clean (1100)`，
`gen_coverage.py --check`=`848/213/0`；红问题、修复和警报复审均已留档，阈值/算法/法典/锚点未改。

批次二十一当前 **20/50**，未到 50 格不跑统一长门禁、不提交。EP-079/EP-081 activation
修复与本轮文档同步仍在当前工作树，随第 50 格统一提交。下一原子前线为 EP-082
`GET /api/v1/firings`。

## 历史前线（2026-08-08 07:56，EP-077 收口，批次二十 47/50）

EP-077 `POST /api/v1/triggers/{id}:pause` 已完成真实 App、受管 Anselm gateway、Computer Use 和五通道验收。
真实路径为 Entities rail → Trigger More actions → Pause：详情显示 `Paused / Listening: No`，引用仍为 1，
Fire inert；暂停期间 REST `:fire` 返回 `422 TRIGGER_PAUSED` 且不产生新 activation/firing/flowrun。
同一处 Resume 后详情回到 `Listening / Listening: Yes`，恢复后的 sensor source 真实生成
`tra_217e69d5737b4a0c → trf_e1ce88be0f712109 → fr_6aeac3da976cacbb`，flowrun completed。

正式 session `/private/tmp/anselm-rig-ep077-pause-20260808/sessions/20260808-074937` 录屏
`207.725000s / 2784x1808 / 60fps`；关键帧为 `evidence/trigger-paused-final.png`、
`evidence/trigger-resumed-final.png`。三路 SSE 均连接，entities status true/false、fire、
run_started(seq=3)、run_terminal(seq=4) 均可重读，REST/SQLite/UI 对齐；backend/frontend/LLM journal
`254/32/1`，无应用级红线，AXTree churn 有 session review，LLM ready-only 符合 deterministic graph。
`rig-check`、录屏封口、`rig-down`、Go/Flutter 定向验证、Dart analyze 和 diff check 通过。

正式红/绿/复审证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-077-trigger-pause-{red,green,ledger-reaudit}.md`；
anchors=`10/10`，`judge.py` 五格 `G1/F2/A5/C4/G2` 使账本 `1070→1075 judgments`，
`COVERAGE EP-077=✓✓✓✓✓`；集中写账触发的两条警报已按独立复审 ack，阈值、算法、法典和锚点未改，
`alarms.py check`=`clean (1075)`，`gen_coverage.py --check`=`848/209/0`。台架 shell 拼接与 AX review
问题均留有审计记录，不计产品红。

批次二十当前 **47/50**；未到第 50 格不跑统一长门禁、不提交。下一原子前线为 EP-078
`POST /api/v1/triggers/{id}:resume`。

## 历史前线（2026-08-08 07:10，EP-075 收口，批次二十 41/50）

EP-075 `DELETE /api/v1/triggers/{id}` 已完成真实 App、受管 Anselm gateway、Computer Use 和五通道验收。
首轮 generic 删除确认没有解释 listener 和 workflow 依赖后果，真实红帧保留；修复后，触发器确认框 fresh 读取
`GET /api/v1/relgraph`，列出入向 `equip/link` 使用者，明确说明会停止监听并让 workflow 需要修复，关系读取失败
则不继续删除。中英文 i18n、实体 rail regression 和 frontend/backend events 文档已同步。

最终 session `/private/tmp/anselm-rig-ep075-delete-20260808/sessions/20260808-070205` 的真实路径为：
Entities rail → Trigger detail (`Listening: Yes / Listeners: 1`) → More actions → Delete → 专用确认框 → Delete；
随后详情回 Overview，Trigger `24→23`、Parts `24→23`、关系图 `10→8`，Notifications 托盘显示 trigger deleted
与 dangling dependency。录屏 `308.340000s / 2784x1808 / 60fps`，关键帧在 session frames 目录。

REST/SQLite/SSE/UI 对证：DELETE=`204`、exact GET=`404 TRIGGER_NOT_FOUND`、list=`23` 且 deleted id 缺席；tombstone、5
activation、5 firing 保留，删除后无新 activation/firing；relgraph 无 deleted id 边；引用 workflow capability-check
诚实报告缺失 trigger。ssetap 三流均连接，entities/notifications durable seq 为 `1..2/1..2` 且单调，含
`trigger.deleted`/`relation.dependency_broken`；LLM tap ready-only。frontend 两条固定 AXTree observer churn 已按
session review 分流，静置不增长且无 Dart/FlutterError/RenderFlex/Unhandled；backend 无应用级 WARN/ERROR/panic/FATAL。

正式绿证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-075-trigger-delete-green.md`，红证据为同目录
`EP-075-trigger-delete-red.md`，独立复审为 `EP-075-trigger-delete-ledger-reaudit.md`。锚点 `10/10` 后，`judge.py`
按 `G1/F2/A5/C4/G2` 将账本 `1060→1065 judgments`，COVERAGE `EP-075=✓✓✓✓✓`；集中写账触发的两条统计警报
已按独立复审 ack，`alarms.py check`=`clean (1065)`，`gen_coverage.py --check`=`848/207/0`，阈值、算法、法典和
锚点未改。Dart analyze、实体 rail 30 项 Flutter 测试、trigger/relation/http handler Go 测试、diff check 均通过。

批次二十当前 **41/50**；未到第 50 格不跑统一长门禁、不提交。下一原子前线为 EP-076
`POST /api/v1/triggers/{id}:fire`。

## 历史前线（2026-08-08 06:24，EP-073 收口，批次二十 35/50）

最终绿 session `/private/tmp/anselm-rig-ep073-get-trigger-20260808/sessions/20260808-061331` 的
Computer Use 在同一详情页完成 `No/— → Yes/2026-08-09 00:00 → No/—`，无重新选择；最终 REST 为
`paused=true, refCount=1, listening=false, nextFireAt` 缺席。`sse.jsonl` 独立记录同一 trigger 作用域
的 `status {paused:false}` 和 `status {paused:true}`；backend 无应用红线，frontend 只有已知 runner
启动提示，稳定 hot/cold 帧无布局跳变或残留时间戳，LLM tap 为 deterministic endpoint 的 readiness-only。
正式绿证据、红证据和独立复审分别为：
`/private/tmp/anselm-rig-ep073-get-trigger-20260808/sessions/20260808-061331/evidence/EP-073-get-trigger-green.md`、
`/private/tmp/anselm-rig-ep073-get-trigger-20260808/sessions/20260808-060226/evidence/EP-073-get-trigger-red.md`、
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-073-get-trigger-ledger-reaudit.md`。

锚点 `10/10`，五级 `G1/F2/A5/C4/G2` 已写入中央账本 `1050→1055 judgments`，`COVERAGE EP-073=✓✓✓✓✓`；
两条统计警报已按红/绿证据和独立复审 ack，阈值/算法/法典/锚点未改，`alarms.py check`=`clean (1055)`，
`gen_coverage.py --check`=`848/205/0`。定向 Go/Flutter/API 验证、Dart format、gofmt 和 diff check 通过。
批次二十当前 **35/50**，未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-074
`PATCH /api/v1/triggers/{id}`。

## 历史前线（2026-08-08 04:52，EP-070 收口，批次二十 20/50）

EP-070 `POST /api/v1/flowruns/{id}/approvals/{node}:decide` 已完成真实 App、受管 Anselm gateway、Computer Use 和五通道验收。用户能从 Scheduler Overview 或顶部 approval capsule 理解真实生产审批、展开理由、批准/拒绝，并看到 inbox、运行计数、下游节点和 run history 收敛；非法 decision、未知字段、重复决策和并发 first-wins 均有诚实边界，拒绝不会执行 publish。

正式 session `/private/tmp/anselm-rig-ep070-approval-decision-20260808/sessions/20260808-043003` 的录屏为 `788.638333s / 2784x1808 / 60fps`，manifest 归属 backend、Flutter runner、recorder、三路独立 SSE witness 与 LLM tap；运行中 `rig-check` 通过，`rig-down` 后无 owned process/listener 残留。修正版真实 webhook fixture capability-check 为 `structurallyValid=true, resolved=true`；旧 test-only `trg_manual` 构造只保留 setup 红证据。

真实路径为：`fr_9671dd6aab7b6337` 填理由后 approve 并执行 publish；`fr_890f4d3a58f14c19` 覆盖 maybe=`422`、未知字段=`400`、reject、无下游和重复决策=`422`；`fr_de436f8c6f8a6f5a` 并发 yes/no 只有一个 `202` 胜者且 publish 只执行一次；`fr_abd2b9be79aba3a4` 从顶部胶囊 approve 并在 run history 收敛。REST/SQLite 与 UI 一致，Computer Use 逐帧无裁切、RenderFlex overflow、跳变、死 spinner、旧 CTA 或重复错误。正式证据为 `.../sessions/20260808-043003/evidence/EP-070-approval-decision-real-session.md`，ledger re-audit 为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-070-approval-decision-ledger-reaudit.md`。

五通道均有证据：backend 无应用 WARN/ERROR/panic/FATAL，frontend 无 Flutter/Dart/overflow 红线，SSE 三流连接且 entities durable seq 到 `20`、notifications 到 `37`，park/decision 按契约为 `seq=0`，LLM challenge/install/models 全 `200`；确定性 graph 无 LLM completion。anchors `10/10`，`judge.py` `G1/F2/A5/C4/G2` 使账本 `1035→1040`，COVERAGE `EP-070=✓✓✓✓✓`，`alarms.py check`=`clean (1040)`，`gen_coverage.py --check`=`848/202/0`，阈值、算法、法典和锚点未改。

批次二十当前 **20/50**；未到第 50 格不跑统一长门禁、不提交。下一原子前线为 EP-071 `POST /api/v1/triggers`。

## 历史前线（EP-069，批次二十 15/50）

EP-069 `GET /api/v1/flowrun-matrix` 已完成真实 App、受管 Anselm gateway、Computer Use 和五通道验收。Scheduler 矩阵真实呈现 completed、failed、running/awaiting-approval、sparse/not-reached 四类状态；红格可打开精确失败 dossier，等待列可打开 Gantt/approval，Failed/Waiting/All 筛选与矩阵一致，逐帧没有裁切、溢出、跳变、死 spinner 或错误 CTA。

正式固定 session `/private/tmp/anselm-rig-ep069-flowrun-matrix-fixed-20260808/sessions/20260808-041832` 的录屏为 `293.975000s`，最终 backend/frontend/SSE/LLM journal 为 `402/18/18/1`，三路 SSE 均接通，managed gateway wiring 在线，`rig-check` 与 `rig-down` 通过且无 owned process/listener 残留。REST/SQLite 对证了 newest-first、ghost/空结果、重复去重、blank-only `400`、51-ID `422`、running/terminal elapsed 边界和每个 node 状态。

首轮真实清理发现并修复 scheduler rail 不消费 durable `notifications` 的 `workflow.deleted` 生命周期帧，导致 REST 已空时 UI 仍显示已删 workflow；新增 notification refetch 和回归测试，固定 session 真实收敛到 `No automation yet`。签名错误只作为可解释的 fixture failure 保留。证据为固定 session `evidence/EP-069-flowrun-matrix-real-session.md`，ledger re-audit 为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-069-flowrun-matrix-ledger-reaudit.md`；`judge.py` `G1/F2/A5/C4/G2` 使账本 `1030→1035`，COVERAGE `EP-069=✓✓✓✓✓`，anchors `10/10`，两条批量写账警报复审 ack 后 `alarms.py check` clean(1035)。

批次二十当时 **15/50**；下一原子前线为 EP-070 `POST /api/v1/flowruns/{id}/approvals/{node}:decide`。

## 历史前线（EP-068，批次二十 10/50）

EP-068 `GET /api/v1/flowrun-stats` 已完成五级验收。真实用户在 Scheduler Overview 看到 Running/Waiting/Failed/Next fire，构造真实 cron 停机跨刻度后看到 Missed KPI 与 schedule lane 的 `2 missed`，打开 workflow 详情看到真实 cron runs、矩阵、成功率和平均耗时。REST 覆盖 workspace totals、byWorkflow 顺序与 ghost、future/倒挂窗口、recent clamp、ID cap、坏时间和 missed；SQLite 保留 `2 missed + 3 started` firing 与 run/node 审计，三路 SSE 和 frontend/backend/LLM journal 无应用红线。

正式 session `/private/tmp/anselm-rig-ep068-flowrun-stats-fixed-20260808/sessions/20260808-035335`，证据 `/private/tmp/anselm-rig-ep068-flowrun-stats-fixed-20260808/sessions/20260808-035335/evidence/EP-068-flowrun-stats-real-session.md`，账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-068-flowrun-stats-ledger-reaudit.md`；账本 `1025→1030`，COVERAGE `EP-068=✓✓✓✓✓`，anchors `10/10`，`alarms.py check`=`clean (1030)`，阈值/算法未改。targeted scheduler unit/black-box 均绿，授权 cleanup `204×6→404×6`，tombstone 和审计保留。批次二十当前 **10/50**，未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-069 `GET /api/v1/flowrun-matrix`。

## 历史前线（EP-067，批次二十 5/50）

EP-067 `GET /api/v1/flowrun-inbox` 已完成五级验收。真实用户在 Scheduler 与通知托盘都能发现 parked approval，看到流程名、`Awaiting approval`、`human`、渲染问题、`1h left` 和 Approve/Reject；Approve、带理由 Reject、非法 decision、未知字段和重复决策均有正确的真实结果，决策后 UI 立即回到 `No approvals waiting on you.` / `Nothing is running right now.`，无死卡或旧 CTA。

正式 session `/private/tmp/anselm-rig-ep067-flowrun-inbox-20260808/sessions/20260808-033401` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend/backend journals、三路 SSE witness 和 LLM tap；录屏 `205.191667s / 2784x1808 / 60fps`。首轮 session 抓到 approval capsule 在异步长问题进入时真实 `RenderFlex overflowed by 18 pixels`，已直接修复为重新测量问题高度并用内容级溢出保护，补回归后最终 session clean。

REST/SQLite/SSE/UI 对证：`fr_30b3f4d1e090ee0d` 经真实 App Approve 为 `completed/decision=yes`；`fr_68dae31075077ccd` 经通知托盘填写理由并 Reject 为 `completed/decision=no`；`fr_86ea343f844bfb69` 的 `maybe`=`422 FLOWRUN_INVALID_DECISION`、未知字段=`400 INVALID_REQUEST` 且两次拒绝不消费 parked 行，随后正常决策收口；重复决策=`422`。最终 inbox=`{parked:[]}`，三条 run 各一个 terminal。entities durable `1..6`、notifications `1..3` 连续，三流均连接，deterministic graph 不伪造 LLM completion。

正式证据 `/private/tmp/anselm-rig-ep067-flowrun-inbox-20260808/sessions/20260808-033401/evidence/EP-067-flowrun-inbox-real-session.md`，ledger re-audit `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-067-flowrun-inbox-ledger-reaudit.md`；账本 `1020→1025 judgments`，COVERAGE `EP-067=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(1025)，三曲线阈值和算法未改。cleanup 为 workflow/approval `204×2→404×2`，tombstone/version/run/node 保留、relations=0、seeded entities 未动。`gen_coverage.py --check`=`848/199/0`，targeted Flutter `81` 项和 `flutter analyze` 全绿。

批次二十当前 **5/50**，未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-068 `GET /api/v1/flowrun-stats`。

## 历史前线（EP-065，批次十九 45/50）

EP-065 `POST /api/v1/flowruns/{id}:replay` 已完成五级验收。真实用户在 Scheduler 打开失败 run，查看失败节点和 traceback，确认 `Re-runs 1 failed nodes · reuses 2 completed results.`，然后在同一 dossier 中看到 `Replay #1`、四节点 completed、finish 输出和 Overview 的 `Failed · 24h 0`；完成 run 再次 replay 返回 `422 FLOWRUN_NOT_REPLAYABLE`，没有第二次 mutation。

正式 session `/private/tmp/anselm-rig-ep065-flowrun-replay-fixed-20260808/sessions/20260808-021122` 由同一 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend/backend journals、三路 SSE witness、真实 gateway LLM tap；录屏 `147.960000s / 2784x1808 / 60fps`。真实 webhook graph 为 `webhook → function → flaky handler → finish function`，capability-check clean。早先 test-only `trg_manual` 探索因悬空引用被排除，不计绿。

REST/SQLite/UI 对证：`POST /flowruns`=`201`，直接 replay=`202`，同 run `replayCount=1`、`flaky.n=2`、`finish.final=2`、四节点完成；第二次 replay=`422 FLOWRUN_NOT_REPLAYABLE`。每个 run 的 stable/finish 只执行一次，flaky 为一次 failed 加一次 replay success，completed nodes 被复用。backend/frontend/SSE/LLM journals 为 `296/18/48/10`，notifications `16..32`、entities `7..18` 单调，gateway challenge/install/models 全 200，无应用级未解释红线；失败 dossier、确认框、成功 inspector 和 Overview 逐帧无视觉缺陷。

正式证据 `/private/tmp/anselm-rig-ep065-flowrun-replay-fixed-20260808/sessions/20260808-021122/evidence/EP-065-flowrun-replay-final-green.md`，API probe 同目录 `EP-065-flowrun-replay-api-probes.md`，cleanup `/private/tmp/anselm-rig-ep065-cleanup-fixed-20260808/sessions/20260808-021437/evidence/EP-065-flowrun-replay-cleanup.md`。账本 `1010→1015 judgments` 按 `G1/F2/A5/C4/G2` 写入，COVERAGE `EP-065=✓✓✓✓✓`，anchors `10/10`；两条统计警报按原阈值独立复审并 ack，`alarms.py check` clean(1015)，`gen_coverage.py --check`=`848/197/0`。按授权 cleanup `204×5→404×5`，tombstone/version/run/node/execution 审计保留、relations=0、seeded entities 未动。批次十九当前 **45/50**，未到 50 格不跑统一长门禁、不提交；下一前线 EP-066 `POST /api/v1/flowruns/{id}:cancel`。

## 历史前线快照（EP-064，批次十九 40/50）

EP-064 `GET /api/v1/flowruns/{id}/activity` 已完成五级验收。真实用户在 Scheduler 打开完成 run，看到 function、handler、agent、MCP 四类真实执行组成的 Gantt，逐节点查看 output、排队/执行时长和 execution log；activity API 四表聚合、keyset 分页、空 run 和错误边界与 UI/SQLite 一致。

最终 session `/private/tmp/anselm-rig-ep064-flowrun-activity-20260808b/sessions/20260808-014240` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend/backend journal、三路独立 SSE witness、真实 gateway LLM tap；录屏 `475.320000s / 2784x1808`，绑定窗口 id `26407`。真实 run `fr_c322e8cac2176f65` 返回 `function 29ms → handler 0ms → agent 9707ms → mcp 3ms` 四行，全部 `ok` 且 `readyAt ≤ startedAt`；`limit=2` 两页无重无漏，trigger-only run 返回空数组，坏 cursor/zero limit/ghost run 分别为 `MALFORMED_CURSOR`/`INVALID_REQUEST`/`FLOWRUN_NOT_FOUND`。SQLite 对证 `flowrun_nodes=5` 与四张执行表各 1 行。

真实画面显示 `Done`、`9.8s`、`queued 0ms`、`ran 9.7s`、`v3 · pinned version`、`5 nodes · Completed 5`；Gantt 长 agent 条比例诚实，agent/MCP Inspector 均有 output 与 execution log ID。五通道 journal：backend 623 行、frontend 17 行、SSE 118 行、LLM 16 行；entities durable 到 14、notifications 到 22，真实 gateway `/v1/chat/completions` 200，前后端无未解释应用红线，`rig-check` 和 `rig-down` 通过。

本格没有产品源代码修复；清理第一命令只因 zsh 变量错误请求 `/api/v1/` 并全部 404，逐条绝对 URL 重跑后 DELETE `204×4`、exact GET `404×4`，属于台架命令错误，不计产品红。正式证据 `/private/tmp/anselm-rig-ep064-flowrun-activity-20260808b/sessions/20260808-014240/evidence/EP-064-flowrun-activity-real-session.md`，cleanup `/private/tmp/anselm-rig-ep064-cleanup-20260808/sessions/20260808-015120/evidence/EP-064-flowrun-activity-cleanup.md`；真实 run/审计保留，seeded entities 未动，relations=0。

正式账本 `1005→1010 judgments`，五级 `G1/F2/A5/C4/G2`，COVERAGE `EP-064=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(1010)，清册 `848 rows / 196 carried / 0 tombstones`；gap-too-fast/discovery-collapse 按本格独立复核 ack，阈值和算法不变。批次十九当前 **40/50**，未到 50 格不跑统一长门禁、不提交；下一前线 EP-065 `POST /api/v1/flowruns/{id}:replay`。

## 历史前线快照（EP-063，批次十九 35/50）

EP-063 `GET /api/v1/flowruns/{id}` 已完成五级验收。真实用户从 Scheduler 进入完成 run inspector，看到 Manual/Done、pinned version、`26 nodes · Completed 26`，首屏受界限显示部分节点，点击 `Show remaining 14` 后展开全部 26 个节点，再点击 node25 查看 output `{"ok":true}` 和 Completed execution log；没有重复、截断、死 loading 或无界倾倒。

最终 session `/private/tmp/anselm-rig-ep063-flowrun-get-20260808/sessions/20260808-012500` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend/backend journal、三路独立 SSE witness、真实 gateway LLM tap；录屏 `438.676667s / 2784x1808`，绑定窗口 id `26377`。API `limit=10` 三页为 `10+10+6`，节点 `node25..node16`、`node15..node06`、`node05..node01,start` 严格 newest-first、无重叠，三页 header 同一 run；unknown run、坏 cursor、`limit=0`、`limit=51` 和 cross-workspace lookup 均按契约处理。REST/SQLite/UI 一致，26 nodes/25 executions 全部 completed。

五通道证据：backend 590 行、frontend 18 行、SSE 124 行、LLM 16 行；entities durable `7..60`、notifications `16..19` 分 stream 连续单调，frontend/backend 无应用级未解释红线，受管网关 challenge/install/models 全 200，deterministic function workflow 不伪造 completion。`rig-check` 五通道全绿，`rig-down` 无残留；正式证据 `/private/tmp/anselm-rig-ep063-flowrun-get-20260808/sessions/20260808-012500/evidence/EP-063-flowrun-get-real-session.md`，账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-063-flowrun-get-ledger-reaudit.md`。

正式账本 `1000→1005 judgments`，五级 `G1/F2/A5/C4/G2`，COVERAGE `EP-063=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(1005)；集中写账的 gap-too-fast 已独立复审 ack，阈值和算法不变，清册 `848 rows / 195 carried / 0 tombstones`。按用户授权 cleanup `/private/tmp/anselm-rig-ep063-cleanup-20260808/sessions/20260808-013308` 删除 workflow/function/隔离 workspace，DELETE `204×3`、精确 GET `404×3`，主 workspace 保留，SQLite 保留 run/node/execution/version 审计且 relations=0。批次十九当前 **35/50**，未到 50 格不跑统一长门禁、不提交；下一前线 EP-064 `GET /api/v1/flowruns/{id}/activity`。

## 历史前线快照（EP-062，批次十九 30/50）

EP-062 `POST /api/v1/flowruns` 已完成五级验收。真实用户从 `Entities → ep062-manual-run` 进入 workflow debugger，点击 `Trigger` 后看到 `Done`、`Completed 2`、`107ms` 和 `accepted: true / source: ui`，再由 `Open run →` 到 Scheduler inspector 查看 Manual origin、queued/ran timing、pinned version 和 execution log。API 侧单 trigger、multi trigger 显式 `entryNode=t2`、unknown/malformed/invalid entry 负路径均与 handler 契约一致。

最终 session `/private/tmp/anselm-rig-ep062-flowrun-start-20260808/sessions/20260808-005702` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend/backend journal、三路 SSE witness、真实 gateway LLM tap；录屏 `1293.626667s / 2784x1808 / 60fps`。REST/SQLite/SSE/UI 交叉证明 `fr_0f741423bace74b4`、`fr_764f18dec3c769b1`、`fr_d7ea4365f1097af6`、`fr_8e32ab2d25642afb` 的状态、节点、输出和版本 pin 一致；负矩阵明确返回 `FLOWRUN_INVALID_ENTRY`、`INVALID_REQUEST`、`WORKFLOW_NOT_FOUND`，不创建幽灵 run。

五通道证据：backend 1582 行、frontend 20 行、SSE 87 行/55 durable frame、LLM 10 行；真实 UI run 的 entities durable seq `37/39/40` 为 `run_started/function close/run_terminal(completed)`，frontend/backend 无未解释应用红线，managed gateway challenge/install/models 全 200。最终帧、AX 树、API probe、session evidence 和 cleanup proof 均已封存；首轮 shell fixture SyntaxError 与 AX set_value 限制已明确分类为构造/仪器问题，不计产品缺陷。

正式账本 `995→1000`，五级 `G1/F2/A5/C4/G2`，COVERAGE `EP-062=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(1000)，清册 `848 rows / 194 carried / 0 tombstones`。集中写账触发的 `gap-too-fast` 已独立复审 ack，阈值和算法不变。按用户授权的独立 cleanup `/private/tmp/anselm-rig-ep062-cleanup-20260808/sessions/20260808-011934` 已删除 2 workflow、1 function，DELETE `204×3`、exact GET `404×3`、live workflow list 空；SQLite 保留 tombstone、3 versions、8 flowruns、8 function executions，relations=0，seeded 数据未动。批次十九当前 **30/50**，未到 50 不跑统一长门禁、不提交；下一前线 EP-063 `GET /api/v1/flowruns/{id}`。

## 历史前线快照（EP-061，批次十九 25/50）

EP-061 `GET /api/v1/flowruns` 已完成五级验收。Workflow detail 的 Runs cockpit 真实走 keyset `20→28`；Scheduler 真实走 offset `29` 行、1/2/3 页及 Manual/Webhook 来源筛选；失败 workflow、Waiting approval、Running 和 Cancelled inspector 均可达且状态、traceback、Replay/Cancel/approval CTA 与 REST 一致。

最终 session `/private/tmp/anselm-rig-ep061-flowruns-20260808/sessions/20260808-003250` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend/backend journal、三路 SSE witness、真实 gateway LLM tap；录屏 `630.583333s / 2784x1808 / 60fps`。API/SQLite 证明 cursor/offset 无重叠且顺序一致，半开时间窗、非法筛选、未知复合筛选和 completed/failed/running/cancelled 桶均正确；工作区 fixture 最终 34 条 flowrun 为 `30 completed / 2 failed / 2 cancelled`，主 workflow 29 条完成历史。

五通道证据：backend 915 行、frontend 17 行、SSE 111 行/107 frame、LLM 10 行；notifications `16..37`、entities `7..77` durable seq 单调，受管网关 challenge/install/models 全 200，无虚构 completion；frontend/backend 无未解释应用红线，`rig-check` 和 `rig-down` 通过。正式证据、API probe、SSE summary 和 final frame 均在 session evidence 中，账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-061-flowruns-ledger-reaudit.md`。

正式账本 `990→995`，五级 `G1/F2/A5/C4/G2`，COVERAGE `EP-061=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(995)，清册 `848 rows / 193 carried / 0 tombstones`。`gap-too-fast` 仅按独立复审 ack，阈值和算法不变；本格没有产品源代码修复，针对性 Go/Flutter、coverage 和 diff 检查通过。按用户授权的独立 cleanup `/private/tmp/anselm-rig-ep061-cleanup-20260808/sessions/20260808-004956` 已删除 5 workflow、5 trigger、1 approval、1 function，全部 `204→404`，live lists 空，relations=0，34 flowruns/8 versions/4 firings 保留，seeded 数据未动。批次十九当前 **25/50**，未到 50 不跑统一长门禁、不提交；下一前线 EP-062。

## 历史前线快照（EP-060，批次十九 20/50）

EP-060 `GET /api/v1/workflows/{id}/versions/{version}` 已完成五级验收。首轮真实 session
`/private/tmp/anselm-rig-ep060-workflow-version-20260808/sessions/20260808-001344` 发现并保留真实跨父泄漏：A 的 opaque version ID 放到 B 的 URL 仍返回 A 的 graph。修复新增父级 `(workflow_id,id)` 查询，保持 scheduler 的全局 pinned 读取不变，并补 store/app/handler regression。

固定 session `/private/tmp/anselm-rig-ep060-workflow-version-fixed-20260808/sessions/20260808-001940`
由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend/backend journal、三路 SSE
witness、真实 gateway LLM tap。真实 App 在 `Entities → Workflow → Versions` 显示 v2 展开、v1→v2
diff、完整 trigger graph，最终录屏 `106.916667s / 2784x1808 / 60fps`；backend/frontend 无未解释
红线。REST 证明 A 自有数字/opaque 均 200，B 读取 A opaque、B v2、A 的 0/-1/999/unknown 均
`404 WORKFLOW_VERSION_NOT_FOUND`；SSE notifications durable `16,17,18` 单调，LLM readiness
challenge/install/models 全 200，read-only 路径不虚构 completion；`rig-check`、`rig-down` 通过。

独立 cleanup `/private/tmp/anselm-rig-ep060-cleanup-20260808/sessions/20260808-002310` DELETE
workflow/trigger=`204×4`、后续 GET=`404×4`、live lists 为空；SQLite 保留两条 workflow tombstone、
3 条版本历史、两条 trigger tombstone、fixture relations=0，seeded `演示对话` 未动。正式证据
`.../evidence/EP-060-workflow-version-final-green.md`，账本复审
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-060-workflow-version-ledger-reaudit.md`；
账本 `985→990`，COVERAGE `EP-060=✓✓✓✓✓`，anchors `10/10`，alarms clean(990)，清册
`848 rows / 192 carried / 0 tombstones`。批次十九当前 **20/50**，未到 50 不跑统一长门禁、不提交；
下一原子前线为 EP-061 `GET /api/v1/flowruns`。

## 历史前线快照（EP-059，批次十九 15/50）

EP-059 `GET /api/v1/workflows/{id}/versions` 已完成五级验收。真实用户从 Entities 找到 `ep059-workflow-versions`，进入 Versions tab，首屏看到 v22..v3 与明确的 `Load more`，点击后追加 v2、v1；首行 v22 自动展开，差异、版本号、时间和变更原因可读，追加无重复且完成后无死控件。

真实 session `/private/tmp/anselm-rig-ep059-workflow-versions-20260808/sessions/20260807-235745` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend/backend journal、三路独立 SSE witness、真实 gateway LLM tap；录像 `251.178333s / 2784x1808 / 60fps`，最终帧显示 v15..v1。fixture workflow `wf_e6a23f5c4c1e6ad0`、trigger `trg_dc40065b733c5085` 通过 21 次真实 `:edit` 形成 v1..v22。

REST/SQLite/SSE/UI 交叉一致：分页页 1 为 `22..3`、页 2 为 `2..1` 严格无重叠；数字和 opaque ID 单读均指向 v22；`limit=0` 为 `400 INVALID_REQUEST`，坏 cursor 为 `400 MALFORMED_CURSOR`；SQLite 保留 22 个版本行；notifications durable seq `16..37` 严格单调无 gap；backend/frontend 无未解释运行期红线；`rig-check`、`rig-down` 全部通过，收台无残留。

正式证据 `/private/tmp/anselm-rig-ep059-workflow-versions-20260808/sessions/20260807-235745/evidence/EP-059-workflow-versions-final-green.md`，账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-059-ledger-alarm-reaudit.md`；五级 `G1/F2/A5/C4/G2` 已写入，账本 `980→985`，COVERAGE 为 `EP-059=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(985)，清册 `848 rows / 191 carried / 0 tombstones`。集中写账触发的 `gap-too-fast` 已独立复审并 ack，阈值和算法未变。

独立 cleanup `/private/tmp/anselm-rig-ep059-cleanup-20260808/sessions/20260808-000634` 已按用户授权软删 workflow/trigger：DELETE `204×2`、GET `404×2`、live lists 为空、22 个版本行和主行 deleted_at 保留、relations=0、seeded `演示对话` 未动。批次十九当前 **15/50**，未满 50 格不跑统一长门禁、不提交；下一前线为 EP-060。

## 历史前线快照（EP-058，批次十九 10/50）

EP-058 `POST /api/v1/workflows/{id}:iterate` 已完成五级验收。真实用户从 Workflow 行选择 `Edit with AI` 后进入持久 AI 编辑对话；模型读取精确 workflow、trigger、relations 和 agent，再用一次 canonical `edit_workflow` 将图从 v1 改到 v2。首轮、fixed2、fixed3 的真实红 session 分别保留了 malformed target/ops、重复 trigger/error 展示和空参 trigger 调用；这些红证据不计绿。最终 fixed4 中第一次 answer 输入失败形成 `Empty answer`，也保留为红观察；重新提交明确请求后 App 最终稳定显示 v2、`entry → summarize` 和三条成功 Activity，无红卡/retry/duplicate mutation。

最终 session `/private/tmp/anselm-rig-ep058-workflow-iterate-fixed4-20260807/sessions/20260807-233816` 由同一 conductor 托管真实 Flutter App、Computer Use、录屏、frontend/backend journal、三路独立 SSE、真实 gateway LLM tap。录屏封口 `571.585000s / 2784x1808 / 60fps`；messages durable `1..94`、entities `7..8`、notifications `16..19` 无 gap；LLM chat responses 全 200，backend/frontend 无未解释应用红线，REST/SQLite 与 UI、tool result、SSE、LLM wire 一致。whitespace request 的 `400 EMPTY_ITERATE_REQUEST` 和 missing workflow 的 `404 WORKFLOW_NOT_FOUND` 均无新 conversation。

正式绿证据 `/private/tmp/anselm-rig-ep058-workflow-iterate-fixed4-20260807/sessions/20260807-233816/evidence/EP-058-workflow-iterate-final-green.md`、ledger/alarm 复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-058-ledger-alarm-reaudit.md` 已封存；账本 `975→980` 按 `G1/F2/A5/C4/G2` 写入五格，COVERAGE EP-058=`✓✓✓✓✓`，anchors 10/10，`alarms.py check` clean(980)，`gen_coverage.py --check` 为 `848 rows / 190 carried / 0 tombstones`。按用户授权的独立无 App cleanup 已删除 conversation/workflow/trigger，DELETE `204×3`、GET `404×3`、版本/消息审计保留、relations=0、seeded 对话未动、收台无残留。批次十九当前 **10/50**，未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-059 `GET /api/v1/workflows/{id}/versions`。

## 历史前线快照（EP-056，批次十八 50/50）

EP-056 `POST /api/v1/workflows/{id}:revert` 已完成五级验收。真实用户在 Workflow Versions 页面从 v3 依次选择 v2、v1 的 `Set active`，header、绿色 active marker 和历史 diff 均即时一致；版本历史不被删除、不产生 v4，非法 version `999`/`0` 均明确返回 `404 WORKFLOW_VERSION_NOT_FOUND`。

最终 session `/private/tmp/anselm-rig-ep056-workflow-revert-20260807/sessions/20260807-214211` 由 conductor 托管真实 Flutter App、Computer Use、录屏、frontend console、backend、三路独立 SSE、LLM tap 和受管网关。录屏 `338.140000s / 2784x1808 / 60fps`，关键帧和五通道证据已封存；backend `459` 行、frontend `76` 行无未解释应用红线，notifications durable seq `16..20` 单调无 gap，收台后 owned process groups 归零。

正式绿证据 `/private/tmp/anselm-rig-ep056-workflow-revert-20260807/sessions/20260807-214211/evidence/EP-056-workflow-revert-final-green.md`、ledger/alarm 独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-056-workflow-revert-ledger-alarm-reaudit.md` 已封存；账本 `965→970` 按 `G1/F2/A1/C4/G2` 五格，COVERAGE EP-056=`✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(970)，`gen_coverage.py --check` 为 `848 rows / 188 carried / 0 tombstones`。

批次十八 50/50 后统一门禁一次完成：`make verify` 的 backend/frontend/docs/demo 全绿；完整 `go test -count=1 -timeout 20m ./...` 全绿；本批修复场景前端定向回归 `79` 项与 analyze 全绿；`make -C backend testend` 全绿（`testend/scenarios 298.841s`），未放宽阈值。按用户授权的无 App cleanup session `/private/tmp/anselm-rig-ep056-cleanup-20260807/sessions/20260807-220655` 已删除专用 workflow/trigger，版本 history 保留、relations=0、收台无残留。下一原子前线为 EP-057 `POST /api/v1/workflows/{id}:capability-check`。

## 历史前线快照（EP-055，批次十八 45/50）

EP-055 `POST /api/v1/workflows/{id}:edit` 首轮抓到旧 viewport 未 fit 和全屏编辑路由没有 notice host 两个产品缺陷；stop-and-fix 后 pristine viewport 会在结构变更后 fit，用户主动变换的 viewport 保持，结构化 `WORKFLOW_INVALID_GRAPH` 在顶层可见。最终真实 session、REST/SQLite/SSE、前端运行期、ledger/alarm 和 cleanup 证据均已封存；COVERAGE `EP-055=✓✓✓✓✓`，账本 `955→960` 红、`960→965` 绿，批次由 `40/50→45/50`。

## 历史前线快照（EP-053，批次十八 35/50）

EP-053 `POST /api/v1/workflows/{id}:deactivate` 已完成五级验收：真实用户从 Workflow 详情 Activate 后用真实 webhook 把流程停在 approval，在不离开 Runs 面板的情况下 Deactivate；App 明确呈现 `draining`，在途 parked run 不被杀掉，approval 决策完成后自动收口到 `inactive`。停用后的 webhook 返回 404，重复 Deactivate 为 200 且不重复 listener/run/history。首轮无产品缺陷；错误 capability 探针和错误 llmtap 端口 session 均被排除，不进入正式绿证据。

最终 session `/private/tmp/anselm-rig-ep053-workflow-deactivate-20260807/sessions/20260807-200724` 由 conductor 托管真实 Flutter App、Computer Use、录屏、frontend console、backend、三路独立 SSE witness、LLM tap 和受管网关。真实画面 `inactive → active / Listening → webhook park → draining → approval yes → inactive`；录屏 `360.425000s / 2784x1808 / 60fps`，两张关键帧已封存。REST/SQLite 证明最终 workflow inactive、trigger 不监听，保留一条 completed webhook flowrun、两个 completed node、一个 firing、两类 v1 history；关系在清理后为 0。

五通道封口：backend `476` 行无应用红线；frontend `114` 行，其中 96 条已逐条归类为固定 AXTree bridge tooling pattern，未知模式仍 fail-closed；SSE 记录 `active → draining → inactive` 与 `run_started(seq=1) → run_terminal(seq=2,completed)` 并正常 EOF；LLM 仅 readiness，不虚构 completion。正式账本 `940→945`，COVERAGE EP-053=`✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(945)，`gen_coverage.py --check` 为 `848 rows / 185 carried / 0 tombstones`。正式绿证据和 ledger/alarm 复审均已写入 `/private/tmp/anselm-rig-formal-20260801-3/evidence/`。

按用户授权，独立无 App cleanup session `/private/tmp/anselm-rig-ep053-final-cleanup-20260807/sessions/20260807-201616` 已删除本格三件专用夹具：DELETE `204×3`、后续 GET `404×3`、flowruns `200`；软删除主行、flowrun/node/firing/version history 保留，关系边为 0，收台后无残留进程。批次十八由 **30/50→35/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-054 `POST /api/v1/workflows/{id}:kill`。

## 历史前线快照（EP-050，批次十八 20/50）

**状态修订。** `POST /api/v1/workflows/{id}:trigger` 已在真实 App、Computer Use、受管网关和五通道台架下完成：用户从 Scheduler workflow 详情页发现 `Run now`，空 body 手动执行后得到 toast、绿色 run、Matrix 与详情入口；第二次带 payload 的真实请求在 UI 中汇聚为第二条绿色 Manual run。workflow 保持 inactive，trigger 仍 `never fired`，证明手动执行与监听触发没有混淆；错误 payload 返回 `400 INVALID_REQUEST` 且不创建 run。

正式 session `/private/tmp/anselm-rig-ep050-workflow-trigger-20260807/sessions/20260807-180921` 录屏 `427.206667s / 2784x1808 / 60fps`，backend 549 行、frontend 17 行、LLM ready-only，三路 SSE 全连接并记录 entities durable seq `1..4`，收台无残留。REST/SQLite 交叉证明 `fr_e87daec34cb74b0a` 与 `fr_58e12b1ffac09e2e` 均 completed、manual、pinned v1；payload 在 trigger node result 中原样保留。前端唯一启动阶段 Flutter runner `open returned 1` 已单独记录，不作为运行期错误豁免；未知前端错误仍 fail-closed。

正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-050-workflow-trigger-final-green.md`，前端运行期复核 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-050-frontend-runtime-review.md`，警报复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-050-ledger-alarm-reaudit.md`。anchors `10/10` 后按 `G1/F2/A5/C4/G2` 写入 `COVERAGE` 为 `✓✓✓✓✓`，正式账本 `910→915 judgments`；集中写账触发的两条统计警报已独立复审并 ack，阈值与算法未修改，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 182 carried / 0 tombstones`。EP-050 没有源代码修复。批次十八当前 **20/50**，未到 50 格不运行统一长门禁、不提交；下一原子前线为 `EP-051 POST /api/v1/workflows/{id}:stage`。

## 历史前线快照（EP-048，批次十八 10/50）

**状态修订。** `PATCH /api/v1/workflows/{id}` 已在真实 App、Computer Use、受管网关和五通道台架下完成：首轮静态治理卡红证据、第一修复菜单文案截断红证据均保留；
最终 binary 的治理卡下拉完整显示五种策略及短解释，真实选择 `Keep latest` 后 wire 值为 `buffer_one`，详情回读稳定，v1/active version 不变。
REST PATCH/GET 均 200，SQLite 版本数为 1，notifications 收到 durable `workflow.updated`；最终 session
`/private/tmp/anselm-rig-ep048-workflow-patch-fix-20260807/sessions/20260807-173308` 五通道齐全，录屏已封口，收台无残留，frontend/backend 无未解释应用级红线。
正式账本 `900→905 judgments`，COVERAGE `EP-048=✓✓✓✓✓`，anchors `10/10`；两条统计警报经独立复审 ack 后 `alarms.py check clean`，
`gen_coverage.py --check` 为 `848 rows / 180 carried / 0 tombstones`。

批次十八当前 **10/50**。本格运行了 `make gen`、Workflow overview Flutter 11 项回归、目标 Flutter analyze、Workflow app/handler Go tests 与格式/差异检查；
未到 50 格，不运行统一长门禁、不提交。下一原子前线为 `EP-049 DELETE /api/v1/workflows/{id}`。

## 历史前线快照（EP-045，批次十七 45/50；以下旧段为历史快照）

**历史状态修订。** `POST /api/v1/workflows` 已完成真实 Chat → trigger search → 单次 create mutation → inactive workflow 产品路径。
用户输入提交前由 Computer Use AX 核对，最终 workflow 只有一个既有 trigger 节点，description/tags/changeReason、版本和 inactive
状态在 UI、REST、SQLite、SSE 与 LLM wire 上一致；稳定态没有失败卡、retry 或 duplicate trigger。

两轮红场次永久保留且不冒充绿：`/private/tmp/anselm-rig-ep045-workflow-create-20260807/sessions/20260807-152351` 的输入注入丢下划线/标点，
模型随后发不支持的扁平 `nodeId/triggerId`；`.../sessions/20260807-153602` 的输入保真已通过，但模型先发 `nodes`/`edges` graph snapshot，
真实 UI 留下 `create_workflow Failed` 与 `Draft unsaved` 后才自修。stop-and-fix 在边界加入两种精确兼容：trigger shorthand 仅无冲突地
做 `nodeId→node.id`、`triggerId→node.ref` 且限制 `kind=trigger`；精确 `nodes`+`edges` snapshot 只映射已观察的 `type/triggerId→kind/ref`
并展开 add_node/add_edge。未知键、缺数组、冲突、错误 kind 和其它对象仍拒绝；schema、domain、tools 清册与 decoder/Execute 回归一并同步。

最终绿 session `/private/tmp/anselm-rig-ep045-workflow-create-20260807/sessions/20260807-154617` 由 conductor 托管真实 Flutter App、Computer Use、
窗口 recorder、frontend console、backend journal、三路独立 SSE、LLM tap 和受管网关；模型先查 `ep045-snapshot-trigger-green`，再一次成功调用
`create_workflow`，无失败/重试。UI 结果表展示 `ep045-snapshot-digest`、描述、三枚 tags、既有 trigger、`Inactive (deactivated)`、v1；Activity
只有 Created。后端 workflow `wf_64daa9eefc827154` 的图为唯一 trigger `trg_f3b9a6e64e4a68e9`，edges 为空；三流有 tool/build/`workflow.created`/
touchpoint，前端无应用级 Dart/Flutter/RenderFlex/Unhandled/overflow 红线，LLM proof/chat 全经 `https://api.anselm.website`，收台无残留。

正式证据见 `/private/tmp/anselm-rig-ep045-workflow-create-20260807/sessions/20260807-154617/evidence/EP-045-workflow-create-final-green.md`，
红证据同目录两份，独立复核见 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-045-workflow-create-ledger-reaudit.md`。anchors `10/10` 后按
`G1/F2/A1/C4/G2` 写账，COVERAGE `EP-045=✓✓✓✓✓`，账本 **885→890 judgments**；两条统计警报按复核 ack，阈值算法未改，
`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 177 carried / 0 tombstones`。

批次十七当前 **45/50**；未满 50 格不跑统一长门禁、不提交；机械清册下一原子前线为 `EP-046 GET /api/v1/workflows`。

## 历史前线快照（EP-044，批次十七 40/50）

**状态修订。** `GET /api/v1/agent-executions/{id}` 已完成真实 Agent Logs 单执行详情产品路径：列表保持轻量，用户首次展开
历史行时真实懒取单条详情，能看到版本、provider/model、输入输出、耗时和完整 transcript；详情不会被后续 durable close
重取意外降级成摘要，也不要求再次调用模型。

首个真实红 session `/private/tmp/anselm-rig-ep044-agent-execution-detail-20260807/sessions/20260807-150221` 证明旧实现
只有列表投影：展开后没有 transcript，也没有 `GET /api/v1/agent-executions/{id}`。stop-and-fix 新增 repository 单读、Agent
行首次展开 lazy fetch、共享 transcript hydration 与既有 `BlockTreeView`，并补齐版本/耗时/开始结束时间和已加载详情保留。
红 session 与红证据保留，不计绿。

最终真实绿 session `/private/tmp/anselm-rig-ep044-agent-execution-detail-20260807/sessions/20260807-150928`：Computer Use
从 Agent → Logs → 最新 `manual · ok` 行展开，看到 `agv_96efb03aec9f0423`、`3617ms`、时间字段、`Trace · 2 steps`；点击
Reasoning 后五步 reasoning 完整可读，最终 `1764` text 保持可见。真实 backend journal 记录单条详情 GET `200 / 1159 bytes`，
列表与单读边界清楚；SQLite、REST transcript 与 UI 匹配。

五通道：screen `121.028333s / 2784x1808 / 60fps`；backend 无应用 WARN/ERROR/panic/fatal/4xx/5xx；SSE 三流均连接、正常收台；
frontend 无 Dart/Flutter/RenderFlex/Unhandled/overflow 应用红线，仅保留已知 macOS launcher foreground 噪声；LLM tap 真实连接
`https://api.anselm.website`，本历史读取路径不虚构新的 completion；`rig-check` 通过、`rig-down` 封口且进程归零。正式证据见
`/private/tmp/anselm-rig-ep044-agent-execution-detail-20260807/sessions/20260807-150928/evidence/EP-044-agent-execution-detail-final-green.md`，
独立复核见 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-044-agent-execution-detail-ledger-reaudit.md`。anchors `10/10` 后按
`G1/F2/A1/C4/G2` 写入，账本 **880→885 judgments**，COVERAGE `EP-044=✓✓✓✓✓`；两条统计警报经独立复核 ack，阈值与算法未修改，
`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 176 carried / 0 tombstones`。

批次十七当前 **40/50**；未到 50 格，不跑统一长门禁、不提交；机械清册下一原子前线为
`EP-045 POST /api/v1/workflows`。

## 历史前线快照（EP-043，批次十七 35/50）

**历史状态。** `GET /api/v1/agents/{id}/executions` 已完成真实 Agent Logs 产品路径：完整执行历史、aggregates、展开详情、分页和
外部执行实时收口均与右侧运行台一致。首个真实 session 发现未知父 Agent 错误返回 `200` 空历史；修复后重跑又发现已打开 Logs
不跟随外部 18 次执行，右岛为 21 而 Logs 仍为 3。两条红 session 均保留；stop-and-fix 增加父实体预检，以及 Logs 对 durable
`FrameClose` 的去抖 REST 重取、展开行保留、最近可信快照和 load-more 游标竞态保护，并补测试/文档。

最终真实 session `/private/tmp/anselm-rig-ep043-agent-executions-20260807/sessions/20260807-144741`：真实 REST `:invoke` 输入
`number=42` 穿过 `https://api.anselm.website` 后返回 `agx_2bb96a87c0d3ce15` / `ok` / `1764`；已打开 Logs 不刷新即从
`21 Done / 0 Failed` 变为 `22 Done / 0 Failed`，右岛同步 `22 total runs · last ok 3.6s`，最新行置顶、可展开且详情显示真实 ID、输入、
输出、provider/model 和 `Use this input`。REST 页为 `20+2` 无重叠、aggregate `22/22/0`；failed 空筛选、非法 status `422`、未知父 `404`
均诚实。

五通道：screen `183.773333s / 2784x1808 / 60fps`；backend `254` 行无应用红线；SSE 三流均连接，Agent scope 为真实
`open → seq=0 delta → durable close`；frontend `18` 行无 Dart/Flutter/RenderFlex/Unhandled/overflow 应用红线，仅保留 raw journal
中的已知 macOS launcher foreground 噪声；LLM tap proof/chat HTTP 200；`rig-check` 通过、`rig-down` 封口且进程归零。正式证据见
`/private/tmp/anselm-rig-ep043-agent-executions-20260807/sessions/20260807-144741/evidence/EP-043-agent-executions-final-green.md`，
独立复核见 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-043-agent-executions-ledger-reaudit.md`。anchors `10/10` 后按
`G1/F2/A1/C4/G2` 写入，账本 **875→880 judgments**，COVERAGE `EP-043=✓✓✓✓✓`；两条统计警报经独立复核 ack，阈值与算法未修改，
`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 175 carried / 0 tombstones`。
批次十七当前 **35/50**，未到 50 格，不跑统一长门禁、不提交；机械清册下一原子前线为
`EP-044 GET /api/v1/agent-executions/{id}`。

## 历史前线快照（EP-042，批次十七 30/50）

**状态修订。** `GET /api/v1/agents/{id}/versions/{version}` 已完成真实 Agent Versions 单版本产品路径：数字版本和
opaque `agv_` 版本 ID 都只能解析到路径中的 Agent，跨父版本和未知父 Agent 均明确 not-found。首个真实负路径发现
opaque ID 走全局查找，另一 Agent 的 v4 与未知父 Agent 错误返回 200；stop-and-fix 增加 parent-scoped repository lookup，
app 先校验父 Agent，数字/opaque 共用边界，并补 store/app 回归测试与 API/domain 文档。红 session
`/private/tmp/anselm-rig-ep042-agent-version-detail-20260807/sessions/20260807-141645` 保留，不进入绿判。

固定版真实 session `/private/tmp/anselm-rig-ep042-agent-version-detail-20260807/sessions/20260807-142043`：自有数字/opaque v4、
自有数字 v1 为 200；跨父数字/opaque v4 为 404 `AGENT_VERSION_NOT_FOUND`；未知父数字/opaque 为 404 `AGENT_NOT_FOUND`；
自有未知版本为 404 `AGENT_VERSION_NOT_FOUND`。Computer Use 看到 v4→v3、v3→v2 diff、v1 完整 prompt 和 earliest version，
无裁切、重叠、stale row 或错误归属；SQLite 为 active v4、版本 `[4,3,2,1]`。

五通道封口：screen `129.010000s / 2784x1808 / 60fps`，backend `196` 行无应用红线，frontend `18` 行无 Flutter/Dart/
RenderFlex/Unhandled/overflow/失联红线，SSE 三流连接并正常收台，因只读 GET 无 durable mutation frame；LLM tap 真实绑定
`https://api.anselm.website`，仅记录 ready、不虚构 completion。正式证据见
`/private/tmp/anselm-rig-ep042-agent-version-detail-20260807/sessions/20260807-142043/evidence/EP-042-agent-version-detail-final-green.md`，
独立复核见 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-042-agent-version-detail-ledger-reaudit.md`。
anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 **870→875 judgments**，COVERAGE `EP-042=✓✓✓✓✓`；统计警报经逐条复核
ack，阈值与算法未修改，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 174 carried / 0 tombstones`。
批次十七当前 **30/50**，未到 50 格，不跑统一长门禁、不提交；机械清册下一原子前线为
`EP-043 GET /api/v1/agents/{id}/executions`。

## 历史前线快照（EP-041，批次十七 25/50）

**历史状态。** `GET /api/v1/agents/{id}/versions` 已完成真实 Agent Versions 产品路径：真实 App 展示 active v4、v3/v2/v1 历史、可展开 diff 和
`v1 · earliest version`，REST 分页 `[4,3]`/`[2,1]`、数字/opaque v4 与 UI/SQLite 严格一致。首个正确接线 session 发现未知父 Agent 被错误返回为
`200` 空历史；已按 stop-and-fix 修复 `ListVersions` 的父实体预检，补回归测试和 API/domain 文档，再以新 binary 重跑得到 `404 AGENT_NOT_FOUND`。
前一条 `8806` 接线错误和修复前红 session 均保留，未进入绿判。

绿 session `/private/tmp/anselm-rig-ep041-agent-versions-fixed-20260807/sessions/20260807-140622`：screen `256.180000s / 2784x1808 / 60fps`，backend `320` 行无应用红线，
frontend `18` 行无 Flutter/Dart/RenderFlex/Unhandled/overflow/失联红线，SSE 三流均连接并正常收台，LLM tap 真实绑定 `https://api.anselm.website`；本只读 GET 不产生
completion 或伪造 durable mutation frame。录屏关键帧、REST 负边界、SQLite `active v4 + [4,3,2,1]` 与原生 Computer Use 树均已在证据文件交叉复核。

正式证据见 `/private/tmp/anselm-rig-ep041-agent-versions-fixed-20260807/sessions/20260807-140622/evidence/EP-041-agent-versions-final-green.md`，独立复核见
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-041-agent-versions-ledger-reaudit.md`。anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 **865→870 judgments**，
COVERAGE `EP-041=✓✓✓✓✓`；两条统计警报经独立复核 ack，阈值与算法未修改，`alarms.py check` clean，`gen_coverage.py --check` 为
`848 rows / 173 carried judgments / 0 tombstones`。批次十七当前 **25/50**，未到 50 格，不跑统一长门禁、不提交；机械清册已确认 EP-040 的五级裁决仍有效，
下一原子前线为 `EP-042 GET /api/v1/agents/{id}/versions/{version}`。

## 历史前线快照（EP-039，批次十七 20/50）

**历史状态。** `POST /api/v1/agents/{id}:iterate` 已完成真实 Agent `Edit with AI` 产品路径：真实 App
从 Agent 行菜单创建可识别的 AI 编辑对话，seed 自动命名并读取 v3 配置；用户 follow-up 只产生一次
规范 `edit_agent`，铸造 v4 `agv_1890517a41cdc11b` 并立即 active。Versions 显示可读 `v3 → v4` diff，
mount、inputs/outputs 和其它字段保留；随后 v4 真实 invoke 返回 `{"receipt":"EP039","total":0}`。

空 request 只返回 `400 EMPTY_ITERATE_REQUEST`，未知 Agent 只返回 `404 AGENT_NOT_FOUND`；前后 conversation
数均保持 1，无 v5、retry、部分写入或幻影会话。最终 session
`/private/tmp/anselm-rig-ep039-agent-iterate-20260807/sessions/20260807-134539` 的五通道全部封口：
screen `301.048333s / 2784x1808 / 60fps`；backend `422` 行无应用红线；SSE notifications `1..3`、
messages `1..35`、entities `1..10` 连续无 gap；frontend `20` 行无 Flutter/Dart/RenderFlex/Unhandled/
overflow/失联红线，仅有已审计的 macOS launcher/IMK 平台噪声；LLM tap 真实连接
`https://api.anselm.website`，8 次 completion 响应全 200。UI、REST、SQLite、SSE、wire 和录屏关键帧对 v4、
会话标题和最新 execution `agx_c7ec1079661121` 一致；rig-down 后进程组归零。

正式证据见 `/private/tmp/anselm-rig-ep039-agent-iterate-20260807/sessions/20260807-134539/evidence/EP-039-agent-iterate-final-green.md`，独立复核见 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-039-agent-iterate-ledger-reaudit.md`。
anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 **860→865 judgments**，COVERAGE `EP-039=✓✓✓✓✓`；
两条统计警报经独立复核 ack，阈值与算法未修改，`alarms.py check` clean，`gen_coverage.py --check` 为
`848 rows / 172 carried judgments / 0 tombstones`。批次十七当前 **20/50**，未到 50 格，不跑统一长门禁、
不提交；机械清册已确认 EP-040 的五级裁决存在且无需重复写账，下一前线为
`EP-041 GET /api/v1/agents/{id}/versions`。

## 历史前线快照（EP-038，批次十七 15/50）

EP-038 的完整证据、五通道事实和批次位置保留在
`README.md §5.2` 的历史快照与 `LOG.md`；COVERAGE 当前行和正式账本均已封口为 `✓✓✓✓✓ / 860 judgments`。

## 历史前线快照（EP-037，批次十七 10/50）

**状态修订。** `POST /api/v1/agents/{id}:revert` 已完成真实 Agent 版本回退路径。真实 App 在 Versions
中展示 v1/v2 diff 和 active 标记；用户先将 v2 回退到 v1，再在 v2 active 下通过受管网关运行
`subtotal=100,tax=10` 得到 `total=110`，最后在结果仍可见时切回 v1。最终右岛清掉旧版本的瞬态
Trace/Result，但保留最新 Recent 审计行；版本历史和 active 指针都可读且一致。

真实负路径对 `version=999` 只发一次 HTTP 请求，返回 `404 AGENT_VERSION_NOT_FOUND`；没有 retry、v3
或指针突变。最终 session `/private/tmp/anselm-rig-ep037-agent-revert-20260807/sessions/20260807-132025`
的录屏、backend、三路 SSE、Flutter console 和受管网关 LLM tap 全部封口：screen `427.071667s / 2784x1808 /
60fps`；backend 546 行无应用红线；notifications durable `1..4`、entities `1..10` 单调；LLM
proof/chat status 全 200；SQLite/REST/UI/SSE/wire 对 `total=110` 和最终 active v1 一致。frontend 的
固定 AXTree 旧节点提示由 session-scoped review 明示为观察器噪声，三秒静置不增长，未知 AX 或 Flutter
runtime 错误仍硬失败；rig-down 后进程组归零。

正式证据见 `/private/tmp/anselm-rig-ep037-agent-revert-20260807/sessions/20260807-132025/evidence/EP-037-agent-revert-final-green.md`，独立复审见 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-037-agent-revert-ledger-reaudit.md`。
anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 **850→855 judgments**，COVERAGE `EP-037=✓✓✓✓✓`；
两条统计警报经独立复审 ack，阈值未放宽，`alarms.py check` clean，`gen_coverage.py --check` 为
`848 rows / 170 carried judgments / 0 tombstones`。批次十七历史位置 **10/50**；下一原子已由 EP-038 接续。

## 历史前线快照（EP-036，批次十七 5/50）

**状态修订。** `POST /api/v1/agents/{id}:invoke` 已完成真实 Agent 调用路径。真实用户从 Agent 详情
点击 Invoke 后立即看到 `Cancel`/`Waiting for output...`，本地 UI 示例正常完成；随后在旧结果仍可见时
从 REST 发起 `subtotal=400,tax=60` 的独立调用，右岛切换为新的 observed run，trace、Result 与
Recent 均显示同一笔 `total=460`，不再混入旧 `total=0`。

首轮真实路径发现 stale-result 产品缺陷，已在前端执行面板加入 durable close 后账本重取和 settled
面板的顶层 observed-run reset，并补 controller 测试与实体文档。最终 session
`/private/tmp/anselm-rig-ep036-agent-invoke-20260807/sessions/20260807-131105` 的录屏、backend、
三路 SSE、Flutter console 和受管网关 LLM tap 全部封口：screen `177.275000s / 2784x1808 / 60fps`；
backend 240 行无应用级红线；frontend 17 行无 Flutter/Dart/RenderFlex/Unhandled；entities durable
seq `11..20` 单调；LLM `400/60` 请求与 `460` 响应均为 200；SQLite 最新 execution `ok / 460 / 8432ms`。
UI/REST/SQLite/SSE/wire 一致，rig-down 后进程组归零。正式证据见
`/private/tmp/anselm-rig-ep036-agent-invoke-20260807/sessions/20260807-131105/evidence/EP-036-agent-invoke-final-green.md`，独立复审见
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-036-agent-invoke-ledger-reaudit.md`。

anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 **845→850 judgments**，COVERAGE `EP-036=✓✓✓✓✓`；
两条统计警报经独立复审 ack，阈值未放宽，`alarms.py check` clean，`gen_coverage.py --check` 为
`848 rows / 169 carried judgments / 0 tombstones`。批次十七当前 **5/50**，未到 50 格，不跑统一长门禁、
不提交；下一前线为 `EP-037 POST /api/v1/agents/{id}:revert`。并发外部调用撞在另一本地飞行中的边界
未由本格声称覆盖。

## 历史前线快照（EP-035，批次十六 50/50，统一门禁已通过）

**状态修订。** `DELETE /api/v1/agents/{id}` 已完成真实 Agent 删除路径：More actions → 明确不可逆确认 → DELETE=204；目标从 active catalog 和 rail 消失，选区回到 Overview，关系边清空，版本审计保留，重复删除无第二次副作用。

真实 session `/private/tmp/anselm-rig-ep035-agent-delete-20260807/sessions/20260807-114742` 由 conductor 托管真实 App、Computer Use、窗口录屏、frontend console、backend、三路 SSE witness 和受管网关 tap。删除前 Agent `ag_4e200525b2c3d63a` 有一条 equip 边；最终画面 Agent=46、目标行消失、无 stale detail/blank pane、关系图 0/0。Cancel-only preflight 和错误 tap 归属的失败尝试均保持在独立 session，不冒充绿证据。

逐帧复核保留删除后的标准 `AnCountUp` 首次揭示：右岛约 0.5 秒从 0 到 46，rail 权威徽标已经是 46，最终卡片、REST、SQLite 一致；中间帧和前端 AXTree session review 见正式 session evidence。五通道封口为录屏 `325.161667s / 2784x1808 / 60fps`、backend `411` 行无应用红线、SSE 三流连接且 notifications seq 1 `agent.deleted` 无 gap、frontend `26` 行仅两条已复核标准 AXTree 观测器噪声、LLM tap ready-only（确定性删除不虚构 completion），收台无残留。

正式绿证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-035-agent-delete-final-green.md`；独立账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-035-agent-delete-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入 **EP-035=✓✓✓✓✓**，账本 **840→845 judgments**，集中写账两条统计警报经独立复审 ack 且阈值未放宽，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 168 carried judgments / 0 tombstones`。

批次十六已 **50/50**。统一门禁已通过：根目录 `make verify` 全绿（含 backend 完整 `go test ./...`、frontend、docs、demo），完整 testend `mise exec -- go test -count=1 -timeout 20m ./...` 全绿，`make -C backend testend` 全绿；后端 Agent/实体专项、Flutter 实体专项、gofmt、diff、coverage、alarms 均通过，验收台架进程组归零。工作树审计通过，本批次代码、测试与工作记录一并提交固化；下一原子前线为 `EP-036`。

## 历史前线快照（EP-032，批次十六 30/50）

**状态修订。** EP-032 `GET /api/v1/agents` 已完成真实 Agent 列表路径。首轮真实 App `/private/tmp/anselm-rig-ep032-agent-list-input-20260806/sessions/20260806-162636` 抓到 rail/Overview 首屏显示 40、翻页后变 45 的真实总数缺陷；stop-and-fix 增加不改变 N4 body 的 `X-Anselm-Total-Count`，前端 rail/Overview 消费精确 header，并让 durable lifecycle 总数刷新不落后于 DB。中间 session 因复用受管 key 旁路旧 tap 被 D1/channel-5 门禁拒绿；最终 `/private/tmp/anselm-rig-ep032-agent-list-count-fixed-20260806/sessions/20260806-165306` 由最新 binary、真实 App、Computer Use、录屏、frontend console、backend journal、三路独立 SSE witness、LLM tap 和受管网关重跑通过。

最终真实 UI 首屏 45，真实 alpha 搜索 2，五次 Backspace 恢复 45，滚动三页后仍 45；REST 为 20/20/5、45 唯一项、无 overlap，header total `45/2/1/0`，N4 body 无 `total`；SQLite live count 45。录屏 `72.431667s / 2784x1808 / 60fps`，backend 162 行、frontend 19 行、SSE 8 行、LLM witness 1 行，应用红线扫描干净，收台无残留。

正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-032-agent-list-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-032-agent-list-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 **820→825 judgments**，COVERAGE `EP-032=✓✓✓✓✓`，两条统计警报按独立复审 ack，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 164 carried judgments / 0 tombstones`。批次十六由 **25→30 / 50**，未满 50 格，不运行统一长门禁、不提交，下一原子前线为 `EP-033 GET /api/v1/agents/{id}`。

## 历史前线快照（EP-031，批次十六 25/50）

**状态修订。** EP-031 `POST /api/v1/agents` 已完成真实 Agent 创建路径。首轮真实 App session `/private/tmp/anselm-rig-ep031-agent-create-20260806/sessions/20260806-154305` 发现 hosted model 将 `tags` 发成 JSON 数组字符串，旧执行边界拒绝并显示真实失败卡；中间修复 session `/private/tmp/anselm-rig-ep031-agent-create-fixed-20260806/sessions/20260806-155712` 又发现流式脱敏孤立 `)`，两轮红证据均保留。stop-and-fix 加入窄 tags 兼容、ID-labelled parenthetical 流式保持和回归测试。

固定 session `/private/tmp/anselm-rig-ep031-agent-create-final-20260806/sessions/20260806-160242` 重跑通过：首次 create 返回 `ag_e093c9019b049a4e` v1，最终文案不含 opaque ID、placeholder 或孤立标点；Computer Use 看到 Created agent 卡、完整 prompt/description/tags、Viewed agent 活动和稳定的 Activity 右岛。模型追加一次安全 `get_agent` 读取，无第二次 create；该行为已在正式证据中明示。

正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-031-agent-create-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-031-agent-create-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 **815→820 judgments**，COVERAGE `EP-031=✓✓✓✓✓`，两条统计警报按独立复审 ack，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 163 carried judgments / 0 tombstones`。批次十六由 **20→25 / 50**，未满 50 格，不运行统一长门禁、不提交，下一原子前线为 `EP-032 GET /api/v1/agents`。

## 历史前线快照（EP-030，批次十六 20/50）

EP-030 的 Handler Logs 单调用详情红绿证据、五级账本与独立复审仍保留在 README §5.2 和正式 evidence 中；以上 EP-031 状态为当前恢复真相。

## 历史前线快照（EP-029，批次十六 15/50）

EP-029 的 `data.calls=null` 红证据、`response.Paged` 修复、最终五通道 session、五级账本和独立复审均保留在 README §5.2 与正式证据中；以上 EP-030 状态为当前恢复真相。

## 历史前线快照（EP-028，批次十六 10/50）

EP-028 的重复 `handler.config_cleared` 红证据、changed 保护修复、最终五通道 session 和 `800→805` 五级账本均保留在 README §5.2 与正式证据中；以上 EP-029 状态为当前恢复真相。

## 历史前线快照（EP-027，批次十六 5/50）

**状态修订。** EP-027 `PUT /api/v1/handlers/{id}/config` 已完成真实 JSON Merge Patch、实例重启、敏感键保留、可选键删除/默认值回落，以及真实 Chat `update_handler_config` 产品路径。固定 session `/private/tmp/anselm-rig-ep027-handler-config-20260806/sessions/20260806-142114` 由 conductor 托管真实 App、Computer Use、录屏、frontend console、backend journal、三路独立 SSE witness、LLM tap 和受管网关；录屏 `583.983333s / 2784x1808`，backend `598` 行，无应用 panic/fatal/WARN/ERROR；messages/entities/notifications durable 序列为 `1..66`、`7..8`、`16..30` 且单调，frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线，LLM 严格回合只出现 `update_handler_config`。REST 与 SQLite 证明 `prefix=delta`、`prefix=null` 回落 `default-prefix` 且 `secret_seen=true`，GET 始终只显示 `api_key=********`；App 画面显示 schema、配置活动和最终结果，无 secret 泄漏、裁切、重叠或视觉跳变。

正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-027-handler-config-update-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-027-handler-config-update-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入五级裁决，账本 **795→800 judgments**，COVERAGE `EP-027=✓✓✓✓✓`，alarms clean。早期 `...dball` 是台架 URL 构造错误，探索性 Chat 的额外 `state()` 也已由严格重跑隔离；两者均保留在证据而未冒充绿路径。`gen_coverage.py --check` 应为 `848 rows / 159 carried judgments / 0 tombstones`。批次十六由 **0→5 / 50**，未满 50 格不运行统一长门禁、不提交；下一原子前线为 `EP-028 DELETE /api/v1/handlers/{id}/config`。

## 历史前线快照（EP-026，批次十五 50/50）

**状态修订。** EP-026 `GET /api/v1/handlers/{id}/config` 已完成真实配置、未配置、敏感值掩码和未知 Handler 边界。固定 session `/private/tmp/anselm-rig-ep026-handler-config-20260806/sessions/20260806-134441` 由 conductor 托管真实 App、Computer Use、录屏、frontend console、backend journal、三路 SSE witness、LLM tap 和受管网关；配置 Handler 返回 `200`/`ready`/`api_key=********`，未配置 Handler 返回 `200`/`unconfigured`/`missingConfig=[api_key]`，未知 ID 返回 `404 HANDLER_NOT_FOUND`。App 画面显示 configured 与 unconfigured 的真实状态和 schema，无 secret 泄漏、裁切、重叠或跳变。首次 PUT 探针的 `405` 是测试命令遗漏显式 `-X PUT` 的台架错误，补正后产品 PUT 为 `204`，不计产品红。

录屏 `245.513333s / 2784x1808`；backend 无应用 WARN/ERROR/panic，三路 SSE durable seq 单调，frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线，受管网关 challenge/install/models 全 `200`；REST/SQLite/UI/SSE/secret scan 交叉一致，收台无残留。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-026-handler-config-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-026-handler-config-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入五级裁决，账本 **790→795 judgments**，COVERAGE `EP-026=✓✓✓✓✓`，alarms clean，gen coverage 为 `848 rows / 158 carried judgments / 0 tombstones`。批次十五由 45→50，统一长门禁已通过：根目录 `make verify`、`make -C backend testend`（305.314s）、`testend` 全包（359.770s）、Handler 后端专项、实体详情 Flutter `7/7`、gofmt/diff 均通过，testend 进程组归零；批次已提交 `6ffc44bb`。下一原子前线为 EP-027。

## 历史前线快照（EP-025，批次十五 45/50）

**状态修订。** EP-025 `GET /api/v1/handlers/{id}/versions/{version}` 首轮真实路径发现跨父 opaque version ID 泄漏：A 读取 B 的 `hdv_...` 返回 B 的版本。stop-and-fix 增加 parent-scoped repository lookup，使数字版本与 opaque 版本详情都受 URL 中父 Handler 约束，并补 store/app/transport/black-box 回归与 Handler domain 文档。固定 session `/private/tmp/anselm-rig-ep025-handler-version-get-fixed-20260806/sessions/20260806-133348` 用新 binary 真实重跑：A 自有数字/opaque 200，A 读取 B opaque、未知数字和未知 opaque 均为 404 `HANDLER_VERSION_NOT_FOUND`，B 自有 opaque 仍 200；Computer Use 画面显示正确 owner 的 v1/stopped/ready/active/source/change reason 和完整代码，无错归属或视觉跳变。红 session `/private/tmp/anselm-rig-ep025-handler-version-get-20260806/sessions/20260806-132936` 保留；固定录屏 186.876667s/30MB，backend 无 WARN/ERROR/panic，三路 SSE durable seq 单调，frontend 无应用级 Flutter/Dart/RenderFlex/Unhandled 红线，受管网关 bootstrap 全 200。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-025-handler-version-final-green.md`，账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-025-handler-version-ledger-reaudit.md`；五级 `G1/F2/A1/C4/G2` 使账本 785→790 judgments，anchors 10/10，统计警报按原阈值独立复审并 ack，alarms.py check clean，gen_coverage.py --check 为 848 rows / 157 carried judgments / 0 tombstones。批次十五由 40→45 / 50，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-026。

## 历史前线快照（EP-024，批次十五 40/50）

EP-024 `GET /api/v1/handlers/{id}/versions` 的 22 版本分页、续页、active/diff/earliest 展开和滚动检查已完成，真实录屏、三路 SSE、backend/frontend、受管网关和 SQLite 证据均已封存；正式账本 780→785，COVERAGE EP-024=✓✓✓✓✓，批次十五由 35→40。以上仅作追溯，当前以前一段 EP-025 状态修订为准。

## 历史前线快照（EP-023，批次十五 35/50）

以下段落仅保留 EP-023 的当时状态，当前恢复以前一段 EP-024 状态修订、README §5.2、LOG 最新条目和 COVERAGE 当前行作为真相。

**状态修订。** EP-023 POST /api/v1/handlers/{id}:iterate 已在真实 App、受管 Anselm 网关、Computer Use 和五通道台架下完成 Handler actions → Edit with AI → ask-user → AI edit → v2 完整产品旅程。首轮真实路径暴露 legacy set_methods 被归一为既有 status 的 add_method，后端真实拒绝 method "status" already exists；红 session 与错误卡永久保留。stop-and-fix 使 edit normalization 读取 active method 名称，既有方法用 update_method、新方法才用 add_method，并补单测与 tool description。固定 session /private/tmp/anselm-rig-ep023-handler-iterate-fixed-20260806/sessions/20260806-130116 由 conductor 托管真实 App、窗口录制、frontend console、backend journal、三路 SSE witness 和 LLM tap；最终只发一个 canonical update_method，App 显示 v2、最终说明和 Activity 1 touched，REST/SQLite active 指针为 v2，消息块保留完整工具链。录屏 400.173333s，三路 durable frame 单调且 close 快照与数据库一致，受管网关 challenge/install/models 与 chat completions 全 200，固定路径无应用级 WARN/ERROR/panic 或 Flutter/Dart/RenderFlex/Unhandled 红线；macOS runner/IMK host 噪声已独立隔离。正式证据 /private/tmp/anselm-rig-formal-20260801-3/evidence/EP-023-handler-iterate-final-green.md，账本复审 /private/tmp/anselm-rig-formal-20260801-3/evidence/EP-023-handler-iterate-ledger-reaudit.md；五级 G1/F2/A1/C4/G2 使账本 775→780 judgments，anchors 10/10，两个原阈值警报独立复审并 ack，alarms.py check clean，gen_coverage.py --check 为 848 rows / 155 carried judgments / 0 tombstones。批次十五由 30→35 / 50，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-024。

## 历史前线快照（EP-022，批次十五 30/50）

以下段落仅保留 EP-022 的当时状态，当前恢复以前一段 EP-023 状态修订、LOG 最新条目和 COVERAGE 当前行作为真相。

**状态修订。** EP-022 `POST /api/v1/handlers/{id}:edit` 已在真实 App、受管 Anselm 网关、Computer Use 和五通道台架下完成成功与非法 method 编辑路径。`hd_f3d9a96f278672d0` 从 v1 `hdv_98ffb76322048024` 开始，真实 App 首次 Call 后显示 `v1 · running`；真实 HTTP `:edit` 用 canonical `update_method` 铸造 v2 `hdv_6ff081d3ae49ebf6`，环境 ready 并重启 resident。App 同步显示 `v2 · running`/`ready`/新代码，旧 v1 结果被清掉而 Recent 保留；随后真实 Call 返回 `{"edited":true,"revision":"v2"}`，Recent 为 2。非法 `does_not_exist` 返回 `422 HANDLER_OP_INVALID` 与具体缺失原因，版本仍只有 v1/v2、active v2、无 v3/副作用。最终 session `/private/tmp/anselm-rig-ep022-handler-edit-20260806/sessions/20260806-123828` 录屏 `191.498333s / 2784x1808 / 60fps`；REST/SQLite 证明两次调用钉住不同 resident instance，三路 SSE 全连接且 durable seq 无 gap，网关 challenge/install/models 全 200，backend/frontend 无未解释应用红线，收台无残留。Flutter 启动器的单条 foreground warning 已在证据中隔离为仪器噪声，未知错误仍 fail-closed。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-022-handler-edit-final-green.md`，账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-022-handler-edit-ledger-reaudit.md`；五级 `G1/F2/A1/C4/G2` 使账本 **770→775 judgments**，anchors `10/10`，两条警报按原阈值独立复审并 ack，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 154 carried judgments / 0 tombstones`。批次十五由 **25→30 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-023`。

**历史快照（EP-021）。** EP-021 `POST /api/v1/handlers/{id}:revert` 的首轮真实路径暴露 v1 标题下残留 v2 结果的产品真相红线；stop-and-fix 后 active version 变化会清掉瞬时结果并保留 durable Recent。最终真实 session 显示 v1 running/ready、旧结果消失，随后 v1 Call 成功；REST/SQLite、SSE、录屏、五通道和 controller `10/10` 已交叉证明，账本为 770，警报 clean。该段仅供追溯，当前恢复以前述 EP-022 状态为准。

以下 EP-020 及更早状态段仅保留作历史快照，恢复执行以上述状态修订、README §5.2、LOG 最新条目和 COVERAGE 当前行作为真相。

**历史快照（EP-020）。** EP-020 `POST /api/v1/handlers/{id}:restart` 已在最终新构建真实 App、受管 Anselm 网关、Computer Use 和五通道台架下完成成功/失败路径。首轮真实 Call 成功后发现 UI 仍显示 `v1 · stopped`，而 REST/SQLite 已是 `runtimeState=running`；stop-and-fix 在 Handler call 收尾后重新读取 server-owned detail。最终 session `/private/tmp/anselm-rig-ep020-handler-restart-fixed-20260806/sessions/20260806-120431` 显示首次 Call 后 `v1 · running`、`ready`、`Done`，Restart 原地完成且不升版本，第二次 Call 的 Recent 为 2；REST/SQLite 为同一 active version `hdv_b075d14eefb8e00f`、两个真实 resident instance `hdi_51fd8207eeaa0161`/`hdi_da984cee7bc1fdf`、两次成功调用。未配置必填 `token` 的负 Handler 真实 Restart 显示 `restart failed · View`，后端为 `422 HANDLER_CONFIG_INCOMPLETE`，无假实例/假调用。录屏 `200.308333s / 2784x1808 / 60fps`；SSE 成功 durable seq `16`、失败 seq `20..22`，无 gap；backend/frontend/LLM tap 均由同一 manifest 归属，网关 challenge/install/models 全 200，AXTree bridge churn 已作工具噪声复核，应用红线扫描干净，收台无残留。正式证据 `EP-020-handler-restart-green.md`，独立账本复审 `EP-020-handler-restart-ledger-reaudit.md`；定向 controller `9/9` 与目标 analyze 通过，账本 **760→765 judgments**，anchors `10/10`，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 152 carried judgments / 0 tombstones`。批次十五由 **15→20 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-021`。

以下 EP-019 及更早状态段仅保留作历史快照，恢复执行以上述状态修订、README §5.2、LOG 最新条目和 COVERAGE 当前行作为真相。

**历史快照（EP-019）。** EP-019 已在最终新构建真实 App、受管网关、Computer Use 和五通道台架下完成 Handler `:call` 成功/失败路径。首轮失败先暴露结构化错误 details 被 UI 丢弃，第二轮又暴露 traceback 被 JSON 转义；修复后最终画面显示 `Done`/stdout/结构化结果，失败画面显示 `Failed`/错误码/用户 stdout，并按真实换行显示 `error` 与 Python traceback。最终 session `/private/tmp/anselm-rig-ep019-handler-call-final-20260806/sessions/20260806-114857` 的录屏为 `176.410000s / 2784x1808 / 60fps`；REST/SQLite 为同一 resident、v1、`1 ok/1 failed` 审计，SSE entities open/delta/close 与 backend 200/502 对齐，LLM challenge/install/models 全 200，frontend/backend 无未解释红线，收台无残留进程。正式证据 `EP-019-green.md`，独立警报复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-019-handler-call-ledger-reaudit.md`；账本 **755→760 judgments**，anchors `10/10`，警报按原阈值复审 ack 后 clean。批次十五由 **10→15 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-020 POST /api/v1/handlers/{id}:restart`。

**状态修订。** EP-018 已在真实 App、受管网关、Computer Use 和五通道台架下完成：取消确认不改变 Handler，确认后 `order_desk` 从活动目录消失、详情回 Overview、计数 `1→0`；HTTP `204→GET 404`，重复 DELETE 为 `HANDLER_NOT_FOUND`，版本历史保留，SQLite `deleted_at` 落真，sandbox env 与关系边清理。录屏 `246.323333s / 2784x1808 / 60fps`，notifications durable `16,17` 连续为 `sandbox.env_deleted`→`handler.deleted`，frontend/backend 无未解释红线；正式证据为 `EP-018-green.md`，警报复审为 `EP-018-ledger-reaudit.md`，正式账本 **750→755 judgments**，anchors `10/10`，`alarms.py check` clean。批次十五当前 **10 / 50**，下一原子前线为 `EP-019 POST /api/v1/handlers/{id}:call`。下方原 EP-017 状态段仅保留作过程快照。

**状态修订。** EP-017 后续发现 description/tags 保存失败误用“名称保存失败”文案，已补齐 `metaSaveFailed` 双语文案并同步 Function/Workflow 同类异常路径。新 binary 的真实 session `/private/tmp/anselm-rig-ep017-handler-patch-20260806/sessions/20260806-111449` 已从空 meta 完成 Computer Use 编辑，最终值为 `rechecked metadata`/`recheck-tag`，录屏 `159.730000s / 2784x1808 / 60fps`，notifications durable `1..3` 无 gap，SQLite 保持单一 v1，resident `bump` 成功，frontend/backend 无未解释应用红线。最终证据为 `EP-017-recheck-green.md`，复审为 `EP-017-recheck-ledger-reaudit.md`；正式账本 **745→750 judgments**，anchors `10/10`，`alarms.py check` clean。批次十五仍为 **5 / 50**，下一原子前线为 `EP-018 DELETE /api/v1/handlers/{id}`。下方原 `当前更新` 长段中的 `745` 与旧 EP-017 证据仅保留作过程快照。

**当前更新。** 第九批 `TOOL-081..090`、第十批 `TOOL-091..100`、第十一批 `TOOL-101..110` 和第十二批 `TOOL-111..120` 均已完成 50/50，并分别提交 `32b33499`、`553fa150`、`de146b72`、`91cdd51c`。`TOOL-121 generate_video`、`TOOL-122 edit_image`、`TOOL-123 animate_image`、`TOOL-124 enroll_voice`、`EP-001 POST /api/v1/functions`、`EP-002 GET /api/v1/functions`、`EP-003 GET /api/v1/functions/{id}`、`EP-004 PATCH /api/v1/functions/{id}`、`EP-005 DELETE /api/v1/functions/{id}`、`EP-006 POST /api/v1/functions/{id}:run`、`EP-007 POST /api/v1/functions/{id}:revert`、`EP-008 POST /api/v1/functions/{id}:edit`、`EP-009 POST /api/v1/functions/{id}:iterate`、`EP-010 GET /api/v1/functions/{id}/versions`、`EP-011 GET /api/v1/functions/{id}/versions/{version}`、`EP-012 GET /api/v1/functions/{id}/executions`、`EP-013 GET /api/v1/function-executions/{id}`、`EP-014 POST /api/v1/handlers`、`EP-015 GET /api/v1/handlers`、`EP-016 GET /api/v1/handlers/{id}` 与 `EP-017 PATCH /api/v1/handlers/{id}` 均已完成五级裁决，正式账本为 **745 judgments**，anchors `10/10`；EP-017 的红绿证据已按原阈值独立复审并 ack，`alarms.py check` clean。批次十三和批次十四均已完成 **50 / 50** 并通过统一长门禁、完整 testend、警报复核和工作树审计；批次十五当前 **5 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-018 DELETE /api/v1/handlers/{id}`。

EP-016 的真实 session `/private/tmp/anselm-rig-ep016-handler-get-20260806/sessions/20260806-100548` 验证了 Handler 详情的完整用户目的：Computer Use 画面显示名称、v1、stopped、unconfigured、activeVersion、Python 3.12、必填 sensitive `api_key`、默认 `region`、`ping` 方法和 source；REST/SQLite 证明 configState、runtimeState、missingConfig、schema 与未知 ID 404 一致。封口录像 `292.240000s / 2784x1808 / 60fps`，三路 SSE、backend journal、frontend console、LLM tap 均由同一 manifest 归属，durable entities `7..8`、notifications `16..20` 无 gap；DELETE=204 后 GET=404，env 已回收。正式证据 `EP-016-green.md`，警报复审 `EP-016-alarm-reaudit.md`；账本 **735→740 judgments**，批次十四 **45→50 / 50**。

EP-017 的首轮真实画面冻结为红：Handler Overview 没有可编辑 description，也没有 tags 入口。stop-and-fix 后真实 Computer Use 从空 meta 输入 description 与 tag，Enter 提交、Escape 收束，最终画面显示 canonical meta、`v1 · running`、`ready`；PATCH 不升版本、不重启 resident。REST/SQLite、`handler.updated` SSE durable `1..4`、backend/frontend journal、LLM tap 与 559.990000s 封口录像交叉一致，非法名称 400 和未知 Handler 404 也已验证。正式证据 `EP-017-green.md`，账本 **740→745 judgments**，复审 `EP-017-ledger-reaudit.md`，anchors `10/10`、`alarms.py check clean`；批次十五 **0→5 / 50**，未满批不跑统一长门禁、不提交；下一原子前线为 `EP-018 DELETE /api/v1/handlers/{id}`。

EP-012 的红 session `/private/tmp/anselm-rig-ep012-functions-20260806/sessions/20260806-075245` 暴露 Overview 以最近 5 条推导总数为 `5 today`、Logs 使用 UTC 直出的问题；fixed session `/private/tmp/anselm-rig-ep012-functions-20260806-fixed/sessions/20260806-080821` 通过 `totalCount` 聚合和 `DateTime.toLocal()` 修复后真实显示 22 total、18 Done/4 Failed、本地时间，并完成失败展开与 Load more 22 行。五通道封口、SQLite 22 条执行审计、DELETE=204→GET=404 和证据文件均已保存；单条 logs 的详情懒加载已由 EP-013 完成，不把列表聚合误称为详情交付。

EP-013 的真实 session `/private/tmp/anselm-rig-ep013-functions-20260806/sessions/20260806-082436` 验证了轻列表到完整详情的用户路径：2 条真实执行（1 ok/1 failed），单详情 REST 对成功与失败均返回完整 input/output/error/logs/timing，未知 ID 为 404；Computer Use 在 Logs 面板展开失败行看到 traceback 与 logs，成功行的 accessibility state 也含完整日志。录屏 `346.728333s / 2784x1808` 可读，SSE 三流记录 run/error/delete，LLM proof/install/models 全 200，backend/frontend 无应用红线；DELETE=204 清理后 SQLite 为 `live_functions=0/deleted_functions=2/execution_rows=2`。正式证据 `EP-013-green.md`，复审 `EP-013-ledger-alarm-reaudit.md`；正式账本 **720→725 judgments**，批次十四 **30→35 / 50**，下一原子前线为 `EP-014 POST /api/v1/handlers`。

EP-014 的真实 session `/private/tmp/anselm-rig-ep014-handlers-20260806-compat9/sessions/20260806-093450` 在 stop-and-fix 后完成 Handler 创建：legacy op 形状先由后端有限翻译到 canonical `add_method`，compat8 又发现脱敏 ID 行留下空行导致 Flutter 表格隐藏 `ping` 方法，随后改为物理移除不可用行并补流式/durable 回归，compat9 画面才稳定显示名称、Python 3.12、`ping` 返回 `{pong: true}`、v1 与“未调用该方法”说明。REST 为 `201/400/200`，SQLite 保留版本/env/调用审计，清理为 `DELETE=204 → GET=404`；录屏 `189.793333s` 可读，三流 durable seq 单调无 gap，llmtap 全 200，backend/frontend 无未解释红线。正式证据 `EP-014-green.md`，复审 `EP-014-alarm-reaudit.md`；账本 **725→730 judgments**，批次十四 **35→40 / 50**，下一原子前线为 `EP-015 GET /api/v1/handlers`。

EP-015 的主 session `/private/tmp/anselm-rig-ep015-handlers-20260806/sessions/20260806-094604` 用 44 个真实 Handler 加 seed 行走通了实体 rail 的 `20+20+5` 续页与 45 行边界；真实输入 `ep015-handler-3` 返回 10 条 `39→30`，独立空输入 session `/private/tmp/anselm-rig-ep015-handlers-20260806/sessions/20260806-095453` 显示精确 `No entities match your search.`。REST 交叉核验 cursor/search/empty/`limit=0` 400，清理 44 行 `DELETE=204`、GET=404，SQLite 保留 44 个版本并回收临时 env。录屏均由 conductor 封口且 ffprobe 可读，主 SSE durable entities `7..94`、notifications `16..147` 无 gap，三流均连接，llmtap bootstrap 全 200，backend/frontend 无未解释红线；Computer Use `set_value` 隐藏值串接单列为仪器限制。正式证据 `EP-015-green.md`，空态补证 `EP-015-empty-search.md`，复审 `EP-015-alarm-reaudit.md`；账本 **730→735 judgments**，批次十四 **40→45 / 50**，下一原子前线为 `EP-016 GET /api/v1/handlers/{id}`。

`EP-011` 首轮真实 App 发现 A 读取 B opaque version ID 的跨父泄漏，且代码审查发现显式版本执行同样缺 parent scope；fixed session 通过 parent-scoped repository lookup、真实 Versions 页面、A/B REST 正负边界、显式 A run、SQLite 软删审计和五通道收台完成复验。UI 的 v2 active、真实 change reason、`+1 −1` diff、v1 earliest/full code 均无截断、错归属或跳变；A/B own ID 与数字版本为 200，cross-parent/unknown 为 404，DELETE=204 后 GET=404，录屏 `284.375s / 2784x1808 / 60fps`，SSE durable entities `1..6`、notifications `1..14` 单调，llmtap bootstrap 三个真实 HTTP 200。正式证据 `EP-011-green.md`，警报复审 `EP-011-ledger-alarm-reaudit.md`；账本 **710→715 judgments**，下一原子前线为 `EP-012`。

`EP-007 POST /api/v1/functions/{id}:revert` 的真实 App session `/private/tmp/anselm-rig-ep007-functions-20260806/sessions/20260806-060152` 完成 Versions 面板中的 v2→v1 `Set active` 回退：UI 保留 v1/v2 历史且 active、运行结果均切到 v1；REST 参数执行、非法 v99、SQLite active/version/execution/notification、`function.reverted` SSE durable 帧与 backend journal 对齐。清理 session 真实 DELETE=204、GET=404、live list 为空，soft-delete 与 `function.deleted` 也对齐。三路 SSE、frontend console、LLM tap 与屏幕录像由同一 manifest 归属；Computer Use 参数编辑器绕过回调的输入现象未作为产品绿证据。正式证据与警报复审分别为 `EP-007-function-revert.md`、`EP-007-ledger-alarm-reaudit.md`。

`EP-008 POST /api/v1/functions/{id}:edit` 的 fixed3 session `/private/tmp/anselm-rig-ep008-functions-20260806-fixed3/sessions/20260806-064400` 真实完成 v1→v2 单次编辑，UI/REST/SQLite/SSE/LLM/frontend/backend 五通道一致；最终录屏 174.058333s，三流 durable seq 为 messages `1..42`、entities `1..8`、notifications `1..9`，LLM 20/20 HTTP 200，无错误卡或 opaque placeholder。首轮 Version ID 占位泄漏和 fixed2 畸形 ops 500 均保留为红证据；修复跨 chunk 脱敏与 `ParseOps` 结构化 `422 FUNCTION_OP_INVALID` 后重跑。空 ops 只重建 env、不铸 v3；Function/conversation 已真实清理。正式证据与警报复审分别为 `EP-008-green.md`、`EP-008-ledger-alarm-reaudit.md`；下一原子前线为 `EP-009`。

`EP-009 POST /api/v1/functions/{id}:iterate` 的 fixed3 session `/private/tmp/anselm-rig-ep009-functions-20260806-fixed3/sessions/20260806-070454` 完成真实 Function 的 `Edit with AI` 用户路径。首轮 generic opening/title 红证据保留；stop-and-fix 后固定请求带实体名称，chat rail/header 可识别，助手读取同一 Function 并进入可继续编辑的 composer。空/空白请求、未知 Function、malformed JSON 均在创建 conversation 前拒绝；REST/SQLite、mention/touchpoint、三路 SSE、backend/frontend、LLM wire 和录屏交叉一致。录屏 `408.985000s / 2784x1808 / 60fps`，messages/entities/notifications durable seq `1..18`、`1..2`、`1..8` 单调，LLM 12 个响应全 200，清理 DELETE=204→GET=404。精确已知 AXTree tooling noise 由 session-scoped `frontend-ax-review.md` 解释，`rig-check.sh` 对未知 AX/Dart/Flutter/runtime 错误仍硬失败。正式证据与警报复审分别为 `EP-009-green.md`、`EP-009-ledger-alarm-reaudit.md`；五级裁决使中央账本 **700→705 judgments**，COVERAGE `EP-009=✓✓✓✓✓`，批次十四 **10→15 / 50**，下一原子前线为 `EP-010 GET /api/v1/functions/{id}/versions`。

`EP-010 GET /api/v1/functions/{id}/versions` 在 session `/private/tmp/anselm-rig-ep010-functions-20260806/sessions/20260806-072203` 真实构造 v1→v21 并走完 Versions 页面：首屏 20 条、cursor 续页 v1、active v21、真实 change reason/code diff、v1 earliest 展开；REST/SQLite/SSE/UI 真值一致。`limit=0/abc` 与坏 cursor 的负边界分别返回 `INVALID_REQUEST`/`MALFORMED_CURSOR`；删除后主实体 404、live list 移除，版本历史按审计约定保留。封口录像 `456.258333s / 2784x1808 / 60fps`，三流均连接，entities durable `1..42`、notifications durable `1..85` 单调，delta seq=0，backend/frontend 无未解释红线，llmtap bootstrap 真实 HTTP 200。正式证据 `EP-010-green.md`，警报复审 `EP-010-ledger-alarm-reaudit.md`；五级裁决使中央账本 **705→710 judgments**，批次十四 **15→20 / 50**，下一原子前线为 `EP-011 GET /api/v1/functions/{id}/versions/{version}`。

EP-005 的红线、修复和证据在 `README.md` §5.2 与 formal evidence 中已完整记录：真实实体 rail 删除路径先冻结旧确认文案，再修复为明确不可撤销后重跑；后端 `204`、REST `404`/列表缺席、SQLite soft-delete/version/env/relation 真相、notifications seq `1..2` 与 UI 终态一致。前端只保留两条静态、5 秒不增长的已知 AXTree 观察器噪声；默认账本错路由与正式账本重放均有独立审计。

`EP-006 POST /api/v1/functions/{id}:run` 的最终 session `/private/tmp/anselm-rig-ep006-functions-20260806/sessions/20260806-053154` 已封口 528.990000s。正向 Example → Run 两次成功，UI/REST/SQLite/backend 对齐；负向真实输入 `A` 显示 JSON 校验错误并禁用 Run，点击不产生执行。三路 SSE 在动作前均已连接；ready env 的同步 Function run 按实现不发布实体/消息帧，零帧是预期，未见断连或异常帧。前端仅静态 IMK 系统噪声，LLM tap 仅 ready；临时 fixture 由真实 DELETE=204、GET=404、列表为空清理。正式证据为 `/private/tmp/anselm-rig-ep006-functions-20260806/sessions/20260806-053154/evidence/EP-006-real-app.md`，账本复审为 `EP-006-ledger-alarm-reaudit.md`；该格已随批次十三收口。

API Serve 修复提交 `0d06f6e58615fec2fd04e3c15d16aea2edaf4aef` 已成功通过 CI `31029509745` 与 production deploy `31029785594`，公网 healthz 为 `200`，设备证明边界按契约返回 `401`。真实受管 `/models` 明示 I2V 后才进入 App 轮次；部署成功不替代产品验收。

`EP-002 GET /api/v1/functions` 的最终五通道 session 为 `/private/tmp/anselm-rig-ep002-functions-20260806/sessions/20260806-034541`：真实 App 中用 45 个真实 Function fixture 验证 `20+20+5` 分页、cursor continuation、filtered search、非法/上限 limit 和实体 rail 的 20→40→45 加载；no-match 空白 rail 已 stop-and-fix 为本地化解释。`EP-003 GET /api/v1/functions/{id}` 随后在 session `/private/tmp/anselm-rig-ep003-functions-20260806/sessions/20260806-035647` 完成真实实体详情、active version、代码/接口/环境元数据和 `FUNCTION_NOT_FOUND` 负路径；录屏 `163.976667s`，backend/frontend 无未解释应用红线，三路 SSE durable seq 单调，LLM completed responses 全 HTTP 200。EP-003 正式证据为 `ep-003-function-get-green.md`，账本复审为 `ep-003-ledger-reaudit.md`。下方旧 EP-001 及更早段落均为历史快照，恢复只以上述当前前线、`LOG.md` 和 COVERAGE 为准。

`TOOL-123` 的真实 App session `/private/tmp/anselm-rig-tool123-live-20260806/sessions/20260806-020305` 完成静态图→危险批准→I2V提交/轮询/媒体上传→5秒MP4→播放结束→重播→全屏→退出全屏；首帧 `changedFrac=0.1009`，源图构图保持。647.886667s 屏幕录像、backend、三路 SSE、frontend console、LLM tap 和 `measure compare` 证据齐全，正式证据为 `sessions/20260806-020305/evidence/tool-123-animate-image-formal-20260806.md`。

上一 session `/private/tmp/anselm-rig-tool123-live-20260806/sessions/20260806-015946` 的 AXTree 红证据仍保留；修复后二进制的 loading/error/retry 反馈由 34 项媒体定向测试和 `flutter analyze` 锁定。五级写账后的 `gap-too-fast` 与 `discovery-collapse` 通过独立复审文件 ack，阈值未放宽。一次未 export `RIG_HOME` 的 L1 误写到默认旧账本已留审计并重放到正式根；正式账本才是本战役水位。

`TOOL-124 enroll_voice` 的真实 App session `/private/tmp/anselm-rig-tool124-live-20260806/sessions/20260806-022721` 完成短参考音频生成、有限库存解释、危险登记人闸批准、网关登记、登记音色复用生成、Settings 库存核对和真实删除清理；参考音频 `att_353b3737368b9dbf` 为 157484 bytes/3.280000s，复用音频 `att_e06c667a3db58ac3` 为 169004 bytes/3.520000s，网关句柄与本地音色行 ID 的创建/使用/删除边界一致。587.738333s 录屏、backend/frontend journal、三路 SSE witness、LLM tap、SQLite/REST 证据齐全；messages durable `1..52`、notifications `1..2` 单调，实体流已连接，frontend/backend 无未解释 runtime 红线。英文主路径完成；Computer Use 中文输入丢失被记录为仪器限制，不计产品红线。

TOOL-124 首轮冻结了 Settings 将音色 GET 失败伪装成空库存的问题；修复为明确错误状态与 Retry，补双语文案、fixture failure hook、`voices_card_test.dart` 6/6 和 settings 文档规则。正式五级 `G1/F2/A5/C4/G2` 已写账，中央账本 **655 judgments**，anchors `10/10`，两项统计警报经独立复审后 clean。

`EP-001` 的真实 App 前置红会话发现三条问题：外层 `ops` JSON 字符串化、嵌套 I/O schema 形状不兼容、成功正文把 ID 渲染成 `the requested item`。红证据均保留；修复后正式 session `/private/tmp/anselm-rig-ep001-green3-20260806/sessions/20260806-030648` 只执行一次创建，规范化参数落入 SQLite/SSE，函数 v1 与环境 `ready` 一致，展开工具卡可复制精确 ID，正文无坏占位。五通道录屏 `337.441667s`，三流 durable seq 单调，LLM/HTTP 全 200，frontend/backend 无未解释应用红线，证据与警报复审分别为 `evidence/ep-001-formal-green-provider-shapes.md`、`evidence/ep-001-ledger-alarm-reaudit.md`。正式账本 **655→660**，批次十三 **20→25 / 50**，下一原子前线为 `EP-002 GET /api/v1/functions`。

代码审查随后发现通用 provider 参数归一化的 `argumentRepair` 错误借用了 `get_flowrun` 原因，且 `edit_function` 的畸形 `ops` 只在执行阶段失败；两项均已 stop-and-fix 并补回归。最终代码重跑 session `/private/tmp/anselm-rig-ep001-auditfix-20260806/sessions/20260806-032244` 的真实 provider wire 仍为外层字符串 `ops`，但 durable/SSE 已规范化为四项 native ops，attrs 为 `provider arguments normalized by tool boundary`；函数 v1/env `ready`，真实 `100 °C → 212 °F`，screen.mov `200.358333s` 可读，messages/entities/notifications durable seq 分别 `1..26`、`1..2`、`1..5` 单调，LLM 全 200，backend/frontend 无未解释应用红线。最终证据为 `evidence/ep-001-audit-fix-green.md`，警报复审为 `evidence/ep-001-auditfix-ledger-reaudit.md`；五级重验证使账本 **660→665**，覆盖批次仍 **25 / 50**，下一前线不变。

`TOOL-113` 的首轮正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-220707` 保留了真实 SSE 中间帧的 `lastMessageAt → the recorded time` 红线；修复后 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-221418` 已由新 binary、真实 App、受管 gateway、Computer Use 和五通道台架复验。三次 cursor 调用取回三页，目标 text delta/close、UI、REST/tool result 和五通道一致；录屏 `162.765s / 2784x1808 / 60fps`，frontend/backend 无未解释红线，LLM wire 全 200。正式证据 `evidence/TOOL-113.md`，警报复审 `evidence/tool-113-ledger-alarm-reaudit.md`，anchors 10/10，最终 `alarms.py check` 为 `clean (600 judgments)`。

`TOOL-114` 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-222259` 完成当前对话 rename/pin/unpin/archive/自动解档/显式解档以及空标题拒绝；六个 tool-call/result 对与 notifications 状态顺序逐帧一致，空标题没有 retry 或 mutation。录屏 `411.743333s / 2784x1808 / 60fps`，messages `1..96`、notifications `1..6` 单调，三路 SSE 连接，frontend 无 runtime 红线，backend 只有预期 validation WARN，LLM chat response 全 200。正式证据 `evidence/TOOL-114.md`，警报复审 `evidence/tool-114-ledger-alarm-reaudit.md`，anchors 10/10，最终 `alarms.py check` 为 `clean (605 judgments)`。

`TOOL-115` 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-232754` 完成全量 kind 检索、handler 筛选、无匹配和空 query 四条真实 App 路径；一次调用约束、精确 ref 卡片、自然语言脱敏、字符串化 hosted 参数兼容、明确 validation failure 和无 mutation 均由 SQLite/SSE/UI/LLM/backend/frontend 五通道交叉核对。首轮泄漏和参数形状红证据保留，修复后二次 session 才判绿；录屏 `217.091667s / 2784x1808`，messages `1..42`、notifications `1..6` 单调，frontend 无运行时红线，backend 只有预期空 query WARN，LLM responses 全 200。正式证据 `evidence/TOOL-115.md`，警报复审 `evidence/tool-115-ledger-alarm-reaudit.md`，anchors 10/10，五级 `G1/F2/A5/C4/G2` 已落账，最终 `alarms.py check` 为 `clean (610 judgments)`。

`TOOL-116` 首轮 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-014547` 冻结了真实端点展示泄露 `(fromId: deploy-helper)` 与中间 SSE 裸占位符；stop-and-fix 让关系表识别起点/终点列，并在 delta/close 统一去除机器字段，精确 ref 仅留工具卡与审计面。修复后二次 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-015059` 真实 App 只调用一次 `get_relations`，终帧显示 `技能 deploy-helper → 函数 greet`；assistant-only SSE 禁词扫描为空，五通道与 `rig-check`/`rig-down` 通过，证据 `evidence/TOOL-116.md`，警报复审 `tool-116-ledger-alarm-reaudit.md`，anchors 10/10，最终 `alarms.py check` 为 `clean (615 judgments)`。

`TOOL-117` 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-020051` 完成 local 正向摘要、local JS shell 降级、loopback 安全拒绝和 Chat 设置切换 Jina 后的动态页面摘要；UI、SQLite、SSE、LLM wire、backend/frontend journal 与 336.700000s 录屏一致。messages durable `1..62`、notifications `1..2` 单调，LLM 28 个 HTTP response 全 200，五通道收台与 anchors 10/10 通过；证据 `evidence/TOOL-117.md`，警报复审 `tool-117-ledger-alarm-reaudit.md`，`alarms.py check` 为 `clean (620 judgments)`。

`TOOL-118` 首轮真实正向路径暴露 managed model 把 `limit` 发成字符串，修复后又由抽帧发现 Markdown 错误代码块横向裁切；两条红线均保留并在新 binary 上 stop-and-fix。正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-023835` 重跑成功结果与 provider 401 失败：成功一次 WebSearch 返回两条有序结果和 `truncated:true`，失败一次 WebSearch 显示完整 401 且助手代码块自动换行；messages durable `1..40`、notifications `1..4` 单调，LLM body 无 validation retry，backend 仅预期 WARN，frontend 无异常，录屏 `244.275000s / 2784x1808 / 60fps`。证据 `evidence/TOOL-118.md`，警报复审 `tool-118-ledger-alarm-reaudit.md`，anchors `10/10`，五级已落账，`alarms.py check` 为 `clean (625 judgments)`。

`TOOL-119` 首轮红证据来自媒体标签脱敏泄露和生成图卡横竖版占位跳变；修复后二进制在真实 App、受管 gateway、Computer Use、三路 SSE witness、LLM tap、backend/frontend journal 和 60fps 录屏下完成 landscape 生图。最终真实 tool call 只调用一次 `generate_image`，wire 只做一次图片生成、一次媒体上传；SQLite、tool result、SSE 和 UI 对证，画面显示 `1344×768` 与真实附件。正式证据 `evidence/TOOL-119.md`，警报复审 `evidence/tool-119-ledger-alarm-reaudit.md`，anchors `10/10`，五级 `G1/F2/A5/C4/G2` 已落账，最终 `alarms.py check` 为 `clean (630 judgments)`。

该段以下既有 TOOL-116 及更早描述均为历史过程记录；恢复执行只以上述当前前线、`README.md` §5.2、`LOG.md` 最新条目和 COVERAGE 当前行为真相。

统一长门禁首轮由旧的“一次返回 55 个子节点”契约断言失败；按现行 `/documents` cursor 分页实现修正 testend，保留 `/documents/tree` 一次整树 metadata 断言。第十一批收口时完整 `make testend` 又冻结了一个真实前置问题：`install_mcp_server` 的不可绕过 danger gate 没有被 chat 验收剧本处理，导致回合正确停在 `streaming`；场景现已逐次断言并批准两道人闸，定向场景与完整 testend `go test ./...`（scenarios 292.290s）均通过。最终 `make verify` 四门全绿，backend gate、锚点 10/10、警报 clean、diff check 均通过；批次已提交 `de146b72`。

**历史快照。** 第九批已完成统一长门禁并提交 `32b33499`；第十批 `TOOL-091..100` 已完成 **50 / 50** 并提交 `553fa150`；第十一批 `TOOL-101..110` 已完成 **50 / 50**，完整 testend、`make verify`、锚点与警报复核通过并提交 `de146b72`。当时中央账本为 `595 judgments`，批次十二为 **10 / 50**，下一原子前线为 `TOOL-113 list_conversations`；该段仅供追溯，当前前线以上方整体重述为准。

下方既有 TOOL-106 及更早描述均为历史过程记录；恢复执行只以上述当前前线、`README.md` §5.2、`LOG.md` 最新条目和 COVERAGE 当前行作为真相。

`TOOL-106` 的前置红 session 已保留：托管模型数组字符串化导致重复调用、可选元数据省略、以及冲突 Activity rail 的成功/失败混合语义；stop-and-fix 已增加精确兼容解码、完整契约描述和统一失败动词/侧幕状态，定向 Go/Flutter 测试通过。正式证据为 `evidence/tool-106-formal-171941-green.md`；锚点因过期重新完成 10/10 校准，账本 gate 五格已写入，`gap-too-fast` 与 `discovery-collapse` 已用 `evidence/tool-106-ledger-alarm-reaudit.md` 复审并 ack，`alarms.py check` clean，未到 50 格不跑统一长门禁、不提交。

下方既有 TOOL-099/100 与旧批次描述为历史过程记录；恢复执行时以上述当前前线、`README.md` §5.2 和 `LOG.md` 最新条目为准。

`TOOL-098` green session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-100552` 的录屏为 `385.805000s / 2784x1808 / 60fps`；五级 `G1/F2/A5/C4/G2` 已写入 `COVERAGE.md`，行状态 `✓✓✓✓✓`。query `database query` 得 4、unmatchable 得 0 且显示 actionable recovery、unfiltered 得 96 且卡片 `first 30 of 96` 可打开有界 JSON tree；messages `1..48`、notifications `1..6`，LLM/REST/SQLite/UI 对齐，frontend/backend 红线为空。正式证据为 `tool-098-formal-100552-green.md`，账本复审为 `tool-098-ledger-alarm-reaudit.md`；观察器一次 30s timeout 已重取最终状态并单独归类，不算产品失败。

修复后 formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-104247` 用新 binary 重跑 `TOOL-099` 无 env 路径：真实 UI 显示 `Dangerous · Awaiting your approval`，SSE 为 `tool_call(dangerous) → interaction → resolved(Deny) → tool_result`，没有安装执行或半安装行；录屏 `88.993333s / 2784x1808 / 60fps`，五通道和 `rig-check` 全绿。证据 `evidence/tool-099-formal-104247-red-deny-gate.md` 只证明负路径，不写 `judge.py`。

上一轮 success formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-143238` 已得到 action-time `Allow`，修复后的卡片显示 `Allowed · connected · 2 tools`，动态 `search_tools` 与 `mcp__context7__resolve-library-id` 一次调用成功；但 uninstall cleanup 没有 gate 且发生了错误名重试，红证据 `evidence/tool-099-formal-143238-red-uninstall-no-gate-retry.md` 仍为红。下一步从修复后二进制重跑卸载，必须证明 `dangerous → interaction`、一次调用、失败名不重试和最终持久化清理。

`TOOL-097` green session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-095429` 的录屏为 `173.423333s / 2784x1808 / 60fps`；五级 `G1/F2/A5/C4/G2` 已写入 `COVERAGE.md`，行状态 `✓✓✓✓✓`。真实 durable card 显示六个默认角色、`Anselm Free` 脱敏 key 与 `ok` 状态、端点、`anselm-auto` 的 `1M/16.4k/image · video` 能力及 native option；messages durable `1..14`、notifications `1..2`，LLM wire/REST/SQLite/UI 对齐，frontend/backend 红线扫描为空。红证据为 `tool-097-formal-094444-red-thin-card.md`，账本复审为 `tool-097-ledger-alarm-reaudit.md`；第十批不因单格完成提前跑长门禁或提交。

`TOOL-095` 的产品结论：创建写入 `source=ai,pinned=false`；更新真实 `source=user,pinned=true` 记忆后只改变 description/body，策展与作者归属保留；非法 slug 原样拒绝并以红色 `Not saved` 显示具体规则，绝不静默改名或重试。SSE messages durable `1..42`、notifications `1..9` 连续，LLM 24 个状态条目全 200，backend/frontend journal clean。五格写账触发的 `gap-too-fast`/`pass-burst`/`discovery-collapse` 已在 `tool-095-ledger-alarm-reaudit.md` 中逐格复核后 ack。

`TOOL-093 inspect_media` formal green：红 session 暴露 fresh media turn 把 schema 示例 `att_...` 当成真实附件 ID，先造成一次失败调用；修复后，`history.go` 在 model-only `<uploaded_attachments_for_tools>` 目录提供按媒体顺序的精确 ID，同时 inspect schema/description 移除可复制示例值。真实 App 在 665.508333s 录屏中完成 image default vision、tiles、crop、text query、audio range、video range 六条路径；没有失败卡、placeholder 参数或伪造 transcript/scene/越界视觉结论。视频模型重复请求由 loop `Duplicate tool call suppressed`，未二次执行。messages `1..97`、notifications `1..2` 连续，LLM `58×200/8×201`，backend/frontend clean；正式证据为 `evidence/tool-093-formal-191935-green.md`，复审为 `tool-093-ledger-alarm-reaudit.md`，五级 `G1/F2/A5/C4/G2` 已落账。

`TOOL-092 read_attachment` formal green：首轮 hosted caller 将 canonical `id` 误发成 `attachmentId`，真实失败卡被冻结；修复 schema/description 的 `id` 规范并增加受管别名归一化后，真实 App 一次完成小文本正文读取、长文 `index/offset/query`、越界 offset 自纠和 PNG 媒体描述符降级。长文索引 `19 chunks / 145689 chars`，query 只有一个有界命中；图片明确指向 `inspect_media`，不伪造像素结论。主录屏 `432.071667s / 2784x1808 / 60fps`，重开 companion `35.160000s`；messages durable `1..111`、notifications `1..2` 无 gap，LLM 42×200/2×201，backend/frontend clean。正式证据为 `evidence/tool-092-formal-184402-green.md`，账本复审为 `tool-092-ledger-alarm-reaudit.md`，五级 `G1/F2/A5/C4/G2` 已落账。

第八批已完成 **50 / 50** 并提交 `31ad1e72`；第九批已完成 **50 / 50**，中央账本 **485 judgments**。第十批正式账本推进到 **500 judgments**，anchors 10/10 有效，正式 alarms clean；`TOOL-091` 的空/正向路径、`TOOL-092` 的文本/长文/媒体路径与持久化重开、`TOOL-093` 的六条 inspect_media 路径均已封存。一次未 export `RIG_HOME` 的试写误归默认账本，已重放到正式根并在台架手册和 LOG 记录；下一原子前线为 `TOOL-094 read_memory`。

`TOOL-091 list_attachments` formal green：空 workspace 一次真实 `list_attachments` 返回 empty；上传一个 91-byte plain-text fixture 后一次真实 `list_attachments` 返回一条 live metadata。SQLite 与 SSE close/tool result/LLM wire/UI 的 filename、kind、MIME、size、createdAt 一致；messages durable `1..29` 无 gap；工具卡逐字段展示本地化上传时点，正文表格由 redactor 指向附件卡，避免全局 timestamp privacy boundary 与产品可用性冲突。录屏 `346.391667s / 2784x1808 / 60fps`，backend/frontend scan clean；五级 `G1/F2/A5/C4/G2` 已落账。

`TOOL-088 edit_document` 的七轮首测红证据覆盖 reasoning placeholder、tags 编码、拆分 mutation、重复 search、provider 双重编码、失败 search 恢复和 filesystem-shaped search 参数。stop-and-fix 修复 per-Run safe-call ledger、search_documents 的窄 provider compatibility、tags 一层 JSON 编码解码，以及单一 canonical edit/opaque ID prompt 契约；测试、领域/API 文档和抽取清册同步。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-155506` 以新二进制、真实 onboarding、真实 Flutter App、受管 gateway、Computer Use、录屏和五通道台架重跑：一次 search、一次 edit、一次 child search，用户编辑目的完成，root rename 后 child path 正确级联；无失败活动、retry 或重复 mutation。REST/SQLite/tool result/UI 一致，messages `1..27`、notifications `1..5` 连续，LLM 全 200，backend/frontend clean，录屏 `140.740000s`。正式证据为 `evidence/tool-088-formal-155506-green-edit-document.md`，五级 `G1/F2/A5/C4/G2` 已落账；下一前线 TOOL-089。

`TOOL-089 move_document` 首轮 formal `20260803-162904` 冻结为红：true-cycle 后重复同一 pair，且前端把 terminal duplicate 渲成第二张误导性的 `Not run` 卡；红证据保留。stop-and-fix 增加可选 `RepeatTerminaler` 终态标记、per-Run terminal ledger、terminal duplicate 前端隐藏、cycle-specific failure card 与双语/领域/抽取清册同步，S18 五方法接口不变。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-164319` 使用修复后二进制和真实 App 重跑三条产品路径：position 0 移入、position 2 移回 root 并单次 list、移入 descendant 的 terminal cycle rejection。SQLite seq `3/4`、`9/10`、`12/13`、`18/19`，最终 tree、UI、REST/tool result、LLM wire 一致；546.920000s screen.mov 可读，SSE 452 frames/61 durable/无 gap，LLM 全 200，backend/frontend 无未解释红线。正式证据为 `evidence/tool-089-formal-164319-green.md`，复审为 `tool-089-ledger-alarm-reaudit.md`；`G1/F2/A5/C4/G2` 已落账。

`TOOL-090 delete_document` 首轮 formal `20260803-170003` 冻结为红：后端 not-found 软失败和最终 prose 正确，但工具卡显示成功删除。修复为 completed not-found payload 的失败重分类、琥珀原始证据与自动展开；同步前端测试、Document/Chat 文档和工具清册。formal green `20260803-170748` 以新二进制和真实 App 重跑 exact search + cascade delete、missing-ID no-op 负路径及 Library 投影；234.611667s screen.mov 可读，SQLite/REST/UI/LLM wire 一致，SSE 298 frames、messages `1..36`、notifications `1..7` 单调、无 gap，LLM 全 200，backend/frontend clean。证据为 `evidence/tool-090-formal-170748-green.md`，复审为 `tool-090-ledger-alarm-reaudit.md`；`G1/F2/A5/C4/G2` 已落账，中央账本 485，警报 clean。第九批 **50 / 50**，当前跑统一长门禁；下一前线 TOOL-091。

`TOOL-081 search_activations` 首轮冻结三条真实红：`firingCount` 被解释为历史累计、`payload.manual=true` 被解释为 CEL 阈值通过、以及 hosted model 的字符串标量导致后端拒绝和可见 retry。修复为 per-activation fan-out/manual bypass 语义、exact bool/decimal scalar string 窄兼容，测试、API/domain 文档和抽取清册同步；三份红证据均保留不计绿。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-113825` 用真实 Flutter App、受管 gateway、Computer Use、314.906667s 录屏、三路 SSE witness、backend/frontend journal 和 LLM tap 完成复验：最终 UI 因果解释正确，请求序列无失败/retry，五通道一致，SSE durable seq 单调，LLM 响应全 200，backend/frontend 无未解释红线。fixture 通过独立本地 API session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-114620` DELETE=204→GET=404 清理，SQLite 审计保留，台架已收台；五级 `G1/F2/A5/C4/G2` 已落账。

`TOOL-082 get_activation` 使用 formal session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-115120` 读取真实历史 activation 与不存在 ID：正向 200，负向 404；UI 如实展示 manual fan-out、缺失 optional fields 和 authoritative not-found，无 retry。screen.mov `179.710000s`，SSE durable messages `1..18`、notifications `1..2` 单调，LLM 全 200，backend 仅预期 not-found WARN，frontend clean。正式证据为 `evidence/tool-082-formal-115120-green.txt`；首次 L5 因证据文件瞬时不可见而被 gate 拒绝，确认落盘后幂等补写，复审说明已记录；五级落账。

`TOOL-083 search_firings` 的两轮红分别暴露 hosted model 字符串化 `limit` 和把 `pattern` 当作必填 `triggerId` 的引导错误；修复为 exact decimal limit 窄兼容，以及 description/schema/validation 的 exact opaque triggerId 契约，补测试、API 文档和抽取清册。formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-120402` 三条有效查询无失败/retry，结果 1/1/0，空 skipped 是合法 no-match；screen.mov `141.861667s`，SSE durable messages `1..39`、notifications `1..2` 单调，LLM 全 200，backend/frontend clean。正式证据为 `evidence/tool-083-formal-120402-green.txt`，三条警报已按红绿证据复审 ack，五级落账。

`TOOL-084 search_documents` 先后冻结四条真实红：filesystem `path/pattern` 形状误投到文档搜索；显式分页返回 cursor 但 schema 没有 cursor；assistant 在同一 tool-call 消息中先流出用户可见答案，导致重复 Page 3；混合搜索的 semantic-only recall 引入无关文档。formal 红证据保留于 `sessions/20260803-121222/`、`121822/`、`122316/`、`123034/`、`123622/` 的 `evidence/` 下，均不计绿。

stop-and-fix 收紧 `search_documents` 的文档库语义、`query/limit/cursor` 契约和首调用即携带显式 limit 的规则；补充结果 metadata hydration、精确 cursor 续页、tool-call 消息不得带用户答案的 loop 提示，并让文档关键词搜索显式走 lexical-only，保留 RAG/omni 的 hybrid 行为。同步 Go 测试、chat prompt 测试、文档和工具抽取清册；`go test ./internal/app/chat ./internal/app/tool/document ./internal/app/search`、`make -C docs verify`、`git diff --check` 均通过。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-124129` 使用新二进制、真实 Flutter App、真实受管 gateway、Computer Use、连续录屏和五通道台架完成：首调用即 `limit=1`，后续两页使用精确 cursor `eyJoIjoiY2UxNGM5MjM4NzRkIiwibyI6MX0` 与 `eyJoIjoiY2UxNGM5MjM4NzRkIiwibyI6Mn0`，总计 3 条目标文档，无 `Noisy Field Notes` 语义误命中；最终 UI 只有一份答案、无失败卡/retry/重复 Page 3。录屏 `187.523333s`，SSE durable seq `1..48` 连续，LLM wire 与 REST/SQLite 交叉一致，backend/frontend 无未解释错误；fixture 清理为 DELETE=204、GET=404、列表为空。正式证据为 `evidence/tool-084-formal-124129-green-search-documents.txt`，账本复审为 `tool-084-ledger-alarm-reaudit.txt`，五级 `G1/F2/A5/C4/G2` 已落账。

`TOOL-085 list_documents` 首轮正式空目录路径在 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-130911` 冻结为红：旧 60 秒响应头预算让 UI 最终显示 `LLM_STREAM_ERROR`，用户拿不到已知空结果；红证据保留且不计绿。stop-and-fix 将共享建连响应头预算提高到 120 秒，保持 ChatTurnSec、流式 idle 和 LLMStreamMaxSec 不变，并补 transport 单测与 Chat domain 说明。formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-132312` 真实完成 Large Collection `40/40/40` 游标分页和 C · Empty Notebook 空目录路径，UI 明示 `complete:true`、`hasMore:false`、总数 120、首尾 0/119 及 `Listed document · empty`；LLM wire/REST 一致、全 200，SSE conversation durable `1..36`、`37..54`，backend/frontend clean，录屏 `418.840000s`。证据为 `evidence/tool-085-formal-132312-green-list-documents.md`，警报复审为 `tool-085-ledger-alarm-reaudit.md`，五级已落账；第九批推进到 **25 / 50**，下一前线 `TOOL-086 read_document`，未到第 50 格不跑统一长门禁、不提交。

`TOOL-086 read_document` 先后冻结两条真实红：formal-133944 的 query-required 空参数被前端误呈为 `Listed document · failed`，且模型把 filesystem `path/pattern` 形状投给 `search_documents`；formal-134623 的模型将文档名称/路径误当 opaque `read_document.id`，产生一次可见 not-found 后才搜索重试。修复为前端 search-only channel、以及 `read_document` description/schema 的 exact opaque `doc_` ID 契约，并同步 entity-search/document 测试与 domain docs。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-135027` 真实 Flutter App + 受管 gateway + Computer Use 重跑，wire 严格为 `search_documents` → `search_tools` → `read_document`；最终 UI 完整展示 path、description、tags、全部标题、中文注记和最终句，无失败卡/retry。REST/SQLite、tool result、SSE messages durable `1..27`、LLM 全 200、backend/frontend journal 一致，录屏 `159.260000s / 2784x1808 / 60fps`；正式证据为 `evidence/tool-086-formal-135027-green-read-document.md`，警报复审为 `tool-086-ledger-alarm-reaudit.md`，五级已落账。cleanup session `20260803-135432` 已将本轮 fixture DELETE=204→GET=404，列表为空，台架已收台；第九批推进到 **30 / 50**，下一前线 `TOOL-087 create_document`，未到 50 格不跑统一长门禁、不提交。
formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-135027` 真实 Flutter App + 受管 gateway + Computer Use 重跑，wire 严格为 `search_documents` → `search_tools` → `read_document`；最终 UI 完整展示 path、description、tags、全部标题、中文注记和最终句，无失败卡/retry。REST/SQLite、tool result、SSE messages durable `1..27`、LLM 全 200、backend/frontend journal 一致，录屏 `159.260000s / 2784x1808 / 60fps`；正式证据为 `evidence/tool-086-formal-135027-green-read-document.md`，警报复审为 `tool-086-ledger-alarm-reaudit.md`，五级已落账。cleanup session `20260803-135432` 已将本轮 fixture DELETE=204→GET=404，列表为空，台架已收台；第九批推进到 **30 / 50**，下一前线 `TOOL-087 create_document`，未到 50 格不跑统一长门禁、不提交。

`TOOL-087 create_document` formal-140938、142906、143806、144710 先后冻结为红：分别发现 placeholder ID 进入用户表格、首次 create 漏掉必填 name、先造空根再删除/编辑且同名子文档重复 mutation、以及用户明确提供的 description/tags 被模型静默漏传。四份红证据均保留、不计绿。stop-and-fix 修复 system prompt、loop redactor，并把 LLM schema 收紧为每次必传 name/description/content/tags；未提供后三者显式传空字符串/空数组，用户值同一 canonical call 原样带上；Go loop/chat/document 回归、工具清册与 document domain 文档同步。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-145421` 真实 Flutter App + 受管 gateway + Computer Use + 五通道重跑：root `/Release Atlas` 与 child `/Release Atlas/Ship Checklist` 正确写入，root description/tags 与 child description 均与用户输入一致，child `parentId` 精确指向 root；最终 UI 只显示两项 Created，无 retry/delete/edit/duplicate/failure，路径和嵌套关系清楚。SSE durable messages/entities/notifications 为 `1..26`/`1..4`/`1..4` 连续唯一，LLM 两次实际 create 均带齐必填字段且全 HTTP 200，REST/SQLite/tool result/UI 一致，backend/frontend clean，录屏 `282.973333s`。证据为 `evidence/tool-087-formal-145421-green-create-document.md`；台架已收台。`judge.py` 写入五级，中央账本由 465 增至 **470 judgments**；两条统计警报按锚点重校、四份红证据和五通道复审后 ack，`alarms.py check` clean。第九批推进到 **35 / 50**，下一前线 `TOOL-088 edit_document`，未到第 50 格不跑统一长门禁、不提交。

`TOOL-079` 的首轮 Computer Use 观察在打开/关闭模型 Popover 后产生 105 行 macOS `AXTree` 更新失败，画面没有立即破碎但可访问性树已退化；已在 `an_popover.dart` 为常驻 `OverlayPortal` 增加稳定的 `Semantics(container:true, explicitChildNodes:true)` 边界，补 14/14 Flutter 回归并通过 frontend 5174 项、docs verify、相关 Go tests 和 diff 检查。负向 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-073913` 的 Deny 未执行删除；正向 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-101120` 的 Allow 只执行一次 delete，UI 显示主行不可恢复、listener 停止、关系影响和审计历史保留，SQLite/REST、SSE、LLM wire、backend/frontend journals 与 `838.035000s / 2784x1808 / 60fps` 封口录屏一致。五级 `G1/F2/A5/C4/G2` 已落账；正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-101120/evidence/tool-079-formal-green-delete-trigger.txt`。本批仍未到第 50 格，不启动统一长门禁、不提交。

`TOOL-078` formal-136 首轮真实 create 暴露 hosted model 将 `config` 发成 JSON 字符串，后端拒绝、App 留失败活动并 retry；修复后 formal-137 真实 onboarding 先 create cron，再 edit name/description/expression，最终 SQLite 为 `acceptance_078_cron_renamed`、`Edit acceptance trigger`、`*/20 * * * *`、`paused=0`，UI 无失败卡/retry/Settling 残留。五通道证据为 screen.mov `222.758333s`、SSE 432 帧且 messages durable `1..59`、LLM tap 24 个有状态响应全 200、backend/frontend 错误扫描 clean；证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-070531/evidence/tool-078-formal-137-green-edit-trigger.txt`。模型最后一次 reasoning 声称字符串化但 wire 仍是 native object，已如实记录，不将其冒充字符串 wire 成功；真实历史红证据与 decoder 单测继续承担该兼容路径证明。五级 `G1/F2/A5/C4/G2` 已落账，gap-too-fast 按批量写账复审并 ack，当前未到 50 格不跑统一长门禁、不提交。

formal-132 暴露 webhook endpoint 被错误脱敏成不可用 placeholder；formal-133 暴露 sensor 自然语言 output map 未规范化导致两次失败重试；formal-134 暴露 fsnotify 坏 config 让 Flutter trigger 卡直接 Map 强转，真实 App 出现 `Something went wrong` 和 Dart type-cast 异常。三份红证据均保留不计绿。修复分别落在 webhook 语义 redaction、sensor map→CEL 规范化及 trigger card 的坏输入容错，并同步 Go/Flutter 回归测试与 domain docs。

`TOOL-080` 首轮暂停负向把恢复动作错误引导到 `edit_trigger`，冻结为红；修复后工具描述、trigger domain 文档、抽取清册和守卫测试共同明确 Resume control/`:resume`，而非 `edit_trigger`。formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-104036` 的正向只执行一次 `fire_trigger` 并产生一个 activation/firing/completed flowrun，暂停负向只执行一次并无 mutation；screen.mov `223.748333s`，SSE 三流无 gap/error，LLM 响应全 200，backend/frontend 扫描 clean。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-104036/evidence/tool-080-formal-green-fire-trigger.txt`，fixture 通过真实 DELETE=204→GET=404 清理，五级已落账。

formal green session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-064904` 使用新二进制、真实 Flutter App、真实受管网关、Computer Use 和五通道台架走通 sensor、cron、webhook、fsnotify 四种 source kind。sensor 真实搜索 function 后一次创建，cron 展示 next fire，webhook 精确 endpoint 只在工具卡可复制，fsnotify 展示路径/事件/pattern；四条均一次成功，最终画面无错误横幅。screen.mov `297.055000s`；SSE 778 帧、messages durable 尾段 `102..116` 单调；backend/frontend 无未解释红线，REST/SQLite/LLM wire/UI 一致。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-064904/evidence/tool-077-formal-135-green-four-trigger-kinds.txt`。五级 `G1/F2/A5/C4/G2` 已落账，gap-too-fast 已按完整复核说明 ack；未到第 50 格，不启动统一长门禁、不提交。

## 历史前线摘要（更新前，2026-08-02 05:27）

第六批已完成 **50 / 50**，中央账本 `350 judgments`，锚点校准有效，警报复审后 clean，统一长门禁和完整 testend 已通过并提交 `8e2c93e4`。`TOOL-055 edit_approval`、
`TOOL-056 revert_approval`、`TOOL-057 delete_approval`、`TOOL-058 search_workflow`、`TOOL-059 get_workflow` 与
`TOOL-060 create_workflow` 已完成 formal 红路径、修复和正负五通道重跑；第七批的 `TOOL-061 edit_workflow` 与 `TOOL-062 revert_workflow` 也已完成 stop-and-fix、正负五通道复验和真实 fixture 清理，当前 **10 / 50**，中央账本 `360 judgments`，下一前线为 `TOOL-063 delete_workflow`，未到第 50 格不启动统一长门禁和提交。
`TOOL-063` 已冻结并完成两轮 stop-and-fix：per-Run exact-once mutation ledger 与“删除主行不可恢复、没有 restore 操作”的产品真相均已有代码、测试和文档证据；formal-139 已由真实 App 走到危险删除人闸，但该不可逆动作尚未获授权，故不判绿、不写账本。当前应从 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-052255` 的保留证据继续，而不是另起台架。
formal-120 的正式证据为 `/private/tmp/anselm-rig-formal-120/sessions/20260802-013952/evidence/tool-055-formal-120-green.txt`。
formal-122 的正式证据为 `/private/tmp/anselm-rig-formal-122/sessions/20260802-020059/evidence/tool-056-formal-122-green.txt`。
formal-123 红证据为 `/private/tmp/anselm-rig-formal-123/sessions/20260802-020830/evidence/tool-057-formal-123-red-gate-fact-and-delete-semantics.txt`；
formal-124 绿证据为 `/private/tmp/anselm-rig-formal-124/sessions/20260802-021702/evidence/tool-057-formal-124-green.txt`。
formal-125 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-022906/evidence/tool-058-formal-125-red-search-fields.txt`；
formal-126 绿证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-023543/evidence/tool-058-formal-126-green.txt`。
formal-127 绿证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-024437/evidence/tool-059-formal-127-green.txt`。
formal-128 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-025448/evidence/tool-060-formal-128-red-stringified-ops-retry.txt`；formal-129 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-030431/evidence/tool-060-formal-129-red-metadata-omitted.txt`；formal-130 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-030934/evidence/tool-060-formal-130-red-metadata-guidance-insufficient.txt`；formal-131 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-031452/evidence/tool-060-formal-131-red-required-metadata-ops-error.txt`；formal-132 绿证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-032142/evidence/tool-060-formal-132-green-stringified-metadata.txt`。TOOL-061 正向 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-041823`，固定后的正式负向证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-042438/evidence/tool-061-formal-acceptance.txt`。
formal-128 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-025448/evidence/tool-060-formal-128-red-stringified-ops-retry.txt`；formal-129 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-030431/evidence/tool-060-formal-129-red-metadata-omitted.txt`；formal-130 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-030934/evidence/tool-060-formal-130-red-metadata-guidance-insufficient.txt`；formal-131 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-031452/evidence/tool-060-formal-131-red-required-metadata-ops-error.txt`；formal-132 绿证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-032142/evidence/tool-060-formal-132-green-stringified-metadata.txt`。TOOL-061 正向 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-041823`，固定后的正式负向证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-042438/evidence/tool-061-formal-acceptance.txt`；TOOL-062 正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-044518/evidence/tool-062-formal-acceptance.txt`。
formal-128 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-025448/evidence/tool-060-formal-128-red-stringified-ops-retry.txt`；formal-129 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-030431/evidence/tool-060-formal-129-red-metadata-omitted.txt`；formal-130 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-030934/evidence/tool-060-formal-130-red-metadata-guidance-insufficient.txt`；formal-131 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-031452/evidence/tool-060-formal-131-red-required-metadata-ops-error.txt`；formal-132 绿证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-032142/evidence/tool-060-formal-132-green-stringified-metadata.txt`。TOOL-061 正向 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-041823`，固定后的正式负向证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-042438/evidence/tool-061-formal-acceptance.txt`。
TOOL-057 的最终语义是软删主行、清关系、保留版本历史、执行前经过危险人闸；TOOL-058 的最终语义是直接关键词优先、无直接命中时补语义，并返回 workflow 完整状态字段；TOOL-059 的最终语义是完整返回并展示 active graph、生命周期、并发策略和错误边界。
`TOOL-060` 的最终语义是显式保留 metadata，且在执行边界窄兼容 hosted model 的精确 stringified tags/ops；`TOOL-061` 的最终语义是编辑已有 workflow 时只发一次合法 mutation，缺失实体只呈现一张诚实失败卡；`TOOL-062` 的最终语义是同一调用携带 workflowId/version，兼容 hosted model 的精确 stringified version，失败结果权威且版本历史保留。三者的 REST/SQLite/SSE/UI/wire 一致；正式 fixture 已通过真实 API 删除并验证 GET=404，SQLite 仅留契约要求的最后 workspace 与审计行。锚点重新校准后 gap/discovery 警报均按证据重审并销账，当前第七批 **10 / 50**，下一前线 `TOOL-063 delete_workflow`。

以下为前一状态的历史摘要，保留用于追溯：

第五批已达到 **50 / 50**：`TOOL-033` 至 `TOOL-046` 均完成五级真实裁决，已提交 `90f51edd`。第六批当前 **24 / 50**，中央账本为 `320 judgments`，锚点校准有效，警报复审后 clean。`TOOL-047 get_control` 的 formal-103 已通过；`TOOL-048 create_control` 的 formal-104/105 红证据暴露 stringified branches、branch `name` 误用和同批重复 mutation，修复后 formal-106 已完成正负五通道复核。`TOOL-049 edit_control` 的 formal-107 红证据暴露同一用户意图产生缺 reason 的 v2 与带 reason 的 v3；修复后 formal-108 已完成审计 reason 正负五通道复核。`TOOL-050 revert_control` 的 formal-109 红证据暴露 hosted model 字符串化 version 导致首轮失败与 retry；修复后 formal-110 真实 App 正向只出现一张成功 `↩ v1` activity，负向不存在版本只出现一张失败卡且 active v1 不变。formal-110 录屏 `147.631667s / 2784x1808`，messages durable `1..29`、notifications `1..7` 连续，entities 已连接，LLM chat completion 全 200，backend 仅刻意负向 WARN，frontend 无 Flutter runtime 红线；证据文件为 `/private/tmp/anselm-rig-formal-110/sessions/20260802-000259/evidence/tool-050-formal-110-green.txt`，fixture/conversation DELETE=204 后 GET=404，台架已收台。`TOOL-051 delete_control`、`TOOL-052 search_approval`、`TOOL-053 get_approval` 的 formal-112/113/114 均完成真实 App 正负五通道复核；`TOOL-054 create_approval` 的 formal-115 红证据与 formal-116 修复后绿证据也已封存，formal-116 无失败活动、无 retry、无第二次 mutation，fixture/conversation DELETE=204 后 GET=404。最新证据为 `/private/tmp/anselm-rig-formal-116/sessions/20260802-010803/evidence/tool-054-formal-116-green.txt`。第六批未到 50 格，不跑统一长门禁、不提交；下一前线为 `TOOL-055 edit_approval`。

`TOOL-051 delete_control` 已完成 stop-and-fix 与正式复验。formal-111 红证据暴露空参 `get_control`、缺少可见 destructive approval gate、以及 post-delete fetch；formal-112 真实 App 正向先查关系，再只调用一次 delete，明确停在 `Dangerous / Awaiting your approval` 卡，批准后只出现一张 `Allowed` 删除活动。REST 证明实体 404、关系清空、版本历史保留，workflow capability-check 明确报告缺失 control；正式证据为 `/private/tmp/anselm-rig-formal-112/sessions/20260802-002441/evidence/tool-051-formal-112-green.txt`。screen.mov `293.141667s / 2784x1808`，messages durable `1..24`、notifications `1..7` 单调，entities 已连接，LLM 全 200，backend/frontend journal 无未解释红线。五级 `G1/F2/A5/C4/G2` 已落账，中央账本 `305 judgments`，警报逐级复审并串行 ack 后 clean；第六批未到 50 格，不跑统一长门禁、不提交。

`TOOL-052 search_approval` 已完成 formal-113：三个真实 REST fixture 支撑 `refund` 正向命中、随机 query 0 结果、空 query 全量列表三条只读目的；正向结果卡可点击进入 Approval 详情，完整 description/template/rules 可见。wire 三次各只调用一次 search_approval，SSE messages durable `1..40`、notifications `1..7` 单调，entities 已连接，LLM 全 200，backend/frontend 无未解释红线；三条 approval 与两条 conversation 已 DELETE=204 并验证列表为空。证据为 `/private/tmp/anselm-rig-formal-113/sessions/20260802-003731/evidence/tool-052-formal-113-green.txt`。五级 `G1/F2/A5/C4/G2` 已落账，中央账本 `310 judgments`，警报复审后 clean；第六批 **14 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-053 get_approval`。

`TOOL-053 get_approval` 已完成 formal-114：真实 onboarding 后建立带 `releaseName`/`riskScore`/`hasMigration` 三字段、完整 markdown template、`allowReason=true`、`timeout=2h`、`timeoutBehavior=reject` 的 approval fixture。正向真实 App 只调用一次 `get_approval`，逐层展示 id/name/description、输入表、完整 template 和 Behavior Settings；缺失 ID 负向也只调用一次，显示明确 not-found 红卡与不编造详情的说明，无 retry。screen.mov `222.798333s / 2784x1808 / 60fps`，messages durable `1..29`、notifications `1..5` 连续，entities 已连接，LLM 响应全 200，backend 仅刻意负路径 WARN，frontend 无 Flutter runtime 红线；approval 与 conversation DELETE=204 后列表为空、GET=404。证据为 `/private/tmp/anselm-rig-formal-114/sessions/20260802-004855/evidence/tool-053-formal-114-green.txt`。五级 `G1/F2/A5/C4/G2` 已落账，中央账本 `315 judgments`，警报复审后 clean；第六批 **19 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-054 create_approval`。

`TOOL-054 create_approval` 已完成 stop-and-fix 与正式复验。formal-115 首轮真实 App 冻结为红：托管模型将 `allowReason` 与 `inputs` 字符串化，首轮后端拒绝后 retry，UI 同时留下失败和成功活动；红证据为 `/private/tmp/anselm-rig-formal-115/sessions/20260802-005845/evidence/tool-054-formal-115-red-stringified-scalars-and-retry.txt`。approval 边界随后加入 native/精确 JSON 字符串兼容 decoder，输入对象按 key 稳定排序，公开 schema 未放宽，并补定向测试与领域文档。formal-116 `/private/tmp/anselm-rig-formal-116/sessions/20260802-010803` 以真实 App、受管网关、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏重跑：模型只调用一次 `create_approval`，无 retry/search/第二次 mutation；UI 只有一张 Created activity，完整表单结果与 wire/REST 一致。screen.mov `245.026667s / 2784x1808`，messages durable `1..15`，LLM 最终 stop，backend/frontend 无未解释运行时红线；approval/conversation DELETE=204 后列表为空、GET=404。正式证据为 `/private/tmp/anselm-rig-formal-116/sessions/20260802-010803/evidence/tool-054-formal-116-green.txt`。五级 `G1/F2/A5/C4/G2` 已落账，中央账本 `320 judgments`，警报复审并串行 ack 后 clean；第六批 **24 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-055 edit_approval`。

`TOOL-055 edit_approval` 的 stop-and-fix 链已完整封存：formal-117 真实会话暴露全量替换字段被托管模型省略，formal-118 暴露空缺 `changeReason`，formal-119 的真实 App 观察暴露 edit 失败 UI 错误复用 create/draft 文案并渲染可操作审批按钮；三轮红事实均不计绿。修复后补齐全量字段/非空审计理由的执行前校验、窄兼容 decoder、工具描述/公开 schema、领域文档和 Flutter regression。

formal-120 `/private/tmp/anselm-rig-formal-120/sessions/20260802-013952` 使用真实 App、受管网关、Computer Use、三路 SSE witness、LLM tap 和连续录屏重跑。正向只调用一次 `edit_approval` 将 v1→v2；负向只调用一次空 `changeReason`，mutation 前拒绝且无 v3、无 retry。screen.mov `417.105000s / 2784x1808 / 60fps`；messages durable `1..29`、entities `1..2`、notifications `1..6` 连续，LLM observed responses 全 200，backend 只有刻意负向 validation WARN，frontend 产品运行时 marker scan clean。严格 `rig-check` 只因 215 行 Computer Use 读取动态 macOS AX 树的已知 `accessibility_bridge.cc` 观察噪声失败；该事实已写入正式证据，没有被隐藏。fixture/conversation DELETE=204 后 GET=404、列表清空，rig-down 已收台。五级 `G1/F2/A5/C4/G2` 已落账，中央账本 `325 judgments`，警报复审后 clean；第六批由 **24 / 50** 推进至 **29 / 50**，下一前线为 `TOOL-056`，未到 50 格不跑统一长门禁、不提交。

`TOOL-056 revert_approval` 的 formal-121 `/private/tmp/anselm-rig-formal-121/sessions/20260802-015701` 首轮冻结为红：托管模型把 `version` 发成字符串，后端拒绝并让 App 出现失败活动后准备 retry；红证据已封存，不计绿。stop-and-fix 在 approval 工具边界增加 exact decimal integer string 兼容，公开 schema 仍为 integer，浮点/布尔/数组/坏字符串继续拒绝，并补测试、描述和领域文档。formal-122 `/private/tmp/anselm-rig-formal-122/sessions/20260802-020059` 真实正向只出现一张 `Reverted approval · ↩ v1`，负向 version 999 只出现一张可解释失败卡且 active v1 不变；无 retry、无 v3。录屏 `100.383333s / 2784x1808 / 60fps`，messages durable `1..29`、notifications `1..7` 连续，entities 已连接，LLM observed responses 全 200，backend 只有刻意负向 version-not-found WARN，frontend/AXTree marker scan clean。REST/SQLite/UI/wire 一致，fixture/conversation DELETE=204 后 GET=404、列表清空，rig-down 已收台。五级 `G1/F2/A5/C4/G2` 已落账，中央账本 `330 judgments`，警报复审后 clean；第六批由 **29 / 50** 推进至 **34 / 50**，下一前线为 `TOOL-057`，未到 50 格不跑统一长门禁、不提交。

## 唤醒协议

每次 loop 必须按以下顺序执行：

1. 读取 [README.md](README.md) 与 [LOG.md](LOG.md)，取得当前前线、开放问题和上次收台位置；再只读
   本轮相关的 COVERAGE、JOURNEYS、CODEX 和台架手册。
2. 运行 `rig-check.sh` 和锚点校准。台架或锚点不绿时，只修台架/裁判系统，不评价产品。
3. 选择一个**最小但完整的产品切片**：一个真实用户目的，或一条旅程中的一个独立站点。切片必须
   能从用户入口走到可验证结果；不按“本轮多盖多少格”倒推范围。
4. 真实启动 App、真实连接受管网关，用 Computer Use 操作；同步观察帧、后端、三路 SSE、Flutter
   console 和 LLM wire。录制操作前、中、后的完整区间，不能只截成功终态。
5. 在该切片驻停清扫适用的正常、空、加载、错误、边界、窄窗、双语、reduced motion 和难触发
   路径。产品目的未达成，或视觉上任何一点不舒服，切片保持未完成。
6. 一旦发现问题，冻结前线并直接修复。修复必须带守卫测试和同步文档；随后逐帧重跑原路径，并
   横扫同类组件/状态，确认修复不是单点补丁后才能解冻。
7. 只能通过 `judge.py` 更新 COVERAGE。pass/fail 必须有真实证据与 CODEX 法条或测量值；不能用
   一次模糊证据批量覆盖不同状态，不能手改格子。
8. 每个切片收尾将证据 session、修复、未决红格和当前批次计数写进 `LOG.md`。达到第 50 个单格时，
   才运行 `alarms.py check`、收台、`make verify`、完整 testend、已修场景回归并提交；批次中只跑
   与当前修复直接相关的快速守卫测试。
9. 没有外部阻塞时立刻选择下一个切片；遇到需要用户拍板的产品形状问题，按 §6 记录并继续不依赖
   该决定的前线。不得用假设把它判绿。

## 反退化护栏

- 一次 loop 只能推进一个最小完整切片，不以时间或 token 预算驱动吞吐。
- 上一轮仍有 live rig/session 时，不得另起第二套台架；先检查并接管/收尾已有会话。
- 锚点凭证过期、警报开放、五通道缺失、前端红行、后端未解释错误或证据不完整时，禁止新增
  `pass`。
- 每次上下文恢复都从盘上文件和当前 git 状态恢复；不信任对话记忆中的“已经测过”。
- 后续修复触及已绿的原语、组件、token、路由或数据结构时，相关旧裁决自动回到待复验队列。
- 质量标准恒定：边角、错误态、降级态与主路径同样要求达到 craft bar。

## 停止条件

Loop 只有在 Goal 的完成定义全部满足时才能停止并将 Goal 标记 `complete`。单轮结束、当天结束、
上下文耗尽、速度变慢或某个区域暂时困难，都不是完成条件。若同一外部阻塞连续三次阻止有意义进展，
只能按 Goal 机制标记 blocked，并在 `LOG.md` 写清楚阻塞证据；不能用“暂时不测”伪装完成。

## 当前配置状态

2026-08-02 00:08 (+0800)：`TOOL-050 revert_control` formal-109 首轮真实 App 冻结为红：hosted model 将 `version` 发成字符串，后端拒绝，UI 留下失败 activity，随后 retry 成功；红证据为 `/private/tmp/anselm-rig-formal-109/sessions/20260801-235559/evidence/tool-050-formal-109-red-stringified-version.txt`，不计绿。stop-and-fix 在 control 工具边界加入 exact decimal integer string 解码，公开 schema 仍为 integer，浮点/布尔/数组/坏字符串继续拒绝；补 control 测试、工具描述和领域文档，定向 Go 测试通过。
- formal-110 `/private/tmp/anselm-rig-formal-110/sessions/20260802-000259` 用新二进制、真实 onboarding、真实受管网关、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏重跑。正向只执行一次 `revert_control`，wire 的 `version:"1"` 被兼容接受，active pointer 从 v2 移到 v1 `ctlv_c05fb8b13fd7b636`；UI 只有一个成功 `Reverted control … · ↩ v1` activity，正文明确 v2 仍在历史。负向只执行一次 version 999，backend 返回 `control logic version not found`，UI 只有一张失败卡且说明 active v1 unchanged，无 retry/新版本。
- 五通道：screen.mov `147.631667s / 2784x1808 / 60fps`；SSE messages durable `1..29`、notifications `1..7` 连续，entities 已连接且无 durable 业务帧，三流各连接一次；LLM 五个 chat completion request/response 全 200；backend 只有刻意负路径 WARN；frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception runtime marker。正负终帧和摘要保存在 session evidence 内。control 与 conversation DELETE=204，随后 GET=404，列表无 fixture 残留；rig-down 已封口且无台架进程泄漏。
- 五级裁决 `TOOL-050=G1/F2/A5/C4/G2` 已写入 COVERAGE；中央账本从 295 增至 `300 judgments`，锚点有效，gap-too-fast/discovery-collapse 按 formal-110 证据逐级复审并 ack，最终 `alarms.py check` clean。本批由 **3 / 50** 推进至 **4 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线为 `TOOL-051 delete_control`。

2026-08-01 23:51 (+0800)：`TOOL-049 edit_control` formal-107 首轮真实 App 冻结为红：托管模型先省略 `changeReason` 生成 v2，再补 reason 生成 v3，同一用户意图产生两次版本 mutation；红证据为 `/private/tmp/anselm-rig-formal-107/sessions/20260801-233447/evidence/tool-049-formal-107-red-missing-change-reason.txt`，不计绿。stop-and-fix 将非空 `changeReason` 加入 AI schema required、工具描述和执行前校验，新增 `CONTROL_CHANGE_REASON_REQUIRED`、control 测试、error-code 与领域文档；定向 `go test ./internal/app/tool/control ./internal/app/loop` 通过。
- formal-108 `/private/tmp/anselm-rig-formal-108/sessions/20260801-234249` 使用新二进制、真实 onboarding、真实受管网关、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏重跑。正向只执行一次 `edit_control`，wire 使用 stringified branches 且每项为正确 `port`，exact reason 为 `acceptance TOOL-049 final fix`，创建 v2 `ctlv_34cbcddfc2f6d22a`；UI 只有一个成功 activity，完整呈现 pass/escalate/review。负向只执行一次缺 reason 调用，backend 在 mutation 前返回 `input validation failed: changeReason is required`，UI 显示失败原因和 `Draft unsaved · truth is still the last version`，无 retry；REST active version 仍是 v2，无 v3。
- 五通道：screen.mov `189.023333s / 2784x1808 / 60fps`；SSE messages durable `1..29`、entities `7..8`、notifications `16..21` 连续，三流各连接一次；LLM 五个 chat completion request/response 全 200；backend 只有刻意负路径 WARN；frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception runtime marker。正负终帧和摘要保存在 session evidence 内。control 与 conversation DELETE=204，随后 GET=404，列表无 fixture 残留；rig-down 已封口且无台架进程泄漏。
- 五级裁决 `TOOL-049=G1/F2/A5/C4/G2` 已写入 COVERAGE；中央账本从 290 增至 `295 judgments`，锚点有效，gap-too-fast/discovery-collapse 按 formal-108 证据逐级复审并 ack，最终 `alarms.py check` clean。本批由 **2 / 50** 推进至 **3 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线为 `TOOL-050 revert_control`。

2026-08-01 23:30 (+0800)：`TOOL-048 create_control` formal-104/105 先后冻结为红：托管模型发出 stringified branches、错误使用 `name`，并在一批 assistant response 中重复 mutation；修复为窄 decoder、明确 `port` schema/描述和同批完全重复调用抑制，定向 control/loop 测试通过。formal-106 使用真实 App + 受管网关 + Computer Use 完成正向一次成功创建和负向一次重复名称拒绝。正向 UI 只有一个成功 activity，完整展示 `pass`/`review` 有序分支；负向显示 `Draft unsaved · nothing was created`、`control logic name already exists`，无 retry。session `/private/tmp/anselm-rig-formal-106/sessions/20260801-232207` 的录屏为 `230.008333s / 2784x1808 / 60fps`，SSE durable `messages 1..29`、`entities 7..8`、`notifications 16..20` 连续，LLM chat completion 全 200，backend 仅预期 duplicate-name WARN，frontend 无运行时红线；fixture/conversation DELETE=204 后 GET=404，台架收台。`TOOL-048=G1/F2/A5/C4/G2` 已落账，中央 clean(290 judgments)，本批 **2 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线 `TOOL-049 edit_control`。

2026-08-01 21:56 (+0800)：`TOOL-045 get_agent_execution` formal-97 真实 App + 受管网关 + Computer Use 完成正向单条 detail 与负向不存在 ID。正向完整显示顶层审计字段、input/output 和两条 transcript；raw REST/LLM wire/UI 一致，off-chat loop block 的空 id/message/seq/status/零值时间由 `messages.Block` 的“落共享 message store 才分配元数据”契约解释，前端 hydration 以 `hblk_*` 兜底，不伪造字段。负向只调用一次并显示 `agent execution not found`，无 retry/其它工具/写操作。session screen.mov `286.645000s / 2784x1808 / 60fps`，SSE durable `notifications 1..3`、`entities 1..4`、`messages 1..28` 连续，LLM 18 个状态 200，backend 仅预期 not-found WARN，frontend 无红线；fixture agent/conversation DELETE=204，台架已收台。`TOOL-045=G1/F2/A5/C4/G2` 已落账，锚点 10/10 通过，警报复审并 ack 后中央 clean(275 judgments)。Goal API 与盘上协议均为 `active`；第五批 **45 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-046 search_control`。

2026-08-01 21:40 (+0800)：`TOOL-044 search_agent_executions` 的 formal-95 两轮红证据已保留：首轮 Computer Use 输入污染造成越界生命周期操作；clean retry 暴露列表携带完整 transcript、模型改写 opaque cursor 导致分页重叠。前线修复为列表裁剪 transcript、工具/schema 强化 cursor byte-for-byte 契约，并补 store/tool 回归测试与同步文档。formal-96 真实 App + 受管网关 + Computer Use 完成正向 2+1 无重叠分页和负向 `status=failed` 空结果，五通道一致：screen.mov `414.928333s / 2784x1808 / 60fps`，SSE durable `notifications 1..5`、`entities 1..12`、`messages 1..49` 连续，LLM 28 个状态响应全 200，frontend 无红线，backend 无 WARN/ERROR/PANIC/FATAL；fixture agent/conversation DELETE=204，台架已收台。`TOOL-044=G1/F2/A5/C4/G2` 已落账，锚点 10/10 通过，警报复审并 ack 后中央 clean(270 judgments)。Goal API 与盘上协议均为 `active`；第五批 **40 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-045 get_agent_execution`。

2026-08-01 21:13 (+0800)：`TOOL-043 invoke_agent` 已完成红证据冻结、修复、新二进制真实复验和五级裁决。formal-93 暴露执行失败误用实体编辑 draft/version 丝带；已新增 `AnHonesty.failedRun`，按 create/edit/run 分流并同步双语文案、W4 守卫测试和 frontend 文档，定向测试 13/13 通过。formal-94 真实 App + 受管网关 + Computer Use 完成正向 `search_agent → invoke_agent` 和负向不存在 ID 单次 invoke：结构化结果 answer=4、confidence=1；负向准确显示 `agent not found`，无 executionId、无 retry、无其它写操作，Activity 显示 `Run failed · inspect the error below`。session screen.mov `236.766667s / 2784x1808 / 60fps`，三路 durable `messages 1..39`、`entities 1..4`、`notifications 1..3`，LLM 20/20 状态 200，backend 仅刻意负路径 WARN，frontend 无红线；REST/SQLite/UI/SSE/LLM wire 一致。agent、conversation 已 DELETE=204→GET=404，成功 execution 保留，台架已收台无残留进程。`TOOL-043=G1/F2/A5/C4/G2` 已落账；锚点 10/10 通过，警报复审并 ack 后中央账本 clean(265 judgments)。Goal API 与盘上协议均为 `active`；第五批 **35 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-044 search_agent_executions`。

2026-08-01 20:49 (+0800)：`TOOL-042 update_agent_meta` 已完成前线冻结、修复和新二进制复验。formal-91 的乐观 user bubble/durable prelude 瞬态重叠保留为红证据；修复 `ConversationTranscript.applyFrame` 的 REST hydration/prelude 跨层幂等，并补 model 回归测试后，定向 Flutter 48 项测试全绿。formal-92 真实 App + 受管网关 + Computer Use 正向只执行一次精确元数据更新，负向不存在 ID 只执行一次并显示 `agent not found`，逐帧无重复气泡、无 retry；session screen.mov `415.496667s`，三路 durable `messages 1..47`、`entities 1..4`、`notifications 1..7`，LLM 24/24 状态 200，backend 仅预期负路径 WARN，frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception 红线，REST/SQLite/LLM wire 一致。所有 fixture DELETE=204→GET=404，execution 历史保留，进程已清零。五级裁决 `G1/F2/A5/C4/G2` 已由 `judge.py` 落账；中央账本 260 条，锚点通过，gap-too-fast/discovery-collapse 经本 session 复审并 ack 后 `alarms.py check` clean。Goal API 与盘上协议均为 `active`。第五批推进至 **30 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-043`。

2026-08-01 19:22 (+0800)：`TOOL-039 edit_agent` 已完成五级裁决 `G1/F2/A5/C4/G2`。formal-85 先修正并锁定工具/文档契约：LLM `edit_agent` 是 partial merge，HTTP `:edit` 才是 full snapshot；定向 agent/tool 测试与 docs verify 通过。真实 onboarding 创建隔离 workspace，再由 REST 构造带 skill、knowledge document、function mount 的 v1；真实 App 正向只改 prompt，UI 显示 v1→v2、version id 和“其它字段已保留”，REST activeVersion、mount-health、三条 equip relation 与 SQLite 只有 v1/v2 一致。负向不存在 ID 只执行一次 edit_agent，显示 `agent not found`、`Draft unsaved · truth is still the last version`，无 retry；逐 body 复原确认后续请求里的历史 tool_calls 是上下文回放，非重复执行。五通道：录屏 `290.713333s / 2784x1808 / 60fps`，LLM 7 request bodies/9 responses 全 200，SSE durable `messages 1..36`、`entities 1..4`、`notifications 1..15` 无 gap，backend 仅预期 not-found WARN，frontend 除 Computer Use 诱发 AXTree bridge 噪声外无 Flutter/Dart/RenderFlex/Unhandled/Exception；formal-84 无 CU 基线已对照确认噪声来源。agent/skill/document/function/conversation 均 DELETE=204→GET=404，关系归零，进程组已收台。警报复审并 ack 后 `clean (245 judgments)`。本批新单格 **19 / 50**，不跑统一长门禁、不提交；下一前线 `TOOL-040 revert_agent`。

2026-08-01 19:10 (+0800)：`TOOL-038 create_agent` 已完成五级裁决 `G1/F2/A5/C4/G2`。formal-81 先发现真实产品缺陷：首轮发送时 scoped SSE 尚未接上，乐观 user bubble 未被 durable 回声收敛，画面出现重复问句；已在普通 send 增加窄 REST head reconcile，并用 retry 参数保持重生成的同 bubble 语义，Flutter 37 项定向测试通过。formal-82 又发现用户明确提供 agent description 时托管模型漏发 `description`，造成创建成功但 REST 元数据为空；已收紧 `create_agent` 工具契约、schema 描述、后端守卫测试和领域文档。formal-83 修复后由真实 App + managed gateway + Computer Use 完成正负路径：正向 exact description/name/prompt 写入 wire、entities、REST 与 UI 一致；负向重复名只执行一次 `create_agent` 并显示可解释失败，无 retry/副作用。formal-84 无 Computer Use 的基线 session 中 frontend 无 Flutter/Dart/RenderFlex/Unhandled 红线；formal-83 动态 AX 查询期间出现的 `AXTree` bridge 行经基线对照归类为观察器诱发噪声，不作为 App 红线。五通道、录屏、终帧、fixture/对话 DELETE=204→GET=404 和 SQLite `deleted_at` 均保留，警报复审并 ack 后 `clean (240 judgments)`。本批新单格 **18 / 50**，不跑统一长门禁、不提交；下一前线 `TOOL-039 edit_agent`。

2026-08-01 18:40 (+0800)：`TOOL-037 get_agent` 已完成五级裁决 `G1/F2/A5/C4/G2`。formal-80 严格正向最终字段表完整，负向不存在 ID 单次失败且无 retry；前置 setup 400、Bash 污染和中途未完成截图均未进入绿证据。五通道、视觉终帧和清理回执保留，警报复审后 `clean (235 judgments)`。本批新单格 **17 / 50**，不跑统一长门禁、不提交；下一前线 `TOOL-038 create_agent`。

2026-08-01 18:30 (+0800)：`TOOL-036 search_agent` 已完成五级裁决 `G1/F2/A5/C4/G2`；共享 `ContentSearch` 影响的旧绿格 `TOOL-014 search_function`、`TOOL-024 search_handler` 已用正式 session `/private/tmp/anselm-rig-formal-20260801-79/sessions/20260801-181753` 复验命中/空 query/identifier no-match 六条路径并恢复五级绿。formal-78/79 的五通道、录屏和终帧均保留；统计警报复审并 ack 后 `clean (230 judgments)`。本批新单格累计 **16 / 50**（旧格复验不重复计数），不跑统一长门禁、不提交；下一前线 `TOOL-037 get_agent`。

2026-08-01 18:16 (+0800)：`TOOL-036 search_agent` 已在正式 session `/private/tmp/anselm-rig-formal-20260801-78/sessions/20260801-181026` 完成真实三路径，但尚未裁决。正向名称命中、空 query 列全库、identifier-shaped `zzqvulon_78` 0 命中均由 UI、LLM wire、三路 SSE、backend/frontend journal 和 SQLite/REST 清理事实交叉验证；录屏 `259.898333s`，五通道摘要与三张终帧已保留。修复触及共享 `ContentSearch`，所以 `search_function`、`search_handler` 等旧搜索绿格先进入待复验，不能直接 judge TOOL-036。本批仍 **15 / 50**，不跑统一长门禁、不提交。

2026-08-01 18:07 (+0800)：固定修复后的 `TOOL-036 search_agent` session `/private/tmp/anselm-rig-formal-20260801-77/sessions/20260801-180355` 已收台，录屏为 `197.091667s`，五通道 journal 和证据保留；fixture `ag_c60a92bcc799a856` 已由真实 DELETE=204、GET=404 和 SQLite `deleted_at` 三重对证，后台进程组无残留。本 session 仍**未裁决**：它包含共享搜索语义原语的修复后正式路径，必须先完成摘要和旧搜索绿格复验范围审查，不能把清理动作当作产品验收。Goal API 仍为不可恢复的 `blocked`，没有创建重复 Goal 或伪造完成；盘上执行协议保持 active。本批仍 **15 / 50**，不跑统一长门禁、不提交，继续 TOOL-036。

2026-08-01 17:58 (+0800)：第五批从 **10 / 50** 推进至 **15 / 50**。`TOOL-035 get_handler_call` 正向在真实 App 中单次读取 `hcl_47cfc89610c56086`，完整显示 method/status/input/output/elapsedMs/logs（含 `trace-call-start`）；负向对不存在 `hcl_0000000000000000` 单次失败，UI 显示 `handler call not found`，无 retry 或其它工具。正式 session `/private/tmp/anselm-rig-formal-20260801-75/sessions/20260801-174951` 的录屏为 `173.071667s`，LLM 16 个响应全 200，三路 SSE durable 序列 `messages 1..28`、`entities 1..4`、`notifications 1..5` 连续，frontend 无红线，backend 仅预期负路径 WARN，SQLite/REST/UI/LLM wire 一致；fixture 与 acceptance 对话已 DELETE=204、GET=404，证据保留。五级裁决 `G1/F2/A5/C4/G2` 已落账，锚点通过，三条警报复审并 ack 后 `clean (215 judgments)`。本批未到 50 格，不跑统一长门禁、不提交；下一前线为 `TOOL-036`。

2026-08-01 17:47 (+0800)：第五批从 **5 / 50** 推进至 **10 / 50**。`TOOL-034 search_handler_calls` 的 session 72 因长提示中的辅助步骤污染、session 73 因托管模型将 `limit` 发成 `"2"` 而触发后端类型错误，均保留为红证据；前线冻结后按既有执行边界先例接受精确十进制字符串，补守卫测试与领域/工具文档。正式五通道 session `/private/tmp/anselm-rig-formal-20260801-74/sessions/20260801-174220` 首次调用即接受 wire 上的 `limit:"2"`，没有红色失败卡或 retry；UI、REST、SQLite、LLM wire、三路 SSE、backend 和 frontend 日志交叉一致，分页回执与全匹配集聚合均可见，抽帧未发现视觉缺陷。fixture 与 acceptance 对话已真实 DELETE，GET 404/`deleted_at` 对证；五级裁决 `G1/F2/A5/C4/G2` 已落账，锚点通过，警报复审并 ack 后 `clean (210 judgments)`。本批未到 50 格，不跑统一长门禁、不提交；下一前线为 `TOOL-035 get_handler_call`。

2026-08-01 17:26 (+0800)：第五批当前完成 **5 / 50**。`TOOL-033 restart_handler` 在正式 session `/private/tmp/anselm-rig-formal-20260801-71/sessions/20260801-172125` 由真实 App 严格执行 `search_handler → call_handler(bump) → restart_handler → call_handler(bump) → get_handler`，两次 count 均为 1，active v1、method、envStatus=ready、runtimeState=running 保持不变；LLM 20 个响应全 200，messages/entities/notifications durable `1..42`、`7..8`、`16..21` 无 gap，backend/frontend 无未解释错误，最终画面含工具序列表与六行断言表。前置 session 70 因 `type_text` 丢失中文约束而越界，保留为 setup-contamination 红证据，未计入裁决；正式 fixture 与对话已真实 DELETE，GET 404/SQLite `deleted_at` 对证。五级裁决 `G1/F2/A5/C4/G2` 已落账；警报复审后 `clean (205 judgments)`。本批未到 50 格，不跑统一长门禁、不提交；下一前线为 `TOOL-034 search_handler_calls`。

2026-08-01 17:06 (+0800)：第四批已完成 **50 / 50**。`TOOL-032 update_handler_meta` 真实验证自然语言找 handler、初次 bump 得 count 1、只改 name/description/tags、版本/env/方法/驻留实例不变，二次 bump 得 count 2；不存在 ID 只执行一次并返回 `handler not found`，未用 edit/restart/retry。session `/private/tmp/anselm-rig-formal-20260801-69/sessions/20260801-161542` 的 screen.mov 为 `298.946667s / 2784x1808 / 60fps`，LLM 21 个响应全 200，messages/entities/notifications durable `1..116`、`7..8`、`16..21` 连续，frontend 无 Flutter 红线，backend 仅一条刻意 not-found WARN；fixture 与 acceptance 对话已 DELETE 并分别 GET 404，抽帧 `evidence/frames/tool-032-220.jpg`、`tool-032-260.jpg`、`tool-032-295.jpg` 逐帧复核无视觉缺陷。统一长门禁发现 workflow agent 的 MediaRef receipt 被 prose 脱敏误伤，已修复为 workflow 数据保留、chat prose 脱敏，并通过 loop 守卫与两个媒体 workflow 定向回归。`make verify`、backend 全量 Go 测试、`make -C backend testend`、testend 全包、锚点、警报、diff、fixture 和进程审计均通过；`alarms.py check` 为 clean(200 judgments)。本批次现在一次性提交，下一前线为 `TOOL-033 restart_handler`。

2026-08-01 16:15 (+0800)：第四批当前完成 **45 / 50**。`TOOL-031 update_handler_config` 的前置 session 54 暴露受管 ASR 握手失败后 Composer 停在 `Finishing 00:00`，已修复 `speech_input_provider.dart` 并通过 5/5 守卫测试；session 67 又暴露旧工具描述让模型把 init config 错送进 `call_handler`，已冻结并修复描述、执行边界、handler 测试和领域/提取文档。干净 session `/private/tmp/anselm-rig-formal-20260801-68/sessions/20260801-160415` 真实完成 `warm→cool→default` 三次配置更新，每次 bootId 变化、prefix 保持；不存在 handler 的负路径只执行一次并返回 `handler not found`，无重试。fixture `hd_c6b5cbdd36c1aa92` 已由真实 DELETE API 删除，GET 404，历史审计证据保留。screen.mov `221.563333s / 2784x1808`，LLM 26/26 状态 200，messages/entities/notifications durable `1..102`、`1..2`、`1..8` 连续，frontend 无 Flutter 红线，backend 只有一条刻意 not-found WARN；最终文本无机器 ID/时间戳，tool card 保留原始真值。五级裁决 `G1/F2/A5/C4/G2` 已落账；锚点复校后两条统计警报已写复审结论并 ack，`alarms.py check` 为 clean(195 judgments)。下一前线为 `TOOL-032 update_handler_meta`。未到第四批 50 格，不跑统一长门禁、不提交。

2026-08-01 14:46 (+0800)：第四批当前完成 **35 / 50**。`TOOL-029 delete_handler` 首轮真实会话发现两个产品/契约问题：工具回执只有 `{id,deleted}`，没有承诺的 retention 真相；失败卡片把不存在 ID 的失败说成过去式“已删除”。前线冻结后修复 `manage.go` 返回结构化 `retention`（handler soft_deleted、versions retained_for_audit、sandbox destroy_requested_best_effort、actions not_found），补 `handler_test.go`、handler domain/tool/COVERAGE 文档，并在中英 locale 和 widget test 中改为 `deleteFailedKind`。最终 session `/private/tmp/anselm-rig-formal-20260801-50/sessions/20260801-143835` 使用新 fixture `hd_ae18f91613773bad`，真实 App 正向只调用一次 delete_handler，UI 展示 retention、五项验证和后续 get_handler not-found；SQLite 证明 deleted_at、v1/v2 保留、环境 0 行、关系 0 行。负路径在同一真实 App 中经过危险调用人闸后只调用一次不存在 ID，卡片显示 `Delete handler failed · failed`，最终报告为 `handler not found` 且无副作用。screen.mov `191.041667s`、`2784x1808`、60fps；LLM 20/20 状态 200；SSE messages/entities/notifications durable `1..51`、`1..4`、`1..12` 连续，500 stream frames、三流各连接一次；frontend 无 Flutter/Dart/RenderFlex/Unhandled/SEVERE，backend 仅三条可解释负路径 WARN。五级裁决 `G1/F2/A5/C4/G2` 已落账；警报两条因同批复核而开，均以正负抽帧、五通道 journal 与数据库证据复审后 ack，`alarms.py check` 为 `clean (185 judgments on record)`。下一前线为 `TOOL-030`。未到第四批 50 格，不跑统一长门禁、不提交。

2026-08-01 13:35 (+0800)：第四批当前完成 **30 / 50**。`TOOL-028 revert_handler` 的 session 42–45 作为红证据保留：前置 edit 依次暴露 `updateMethod`、`kind:set_method`、`set_method_description` 等不规范形状；将 edit 前置与回退切片分离后，session 45 又真实暴露 hosted model 把 `version` 发成字符串。修复 `backend/internal/app/tool/handler/manage.go` 的专用参数边界：公开 schema 仍为 integer，仅接受精确十进制整数串，并以测试拒绝小数、数组、布尔、文字和非正数；同步 handler 领域文档。最终 session `/private/tmp/anselm-rig-formal-20260801-46/sessions/20260801-132558` 由规范 REST fixture 先建立 v2，再由真实 App 单次回退到 v1，另执行一次 version 999 负路径；主路径 active v2→v1、v2 历史保留、env ready、runtime running、resident restarted，负路径精确 `handler version not found` 且无指针/版本/重启副作用。录屏 `258.636667s`、`2784x1808`，LLM 全状态 200，messages/entities/notifications durable `1..91`、`7..8`、`16..21` 连续，frontend 无 Flutter 红线，backend 仅预期拒绝 WARN，SQLite/REST/UI/LLM wire 一致。五级裁决 `G1/F2/A5/C4/G2` 已落账，警报复审后 `clean (180 judgments on record)`。下一前线为 `TOOL-029 delete_handler`。未到第四批 50 格，不跑统一长门禁、不提交。

2026-08-01 13:07 (+0800)：第四批当前完成 **25 / 50**。`TOOL-027 edit_handler` 的前两次真实会话作为红证据保留：托管模型先发 `methodName`，再发 `method` 加顶层字段，均与公开 `{op,name,patch}` 契约不一致；前线冻结后，在执行边界加入仅针对该已知 hosted-model alias 的窄归一化，公开 schema 保持严格，补齐 handler 守卫测试、工具描述和领域文档。修复后的真实窗口绑定会话 `/private/tmp/anselm-rig-formal-20260801-41/sessions/20260801-125948` 覆盖成功路径（精确生成 v2、更新 `place` 描述、env ready、resident 从 stopped 重启为 running）和负路径（不存在 method 被拒绝、无 v3、active 仍为 v2）；screen.mov `160.443333s`、`2784x1808`，LLM 26 个状态全 200，messages/entities/notifications durable `1..57`、`7..8`、`16..22` 连续无 gap，frontend 无 Flutter 红线，backend 仅预期拒绝 WARN，SQLite/UI/LLM wire 一致。五级裁决 `G1/F2/A5/C4/G2` 已落账，警报复审后 `clean (175 judgments on record)`。下一前线为 `TOOL-028 revert_handler`。未到第四批 50 格，不跑统一长门禁、不提交。

2026-08-01 12:43 (+0800)：第四批当前完成 **20 / 50**。`TOOL-026 create_handler` 在真实窗口绑定台架
`/private/tmp/anselm-rig-formal-20260801-38/sessions/20260801-123643` 收尾：首轮发现 hosted model 把
声明为 array 的 `ops` 发成 JSON-encoded array string，冻结并修复 create/edit 共用解码边界、补守卫测试和同步
工具描述；修复后一次成功创建 `acceptance_handler_minimal_probe`（2 ops、v1、env ready），一次缺 method
拒绝（后端原文 + UI `Draft unsaved · nothing was created`），无 create 重试、SQLite 无负向实体。录屏
`256.185000s`、`2784x1808`，LLM challenge/install/models/chat 共 24 个响应全 200，messages durable `1..53`、
entities `7..12`、notifications `16..22` 无 gap，frontend 无 Flutter 红线，backend 仅刻意业务拒绝 WARN；五级
裁决 `G1/F2/A5/C4/G2` 已落账，警报复审后 `clean (170 judgments on record)`。下一前线为 `TOOL-027 edit_handler`。
未到第四批 50 格，不跑统一长门禁、不提交。

2026-08-01 12:05 (+0800)：第四批当前完成 **15 / 50**。`TOOL-025 get_handler` 已由固定真实会话
`/private/tmp/anselm-rig-formal-20260801-32/sessions/20260801-115554` 收尾：正常名称→搜索→ID→详情链返回完整
active version、方法体、configState/runtimeState；显式不存在 ID 只调用一次并显示 `handler not found`，另保留
名称误作 ID 的红反证。screen.mov `302.100000s` 可读，LLM 11 个 chat 请求/响应全 200，messages durable `1..61`、
notifications `16..19` 单调无 gap，entities 保持连接，Flutter console 无异常，backend 仅两条刻意 not-found WARN。
五级裁决 `G1/F2/A5/C4/G2` 均已落账；警报复审后 `alarms.py check` 为 `clean (165 judgments on record)`。
未发现代码或产品缺陷，未改代码；下一前线为 `TOOL-026 create_handler`。未到第四批 50 格，不跑统一长门禁、不提交。

2026-08-01 11:55 (+0800)：第四批当前完成 **10 / 50**。`TOOL-024 search_handler` 已由固定真实会话
`/private/tmp/anselm-rig-formal-20260801-31/sessions/20260801-114544` 收尾：名称命中、空 query 全列出、
随机 no-match 三态均由真实 App + 受管网关完成，工具调用次数、参数和结果与 SQLite/LLM wire 一致；screen.mov
`264.113333s` 可读，LLM 8 个 chat 请求/响应全 200，messages durable `1..48`、notifications `16..17` 单调无 gap，
entities 保持连接，Flutter console 无异常，backend 无 WARN/ERROR。五级裁决 `G1/F2/A5/C4/G2` 均已落账；
警报复审后 `alarms.py check` 为 `clean (160 judgments on record)`。未发现代码或产品缺陷，未改代码；下一前线为
`TOOL-025 get_handler`。未到第四批 50 格，不跑统一长门禁、不提交。

2026-08-01 11:43 (+0800)：第四批当前完成 **5 / 50**。`TOOL-023 get_function_execution` 已由固定真实会话
`/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-113505` 收尾：成功路径取回完整执行记录，
不存在 ID 路径只调用一次并展示明确失败、未重试；screen.mov `159.710000s` 可读，LLM `6` 个请求体与 `7`
个响应体状态均为 200，messages durable `1..28`、notifications `1..4` 单调无 gap，entities 保持连接，
Flutter console 无异常，backend 仅刻意 `function execution not found` WARN。五级裁决 `G1/F2/A5/C4/G2`
均已落账；两次警报复审均完成，`alarms.py check` 为 `clean (155 judgments on record)`。未发现代码或产品缺陷，
未改代码；下一前线为 `TOOL-024 search_handler`。未到第四批 50 格，不跑统一长门禁、不提交。

2026-08-01 11:15 (+0800)：第三批 `50 / 50` 已完成统一长门禁、完整 testend、专项回归、警报/锚点/diff/进程审计并提交 `eb1ee050`。第四批从 `0 / 50` 开始，下一前线为 `TOOL-023 get_function_execution`；继续遵守单作者、真实五通道、逐格 stop-and-fix，未到下一批 50 格不跑统一长门禁、不提交。

2026-08-01 11:09 (+0800)：第三批已完成 **50 / 50**。`TOOL-022 search_function_executions` 首轮真实会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-103528` 暴露托管模型把分页 `limit` 发成字符串，严格 decoder 首次拒绝；按 stop-and-fix 修复 `search_function_executions` 执行边界，公开 schema 仍为 integer，同时兼容精确整数字符串并拒绝小数/数组/非数字字符串。固定会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-103839` 真实覆盖分页、failed/version 筛选、空结果和非法 status，screen.mov `420.495000s` 可读，backend 仅刻意 invalid-status WARN，frontend 仅已知 macOS 噪声，LLM chat-completion 状态响应全 200，messages/notifications durable `1..81`/`1..8` 单调，entities 保持连接；五级证据已落账，警报复审并 ack 后 `clean (150 judgments)`。之后统一长门禁全部通过：`make verify`、backend `go test ./...`、`make -C backend testend`、testend 全包、webhook 崩溃恢复专项、docs lint、anchors、alarms、diff 与进程泄漏审计均为绿。当前只剩最终工作树审计与本批次一次性提交，完成前不进入 `TOOL-023`。

2026-08-01 10:26 (+0800)：第三批当前完成 **45 / 50**。`TOOL-021 run_function` 首轮真实会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-100648` 暴露模型实际把显式版本发成字符串、并在不存在 ID 场景写错零串；第二轮在 schema 已明确 integer 后仍复现字符串化字段。按 stop-and-fix 修复执行边界，公开 schema 保持强类型但兼容精确整数字符串和字符串化对象；固定会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-101832` 真实一次成功执行 v2、一次不存在 ID 拒绝、一次缺参数执行失败，screen.mov `468.141667s`、2880x1800，backend 仅预期 WARN，frontend 仅已知 macOS 噪声，LLM 15 个响应全 200，messages/entities/notifications durable `1..75`、`1..4`、`1..6` 单调；五级证据已落账，警报复审并 ack 后 `clean (145 judgments)`。下一前线为 `TOOL-022 search_function_executions`；第三批未到 50 格，不跑统一长门禁、不提交。

2026-08-01 10:04 (+0800)：第三批当前完成 **40 / 50**。`TOOL-020 update_function_meta` 首轮真实会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-094939` 发现两项需冻结的问题：Computer Use `type_text` 吞掉字面下划线，导致模型把精确名称意图变成连字符；不存在 ID 的负路径中，模型把 `tags` 数组先序列化成字符串后才重试。修复工具描述和参数 schema，明确 JSON 对象示例、`tags` 必须为字符串数组且禁止逗号字符串；同时让 `rig-up` 初始化 `session/evidence/`，避免证据目录被首次截图转换误写成普通文件。修复后二进制会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-095616` 真实覆盖精确下划线 meta 更新和只传 name 的不存在 ID 拒绝：只一次 meta 调用、v1/代码/active version/env 不变、无 restart；错误路径干净 `function not found` 且无副作用。screen.mov `268.930000s`、2880x1800；backend 一条预期 WARN，LLM 24 个响应全 200，messages/notifications durable `1..73`/`1..5` 单调，entities 连接正常，frontend 仅已知 macOS 噪声。五级证据已落账，警报复审并 ack 后 `clean (140 judgments)`；下一前线为 `TOOL-021`。第三批尚未到 50 格，不跑统一长门禁、不提交。

2026-08-01 09:42 (+0800)：第三批当前完成 **35 / 50**。`TOOL-019 delete_function` 首轮真实会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-092832` 暴露了工具描述与持久化设计的契约冲突：主行是软删、不可变版本历史按设计保留，但旧报告错误声称“全版本删除”；该会话只作为反证保留，未判绿。修复 `backend/internal/app/tool/function/lifecycle.go` 的描述与返回结构、补工具测试并同步 API 文档后，在 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-093503` 由真实 App + 受管网关重跑：主行软删、版本审计保留、sandbox 回收、后续动作 not-found；成功与不存在 ID 失败路径均无错误副作用。修复会话 screen.mov 为 `466.838333s`、2880x1800；backend 两条预期 WARN（fixture 一次错误 ops 重试、一次刻意 not-found），LLM 22 个响应全 200，messages/entities/notifications durable 分别 `1..64`、`1..4`、`1..9` 单调，frontend 仅已知 macOS 平台噪声；SQLite 与 HTTP 交叉核对一致。五级证据已落账，五次警报均基于本次正负画面、录屏、五通道 journal、SQLite/HTTP 结果复审并 ack，最终 `clean (135 judgments)`。提取物与 COVERAGE 摘要已同步为 retention truth；下一前线为 `TOOL-020 update_function_meta`。第三批尚未到 50 格，不跑统一长门禁、不提交。

2026-08-01 09:25 (+0800)：第三批当前完成 **30 / 50**。`TOOL-018 revert_function` 真实覆盖既有 function 从 v2 回退到 v1 的成功路径，以及不存在 v999 的失败路径。成功路径证明 active pointer 从 v2→v1、无新版本、v2 仍在历史且环境 ready；失败路径两次业务拒绝均为 `function version not found`，随后真实 `get_function` 核验 active 仍为 v1，SQLite 无 v3、无指针副作用。会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-091433` 的 screen.mov 为 `490.781667s`、2880x1800；messages durable `1..86`、notifications `1..5` 单调无 gap/regression，entities 保持连接，LLM 2 个 challenge 与 26 个 chat 响应全 200，frontend 仅已知 macOS IMK 噪声，backend 仅两条刻意失败 WARN。五级证据已落账，五次警报均用该 session 复审并 ack，最终 `clean (130 judgments)`。第三批尚未到 50 格，不跑统一长门禁、不提交；下一前线为 `TOOL-019 delete_function`。

2026-08-01 09:12 (+0800)：第三批当前完成 **25 / 50**。`TOOL-017 edit_function` 真实覆盖 v1→v2 成功版本、代码 diff、env ready 与非法代码拒绝；模型为确认失败后真相额外调用了只读 `get_function`，日志如实保留，未发生其他写操作。最终会话
`/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-090605` 的 SQLite 只有 v1/v2 且 active 指向 v2，无 v3；screen.mov `206.015000s`，三路 durable seq 分别 `1..67`、`1..6`、`1..7` 单调唯一，LLM 20 个状态响应全 200，frontend 仅已知 macOS 平台噪声；五级证据已落账，警报复审后 `clean (125 judgments)`。第三批尚未到 50 格，不跑统一长门禁、不提交；下一前线为 `TOOL-018 revert_function`。

2026-08-01 09:01 (+0800)：第三批当前完成 **20 / 50**。`TOOL-016 create_function` 首轮真实新建失败路径发现 create 误用 edit 专属“上一版”诚实丝带；前线冻结后新增 `failedCreate` 双语文案、按 `create_*` 分流并补 create/edit 对称 widget 回归。最终会话
`/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-085503` 真实覆盖五操作成功创建与缺 `set_code` 的后端校验失败；SQLite 证明失败名无实体副作用，screen.mov `188.273333s`，三路 durable seq 分别 `1..51`、`1..6`、`1..7` 单调唯一，LLM 18 个状态响应全 200，frontend 仅已知 macOS 平台噪声；五级证据已落账，警报复审后 `clean (120 judgments)`。第三批尚未到 50 格，不跑统一长门禁、不提交；下一前线为 `TOOL-017 edit_function`。

2026-08-01 08:52 (+0800)：用户重新启用 Goal/Loop。已核对盘上只有一个 `active` Goal，未创建副本、未启用并行 agent；现有真实台架仍在运行，未另起第二套。执行协议恢复为单作者、单切片、五通道、发现即停修、每 50 个 COVERAGE 单格统一门禁并提交；当前批次仍为 **15 / 50**，不提前跑长门禁、不提交，接管前线 `TOOL-016 create_function`。

2026-08-01 08:44 (+0800)：第三批当前完成 **15 / 50**。`TOOL-015 get_function` 首轮真实 not-found 路径发现用户错误卡片泄漏
`functionapp.Get:` 内部 Go 路径；前线冻结后修复 `executeTool` 的用户错误出口并补回归测试，最终会话
`/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-083704` 重新覆盖完整活跃版本、环境 ready、
不存在 ID 的 clean error。录屏 `189.096667s`，三路 SSE 均连接，messages durable `1..43`、notifications `1..4` 单调，
entities 连接正常，LLM 18 个状态响应全 200，frontend 仅已知 macOS 平台噪声；首轮缺陷会话不用于判绿。
修复后的五级证据已落账，警报复审后 `clean (115 judgments)`。第三批尚未到 50 格，不跑统一长门禁、不提交；下一前线为
`TOOL-016 create_function`。

2026-08-01 08:22 (+0800)：第三批当前完成 **10 / 50**。`TOOL-014 search_function` 在全新 workspace 中先构造
ready 的 `acceptance_search_probe` fixture，再以真实 App/gateway 覆盖 acceptance 命中、空 query、`FIXTURE`
大写 tag 命中和 zzznonexistent no-match；完整录屏 `506.090000s`，backend 无异常，frontend 仅已知 macOS 平台
噪声，LLM chat 48 个响应全 200，三路 SSE durable seq 单调。首轮 Computer Use 草稿拼接被排除，干净对话重新
执行；五级证据已落账，警报复审后 `clean (110 judgments)`。第三批尚未到 50 格，不跑统一长门禁、不提交；下一前线为
`TOOL-015 get_function`。

2026-08-01 08:10 (+0800)：第三批当前完成 **5 / 50**。`TOOL-013 search_tools` 首轮真实 App/gateway 会话发现
`loaded_tools` 命中回执与前端旧 schema 不匹配、以及 transcript pending lazy builder 竞态；已停下修复，补齐
前端兼容、不可变快照和回归测试。第二次全新真实会话 `/private/tmp/anselm-rig-formal-20260801-29/sessions/20260801-080221`
覆盖命中与无命中路径，`rig-check` 五通道全绿，screen.mov `155.068333s`，backend 无未解释错误，LLM 14 个响应全 200，
messages durable seq `1..36`、notifications durable seq `1..2` 单调；`judge.py` 五格已落账，警报复审后
`clean (105 judgments)`。第三批尚未到 50 格，不跑统一长门禁、不提交；下一前线为 `TOOL-014 search_function`。

2026-08-01 07:48 (+0800)：第二批已完成 `50 / 50`。统一长门禁全部通过：正确台架 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 的 `alarms.py check` 为 `clean (100 judgments on record)`，锚点 10 题复核通过，`make verify`、完整 `testend` 模块测试、完整场景组和已修 webhook 崩溃恢复回归均为绿。下一前线为 `TOOL-013 search_tools`，提交本批次后继续逐格运行。

2026-08-01 07:17 (+0800)：用户暂停后重新启用 Goal/Loop。盘上唯一持久 Goal 仍为 `active`，未创建副本；本轮继续由单一作者执行，不启用并行 agent。执行计划已恢复为：第二批 `50 / 50` 的统一长门禁 → 全部通过后一次性提交 → 从 `TOOL-013 search_tools` 继续；门禁未全绿前不提交、不推进下一格。

2026-08-01 06:50 (+0800)：Goal/Loop 已恢复并完成真实续跑；已核对 Codex Goal 仍为唯一 `active` 实例，未创建副本；未启用任何并行 agent。`TOOL-004 LS`、`TOOL-005 Glob`、`TOOL-006 Grep`、`TOOL-007 Bash`、`TOOL-008 BashOutput`、`TOOL-009 KillShell`、`TOOL-010 ask_user`、`TOOL-011 todo_write` 与 `TOOL-012 todo_read` 台架均已按协议收台并完成五级裁决，证据保留；第二批已到 `50 / 50`，统一长门禁正在执行，下一前线为 `TOOL-013 search_tools`。

最新续跑事实：`TOOL-011 todo_write` 与 `TOOL-012 todo_read` 共用真实台架 `/tmp/anselm-rig-formal-20260801-28/sessions/20260801-064406`，覆盖部分清单读回、全部完成、零开放项后的真实 readback 与提醒抑制；五通道收台无未解释错误，警报复审后 `clean (100 judgments)`。第二批已到 `50 / 50`，现在执行统一长门禁，门禁通过前不提交。

2026-08-01：持久 Goal 已确认仍为 `active`（未创建副本）；Loop 协议已幂等重新装载；50 格批次策略保持不变。首批已计数
`50 / 50` 并提交 `b26f623e`；第二批当前计数为 `50 / 50`，已完成真实 `TOOL-003 Edit`、`TOOL-004 LS`、`TOOL-005 Glob`、`TOOL-006 Grep`、`TOOL-007 Bash`、`TOOL-008 BashOutput`、`TOOL-009 KillShell`、`TOOL-010 ask_user`、`TOOL-011 todo_write` 与 `TOOL-012 todo_read` 五级独立裁决；统一长门禁、完整 testend、已修场景回归、工作树审计和提交待执行。此前真实 onboarding→聊天→composer→场次条→日志抽屉→Read→Write 工具切片中 `EDGE-325`、`EDGE-326`、`SURF-003`、
`SURF-010`、`SURF-011`、`SURF-012`、`SURF-013`、`SURF-014`、`TOOL-001`、`TOOL-002` 的五级独立裁决。`SURF-012` 曾发现菜单打开命名模态后焦点被
退场菜单覆盖，已在共享 `AnPopover`/`AnMenu` 生命周期修复并由真实 App 复验；本批次长门禁又发现菜单命令等待动画 Future 导致 widget 行为延迟、以及窄 Gantt 行的 RenderFlex 溢出，均已修复并由完整 `make verify` 复验；随后完成流式输入、附件预览与读取、
实体 mention 候选/药丸/上下文注入、工作目录、git 分支与工作目录聊天连续性。完整 testend、根级 `go test ./...` 和警报复核也已通过；`SURF-013` 真实构造 51 个用户回合，
证明场次条第一页 50 条、第二页 2 条，场次条同时可见最新与最早锚点；turn 001 与 turn 027 深跳、`Jump to present`
回到现场均已逐帧复验。`SURF-014` 首轮发现长失败日志摘要失焦且伴随 AXTree 红行，已冻结并修复；修复后真实会话
`/tmp/anselm-rig-formal-20260801-8/sessions/20260801-030652` 复验成功/失败函数、MCP dossier、stderr 抽屉和 Copy→Copied，
前端、后端、LLM tap 与三路 SSE 均通过五通道检查。随后 `TOOL-001 Read` 真实覆盖整读、分页、缺失文件和越界保护，
`/tmp/anselm-rig-formal-20260801-9/sessions/20260801-032022` 五通道无红线。`TOOL-002 Write` 会话
`/tmp/anselm-rig-formal-20260801-12/sessions/20260801-033935` 首轮冻结了 completed 拒绝结果仍显示成功动词的真实缺陷；修复后
`Write failed existing.txt · read first` 与磁盘未改、SSE 仅 Write 无 Read、五通道无红线均已复验。`TOOL-003 Edit` 会话
`/tmp/anselm-rig-formal-20260801-14/sessions/20260801-044210` 完成 Read→Edit→Read 精确替换和无匹配只读拒绝；五通道、磁盘真相和两张关键画面均已复核。`TOOL-004 LS` 会话 `/tmp/anselm-rig-formal-20260801-17/sessions/20260801-050302` 真实覆盖直接列举、隐藏文件、空目录、嵌套非递归、缺失路径和非目录错误；首轮发现失败结果仍显示成功动词，修复 `lsResultFailed`/`listFailed` 后真实错误卡片显示 `List failed … · failed` 并自动展开正文，messages durable seq 1..40 单调，LLM 18 个响应全 200，录像 `213.276667s` 可读，`TOOL-005 Glob` 会话 `/tmp/anselm-rig-formal-20260801-19/sessions/20260801-051557` 首轮发现递归噪声目录契约未被模型理解，冻结后补齐后端 description/schema、前端失败重分类与守卫测试；修复后真实复验成功、空结果、截断、缺失根和非目录边界，screen.mov 可读，backend/frontend 无未解释错误，LLM 20 个响应全 200，三路 SSE 均连接且 messages durable seq 单调。`TOOL-006 Grep` 会话 `/tmp/anselm-rig-formal-20260801-22/sessions/20260801-054044` 首轮发现噪声目录泄漏、语义计数错误、错误态误报和非法正则 WARN，修复后真实覆盖 content/files/count/multiline/truncation/no-match/invalid-regex/missing-root，录屏 `269.225000s` 可读，backend 无 WARN/ERROR/panic/fatal，LLM 28 个响应全 200，messages durable seq 1..70、notifications durable seq 1..2 连续，三流均连接。`TOOL-008 BashOutput` 会话 `/tmp/anselm-rig-formal-20260801-24/sessions/20260801-060449` 又真实覆盖增量读取、regex 过滤、无新输出、缺失 bash_id 与非法 regex，录屏 `548.728333s` 可读，LLM 36 个响应全 200；`TOOL-009 KillShell` 会话 `/tmp/anselm-rig-formal-20260801-26/sessions/20260801-062334` 首轮发现重复终止语义冲突并完成共享卡片修复后重跑，LLM 32 个响应全 200、messages durable seq 1..76、notifications durable seq 1..2 连续；`TOOL-010 ask_user` 会话 `/tmp/anselm-rig-formal-20260801-27/sessions/20260801-063212` 真实覆盖等待态、选项回答和 `Don't answer` 跳过态，LLM 16 个响应全 200、messages durable seq 1..28、notifications durable seq 1..2 连续；`TOOL-011 todo_write` 与 `TOOL-012 todo_read` 会话 `/tmp/anselm-rig-formal-20260801-28/sessions/20260801-064406` 真实覆盖部分清单读回、全部完成与零开放项提醒抑制，LLM 26 个响应全 200、messages durable seq 1..64、notifications durable seq 1..2 连续；第二批十格工具切片的统计警报均经证据复审后销账，最终 `alarms.py check` 为 clean(100 judgments)。第二批达到 `50 / 50`，统一长门禁进行中，下一前线为 `TOOL-013 search_tools`。
## 2026-08-13 09:46 · EP-221–EP-224 朗读缓存缺陷 stop-and-fix 后真实复验

当前前线仍以 `README.md §5.2` 的整体重述为准：上一轮 EP-221–EP-224 真实朗读候选没有直接入账，
因为 SQLite 取证发现 `speech_cache.last_used_at` 的旧路径和新写入均为 Go 零时间，破坏 LRU；前线
在正式裁决前停下。现已在 `Put` 显式写当前时间，并在 bootstrap migration 后幂等把旧零值回填为各行
`created_at`，测试与 attachment/database 文档同步。

用真实旧数据目录重启新 binary 后，4 条历史缓存全部非零，已有真实命中时间保持，新朗读行也非零；
真实 App 新会话完成唯一文本聊天，未命中朗读准备态和完成态同槽收敛，第二次命中没有重复 TTS。
五通道 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-093429`：backend
无 WARN/ERROR/panic，三路 SSE target durable seq 无缺口，真实网关 proof/chat/TTS 全 200，前端仅有已知
launcher foreground warning，无 Dart/Flutter/RenderFlex/overflow/Unhandled 红线；`rig-check` 前后通过、
`rig-down` 正常，录屏和完整日志保留。

候选证据：`sessions/20260813-093429/evidence/EP-221-224-readaloud-capabilities-repair-r1.md`。
本轮不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；账本仍 `1790`，清册仍
`848 / 351 / 0`，批次三十四仍 `27/50`。EP-220 当前对象删除未执行。
