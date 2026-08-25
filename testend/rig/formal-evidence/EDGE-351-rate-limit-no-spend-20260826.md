# EDGE-351 429 不动钱

- 判定对象：受管生成遭遇限流而非配额耗尽时，额度与安装身份不变。
- 证据：`backend/internal/app/speech`、`backend/internal/app/readaloud`、`backend/internal/transport/httpapi/handlers` 定向测试通过；错误分类将 rate limited 与 quota exhausted 分开。
- 产品判断：瞬时限流可重试，不伪报“钱已花掉”，不轮换受管 install；配额耗尽才进入不可重试分支。
- 法条：F1、F4。

