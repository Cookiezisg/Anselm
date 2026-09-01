# EDGE-288 · fork skill 无 runner：真实装配不可达性核验

日期：2026-09-01

## 结论

本格描述的是“未接 subagent runner 的装配下激活 fork skill”。服务层保留并通过
`TestActivate_Fork_NoRunner_Degrades` 覆盖 `SKILL_SUBAGENT_UNAVAILABLE`，但当前可发行的
完整装配在 `backend/internal/bootstrap/build_services.go` 无条件创建 `subagentSvc`，并将其
注入 `skillapp.NewService(st.skill, subagentSvc, ...)`。因此该错误分支不是当前真实 App 可由
用户进入的产品状态，L2-L5 对本发行装配明确不适用；不能用成功的 fork 路径冒充 503 错误路径。

## 真实装配交叉证据

- session：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-125841`
- workspace：`ws_419614654ae20341`
- 真实 App 打开 Library，选中 `edge288-fork`；画面显示 `Context: Fork`、`Agent` 字段及
  `Explore`，没有把它渲染成 inline skill。
- API 创建合法 fork skill 后调用真实 `POST /api/v1/skills/edge288-fork:activate`，返回
  `200`，由隔离 Explore runner 返回任务结果；这与完整装配注入 runner 的代码事实一致。
- backend journal 记录创建、fork 子任务工具边界和激活 `200`，无应用级 ERROR/panic/FATAL。
- `sse.jsonl` 记录 `messages`、`entities`、`notifications` 三流连接及 skill 生命周期帧。
- `llm.jsonl` 记录 managed challenge/install/models 与真实 chat wire，全部 HTTP `200`。
- `frontend.log` 除 macOS IMK 系统行外无 Flutter/Dart/RenderFlex/RenderBox/Unhandled 错误。
- `screen.mov` 已由 `rig-down.sh` 封存，时长 `97.206667s`；`rig-check` 五通道通过，owned
  processes 已收尸。

## 适用性裁决

- L1：既有 focused 普通/race 回归和合同黑盒测试通过，覆盖 nil runner、缺 agent、非法 agent
  及不污染 active skill 的结构防线。
- L2：`na`。真实发行装配始终注入 runner；本 session 观察到的是成功激活，不能伪称无 runner
  的用户错误反馈。
- L3：`na`。不可达分支没有可评估的真实反馈连续性。
- L4：`na`。不可达分支没有可评估的真实错误文案/视觉表达。
- L5：`na`。不可达分支没有可评估的产品入口发现性；fork skill 的正常 Library 入口由本
  session 观察，并非本格的错误入口。

这不是对未执行真实测试的豁免，而是由完整装配代码、真实 App 成功激活和五通道 session
共同证明的适用性边界。若未来引入可选 runner、插件装配或启动降级开关，应重新打开本格并
为 503 用户路径建立独立真实 session。
