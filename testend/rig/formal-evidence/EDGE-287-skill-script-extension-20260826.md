# EDGE-287 · run_skill_script 扩展名不支持

## L1 focused evidence

- `backend/internal/app/tool/skill/run_script_test.go:TestRunSkillScript_ValidateInput` 通过：`run.sh` 返回 ErrScriptUnsupported，而 `.py`/`.mjs` 进入受支持路径。
- 同文件 `TestRunSkillScript_HaltOnRepeatOnlyForTerminalScriptRejections` 通过：不支持扩展名是终态并指向 host bash，临时 sandbox 失败仍可重试。

## 判定

L1=`E1`：不支持的脚本格式会给出可解释的拒绝，而不是用错误解释器执行。L2-L5 本批未启动真实 App，记 `na`。
