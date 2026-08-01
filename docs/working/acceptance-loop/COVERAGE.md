---
id: WRK-089
type: working
status: active
owner: "@weilin"
created: 2026-07-28
reviewed: 2026-07-28
review-due: 2026-10-26
audience: [human, ai]
landed-into:
---

# WRK-089 · 验收清册(COVERAGE)——面矩阵账本

> **本文件由 `testend/rig/gen_coverage.py` 生成/刷新,手改只动「五级」「证据」两列**(其余列
> 重生成时以原始提取物为准)。行键=项名;重提取后重生成:已判列逐字携带、新行未判、消失行进墓碑。
> 原始提取物(含完整配方与语义)在 `testend/rig/extracts/*.md`,判前先查原文。
>
> **五级列**(WRK-087 §0 判据金字塔,每格一符):①办成 ②真(五通道互证) ③顺(丝滑) ④美(craft)
> ⑤可发现。符号:`·`=未判 `✓`=过 `✗`=开缺陷(修复中,格上留 ✗ 直到真机复验) `~`=不适用
> (须在证据列注明为何)。**一行全列非 `·`/`✗` 才算这行完**;裁决必须援引 CODEX 法条或测量值,
> 证据列写指针。


## 工具全集(124)

| ID | 项 | 摘要 | 五级 | 证据 |
|---|---|---|---|---|
| TOOL-001 | Read | filesystem · 读文件,cat -n 格式,默认前 2000 行,offset+limit 分页 | ✓✓✓✓✓ | L1:G1→/tmp/anselm-rig-formal-20260801-9/evidence/tool-001-read-session-summary.txt; L2:F2→/tmp/anselm-rig-formal-20260801-9/evidence/tool-001-read-session-summary.txt; L3:A5→/tmp/anselm-rig-formal-20260801-9/evidence/tool-001-read-session-summary.txt; L4:C4→/tmp/anselm-rig-formal-20260801-9/evidence/read-tool-final.png; L5:G2→/tmp/anselm-rig-formal-20260801-9/evidence/read-tool-final.png |
| TOOL-002 | Write | filesystem · 原子写文件(覆盖需本对话先 Read 过),父目录须存在 | ✓✓✓✓✓ | L1:G1→/tmp/anselm-rig-formal-20260801-12/evidence/tool-002-write-session-summary.txt; L3:A5→/tmp/anselm-rig-formal-20260801-12/evidence/tool-002-write-session-summary.txt; L4:C4→/tmp/anselm-rig-formal-20260801-12/evidence/tool-002-write-session-summary.txt; L5:G2→/tmp/anselm-rig-formal-20260801-12/evidence/tool-002-write-session-summary.txt; L2:F2→/tmp/anselm-rig-formal-20260801-12/evidence/tool-002-write-session-summary.txt |
| TOOL-003 | Edit | filesystem · 文件内精确字面串替换(非正则),须先 Read | ✓✓✓✓✓ | L1:G1→/tmp/anselm-rig-formal-20260801-14/sessions/20260801-044210/evidence/tool-003-edit-session-summary.txt; L2:F2→/tmp/anselm-rig-formal-20260801-14/sessions/20260801-044210/evidence/tool-003-edit-session-summary.txt; L3:A5→/tmp/anselm-rig-formal-20260801-14/sessions/20260801-044210/evidence/tool-003-edit-session-summary.txt; L4:C4→/tmp/anselm-rig-formal-20260801-14/sessions/20260801-044210/evidence/edit-tool-final.jpeg; L5:G2→/tmp/anselm-rig-formal-20260801-14/sessions/20260801-044210/evidence/edit-tool-no-match.jpeg |
| TOOL-004 | LS | search · 列目录直接内容(非递归),目录优先 | ✓✓✓✓✓ | L1:G1→/tmp/anselm-rig-formal-20260801-17/sessions/20260801-050302/evidence/tool-004-ls-session-summary.txt; L2:F2→/tmp/anselm-rig-formal-20260801-17/sessions/20260801-050302/evidence/tool-004-ls-session-summary.txt; L3:A5→/tmp/anselm-rig-formal-20260801-17/sessions/20260801-050302/screen.mov; L4:C4→/tmp/anselm-rig-formal-20260801-17/sessions/20260801-050302/evidence/ls-errors.jpeg; L5:G2→/tmp/anselm-rig-formal-20260801-17/sessions/20260801-050302/evidence/ls-success.jpeg |
| TOOL-005 | Glob | search · glob 模式找文件(支持 ** 递归),按 mtime 倒序 | ✓✓✓✓✓ | L1:G1→/tmp/anselm-rig-formal-20260801-19/sessions/20260801-051557/evidence/tool-005-glob-session-summary.txt; L2:F2→/tmp/anselm-rig-formal-20260801-19/sessions/20260801-051557/evidence/tool-005-glob-session-summary.txt; L3:A5→/tmp/anselm-rig-formal-20260801-19/sessions/20260801-051557/screen.mov; L4:C4→/tmp/anselm-rig-formal-20260801-19/sessions/20260801-051557/evidence/glob-boundaries.jpeg; L5:G2→/tmp/anselm-rig-formal-20260801-19/sessions/20260801-051557/evidence/glob-success.jpeg |
| TOOL-006 | Grep | search · ripgrep 正则内容检索,三种输出模式 | ✓✓✓✓✓ | L1:G1→/tmp/anselm-rig-formal-20260801-22/sessions/20260801-054044/evidence/tool-006-grep-session-summary.txt; L2:F2→/tmp/anselm-rig-formal-20260801-22/sessions/20260801-054044/evidence/tool-006-grep-session-summary.txt; L3:A5→/tmp/anselm-rig-formal-20260801-22/sessions/20260801-054044/screen.mov; L4:C4→/tmp/anselm-rig-formal-20260801-22/sessions/20260801-054044/screen.mov; L5:G2→/tmp/anselm-rig-formal-20260801-22/sessions/20260801-054044/evidence/tool-006-grep-session-summary.txt |
| TOOL-007 | Bash | shell · 执行 shell 命令,支持 run_in_background | ✓✓✓✓✓ | L1:G1→/tmp/anselm-rig-formal-20260801-23/sessions/20260801-055042/evidence/tool-007-bash-session-summary.txt; L2:F2→/tmp/anselm-rig-formal-20260801-23/sessions/20260801-055042/evidence/tool-007-bash-session-summary.txt; L3:A5→/tmp/anselm-rig-formal-20260801-23/sessions/20260801-055042/screen.mov; L4:C4→/tmp/anselm-rig-formal-20260801-23/sessions/20260801-055042/evidence/bash-output-cap.jpeg; L5:G2→/tmp/anselm-rig-formal-20260801-23/sessions/20260801-055042/evidence/bash-workdir.jpeg |
| TOOL-008 | BashOutput | shell · 拉取后台 Bash 新增输出+状态 | ✓✓✓✓✓ | L1:G1→/tmp/anselm-rig-formal-20260801-24/sessions/20260801-060449/evidence/tool-008-bashoutput-session-summary.txt; L2:F2→/tmp/anselm-rig-formal-20260801-24/sessions/20260801-060449/evidence/tool-008-bashoutput-session-summary.txt; L3:A5→/tmp/anselm-rig-formal-20260801-24/sessions/20260801-060449/screen.mov; L4:C4→/tmp/anselm-rig-formal-20260801-24/sessions/20260801-060449/evidence/bashoutput-invalid-regex.jpeg; L5:G2→/tmp/anselm-rig-formal-20260801-24/sessions/20260801-060449/evidence/bashoutput-missing.jpeg |
| TOOL-009 | KillShell | shell · 按 bash_id 终止后台 Bash(幂等) | ✓✓✓✓✓ | L1:G1→/tmp/anselm-rig-formal-20260801-26/sessions/20260801-062334/evidence/tool-009-killshell-session-summary.txt; L2:F2→/tmp/anselm-rig-formal-20260801-26/sessions/20260801-062334/evidence/tool-009-killshell-session-summary.txt; L3:A5→/tmp/anselm-rig-formal-20260801-26/sessions/20260801-062334/screen.mov; L4:C4→/tmp/anselm-rig-formal-20260801-26/sessions/20260801-062334/evidence/killshell-already-stopped.jpeg; L5:G2→/tmp/anselm-rig-formal-20260801-26/sessions/20260801-062334/evidence/killshell-terminated.jpeg |
| TOOL-010 | ask_user | ask · 向用户提问并阻塞等待(humanloop broker) | ✓✓✓✓✓ | L1:G1→/tmp/anselm-rig-formal-20260801-27/sessions/20260801-063212/evidence/tool-010-ask-user-session-summary.txt; L2:F2→/tmp/anselm-rig-formal-20260801-27/sessions/20260801-063212/evidence/tool-010-ask-user-session-summary.txt; L3:A5→/tmp/anselm-rig-formal-20260801-27/sessions/20260801-063212/screen.mov; L4:C4→/tmp/anselm-rig-formal-20260801-27/sessions/20260801-063212/evidence/askuser-pending.jpeg; L5:G2→/tmp/anselm-rig-formal-20260801-27/sessions/20260801-063212/evidence/askuser-skipped.jpeg |
| TOOL-011 | todo_write | todo · 整体覆盖写本对话任务清单 | ✓✓✓✓✓ | L1:G1→/tmp/anselm-rig-formal-20260801-28/sessions/20260801-064406/evidence/tool-011-todo-write-session-summary.txt; L2:F2→/tmp/anselm-rig-formal-20260801-28/sessions/20260801-064406/evidence/tool-011-todo-write-session-summary.txt; L3:A5→/tmp/anselm-rig-formal-20260801-28/sessions/20260801-064406/screen.mov; L4:C4→/tmp/anselm-rig-formal-20260801-28/sessions/20260801-064406/evidence/todo-completed.jpeg; L5:G2→/tmp/anselm-rig-formal-20260801-28/sessions/20260801-064406/evidence/todo-completed.jpeg |
| TOOL-012 | todo_read | todo · 读回当前任务清单含已完成项 | ✓✓✓✓✓ | L1:G1→/tmp/anselm-rig-formal-20260801-28/sessions/20260801-064406/evidence/tool-012-todo-read-session-summary.txt; L2:F2→/tmp/anselm-rig-formal-20260801-28/sessions/20260801-064406/evidence/tool-012-todo-read-session-summary.txt; L3:A5→/tmp/anselm-rig-formal-20260801-28/sessions/20260801-064406/screen.mov; L4:C4→/tmp/anselm-rig-formal-20260801-28/sessions/20260801-064406/evidence/todo-completed.jpeg; L5:G2→/tmp/anselm-rig-formal-20260801-28/sessions/20260801-064406/evidence/todo-completed.jpeg |
| TOOL-013 | search_tools | toolset · 按能力检索并激活 lazy 工具 | ✓✓✓✓✓ | L1:G1→/private/tmp/anselm-rig-formal-20260801-29/sessions/20260801-080221/evidence/tool-013-search-tools-session-summary.txt; L2:F2→/private/tmp/anselm-rig-formal-20260801-29/sessions/20260801-080221/evidence/tool-013-search-tools-session-summary.txt; L3:A5→/private/tmp/anselm-rig-formal-20260801-29/sessions/20260801-080221/evidence/tool-013-search-tools-session-summary.txt; L4:C4→/private/tmp/anselm-rig-formal-20260801-29/sessions/20260801-080221/evidence/search-tools-hit-card.png; L5:G2→/private/tmp/anselm-rig-formal-20260801-29/sessions/20260801-080221/evidence/search-tools-no-match.png |
| TOOL-014 | search_function | function · 关键词+语义检索 function 库 | ✓✓✓✓✓ | L1:G1→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-081207/evidence/tool-014-search-function-session-summary.txt; L2:F2→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-081207/evidence/tool-014-search-function-session-summary.txt; L3:A5→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-081207/evidence/tool-014-search-function-session-summary.txt; L4:C4→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-081207/evidence/search-function-hit.png; L5:G2→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-081207/evidence/search-function-no-match.png |
| TOOL-015 | get_function | function · 取 function 活跃版本全貌 | ✓✓✓✓✓ | L1:G1→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-083704/evidence/tool-015-get-function-session-summary.txt; L2:F2→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-083704/evidence/tool-015-get-function-session-summary.txt; L3:A5→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-083704/evidence/tool-015-get-function-session-summary.txt; L4:C4→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-083704/evidence/get-function-hit.png; L5:G2→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-083704/evidence/get-function-not-found.png |
| TOOL-016 | create_function | function · ops 构建新 Python function,v1 立即生效 | ✓✓✓✓✓ | L1:G1→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-085503/evidence/tool-016-create-function-session-summary.txt; L2:F2→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-085503/evidence/tool-016-create-function-session-summary.txt; L3:A5→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-085503/evidence/tool-016-create-function-session-summary.txt; L4:C4→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-085503/evidence/create-function-hit.png; L5:G2→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-085503/evidence/create-function-failed.png |
| TOOL-017 | edit_function | function · 活跃版本叠 ops 出新版本 | ✓✓✓✓✓ | L1:G1→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-090605/evidence/tool-017-edit-function-session-summary.txt; L2:F2→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-090605/evidence/tool-017-edit-function-session-summary.txt; L3:A5→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-090605/evidence/tool-017-edit-function-session-summary.txt; L4:C4→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-090605/evidence/edit-function-hit.png; L5:G2→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-090605/evidence/edit-function-failed.png |
| TOOL-018 | revert_function | function · 活跃指针切到已有版本号 | ✓✓✓✓✓ | L1:G1→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-091433/evidence/tool-018-revert-function-session-summary.txt; L2:F2→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-091433/evidence/tool-018-revert-function-session-summary.txt; L3:A5→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-091433/evidence/tool-018-revert-function-session-summary.txt; L4:C4→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-091433/evidence/revert-function-hit.png; L5:G2→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-091433/evidence/revert-function-failed.png |
| TOOL-019 | delete_function | function · 软删 function 主行并回收 sandbox;不可逆版本历史保留供审计,主实体与动作随后 not-found | ✓✓✓✓✓ | L1:G1→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-093503/evidence/tool-019-delete-function-session-summary.txt; L2:F2→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-093503/evidence/tool-019-delete-function-session-summary.txt; L3:A5→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-093503/evidence/tool-019-delete-function-session-summary.txt; L4:C4→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-093503/evidence/delete-function-fixed-hit.png; L5:G2→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-093503/evidence/delete-function-fixed-failed.png |
| TOOL-020 | update_function_meta | function · 仅改 name/description/tags | ✓✓✓✓✓ | L1:G1→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-095616/evidence/tool-020-update-function-meta-session-summary.txt; L2:F2→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-095616/evidence/tool-020-update-function-meta-session-summary.txt; L3:A5→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-095616/evidence/tool-020-update-function-meta-session-summary.txt; L4:C4→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-095616/evidence/update-function-meta-fixed-hit.png; L5:G2→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-095616/evidence/update-function-meta-fixed-failed.png |
| TOOL-021 | run_function | function · 关键字参数运行,返回 ok/output/logs | ✓✓✓✓✓ | L1:G1→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-101832/evidence/tool-021-run-function-session-summary.txt; L2:F2→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-101832/evidence/tool-021-run-function-session-summary.txt; L3:A5→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-101832/evidence/tool-021-run-function-session-summary.txt; L4:C4→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-101832/evidence/run-function-explicit-v2.png; L5:G2→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-101832/evidence/run-function-not-found-final.png |
| TOOL-022 | search_function_executions | function · 分页检索执行历史 | ✓✓✓✓✓ | L1:G1→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-103839/evidence/tool-022-search-function-executions-session-summary.txt; L2:F2→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-103839/evidence/tool-022-search-function-executions-session-summary.txt; L3:A5→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-103839/evidence/search-executions-paging.png; L4:C4→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-103839/evidence/search-executions-invalid-status.png; L5:G2→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-103839/evidence/search-executions-empty.png |
| TOOL-023 | get_function_execution | function · 取单条执行记录 | ✓✓✓✓✓ | L1:G1→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-113505/evidence/tool-023-get-function-execution-session-summary.txt; L2:F2→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-113505/evidence/tool-023-get-function-execution-session-summary.txt; L3:A5→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-113505/evidence/get-function-execution-success.jpg; L4:C4→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-113505/evidence/get-function-execution-success.jpg; L5:G2→/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-113505/evidence/get-function-execution-not-found.jpg |
| TOOL-024 | search_handler | handler · 检索 handler 库 | ✓✓✓✓✓ | L1:G1→/private/tmp/anselm-rig-formal-20260801-31/sessions/20260801-114544/evidence/tool-024-search-handler-session-summary.txt; L2:F2→/private/tmp/anselm-rig-formal-20260801-31/sessions/20260801-114544/evidence/tool-024-search-handler-session-summary.txt; L3:A5→/private/tmp/anselm-rig-formal-20260801-31/sessions/20260801-114544/evidence/search-handler-hit.png; L4:C4→/private/tmp/anselm-rig-formal-20260801-31/sessions/20260801-114544/evidence/search-handler-hit.png; L5:G2→/private/tmp/anselm-rig-formal-20260801-31/sessions/20260801-114544/evidence/search-handler-no-match.png |
| TOOL-025 | get_handler | handler · 取活跃版本+配置态+运行态 | ✓✓✓✓✓ | L1:G1→/private/tmp/anselm-rig-formal-20260801-32/sessions/20260801-115554/evidence/tool-025-get-handler-session-summary.txt; L2:F2→/private/tmp/anselm-rig-formal-20260801-32/sessions/20260801-115554/evidence/tool-025-get-handler-session-summary.txt; L3:A5→/private/tmp/anselm-rig-formal-20260801-32/sessions/20260801-115554/evidence/get-handler-details.png; L4:C4→/private/tmp/anselm-rig-formal-20260801-32/sessions/20260801-115554/evidence/get-handler-top.png; L5:G2→/private/tmp/anselm-rig-formal-20260801-32/sessions/20260801-115554/evidence/get-handler-not-found.png |
| TOOL-026 | create_handler | handler · 新建有状态常驻 Python 类 | ✓✓✓✓✓ | L1:G1→/private/tmp/anselm-rig-formal-20260801-38/sessions/20260801-123643/evidence/tool-026-create-handler-session-summary.txt; L2:F2→/private/tmp/anselm-rig-formal-20260801-38/sessions/20260801-123643/evidence/tool-026-create-handler-session-summary.txt; L3:A5→/private/tmp/anselm-rig-formal-20260801-38/sessions/20260801-123643/evidence/create-handler-success.jpeg; L4:C4→/private/tmp/anselm-rig-formal-20260801-38/sessions/20260801-123643/evidence/create-handler-success.jpeg; L5:G2→/private/tmp/anselm-rig-formal-20260801-38/sessions/20260801-123643/evidence/create-handler-rejected.jpeg |
| TOOL-027 | edit_handler | handler · 叠 ops 新版本并重启实例 | ✓✓✓✓✓ | L1:G1→/private/tmp/anselm-rig-formal-20260801-41/sessions/20260801-125948/evidence/tool-027-edit-handler-session-summary.txt; L2:F2→/private/tmp/anselm-rig-formal-20260801-41/sessions/20260801-125948/evidence/tool-027-edit-handler-session-summary.txt; L3:A5→/private/tmp/anselm-rig-formal-20260801-41/sessions/20260801-125948/evidence/edit-handler-success.png; L4:C4→/private/tmp/anselm-rig-formal-20260801-41/sessions/20260801-125948/evidence/edit-handler-success.png; L5:G2→/private/tmp/anselm-rig-formal-20260801-41/sessions/20260801-125948/evidence/edit-handler-rejected-missing-method.png |
| TOOL-028 | revert_handler | handler · 切版本并重启实例 | ✓✓✓✓✓ | L1:G1→/private/tmp/anselm-rig-formal-20260801-46/sessions/20260801-132558/evidence/tool-028-revert-handler-session-summary.txt; L2:F2→/private/tmp/anselm-rig-formal-20260801-46/sessions/20260801-132558/evidence/tool-028-revert-handler-session-summary.txt; L3:A5→/private/tmp/anselm-rig-formal-20260801-46/sessions/20260801-132558/evidence/revert-handler-success.jpg; L4:C4→/private/tmp/anselm-rig-formal-20260801-46/sessions/20260801-132558/evidence/revert-handler-success.jpg; L5:G2→/private/tmp/anselm-rig-formal-20260801-46/sessions/20260801-132558/evidence/revert-handler-negative.jpg |
| TOOL-029 | delete_handler | handler · 停实例并软删主行;回执含 retention(handler/versions/sandbox/actions);版本历史保留审计,环境尽力回收,关系边清理,主实体与动作随后 not-found | ✓✓✓✓✓ | L1:G1→/private/tmp/anselm-rig-formal-20260801-50/sessions/20260801-143835/evidence/tool-029-delete-handler-session-summary.txt; L2:F2→/private/tmp/anselm-rig-formal-20260801-50/sessions/20260801-143835/evidence/tool-029-delete-handler-session-summary.txt; L3:A5→/private/tmp/anselm-rig-formal-20260801-50/sessions/20260801-143835/evidence/tool-029-positive.png; L4:C4→/private/tmp/anselm-rig-formal-20260801-50/sessions/20260801-143835/evidence/tool-029-positive.png; L5:G2→/private/tmp/anselm-rig-formal-20260801-50/sessions/20260801-143835/evidence/tool-029-negative.png |
| TOOL-030 | call_handler | handler · 调用常驻实例方法 | ✓✓✓✓✓ | L1:G1→/private/tmp/anselm-rig-formal-20260801-51/sessions/20260801-144938/evidence/tool-030-call-handler-session-summary.txt; L2:F2→/private/tmp/anselm-rig-formal-20260801-51/sessions/20260801-144938/evidence/tool-030-call-handler-session-summary.txt; L3:A5→/private/tmp/anselm-rig-formal-20260801-51/sessions/20260801-144938/evidence/tool-030-call-handler-final.png; L4:C4→/private/tmp/anselm-rig-formal-20260801-51/sessions/20260801-144938/evidence/tool-030-call-handler-final.png; L5:G2→/private/tmp/anselm-rig-formal-20260801-51/sessions/20260801-144938/evidence/tool-030-call-handler-final.png |
| TOOL-031 | update_handler_config | handler · Merge Patch 写 init-args 后重启 | ✓✓✓✓✓ | L1:G1→/private/tmp/anselm-rig-formal-20260801-68/sessions/20260801-160415/evidence/tool-031-final-clean-summary.txt; L2:F2→/private/tmp/anselm-rig-formal-20260801-68/sessions/20260801-160415/evidence/tool-031-final-clean-summary.txt; L3:A5→/private/tmp/anselm-rig-formal-20260801-68/sessions/20260801-160415/evidence/tool-031-final-clean-summary.txt; L4:C4→/private/tmp/anselm-rig-formal-20260801-68/sessions/20260801-160415/evidence/tool-031-final-clean-summary.txt; L5:G2→/private/tmp/anselm-rig-formal-20260801-68/sessions/20260801-160415/evidence/tool-031-final-clean-summary.txt |
| TOOL-032 | update_handler_meta | handler · 仅改 meta,不重启 | ✓✓✓✓✓ | L1:G1→/private/tmp/anselm-rig-formal-20260801-69/sessions/20260801-161542/evidence/tool-032-update-handler-meta-session-summary.txt; L2:F2→/private/tmp/anselm-rig-formal-20260801-69/sessions/20260801-161542/evidence/tool-032-update-handler-meta-session-summary.txt; L3:A5→/private/tmp/anselm-rig-formal-20260801-69/sessions/20260801-161542/evidence/tool-032-update-handler-meta-session-summary.txt; L4:C4→/private/tmp/anselm-rig-formal-20260801-69/sessions/20260801-161542/evidence/tool-032-update-handler-meta-session-summary.txt; L5:G2→/private/tmp/anselm-rig-formal-20260801-69/sessions/20260801-161542/evidence/tool-032-update-handler-meta-session-summary.txt |
| TOOL-033 | restart_handler | handler · 优雅关停+新实例 | ····· |  |
| TOOL-034 | search_handler_calls | handler · 列调用历史 | ····· |  |
| TOOL-035 | get_handler_call | handler · 取单条调用记录 | ····· |  |
| TOOL-036 | search_agent | agent · 检索 agent 库 | ····· |  |
| TOOL-037 | get_agent | agent · 取 agent 活跃版本完整配置 | ····· |  |
| TOOL-038 | create_agent | agent · 新建配置式 LLM worker | ····· |  |
| TOOL-039 | edit_agent | agent · 局部编辑,未传字段保持 | ····· |  |
| TOOL-040 | revert_agent | agent · 回退活跃版本 | ····· |  |
| TOOL-041 | delete_agent | agent · 软删,保留执行历史 | ····· |  |
| TOOL-042 | update_agent_meta | agent · 仅改行 meta | ····· |  |
| TOOL-043 | invoke_agent | agent · 跑 agent ReAct 循环,按 outputSchema 成形 | ····· |  |
| TOOL-044 | search_agent_executions | agent · 检索运行历史 | ····· |  |
| TOOL-045 | get_agent_execution | agent · 取单条执行全记录 | ····· |  |
| TOOL-046 | search_control | control · 检索 control | ····· |  |
| TOOL-047 | get_control | control · 取活跃版本分支集 | ····· |  |
| TOOL-048 | create_control | control · 新建路由分支表实体 | ····· |  |
| TOOL-049 | edit_control | control · 全量替换分支集新版本 | ····· |  |
| TOOL-050 | revert_control | control · 切版本指针 | ····· |  |
| TOOL-051 | delete_control | control · 删全版本 | ····· |  |
| TOOL-052 | search_approval | approval · 检索 approval 表单 | ····· |  |
| TOOL-053 | get_approval | approval · 取活跃版本(模板+timeout 等) | ····· |  |
| TOOL-054 | create_approval | approval · 新建 approval 表单实体 | ····· |  |
| TOOL-055 | edit_approval | approval · 全量替换新版本 | ····· |  |
| TOOL-056 | revert_approval | approval · 切版本指针 | ····· |  |
| TOOL-057 | delete_approval | approval · 删全版本,不可逆 | ····· |  |
| TOOL-058 | search_workflow | workflow · 检索 workflow 含生命周期态 | ····· |  |
| TOOL-059 | get_workflow | workflow · 取活跃图+生命周期+并发策略 | ····· |  |
| TOOL-060 | create_workflow | workflow · ops 构图,v1 初始 deactivated | ····· |  |
| TOOL-061 | edit_workflow | workflow · 叠 ops 出新版本 | ····· |  |
| TOOL-062 | revert_workflow | workflow · 切图版本指针 | ····· |  |
| TOOL-063 | delete_workflow | workflow · 删全图版本,不可逆 | ····· |  |
| TOOL-064 | capability_check_workflow | workflow · 校验图健全+引用实体可用 | ····· |  |
| TOOL-065 | trigger_workflow | workflow · 自供 payload 手动跑一次 | ····· |  |
| TOOL-066 | stage_workflow | workflow · 布防:下次真实触发跑一次即解除 | ····· |  |
| TOOL-067 | activate_workflow | workflow · 上线持续监听 | ····· |  |
| TOOL-068 | deactivate_workflow | workflow · 优雅下线,在飞跑完 | ····· |  |
| TOOL-069 | kill_workflow | workflow · 硬停+取消在飞 | ····· |  |
| TOOL-070 | get_flowrun | workflow · 取运行头+全节点记录 | ····· |  |
| TOOL-071 | search_flowruns | workflow · 列运行,可限定 workflow | ····· |  |
| TOOL-072 | replay_flowrun | workflow · 断点重跑失败运行 | ····· |  |
| TOOL-073 | list_approval_inbox | workflow · 列全工作区待决审批 | ····· |  |
| TOOL-074 | decide_approval | workflow · 批/拒停在审批节点的运行 | ····· |  |
| TOOL-075 | search_triggers | trigger · 检索 trigger 含 listener 在线态 | ····· |  |
| TOOL-076 | get_trigger | trigger · 取 kind/配置/运行态 | ····· |  |
| TOOL-077 | create_trigger | trigger · 新建信号源 | ····· |  |
| TOOL-078 | edit_trigger | trigger · 改 name/description/config(kind 不可变) | ····· |  |
| TOOL-079 | delete_trigger | trigger · 软删,停 listener | ····· |  |
| TOOL-080 | fire_trigger | trigger · 手动触发一次演练扇出 | ····· |  |
| TOOL-081 | search_activations | trigger · 查动作日志(触没触发都记) | ····· |  |
| TOOL-082 | get_activation | trigger · 取单条 activation | ····· |  |
| TOOL-083 | search_firings | trigger · 查扇出收件箱逐 workflow 处置 | ····· |  |
| TOOL-084 | search_documents | document · 按内容检索文档库 | ····· |  |
| TOOL-085 | list_documents | document · 列 Notion 式树 | ····· |  |
| TOOL-086 | read_document | document · 载入完整 markdown 正文 | ····· |  |
| TOOL-087 | create_document | document · 建文档,可嵌套 | ····· |  |
| TOOL-088 | edit_document | document · 更新字段,content/tags 全量替换 | ····· |  |
| TOOL-089 | move_document | document · 重挂父节点+兄弟序,路径级联 | ····· |  |
| TOOL-090 | delete_document | document · 删除文档 | ····· |  |
| TOOL-091 | list_attachments | attachment · 列上传文件 | ····· |  |
| TOOL-092 | read_attachment | attachment · 读文本/文档类附件正文 | ····· |  |
| TOOL-093 | inspect_media | attachment · 按 id 取有界媒体证据(图走视觉路由) | ····· |  |
| TOOL-094 | read_memory | memory · 按名载入记忆正文 | ····· |  |
| TOOL-095 | write_memory | memory · 存跨对话持久事实(重名原地更新) | ····· |  |
| TOOL-096 | forget_memory | memory · 删除记忆 | ····· |  |
| TOOL-097 | get_model_config | model · 报工作区模型配置 | ····· |  |
| TOOL-098 | list_mcp_marketplace | mcp · 浏览 MCP 市场 | ····· |  |
| TOOL-099 | install_mcp_server | mcp · 安装 MCP server+env | ····· |  |
| TOOL-100 | uninstall_mcp_server | mcp · 卸载:停进程删配置 | ····· |  |
| TOOL-101 | reconnect_mcp | mcp · 重启已装 server 连接 | ····· |  |
| TOOL-102 | search_mcp_calls | mcp · 列工具调用历史 | ····· |  |
| TOOL-103 | get_mcp_call | mcp · 取单条调用记录 | ····· |  |
| TOOL-104 | activate_skill | skill · 激活:载入指令+占位符替换 | ····· |  |
| TOOL-105 | get_skill | skill · 读完整内容不激活 | ····· |  |
| TOOL-106 | create_skill | skill · 撰写新 skill | ····· |  |
| TOOL-107 | edit_skill | skill · 全量覆写 SKILL.md | ····· |  |
| TOOL-108 | delete_skill | skill · 永久删除目录 | ····· |  |
| TOOL-109 | run_skill_script | skill · 沙箱跑 skill 自带脚本 | ····· |  |
| TOOL-110 | Subagent | subagent · 派发隔离子 agent(Explore/Plan/general-purpose) | ····· |  |
| TOOL-111 | get_subagent_trace | subagent · 读回 subagent 隐藏 trace | ····· |  |
| TOOL-112 | search_conversations | conversation · 混合检索历史对话 | ····· |  |
| TOOL-113 | list_conversations | conversation · 枚举对话按活跃排序 | ····· |  |
| TOOL-114 | manage_conversation | conversation · 归档/置顶/重命名当前对话 | ····· |  |
| TOOL-115 | search_blocks | blocks · 检索可接线 workflow 积木 | ····· |  |
| TOOL-116 | get_relations | relation · 查实体关系邻域(uses/used-by) | ····· |  |
| TOOL-117 | WebFetch | web · 抓 URL 并 LLM 摘要 | ····· |  |
| TOOL-118 | WebSearch | web · 联网搜索 | ····· |  |
| TOOL-119 | generate_image | generate · 文生图,落附件返回 receipt | ····· |  |
| TOOL-120 | generate_speech | generate · 文合成语音,落音频附件 | ····· |  |
| TOOL-121 | generate_video | generate · 文生视频(同步,最贵) | ····· |  |
| TOOL-122 | edit_image | generate · 改既有图:attachmentId+指令("改成夜晚"),生成模型原生改图,落新附件返回 receipt | ····· |  |
| TOOL-123 | animate_image | generate · 图生视频:attachmentId+运动 prompt("缓推近"),受管两次请求形(签名句柄),落视频附件 | ····· |  |
| TOOL-124 | enroll_voice | generate · 参考音色登记:干净音频附件(≤30s 单说话人)+名字→音色库存,后续 generate_speech 可指名 | ····· |  |

