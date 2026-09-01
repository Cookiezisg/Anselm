# EDGE-180 embedder 孤儿回收：L5 真实 App 可发现性

- 结论：`pass`。
- 真实路径使用同一独立数据目录的崩溃段与恢复段；用户不需要知道 `embedder.pid`、`llama-server`、`SIGKILL` 或 backend 端口。

从用户视角，服务异常时真实 App 清楚显示 `Can't reach the local engine`、`The local engine is unavailable. Start it, then try again.` 和 `Retry`；恢复启动后回到正常 Chat，用户提出搜索目标即可得到真实搜索结果。没有要求用户打开终端、删除 PID 文件、重新下载模型或理解内部搜索实现。

这是从零用户可理解的失败到恢复路径。内部回收动作由下次启动自动完成，因此没有额外隐藏操作，也没有将“日志中出现 reaped”冒充用户可见功能。第二段真实搜索返回与旧残留收容同时由 REST、backend、SSE 和 App 画面核实。

判定依据：`CODEX G1`。
