---
id: DOC-012
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Handler

## 1. 定位

Handler 是用户构建的有状态 Python 类。一个 Handler 对应一个 workspace 内
共享的常驻进程；Chat、Agent、Workflow 与 HTTP 调用同一实例，`self` 状态可
跨调用保留。

```text
Handler row + encrypted init config
→ immutable Version(class parts + schema + deps + env mirror)
→ one resident Instance
→ serialized method RPC
→ terminal Call audit
```

Function 每次调用启动隔离进程；Handler 在常驻进程上执行 RPC。这是两者的核心
边界。

## 2. 版本与类装配

主行保存身份、active pointer 与整块加密的 init config。Version 保存：

- imports、init body、shutdown body；
- MethodSpec 列表；
- InitArgSpec；
- dependencies、Python version、env mirror。

`AssembleClass` 将这些部分生成 `HandlerImpl`。Method inputs/outputs 使用通用
`schema.Field`；init args 独立建模，因为它们还包含
`required|sensitive|default`。

版本号、revert、per-version env、envfix 与 trim 语义与
[`function.md`](function.md) 相同。代码/schema Edit 与 Revert 都会重启实例。
纯 metadata 更新不铸版本、不重启，因此不会无故丢掉内存态。空 ops 表示重建
active env 并重启；工具结果明确返回 restarted。

### LLM 构建 op 形状

create_handler 与 edit_handler 的 ops 是带 op 判别字段的数组。
update_method 是唯一使用 RFC 7396 merge patch 的 op，精确形状为：

~~~json
{"op":"update_method","name":"place","patch":{"description":"..."}}
~~~

其中顶层 name 选择已有 method，所有修改字段必须嵌在 patch 对象内；
不能使用 methodName，也不能把 description、body、inputs 或 outputs
放在 patch 外。add_method 的完整 MethodSpec 必须嵌在 method 字段内。
执行边界只为 hosted model 的一个确定性别名
`updateMethod` + `method/methodName` + 顶层 method 字段，以及完整的
`kind:"set_method"` + 嵌套 MethodSpec，提供窄归一化；公开 schema 仍以
canonical 形状为准，近似拼写、未知字段或空 patch 不因此获得通过。

`revert_handler` 的 `version` 公开仍是 integer；执行边界额外接受只包含十进制整数的
字符串，以兼容 hosted model 的标量字符串化。小数、数组、布尔、文字和非正数仍拒绝。

## 3. 配置

Config 以 AES-GCM 整 blob 存储。Update 使用 JSON Merge Patch，`null` 删除
字段，保存后重启实例并重新执行 `__init__`。Clear 清空配置并停止实例。
工具执行边界接受 schema 所述对象，亦接受一个解码后仍为对象的 JSON 字符串，
以容忍托管模型对嵌套 object 的字符串化；数组、数字、非法 JSON 字符串和根级
`null` 仍拒绝。该兼容只改变编码，不改变 Merge Patch 语义。

读侧只提供：

- `unconfigured|partially_configured|ready` 与 missing required args；
- sensitive 值替换为 `********` 的 masked config。

Spawn 前按 active `InitArgSpec` 过滤配置，避免 schema 已删除的孤儿 key 作为
意外 kwarg 进入 `__init__`。必填值不全时返回
`HANDLER_CONFIG_INCOMPLETE`。

LLM 工具边界也刻意分开：`call_handler` 只调用已声明的方法，`args` 是该方法的关键字参数，不能用
顶层 `config` 改初始化配置；`update_handler_config` 是修改 init-args 的唯一工具，执行 JSON Merge
Patch 后重启实例。这样「调用方法」与「重配服务」不会在模型第一次操作时混成同一条路径。

## 4. 实例生命周期

Instance 只存在内存，状态为 `running|stopped|crashed`。Manager 保证每个
Handler 至多一个实例：

- Get 复用健康实例；
- crashed 实例先废弃，再按需 spawn；
- 并发首调共享一次 in-flight spawn；
- Boot 对 active、env-ready、config-ready 的 Handler 最佳努力预热；
- Restart = Stop + Get；退出时 StopAll。

Spawn 加载 active version、解密并过滤 config、确保 env、写 class/driver、
启动长进程并执行 `client.Init`。env 被 GC 时重建并重试一次。Init 失败保留
结构化 traceback，并作为失败 Call 可观察。

## 5. RPC 与调用

Driver 使用逐行 JSON 协议：

```text
init → ready | init_error
call → progress* → return | error
shutdown
```

用户 stdout 在进程启动时整体改道 stderr，协议帧使用保留的真实 stdout，
因此 import、init、method 或 shutdown 中的 `print()` 不会破坏协议。

单一 stdio 管道由 mutex 串行。每次调用使用 MethodSpec timeout；未声明时使用
全局 Handler wall-clock。取消、EOF、读写失败或协议错误都会把实例标记为
crashed：取消后迟到回复可能污染下一次读取，因此不能复用该管道。

Streaming method 的 progress yield 同时进入调用者 progress、Entities run
terminal 与有界日志。Generator 的最后一个非-progress yield 或 return value
作为终值。

所有入口汇入 `Call`：

1. 解析 Handler 与 active method；
2. 建立调用 deadline；
3. 获取或 spawn Instance；
4. 通过 `StreamCall` 执行；
5. 在 detached context 写 Call。

Spawn 失败也是一次真实调用失败，会写 instance ID 为空的 failed Call。状态为
`ok|failed|cancelled|timeout`。Call 保存 conversation、message、tool-call、
flowrun、node 与 iteration 溯源。实时错误与持久日志都会清洗框架注入的
sensitive config；结构化错误保留 code/details，去除内部 Go 包装路径。

## 6. 媒体产物

每次 method call 可获得独立临时目录，作为 cwd 与 `$ANSELM_OUT`。返回值中的
`{"$media":"relative/path"}` 在记录 Call 前就地替换为
`source="handler_artifact"` 的 MediaRef。

目录按调用传入并在 `finally` 恢复 cwd；这一安全性依赖 RPC 调用全程串行。
Function 与 Handler 共用同一媒体采集器及路径、大小、数量、MIME 边界。
Uploader 未装配时不创建目录，声明原样通过。

## 7. 契约与集成

精确端点见 [`api.md`](../api.md)，包括 config、call 与 restart；表见
[`database.md`](../database.md)，错误见
[`error-codes.md`](../error-codes.md)，事件见
[`events.md`](../events.md)。ID：`hd_`、`hdv_`、`hcl_`；env：`hdenv_`；
内存实例：`hdi_`。

- Catalog 以容器投影暴露 active methods；
- Mention 提供 description 与装配后的 active class；
- Agent mount `hd_<id>.<method>` 合成为 `<handler>__<method>`；
- Workflow action、Chat、HTTP 与 Sensor 调用同一 `Call`；
- Delete 停实例、软删主行、清 relation，并最佳努力回收 env/代码目录。

`delete_handler` 的工具回执同时返回结构化 `retention`：`handler=soft_deleted`、
`versions=retained_for_audit`、`sandbox=destroy_requested_best_effort`、
`actions=not_found`。这四项是删除后的结果事实；若删除前存在引用，还会额外返回
`dependents`、`dependentCount` 与修复提示。版本和环境的实际状态仍以对应 REST/数据库
审计证据为准，不能把“best effort”误读为同步清理完成。

LLM 工具覆盖搜索、读取、构建、revert、配置、restart、调用与 Call 查询。
`update_handler_meta` 只改主行，不重启实例。