## API 端点全集(257)

| ID | 项 | 摘要 | 五级 | 证据 |
|---|---|---|---|---|
| EP-001 | POST /api/v1/functions | function · 创建函数（扁平 payload 反推 ops 走构建管线），201 | ····· |  |
| EP-002 | GET /api/v1/functions | function · 函数分页列表（`?search` name 子串过滤） | ····· |  |
| EP-003 | GET /api/v1/functions/{id} | function · 单读，附 activeVersion（代码+env 状态一趟拿全） | ····· |  |
| EP-004 | PATCH /api/v1/functions/{id} | function · 改 meta（name/description/tags，不升版本） | ····· |  |
| EP-005 | DELETE /api/v1/functions/{id} | function · 软删 + 销毁 env + 清边，204 | ····· |  |
| EP-006 | POST /api/v1/functions/{id}:run | function · 同步执行，body `{args, version?}`，返裸结果 | ····· |  |
| EP-007 | POST /api/v1/functions/{id}:revert | function · active 指针移到指定版本号 | ····· |  |
| EP-008 | POST /api/v1/functions/{id}:edit | function · ops 构建新版本（空 ops = 仅重建 env） | ····· |  |
| EP-009 | POST /api/v1/functions/{id}:iterate | function · 开 AI 编辑对话，202 返 conversation id | ····· |  |
| EP-010 | GET /api/v1/functions/{id}/versions | function · 版本分页列表 | ····· |  |
| EP-011 | GET /api/v1/functions/{id}/versions/{version} | function · 单版本（接受版本号或 fnv_ id） | ····· |  |
| EP-012 | GET /api/v1/functions/{id}/executions | function · 执行日志分页 + aggregates | ····· |  |
| EP-013 | GET /api/v1/function-executions/{id} | function · 单执行详情（含 logs） | ····· |  |
| EP-014 | POST /api/v1/handlers | handler · 创建 handler（扁平 → ops），201，不 spawn 实例 | ····· |  |
| EP-015 | GET /api/v1/handlers | handler · handler 分页列表（`?search`） | ····· |  |
| EP-016 | GET /api/v1/handlers/{id} | handler · 单读（附 activeVersion + configState + runtimeState） | ····· |  |
| EP-017 | PATCH /api/v1/handlers/{id} | handler · 改 meta | ····· |  |
| EP-018 | DELETE /api/v1/handlers/{id} | handler · 停实例 + 软删 + 销毁 env + 清边，204 | ····· |  |
| EP-019 | POST /api/v1/handlers/{id}:call | handler · 同步调方法，body `{method, args}`，返裸结果 | ····· |  |
| EP-020 | POST /api/v1/handlers/{id}:restart | handler · 手动重启常驻实例，返新 runtimeState | ····· |  |
| EP-021 | POST /api/v1/handlers/{id}:revert | handler · 移 active 指针 + 重启实例 | ····· |  |
| EP-022 | POST /api/v1/handlers/{id}:edit | handler · ops 构建新版本 + 重启实例 | ····· |  |
| EP-023 | POST /api/v1/handlers/{id}:iterate | handler · 开 AI 编辑对话 | ····· |  |
| EP-024 | GET /api/v1/handlers/{id}/versions | handler · 版本分页列表 | ····· |  |
| EP-025 | GET /api/v1/handlers/{id}/versions/{version} | handler · 单版本（号或 hdv_ id） | ····· |  |
| EP-026 | GET /api/v1/handlers/{id}/config | handler · 读 config（sensitive 掩码） | ····· |  |
| EP-027 | PUT /api/v1/handlers/{id}/config | handler · JSON Merge Patch 更新 + 重启实例重跑 `__init__` | ····· |  |
| EP-028 | DELETE /api/v1/handlers/{id}/config | handler · 清空 config + 停实例 | ····· |  |
| EP-029 | GET /api/v1/handlers/{id}/calls | handler · 调用日志分页 + aggregates | ····· |  |
| EP-030 | GET /api/v1/handler-calls/{id} | handler · 单调用详情（含 logs） | ····· |  |
| EP-031 | POST /api/v1/agents | agent · 创建（identity + 全量 Config 快照 = v1），201 | ····· |  |
| EP-032 | GET /api/v1/agents | agent · agent 分页列表（`?search`） | ····· |  |
| EP-033 | GET /api/v1/agents/{id} | agent · 单读（附 activeVersion） | ····· |  |
| EP-034 | PATCH /api/v1/agents/{id} | agent · 改 meta | ····· |  |
| EP-035 | DELETE /api/v1/agents/{id} | agent · 软删 + 清边，204 | ····· |  |
| EP-036 | POST /api/v1/agents/{id}:invoke | agent · 同步跑 ReAct loop，body `{input, version?}` | ····· |  |
| EP-037 | POST /api/v1/agents/{id}:revert | agent · 移 active 指针 | ····· |  |
| EP-038 | POST /api/v1/agents/{id}:edit | agent · 全量 Config 替换 → 新版本 | ····· |  |
| EP-039 | POST /api/v1/agents/{id}:iterate | agent · 开 AI 编辑对话 | ····· |  |
| EP-040 | GET /api/v1/agents/{id}/mount-health | agent · 按需预检 active 版本各挂载是否可解析 | ····· |  |
| EP-041 | GET /api/v1/agents/{id}/versions | agent · 版本分页列表 | ····· |  |
| EP-042 | GET /api/v1/agents/{id}/versions/{version} | agent · 单版本（号或 agv_ id） | ····· |  |
| EP-043 | GET /api/v1/agents/{id}/executions | agent · 执行日志分页 + aggregates | ····· |  |
| EP-044 | GET /api/v1/agent-executions/{id} | agent · 单执行详情（含完整 transcript） | ····· |  |
| EP-045 | POST /api/v1/workflows | workflow · 创建工作流，201 | ····· |  |
| EP-046 | GET /api/v1/workflows | workflow · 分页列表（`?search`） | ····· |  |
| EP-047 | GET /api/v1/workflows/{id} | workflow · 单读（附 activeVersion 图） | ····· |  |
| EP-048 | PATCH /api/v1/workflows/{id} | workflow · 改 meta（含 concurrency 政策），不升版本 | ····· |  |
| EP-049 | DELETE /api/v1/workflows/{id} | workflow · 软删 + 清边，204 | ····· |  |
| EP-050 | POST /api/v1/workflows/{id}:trigger | workflow · 立即跑一次，body `{payload?}`，202 返 flowrun id | ····· |  |
| EP-051 | POST /api/v1/workflows/{id}:stage | workflow · 待命恰一次真实触发后自动撤防（已 active → 409） | ····· |  |
| EP-052 | POST /api/v1/workflows/{id}:activate | workflow · 上线：挂监听 + active，返实体快照 | ····· |  |
| EP-053 | POST /api/v1/workflows/{id}:deactivate | workflow · 优雅下线：摘监听 + inactive/draining | ····· |  |
| EP-054 | POST /api/v1/workflows/{id}:kill | workflow · 硬停：摘监听 + 取消全部在途 run，返实体快照 | ····· |  |
| EP-055 | POST /api/v1/workflows/{id}:edit | workflow · 图 ops 构建新版本 | ····· |  |
| EP-056 | POST /api/v1/workflows/{id}:revert | workflow · 移 active 指针 | ····· |  |
| EP-057 | POST /api/v1/workflows/{id}:capability-check | workflow · ref 解析体检，返 problems + warnings | ····· |  |
| EP-058 | POST /api/v1/workflows/{id}:iterate | workflow · 开 AI 编辑对话 | ····· |  |
| EP-059 | GET /api/v1/workflows/{id}/versions | workflow · 版本分页列表 | ····· |  |
| EP-060 | GET /api/v1/workflows/{id}/versions/{version} | workflow · 单版本图 | ····· |  |
| EP-061 | GET /api/v1/flowruns | flowrun · 运行历史分页（keyset 或 offset 两互斥模式 + 全套过滤） | ····· |  |
| EP-062 | POST /api/v1/flowruns | flowrun · 手动起 run，body `{workflowId, entryNode?, payload?}` | ····· |  |
| EP-063 | GET /api/v1/flowruns/{id} | flowrun · run 头 + 一页节点行（N4 keyset） | ····· |  |
| EP-064 | GET /api/v1/flowruns/{id}/activity | flowrun · 按 run 聚合的四表执行活动时长投影（keyset） | ····· |  |
| EP-065 | POST /api/v1/flowruns/{id}:replay | flowrun · 重放失败 run（仅 failed 可重放） | ····· |  |
| EP-066 | POST /api/v1/flowruns/{id}:cancel | flowrun · 取消单个 running run，202 返 run + 节点首页 | ····· |  |
| EP-067 | GET /api/v1/flowrun-inbox | flowrun · 审批收件箱（全部 parked 节点行 + workflow 上下文 enrich） | ····· |  |
| EP-068 | GET /api/v1/flowrun-stats | flowrun · 运营统计批查（`?workflowIds&recentN&since&until`），有界 ≤50 | ····· |  |
| EP-069 | GET /api/v1/flowrun-matrix | flowrun · 节点×run 状态格阵批查（`?flowrunIds`），有界 ≤50 | ····· |  |
| EP-070 | POST /api/v1/flowruns/{id}/approvals/{node}:decide | flowrun · 人工审批决策 `{decision, reason?}`，first-wins | ····· |  |
| EP-071 | POST /api/v1/triggers | trigger · 创建触发器（cron/webhook/fsnotify/sensor） | ····· |  |
| EP-072 | GET /api/v1/triggers | trigger · 分页列表（带 paused/refCount/listening/lastFiredAt） | ····· |  |
| EP-073 | GET /api/v1/triggers/{id} | trigger · 单读（同上派生字段） | ····· |  |
| EP-074 | PATCH /api/v1/triggers/{id} | trigger · Edit：热更监听中的 listener（暂停者不热更） | ····· |  |
| EP-075 | DELETE /api/v1/triggers/{id} | trigger · 删除触发器 + 注销监听 | ····· |  |
| EP-076 | POST /api/v1/triggers/{id}:fire | trigger · 手动催一次，202 返 activation id（暂停 → 422） | ····· |  |
| EP-077 | POST /api/v1/triggers/{id}:pause | trigger · 持久暂停 + 源头注销 listener，返裸 trigger | ····· |  |
| EP-078 | POST /api/v1/triggers/{id}:resume | trigger · 恢复调度并按当前 config 重注册，返裸 trigger | ····· |  |
| EP-079 | POST /api/v1/triggers/{id}:iterate | trigger · 开 AI 编辑对话 | ····· |  |
| EP-080 | GET /api/v1/triggers/{id}/activations | trigger · 活动审计分页（触没触发都有记录） | ····· |  |
| EP-081 | GET /api/v1/trigger-activations/{id} | trigger · 单 activation 详情 | ····· |  |
| EP-082 | GET /api/v1/firings | trigger · workspace 级 firing 收件箱分页（`?triggerId&status&窗`） | ····· |  |
| EP-083 | GET /api/v1/triggers/{id}/firings | trigger · 逐 trigger firing 分页（同一 handler，路径填 filter） | ····· |  |
| EP-084 | GET /api/v1/trigger-schedule | trigger · 前瞻 cron 调度时间线（`?within&limit`，带 truncated） | ····· |  |
| EP-085 | ANY /api/v1/webhooks/{triggerId}/{path...} | trigger · webhook 外部入站 catch-all（方法按 trigger config，默认 POST；免 bearer、自带 HMAC） | ····· |  |
| EP-086 | POST /api/v1/controls | control · 创建 control（路由分支实体），201 | ····· |  |
| EP-087 | GET /api/v1/controls | control · 分页列表 | ····· |  |
| EP-088 | GET /api/v1/controls/{id} | control · 单读（附 activeVersion） | ····· |  |
| EP-089 | PATCH /api/v1/controls/{id} | control · 改 meta | ····· |  |
| EP-090 | DELETE /api/v1/controls/{id} | control · 软删 + 清边，204 | ····· |  |
| EP-091 | POST /api/v1/controls/{id}:edit | control · 构建新版本 | ····· |  |
| EP-092 | POST /api/v1/controls/{id}:revert | control · 移 active 指针 | ····· |  |
| EP-093 | POST /api/v1/controls/{id}:iterate | control · 开 AI 编辑对话 | ····· |  |
| EP-094 | GET /api/v1/controls/{id}/versions | control · 版本分页列表 | ····· |  |
| EP-095 | GET /api/v1/controls/{id}/versions/{version} | control · 单版本 | ····· |  |
| EP-096 | POST /api/v1/approvals | approval · 创建 approval（人在环审批实体），201 | ····· |  |
| EP-097 | GET /api/v1/approvals | approval · 分页列表 | ····· |  |
| EP-098 | GET /api/v1/approvals/{id} | approval · 单读（附 activeVersion） | ····· |  |
| EP-099 | PATCH /api/v1/approvals/{id} | approval · 改 meta | ····· |  |
| EP-100 | DELETE /api/v1/approvals/{id} | approval · 软删 + 清边，204 | ····· |  |
| EP-101 | POST /api/v1/approvals/{id}:edit | approval · 构建新版本 | ····· |  |
| EP-102 | POST /api/v1/approvals/{id}:revert | approval · 移 active 指针 | ····· |  |
| EP-103 | POST /api/v1/approvals/{id}:iterate | approval · 开 AI 编辑对话 | ····· |  |
| EP-104 | GET /api/v1/approvals/{id}/versions | approval · 版本分页列表 | ····· |  |
| EP-105 | GET /api/v1/approvals/{id}/versions/{version} | approval · 单版本 | ····· |  |
| EP-106 | GET /api/v1/skills | skill · skill 全列（有界不分页，List 省 dir） | ····· |  |
| EP-107 | POST /api/v1/skills | skill · 新建 skill（严格冲突 + name 须符规范形态） | ····· |  |
| EP-108 | GET /api/v1/skills/{name} | skill · 单读（附 provenance 与 dir） | ····· |  |
| EP-109 | PUT /api/v1/skills/{name} | skill · 结构化覆盖（保真读-改-写，frontmatter 键序不丢） | ····· |  |
| EP-110 | DELETE /api/v1/skills/{name} | skill · 删整目录含捆绑文件，204 | ····· |  |
| EP-111 | POST /api/v1/skills/{name}:activate | skill · 激活：inline 渲染注入 / fork 派 subagent | ····· |  |
| EP-112 | POST /api/v1/skills/{name}:update | skill · 按 provenance 来源重拉（本地改动非 force → 409） | ····· |  |
| EP-113 | POST /api/v1/skills/{name}:approve-tools | skill · 打开 allowed-tools 信任门 | ····· |  |
| EP-114 | POST /api/v1/skills:inspect-source | skill · 预览来源可装 skill 清单，不落盘 | ····· |  |
| EP-115 | POST /api/v1/skills:install | skill · 从来源安装 `{source, names?, force?}` | ····· |  |
| EP-116 | GET /api/v1/skills/{name}/files | skill · 全文件元数据列表（含 SKILL.md，有界不分页） | ····· |  |
| EP-117 | GET /api/v1/skills/{name}/files/{path...} | skill · 单文件裸字节读（1MB 护栏） | ····· |  |
| EP-118 | PUT /api/v1/skills/{name}/files/{path...} | skill · 裸字节写入，204（SKILL.md 为带校验整替） | ····· |  |
| EP-119 | DELETE /api/v1/skills/{name}/files/{path...} | skill · 删附属文件，204（清单拒删） | ····· |  |
| EP-120 | GET /api/v1/mcp-servers | mcp · server 实时状态列表 | ····· |  |
| EP-121 | GET /api/v1/mcp-servers/{name} | mcp · 单读（状态 + tools 缓存） | ····· |  |
| EP-122 | PUT /api/v1/mcp-servers/{name} | mcp · 手动装/同名替换（stdio 或 remote；失败仍落盘） | ····· |  |
| EP-123 | DELETE /api/v1/mcp-servers/{name} | mcp · 卸载 server，204 | ····· |  |
| EP-124 | POST /api/v1/mcp-servers/{name}:reconnect | mcp · 重连重置按钮，返新状态 | ····· |  |
| EP-125 | GET /api/v1/mcp-servers/{name}/stderr | mcp · stdio stderr ring 尾 | ····· |  |
| EP-126 | GET /api/v1/mcp-servers/{name}/calls | mcp · 调用台账分页 + aggregates | ····· |  |
| EP-127 | POST /api/v1/mcp-servers/{name}/tools/{tool}:invoke | mcp · 直接试调工具（绕过 chat/LLM），返裸结果 | ····· |  |
| EP-128 | POST /api/v1/mcp-servers:import | mcp · 导入 Claude Desktop mcp.json 片段（`?overwrite=`） | ····· |  |
| EP-129 | GET /api/v1/mcp-calls/{id} | mcp · 单调用详情（含 logs + 失败 stderr 尾） | ····· |  |
| EP-130 | GET /api/v1/mcp-registry | mcp · curated 市场全列 | ····· |  |
| EP-131 | POST /api/v1/mcp-registry:plan | mcp · 安装表单数据源（选包结果投影，零副作用） | ····· |  |
| EP-132 | POST /api/v1/mcp-registry:install | mcp · 从市场安装 `{name, env}` | ····· |  |
| EP-133 | GET /api/v1/documents | document · 直接子节点列表（`?parentId=`，空=根级） | ····· |  |
| EP-134 | POST /api/v1/documents | document · 创建文档，201 | ····· |  |
| EP-135 | GET /api/v1/documents/tree | document · 整树 metadata（无正文，每行带 hasContent） | ····· |  |
| EP-136 | GET /api/v1/documents/{id} | document · 单读（含 content） | ····· |  |
| EP-137 | PATCH /api/v1/documents/{id} | document · 更新文档 meta/正文 | ····· |  |
| EP-138 | DELETE /api/v1/documents/{id} | document · 删除（含子树），204 | ····· |  |
| EP-139 | POST /api/v1/documents/{id}:move | document · 移动（防环；nil parent=根） | ····· |  |
| EP-140 | POST /api/v1/documents/{id}:duplicate | document · 深拷整子树，201 返新根裸实体 | ····· |  |
| EP-141 | POST /api/v1/documents/{id}:iterate | document · 开 AI 编辑对话 | ····· |  |
| EP-142 | POST /api/v1/conversations | conversation · 创建对话 | ····· |  |
| EP-143 | GET /api/v1/conversations | conversation · 列表（`?search&archived&sort&workDir&pinned`） | ····· |  |
| EP-144 | GET /api/v1/conversations/{id} | conversation · 单读（含 isGenerating/awaitingInput/hasUnread） | ····· |  |
| EP-145 | PATCH /api/v1/conversations/{id} | conversation · 改 meta（ModelOverride 三态 + workDir） | ····· |  |
| EP-146 | DELETE /api/v1/conversations/{id} | conversation · 软删 + 级联清边与触点台账，204 | ····· |  |
| EP-147 | GET /api/v1/conversations/workdir-groups | conversation · 驻地分组投影（零参数有界，分列 active/archived 计数） | ····· |  |
| EP-148 | POST /api/v1/conversations:archive-workdir | conversation · 驻地组批量归档 `{workDir}`，返改变条数 | ····· |  |
| EP-149 | POST /api/v1/conversations:delete-workdir | conversation · 驻地组批量删除 `{workDir}`，跨归档态 | ····· |  |
| EP-150 | GET /api/v1/conversations/{id}/workdir | conversation · 驻地投影（现算 path/exists/git/branches/worktrees） | ····· |  |
| EP-151 | POST /api/v1/conversations/{id}/workdir:switch-branch | conversation · 切本地分支（脏区拒 422），返重探 WorkDirInfo | ····· |  |
| EP-152 | POST /api/v1/conversations/{id}/workdir:create-branch | conversation · 从 HEAD 建分支（不受脏区门），返 WorkDirInfo | ····· |  |
| EP-153 | POST /api/v1/conversations/{id}/workdir:add-worktree | conversation · 建 worktree 一条龙 `{name}` 并自动切驻地 | ····· |  |
| EP-154 | POST /api/v1/conversations/{id}/messages | chat · Send：落 user 回合 + 开 assistant 回合，202 返 msg id | ····· |  |
| EP-155 | GET /api/v1/conversations/{id}/messages | chat · 回合历史三读形态（`?cursor` / `?around` / `?dir=newer`） | ····· |  |
| EP-156 | POST /api/v1/conversations/{id}:cancel | chat · 取消在途生成，204 | ····· |  |
| EP-157 | POST /api/v1/conversations/{id}:seen | chat · 清 hasUnread（幂等），204 | ····· |  |
| EP-158 | POST /api/v1/conversations/{id}:fork | chat · 分叉线程到新对话，201 返新对话全行 | ····· |  |
| EP-159 | POST /api/v1/conversations/{id}:retry | chat · 末回合换新版本（重生成 / 编辑重发），202 返新 msg id | ····· |  |
| EP-160 | GET /api/v1/conversations/{id}/system-prompt-preview | chat · system prompt 调试预览 | ····· |  |
| EP-161 | GET /api/v1/conversations/{id}/usage | chat · token 用量 | ····· |  |
| EP-162 | GET /api/v1/conversations/{id}/interactions | chat · 待决人机交互重同步 | ····· |  |
| EP-163 | POST /api/v1/conversations/{id}/interactions/{toolCallId} | chat · 决议交互 `{action, answer?}`，204 | ····· |  |
| EP-164 | GET /api/v1/conversations/{id}/anchors | chat · 场次条导航锚点 keyset 分页 | ····· |  |
| EP-165 | GET /api/v1/conversations/{conversationId}/todos | todo · 对话工作清单（有界不分页） | ····· |  |
| EP-166 | GET /api/v1/conversations/{conversationId}/touchpoints | touchpoint · 对话触点台账 keyset 分页（`?kind&verb`） | ····· |  |
| EP-167 | GET /api/v1/sandbox/runtimes | sandbox · 已装运行时列表 | ····· |  |
| EP-168 | GET /api/v1/sandbox/runtimes/available | sandbox · 可装语言运行时 + 默认/钉死版本 | ····· |  |
| EP-169 | POST /api/v1/sandbox/runtimes | sandbox · 安装运行时 | ····· |  |
| EP-170 | DELETE /api/v1/sandbox/runtimes/{id} | sandbox · 卸载运行时 | ····· |  |
| EP-171 | GET /api/v1/sandbox/envs | sandbox · env 列表（有界） | ····· |  |
| EP-172 | GET /api/v1/sandbox/envs/{id} | sandbox · 单 env 详情 | ····· |  |
| EP-173 | DELETE /api/v1/sandbox/envs/{id} | sandbox · 销毁 env | ····· |  |
| EP-174 | GET /api/v1/sandbox/disk-usage | sandbox · 沙箱磁盘占用 | ····· |  |
| EP-175 | GET /api/v1/sandbox/bootstrap-status | sandbox · 引导状态 | ····· |  |
| EP-176 | POST /api/v1/sandbox:gc | sandbox · 垃圾回收孤儿 env | ····· |  |
| EP-177 | POST /api/v1/sandbox:retry-bootstrap | sandbox · 重试引导 | ····· |  |
| EP-178 | GET /api/v1/conversations/{id}/sandbox-envs | sandbox · 对话级 scratch env 列表 | ····· |  |
| EP-179 | POST /api/v1/conversations/{id}/sandbox-envs/{kind}:reset | sandbox · 销毁该对话某 kind 的 scratch env，204 | ····· |  |
| EP-180 | POST /api/v1/conversations/{id}/sandbox-envs:reset-all | sandbox · 销毁该对话全部 scratch env | ····· |  |
| EP-181 | POST /api/v1/attachments | attachment · 上传附件（返行 + 可选 preparation） | ····· |  |
| EP-182 | GET /api/v1/attachments/{id} | attachment · 附件 metadata（含 preparation 状态） | ····· |  |
| EP-183 | GET /api/v1/attachments/{id}/content | attachment · 附件内容字节 | ····· |  |
| EP-184 | POST /api/v1/attachments/{id}/playback-lease | attachment · audio 短期 loopback 播放租约，返 `{url,expiresAt}` | ····· |  |
| EP-185 | GET /api/v1/attachment-playback/{token} | attachment · bearerless 短租约 fetch（支持 Range/seek） | ····· |  |
| EP-186 | POST /api/v1/attachments/{id}/preparation/cancel | attachment · 取消进行中的媒体准备（canCancel 时） | ····· |  |
| EP-187 | POST /api/v1/attachments/{id}/preparation/retry | attachment · 重试失败的媒体准备（canRetry 时） | ····· |  |
| EP-188 | DELETE /api/v1/attachments/{id} | attachment · 删除附件 | ····· |  |
| EP-189 | GET /api/v1/memories | memory · memory 全列（有界不分页） | ····· |  |
| EP-190 | GET /api/v1/memories/{name} | memory · 单读（name 即 id） | ····· |  |
| EP-191 | PUT /api/v1/memories/{name} | memory · Upsert | ····· |  |
| EP-192 | DELETE /api/v1/memories/{name} | memory · 删除 | ····· |  |
| EP-193 | POST /api/v1/memories/{name}/pin | memory · 置顶 | ····· |  |
| EP-194 | POST /api/v1/memories/{name}/unpin | memory · 取消置顶 | ····· |  |
| EP-195 | GET /api/v1/search | search · 综搜/垂搜同端点（`?q&types&tags&窗&cursor&limit`） | ····· |  |
| EP-196 | POST /api/v1/search:reindex | search · 就地重建本 workspace 索引，204（并发调 409） | ····· |  |
| EP-197 | GET /api/v1/search/settings | search · 机器级搜索设置 + 引擎实时状态 | ····· |  |
| EP-198 | PATCH /api/v1/search/settings | search · 修补搜索设置（embedder/ollama 参数） | ····· |  |
| EP-199 | GET /api/v1/workspaces | workspace · workspace 全列（有界不分页） | ····· |  |
| EP-200 | POST /api/v1/workspaces | workspace · 创建 workspace（触发异步免费档开通） | ····· |  |
| EP-201 | GET /api/v1/workspaces/{id} | workspace · 单读 | ····· |  |
| EP-202 | PATCH /api/v1/workspaces/{id} | workspace · 改 meta（含 webFetchMode） | ····· |  |
| EP-203 | DELETE /api/v1/workspaces/{id} | workspace · 删除（守最后一个） | ····· |  |
| EP-204 | GET /api/v1/workspaces/{id}/stats | workspace · 删除确认的内容盘点（含 blobBytes，超时 -1） | ····· |  |
| EP-205 | PUT /api/v1/workspaces/{id}/default-models/{scenario} | workspace · 设某场景默认模型（校 apiKeyId 存在性 + native options） | ····· |  |
| EP-206 | DELETE /api/v1/workspaces/{id}/default-models/{scenario} | workspace · 清该场景默认模型 | ····· |  |
| EP-207 | PUT /api/v1/workspaces/{id}/default-search | workspace · 设默认搜索 key | ····· |  |
| EP-208 | DELETE /api/v1/workspaces/{id}/default-search | workspace · 清默认搜索 key | ····· |  |
| EP-209 | POST /api/v1/workspaces/{id}:activate | workspace · 刷 lastUsedAt | ····· |  |
| EP-210 | POST /api/v1/api-keys | apikey · 建 key（白名单 provider，dev 才含 mock） | ····· |  |
| EP-211 | GET /api/v1/api-keys | apikey · key 列表 | ····· |  |
| EP-212 | PATCH /api/v1/api-keys/{id} | apikey · 改 key（受管行 422 `API_KEY_IMMUTABLE`） | ····· |  |
| EP-213 | DELETE /api/v1/api-keys/{id} | apikey · 删 key（受管行 422；被引用挡 `API_KEY_IN_USE`） | ····· |  |
| EP-214 | POST /api/v1/api-keys/{id}:test | apikey · probe 探测该 key 可用性 | ····· |  |
| EP-215 | GET /api/v1/providers | apikey · provider 白名单列表（每项带 managed 标记） | ····· |  |
| EP-216 | GET /api/v1/freetier/quota | freetier · 免费档本月配额代理（无受管行 404） | ····· |  |
| EP-217 | POST /api/v1/freetier:provision | freetier · 手动重开通/修复（幂等），返 `{provisioned}` | ····· |  |
| EP-218 | GET /api/v1/speech/asr | speech · 本机 ASR WebSocket sidecar（16k PCM + 控制帧） | ····· |  |
| EP-219 | GET /api/v1/voices | voice · 音色库存列表（enroll_voice 登记的参考音色;库存上限闸,不是钱的闸） | ····· |  |
| EP-220 | DELETE /api/v1/voices/{id} | voice · 删除已登记音色（网关侧句柄随之失效） | ····· |  |
| EP-221 | GET /api/v1/read-aloud/availability | read-aloud · 朗读可用性 `{available}` | ····· |  |
| EP-222 | POST /api/v1/read-aloud:read | read-aloud · 合成朗读，返附件引用 + `cached`（不经 LLM） | ····· |  |
| EP-223 | GET /api/v1/model-capabilities | model · 模型能力目录（有界不分页） | ····· |  |
| EP-224 | GET /api/v1/scenarios | model · 场景枚举（dialogue/utility/agent + image/speech/video） | ····· |  |
| EP-225 | GET /api/v1/relations | relation · 关系边列表 | ····· |  |
| EP-226 | GET /api/v1/relations/neighborhood | relation · 某实体邻域子图 | ····· |  |
| EP-227 | GET /api/v1/relgraph | relation · 全关系图 | ····· |  |
| EP-228 | GET /api/v1/catalog | catalog · 目录/模板清单 | ····· |  |
| EP-229 | GET /api/v1/tools | tools · 可授权内置工具目录 `{name, summary}`（有界不分页） | ····· |  |
| EP-230 | GET /api/v1/limits | limits · 机器级活动运行上限 | ····· |  |
| EP-231 | GET /api/v1/limits/schema | limits · 逐字段 default/min/max/unit/desc 元数据 | ····· |  |
| EP-232 | PATCH /api/v1/limits | limits · 部分合并更新并热换（越界 400） | ····· |  |
| EP-233 | POST /api/v1/limits:reset | limits · 恢复服务端 Default() 并热换 | ····· |  |
| EP-234 | GET /api/v1/health | system · liveness 探针（免 workspace，不免 bearer） | ····· |  |
| EP-235 | GET /api/v1/version | system · 构建版本 `{version}`（免 workspace） | ····· |  |
| EP-236 | GET /api/v1/system/data-dir | system · 解析后的数据目录 `{dataDir}` | ····· |  |
| EP-237 | GET /api/v1/network | system · 出站代理配置读 | ····· |  |
| EP-238 | PATCH /api/v1/network | system · 出站代理配置整体替换并应用 env | ····· |  |
| EP-239 | GET /api/v1/retention | system · run 保留天数（恒具体值，默认 90） | ····· |  |
| EP-240 | PATCH /api/v1/retention | system · 部分合并保留策略并踢一趟清理（0=永久） | ····· |  |
| EP-241 | GET /api/v1/storage-stat | storage · 库 + 附件两存储字节盘点（零参数单对象） | ····· |  |
| EP-242 | POST /api/v1/storage:compact | storage · 同步全量 VACUUM，200 返 `{reclaimedBytes,migrated}` | ····· |  |
| EP-243 | GET /api/v1/notifications | notification · 通知 keyset 分页（最新在前） | ····· |  |
| EP-244 | GET /api/v1/notifications/unread-count | notification · 未读计数（徽标对账源） | ····· |  |
| EP-245 | POST /api/v1/notifications/{id}:mark-read | notification · 单条标已读 | ····· |  |
| EP-246 | POST /api/v1/notifications:mark-all-read | notification · 批量标已读（可选 `{after?,before?}` 半开窗） | ····· |  |
| EP-247 | POST /api/v1/notifications:mark-all-unread | notification · 批量标未读（mark-all-read 镜像），204 | ····· |  |
| EP-248 | POST /api/v1/executions/{id}:triage | aispawn · 按 execId 前缀开 AI 诊断对话，202 返 conversation id | ····· |  |
| EP-249 | GET /api/v1/messages/stream | stream(SSE) · 聊天消息 SSE 流（open→delta*→close） | ····· |  |
| EP-250 | GET /api/v1/entities/stream | stream(SSE) · 实体面板活动 SSE 流（含 ephemeral Signal） | ····· |  |
| EP-251 | GET /api/v1/notifications/stream | stream(SSE) · 通知 SSE 流 | ····· |  |
| EP-252 | GET /debug/pprof/ | debug(dev-only) · pprof Index 子树（goroutine/heap/allocs/block…） | ····· |  |
| EP-253 | GET /debug/pprof/cmdline | debug(dev-only) · 进程命令行 | ····· |  |
| EP-254 | GET /debug/pprof/profile | debug(dev-only) · CPU profile | ····· |  |
| EP-255 | GET /debug/pprof/symbol | debug(dev-only) · 符号解析 | ····· |  |
| EP-256 | GET /debug/pprof/trace | debug(dev-only) · 执行 trace | ····· |  |
| EP-257 | GET /debug/stats | debug(dev-only) · 运行时快照 JSON（goroutines/heap/GC…） | ····· |  |

