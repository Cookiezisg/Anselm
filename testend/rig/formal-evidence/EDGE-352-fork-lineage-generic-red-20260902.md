# EDGE-352 | 分叉携带附件与 subagent 树 | 血缘标题红证据

- 正式 session：`/private/tmp/anselm-rig-formal-20260902-32/sessions/20260902-054857`。
- 真实路径：真实 App 上传附件、提及 `greet`、生成一个真实 subagent 树，再从用户可见的 `Fork from here` 入口分叉。
- 观察结果：分叉线程保留附件、提及快照和 subagent 树，但顶部血缘菜单只显示泛化的 `Forked from another conversation`，没有源线程名称。
- 根因：分叉创建时源线程仍是空标题；`forkSourceProvider` 只做一次读取，源线程随后通过 notifications lifecycle 信号完成自动命名时，血缘 provider 不会重新读取。
- 判定：冻结 EDGE-352，L3-L5 不入账。该现象损害血缘可理解性，不是可接受的加载态或输入桥接噪声。
- 修复方向：source provider 订阅其对应的 durable lifecycle 信号，只重读该源；不启动 conversation rail，不新增 SSE 通道。补 widget 回归测试覆盖菜单已打开后标题更新和源删除泛化降级。
