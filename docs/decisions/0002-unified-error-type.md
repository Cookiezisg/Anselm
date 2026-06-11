---
id: DOC-003
type: decision
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-11
review-due: 2099-12-31
audience: [human, ai]
---

# 0002 — 统一错误类型到 pkg/errors，所有 sentinel 一种造法

## 背景

错误构造原本**按出口分情况**：会冒泡到 HTTP 的 domain 错误用 `errorsdomain.New`（`domain/errors`，带 Kind + wire code）；LLM tool 错误（todo/shell/web/filesystem/search/toolset）+ pkg/infra 原语用标准库 `errors.New`（裸字符串）。

问题：① **"是否冒泡 HTTP"是个每处都要做的判断**——错了就把错误降级成不透明 500（todo 为此写了 9 行注释 justify、评审时也曾误判）；② **脆弱**——一个 tool 错误今天不冒 HTTP、明天加个写端点就漏成 500；③ 错误类型放在 `domain/errors`，**pkg 物理上无法 import 它**（反向依赖），逼出"pkg/infra 只能用 std"的例外。一条要靠长注释 justify、反复让人踩坑的规则，本身就是冗余。

## 决策

**把错误类型移到地基 `pkg/errors`，所有命名 sentinel 一种造法。**

1. **类型下沉**：`Error`/`Kind`/`New`/`Is`/`WithCause`/`WithDetails` 从 `domain/errors` 移到 `pkg/errors`。它是**纯机制**（Kind = HTTP 类别、Code = 字符串、零业务），本就属地基；下沉后 **pkg/infra/domain/app 全层可 import、无反向依赖**。导入别名 `errorsdomain` → `errorspkg`。
2. **一种造法**：所有**命名 sentinel** 一律 `errorspkg.New(kind, code, msg)`——**无"是否冒泡 HTTP"之分**。同一错误两种出口：HTTP 读 Kind/Code 走 N1 Envelope；LLM tool 读 Message（该路径不用 Kind/Code，但未来若冒到 HTTP 即正确映射）。
3. **泛型原语带兜底码、domain 翻译保特异性**：`orm.ErrNotFound` 带 `ORM_NOT_FOUND`(KindNotFound) 作兜底，但 domain 仍 `errors.Is` 后翻成具体的 `FUNCTION_NOT_FOUND`（前端更有用）。类型全层可用 ≠ 人人带终态码。
4. **边界**：规则只管**命名 sentinel**。`fmt.Errorf("…: %w", err)` 包裹照常（保留 `errorspkg.Error` 链供 `errors.Is/As`）；`errors.Is`/`errors.As` 用标准库。

## 取舍

**为何不选：**
- **保留按出口分情况**（旧 S20）：判断成本 + 脆弱 + 要长注释 justify——正是该消灭的冗余。
- **只转 tool 22 个、类型留在 `domain/errors`**：治标。类型仍错置在 domain（它是机制非业务），pkg/infra 仍被反向依赖挡住、无法统一。
- **内联 validation 也盲配一次性码**：放弃。~22 处内联 `errors.New("x required")` 是 tool 层重复样板，且部分与已有 sentinel 重复（`shell/kill.go` 的 "bash_id is required" ≈ `ErrEmptyBashID`）——盲转会焊死冗余。归 tool 模块评审做去重 + 共享 helper（findings F-3）。

## 后果

- 错误类型在 `pkg/errors`；**全库无 std-errors 命名 sentinel**（37 个 tool+pkg+infra sentinel 全转 `errorspkg.New`）。
- `errors.Is` 按 **Code** 匹配——类型搬迁 + 转换后**全量测试绿、行为零变**。
- `S20` 重述为"全量统一"；`STD-1` 同步。
- 跨平台/分层更干净：地基（orm/reqctx/fspath…）的原语现都是结构化错误，未冒泡也带正确 Kind。
- **未尽**：~22 处内联 validation（findings F-3）随各 tool 模块评审去重统一——非本 ADR 范围。