## 前端面全集(114)

| ID | 项 | 摘要 | 五级 | 证据 |
|---|---|---|---|---|
| SURF-001 | shell/startup-gate | screen · 后端 phase 门控面:连接中 / 崩溃可重试 / 就绪显壳,整 app 单点。 | ····· |  |
| SURF-002 | shell/workspace-gate | screen · 冷启动工作区名册解析中的「准备工作区」面,扣住 Router。 | ····· |  |
| SURF-003 | shell/workspace-onboarding | screen · 零工作区单页创建面:左 Rijksmuseum 画作 + 右恒宽 460 决策列 + 真 AnComposer。 | ✓✓✓✓✓ | L1:G1→/tmp/anselm-rig-formal-20260801-3/evidence/edge-325-onboarding.png; L2:F1→/tmp/anselm-rig-formal-20260801-3/evidence/first-slice-observations.txt; L3:B2→/tmp/anselm-rig-formal-20260801-3/evidence/visual-stability-final.txt; L4:C2→/tmp/anselm-rig-formal-20260801-3/evidence/edge-325-onboarding.png; L5:G1→/tmp/anselm-rig-formal-20260801-3/evidence/edge-325-onboarding.png |
| SURF-004 | shell/ocean-switcher | rail · 左岛顶部四海洋图标钮 + matched-geometry 滑动药丸,settings 时无选中。 | ····· |  |
| SURF-005 | shell/sidebar-footer | rail · 左岛底栏:workspace 快捷菜单 + 设置格 + 通知格(红点)。 | ····· |  |
| SURF-006 | shell/ocean-breadcrumb-head | screen · 海洋浮层头 44px 透明带:reopen 钮 + OceanBreadcrumb 标题 + panel-right 钮。 | ····· |  |
| SURF-007 | shell/notice-band | screen · 顶带消息舞台:AnNoticeCapsule / AnApprovalCapsule 居中 + 右缘队列尾巴。 | ····· |  |
| SURF-008 | shell/notification-tray | rail · 铃接管左岛中段:搜索 + ⚙ + 今天/昨天/更早三时段可折叠组。 | ····· |  |
| SURF-009 | shell/flowrun-inbox | rail · 铃托盘顶部「待你处理」审批带:parked 卡 + Approve/Reject。 | ····· |  |
| SURF-010 | chat/landing | screen · 无选区新对话面:静态问候 h2 + 居中浮起 composer,首发建线程并导航。 | ✓✓✓✓✓ | L1:G1→/tmp/anselm-rig-formal-20260801-3/evidence/chat-landing.png; L2:F1→/tmp/anselm-rig-formal-20260801-3/evidence/first-slice-observations.txt; L3:B2→/tmp/anselm-rig-formal-20260801-3/evidence/visual-stability-final.txt; L4:C2→/tmp/anselm-rig-formal-20260801-3/evidence/chat-landing.png; L5:G1→/tmp/anselm-rig-formal-20260801-3/evidence/chat-landing.png |
| SURF-011 | chat/transcript | screen · `/chat/:id` 对话正文流 + 停靠 composer,按会话 key 换台。 | ✓✓✓✓✓ | L1:G1→/tmp/anselm-rig-formal-20260801-3/evidence/chat-final.png; L2:F2→/tmp/anselm-rig-formal-20260801-3/evidence/first-slice-observations.txt; L3:A5→/tmp/anselm-rig-formal-20260801-3/evidence/visual-stability-final.txt; L4:C5→/tmp/anselm-rig-formal-20260801-3/evidence/chat-final.png; L5:G1→/tmp/anselm-rig-formal-20260801-3/evidence/chat-final.png |
| SURF-012 | chat/composer | screen · 停靠输入器:附件/@ mention/工作目录钮/git 动作/发送键两档。 | ✓✓✓✓✓ | L1:G1→/tmp/anselm-rig-formal-20260801-4/evidence/composer-mention-final.png; L2:F2→/tmp/anselm-rig-formal-20260801-4/evidence/composer-surface-session-summary.txt; L3:A5→/tmp/anselm-rig-formal-20260801-4/evidence/composer-surface-session-summary.txt; L4:C4→/tmp/anselm-rig-formal-20260801-4/evidence/composer-mention-final.png; L5:G2→/tmp/anselm-rig-formal-20260801-4/evidence/composer-mention-candidate.png |
| SURF-013 | chat/toc | screen · 场次条:全量 keyset 分页锚点列,任意深度不静默截断。 | ✓✓✓✓✓ | L1:G1→/tmp/anselm-rig-formal-20260801-5/evidence/toc-full-list.png; L2:F2→/tmp/anselm-rig-formal-20260801-5/evidence/toc-surface-session-summary.txt; L3:B2→/tmp/anselm-rig-formal-20260801-5/evidence/toc-jump-present.png; L4:C4→/tmp/anselm-rig-formal-20260801-5/evidence/toc-full-list.png; L5:G2→/tmp/anselm-rig-formal-20260801-5/evidence/toc-full-list.png |
| SURF-014 | chat/log-drawer | screen · 共享日志抽屉:计行标签 + 双端截断 + 全量复制 + MCP stderr 分段。 | ✓✓✓✓✓ | L1:G1→/tmp/anselm-rig-formal-20260801-8/evidence/surf-014-session-summary.txt; L2:F2→/tmp/anselm-rig-formal-20260801-8/evidence/surf-014-session-summary.txt; L3:A5→/tmp/anselm-rig-formal-20260801-8/evidence/surf-014-session-summary.txt; L4:C4→/tmp/anselm-rig-formal-20260801-8/evidence/log-drawer-mcp-dossier.png; L5:G2→/tmp/anselm-rig-formal-20260801-8/evidence/log-drawer-mcp-dossier.png |
| SURF-015 | chat/run-dossier | screen · 一次执行的完整审计卷宗:状态徽 + 溯源 + I/O 机器窗 + 日志抽屉。 | ····· |  |
| SURF-016 | chat/nested-run-pane | screen · Subagent/invoke_agent 卡下的 live E3 嵌套轨迹窗。 | ····· |  |
| SURF-017 | chat/tool-cards | screen · 对话流内联工具卡族(exec/search/todo/trigger/workflow/subagent 等 20+ 皮肤)。 | ····· |  |
| SURF-018 | chat/rail-pinned | rail · 置顶段:跨 residency 的全部 pinned 线程,pin 优先。 | ····· |  |
| SURF-019 | chat/rail-residency | rail · 每个 workDir 一段:目录名即段名,折叠段零取数。 | ····· |  |
| SURF-020 | chat/rail-recents | rail · 不属任何目录的线程,按活动/创建/名称排序。 | ····· |  |
| SURF-021 | chat/rail-states | rail · rail 四态:骨架 / 错误+重试 / 空 / 列表。 | ····· |  |
| SURF-022 | chat/sidestage | inspector · 右岛侧幕 StagePanel:todo 顶行 + 活动委派层 + 落定 Cast 时间三档 + 载更多。 | ····· |  |
| SURF-023 | entities/overview | screen · `/entities` 默认总览:五计数牌 + 关系图预览 + 最近更新 5 行。 | ····· |  |
| SURF-024 | entities/graph | screen · `/entities/graph` 全屏无边框关系图探索态:满幅涟漪焦点星图 + kind 图例过滤。 | ····· |  |
| SURF-025 | entities/detail | screen · `/entities/:kind/:id` 单一 AnPage 文档:OceanHeader + AnTabs(flow) + 720 阅读列同滚。 | ····· |  |
| SURF-026 | entities/tab-overview | screen · 概览 tab:各 kind 量身(function 代码收合 / workflow 图 hero / trigger 四源模板)。 | ····· |  |
| SURF-027 | entities/tab-versions | screen · 版本 tab:全宽粘性手风琴,行内 diff 卡 + 结构化摘要 + 设为活跃版本。 | ····· |  |
| SURF-028 | entities/tab-logs | screen · 日志 tab:ok/failed 聚合 + AnRowDetail 行展开 + loadMore。 | ····· |  |
| SURF-029 | entities/tab-runs | screen · workflow 运行驾驶舱:AnRunBoard + 节点甘特 + run 态图 + 内联节点调试。 | ····· |  |
| SURF-030 | entities/tab-activity | screen · trigger 活动 tab:activations 触发面,firedOnly 过滤。 | ····· |  |
| SURF-031 | entities/tab-dispatch | screen · trigger 派发 tab:firings 运行面,status 过滤 pending/started/skipped/superseded/shed。 | ····· |  |
| SURF-032 | entities/workflow-editor | screen · `/entities/workflow/:id/editor` 全屏无边框图编辑器:满铺画布 + 浮层药丸 chrome。 | ····· |  |
| SURF-033 | entities/rail-overview-row | rail · rail 顶部固定「总览」无头行,无选中即高亮。 | ····· |  |
| SURF-034 | entities/rail-function | rail · Function 折叠段(可执行 Quadrinity)。 | ····· |  |
| SURF-035 | entities/rail-handler | rail · Handler 折叠段,行状态点=运行态。 | ····· |  |
| SURF-036 | entities/rail-agent | rail · Agent 折叠段。 | ····· |  |
| SURF-037 | entities/rail-workflow | rail · Workflow 折叠段,状态点=生命周期/attention。 | ····· |  |
| SURF-038 | entities/rail-control | rail · Control 支撑段(无调试台)。 | ····· |  |
| SURF-039 | entities/rail-approval | rail · Approval 支撑段(运行时第二张脸在铃托盘)。 | ····· |  |
| SURF-040 | entities/rail-trigger | rail · Trigger 支撑段,listener 热→蓝点,头部持 Fire CTA。 | ····· |  |
| SURF-041 | entities/run-terminal | inspector · 右岛实体调试台 v3 JSON-first:身份头 + 速览带 + 编辑器卡 + 工具条 + 最近执行条 + 落定条。 | ····· |  |
| SURF-042 | entities/workflow-editor-inspector | inspector · 图编辑器可收右岛:节点 kind/ref 分层选择器/input 映射/retry/边 port,未选=空态。 | ····· |  |
| SURF-043 | entities/graph-entity-card | inspector · 探索态右岛实体卡:kind 字形 + vN + 描述 + 关系分组 + 打开详情。 | ····· |  |
| SURF-044 | library/draft | screen · 无选区被动着陆草稿编辑器:四空态灰引导,首次编辑才 POST 并认领 id 不重挂。 | ····· |  |
| SURF-045 | library/document | screen · `/documents/:id` AnDocumentEditor 同滚页:头 sliver(面包屑/H1/描述/tags) + AnEditor sliver。 | ····· |  |
| SURF-046 | library/skill-manifest | screen · `/documents/skill/:name` 清单页:标题不可改名、PUT 全覆盖、⋯ 切源码模式。 | ····· |  |
| SURF-047 | library/skill-file-preview | screen · `?file=<rel>` 文件预览族:md 富文本 / 代码 / 图片 / SVG / CSV / 字体 / 信息卡 + 逃生口。 | ····· |  |
| SURF-048 | library/rail-documents | rail · Documents 递归页面树段:全 CRUD + hover [+][⋯] + 拖拽重排 + 空/已写 icon。 | ····· |  |
| SURF-049 | library/rail-skills | rail · Skills 扁平 slug 列段,行 id 加 `skill:` 前缀防撞。 | ····· |  |
| SURF-050 | library/inspector-doc | inspector · 文档右岛:身份头 + 速览带 + 三折叠组(大纲 / 属性 / 反链)。 | ····· |  |
| SURF-051 | library/inspector-skill | inspector · skill 右岛:文件树组(含绑定) → 属性组(表单/allowed-tools 选择器) → 来源组 → 大纲组。 | ····· |  |
| SURF-052 | scheduler/overview | screen · `/scheduler` 全局看板:KPI 牌 → 调度时间轴 → 等你处理 → 正在跑 → 失败聚合,零数据整页教育卡。 | ····· |  |
| SURF-053 | scheduler/workflow-home | screen · `/scheduler/w/:id` 运营主页四段:健康头 → 矩阵区 → run 大表(行内速览卡) → triggers 陈列。 | ····· |  |
| SURF-054 | scheduler/run-flagship | screen · `/scheduler/w/:id/runs/:frId` 单 run 旗舰:卷宗头 + 钉版图 + 甘特 + 台账,一个 URL 选区。 | ····· |  |
| SURF-055 | scheduler/run-relay | screen · `/scheduler/runs/:frId` 仅 id 中转位:解析宿主 workflow 后交棒旗舰。 | ····· |  |
| SURF-056 | scheduler/rail-overview-row | rail · 固定首行 Overview,右缘等人计数徽=rail 唯一数字。 | ····· |  |
| SURF-057 | scheduler/rail-main | rail · 无头主段:曾运行过的 workflow,活动排序 + 单值 meta(运行中/下次点火/上次)。 | ····· |  |
| SURF-058 | scheduler/rail-never-ran | rail · 沉底初始折叠段「未运行 (n)」。 | ····· |  |
| SURF-059 | scheduler/rail-inactive | rail · 再沉一段「停用 (n)」,灰不占状态点位。 | ····· |  |
| SURF-060 | scheduler/run-inspector-dossier | inspector · 右岛无选中脸=运行卷宗:钉结论 + replay 史 + 入口 payload + 全文错误 + :triage。 | ····· |  |
| SURF-061 | scheduler/run-inspector-node | inspector · 右岛选中节点脸=检查器:迭代切换 + 错误 + I/O 树 + 日志深链 + 就地人闸/重放。 | ····· |  |
| SURF-062 | settings/rail-prefs | rail · 目录段「偏好」:通用 / 通知 / 对话。 | ····· |  |
| SURF-063 | settings/rail-resources | rail · 目录段「资源」:模型与密钥 / MCP 服务器 / 记忆 / 沙箱。 | ····· |  |
| SURF-064 | settings/rail-system | rail · 目录段「系统」:工作区 / 存储与日志 / 高级限额 / 网络 / 快捷键 / 关于。 | ····· |  |
| SURF-065 | settings/rail-search | rail · 同一输入框双视图:空查询=三段目录,有查询=设置项级命中列表。 | ····· |  |
| SURF-066 | settings/panel-general | panel · 通用:主题三档 + 缩放六档 + 字体三轴 + 语言双写 + 记住窗口 + 开机自启 + 自动检查更新。 | ····· |  |
| SURF-067 | settings/panel-notifications | panel · 通知:三档级别 + OS/应用内两开关 + 失败崩溃/待审批/需关注三类登记。 | ····· |  |
| SURF-068 | settings/panel-chat | panel · 对话:右岛自动登台三档 + 发送键两档 + webFetchMode + 默认对话模型跳转行。 | ····· |  |
| SURF-069 | settings/panel-models-keys | panel · 模型与密钥(0731 重形):受管免费档卡 + **音色库存卡**(克隆音色 2 槽:列表/删除/「库存不是配额」文案,仅受管档) + 品牌 logo 密钥行… | ····· |  |
| SURF-070 | core/media-viewer | overlay · 媒体放大察看器(0731 新增,WRK-082 B1 人眼验收逼出):图/视频同一 RawDialogRoute chrome(scrim/关闭/Esc/… | ····· |  |
| SURF-071 | settings/panel-mcp | panel · MCP 服务器:空态即市场 + 已装双列品牌卡 + 详情三 tab(工具/调用/stderr) + 手动添加/导入/市场。 | ····· |  |
| SURF-072 | settings/panel-memory | panel · 记忆:名册 + 搜索 + 行内金 pin toggle + 新建记忆推入编辑 + 确认物理删除。 | ····· |  |
| SURF-073 | settings/panel-sandbox | panel · 沙箱:健康门 + 磁盘占用诚实字节 + 运行时装删(五 owner tab) + GC 两步。 | ····· |  |
| SURF-074 | settings/panel-workspaces | panel · 工作区:色点名册(点行热切换) + 新建 AnComposer + 推入编辑(改名/六色/危险区输名删)。 | ····· |  |
| SURF-075 | settings/panel-storage | panel · 存储与日志:数据目录 + 磁盘占用 + 诊断 + Run 历史保留 + 数据库压缩 + 重置偏好 + 出厂重置。 | ····· |  |
| SURF-076 | settings/panel-limits | panel · 高级限额:`GET /limits/schema` 驱动的 group + 字段行,部分嵌套 PATCH + 越界回滚。 | ····· |  |
| SURF-077 | settings/panel-network | panel · 网络:http/https/no_proxy 三字段 + 整体替换 PATCH + 重启注记 AnCallout。 | ····· |  |
| SURF-078 | settings/panel-shortcuts | panel · 快捷键:6 全局命令逐行小帽,点帽录键 + 冲突拒绝 + 单项/全部重置。 | ····· |  |
| SURF-079 | settings/panel-about | panel · 关于:版本区 + 检查更新(GitHub Releases 三面) + 引擎版本 + 诊断 + 字体致谢。 | ····· |  |
| SURF-080 | settings/detail-push | screen · 推入第三级(13 kind):addKey/editKey/sandboxInstall/mcpServer/mcpAdd/mcpImport/mcpMar… | ····· |  |
| SURF-081 | i18n/chat | i18n-group · 683 键:对话海洋全部文案(rail/composer/侧幕/工具卡/turn 动作)。 | ····· |  |
| SURF-082 | i18n/settings | i18n-group · 399 键:13 面板 + 三段目录 + 搜索 + 三域徽全部文案。 | ····· |  |
| SURF-083 | i18n/entities | i18n-group · 302 键:实体海洋 rail/详情/tab/调试台/关系图文案。 | ····· |  |
| SURF-084 | i18n/scheduler | i18n-group · 246 键:调度海洋 rail/Overview/运营主页/run 旗舰文案。 | ····· |  |
| SURF-085 | i18n/library | i18n-group · 125 键:文库海洋 rail/编辑器/skill 表单/右岛三组文案。 | ····· |  |
| SURF-086 | i18n/notifications | i18n-group · 45 键:通知托盘标题/时段组/批量标记/搜索/显示选项。 | ····· |  |
| SURF-087 | i18n/run | i18n-group · 41 键:运行结果、重放、审批等待、flowrun 节点计数文案。 | ····· |  |
| SURF-088 | i18n/feedback | i18n-group · 36 键:信息/成功/警告/错误/确认删除/加载/步骤/标签增删。 | ····· |  |
| SURF-089 | i18n/a11y | i18n-group · 26 键:屏幕阅读器标签(旗标/编辑字段/更多动作/图缩放)。 | ····· |  |
| SURF-090 | i18n/attach | i18n-group · 21 键:附件不可用/重试/上传中/媒体准备失败/取消准备。 | ····· |  |
| SURF-091 | i18n/shell | i18n-group · 14 键:侧栏收展/切面板/海洋/即将推出/设置/通知/工作区回退。 | ····· |  |
| SURF-092 | i18n/ref | i18n-group · 11 键:11 种 ref 药丸类型名(function/handler/workflow/agent/document/conversation/… | ····· |  |
| SURF-093 | i18n/coldStart | i18n-group · 11 键:onboarding 预览/连接中/创建工作区/名称冲突/画作致谢。 | ····· |  |
| SURF-094 | i18n/action | i18n-group · 8 键:编辑/取消/保存/复制/展开/收起/换行/删除通用动词。 | ····· |  |
| SURF-095 | i18n/diff | i18n-group · 7 键:新增/删除/折叠/显示全部/只显变更。 | ····· |  |
| SURF-096 | i18n/startup | i18n-group · 6 键:启动门控连接中/崩溃/重试/错误面文案。 | ····· |  |
| SURF-097 | i18n/graph | i18n-group · 6 键:图节点 kind 词。 | ····· |  |
| SURF-098 | i18n/status | i18n-group · 5 键:idle/run/wait/err/done 五状态词。 | ····· |  |
| SURF-099 | i18n/tree | i18n-group · 3 键:JSON 树非法/循环/更多项。 | ····· |  |
| SURF-100 | i18n/appName | i18n-group · 1 键:产品名 wordmark。 | ····· |  |
| SURF-101 | i18n/markdown | i18n-group · 1 键:图片加载失败提示。 | ····· |  |
| SURF-102 | stage/function | stage · 地层 → OpTicker 三态点 → 活代码窗 → 落定真 diff 徽(before=冻结基线)。 | ····· |  |
| SURF-103 | stage/document | stage · 书脊 + 前缀快进 + R-9 元数据卡 + `[[id]]` 内联药丸解真名。 | ····· |  |
| SURF-104 | stage/workflow | stage · 真画布图生长 + 判别式抽屉;edit ops 在旧图重放,落定对账新鲜真相。 | ····· |  |
| SURF-105 | stage/control | stage · 丝线决策梯 + 透传幽灵 + 否则徽。 | ····· |  |
| SURF-106 | stage/approval | stage · 信笺 + 琥珀插值 + timeout 人话;失败面红标「创建失败·残稿如下」。 | ····· |  |
| SURF-107 | stage/trigger | stage · 四脸(cron/webhook/fsnotify/sensor) + R-16 落定只信 GET + nextFireAt 分钟活钟。 | ····· |  |
| SURF-108 | stage/subagent | stage · 一席一卡:任务名=args.prompt 首行 + ReAct 尾 + 结算双源 + 内联终端活窗 ≤10 行。 | ····· |  |
| SURF-109 | stage/handler | stage · 方法架:set_init_args_schema 键=args,update_method RFC-7396 合并上架,timeout 渲钟词。 | ····· |  |
| SURF-110 | stage/agent | stage · prompt/tools/knowledge/model 四槽全铺,未触槽回全墨,落定 prompt 有界视口内滚。 | ····· |  |
| SURF-111 | stage/skill | stage · 装订台 + allowedTools 琥珀仅在信任门已批时 + $ 占位槽。 | ····· |  |
| SURF-112 | stage/memory | stage · 记忆笺,图钉 REST-only。 | ····· |  |
| SURF-113 | stage/mcp | stage · 接线现场 + 工具货架(仅 install/reconnect/create 的类型化 tools 列表)。 | ····· |  |
| SURF-114 | stage/generic | stage · 第 13 座通用舞台兜底(诚实丝带 + kind 量身体 + poll 型活运行卷);conversation 无舞台、attachment 走展品座。 | ····· |  |

## 难触发/边界路径全集(353)

| ID | 项 | 摘要 | 五级 | 证据 |
|---|---|---|---|---|
| EDGE-001 | 上下文水位 80% 触发 tool_result 换 marker | loop · 单对话灌入大量长 tool_result 直到预测 prompt 达 80% input budget · 保留最新 3 组完整 tool_result 与全部… | ····· |  |
| EDGE-002 | continuation checkpoint 语义压缩 | loop · 清旧 tool_result 后仍超 80%，逼引擎把旧前缀折成结构化 checkpoint · 目标降到 55%，checkpoint 协议完整（不留悬空 t… | ····· |  |
| EDGE-003 | 语义压缩失败落确定性有损 checkpoint | loop · 让 utility 与主模型两条压缩路径都失败（mock 返错） · 回落到明确标注「有损、需 re-fetch」的确定性 checkpoint，回合不炸 | ····· |  |
| EDGE-004 | 权威 context_length 透明恢复 | loop · 让 provider 在尚未产出任何 block 时返结构化 `UPSTREAM_REJECTED.reason=context_length` · 清旧结果、… | ····· |  |
| EDGE-005 | CONTEXT_INPUT_TOO_LARGE 终态 | loop · 自动恢复后最新一条不可再分的输入（超大附件）仍被 provider 拒 · 回合终态 error + `CONTEXT_INPUT_TOO_LARGE`，提示拆… | ····· |  |
| EDGE-006 | DeepSeek active tool chain 切割 | loop · 在 deepseek 路由上压缩一条含 reasoning_content + tool_calls 的长链 · 按完整 assistant / tool gr… | ····· |  |
| EDGE-007 | 工具错误风暴熔断 | loop · 脚本让模型连续 3 轮每个 tool_result 都带 error · `TOOL_ERROR_STORM` 终止回合，UI 可解释、不无限钻牛角尖 | ····· |  |
| EDGE-008 | MaxSteps 耗尽 | loop · 把 `limits.Agent.MaxSteps` 调到 2 并让模型持续要动工具 · stop_reason=max_steps + error_code `… | ····· |  |
| EDGE-009 | 回合总墙钟兜底 | chat · 把 `ChatTurnSec` 调到几秒 + 用一个卡住的工具（不响应的 MCP） · 回合被墙钟切断落终态，isGenerating 复位、不阻塞 grace… | ····· |  |
| EDGE-010 | tool_result 256KiB 硬封顶 | loop · 跑一个不带 head_limit 的巨量 Grep 或话痨 MCP 工具 · 保头部 + 附收窄提示，落库/SSE/prompt 三处都不被打爆 | ····· |  |
| EDGE-011 | 执行组并行下标写入 | loop · 让模型一轮内发多个同 `execution_group` 的工具调用 · goroutine 并发跑、按调用序拍平 block，无乱序无竞态 | ····· |  |
| EDGE-012 | danger 非枚举值 fail-open | loop · 让模型把 `danger` 填成 `"none"` 或省略 · 回落 `safe` 不设闸（fail-open），与 fspath fail-closed 相反 | ····· |  |
| EDGE-013 | ObjectMap 字符串化对象参数 | loop · 让模型把 `run_function.args` 送成 `"{\"points\":6}"` 字符串 · 接受并解出对象；解出数组/数字/非 JSON 仍报错 | ····· |  |
| EDGE-014 | MediaExpander 当轮回喂 | loop · 让 `generate_image` 或 MCP 工具在一步内产出 MediaRef · 以一条追加 user 消息把原生 content part 喂给后续请… | ····· |  |
| EDGE-015 | MCP 非纯 JSON 结果里的 receipt | loop · 让 MCP 返 `[image: …]\n{…receipt…}` 这种「一段话 + receipt」 · 逐 `{` 试解嵌入对象，媒体仍到达模型（只认整串 … | ····· |  |
| EDGE-016 | 生成族产地过滤 | loop · 让 `generate_image` 的 tool_result 被 MediaExpander 收集 · 只回 receipt 不回字节（ADR 0017），… | ····· |  |
| EDGE-017 | deepseek 全文本 parts 坍缩 | llm · 在 deepseek 路由上发一条附件被降级成文本占位的 user 回合 · Parts 以 `\n\n` join 坍缩回字符串 content，避免该对话每回… | ····· |  |
| EDGE-018 | sanitizer 孤儿 tool_call 补 stub | llm · 取消一个正在派发工具的回合后再续聊 · 发送前给孤儿 tool_call 合成 stub 回复，严格 provider 不 400 | ····· |  |
| EDGE-019 | 危险工具人闸阻塞 | loop · 让模型自报 `danger=dangerous`（含花真钱的生成调用） · dispatchWithGate 阻塞等人批，interaction 信号推流、br… | ····· |  |
| EDGE-020 | approve_always 会话白名单 | chat · 对同一 (对话, 工具) 先 approve_always，再触发第二次同工具危险调用 · 第二次直接放行不再问 | ····· |  |
| EDGE-021 | 白名单随对话删除清除 | chat · approve_always 后删除该对话 · `ForgetConversation` 钩子整批清掉，授权不越过删除泄漏在内存 | ····· |  |
| EDGE-022 | 驻地越界写人闸 | loop · 挂驻地的对话里让模型 `Write` 一个驻地子树外的绝对路径 · 无视自报等级强制设闸，载荷多一个 `outsideWorkDir:true`；`approv… | ····· |  |
| EDGE-023 | 越界判定路径解不开 | loop · 让 `Write` 的 args 畸形或无路径字段 · 落回普通 danger 闸（而非静默放行），Execute 自己再拒 | ····· |  |
| EDGE-024 | 驻地只闸写不闸读 | loop · 挂驻地后让模型 Read/Grep 驻地外绝对路径 · 直接放行、绝不设闸（zoom 非牢） | ····· |  |
| EDGE-025 | skill 信任门未批时预授权为空 | skill · 装一个 installed skill 但不 `:approve-tools`，再激活它 · 正文注入、active skill 记名，但 allowed-t… | ····· |  |
| EDGE-026 | allowed-tools 变更重置信任门 | skill · 对已授权的 installed skill 跑 `:update` 且新版改了 allowed-tools · 信任门重置回未授权；未变则授权延续 | ····· |  |
| EDGE-027 | ask_user 无交互用户 | loop · 在 agent invoke / workflow 节点（无 broker）路径上触发 `ask_user` · 503 `ASK_NO_INTERACTIVE… | ····· |  |
| EDGE-028 | interaction 枚举外 action | chat · POST resolve-interaction 传 `"aprove"` 拼错 · 先于 broker 查找 422 `INTERACTION_INVALID… | ····· |  |
| EDGE-029 | 重复 resolve interaction | chat · 同一 toolCallId 连发两次决议 · 第二次 404 `NO_PENDING_INTERACTION`，幂等安全 | ····· |  |
| EDGE-030 | 生成中再 Send | chat · 回合流式期间再 POST 一条消息 · 409 `STREAM_IN_PROGRESS`，不排队 | ····· |  |
| EDGE-031 | 回合收尾期单槽缓冲 | chat · 在压缩检查（可达秒级 LLM 调用）窗口内 Send · 落进单槽缓冲紧随其后被服务；槽已满仍 409 | ····· |  |
| EDGE-032 | convQueue 5 分钟自毁后重建 | chat · 让对话空闲 >5min 再发消息 · 队列拆卸后按需重建，task 不滞留死 channel | ····· |  |
| EDGE-033 | 关页不留 streaming 孤儿 | chat · 回合流式中直接关闭客户端/取消请求 · WriteFinalize 在 Detached ctx 落 blocks + message_stop | ····· |  |
| EDGE-034 | 硬崩溃孤儿回合清扫 | chat · kill -9 后端于流式回合中途，再启动 · boot `SweepOrphans` 逐 workspace 把 pending/streaming 行扫成 … | ····· |  |
| EDGE-035 | 自动标题双预算 | chat · 让标题生成占满 10s `autoTitleTimeout` 后再落盘 · 落盘另取从 detached 新 derive 的 5s 预算，慢步不饿死写入 | ····· |  |
| EDGE-036 | 只发生过一轮的对话标题丢失 | chat · 让首轮 autoTitle 生成成功但落盘失败，且不再发第二轮 · 线程永远叫「New chat」（已知诚实边界，下一轮才补） | ····· |  |
| EDGE-037 | 归档对话发消息自动解档 | chat · 给 archived 线程 POST 消息 · 隐式 unarchive 后照常接收，软失败不挡消息 | ····· |  |
| EDGE-038 | :retry 重生成分支 | chat · 对末回合 POST `:retry` 空 body · supersede 末 assistant、不写新 user 回合、入既有队列重跑 | ····· |  |
| EDGE-039 | :retry 编辑重发分支 | chat · POST `:retry` 带 `content` · supersede 末 user + 其 assistant 两条，新 user 回合保留原附件 id、… | ····· |  |
| EDGE-040 | superseded 指针只挡 LLM 视图 | messages · retry 后用三种 REST 读形态与 `?around=` 读旧版本行 · 旧行照常返回可寻址；只有 `LoadThreadForLLM` 按 `s… | ····· |  |
| EDGE-041 | retryOf 在 close 快照里 | chat · 用第二个客户端在 open 帧之后才连上（或 410 后 replay） · 仅凭 message_stop 的 close 快照即可重建版本链，绝不渲成多出来的一轮 | ····· |  |
| EDGE-042 | retry 尾巴是无回答的 user 行 | chat · 崩溃清扫后线程尾巴是一条没有 assistant 的 user 行，再 `:retry` · 「重生成」自然降级为「把缺的那个回答产出来」 | ····· |  |
| EDGE-043 | retry 写序中断留重复问句 | chat · 在「落新行」与「supersede 旧行」之间杀掉进程 · 屏幕上出现看得见的重复问句（自我修正），绝不从模型视图删掉一次交流 | ····· |  |
| EDGE-044 | retry 非终态尾巴 | chat · 硬崩溃留下 pending/streaming 尾行后立刻 `:retry` · 409 `STREAM_IN_PROGRESS`（耐久状态与内存队列两处门都读） | ····· |  |
| EDGE-045 | retry 的 modelOverride 逐回合 | chat · `:retry` 带 modelOverride 后再看对话头 · 只作用于本回合、绝不回写 `conversations.model_override`，行的… | ····· |  |
| EDGE-046 | fork summary 水位重定基 | chat · 对一条已压缩过的线程在水位**之后**的消息处 `:fork` · 带走 summary 且水位重定基为被折叠 block 中最大的新 seq | ····· |  |
| EDGE-047 | fork 切在水位之前不带 summary | chat · 在 `summary_covers_up_to_seq` 之前的消息处 fork · summary 与水位都不带（否则摘要描述分叉根本没有的历史） | ····· |  |
| EDGE-048 | fork 版本指针 remap | chat · 对一条重试过的线程 fork · `superseded_by` 与 `attrs.retryOf` 双双 remap；被窗切掉的取代者留零值（该行即现行版）、… | ····· |  |
| EDGE-049 | fork parent_block_id 跨消息 remap | chat · fork 一条含 subagent 子树的线程 · 预铸全部新 block id 后再灌行，subagent block 仍挂在其父 tool_call 下 | ····· |  |
| EDGE-050 | fork 血缘源被删 | conversation · fork 后删除源对话 · 两列 id 悬空、UI 只是不显血缘行，无级联无外键 | ····· |  |
| EDGE-051 | 压缩水位幂等键 | contextmgr · 在写 summary 与翻 archived 标记之间杀进程再启动 · 水位是幂等键，重跑不重复计数、不二次折叠 | ····· |  |
| EDGE-052 | 压缩读过滤被取代回合 | contextmgr · 让一个被 retry 掉的回答落进压缩窗口 · 压缩读丢掉被取代版本，否则它会经 summary 回流进此后每次 prompt | ····· |  |
| EDGE-053 | demote 只动 tool_result | contextmgr · 单个 assistant 回合内堆很长的工具链后回合收尾 · 全线程 tool_result 按新旧降 hot→warm→cold，用户原话与大粘贴不截断 | ····· |  |
| EDGE-054 | 附件跨压缩水位 | contextmgr · 让含附件的旧回合被折进 summary · 持久附件 id 写入摘要，后续只能经 `read_attachment` 重读、不编造媒体细节 | ····· |  |
| EDGE-055 | 最近 2 条 message 的 durable 底线 | contextmgr · 构造一条只有两条消息但都极长的线程 · durable summarize 不越过最近 2 条，loop 仍可在 prompt 投影内做 check… | ····· |  |
| EDGE-056 | SSE 410 SEQ_TOO_OLD 重放 | stream · 断开某条流足够久（或灌满 replay 环）后带旧 `Last-Event-ID` 重连 · 410 Gone + `SEQ_TOO_OLD`，客户端全量重拉再续 | ····· |  |
| EDGE-057 | 续传游标三来源 | stream · 分别用 `Last-Event-ID` 头、`?fromSeq`、以及缺/坏值重连 · 头优先 > 查询参 > 缺/坏一律 0（仅实时、不重放） | ····· |  |
| EDGE-058 | durable buffer 满断开卡死订阅者 | stream · 造一个只连不读的 SSE 订阅者并灌 durable 帧到 `bufSize+256` · 发布方关它的 done、幂等断开，不让一个卡死客户端堵死整工作区扇出 | ····· |  |
| EDGE-059 | ephemeral delta 丢弃不背压 | stream · 让 token 级 delta 打满慢订阅者 · seq=0 帧不入环、订阅者满即丢，绝不卡生产者 | ····· |  |
| EDGE-060 | lifecycleResync 六处配对 | frontend · 制造 notifications 流 410 缺口 · chat rail / 对话头 / 实体列表 / 实体详情 / library 树 / skil… | ····· |  |
| EDGE-061 | transcriptResync 不可与 lifecycleResync 互顶 | frontend · 制造 messages 流缺口而 notifications 流完好 · 只有 transcriptResync 能救活态点，两条流的 resync 不… | ····· |  |
| EDGE-062 | overlap serial 推迟 | scheduler · 让 workflow(serial) 有一个在途 run，再打第二次真触发 · 新 firing 留 pending，下个 5s tick 再试，绝不并发 | ····· |  |
| EDGE-063 | overlap skip 丢弃 | scheduler · 同上但策略设 skip · firing 标 `skipped`（中性「未执行」桶、不染红），不建 run | ····· |  |
| EDGE-064 | overlap buffer_one 收敛 | scheduler · 在途 run 期间连打三次触发（策略 buffer_one） · 更早的 pending 全标 `superseded`，只留最新一条 | ····· |  |
| EDGE-065 | overlap replace 抢占 | scheduler · 在途 run 期间再触发（策略 replace） · 先 race-safe 取消在途 run（标 cancelled + 打断 advance）再跑… | ····· |  |
| EDGE-066 | overlap allow_all 并发 | scheduler · 高频触发 allow_all workflow · 多 run 并发跑，池 N=4 封顶子进程扇出 | ····· |  |
| EDGE-067 | 手动 :trigger 绕过 overlap | scheduler · 策略设 replace/buffer_one，连点两次 `:trigger` 或 `trigger_workflow` · 两个手动 run 同时在途… | ····· |  |
| EDGE-068 | 两阶段 drain 背靠背触发 | scheduler · 让同一 workflow 的两条 firing 落在同一 tick 的同一批 · phase-1 顺序 claim+seed 全批、phase-2 才… | ····· |  |
| EDGE-069 | ClaimFiring 事务崩溃回滚 | scheduler · 在 claim+建 run 头+seed 的单事务中途杀进程 · firing 仍 pending，绝无 claimed-但-无-run 的半成品残留 | ····· |  |
| EDGE-070 | approval 人工 vs 超时 first-wins | approval · 让 approval timeout 恰好在人点批准的同一瞬到期 · `ResolveParkedNode` 条件更新首写赢，人工输家 422 `FLO… | ····· |  |
| EDGE-071 | approval 三种超时行为 | approval · 分别配 timeoutBehavior=reject/approve/fail 并等到期 · 各自走 no 分支 / yes 分支 / 让 run 失败 | ····· |  |
| EDGE-072 | approval 显式零时长 | approval · create 时填 `timeout:"0s"` · 422 `APPROVAL_INVALID_TIMEOUT`（会永 park 却不触发；用 `""… | ····· |  |
| EDGE-073 | approval 版本 resolve 失败 | approval · 让收件箱行的钉死 approval 版本解析不出来 · 仅该行缺 `deadline` 键，行本身保持可见可决策 | ····· |  |
| EDGE-074 | run 取消竞态输家 | scheduler · 对一个正在自然落定的 run 打 `:cancel` · 头守卫裁决，输家 422 `FLOWRUN_NOT_CANCELLABLE`、不发第二帧 `… | ····· |  |
| EDGE-075 | 取消赢家收割 parked 审批 | scheduler · 取消一个持 parked 审批节点的 running run · 仅赢家 `CancelParkedNodes` 把 parked 写成 `cance… | ····· |  |
| EDGE-076 | 收割闸破了会造永久停滞子图 | scheduler · 人为让 first-wins 输家也收割（回归验证） · 「有行、却未 completed」挡住重排与全部下游边，`:replay` 也清不掉——必须… | ····· |  |
| EDGE-077 | 被打断的在飞节点不落行 | scheduler · 在一个卡在 LLM 流式/长工具的节点上取消 run · `nodeInterrupted` 伪状态、不写任何行、不发 tick、不误写 failed | ····· |  |
| EDGE-078 | 崩溃恢复 Recover | scheduler · 让 running run 处于半途时 kill -9，再启动 · boot 对每个 running run 入队（非内联）再调一遍 Advance，… | ····· |  |
| EDGE-079 | 恢复后排队戳是新起点 | scheduler · 崩溃恢复一个曾排队的节点 · `ready_at` = 恢复驱动的 walk 时刻，绝不回填伪装无缝 | ····· |  |
| EDGE-080 | :replay 只收 failed | scheduler · 对一个 cancelled run 打 `:replay` · 422 `FLOWRUN_NOT_REPLAYABLE`（cancelled 是终局终态） | ····· |  |
| EDGE-081 | 并发 :replay 守卫 | scheduler · 同一 failed run 同时打两次 `:replay` · `WHERE status='failed'` 守卫使输家匹配 0 行 → 422，赢… | ····· |  |
| EDGE-082 | replay 与保留清理竞速 | scheduler · 让保留清理正要删某终态 run 时打 `:replay` · 删头时重申终态守卫，`:replay` 赢、清理输 | ····· |  |
| EDGE-083 | MaxIterations 栅栏 | scheduler · 写一个 CEL guard 永真的回边循环 · 至多 1001 条循环体行（iteration 0 是前向入口 + 1000 条回边轮）后停 | ····· |  |
| EDGE-084 | 菱形 join 未守 has() | workflow · 造一个读 `X.field` 而 X 在 control 另一分支的汇合节点，跑不选 X 的分支 · 运行时 `no such key` 炸（capab… | ····· |  |
| EDGE-085 | pin 闭包冻结在途 run | scheduler · run 跑到一半时编辑被引用的 function/agent/control · 在途 run 仍跑 pin 住的版本；handler/mcp 活态绑… | ····· |  |
| EDGE-086 | advClosing 关停不跑缓冲 run | scheduler · 队列里堆着 run 时发 SIGTERM · 先置 advClosing、缓冲 run 跳过不执行、保持 Running 待下次 boot Recover | ····· |  |
| EDGE-087 | sendJob 撞已关队列 | scheduler · 让 feeder 在 `StopPool` 的 `close(queue)` 之后 mid-send · recover 兜住 panic、丢弃该入队… | ····· |  |
| EDGE-088 | per-run 单飞 + redrive | scheduler · 对同一 run 并发触发多次 advance · 至多一个 goroutine 在跑，其余置 redrive 标志；ctx 取消后停止再走 | ····· |  |
| EDGE-089 | draining 最后一个 run 结算 | workflow · 有在途 run 时 `:deactivate`，等最后一个 run 落定（或对它 `:cancel`） · draining→inactive 收口，取… | ····· |  |
| EDGE-090 | run 历史保留清理 | scheduler · 把 `runRetentionDays` 调到 1 天并造一批老终态 run · 删头 + 节点行 + 该 run 的四张审计表行；running/p… | ····· |  |
| EDGE-091 | 保留清理后的孤儿深链 | frontend · 点一条 firing/通知里指向已被清理 run 的 flowrunId · 深链 404、呈现端渲孤儿墓碑（诚实后果） | ····· |  |
| EDGE-092 | 磁盘回收闸 | infra/db · 保留清理真删了行后观察文件大小 · 死空间 ≥25% 或 ≥128MiB 才 `incremental_vacuum`，日常 churn 不折腾文件 | ····· |  |
| EDGE-093 | 手动 VACUUM 压缩失败 | storage · 在磁盘接近满时点「压缩数据库」 · 500 `STORAGE_COMPACT_FAILED`，库不动、可重试 | ····· |  |
| EDGE-094 | mode=0 老库升级 | infra/db · 用 auto_vacuum 顺序修复之前建的 dogfood 库跑 `:compact` · 顺带升级到 INCREMENTAL、零丢行、`migrat… | ····· |  |
| EDGE-095 | flowrun-stats 倒挂窗 | scheduler · 传 `until` ≤ `since` · 静默给出空窗结果，不是错误 | ····· |  |
| EDGE-096 | flowrun-matrix 未知 id | scheduler · 传入异 workspace / 不存在的 flowrunIds · 静默缺席（cols 自带键可发现），全未知返三个空列表 | ····· |  |
| EDGE-097 | matrix 多迭代最坏处置 | scheduler · 造一个第 3 轮 failed、第 5 轮 completed 的 loop 节点 · 格取最坏 `failed`（不是最后一轮）；cancelled… | ····· |  |
| EDGE-098 | activity 排队段负值 | scheduler · 对一个 `:replay` 过的 run 读 `/activity` · 旧审计尝试行可早于新真相行 readyAt，呈现端把排队段钳制 ≥0 | ····· |  |
| EDGE-099 | flowruns 两种分页互斥 | scheduler · 同时给 `?cursor` 与 `?offset` · 422 `FLOWRUN_LIST_CURSOR_OFFSET_CONFLICT`，绝不静默择一 | ····· |  |
| EDGE-100 | LLM 工具 flowrun 节点封顶 | workflow · 让 `get_flowrun` 打在一个数千行的长 loop run 上 · 封顶 80 节点（保全部非 completed + 最近尾巴）+ `nod… | ····· |  |
| EDGE-101 | misfire 记账不补跑 | trigger · 后端停机跨过若干 cron 刻度后启动 · 每个错过刻度落一条 `missed` firing（created_at 回拨到刻度本身），绝不补跑 | ····· |  |
| EDGE-102 | 睡眠期 misfire（进程仍活） | trigger · 让笔记本睡一小时再醒（进程未重启） · 1min ticker 的 SweepMisfires 发现并记账，无重启也不漏 | ····· |  |
| EDGE-103 | 窗口上界留容差尾带 | trigger · 让一个刻度恰落在 now 前 2min 的 `MisfireTolerance` 尾带内 · 本趟不记 missed（否则占掉 dedup 键让真 fir… | ····· |  |
| EDGE-104 | hotSince 下界 | trigger · 重启后立刻打开面板问「我错过什么了」 · 重启自己错过的刻度立刻入账（hotSince 及之前的刻度已死），不等两分钟 | ····· |  |
| EDGE-105 | AttachReplay 零值纪元 | trigger · boot 重放挂载 vs 运行中 0→1 实时挂载 · 前者盖零值纪元故为其记停机缺口；后者盖 now、绝不记挂载前的账 | ····· |  |
| EDGE-106 | 暂停期间的错过不算 misfire | trigger · 暂停一个 cron trigger 数小时后 `:resume` · 窗被闭合但不产生任何 missed 行（暂停是用户意志、非事故） | ····· |  |
| EDGE-107 | catchup_one 补一个 | trigger · 配 `misfirePolicy:catchup_one` 后停机跨多个刻度再启动 · 只对本趟真落账的最近一个刻度补跑（`RequeueMissedFi… | ····· |  |
| EDGE-108 | catchup_one 崩溃窗不重跑 | trigger · 在扇出已提交、水位未推进之间杀进程再启 · 已入账刻度（dedup 命中）不许再补，绝不把同一刻度跑第二遍 | ····· |  |
| EDGE-109 | misfire 台账双封顶 | trigger · 用 `* * * * *` 的 trigger 跨一周关机后启动 · 每 trigger 单趟至多 200 条（留最近的）+ 遍历封 30d，水位仍跳到窗… | ····· |  |
| EDGE-110 | 睡醒伪 fire 吸附/丢弃 | trigger · 让 robfig 在睡醒时补送一次过期回调 · `snapTick` 吸附到 2min 内最近刻度；无此刻度即判墙钟跳变丢弃（绝不隐式补跑） | ····· |  |
| EDGE-111 | AppendFiring 撞键返已存在行 | trigger · 让同一刻度在 missed 已记后又真 fire · 按返回行 status 分流：missed 经 Requeue 救回 pending 并计数，终态行… | ····· |  |
| EDGE-112 | shed 孤儿 firing | trigger · 在 firing pending 期间删掉监听它的 workflow · claim 时见 `WORKFLOW_NOT_FOUND` 即终态 shed，不… | ····· |  |
| EDGE-113 | sensor 电平触发风暴 | trigger · 让 sensor 条件持续为真跨多个 poll 周期 · 每 poll 都 fire 一条新 firing（非边沿），alert-storm 由 work… | ····· |  |
| EDGE-114 | trigger 暂停在源头注销 | trigger · `:pause` 一个 cron/webhook/fsnotify/sensor trigger · cron 摘 entry / webhook 路径 … | ····· |  |
| EDGE-115 | 暂停时 :fire 大声拒 | trigger · 对已暂停 trigger 打 `:fire` 或 `fire_trigger` · 422 `TRIGGER_PAUSED`，agent 与 UI 都绕不… | ····· |  |
| EDGE-116 | resume 的 Register 失败回滚 | trigger · 让 source 在 `:resume` 时拒绝起来（端口占用/路径不存在） · 持久开关翻回 paused=true、错误上抛，可再按一次重试（绝不留 … | ····· |  |
| EDGE-117 | Edit 与 :pause 并发 | trigger · agent 在改 trigger 的同时用户按 ⏸ · Edit 走定点 UPDATE 只写 name/desc/config/outputs，绝不整行 … | ····· |  |
| EDGE-118 | 暂停期间的 Edit 何时生效 | trigger · 暂停 → Edit 改 cron 表达式 → `:resume` · 暂停期不热更，resume 用当前 config 重注册 | ····· |  |
| EDGE-119 | webhook 路径改后旧路径 | trigger · Edit 改 `config.path` 后打旧 URL · catch-all registry miss → 404（mux 永不增长、无 per-t… | ····· |  |
| EDGE-120 | webhook HMAC 不匹配 | trigger · 配 `signatureAlgo:hmac-sha256-hex` 后发错签名 · 401 纯文本响应（不走标准 envelope） | ····· |  |
| EDGE-121 | webhook 分钟桶去重 | trigger · 一秒内重放同一 body 三次，下一分钟再发一次 · 秒级网络重试折叠成一条；下一分钟同 payload 照常触发 | ····· |  |
| EDGE-122 | fsnotify 秒桶去重 | trigger · 用编辑器保存一次（产生事件突发） · path+op+秒桶折叠成一条 firing，eventKind 归一为配置词汇小写 | ····· |  |
| EDGE-123 | 暂停时 nextFireAt 缺席 | trigger · 读一个已暂停 cron trigger 的行 · `listening=false` 且 `nextFireAt` 键缺席（给时间戳即撒谎） | ····· |  |
| EDGE-124 | envfix 自愈循环 | function · 声明一个装不上的依赖（拼错包名）并 create function · LLM 改依赖重试 ≤3 次，尝试/修复行 tee 到 entities 流 b… | ····· |  |
| EDGE-125 | envfix 拒绝丢包修复 | function · 让 LLM 的「修复」把声明依赖列表缩到原始数量以下 · 拒绝该建议、env 保持 failed + 真实装错，绝不产出缺包的绿 env | ····· |  |
| EDGE-126 | 未配 utility 模型时的 envfix | function · 清空 utility 场景默认后触发一次装不上 · `OK=false` 结束、stderr 留在 History 上呈给建构 LLM，绝不返 Go e… | ····· |  |
| EDGE-127 | env failed 仍创建成功 | function · 用装不上的依赖建 function 后立刻 `:run` · 实体创建成功且状态可见；run 时才 422 `FUNCTION_ENV_NOT_READY` | ····· |  |
| EDGE-128 | 空 ops edit 重建 env | function · 对 env failed 的 function 打 `:edit` 空 ops · 只重建 active env、发 `function.env_reb… | ····· |  |
| EDGE-129 | env 被 GC 后重试一次 | function · 跑 `sandbox:gc` 回收掉某 function 的 venv 再执行它 · `ErrEnvNotFound` → 重建 env + 重试一次，… | ····· |  |
| EDGE-130 | 版本 cap 50 trim 回收 venv | function · 对同一 function 连续 edit 51 次 · 硬删最老版本（放过 active）并经 `DestroyEnv` 回收其孤儿 venv | ····· |  |
| EDGE-131 | revert 到很老版本后再 trim | function · revert 到 v1 后再连续 edit 到越过 cap · trim 放过 active（哪怕它是最老的那个） | ····· |  |
| EDGE-132 | function 超时清洗 | function · 把 `FunctionRunSec` 调到 1s 跑一个死循环 function · 返 504 `FUNCTION_RUN_TIMEOUT`（不是裸 … | ····· |  |
| EDGE-133 | function 媒体产物声明 | function · 让 function 写 `chart.png` 并返 `{"chart": {"$media": "chart.png"}}` · 就地替换成 Med… | ····· |  |
| EDGE-134 | 产物路径逃逸 | function · 声明 `{"$media": "../../.ssh/id_rsa"}` · `fspath.Inside` fail-closed 在打开任何东西之前拒 | ····· |  |
| EDGE-135 | 产物四道闸逐件失败 | function · 声明一个 40MiB 的图 + 一个伪装成 .png 的 shell 脚本 · 逐件拒绝写进 logs、声明原样留下，绝不弄废一次算对了的运行 | ····· |  |
| EDGE-136 | 无 uploader 时的产物声明 | function · 在只跑 REST 的装配/测试下声明产物 · 声明原样通过、不建目录，绝不新增失败模式 | ····· |  |
| EDGE-137 | handler spawn 单飞 | handler · 让 chat 一轮并行发多个 `call_handler` 打在冷 handler 上 · 共享一次 in-flight spawn，不重复付 env+进… | ····· |  |
| EDGE-138 | handler 孤儿 config key | handler · 先配一个 init arg，再 edit 掉该 arg 的 schema，然后调用 · spawn 咽喉按 active schema 过滤掉孤儿 key… | ····· |  |
| EDGE-139 | handler config 不完整 | handler · 建 handler 后不配必填 init arg 就调用 · `HANDLER_CONFIG_INCOMPLETE`、不 spawn，且仍记一条 fail… | ····· |  |
| EDGE-140 | handler ctx 取消 = 管道脏 | handler · 在一次 RPC 等待中取消回合 · 客户端标 crashed、废弃实例（下次 Get 自动重生），这是协议正确性不是 bug | ····· |  |
| EDGE-141 | handler generator 终值两写法 | handler · 分别用 `yield 终值` 和 `return 终值` 写 method · 两种都生效（driver 捕 `StopIteration.value`）… | ····· |  |
| EDGE-142 | handler traceback 不被剥 | handler · 让 method 内抛 Python 异常 · traceback 进错误 Details（非 fmt 包裹），agent/flowrun 路径读到的不是… | ····· |  |
| EDGE-143 | handler 注入 secret 掩码三面 | handler · 让 method 把 sensitive init-arg 值 print 出来并抛进 traceback · 实时错误面 / logs / 审计副本三处… | ····· |  |
| EDGE-144 | handler 空 ops edit 抹内存态 | handler · 对有状态 handler 打 `:edit` 空 ops · 重建 env + 重启（内存态丢失），结果带 `restarted:true` + rest… | ····· |  |
| EDGE-145 | handler 纯 meta edit 不重启 | handler · 用 ops 全为 `set_meta` 的 edit 改名 · 只更行、不铸版本、不重启（内存态保住） | ····· |  |
| EDGE-146 | handler 产物目录 chdir 恢复 | handler · 让一次带 `out` 的调用中途 continue/异常退出 · driver 在 try/finally 里恢复 cwd，下一次调用不从已删目录起步 | ····· |  |
| EDGE-147 | handler 同实例并发调用串扰 | handler · 让两次调用同时在同一实例上跑并各自 print · stderr 扇出按窗口归属，明示可能串扰；收尾留 30ms 宽限接住迟到的 print | ····· |  |
| EDGE-148 | 沙箱运行时首用直装 | sandbox · 清空 runtimes 目录后首次跑 python function · 从上游拉钉死版本 tarball、sha256/512 校验、staging 原… | ····· |  |
| EDGE-149 | sandbox bootstrap 失败 degraded | sandbox · 让数据目录不可写导致 bootstrap 失败 · 进 degraded 模式、不挂 boot，`:retry-bootstrap` 可救 | ····· |  |
| EDGE-150 | boot 回收残留 running_pid | sandbox · kill -9 后端时留下活的 sandbox 子进程 · `RestoreOrCleanupOnBoot` 对记录 pid 的整个进程组 SIGKILL… | ····· |  |
| EDGE-151 | boot 回收 run_in_background 孤儿 | shell · kill -9 时留下 `run_in_background` 的 bash · `ReapStaleOnBoot` 按 `<dataDir>/shellpi… | ····· |  |
| EDGE-152 | uvx/npx 孙进程整组杀 | sandbox · 用 uvx 起一个 MCP server 再删它 · 负 pgid SIGKILL 连 python/node 孙进程一同收割 | ····· |  |
| EDGE-153 | env 在用时删除 | sandbox · 对正在被实例占用的 env 打 DELETE · 409 `SANDBOX_ENV_IN_USE`，诚实拒绝 | ····· |  |
| EDGE-154 | agent 挂载撞名 | agent · 挂两个合成后同名的工具（如同名 function 与 handler 方法） · 撞名检测使 invoke 失败；`mount-health` 对称地把第二个… | ····· |  |
| EDGE-155 | agent 挂载目标被删 | agent · create 后删掉被挂的 function/知识文档 · invoke fail-fast 冒具体码；`mount-health` 逐条报 unhealth… | ····· |  |
| EDGE-156 | 离线 MCP 挂载归因 | agent · 让被挂 MCP server 处于 failed/connecting 再 invoke · 报 `MCP_SERVER_DOWN` 而非 `MCP_TOOL… | ····· |  |
| EDGE-157 | agent 声明输出回解析 | agent · 声明 2+ outputs 但让终答是自由文本 · 422 `AGENT_OUTPUT_NOT_STRUCTURED` 大声失败（恰 1 声明则裹进该名） | ····· |  |
| EDGE-158 | agent 非 OK 终态置空输出 | agent · 让声明了 outputs 的 agent 撞 max_steps 或工具风暴 · `Output` 置 nil，绝不留裸叙述冒充声明形状；裸文本仍在 tran… | ····· |  |
| EDGE-159 | sys: 能力工具无路由 | agent · 挂 `sys:generate_image` 但不配任何能出图的 key · ref 不可解析、invoke 大声失败；mount-health 显 Heal… | ····· |  |
| EDGE-160 | agent 墙钟压过自报终态 | agent · 把 `AgentInvokeSec` 调到几秒跑一个慢 agent · ctx DeadlineExceeded 映射 `timeout`（durable、可… | ····· |  |
| EDGE-161 | subagent 墙钟 | subagent · 从一个无父回合 deadline 的路径 spawn subagent · `Spawn` 自套 `ChatTurnSec`，超时收尾 cancelle… | ····· |  |
| EDGE-162 | subagent 深度守卫 | subagent · 让 subagent 试图再派 subagent · `Subagent` 工具总从子集剔除（深度 1） | ····· |  |
| EDGE-163 | get_subagent_trace 隔离 | subagent · 在 subagent 内试图读 subagent trace · 该工具总被 strip，防泄漏父对话的其它 subagent trace | ····· |  |
| EDGE-164 | 被取消的 subagent 落终态 | subagent · 取消父回合时 subagent 正在跑 · 混血 host 在 Detached 上落 message_stop 终态，防孤儿 | ····· |  |
| EDGE-165 | MCP OAuth 全流程 | mcp · 装一个支持 DCR 的 remote server（如 notion/sentry） · 探测 401 → RFC 9728/8414 发现 → DCR 注册公共… | ····· |  |
| EDGE-166 | OAuth refresh 失效 | mcp · 在网关侧吊销 refresh token 后调用该 server · 401 `MCP_OAUTH_REAUTH_REQUIRED`，指路重新授权 | ····· |  |
| EDGE-167 | 自带客户端固定端口被占 | mcp · 装 Box/Entra 类 server 时先占住 47100 · 退随机端口（固定端口只是让用户能注册确定 redirect URI） | ····· |  |
| EDGE-168 | 每租户模板 URL | mcp · 装 Glean 类 `Remote.URLEnv` 条目 · `Plan` 暴露成必填 env，安装时 `expandPlaceholders` 解出真实 URL… | ····· |  |
| EDGE-169 | MCP degraded 态 | mcp · 让某 server 连续 3 次调用失败 · 转 degraded（仍 `IsCallable`、软警告），entities 流发 status 信号变色 | ····· |  |
| EDGE-170 | MCP 连接失败仍落盘 | mcp · PUT 一个连不上的 stdio/remote server · 落盘 `status=failed` + `lastError`，`:reconnect` 可救 | ····· |  |
| EDGE-171 | MCP 媒体逐件 best-effort | mcp · 让 MCP 返多件 image/audio，其中一件落库失败 · 失败件保留占位叙事、其余成为一等附件，绝不失败整个调用 | ····· |  |
| EDGE-172 | 无 uploader 时的 MCP 媒体 | mcp · 在未装配 uploader 的环境跑返图 MCP 工具 · 整体退回占位符（诚实降级） | ····· |  |
| EDGE-173 | MCP name-or-id 双键 purge | mcp · 用 `mcp:<名>/tool` 挂载后再 `RemoveServer` · 按 `srv.ID` 与 `srv.Name` 两键 purge equip 边，不… | ····· |  |
| EDGE-174 | MCP 进度关联 | mcp · 并发跑两个会发 progress 的 MCP 工具 · per-call token 把 session 级 progress 关联回各自的 sink，不串台 | ····· |  |
| EDGE-175 | MCP 失败附 stderr 尾 | mcp · 让一个 stdio server 在调用时崩 · `logs` 附 8KiB server stderr 尾并标注「可能早于本次调用」 | ····· |  |
| EDGE-176 | MCP 市场缺必填 env | mcp · 从市场装一个需要 token 的条目但留空 env · 422 `MCP_ENV_MISSING`（`Plan`→`missingEnv` 结构性堵死静默零认证连接） | ····· |  |
| EDGE-177 | 无可跑 package | mcp · 装一个只有不支持 runtime 包的 registry 条目 · 422 `MCP_NO_RUNNABLE_PACKAGE` | ····· |  |
| EDGE-178 | 搜索 embedder 缺席降级 | search · 把 `embedder` 设为 `off`（或让 builtin 下载失败） · 恒混合管线自动降级成纯词法 BM25 结果，检索模式无配置、无报错 | ····· |  |
| EDGE-179 | 首用下载途中关停 | search · 在 builtin embedder 首次拉 ~600MB 模型时发 SIGTERM · `Close(ctx)` 由关停 ctx 限界、中止安装 ctx … | ····· |  |
| EDGE-180 | embedder 孤儿回收 | search · kill -9 后端留下 ~2GB llama-server 再启动 · 按 `runtimes/llamasrv/embedder.pid` best-e… | ····· |  |
| EDGE-181 | 整批 embed upsert 全失败 | search · 让向量表写入全失败（盘满/表损） · 中止本轮等下次 kick，绝不进无限重嵌热循环 | ····· |  |
| EDGE-182 | cosineFloor 噪声闸 | search · 用一段乱码 query 搜一个有 8 个实体的 workspace · 余弦 <0.55 全被挡，绝不按噪声灌全 workspace | ····· |  |
| EDGE-183 | 换 embedder 重嵌 | search · 从 builtin 切到 ollama · 旧模型行对新模型即「缺向量」自动重嵌，绝不混用；向量缓存整体 invalidate | ····· |  |
| EDGE-184 | 短词 LIKE 回退 | search · 用 2 个字符的 query 搜 · trigram 零命中 → 短词 LIKE 回退；长短混合时长 token 走 MATCH、短 token 叠 LIKE | ····· |  |
| EDGE-185 | 异查询游标 | search · 拿 A 查询的 cursor 去翻 B 查询 · 400 `SEARCH_CURSOR_INVALID`，绝不切错窗口 | ····· |  |
| EDGE-186 | :reindex 并发与就地重建 | search · 同 workspace 连打两次 `:reindex`，期间并发 Search · 第二次 409 `SEARCH_REINDEX_RUNNING`；重建期… | ····· |  |
| EDGE-187 | fts_schema_version 不匹配 | search · 改 schema 版本后启动 · boot 清空全量重建（索引从不原地迁移） | ····· |  |
| EDGE-188 | 密文红线 | search · 建带 secret 的 api key / mcp config / trigger config 后全文搜其值 · 零命中——经 Encryptor 落盘… | ····· |  |
| EDGE-189 | Changed 队满丢事件 | search · 短时间批量写实体打满非阻塞投递队列 · 溢出丢弃，boot 对账（stamps 比对 + 孤儿清理）兜底自愈 | ····· |  |
| EDGE-190 | sifter 缺席回退 | search · 清掉 utility 模型后跑 `search_blocks` · 回退纯索引排序（三段精度链第③段），对调用方透明 | ····· |  |
| EDGE-191 | 附件 sandbox 提取路径 | attachment · 上传一个 .docx/.odt 并 @ 进对话 · 走共享 python env 的一次性抽取脚本、400K char 截断内联（NativeDoc… | ····· |  |
| EDGE-192 | 不认的 mime 抽取 | attachment · 上传一个抽取器不认的二进制文档 · 415 `ATTACHMENT_EXTRACTION_UNSUPPORTED` → 降级成明确文字占位，回合不失败 | ····· |  |
| EDGE-193 | 模型能力缺失诚实降级 | attachment · 把默认对话模型换成无 vision 的模型再发图 · 按原顺序降成明确文字占位（不丢附件、不假装看得见） | ····· |  |
| EDGE-194 | 单回合媒体额度耗尽 | attachment · 一条消息附超过 `MaxMediaParts`/`MaxMediaBytes` 的图 · 超额部分降级成文字占位，其余仍原生递交 | ····· |  |
| EDGE-195 | 不可交付格式（HEIC/AVIF） | attachment · 在受管 Anselm 路由下发一张 HEIC · 上传**之前**判定为不可交付、降级成点名文件与格式的注记，不中断整回合 | ····· |  |
| EDGE-196 | 受管 remote media lease | attachment · 在受管路由下发一张图并观察线缆 · 经 device-proof resumable upload 取短期 lease，传**相对** fetch … | ····· |  |
| EDGE-197 | lease 临期刷新 | attachment · 让同一附件在一次长 ReAct 里跨过 lease 过期前 30s · 自动重传刷新，同一可用字节不重复上传；重启不保留 bearer | ····· |  |
| EDGE-198 | staging 失败大声失败 | attachment · 让受管 staging 端点返错 · 本回合大声失败，绝不静默丢媒体（与「不可交付格式降级」语义刻意不同） | ····· |  |
| EDGE-199 | 代理图未 ready | attachment · 上传大图后立刻发送 · 本回合最多短暂等待本地 worker 产出 `model-default` v2 代理，超时退回原件、后台继续追上 | ····· |  |
| EDGE-200 | blob GC 只在 boot 跑 | attachment · 上传大量附件后删除，再重启 · boot 逐 workspace 按活跃 sha 保留集回收；删除时不扫描（会与在飞上传的 Put 竞态） | ····· |  |
| EDGE-201 | 缺失/不可读 blob | attachment · 手工删掉某个 blob 文件后重放该回合 · 告警跳过、绝不让回合失败 | ····· |  |
| EDGE-202 | audio playback token 过期 | attachment · 签发 playback-lease 后等它过期再 fetch · 404；token 仅内存保存、绑 workspace/attachment，支持… | ····· |  |
| EDGE-203 | 非 audio 签发 playback | attachment · 对一张图打 `:playback-lease` · 415 `ATTACHMENT_PLAYBACK_UNSUPPORTED` | ····· |  |
| EDGE-204 | 朗读缓存命中 | readaloud · 对同一段文本+音色连按两次朗读 · 第二次 `cached=true`、命中在合成之前判定，`SpeechInputs()` 不多一条（零上游花费） | ····· |  |
| EDGE-205 | 朗读缓存 LRU 淘汰 | readaloud · 朗读到超过 per-workspace 50MB 预算 · 按 `last_used_at` 物理删缓存行（D1 第三个例外），其附件软删、blob … | ····· |  |
| EDGE-206 | 朗读长度上限 | readaloud · 提交 >4000 rune 的文本 · 400 `READALOUD_TEXT_TOO_LONG` | ····· |  |
| EDGE-207 | 朗读可用性诚实缺席 | readaloud · 清掉所有能说话的 key · `/read-aloud/availability` 返 false → 前端根本不给按钮（探测失败也自吞成 false… | ····· |  |
| EDGE-208 | origin_tool_call_id 收窄展开 | attachment · 让模型在 tool_result 里回显一个**不是**本次调用铸出的 att_ id · `ToolResultContentParts` 只展开… | ····· |  |
| EDGE-209 | 附件无保留线 | attachment · 让附件积累数月 · 永不自动删除（裁定：删除不可逆、不删可逆），容量治理走带预览的手动清理 | ····· |  |
| EDGE-210 | 免费档配额耗尽 | freetier · 把受管档用到网关返 402 / 流内 `BUDGET_EXHAUSTED` · `LLM_QUOTA_EXHAUSTED`（429，Code 与 RAT… | ····· |  |
| EDGE-211 | 网关 install 自愈 | freetier · 在网关侧清库/吊销 install 后点设置页「修复」 · 探测见 `INVALID_INSTALL` → 重新登记设备 + `RotateManage… | ····· |  |
| EDGE-212 | 瞬时失败绝不轮换 | freetier · 断网/让网关限流后点「修复」 · 不轮换凭证（离线/限流/网关重启绝不毁掉好 install），失败留日志、行保持原样 | ····· |  |
| EDGE-213 | 未开通读配额 | freetier · 在 in-memory/测试模式或 provision 仍 pending 时读 `/freetier/quota` · 404 `FREETIER_N… | ····· |  |
| EDGE-214 | 开通降级不挂 boot | freetier · 无机器指纹 / install 失败 / 持久化冲突 · 每个失败路径 log 并返 nil，免费档缺席绝不挂 boot 或 onboarding | ····· |  |
| EDGE-215 | 受管 key 不可变 | apikey · 对受管 `anselm` 行打 PATCH 或 DELETE · 均 422 `API_KEY_IMMUTABLE`（删除会割裂安装身份与配额历史，零引用也… | ····· |  |
| EDGE-216 | 被引用的 key 拒删 | apikey · 删一个被 scenario 默认 / 搜索默认 / agent override 引用的 key · 422 `API_KEY_IN_USE` + `det… | ····· |  |
| EDGE-217 | 旋转 key 重探失败 | apikey · PATCH 换新 key 值但让重探针失败 · PATCH 仍成功（旋转已完成），只是 testStatus 反映失败，不脑裂 | ····· |  |
| EDGE-218 | 播种只填未设 | freetier · 用户先手动设了 dialogue 默认，再触发受管播种 · `SeedDefaultsIfUnset` 只填仍未设的 scenario，绝不覆盖显式选择 | ····· |  |
| EDGE-219 | native knob 校验 | model · 给 modelRef 的 `options` 填一个该模型没有的旋钮 / 非法值 · 422 `MODEL_OPTION_UNSUPPORTED` / 400… | ····· |  |
| EDGE-220 | 未探测/custom 模型 | model · 用一个 custom provider 的未探测 modelId 且 options 为空 · 不做硬目录校验，保留 invoke 时 fail-loud | ····· |  |
| EDGE-221 | 写时校 apiKeyId 存在性 | model · 把 conversation/agent override 或 workspace 默认指向不存在的 key · 立刻 `API_KEY_NOT_FOUND`… | ····· |  |
| EDGE-222 | 生成 origin 从凭证派生 | llm · 用新加坡区 DashScope key 触发视频/图片生成 · 从凭证聊天 base 剥 `/compatible-mode/v1` 得生成 origin，绝不硬… | ····· |  |
| EDGE-223 | 视频轮询超时诚实话 | llm · 让视频任务超过轮询上限 · 503 `VIDEO_GEN_FAILED`，消息含「上游任务可能仍会完成」的诚实话，无假进度百分比 | ····· |  |
| EDGE-224 | 不可能的生成组合钳制 | llm · 向 Veo 要 15 秒视频 · 客户端钳到该路由做得到的长度，receipt 报**真正做出来**的那个 | ····· |  |
| EDGE-225 | 能力工具诚实缺席 | chat · 清掉所有能出图的 key 后看工具集 · `generate_image` 不注入（逐请求重估，与 generate_speech 各自判定）；硬调则 422 … | ····· |  |
| EDGE-226 | 受管档视频路由 | freetier · 只有受管 key 时调 `generate_video` · 受管播种含 video(WRK-082 H1 翻案):经网关签名句柄提交→轮询→取回,真生… | ····· |  |
| EDGE-227 | 语音配额与限流分流 | speech · 让网关分别返 QUOTA/BUDGET/INSTALL_CAP、RATE_LIMITED/UPSTREAM_BUSY、ACCOUNT_BANNED · 分别… | ····· |  |
| EDGE-228 | ASR sidecar 无受管凭证 | speech · 清掉受管行后开语音输入 · 503 `SPEECH_UNAVAILABLE`（语音只走默认 Anselm Auto，不拿 BYOK 做适配） | ····· |  |
| EDGE-229 | 多块 TTS PCM 拼接 | llm · 朗读一段超过单请求上限（qwen ~500 字符 / 智谱 1024）的长文本 · 在 PCM 层重接（非按字节追加 WAV），格式不一致大声拒绝而非静默变调 | ····· |  |
| EDGE-230 | ParseWAV 遍历 chunk 表 | llm · 用一个夹带 LIST/fact chunk 的 WAV · 遍历 chunk 表而非假定 44 字节头，元数据不被当成样本 | ····· |  |
| EDGE-231 | 断网启动 | bootstrap · 拔网线后冷启动 · 免费档 provision 失败留 nil、modelcatalog 刷新失败静默留 vendored/缓存、更新检查沉默，app… | ····· |  |
| EDGE-232 | 模型目录运行时刷新失败 | llm · 让 boot 后 30s 的 models.dev 刷新失败 · 静默留旧（缓存优先于 vendored），能力描述不塌 | ····· |  |
| EDGE-233 | boot 顺序 SweepMisfires | bootstrap · 让 SweepMisfires 早于 ReattachActive 跑（回归验证） · 监听表为空则静默什么都不记——顺序必须严格在 Reattach… | ····· |  |
| EDGE-234 | 三步优雅关停 | bootstrap · 有 3 条常驻 SSE 连接时发 SIGTERM · 先 cancel base 请求 ctx（否则 http.Shutdown 干等满 grace … | ····· |  |
| EDGE-235 | 关停预算格 | bootstrap · 让某子系统在关停时卡住 · shutdownGrace 6s + drainShutdownGrace 2s + 2×WaitDelay 2s 必须嵌… | ····· |  |
| EDGE-236 | 父进程死人开关 | bootstrap · 用 `ANSELM_PARENT_WATCH=1` 起后端后 kill -9 父进程 · stdin EOF 汇入同一 `signal.NotifyC… | ····· |  |
| EDGE-237 | 坏 settings.json | bootstrap · 手工写坏 `<dataDir>/settings.json` 再启动 · boot 失败（缺文件则纯默认） | ····· |  |
| EDGE-238 | settings 三段整体写 | bootstrap · 只 PATCH limits 后检查 network/retention 段 · `persist(limits, network, retentio… | ····· |  |
| EDGE-239 | CHECK 加词整表重建 | infra/db · 用一个旧 schema 的库启动（trigger_firings/flowrun_nodes/message_blocks 三处） · `Migrate… | ····· |  |
| EDGE-240 | ADD COLUMN 结果幂等 | infra/db · 对已加过列的库重复启动 · `duplicate column name` 视作已应用跳过；其他语句的真重复列错仍令整个迁移失败 | ····· |  |
| EDGE-241 | 换 master key 种子 | bootstrap · 改 `ANSELM_MASTER_KEY` 后启动一个已有密文的库 · 既有密文（api key / handler config / mcp con… | ····· |  |
| EDGE-242 | keychain 铸钥只对全新安装 | frontend · 在盘上已有 db 的旧装机上启动 · 绝不硬注新钥；keychain 异常一律退化机器指纹旧径，启动绝不变砖 | ····· |  |
| EDGE-243 | 出厂重置 | frontend · 在设置页输「Anselm」触发出厂重置 · 停 sidecar → 删数据目录 → resetAll → `open -n` 重启 + exit(0) | ····· |  |
| EDGE-244 | bearer token 缺失 | transport · 让前端拿错/丢失 `ANSELM_AUTH_TOKEN` · 401 `UNAUTH_BAD_TOKEN` → 前端显示「重启后端」横幅、**不清 w… | ····· |  |
| EDGE-245 | workspace 头缺失 | transport · 对隔离路由不带 `X-Anselm-Workspace-ID` · 401 `UNAUTH_NO_WORKSPACE` → 前端清 workspace… | ····· |  |
| EDGE-246 | DNS rebinding 防护 | transport · 用非 loopback Host 头打后端 · 403 `FORBIDDEN_BAD_HOST`（常开，仅放行 127.0.0.1/::1/local… | ····· |  |
| EDGE-247 | ServeMux 纯文本 404/405 改写 | transport · 打一个 `/api/v1/` 下不存在的路径 / 用错方法 · 改写成 N1 envelope 的 `ROUTE_NOT_FOUND` / `METH… | ····· |  |
| EDGE-248 | 客户端断连与请求超时 | transport · 中途断开一个长请求 / 让请求超 deadline · `CLIENT_CLOSED`(499) / `REQUEST_TIMEOUT`(504)，从… | ····· |  |
| EDGE-249 | 后台裸 ctx 播种缺失 | bootstrap · 给某个后台入口传裸 `context.Background()`（回归验证） · ws-scoped 查询 500 `MISSING_WORKSPAC… | ····· |  |
| EDGE-250 | workspace 删除级联 | workspace · 删一个有活 workflow / 常驻 handler / MCP / 索引 / 文件树的 workspace · Reaper 杀自动化 → 停实例… | ····· |  |
| EDGE-251 | 删最后一个 workspace | workspace · 只剩一个 workspace 时删它 · 422 `CANNOT_DELETE_LAST_WORKSPACE` | ····· |  |
| EDGE-252 | stats blobBytes 超时 | workspace · 造一棵极大的 blobs 树再读 `{id}/stats` · 500ms 预算内 walk，超时/未接线返 **-1**（诚实未知，绝不假 0） | ····· |  |
| EDGE-253 | 单连接 panic 事务砖化 | orm · 让事务内 panic 且上层在不可取消 ctx 上 recover · `Transaction` 的 defer 回滚保证唯一连接不被永久占住（否则整库砖化） | ····· |  |
| EDGE-254 | keyset 排序切换丢游标 | conversation · 在 `?sort=activity` 翻到第二页后切到 `?sort=name` 继续用旧 cursor · 必须丢弃游标重头翻（游标列随排序列… | ····· |  |
| EDGE-255 | PageAsc collation 不一致 | orm · 让 `.Order()` 或覆盖索引漏掉 `COLLATE NOCASE` · 跨页漏/重行（keyset 不变量对 collation 敏感） | ····· |  |
| EDGE-256 | 驻地目录被移走 | conversation · 挂驻地后在终端里把该目录删掉/改名 · `GET /{id}/workdir` 答 `path` 非空而 `exists=false`（警示态，… | ····· |  |
| EDGE-257 | 脏区切分支被拒 | conversation · 在有未提交改动的驻地里 `:switch-branch` · 422 `CONVERSATION_WORK_DIR_DIRTY`（脏态服务端此刻… | ····· |  |
| EDGE-258 | 新建分支不受脏区门 | conversation · 同样脏状态下 `:create-branch` · 放行（`checkout -b` 从当前 HEAD 起、工作树零变化），这处不对称是刻意的 | ····· |  |
| EDGE-259 | 切分支名拼错 | conversation · `:switch-branch` 传一个只在远端存在的分支名 · 404 `CONVERSATION_BRANCH_NOT_FOUND`——同时… | ····· |  |
| EDGE-260 | 前导 `-` 的合法 ref | conversation · 传分支名 `-foo` · 422 `CONVERSATION_INVALID_BRANCH`（对 git 合法但会被下条命令读成选项） | ····· |  |
| EDGE-261 | worktree 目录已存在 | conversation · 对一个已有 `../Anselm-x` 的名字打 `:add-worktree` · 409 `CONVERSATION_WORKTREE_EX… | ····· |  |
| EDGE-262 | worktree 分支已存在 | conversation · 用 `make worktree-rm` 保留的分支名重开一份 worktree · 复用该分支（与 Makefile 一致）；若已在别处 ch… | ····· |  |
| EDGE-263 | worktree 建成后切驻地失败 | conversation · 让 `:add-worktree` 的最后一步（Service.Update）失败 · 留下完好的 worktree + 仍在原处的线程——可停… | ····· |  |
| EDGE-264 | 「这里没有 git」四情形 | conversation · 分别用未挂 / 已消失 / 普通目录 / 无 git 二进制打三个写动作 · 统一 422 `CONVERSATION_WORK_DIR_NOT… | ····· |  |
| EDGE-265 | 切驻地落 marker 块 | conversation · 对已有消息的线程中途 PATCH 换 `workDir` · 落一个 `{kind:'workdir',from,to}` marker 块（c… | ····· |  |
| EDGE-266 | 空线程/重复 PATCH 不落 marker | conversation · 首发之前挂驻地；或对同一路径重复 PATCH · 均不落标记（没有「之前」；重复是 no-op） | ····· |  |
| EDGE-267 | 切分支不落 marker | conversation · 在同一驻地里切分支 · 驻地没变故不落标记（分支变化活在投影里） | ····· |  |
| EDGE-268 | 驻地分组批量归档重跑 | conversation · 对同一驻地连打两次 `:archive-workdir` · 第二次答 `archived: 0` 且不发回声（只动 `archived=0` 的行） | ····· |  |
| EDGE-269 | 驻地分组批量删除范围 | conversation · 对一个含置顶 + 已归档线程的驻地打 `:delete-workdir` · 跨归档态删、**置顶存活**、消息行分毫不动、文件系统分毫不动（U… | ····· |  |
| EDGE-270 | 空 workDir 批量动作 | conversation · 给 `:archive-workdir` 传 `workDir:""` · 400 `INVALID_REQUEST`（`''` 是正当过滤但不… | ····· |  |
| EDGE-271 | 分组事务交叉核对 | conversation · 让批量语句影响行数与 Pluck 出的 id 数不一致 · 变成一次**回滚的错误**，绝不留下半个归档了的目录 | ····· |  |
| EDGE-272 | 分组计数跨翻页不漂移 | conversation · rail 无限翻页时反复滚动并对比组头计数 · 服务端一次 GROUP BY 算出，workspace 没变则数就不变 | ····· |  |
| EDGE-273 | `?workDir=` 三态 presence | conversation · 分别用缺席 / `?workDir=`（空值）/ `?workDir=<path>` 列表 · 不过滤 / 仅未挂 / 仅该驻地——必须读键 p… | ····· |  |
| EDGE-274 | 立碑线程读消息 | conversation · 删一条对话后 `GET /{id}/messages` · 404 `CONVERSATION_NOT_FOUND`（线缆分不清「行被立碑」与「… | ····· |  |
| EDGE-275 | 文档超 1MB | document · PUT 一篇 >1MB 的正文 · 413 `DOCUMENT_CONTENT_TOO_LARGE`，硬拒、绝不自动拆分 | ····· |  |
| EDGE-276 | 并发同父建文档 | document · 同时对同一 parent 建多个文档 · `InsertAtNextPosition` 单事务 `max(兄弟)+1`，position 不撞车（无 p… | ····· |  |
| EDGE-277 | 文档改名子树级联 | document · 对一棵三层深的子树根改名 · 批量重写全部后裔的物化 `path` | ····· |  |
| EDGE-278 | 文档 Move 防环 | document · 把一个节点挂到自己的后裔下 · 422 `DOCUMENT_INVALID_PARENT` | ····· |  |
| EDGE-279 | 对话挂载的文档被删 | document · PATCH 挂载文档后删掉它，再发消息 · 渲成 `<document id=… missing="true">` 警告行（模型知道 grounding… | ····· |  |
| EDGE-280 | agent 知识文档被删 | agent · 同样场景但走 agent knowledge 挂载 · 大声失败 `AGENT_KNOWLEDGE_NOT_FOUND` + `details.missing… | ····· |  |
| EDGE-281 | skill 安装炸弹护栏 | skill · 用一个 300MB 解压 / 5000 条目 / 含 symlink 的 tarball 装 skill · 压缩 100MB、解压 200MB、4096 条… | ····· |  |
| EDGE-282 | skill 本地改动漂移 | skill · 手工改一个 installed skill 的文件后 `:update` · 409 `SKILL_LOCALLY_MODIFIED` + details 列… | ····· |  |
| EDGE-283 | skill 路径穿越 | skill · files 面 PUT 到 `../../etc/x` 或用反斜杠/绝对路径 · 三重守卫（`filepath.IsLocal` 词法 → Clean 复核 … | ····· |  |
| EDGE-284 | skill 清单拒删 | skill · DELETE `skills/{name}/files/SKILL.md` · 400 `SKILL_FILE_PATH_INVALID`，指向 `DELET… | ····· |  |
| EDGE-285 | 大小写不敏感 FS 上的 skill.md | skill · 在 macOS 上先有小写 `skill.md` 再走平台写入 · 写大写、清退独立小写残件，经 `SameFile` 判别防自删 | ····· |  |
| EDGE-286 | skill 目录前导兜底 | skill · 激活一个带捆绑文件但正文没写占位符的 skill · 渲染结果前置一行 `This skill's directory …: <abs>`；单文件 skill 不加 | ····· |  |
| EDGE-287 | run_skill_script 扩展名不支持 | skill · 用 `.rb` 脚本调 `run_skill_script` · 400 `SKILL_SCRIPT_UNSUPPORTED`，指向 bash 工具 | ····· |  |
| EDGE-288 | fork skill 无 runner | skill · 在未接 subagent runner 的装配下激活 fork skill · 503 `SKILL_SUBAGENT_UNAVAILABLE`；`conte… | ····· |  |
| EDGE-289 | @ 一个 fork skill | skill · 在输入框 @ 一个 fork 模式 skill · fork skill 不进 @ 候选；即便注入也只给指令、不给预授权 | ····· |  |
| EDGE-290 | skill 未知 frontmatter 键保真 | skill · 用右岛表单编辑一个带 `license`/厂商扩展键的 skill · typed 视图之外的键与键序在编辑循环中不丢 | ····· |  |
| EDGE-291 | memory 更新保留策展 | memory · 让 LLM 的 `write_memory`（永远 source=ai、从不设 pinned）编辑一条用户置顶的记忆 · 保留现有 `pinned` 与 `… | ····· |  |
| EDGE-292 | todo 全完成后被问清单 | todo · 让 agent 把清单全标 completed 后再问「列一下清单」 · reminder 在 0-open 时抑制，靠常驻 `todo_read` 读回含已完… | ····· |  |
| EDGE-293 | 删被依赖实体 | relation · 删一个被 3 个 agent 挂载的 function（HTTP 或 LLM 工具任一路径） · purge 抹边**前**快照入向 equip/lin… | ····· |  |
| EDGE-294 | 触点不记幽灵删除 | touchpoint · 让用户 deny 一次 `delete_agent` 危险调用 · 门 = `ok && executed`，被拒的调用工具层没发生 → 绝不产生 … | ····· |  |
| EDGE-295 | 触点记真执行的失败 | touchpoint · 跑一个会抛异常的 function / 一个 status=failed 的 agent · 仍记 `executed`（台账是足迹事实，成败属执行审计） | ····· |  |
| EDGE-296 | 触点 deleted 行借名 | touchpoint · 删一个对话从未碰过的实体，再看台账 · 兄弟借名取不到 → 诚实空名（hydrate 只查活体） | ····· |  |
| EDGE-297 | 触点目录穷尽性 | touchpoint · 加一个新工具但不在提取目录或 no-touch 清单表态 · bootstrap 的 `TestTouchpointCatalog_CoversEv… | ····· |  |
| EDGE-298 | 未读徽标绝不据帧 +1 | frontend · 让 Emit 与 Broadcast 两档同 type 事件同时到达 · 徽标只靠权威 `unread-count` refetch（两档帧形相同、pa… | ····· |  |
| EDGE-299 | 顶带 5000 条积压 | frontend · 短时间灌 5000 条通知 · 队列 O(1)、UI 只投影 current + 最多两 cue + 计数，widget 数不随积压增长、不设 cap … | ····· |  |
| EDGE-300 | 顶带公平调度 | frontend · 同时灌大量 priority（审批/操作反馈）与 normal 事件 · 每播 3 条 priority 必须让 1 条 normal 接班，普通事件不被饿死 | ····· |  |
| EDGE-301 | 顶带清场水位 | frontend · 在批清动画进行中再来新消息 · `clearVisibleSnapshot` 交换两条队列，新消息进新队列保留、不被旧清场误伤 | ····· |  |
| EDGE-302 | OS 通知被静默拒 | frontend · 在 unsigned dev bundle 上让 app 失焦后触发后台事件 · UserNotifications 可能静默拒（已知边界，真投递以签名… | ····· |  |
| EDGE-303 | 侧幕 activity 门控 | frontend · 打开一条从没跑过任何工具的空对话 · 右岛按钮不存在（无内容→无门），首条 activity 到达时 toggle 横向滑入 | ····· |  |
| EDGE-304 | 侧幕跟随三档 | frontend · 分别设 always / 每会话首次 / 从不，再让首个活动登台 · 前两档自动开岛，`从不` 档只亮按钮与 activityBit | ····· |  |
| EDGE-305 | 侧幕尊重手动关 | frontend · 在面板可见时手动关一次，再让新活动登台 · 本会话记入手动关、不再自动弹（切海洋翻桶不误记） | ····· |  |
| EDGE-306 | 导演器清 Live 幽灵 | frontend · 制造流缺口吞掉一个 tool_result 终态帧，再让 subagentEpoch 变化 · 按 transcript 全部 live 根重新接地，清… | ····· |  |
| EDGE-307 | poll 型 202 不谢幕 | frontend · 用 `trigger_workflow`（202 只是回执）后等 run 跑很久 · 关帧后不离场，驻留到 durable `run_terminal`… | ····· |  |
| EDGE-308 | 侧幕失败行清除 | frontend · 让一个工具失败后驻留在侧幕 · hover 亮行级清除按钮（失败驻留的唯一出口），否则旧失败活动永久滞留 | ····· |  |
| EDGE-309 | 侧幕分档时钟 | frontend · 让一行静置跨过「刚刚」窗（10min）而无任何重建 · 每分钟安静重分桶，不让静置行冻在「刚刚」再突跳 | ····· |  |
| EDGE-310 | 深跳 ?around= 整窗替换 | frontend · 从场次条跳到一条很老的消息 · 整扇替换（目标即 center sliver 首行）+ 双向续翻 + 「回到现场」pill；跳转即解钉、流式帧绝不夺视口 | ····· |  |
| EDGE-311 | 归队重钉贴底 | frontend · 从深跳窗点「回到现场」且重拉很快（不换 State） · 转变显式重钉贴底，否则读者被晾在历史里（真机抓获的真 bug） | ····· |  |
| EDGE-312 | 版本组走 retryOf | frontend · 加载一份在自己被 supersede **之前**就取到的旧版副本 · 按向后指针 `attrs.retryOf` 组版本（`supersededBy`… | ····· |  |
| EDGE-313 | 编辑器 undo 全量重建 | frontend · 在增量 presenter 下按 ⌘Z · `DocumentWasResetChange` 哨兵令归账 fail-safe 走全量重建（事件不描述 u… | ····· |  |
| EDGE-314 | 编辑器唯一光标铁律 | frontend · 点进嵌入代码块字段或表格格 · 后代持焦（hasFocus && !hasPrimaryFocus）时清文档选区，避免两根光标同屏共闪 | ····· |  |
| EDGE-315 | 空 task 尾空格腐化 | frontend · 建一个空的 `- [ ] ` 待办后存盘再打开，往返两轮 · 剪尾空白豁免空 task 行；旧腐化档由 `_healTaskShapes` 自愈（字面 … | ····· |  |
| EDGE-316 | 行内代码 CJK 断盒 | frontend · 在行内代码里写中文注释并观察灰底 · 逐视觉行并盒（`getBoxesForSelection` 在 script run 边界会断），灰块连续不断裂 | ····· |  |
| EDGE-317 | 选区跨块缝隙 | frontend · 跨多个块划选 · 逐视觉行并盒（同行判据是竖向中心重合、非重叠）+ 块间 padding 由 overlay gap layer 填 | ····· |  |
| EDGE-318 | 原子块双/三击 | frontend · 双击代码块/表格/分隔线后拖动 · tap guard 在上游状态机之前整块选中并 halt，不形成 NPE 毒态（「点着点着鼠标失灵」） | ····· |  |
| EDGE-319 | 大纲下标不变式 | frontend · 用围栏内 `#`、引用内 `#`、h4–h6 的刁钻文档 · 大纲正则与编辑器 `headingNodeIds` 对「谁是标题」完全一致（h1–h6 六… | ····· |  |
| EDGE-320 | skill 双写者竞态 | frontend · 在中心 body 与右岛 config 表单的 600ms 防抖窗口内同时编辑 · 已知竞态窗（注释已声明），属记档取舍 | ····· |  |
| EDGE-321 | 草稿文档首次编辑 | frontend · 在 library 无选区态打字 · 判空（标题/正文/简介/标签全未动）才不建；首次编辑 POST 后认领新 id、编辑器不重挂（光标/内容不丢） | ····· |  |
| EDGE-322 | 应内缩放到顶 | frontend · 在小屏上连按 ⌘+ · `maxFactor` = 屏可容/设计 min，到顶即停、绝不撑破布局；持久化档恢复时也按当前屏收敛 | ····· |  |
| EDGE-323 | 进全屏白带 | frontend · 从小窗进原生全屏 · 在原生 `willEnterFullScreen`（动画**前**）撤 toolbar，过渡无白带（window_manager … | ····· |  |
| EDGE-324 | 窗角半径 swizzle 失效 | frontend · 让 `NSThemeFrame` 私有半径 getter 改名（未来 OS 版本） · 判空守卫静默回落系统半径、不崩 | ····· |  |
| EDGE-325 | 空工作区名册 | frontend · 全新安装（或出厂重置）后启动 · 停在单页 onboarding，创建成功直接落空白 Chat；不另存 first-run flag，故恢复数据库不漂移 | ✓✓✓✓✓ | L1:G1→/tmp/anselm-rig-formal-20260801-3/evidence/edge-325-onboarding.png; L2:F1→/tmp/anselm-rig-formal-20260801-3/evidence/first-slice-observations.txt; L3:B2→/tmp/anselm-rig-formal-20260801-3/evidence/visual-stability-final.txt; L4:C2→/tmp/anselm-rig-formal-20260801-3/evidence/edge-325-onboarding.png; L5:G1→/tmp/anselm-rig-formal-20260801-3/evidence/edge-325-onboarding.png |
| EDGE-326 | 首启创建过渡 | frontend · 在 onboarding 提交名字 · 旧面与真 Shell 短暂共存、按两端实测 Composer 矩形做 560ms paint-only 飞行；r… | ✓✓✓✓✓ | L1:G1→/tmp/anselm-rig-formal-20260801-3/evidence/chat-landing.png; L2:F1→/tmp/anselm-rig-formal-20260801-3/evidence/first-slice-observations.txt; L3:B2→/tmp/anselm-rig-formal-20260801-3/evidence/visual-stability-final.txt; L4:C2→/tmp/anselm-rig-formal-20260801-3/evidence/edge-326-transition-before.png; L5:G1→/tmp/anselm-rig-formal-20260801-3/evidence/chat-landing.png |
| EDGE-327 | workspace 热切换三拍 | frontend · 在一条对话深链上切换 workspace · ①同瞬 `go('/')` 并清右岛线程记忆 ②post-frame 才设 id（先离开是先一**帧**）… | ····· |  |
| EDGE-328 | 快捷键冷启动 | frontend · 冷启动后不点任何地方直接按 ⌘B · `GlobalShortcuts` 挂在 autofocus **之上**才不被饿死（放焦点之下要先点一下才活） | ····· |  |
| EDGE-329 | 快捷键录制后吞键 | frontend · 在设置里录一个新绑定后继续按组合键 · 录完 `unfocus()` 交还键盘，否则本行吞掉后续每次组合键 | ····· |  |
| EDGE-330 | 设置项搜索索引漂移 | frontend · 新增一个可搜索行但忘了声明索引（或反之） · `settings_search_test` 双向门禁红 | ····· |  |
| EDGE-331 | 限额面板载入失败 | frontend · 让 `GET /limits/schema` 失败 · 整面 `AnState` 人话句 + wire 码收 tooltip + 重试钮，不灰屏 | ····· |  |
| EDGE-332 | MCP 面板帧不可信 | frontend · 让 entities 流的 mcp 帧密集到达 · 任何帧 → 300ms coalesce 一次重取；410 强制重取 | ····· |  |
| EDGE-333 | 保留面板无客户端默认 | frontend · 全新安装打开存储面板的「Run 历史保留」 · GET 恒返服务端自持的具体值（90），客户端永不硬编默认、无 modified/onReset | ····· |  |
| EDGE-334 | testend Kill9 崩溃半场 | testend · 用 `Kill9`（真 SIGKILL）模拟崩溃恢复场景 · 绝不软化成 SIGTERM，否则优雅链会先删掉要断言的残骸（非终态行/未收尸子进程/未 ch… | ····· |  |
| EDGE-335 | testend 进程组泄漏自检 | testend · 让某个场景漏出常驻 llama-server · 轮询进程组至空，超 10s 仍有成员即 `t.Errorf` 并列幸存者命令行（测试绿不是收容的证据） | ····· |  |
| EDGE-336 | testend 超时/被杀由下一轮收 | testend · 让整轮撞 `-timeout` 或对测试二进制 SIGKILL · 下一轮按 `$TMPDIR/anselm-testend/<pid>/` 的 pid … | ····· |  |
| EDGE-337 | testend 缓存剥 pid | testend · 让运行时缓存搭上 `embedder.pid` · `saveRuntimeCache` 回存前剥 `*.pid`，否则回收器指向 OS 此后分给别人的号码 | ····· |  |
| EDGE-338 | testend 网关指向关闭端口 | testend · 跑一轮完整 testend 并观察真网关侧 · `ANSELM_GATEWAY_URL` 指向关闭的回环端口使开通快速失败，绝不登记 ~50 个真 ins… | ····· |  |
| EDGE-339 | BYOK base URL 模板未填占位 | apikey · 选 Azure/Vertex 等模板型供应商,base URL 留占位原样提交 · 表单以 `baseUrlTemplateHint` 指名要替换的占位;模… | ····· |  |
| EDGE-340 | Vertex service-account 文件校验 | apikey · 贴一段缺 `type`/`project_id`/`private_key` 的 JSON · `serviceAccountBad` 当场拒绝;合法文件则… | ····· |  |
| EDGE-341 | 未验证供应商诚实徽标 | apikey · 从 173 家目录选一家从未真测过的 · `unverified` 徽标 + hint(「来自 models.dev 目录,没人试过」);诊断句引导先疑 b… | ····· |  |
| EDGE-342 | chat-only 模型的工具面 | catalog · 选一个 `tool_call=false` 的模型开对话 · picker 带 `chatOnlyBadge`,目录不再替用户扔掉能聊天的模型;对话内工具… | ····· |  |
| EDGE-343 | 工具参数双线缆形 | llm · 让 provider 分别以 object 与 string 两形返回 tool arguments · 两形都被认得(toolargs 归一),不再只认其中一种 | ····· |  |
| EDGE-344 | 直连生成整体退场 | generate · 只配 BYOK key、无受管 install,让模型试 generate_image · 生成三工具**诚实缺席**(CapabilityTools … | ····· |  |
| EDGE-345 | 音色登记→指名说话全链 | voice · enroll_voice 登记参考音色→generate_speech 指名它 · 句柄被翻译成上游 id(63f402f 之前从来没能说过话);音色出现在设… | ····· |  |
| EDGE-346 | 音色库存 2 槽上限 | voice · 登记第三个音色 · 库存闸拒绝(`voicesFull` 文案「删一个腾位」);库存不是钱的闸,与配额无关 | ····· |  |
| EDGE-347 | 删音色上游失败保行 | voice · 让网关删句柄失败再删本地音色 · `voicesDeleteFailed`:行保留可重试,绝不本地删了上游还挂着 | ····· |  |
| EDGE-348 | 语音双工握手拒绝闭集 | speech · 让网关握手返 401/配额类拒绝 · 拒绝只携带闭集 code(`handshakeRefusal`),上游散文**没有能力**泄进用户面错误 | ····· |  |
| EDGE-349 | 语音流中上游断线 | speech · 会话中途杀上游连接 · 客户端收 `SPEECH_UPSTREAM_CLOSED` 事件帧,双向心跳 deadline 收尾,不悬挂 | ····· |  |
| EDGE-350 | 语音帧越界 | speech · 发超过帧上限的音频帧 / 非法控制帧 · `SPEECH_AUDIO_FRAME_INVALID` / `SPEECH_CONTROL_INVALID`,会… | ····· |  |
| EDGE-351 | 429 不动钱 | freetier · 受管生成撞限流(非配额耗尽) · 网关侧 429 **不扣用户配额**(aabd07d:恢复 GW-INV-23 合规);配额卡数字不动 | ····· |  |
| EDGE-352 | 分叉携带附件与 subagent 树 | fork · fork 一条带附件、@ 快照与 subagent 嵌套的对话 · attrs 逐字带走**除** retryOf/parentBlockId 被 remap … | ····· |  |
| EDGE-353 | workflow 停用排空双类 | workflow · :deactivate 时既有在飞 run 又有已接受 pending firing · draining 直到**两类**都排空才 inactive;… | ····· |  |

**TOTAL: 848 行 × 5 级 = 4240 格**
