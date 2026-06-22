---
id: DOC-046
type: reference
status: active
owner: @weilin
created: 2026-06-22
reviewed: 2026-06-22
review-due: 2026-09-22
audience: [human, ai]
---

# 前端契约层 —— 后端的 Dart 投影

> `core/contract/` 是后端契约的逐字镜像。改后端字段 → **同提交**改这里的 DTO + 本篇(doc-sync 铁律延伸到前端,CLAUDE.md / GOVERNANCE §12)。事实源 = `references/backend/{api,database,error-codes,events}.md`。

## 1. DTO

所有实体 DTO 住 `core/contract/`(客户端无 domain 层,见 [architecture](architecture.md))。每个 = **freezed + json_serializable**,**camelCase 线缆 ↔ json,无重命名表**(后端 N3 已 camelCase)。范式见 `core/contract/workspace.dart`(`Workspace` + `ModelRef`,镜像后端 `workspace.Workspace`/`model.ModelRef`)。

## 2. 网络一次编码(`core/net/api_client.dart`)

- 成功 `{data: …}` → `EnvelopeInterceptor` 拆成裸实体;失败 `{error:{code,message,details}}` → typed `ApiException`(`core/contract/api_error.dart`)。
- 列表 `{data:[…], nextCursor, hasMore}` → `Page<T>`(`core/contract/page.dart`)。
- 202 异步动作 → `postForId(path) → data.id`;`:run/:call/:invoke` → 裸结果;204 → no-content。

## 3. 封闭集只 seal 真封闭的(ADR 0004 §5)

`@freezed`/`enum` **仅对真封闭集**:4 frame 动词 / 6 block 型 / 5 图节点 kind / 4 trigger 源 / model 场景。**协议级 SSE `node.type` 与 ~261 错误码保持开放 `String` + `unknown` 兜底**(producer 定义、非穷举)——只对命名 UI 分支的少数错误码生成 enum 分支。

## 4. codegen

`cd frontend && make gen` = build_runner(freezed/json)+ `dart run slang`(i18n)。产物(`*.freezed.dart`/`*.g.dart`/`strings*.g.dart`)入库(deterministic)。
