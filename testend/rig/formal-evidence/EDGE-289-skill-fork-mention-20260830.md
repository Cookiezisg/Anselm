# EDGE-289 · @ 一个 fork skill

## L1 focused evidence

- `backend/internal/app/skill/files_test.go:TestPreauthorizeActiveSkill_InlineGrantsForkSkips` 普通与 `-race` 通过：inline skill 会设置 active skill 并预授权，fork skill 不会设置父回合 active/pre-authorization。
- `frontend/test/app/entity_mention_source_test.dart` 的 `@ candidates exclude fork skills while retaining inline skills` 通过：候选集合保留 `inline-one`，不包含 `fork-one`。
- `frontend/test/app/entity_mention_source_test.dart` 全文件 5/5 通过；前端过滤位于生产 `EntityMentionSource._skillCandidates`，不是仅 fixture 规则。

## 判定

L1=`G1`：`@` 入口只暴露 inline skill，fork skill 保持 subagent/`activate_skill` 语义，避免把两种执行模型混成一个用户入口。L2-L5 不以单测替代真实 App：候选排序、输入反馈、视觉 craft、文案和发现性仍由人工队列在真实五通道台架上收口。

## Reproduction

```text
cd backend && go test ./internal/app/skill -run 'TestPreauthorizeActiveSkill_InlineGrantsForkSkips' -count=1
cd backend && go test -race ./internal/app/skill -run 'TestPreauthorizeActiveSkill_InlineGrantsForkSkips' -count=1
cd frontend && mise exec -- flutter test test/app/entity_mention_source_test.dart
```
