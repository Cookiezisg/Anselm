---
# Round 0038 — handler 重写：MCP 式单例常驻生命周期 + 复用 app/envfix（function 孪生）

类型 / 目标：波次 3 Quadrinity 第二元 `handler`（有状态 Python 类）。用户拍板**把进程生命周期重做成 MCP 式**——开局常驻、一直在线、退出软件才优雅关闭——砍掉旧实现最重、还自我矛盾的那块。其余 = function（R0037）孪生。

## 核心方针（一句话）
**handler = function 孪生（方案 A 版本 / app/envfix / forge / call_log / 适配器 / 5 方法工具）+ 三件独有（类组装 / 加密 config / MCP 式单例常驻进程）。生命周期从一堆机器塌成 3 动词 boot/restart/shutdown。**

## 用户拍板的决策
1. **MCP 式单例常驻**：每 handler 一个常驻进程（`map[handlerID]*Instance`），boot 开局起、restart 重置、shutdown 退出关；**chat/agent/workflow 共享同一实例 + 状态**（真有状态）。删旧 `Owner` + `map[Owner]map[name]` per-owner + 两套 call 分叉（**chat 即起即杀使有状态类退化无状态——自我矛盾**）+ lazy/crash/race/owner-teardown。
2. **restart 双触发**：自动（edit / 改 config → 重启吃新代码/config）+ **手动 `restart_handler` 工具 + `POST :restart`**（对话内"这个坏了帮我重启"——crash 重生救不了"活着但状态坏了"，restart 是有状态服务的「重置按钮」，用户特别要求加 LLM 工具）。
3. **方案 A 版本**（同 function）+ **env-fix 复用 `app/envfix`**（R0037 抽的共享包，handler 是第二个消费者）。

## 新增 / 重写
- **domain/handler**：去 GORM；Handler（+ config_encrypted + 计算 ConfigState/MissingConfig/RuntimeState）+ Version（类块 imports/init_body/shutdown_body/methods/init_args_schema、单调号、删 status/env_sync_stage/detail）+ Call call_log（hcl_、triggered_by 四值、删 hints）+ MethodSpec/ArgSpec/InitArgSpec + errorsdomain（删 pending/instanceNotFound/envFailed/ast/configInvalid，加 ErrInvalidCode，crashed→HANDLER_CRASHED 502）。
- **infra/handler/client.go**：stdio 行-JSON RPC 客户端照搬（Init/Call/StreamCall/Shutdown/Crashed、reqID 匹配 + mutex 串行 + crash 检测 + 500ms shutdown 上限）。
- **infra/store/handler**：orm 三表 + DDL（config_encrypted 列、GetConfigEncrypted/Update/Clear、trim 保护 active）。
- **app/handler/manager.go ★**：MCP 式 `instanceManager`——`Get`(无/crashed 则 spawn) / `Restart` / `Stop` / `StopAll`(退出) / `Boot`(开局起) / `State`(running/stopped/crashed)。
- **app/handler Service**：crud（create 不 spawn / edit·revert→重启 / delete→停+销毁）+ Call（manager.Get→invokeMethod→记 call，crash/timeout 映射 domain 错误）+ Restart + config（加密 + 改配置自动重启 + 门控 spawn）+ AssembleClass（拼 HandlerImpl 类 + DriverScript）+ ensureEnv（复用 envfix）+ SandboxRunner 端口/适配器（写 user_handler.py+driver.py + SpawnLongLived）+ 3 适配器（catalog/mention/relation Namer，4 动词边）。
- **app/tool/handler**：11 工具（search/get/create/edit/revert/delete/**call**/update_config/**restart**/search_calls/get_call），5 方法、danger 自报、create/edit forgeSink 折 envFixAttempts、call 按 ctx 区分 chat/agent。
- **handler HTTP**：REST + `:call`/`:restart`/`:revert`/`:edit` + config（GET masked / PUT merge+重启 / DELETE）+ versions + calls；删 pending 三端点；:iterate 留 M6。

## 测试（全离线）
- store 5（隔离/dup/config 加密往返/trim 保护 active/calls 聚合）。
- app 9（**生命周期核心**：create 不 spawn / call spawn+复用+记录 / **restart 停+重生** / **crash 下次调用重生** / edit 重启+号 +1 / revert 纯移指针 / **config 门控 spawn**（无配置 ErrConfigIncomplete、UpdateConfig 后起）/ shutdown 停全部 / AssembleClass）——fake sandbox runner + fake client（clientLog 记每次 spawn）+ 真 envfix（okSandbox）+ fake encryptor。
- tool（11 装配 + ValidateInput）+ domain（IsValidTrigger）。

## 验证
`gofmt -l` 干净 · `go build ./...` 0 · `go vet ./...` 0 · `go test -race`（domain/store/app/tool + function + envfix）全绿。

## 契约
- `domains/handler.md` **整篇重写**（DOC-111：MCP 式 boot/restart/shutdown + 方案 A + 类组装 + 加密 config + restart；删 15min-idle/ast-scan/UDS/per-owner/:reconnect 吹嘘）。
- `api.md`（删 pending 三端点、config POST→PUT、+:restart）· `error-codes.md`（删 5 + 加 INVALID_CODE + crashed→HANDLER_CRASHED 502/RPC_TIMEOUT 改名）· `database.md`（前缀 +hdenv_/hdi_）· `contract-changes #18`。

## 跨波次接线（deps-todo 登记）
- handler `Boot(ctx)` / `Shutdown(ctx)` 注入 server boot/退出 M7（多 workspace boot 编排 + workspace 切换时起停留 M7 定）。
- SandboxRunner + envfix.Provisioner + encryptor + clientFact 装配 M7；3 适配器注入 + DDL 收集 M7。
- workflow tool 节点 kind=handler 调方法（triggered_by=workflow）M4；triggered_by 写入方 agent M3.4 / chat M5.2。
- `:iterate`（askai）波次 6。
