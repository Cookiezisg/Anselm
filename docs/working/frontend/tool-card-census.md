---
id: WRK-057
type: working
status: active
owner: @weilin
created: 2026-07-06
reviewed: 2026-07-24
review-due: 2026-10-04
audience: [human, ai]
---

# 工具卡线缆普查底册 —— 蓝图的证据基座

> [`tool-card-blueprints.md`](tool-card-blueprints.md)(WRK-056)的证据底册,12 章:**01–09** 后端 114 工具逐个契约(args 全字段 / edit 补丁风格 / Execute 精确返回 / progress 流 / 错误模式)· **10** 框架机制(summary·danger 注入与剥离 / args delta 生命周期 / progress 块 / 拒绝散文常量 / 全量注册表 / E3 嵌套)· **palette** 前端乐器清单(逐件流式适性 + 缺口清单)· **graph** 图画布勘探(增量可行性 / settle-then-replay 路径)。
> **快照纪律**:本册生成于 2026-07-06,**代码是唯一真相**——消费任何一条前若怀疑漂移,以代码复核为准;蓝图落地各批次时按迭代铁律③(a) 重读对应后端面。

---


---

# 工具普查 01 — filesystem / search / shell

> 来源:`backend/internal/app/tool/{filesystem,search,shell}/` 逐文件通读(2026-07-05,分支 frontend-rebuild)。
> 共 9 工具:Read / Write / Edit(filesystem)、LS / Glob / Grep(search)、Bash / BashOutput / KillShell(shell)。
> 全域共性(不逐工具重复):
> - **无 cwd 铁律**:所有路径经 `pkg/fspath.Expand` —— 支持 `~` / `~/rest`(不支持 `~user`)、展开后必须绝对,否则返 `FSPATH_NOT_ABSOLUTE` 文案。
> - **PathGuard**:每工具执行前过 `Allow`(读)或 `AllowWrite`(写),拒绝时 tool_result = `"path is denied by safety guard: <path>"`。
> - **错误双通道**:`ValidateInput` 返 `errorspkg` sentinel(结构错,LLM 修参数);`Execute` 内几乎所有运行期失败都以**人读字符串作为正常 tool_result 返回**(err==nil)——UI 看到的"错误"多数是普通结果文本,没有错误标记位,需按文案模式识别。
> - **progress 流**:9 工具中**只有 Bash 前台**发 progress 块(见 Bash 节);其余 8 个全部一次性返回、执行中无任何中间流。
> - summary/danger/execution_group 为框架注入,下文 args 均不含。

---

## 1. Read(filesystem/read.go)

文件读取,cat -n 分页输出;副作用:把 path→size 盖进 AgentState.SeenFiles(供 Write/Edit 写前必读守卫)。

**args**
| 字段 | 类型 | 必填 | 默认 |
|---|---|---|---|
| `file_path` | string | ✅ | — 绝对路径 |
| `offset` | number | ✗ | 1(1-based 起始行) |
| `limit` | number | ✗ | 2000(`limits.Tools.ReadDefaultLines`) |

无 PAYLOAD 字段。

**返回**:原始字符串,cat -n 模板 —— 每行 `%5d\t<内容>\n`(5 宽右对齐行号 + TAB)。截断时末尾追加一行:
`... [truncated at line N; use offset+limit to read more]`。
空文件返回 `<system-reminder>File exists but has empty contents.</system-reminder>`。
体积:默认最多 2000 行、单行上限 8 MiB(超长行 scanner 报错而非截断)。

**错误文案**(均为正常 tool_result):`File not found: <p>` / `Permission denied: <p>` / `Cannot access <p>: <err>` / `Path is a directory, not a file: <p>. Use Glob with pattern "*" ...` / `Failed to read <p>: <err>`。
ValidateInput sentinel:`FS_EMPTY_FILE_PATH` / `FS_NEGATIVE_OFFSET` / `FS_NEGATIVE_LIMIT`。

危险性:只读,安全。progress:无。

---

## 2. Write(filesystem/write.go)

创建或覆写整个文件(原子:tmp + chmod + rename)。**补丁风格 = 整体替换**(全量 content,非增量)。

**args**
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `file_path` | string | ✅ | 绝对路径,父目录必须已存在 |
| `content` | string | ✅(可为 "") | **PAYLOAD** —— 完整文件内容 |

**守卫三重**:PathGuard.AllowWrite(.git/.env/node_modules 等写专属拒绝)→ 父目录存在且是目录 → **覆写必须本次会话 Read 过**(AgentState.SeenFiles;state 缺失 fail-closed 拒绝)。新建文件不需要先 Read。mode:覆写保留原 perm,新建 0644。成功后把新 size 重盖进 SeenFiles(所以 Write 后可直接 Edit)。

**返回**:单行 `Wrote <path>`。体积恒小。

**错误文案**:`Parent directory does not exist: <dir>. Use Bash 'mkdir -p' ...` / `Parent path exists but is not a directory: ...` / `Path is a directory, not a file: ...` / `Cannot verify Read-first guard: agent state missing. Read the file first.` / `File must be read first before overwriting: <p>. Use the Read tool first.` / `Write failed (writing temp|closing temp|chmod temp|rename to target): <err>`。
ValidateInput sentinel:`FS_EMPTY_FILE_PATH` / `FS_CONTENT_REQUIRED`(content 键缺失;空串合法)。

危险性:写盘,但无确认门(危险靠 LLM 自报 danger 字段,本工具内无额外拦截)。progress:无。

---

## 3. Edit(filesystem/edit.go)

原地**字面量子串替换**(非 regex,空白/大小写敏感)。**补丁风格 = 单点字面 patch**:`old_string → new_string`,不是 ops 数组、不是行号 diff —— 前端 morph 应把 old/new 做成 before/after diff 视图;`new_string` 是创作内容锚。

**args**
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `file_path` | string | ✅ | 绝对路径,文件必须已存在 |
| `old_string` | string | ✅ 非空 | 被替换文本(须唯一,除非 replace_all) |
| `new_string` | string | ✅(可为 "") | **PAYLOAD** —— 替换文本;空串=删除匹配段 |
| `replace_all` | boolean | ✗ | 默认 false;true=全部替换(如变量改名) |

**守卫四重**:AllowWrite → 文件存在且非目录 → 写前必读(AgentState,缺失 fail-closed)→ **size 漂移检测**(当前 size ≠ 上次 Read 盖章 size 即拒绝;同 size 内容互换会漏,v1 取舍)。写入同 Write:原子 tmp+chmod(保留原 mode)+rename,成功后重盖 size。

**返回**:`Replaced 1 occurrence in <path>.` 或 `Replaced N occurrences in <path>.`。体积恒小。

**错误文案**(UI 值得区分的模式):
- `File not found: <p>. Edit can only modify existing files; use Write to create new ones.`
- `File must be read first before editing: <p>. Use the Read tool first.`
- `File has been modified since last read (current size X, expected Y): <p>. Read it again before editing.`
- `old_string not found in the file. Verify the exact text (whitespace and case matter).`
- `Found N matches of old_string in <p>, but replace_all is false. Either provide more surrounding context ... or set replace_all: true.`
- `Edit failed (cannot create temp|writing temp|closing temp|chmod temp|rename to target): <err>`

ValidateInput sentinel:`FS_EMPTY_FILE_PATH` / `FS_EMPTY_OLD_STRING` / `FS_NEW_STRING_REQUIRED` / `FS_EDIT_NOOP`(old==new)。

危险性:写盘,无确认门。progress:无。

---

## 4. LS(search/ls.go)

列目录一层(非递归),目录优先再按名字序 —— "打开文件夹看一眼"原语。只读、不碰 AgentState。

**args**
| 字段 | 类型 | 必填 | 默认 |
|---|---|---|---|
| `path` | string | ✅ | — 绝对或 ~ |
| `limit` | number | ✗ | 200,硬上限 1000 |

无 PAYLOAD。

**返回**:行式文本模板 ——
```
<abs> (<total> entries)
  dir   <name>
  link  <name>
  file  <name>   <humanBytes>   <YYYY-MM-DD HH:MM>
```
空目录第二行 `  (empty)`;截断尾行 `  ... showing L of T entries; raise limit to see more`。size 为 humanBytes(`123 B` / `1.5 KB` / MB…)。体积:≤1000 行级。

**错误文案**:`Directory not found: <p>` / `Not a directory (use Read for a file): <p>` / `Cannot read directory <p>: <err>` / `Cannot access <p>: <err>`。
ValidateInput sentinel:`SEARCH_PATH_REQUIRED` / `SEARCH_NEGATIVE_LIMIT`。

危险性:只读。progress:无。

---

## 5. Glob(search/glob.go)

按名字模式找文件(doublestar,支持 `**` 递归),mtime 降序。**唯一返回 JSON 的搜索工具**。

**args**
| 字段 | 类型 | 必填 | 默认 |
|---|---|---|---|
| `pattern` | string | ✅ | glob(如 `**/*.go`) |
| `path` | string | ✅ | 搜索根,绝对或 ~ |
| `limit` | number | ✗ | 100,硬上限 1000 |

无 PAYLOAD。

**返回**:`json.MarshalIndent` 两空格缩进的 JSON:
```json
{
  "root": "<abs>",
  "matches": [ { "path": "<abs>", "type": "file|dir|link", "size": 123, "mtime": "RFC3339" } ],
  "total": N,        // 截断前总数
  "truncated": bool
}
```
排序 mtime 降序(同 mtime 按 path 升序)。体积:≤1000 条 match 的 JSON。

**特殊行为**:
- **噪音目录后置过滤**:命中路径中含 `.git / node_modules / .venv / venv / __pycache__ / .anselm` 任一段即丢弃(根自身在噪音目录内不受限)。
- **ctx 超时护栏**(F183 修复):doublestar walk 不可中断,放 goroutine 里跑;回合 ctx 取消时返回文案 `Glob search exceeded the time budget before completing — narrow the search root and avoid a bare '**' from a large directory, then try again.`

**错误文案**:`Search root not found: <p>` / `Search root must be a directory: <p>` / `Invalid glob pattern "<pat>": <err>` / `Cannot access ...`。
ValidateInput sentinel:`SEARCH_EMPTY_PATTERN` / `SEARCH_PATH_REQUIRED` / `SEARCH_NEGATIVE_LIMIT`。

危险性:只读。progress:无。

---

## 6. Grep(search/grep.go + grep_rg.go + grep_stdlib.go)

regex 内容搜索,双后端:装了 ripgrep 走 rg(exec.CommandContext),否则纯 Go stdlib 回退;两端 args/输出语义一致(rg 失败还会 log warn 后落回 stdlib)。

**args**(注意三个带连字符的 JSON 键)
| 字段 | 类型 | 必填 | 枚举/默认 |
|---|---|---|---|
| `pattern` | string | ✅ | regex |
| `path` | string | ✅ | 文件或目录,绝对或 ~ |
| `glob` | string | ✗ | 文件名过滤(如 `*.go`) |
| `type` | string | ✗ | 语言过滤(go/py/js/ts/tsx/jsx/rust/rs/c/cpp/java/rb/php/swift/kotlin/yaml/yml/json/xml/html/css/md/sh/toml/sql) |
| `output_mode` | string | ✗ | 枚举 `content` \| `files_with_matches`(默认) \| `count` |
| `-A` / `-B` | number | ✗ | 后/前上下文行数(content 模式) |
| `-C` | number | ✗ | 双向上下文,折进 -A/-B |
| `-n` | boolean | ✗ | content 模式显示行号 |
| `-i` | boolean | ✗ | 大小写不敏感 |
| `multiline` | boolean | ✗ | 默认 false;跨行匹配 |
| `head_limit` | number | ✗ | 截前 N 条(content=匹配行 / 其他=文件数) |

无 PAYLOAD。

**返回**(按 output_mode,rg `--no-heading` 风格纯文本):
- `files_with_matches`:每行一个绝对路径。
- `count`:每行 `path:N`。
- `content`:每行 `path:lineNum:text`(上下文行分隔符用 `-` 代替 `:`;单文件 root 省略 path 前缀;`-n` 才有行号)。
- 无匹配统一返回 `No matches for "<pattern>" in <root>.`(err==nil,非错误)。
- 截断标记:`... [truncated at N lines|files|matches; raise head_limit to see more]`;字节上限 256KB(`rgOutputCapBytes`/`stdlibOutputCapBytes`),超限追 `... [output capped at 262144 bytes ...; narrow with glob/type or use head_limit]`。

**特殊行为**:stdlib 后端跳过同一噪音目录集;multiline 时文件 >32MiB 直接跳过;stdlib WalkDir 每条目查 ctx(可取消);正则错误返 `Invalid regex pattern: <err>` 文案。

ValidateInput sentinel:`SEARCH_EMPTY_PATTERN` / `SEARCH_PATH_REQUIRED` / `SEARCH_INVALID_OUTPUT_MODE` / `SEARCH_NEGATIVE_LIMIT`(-A/-B/-C/head_limit 任一为负)。

危险性:只读。progress:无。

---

## 7. Bash(shell/bash.go)

跑 shell 命令(Unix `/bin/sh -c`,Windows `cmd.exe /c`)。**无 cwd、无持久 shell 状态**——每次调用独立进程,`cd` 不跨调用。子进程自成进程组(Unix),杀时波及孙进程。

**args**
| 字段 | 类型 | 必填 | 默认 |
|---|---|---|---|
| `command` | string | ✅ | —(准 PAYLOAD:脚本可以很长,但通常一行) |
| `run_in_background` | boolean | ✗ | false |
| `timeout` | number | ✗ | 前台 120000ms(`limits.Timeout.BashDefaultTimeoutSec`×1000),硬上限 600000;后台忽略 |

**前台返回**(模板 `formatForegroundResult`):
```
<合并 stdout+stderr>
                       ← 空行
[<note>]               ← 仅异常时有,见下
[exit code: N]
```
- 正常结束:只有 `[exit code: 0|N]`(非零走 ExitError 分支,同格式)。
- 超时:note=`command timed out after 2m0s`,exit code -1。
- 回合取消(用户 stop/turn-cap):note=`cancelled`,exit code -1。
- exec 失败:note=`exec failed: <err>`,exit code -1。
- **硬拦截**:note=`blocked: <reason> (refused; rephrase if intentional)`,exit code -1,正文为空。
- 输出上限 256KB(`limits.Tools.BashOutputCapKB`),**保尾弃头**,头部标 `...[truncated N bytes from start]`。

**后台返回**:
```
Started background command (bash_id=bsh_<16hex>): <command>
Use BashOutput with this bash_id to poll new output, or KillShell to terminate.
```

**progress 流(全普查唯一)**:前台执行时合并 stdout+stderr 经 `io.MultiWriter` **同时**写结果 buf 和 `loopapp.ToolProgress(ctx)` —— 在 tool_call 下嵌一个流式 `progress` 块(`Open.ParentID=tool_call id`,首个非空写才开块):粒度=原始字节 chunk(delta 帧,seq=0 ephemeral),内容=终端原样滚动输出;Close 时以累积全文快照收块(`{"text": "..."}`)并随回合持久化(不回喂 LLM)。**后台模式不发 progress**(输出进 ring buffer,靠 BashOutput 轮询)。UI:前台 Bash = 活终端窗数据源;progress 无 256KB 截断(截断只作用于最终 tool_result)。

**危险相关**:`danger.go` 硬拦截 6 条灾难规则(非安全边界、非 allow/deny 配置,真正控制是框架 danger 自报):
1. `rm -rf` 根/家目录(`/`、`/*`、`~`、`$home`)
2. `sudo` / `doas`(非交互会卡密码)
3. `mkfs`
4. `dd of=/dev/...`
5. `> /dev/(sd|hd|nvme|disk|mmcblk)` 重定向覆写块设备
6. fork bomb `:(){ :|:& };:`

ValidateInput sentinel:`SHELL_EMPTY_COMMAND` / `SHELL_INVALID_TIMEOUT`(越 [0,600000])。

---

## 8. BashOutput(shell/output.go)

轮询后台 shell 的**增量**输出(游标制,只返上次 poll 之后追加的字节)+ 状态尾注。

**args**
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `bash_id` | string | ✅ | `bsh_` ID |
| `filter` | string | ✗ | regex,只保留匹配行(ValidateInput 预编译校验) |

无 PAYLOAD。

**返回**(模板 `formatOutputResult`):
```
<新输出 或 "(no new output since last poll)">
                       ← 空行
[note: N bytes dropped from buffer head before this poll due to ring overflow]  ← 仅溢出时
[status: running] | [status: exited (code N)] | [status: killed] | [status: errored]
```
后台 ring buffer 256KB(`bgBufferBytes`),溢出丢最旧字节并计数。体积:单次 ≤256KB。

**错误文案**:`Background shell process not found: <id>`(正常 tool_result;对应 sentinel `SHELL_PROCESS_NOT_FOUND` 仅内部)。
ValidateInput sentinel:`SHELL_EMPTY_BASH_ID` / filter regex 编译错(fmt 包裹)。

危险性:只读。progress:无。

---

## 9. KillShell(shell/kill.go)

终止后台 shell(组杀,连孙进程)并从注册表删除。**幂等**——杀已结束/未知 id 无害。

**args**
| 字段 | 类型 | 必填 |
|---|---|---|
| `bash_id` | string | ✅ |

无 PAYLOAD。

**返回**:`Killed background shell <id>.` 或 `Background shell <id> already finished; removed from registry.` 或 `Background shell process not found: <id>`。体积恒小。

ValidateInput sentinel:`SHELL_EMPTY_BASH_ID`。

危险性:进程终止,幂等,无确认门。progress:无。

---

## 附:UI 关键横断面速查

| 工具 | 输出形态 | PAYLOAD | 补丁风格 | progress |
|---|---|---|---|---|
| Read | cat -n 文本 | — | — | 无 |
| Write | 单行确认 | `content`(整文件) | **整体替换** | 无 |
| Edit | 单行确认 | `new_string` | **单点字面 patch(old→new,+replace_all)** | 无 |
| LS | 行式清单文本 | — | — | 无 |
| Glob | **JSON**(root/matches/total/truncated) | — | — | 无 |
| Grep | rg 风格行文本 | — | — | 无 |
| Bash | 正文+`[exit code: N]` footer | `command`(弱) | — | **前台有:原始终端字节流** |
| BashOutput | 增量正文+`[status: ...]` footer | — | — | 无 |
| KillShell | 单行确认 | — | — | 无 |

- 本批**没有 ops 型编辑工具**;文件修改只有 Write(全量)与 Edit(单点字面替换)两种 morph 源。
- Edit 的 diff 渲染素材 = args 里的 `old_string`/`new_string` 本身(结果串只有计数),前端 diff 必须从 args 流式取。
- 所有 Execute 期失败都是普通 tool_result 文本,无结构化错误标记;UI 如需"失败态"须按文案前缀识别(`File not found:` / `... failed (...)` / `blocked:` / `[exit code: 非0]` 等)。


---

# Tool 普查 02 — function / handler 系(22 工具)

> 代码源:`backend/internal/app/tool/{function,handler}/` + 底层 `app/{function,handler}`、`domain/{function,handler}`。
> 通用:`summary`/`danger`/`execution_group` 由框架注入,**不计入下述 args**。所有结果经 `toolapp.ToJSON` 压缩单行 JSON。
> `danger` 三级(safe/cautious/dangerous)是 **LLM 逐次自报**,工具本身无静态危险等级;dangerous 阻塞等用户确认。

---

## 共享机制(先读)

**ops 型补丁(create/edit 共用)**:`ops` 是 JSON 数组,每项带 `op` 判别字段;进 `ParseOps` 前先过 `jsonrepair.RepairBytes`(容忍 LLM 畸形 JSON)。ops 应用在 active 版本草稿之上,逐 op 校验,产出**整份新不可变 Version**(版本号单调 max+1),active 指针立即指向新版——**无 pending/accept 状态机**。前端 morph 心智:op = 对草稿字段的**整段替换**(set_code 换整个 code、set_inputs 换整个 inputs 数组),不是行级 diff;唯 handler 的 `update_method` 是 RFC 7396 merge patch。

**SSE-C build 镜像**:`create_function`/`edit_function`/`create_handler`/`edit_handler` 实现 `Build() BuildSpec`(function|handler × create|edit)——loop 把它们**流式生成中的 code args 实时镜像到 entities 流**,实体面板可边生成边填充(活代码窗数据源)。

**progress 块(env-fix)**:create/edit 执行中若装依赖,buildSink 把每步经 `loopapp.ToolProgress(ctx)` 流成 tool_call 下的 `progress` 块,逐行文本:
- `✓ env ready (attempt N)\n`
- `✗ attempt N failed: <error>\n`
- `↻ install failed — revising deps with an LLM (attempt N)…\n`

依赖装失败 → LLM 自动改依赖重试 ≤3 次;attempts>1 时结果带 `envFixAttempts`:`[{attempt:int, deps:[string], ok:bool, error?:string}]`。

**search 双路径(注意形状不一致)**:`search_function`/`search_handler` 若 content 搜索引擎在且 query 非空 → 语义搜索,返 `{count, total, <listKey>:[{id,name,description}], nextCursor?, hasMore?}`(description 装的是**snippet**;nextCursor/hasMore 仅截断时出现,limit 固定 20);否则回落子串搜索,返 `{count, <listKey>:[...]}`(**无 total**)。listKey = `functions` / `handlers`。

**delete 依赖注解**:删除结果基础 `{id, deleted:true}`,若有实体引用它则追加 `dependents:[{kind,id}]` + `dependentCount:int` + `note:"this entity was referenced by other entities…"`(固定长句)。删**前**取依赖边(purge 会抹边)。

**schema.Field**(inputs/outputs 元素):`{name, type, description?}`,type ∈ string|number|boolean|object|array。

---

# 一、function 系(10)

## 1. search_function
按关键词+语义搜 function 库(name/description/tags);空 query 列全部。
- **args**:`query` string 可选。
- **返回**:见「search 双路径」,listKey=`functions`。体积小(slim 行)。
- progress:无。危险:只读。
- 错误:无 sentinel(ValidateInput 恒 nil)。

## 2. get_function
取单个 function 及其 active 版本全量。
- **args**:`functionId` string **必填**。
- **返回**:Function 行完整 JSON:`{id, name, description, tags, activeVersionId, createdAt, updatedAt, activeVersion:{id, functionId, version, code, inputs, outputs, dependencies, pythonVersion, envId, envStatus, envError?, envSyncedAt?, changeReason?, builtInConversationId?, createdAt, updatedAt}}`。**PAYLOAD 输出**:`activeVersion.code`(整份 Python 源码,可达数 KB~数十 KB)。
- envStatus 枚举:pending|syncing|ready|failed。
- 错误:`FUNCTION_ID_REQUIRED`(校验)/ `FUNCTION_NOT_FOUND`。

## 3. create_function
用 ops 建新 Python function;v1 立即生效。
- **args**:`ops` array **必填非空**(PAYLOAD);`changeReason` string 可选。
- **op 动词全集(6,精确字段)**:
  | op | 字段 | 语义 |
  |---|---|---|
  | `set_meta` | `name?` `description?` `tags?:[string]` | 指针字段,nil 不动 |
  | `set_code` | `code:string` | **PAYLOAD 核心**;首个顶层 def 即入口 |
  | `set_inputs` | `inputs:[Field]` | 整组替换 |
  | `set_outputs` | `outputs:[Field]` | 整组替换 |
  | `set_dependencies` | `dependencies:[string]` | pip 列表,如 `"requests==2.31"` |
  | `set_python_version` | `version:string` | 默认 "3.12" |
  create 必含 set_meta+set_code;未知 op → `FUNCTION_OP_INVALID`(Details 带 op+reason)。
- **返回**:`{id, versionId, version:int, envStatus, opsApplied:int, envError?, envFixAttempts?}`。体积小(除 envFixAttempts 数条)。
- **progress**:有——env-fix 逐行(见共享节)。
- 危险:创建新实体,可逆(有版本史)。
- 错误:`FUNCTION_OPS_REQUIRED` / `FUNCTION_OP_INVALID` / `FUNCTION_INVALID_CODE`(无 def、空码、黑名单 import)/ `FUNCTION_NAME_DUPLICATE` / `FUNCTION_SANDBOX_UNAVAILABLE`。

## 4. edit_function
在 active 版本之上套 ops 铸新版本,立即生效。**补丁风格 = ops 型,与 create 同 6 个 op**;每个 set_* 都是字段级整段替换(改代码 = 重发整份 code)。
- **args**:`functionId` **必填**;`ops` array **必填但可为空数组**(空 = 只重建 active 版本的 env,重试装依赖);`changeReason` 可选。PAYLOAD=`ops`。
- **返回**:同 create:`{id, versionId, version, envStatus, opsApplied, envError?, envFixAttempts?}`。
- **progress**:有(env-fix)。SSE-C 镜像:有。
- 错误:`FUNCTION_ID_REQUIRED` / `FUNCTION_NOT_FOUND` / `FUNCTION_OP_INVALID` / `FUNCTION_VERSION_CONFLICT`(并发编辑撞版本号)。

## 5. revert_function
把 active 指针移到既有版本号;新版本留在历史。**name/description/tags 不随版本**(在 function 行上),revert 只还原 code/inputs/outputs/dependencies。
- **args**:`functionId` **必填**;`version` int **必填**(>0)。
- **返回**:`{id, activeVersionId, version:int}`。极小。
- progress:无。危险:可逆(指针移动)。
- 错误:`FUNCTION_ID_REQUIRED` / `FUNCTION_VERSION_POSITIVE` / `FUNCTION_VERSION_NOT_FOUND`。

## 6. delete_function
删 function 及全部版本+沙箱环境。**不可逆**(描述自明"not reversible"——LLM 应自报 dangerous → 前端阻塞确认)。
- **args**:`functionId` **必填**。
- **返回**:`{id, deleted:true}` + 依赖注解(见共享节)。
- 错误:`FUNCTION_ID_REQUIRED` / `FUNCTION_NOT_FOUND`。

## 7. update_function_meta
纯改名/改描述/改标签:只 patch function 行,**不铸版本、不重建 env**。字段 patch 风格:只传想改的字段(指针语义,省略=不动)。
- **args**:`functionId` **必填**;`name`(小写字母数字+横线下划线,1–64)/ `description` / `tags:[string]` 均可选。
- **返回**:`{id, name, description, tags}`。极小。
- 错误:`FUNCTION_ID_REQUIRED` / `FUNCTION_INVALID_NAME` / `FUNCTION_NAME_DUPLICATE` / `FUNCTION_NOT_FOUND`。

## 8. run_function
以关键字参数跑 function(每次全新隔离进程);每次运行落 execution 审计行。
- **args**:`functionId` **必填**;`args` object **必填**(schema 层面 required,ValidateInput 只查 functionId);`version` int 可选(缺省跑 active 版)。
- **返回**(`ExecutionResult`):`{ok:bool, output:any, errorMsg:string, elapsedMs:int64, logs?:string}` — `logs` 是函数自己的 print()/调试输出(adapter 头尾限长);`errorMsg` 恒出现(成功时空串),`output` 恒出现。**output/logs 可大**。
- **progress**:**无**(run 不推流;进度只有 create/edit/call_handler 有)。
- triggeredBy 自动推导:subagent ctx → `agent`,否则 `chat`(不入 args)。
- 危险:执行任意用户代码——LLM 按代码内容自报。
- 错误:`FUNCTION_ID_REQUIRED` / `FUNCTION_NOT_FOUND` / `FUNCTION_VERSION_NOT_FOUND` / `FUNCTION_NO_ACTIVE_VERSION` / `FUNCTION_ENV_NOT_READY` / `FUNCTION_SANDBOX_UNAVAILABLE` / `FUNCTION_RUN_TIMEOUT`(墙钟超限被杀)。

## 9. search_function_executions
列 function 执行历史(新→旧)+ ok/failed 汇总。
- **args**:`functionId` **必填**;`status`(ok|failed|cancelled|timeout)/ `versionId` / `limit` int(默认 50)/ `cursor` string 均可选。
- **返回**:`{executions:[Execution], nextCursor?:string, hasMore:bool, aggregates:{okCount:int, failedCount:int}}`。Execution 行含 `{id, functionId, versionId, status, triggeredBy(chat|agent|workflow|manual), input, output?, errorMessage?, logs?, elapsedMs, startedAt, endedAt, conversationId?, messageId?, toolCallId?, flowrunId?, flowrunNodeId?, flowrunIteration?, createdAt}` — 注意 list 也带全量 input/output/logs,**页可很大**。
- 错误:`FUNCTION_ID_REQUIRED` / `FUNCTION_EXECUTION_INVALID_STATUS`(非法 status 过滤,422,Details 带合法集)。

## 10. get_function_execution
按 id 取单条执行记录(原样行,无衍生 hints)。
- **args**:`executionId` **必填**。
- **返回**:单个 Execution(字段同上)。
- 错误:`FUNCTION_EXECUTION_ID_REQUIRED` / `FUNCTION_EXECUTION_NOT_FOUND`。

---

# 二、handler 系(12)

handler = 有状态 Python 类,**每 handler 一个常驻进程**(self.xxx 跨调用留存);版本模型同 function(线性只增 + active 指针)。

## 1. search_handler
搜 handler 库;空 query 列全部。
- **args**:`query` string 可选。
- **返回**:双路径,listKey=`handlers`。
- 错误:无。

## 2. get_handler
取单 handler:active 版本(类各部分+methods+init-args schema)+ 配置态 + 运行态。
- **args**:`handlerId` **必填**。
- **返回**:`{id, name, description, tags, activeVersionId, createdAt, updatedAt, activeVersion:{id, handlerId, version, imports, initBody, shutdownBody, methods:[MethodSpec], initArgsSchema:[InitArgSpec], dependencies, pythonVersion, envId, envStatus, envError?, envSyncedAt?, changeReason?, builtInConversationId?, createdAt, updatedAt}, configState?, missingConfig?:[string], runtimeState?}`。
  - MethodSpec:`{name, description?, inputs:[Field], outputs?:[Field], body, streaming:bool, timeout?:int(ms)}` — **body 是 PAYLOAD**。
  - InitArgSpec:`{name, type, description?, required:bool, sensitive:bool, default?}`(sensitive 值加密存、读时掩码——config 值本身不在返回里)。
  - configState 枚举:unconfigured|partially_configured|ready;runtimeState 枚举:running|stopped|crashed。
- 错误:`HANDLER_ID_REQUIRED` / `HANDLER_NOT_FOUND`。

## 3. create_handler
用 ops 建常驻 handler 类;v1 立即生效。类被拼装成 `HandlerImpl`(含 `__init__(self, ...initArgs)` / `shutdown(self)` / 各 method)。
- **args**:`ops` array **必填非空**(PAYLOAD);`changeReason` 可选。
- **op 动词全集(10,精确字段)**:
  | op | 字段 | 语义 |
  |---|---|---|
  | `set_meta` | `name?` `description?` `tags?` | 同 function |
  | `set_imports` | `imports:string` | import 段整替 |
  | `set_init` | `initBody:string` | `__init__` body 整替 |
  | `set_shutdown` | `shutdownBody:string` | 清理钩子整替 |
  | `set_init_args_schema` | `args:[InitArgSpec]` | 整组替换 |
  | `add_method` | `method:MethodSpec` | 追加;**字段必须嵌在 "method" 下**,顶层多余键大声报错并回示正确形状;重名报错 |
  | `update_method` | `name:string` `patch:object` | **RFC 7396 merge patch**(null 删键、嵌套递归合并)——唯一非整替 op |
  | `delete_method` | `name:string` | 删指定 method |
  | `set_dependencies` | `dependencies:[string]` | 同 function |
  | `set_python_version` | `version:string` | 默认 "3.12" |
  create 必含 set_meta + ≥1 个 add_method。
- **返回**:`{id, versionId, version, envStatus, opsApplied, envError?, envFixAttempts?}` — **create 刻意不报 runtimeState**(新 handler 不 spawn,几乎总要先配 config,"未运行"是预期)。
- **progress**:有(env-fix)。SSE-C 镜像:有。
- 错误:`HANDLER_OPS_REQUIRED` / `HANDLER_OP_INVALID`(Details 带 op+reason)/ `HANDLER_INVALID_CODE` / `HANDLER_NAME_DUPLICATE` / `HANDLER_SANDBOX_UNAVAILABLE`。

## 4. edit_handler
ops 套在 active 版本上铸新版并**重启常驻实例**(抹内存态)。三条特殊路径,UI 必须区分:
1. **全 set_meta ops** → 不铸版本、不重启,内存态保全(纯改名首选路径之一)。
2. **空 ops 数组** → 重建 env + 重启,不铸版本;结果带 `restarted:true` + `restartNote:"rebuilt the environment and restarted the resident instance — in-memory state was wiped…"`(长句,提醒非 no-op)。
3. **普通代码 edit** → 新版本 + 重启;结果带 `runtimeState`,若 ≠ "running" 追加 `runtimeWarning:"the resident instance is not running after this edit — …fix the code, or revert_handler…"`(坏 `__init__` 的 env 照样 ready,靠这个字段揭穿 brick)。
- **⚠️ 校正(2026-07-06 读码)**:`runtimeState` **三条路径都出现**(`build.go:152-157` 无论哪条都调 `Get` 取 state,`manager.State` 永不返空:`stopped|running|crashed`),非仅路径 3。`runtimeWarning` 后端在 `runtimeState != "running"` 时都发——**故一次纯改名(路径 1)若 handler 从未 spawn(`stopped`)也会带 runtimeWarning**,这是良性态、非「本次弄坏」。**UI 收窄**:`crashed` 才是真 brick(红警告 + 危险回执自动展开);`stopped` 良性(静音徽,不显 runtimeWarning);`running` 绿。`envStatus` 在 create/edit 结果里只会是 `ready|failed`(同步 ensureEnv;pending/syncing 是过程态)。失败 tool_result 是**纯文本**(Surface 的 Message+Details,不含 wire code、非 JSON)——前端须先判 block.status=error 再决定是否 JSON.parse。
- **args**:`handlerId` **必填**;`ops` array **必填可空**(PAYLOAD);`changeReason` 可选。op 集同 create。
- **返回**:`{id, versionId, version, envStatus, opsApplied, restarted?, restartNote?, envError?, runtimeState?, runtimeWarning?, envFixAttempts?}`。
- **progress**:有(env-fix)。SSE-C 镜像:有。
- 错误:`HANDLER_ID_REQUIRED` / `HANDLER_NOT_FOUND` / `HANDLER_OP_INVALID` / `HANDLER_VERSION_CONFLICT`。

## 5. revert_handler
active 指针移到旧版本号,然后**重启实例**跑它。name/description/tags 不随版本。
- **args**:`handlerId` **必填**;`version` int **必填**(>0)。
- **返回**:`{id, activeVersionId, version}`。
- 错误:`HANDLER_ID_REQUIRED` / `HANDLER_VERSION_POSITIVE` / `HANDLER_VERSION_NOT_FOUND`。

## 6. delete_handler
停常驻实例 + 删全部版本与环境。**不可逆**。
- **args**:`handlerId` **必填**。
- **返回**:`{id, deleted:true}` + 依赖注解。
- 错误:`HANDLER_ID_REQUIRED` / `HANDLER_NOT_FOUND`。

## 7. call_handler
调常驻实例上的一个 method(首用自动拉起实例);每次调用落 call 审计行。
- **args**:`handlerId` **必填**;`method` string **必填**;`args` object **必填**(schema required;ValidateInput 只查前两个)。
- **返回**:`{result: <method 返回值>}` — result 为任意 JSON,**可大**。流式 method:结果 = 最后一个非 progress yield **或** return 值(两者都算)。
- **progress**:**有** — 流式 method 每个 yield 实时流成 `progress` 块:字符串 yield 原样 + `\n`,非字符串 JSON 序列化 + `\n`。非流式 method 无 progress。
- triggeredBy 由 ctx 推导(subagent→agent,否则 chat)。
- 危险:执行用户代码 + 可能外部写——LLM 自报。
- 错误:`HANDLER_ID_REQUIRED` / `HANDLER_METHOD_REQUIRED` / `HANDLER_NOT_FOUND` / `HANDLER_METHOD_NOT_FOUND` / `HANDLER_NO_ACTIVE_VERSION` / `HANDLER_ENV_NOT_READY` / `HANDLER_CONFIG_INCOMPLETE`(必填 init-args 未配)/ `HANDLER_INSTANCE_SPAWN_FAILED` / `HANDLER_CRASHED` / `HANDLER_RPC_TIMEOUT`(单 method timeout 或全局默认触发)。

## 8. update_handler_config
设 init-args 配置值(传给 `__init__` 的),然后重启实例生效。**JSON Merge Patch 语义**:传部分对象,null 删键。秘密值(api key 等)通常由用户在 UI 填,工具只设 LLM 真有的值。
- **args**:`handlerId` **必填**;`config` object **必填**(merge patch)。
- **返回**:`{id, configUpdated:true}`。极小。
- 错误:`HANDLER_ID_REQUIRED` / `HANDLER_NOT_FOUND` / `HANDLER_CONFIG_DECRYPT_FAILED`(内部)。

## 9. update_handler_meta
不重启的纯改名/描述/标签:只 patch handler 行,**无新版本、无重启、self.xxx 保全**。字段 patch,省略=不动。
- **args**:`handlerId` **必填**;`name`(同 function 规则)/ `description` / `tags` 可选。
- **返回**:`{id, name, description, tags}`。
- 错误:`HANDLER_ID_REQUIRED` / `HANDLER_INVALID_NAME` / `HANDLER_NAME_DUPLICATE` / `HANDLER_NOT_FOUND`。

## 10. restart_handler
优雅重启常驻进程(跑 shutdown() → 以最新 config+code 起新实例)。对话内"这 handler 坏了重启它"路径(HTTP :restart 是编辑器按钮路径)。
- **args**:`handlerId` **必填**。
- **返回**:成功 `{id, runtimeState}`;**失败不返回工具错误**,而是折进结果:`{id, runtimeState, error:"<message>"}` — UI 若只按 tool error 判失败会漏掉这种"结果内失败"。
- progress:无。危险:抹内存态(cautious 级别倾向)。
- 错误(结果内):spawn 失败等以 error 字符串出现;校验 `HANDLER_ID_REQUIRED`。

## 11. search_handler_calls
列 handler 调用历史(新→旧)+ ok/failed 汇总。
- **args**:`handlerId` **必填**;`method` / `status`(ok|failed|cancelled|timeout)/ `limit` int / `cursor` string 可选。
- **返回**:`{calls:[Call], nextCursor?, hasMore:bool, aggregates:{okCount, failedCount}}`。Call 行:`{id, handlerId, versionId, method, status, triggeredBy, input, output?, errorMessage?, logs?, elapsedMs, startedAt, endedAt, instanceId?, conversationId?, messageId?, toolCallId?, flowrunId?, flowrunNodeId?, flowrunIteration?, createdAt}` — list 带全量 input/output/logs,页可大。
- 错误:`HANDLER_ID_REQUIRED` / `HANDLER_CALL_INVALID_STATUS`。

## 12. get_handler_call
按 id 取单条调用记录;logs 含该次调用期间 method 的 yields + print()/stderr。
- **args**:`callId` **必填**。
- **返回**:单个 Call(字段同上)。
- 错误:`HANDLER_CALL_ID_REQUIRED` / `HANDLER_CALL_NOT_FOUND`。

---

## UI 要点速记

1. **morph 基础 = 整段替换**:function 全部 op、handler 除 update_method 外都是字段整替;`update_method` 是唯一 merge patch(可做字段级 diff 展示)。
2. **PAYLOAD 字段**:function `set_code.code`;handler `add_method.method.body` / `set_init.initBody` / `set_imports.imports`。create/edit 的活代码窗靠 SSE-C 镜像喂(不用等 tool_result)。
3. **progress 三处**:create/edit_*(env-fix 逐行,✓/✗/↻ 前缀文本)、call_handler(流式 method 的 yield 逐行);run_function **没有**。
4. **诚实终态字段**:edit_handler 的 `runtimeState`/`runtimeWarning`/`restarted`/`restartNote`,restart_handler 的结果内 `error` — 都是"工具成功但物已坏"的信号,值得视觉强调。
5. **search 结果两形状**(语义路径有 total/nextCursor,子串路径没有),前端需兜。
6. **delete 的 dependents 列表**是修复入口(kind+id 可点跳)。


---

# 普查 03 — agent/ + subagent/ 工具族(共 12 个)

> 源:`backend/internal/app/tool/agent/{agent,build,build_spec,lifecycle,query,executions,sentinels}.go` + `backend/internal/app/tool/subagent/{subagent,trace}.go`。
> 佐证:`app/agent/{invoke,executions}.go`、`domain/agent/{agent,execution}.go`、`app/tool/{tool,dependents,contentsearch}.go`、`app/subagent/registry.go`。
> summary/danger/execution_group 为框架注入,下文一律不计入 args。agent 系全部是**懒加载工具**(Toolset.Lazy,经 search_tools 浮现)。**无 accept 工具**:create/edit 立即生效(无 pending/accept 状态机)。

---

## 1. search_agent

- **用途**:按关键词+语义(FTS 覆盖 name/description/tags/正文)搜 agent;空 query 列全部。
- **Parameters**:`query` string 可选(空=列全部)。无 PAYLOAD。
- **Execute 返回**(JSON):
  - FTS 引擎可用且 query 非空 → `{"count": N, "total": M, "agents": [{"id","name","description"(=snippet)}], "nextCursor"?, "hasMore"?}`(SlimPageResult,页上限 20,`hasMore` 只在有 nextCursor 时出现且恒 true);
  - 引擎缺席/空 query → 回退子串路径:`{"agents": [{"id","name","description"}], "count": N}`(**无 total/hasMore**——两条路径形状不完全一致)。
- **progress**:无。
- **危险**:只读。
- **错误**:无 sentinel(ValidateInput 恒 nil;坏 JSON → `search_agent: bad args`)。

## 2. get_agent

- **用途**:取 agent 全配置(经 active version 一趟拿齐)。
- **Parameters**:`agentId` string **必填**。
- **Execute 返回**:整个 `agentdomain.Agent` 直接 ToJSON:
  ```
  {"id","name","description","tags":[],"activeVersionId","createdAt","updatedAt",
   "activeVersion": {"id","agentId","version":int,"prompt","skill"?,"knowledge":[docId],
     "tools":[{"ref","name"}], "inputs":[{"name","type","description"?}], "outputs":[同],
     "modelOverride"?:{"apiKeyId","modelId"}, "changeReason"?, "builtInConversationId"?,
     "createdAt","updatedAt"}}
  ```
  (workspace_id/deleted_at 以 `json:"-"` 隐去;`activeVersion` omitempty——无活跃版本时缺席)。
- **progress**:无。危险:只读。
- **错误**:`AGENT_ID_REQUIRED`;下游 `AGENT_NOT_FOUND`(404)。
- ⚠️ Description 有陈旧句:"Read this before edit_agent (edit replaces the whole config)"——**edit 实际早已是合并语义**(见下),此句与 edit_agent 自己的描述矛盾,代码行为以 merge 为准。

## 3. create_agent 【BuildTool】

- **用途**:新建 agent(配置好的 LLM worker,不写代码,按引用挂载能力);v1 立即生效。
- **Parameters**:required `["name","prompt"]`
  | 字段 | 类型 | 说明 |
  |---|---|---|
  | name | string 必填 | 唯一名 |
  | description | string | 一句话角色 |
  | tags | string[] | |
  | **prompt** | string 必填 | **PAYLOAD**(system prompt,大体量创作内容) |
  | skill | string | 0-1 个 skill 名,必须已存在(不存在建时拒);只注入 Guide,allowed-tools 预授权**不**随带 |
  | knowledge | string[] | 文档 ID,必须都已存在 |
  | tools | [{ref, name?}] | ref ∈ fn_… / hd_…method / mcp:server/tool,**禁 ag_**;name 运行时被忽略(恒用实体现名,不可别名) |
  | inputs | [{name,type,description}] | type ∈ string\|number\|boolean\|object\|array |
  | outputs | [同 inputs] | 空=自由文本终答;非空=终答为含这些字段的 JSON 对象 |
  | modelOverride | {apiKeyId, modelId} | 可选,覆盖默认 agent 模型 |
  | changeReason | string | 一行变更理由 |
- **Execute 返回**:`{"id": "ag_…", "versionId": "agv_…", "version": 1}`(小)。
- **progress / 流式**:实现 `BuildTool` → `BuildSpec{Kind:"agent", Op:"create"}`。**loop 把流式 tool-call args 的 delta 镜像到 entities SSE 流(SSE-C)**——前端 agent 面板随 LLM 打字实时填充(loop 不解析 args,前端自己解析流式 JSON)。这是本族唯一"执行前进度"形态。
- **危险**:写但可逆(新实体);无工具侧确认逻辑(danger 由 LLM 自报)。
- **错误**:`AGENT_NAME_PROMPT_REQUIRED`(name/prompt 任一空白);下游:`AGENT_NAME_CONFLICT`(409)、`AGENT_SKILL_NOT_FOUND`、`AGENT_KNOWLEDGE_NOT_FOUND`、`AGENT_TOOLS_AGENT_REF`(ag_ ref)、`AGENT_TOOL_REF_BLANK`、`AGENT_INVALID_MODEL_OVERRIDE`(均 422)。

## 4. edit_agent 【BuildTool】

- **用途**:编辑 agent 配置,产新版本立即生效。
- **补丁风格:字段级 MERGE patch(非 ops、非整体替换)**——这是本族 morph 关键:
  - 以 agent 当前 active config 为基底,**只覆盖请求 JSON 里"键实际出现"的字段**(`mergeConfig` 用 `map[string]RawMessage` 探键存在性);
  - 缺省键 → 保留现值;显式传空(`[]` / `""` / `null`)→ 清空;
  - 可 merge 的键 = configArgs 全集:prompt / skill / knowledge / tools / inputs / outputs / modelOverride / changeReason;
  - 历史注释:原全替换曾致 prompt-only 编辑抹掉 tools/knowledge,实测 ~40% 丢配率,故改 merge(F-edit-agent-merge)。
- **Parameters**:required `["agentId"]`;其余同 create 的 configProps(prompt 此处**非必填**)。**PAYLOAD = prompt**。
- **ValidateInput 特例**:请求里出现 `name`/`description`/`tags` 任一键 → **大声拒** `AGENT_META_NOT_IN_EDIT`(它们在 agent 行、非版本化 config,指向 update_agent_meta;修 F171 静默吞 meta)。
- **Execute 返回**:`{"agentId","versionId","version":int}`(小)。
- **progress / 流式**:`BuildSpec{Kind:"agent", Op:"edit"}`——同 create,args delta 镜像 entities 流,面板实时填充。
- **危险**:改可恢复状态(版本史即 undo)。
- **错误**:`AGENT_ID_REQUIRED` / `AGENT_META_NOT_IN_EDIT`;下游同 create 的 422 族 + `AGENT_NOT_FOUND` + `AGENT_VERSION_CONFLICT`(并发编辑 409)。

## 5. revert_agent

- **用途**:把 active 指针移回既有旧版本号(不重编号);版本史即 undo。**只还原版本化 config**,name/description/tags 不动。
- **Parameters**:required `["agentId","version"]`;`version` integer(目标版本号,≥1)。
- **Execute 返回**:`{"agentId","versionId","version":int}`。
- **progress**:无(非 BuildTool——revert 不流内容)。
- **错误**:`AGENT_REVERT_ARGS_REQUIRED`(agentId 空或 version<1);下游 `AGENT_VERSION_NOT_FOUND`(404)。

## 6. delete_agent

- **用途**:软删 agent;挂载关系边被抹、执行史保留。
- **Parameters**:`agentId` string 必填。
- **Execute 返回**:**人话字符串、非 JSON**(模板):
  `Deleted agent "ag_xxx".`
  有依赖时追加后缀:` Note: this entity was referenced by other entities (workflows/agents that equipped it, or documents that linked it); they may now fail — the referencing entities are listed in `dependents`; edit each to drop or repoint the now-dead reference. Referencing entities: [wf_1 ag_2 …].`
  (依赖 ref 在删**前**经 `DependentRefs` 读——purge 会抹边;advisory,读失败绝不阻删。注意:句里说 "listed in `dependents`" 但字符串出口实际只列 id 数组——措辞是 JSON 版 AnnotateDependents 的复用。)
- **progress**:无。
- **危险**:**本族最危险**(不可逆意图,虽为软删);无工具侧确认——阻塞确认靠 LLM 自报 danger=dangerous + loop 内存闸。UI 应视为高危卡。
- **错误**:`AGENT_ID_REQUIRED`;下游 `AGENT_NOT_FOUND`。

## 7. update_agent_meta

- **用途**:纯改名/改描述/改 tags——只 patch agent 行,**不产新版本**。与 edit_agent 互补(meta ↔ 版本化 config 的不对称,同 function/workflow set_meta)。
- **Parameters**:required `["agentId"]`;`name`(小写字母数字+连字符/下划线,1-64)/ `description` / `tags` 均可选,**指针语义:只传想改的**(Execute 用 `*string`/`*[]string` 区分缺席 vs 传空)。
- **Execute 返回**:`{"id","name","description","tags":[]}`(patch 后的行)。
- **progress**:无。危险:轻写。
- **错误**:`AGENT_ID_REQUIRED`;下游 `AGENT_NOT_FOUND`、`AGENT_NAME_CONFLICT`。

## 8. invoke_agent

- **用途**:跑一次 agent 的 ReAct loop,返终态输出;每次运行落 `agent_executions` 一行。
- **Parameters**:required `["agentId","input"]`
  - `agentId` string;
  - `input` **object 必填**——本次任务/数据(schema 明说"没有单独 prompt 字段");自包含 agent 传 `{}`。`input:null`/缺席 → 拒(防任务键写错却跑出误导 ok:true)。
  - 注:app 层 `InvokeInput` 还有 MaxTurns/VersionID 等,但**工具不透出**——恒 active 版本 + 默认轮上限(`limits.Agent.InvokeMaxTurns`)。
- **Execute 返回**(`InvokeResult` ToJSON):
  ```
  {"executionId":"agexec_…","ok":bool,"output":any,"status":"ok|failed|cancelled|timeout",
   "stopReason"?,"steps":int,"tokensIn":int,"tokensOut":int,"errorMsg"?,"elapsedMs":int}
  ```
  `output`:无声明 outputs → 自由文本串;单声明 → `{name: text}`;多声明 → JSON 对象(拆不开则整次 fail,`AGENT_OUTPUT_NOT_STRUCTURED`)。体积中等(output 可大,transcript 不在此返回)。
- **progress / 流式(UI 重点,双通道)**:工具接口本身无 progress 参数,但 app 层 `InvokeAgent` 做两件事:
  1. **E3 嵌套(messages 流)**:chat 内经 tool 调起时(ctx 有 toolCallId),agent 的全部流式 block(text/reasoning/tool_call/tool_result 逐步)**实时嵌在 invoke_agent 这个 tool_call 之下**——前端把子 agent 运行内联渲成该 tool 的中间过程。这些 block **仅流、不落 message_blocks**;耐久记录是 Execution.Transcript,reload 时前端从 transcript 重水合。
  2. **SSE-C(entities 流)**:同一 ReAct 轨迹每个 block 镜像到 `Scope{Kind:agent, ID:ag_…}` 的 entities 流——agent 面板实时看到运行,与触发方无关(chat/REST/workflow)。
- **危险**:执行体;耗 token;墙钟上限 `limits.Timeout.AgentInvokeSec`(超时 → status=timeout,可 :replay)。
- **错误**:`AGENT_ID_REQUIRED` / `AGENT_INPUT_REQUIRED`(消息自带指引:"pass {} if self-contained — there is no 'prompt' field");下游 `AGENT_NOT_FOUND`、`AGENT_NO_ACTIVE_VERSION`(422)、`AGENT_MOUNT_INVALID`(挂载解析失败)、`AGENT_OUTPUT_NOT_STRUCTURED`。

## 9. search_agent_executions

- **用途**:搜执行史,cursor 分页 + ok/failed 汇总徽标。
- **Parameters**(全可选):
  | 字段 | 类型 | 枚举 |
  |---|---|---|
  | agentId | string | |
  | status | string | `ok` \| `failed` \| `cancelled` \| `timeout` |
  | triggeredBy | string | `chat` \| `workflow` \| `manual` |
  | conversationId | string | |
  | flowrunId | string | |
  | limit | integer | |
  | cursor | string | |
- **Execute 返回**:
  ```
  {"executions":[Execution…], "nextCursor"?, "hasMore":bool,
   "aggregates":{"okCount":int,"failedCount":int}}
  ```
  Execution 行字段:`id, agentId, versionId, modelId?, apiKeyId?, provider?, status, triggeredBy, input, output?, transcript?, errorMessage?, elapsedMs, startedAt, endedAt, conversationId?, messageId?, toolCallId?, flowrunId?, flowrunNodeId?, flowrunIteration?, createdAt`。
  ⚠️ **列表行是全列查询,`transcript`(完整 block 序列 JSON)也随行返回**——体积可能非常大(同 F173 get_flowrun 倾倒问题的姊妹面);描述里"Use get_agent_execution for one run's full input/output"暗示 slim,代码并未投影瘦身。UI 侧列表应只取概要字段。
  aggregates 的汇总**忽略 status 过滤**(徽标恒显匹配集两半);failedCount = 非 ok 总数(含 cancelled/timeout)。
- **progress**:无。危险:只读。
- **错误**:无 ValidateInput sentinel;store 侧非法 status → `AGENT_EXECUTION_INVALID_STATUS`(422,Details 带 `{"allowed":[…],"got":…}`,可自纠)。

## 10. get_agent_execution

- **用途**:按 id 取单条执行完整记录(含全 transcript——invoke_agent 卡"查看轨迹"的数据源)。
- **Parameters**:`executionId` string 必填。
- **Execute 返回**:单个 Execution 全行 ToJSON(字段同上,含 `transcript` 完整 block 序列)。**典型体积大**(transcript = 跨步 text/reasoning/tool_call/tool_result 全量)。
- **progress**:无。危险:只读。
- **错误**:`AGENT_EXECUTION_ID_REQUIRED`;下游 `AGENT_EXECUTION_NOT_FOUND`(404)。

---

## 11. Subagent (注意:大写 S,非 snake_case)

- **用途**:派一个隔离子 agent 跑聚焦子任务、返其最终答案(Task 工具)。子 agent 看不到本对话历史、**不能再派子 agent**(工具集不含 Subagent + ctx 双守卫)。
- **Parameters**:required `["subagent_type","prompt"]`(**snake_case 字段,本族唯一**)
  - `subagent_type` string,enum 由 runner 注册表注入,内置三值:`Explore`(只读代码侦察)/ `Plan`(调研出实施计划)/ `general-purpose`(父工具全集的聚焦 worker);
  - `prompt` string——**PAYLOAD**(自包含任务描述)。
- **Execute 返回**:**原始字符串** = 子 agent 的最终答案文本(无 JSON 包裹)。体积=一段回答,可长。
- **progress / 流式**:工具本身不发 progress;但子 agent 的回合作为带 `SubagentID` 的 **sub-message 落父对话**(E3 嵌套,Attrs.parentBlockId = 派它的 tool_call block id)——messages 流上实时可见嵌套轨迹,父 LLM 历史却排除它(故有 trace 工具)。
- **危险**:general-purpose 持父工具集(含写工具),危险度取决于任务;Explore/Plan 白名单只读。
- **错误**(均 plain error,非 sentinel,渲成 tool_result 供重试):`prompt is required` / `subagent_type must be one of […]` / `a subagent cannot spawn another subagent`(递归拒) / `subagent run failed: …`(派发失败降级为 tool-result,不冒 HTTP)。

## 12. get_subagent_trace

- **用途**:读回**本对话**内某 subagent 干了什么(只读)。subagent 无自己的表——轨迹是父对话里带 SubagentID 的 sub-message,内存过滤。
- **Parameters**:`subagentRunId` string 可选(`subagt_…`);**省略 = 列出本对话全部 subagent run**,带 id = 导出该 run 完整 trace。双形态一工具。
- **Execute 返回**(JSON):
  - 列表形态:`{"count":N, "subagentRuns":[{"subagentRunId","status","stopReason"?,"finalText"?(末个 text 块=答案),"blockCount":int,"spawningToolCallId"?}]}`(时序=派发序);
  - 详情形态:`{"subagentRunId","status","stopReason","errorMessage","spawningToolCallId","blocks":[{"type","status"?,"content"?,"error"?,"blockId"?,"parentBlockId"?}]}`(块按 Seq 落盘序;详情体积可大)。
  - 降级字符串(非错):不在对话内 → `get_subagent_trace is only available inside a conversation (no conversationId in context).`;未知 id → `No subagent run "xxx" in this conversation. Call get_subagent_trace with no arguments to list the runs that exist here.`
- **progress**:无。危险:只读。
- **错误**:仅坏 JSON(`get_subagent_trace: bad args`);仓储读错才真冒泡。

---

## 横切事实(UI 相关)

- **补丁风格总结**:本族**没有 ops 型工具**。edit_agent = 字段级 merge patch(present-key overlay);update_agent_meta = 指针字段 patch;revert = 指针移动;无任何整体替换。
- **进度呈现三形态**:① create/edit_agent 靠 BuildTool SSE-C **args 流式镜像**(执行前面板实时填充);② invoke_agent 靠 **E3 块嵌套 + SSE-C run 轨迹**(执行中);③ 其余工具零进度、一次性返回。
- **依赖警示**:delete_agent 结果内联点名依赖实体 id(删前快照)——UI 可渲成"可能受影响"列表。
- **版本模型**:版本号单调 max+1、永不重编;每 agent 留存上限 50(AcceptedVersionCap,写时裁剪)。


---

# Workflow 工具族普查(backend/internal/app/tool/workflow/)

> 代码为准。共 **17 个工具**(比预期多 2:`list_approval_inbox` + `decide_approval`,人在环半边)。
> 全部为懒加载工具(Toolset.Lazy,经 search_tools 浮现)。
> 所有工具结果经 `toolapp.ToJSON` 输出**紧凑 JSON 字符串**(无缩进)。
> summary/danger/execution_group 为框架注入,下文一律不计。
> **无任何工具接 progress emitter**——Execute 签名只有 `(ctx, argsJSON)`,执行中不发 progress 块。唯一"流式"行为是 create/edit_workflow 实现 `BuildTool` 接口(build_spec.go):loop 把**流入的 args delta 镜像到 entities SSE 流(SSE-C)**,`BuildSpec{Kind:"workflow", Op:"create"|"edit"}`——前端可在 args 流入时实时长出画布节点/边(loop 不解析 args,前端自己解析流式 ops)。

---

## 1. create_workflow(build.go)

用 ops 数组从零建 workflow 图;v1 立即生效,新建即 deactivated(需另行 activate)。

**Parameters**(required: `name`, `ops`):
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| name | string | ✓ | workspace 内唯一名(snake_case 约定) |
| description | string | | |
| tags | string[] | | |
| **ops** | object[] | ✓(非空) | **PAYLOAD**。图编辑 op 数组,带 `op` 判别字段 |
| changeReason | string | | 一行变更原因 |

**ops 即补丁语言(与 edit_workflow 完全同一套,7 个 op 动词,按声明序逐个生效)**:

| op | 字段 | 语义 |
|---|---|---|
| `set_meta` | `name?` `description?` `tags?` `concurrency?`(serial\|skip\|buffer_one\|replace\|allow_all,默认 serial) | 只改头部身份,不动图;多个 set_meta 按字段后者胜 |
| `add_node` | `node: {id, kind, ref, input?, retry?, pos?, notes?}` | 加节点;id 空/重复报错;**node 内容字段误放 op 顶层(input/ref/kind/retry/fromPort 当 "node" 的兄弟)会被显式拒绝**(strayNodeKeys 防呆) |
| `update_node` | `id`, `patch: {…部分节点字段…}` | **RFC7396 式顶层合并**:patch 出现的键整体覆写(`input`/`retry` 是**整对象替换、非深合并**——改一个 input 键须重发全部 input 键);`id` 不可变(patch 里的 id 被忽略) |
| `delete_node` | `id` | 删节点,**级联删掉触及它的所有边** |
| `add_edge` | `edge: {id, from, to, fromPort?}` | 加边;fromPort 仅 control(分支名)/approval(yes\|no)源必填、其余必须缺席 |
| `update_edge` | `id`, `patch: {…}` | 同 update_node 的顶层合并;id 不可变 |
| `delete_edge` | `id` | 删边 |

**Node 结构**(domain/workflow/workflow.go):`{id, kind, ref, input?: map<string,string 裸CEL>, retry?: {maxAttempts, backoff?, delayMs?}, pos?: {x,y}, notes?}`。kind∈trigger|action|agent|control|approval;ref 前缀按 kind:trg_ / (fn_|hd_<id>.method|mcp:server/tool) / ag_ / ctl_ / apf_。input 的 CEL 直接按上游节点 id 取值(`"start.amount"`),无 payload/ctx 根。
**Edge 结构**:`{id, from, fromPort?, to}`。

**Execute 返回**:`{"id":"wf_…","versionId":"wfv_…","version":1,"active":false,"lifecycleState":"inactive"}`。小体积(单行)。

**ValidateInput sentinels**:`WORKFLOW_NAME_REQUIRED` / `WORKFLOW_OPS_REQUIRED`。
**Execute 期错误**(domain):`WORKFLOW_INVALID_OPS`(op 畸形/图不一致,details.reason 带 `ops[i] (op类型): 原因`)、`WORKFLOW_INVALID_GRAPH`(结构校验失败:≥1 trigger、无孤儿节点、回边只准出自 control/approval 等,details.reason)、`WORKFLOW_NAME_DUPLICATE`(Conflict)。

**UI 要点**:Description 内嵌约 3KB 的 opsDoc(op 形状 + 节点结果形状 + 分支/合流/循环语义教程)。ops 是唯一大体量创作内容;配合 SSE-C 镜像可做"图实时生长"画布。

---

## 2. edit_workflow(build.go)

在 active 图之上应用 ops 产出新版本,立即生效(无 pending/accept)。回退用 revert_workflow。

**Parameters**(required: `workflowId`, `ops`):
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| workflowId | string | ✓ | |
| **ops** | object[] | ✓(非空) | **PAYLOAD**。同 create 的 7 op 补丁语言(见上表) |
| changeReason | string | | |

**补丁风格 = ops 型**(前端 morph 的关键):不是整图替换、不是字段 patch,而是**有序 op 流对 active 图做增量变换**;其中 update_node/update_edge 内部又是**顶层 merge-patch**(present-key-wins,input 整体替换)。

**Execute 返回**:`{"id":"wf_…","versionId":"wfv_…","version":N}`。
**错误**:`WORKFLOW_ID_REQUIRED` / `WORKFLOW_OPS_REQUIRED`(ValidateInput);`WORKFLOW_NOT_FOUND`、`WORKFLOW_INVALID_OPS`、`WORKFLOW_INVALID_GRAPH`、`WORKFLOW_VERSION_CONFLICT`(并发编辑)。
**SSE-C**:同 create,BuildSpec{workflow, edit}。

---

## 3. revert_workflow(build.go)

把 active 指针移到既有版本号;新版本留在历史、可切回。

**Parameters**(required 全部):`workflowId` string;`version` integer(要设为 active 的版本号,须 >0)。无 PAYLOAD。
**Execute 返回**:`{"id":"wf_…","activeVersionId":"wfv_…","version":N}`(注意键名是 **activeVersionId**,与 edit 的 versionId 不同)。
**错误**:`WORKFLOW_VERSION_POSITIVE`(ValidateInput);`WORKFLOW_NOT_FOUND` / `WORKFLOW_VERSION_NOT_FOUND`。

---

## 4. delete_workflow(build.go)

删 workflow 及全部图版本,**不可逆**;结果报告哪些实体曾引用它(可能因此坏掉)。

**Parameters**:`workflowId` string(唯一,必填)。
**Execute 返回**:基础 `{"id":"wf_…","deleted":true}`;若删前查到依赖(relation equip/link 入边),追加三键:`"dependents":[{"kind":"agent","id":"ag_…"},…]`、`"dependentCount":N`、`"note":"this entity was referenced by other entities…"`(固定修复提示句)。依赖读取 advisory——读失败不阻删。
**危险倾向**:描述明言 "This is not reversible",建议删前用 get_relations 查依赖。UI 应按危险动作呈现。
**错误**:`WORKFLOW_ID_REQUIRED`;`WORKFLOW_NOT_FOUND`。

---

## 5. search_workflow(query.go)

按关键词 + 语义相关度找 workflow(name/description/tags,接了内容引擎时含正文);空 query 列全部。

**Parameters**:`query` string(可选;缺省/空 = 列全部)。无必填。
**Execute 返回**(两条路径,schema 对 UI 略有差):
- 内容引擎路径(query 非空且引擎在):`{"count":N,"total":M,"workflows":[{"id","name","description"(实为搜索 snippet)}…],"nextCursor"?,"hasMore"?}`(截断披露,页上限 20)。
- 回退子串路径(空 query/无引擎/引擎错):`{"count":N,"workflows":[{"id","name","description","lifecycleState","active"}…]}`——**只有这条路径带 lifecycleState/active**。
**体积**:slim 行,中等;全列时随库存线性。
**错误**:几乎无(ValidateInput 恒 nil)。

---

## 6. get_workflow(query.go)

取单个 workflow + active 版本完整图。

**Parameters**:`workflowId` string(必填)。
**Execute 返回**:整个 `Workflow` struct 直接 ToJSON:`{"id","name","description","tags","active","lifecycleState","concurrency","needsAttention","attentionReason"?,"lastActionBy","activeVersionId","createdAt","updatedAt","activeVersion":{"id","workflowId","version","graph"(JSON blob 字符串),"changeReason"?,"builtInConversationId"?,"createdAt","updatedAt","graphParsed":{"nodes":[…],"edges":[…]}}}`。
**注意双份图**:`graph` 是原始 JSON 字符串、`graphParsed` 是解码对象——前端应读 graphParsed。
**体积**:随图大小;典型几 KB,大图可到几十 KB。
**错误**:`WORKFLOW_ID_REQUIRED`;`WORKFLOW_NOT_FOUND` / `WORKFLOW_NO_ACTIVE_VERSION`。

---

## 7. capability_check_workflow(capability.go)

校验 active 图:结构健全 + (catalog 在时)每个被引用实体存在、有 active 版本、暴露图所用端口/方法。problems=阻塞、warnings=advisory(含"读未声明输出"提示)。**不完全校验数据流**——干净报告仍需一次 trigger_workflow 实跑确认。

**Parameters**:`workflowId` string(必填)。
**Execute 返回**:`{"id","ok":bool,"structurallyValid":bool,"resolved":bool,"problems":[…],"warnings":[…]}`。
**错误**:`WORKFLOW_ID_REQUIRED`;`WORKFLOW_NOT_FOUND` / `WORKFLOW_NO_ACTIVE_VERSION`。
**UI 要点**:report 天然适合 checklist 呈现(ok 绿 / problems 红块 / warnings 黄块)。

---

## 8. trigger_workflow(exec.go)

手动跑一次("run now"),payload 假装 trigger fire。**手动 run 不走 concurrency/overlap 政策**(那只管真实触发)——两个手动 run 可并存。不改监听状态。

**Parameters**(required: `workflowId`):
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| workflowId | string | ✓ | |
| payload | object | | 喂给入口 trigger 节点作其结果;须匹配触发器 fire-payload 形状(webhook 嵌 `{"body":{…}}`、cron `{"firedAt":…}`、fsnotify `{"path","eventKind","firedAt"}`);缺省 `{}` |

**Execute 返回**:`{"flowrunId":"fr_…","workflowId":"wf_…"}`——异步启动,查进展用 get_flowrun。
**错误**:`WORKFLOW_ID_REQUIRED`;`WORKFLOW_NOT_FOUND` / `WORKFLOW_NO_ACTIVE_VERSION` / `FLOWRUN_INVALID_ENTRY`(入口 trigger 无效/歧义)。

---

## 9. stage_workflow(exec.go)

待命一次:下一次**真实**触发跑一次然后自动解除——真事件试跑。已 active 则拒;坏图拒绝待命。

**Parameters**:`workflowId` string(必填,唯一)。
**Execute 返回**:`{"staged":true,"workflowId":"wf_…"}`。
**错误**(UI 值得区分):`WORKFLOW_ALREADY_ACTIVE`(Conflict,先 deactivate)/ `WORKFLOW_NO_TRIGGER_ENTRY`(纯手动图无从挂监听)/ **`WORKFLOW_NOT_RUNNABLE`**(能力不健全,违例清单在 details.problems)。
注:此工具的 ValidateInput 走共享 helper,空 id 报 `fmt.Errorf("stage_workflow: workflowId is required")`(非 sentinel,与其余工具不一致——见 notes)。

---

## 10. activate_workflow(exec.go)

上线:持续监听 trigger、对每次真实 fire 反应。坏图拒绝激活(`WORKFLOW_NOT_RUNNABLE`,details.problems)。

**Parameters**:`workflowId` string(必填,唯一)。
**Execute 返回**:`{"workflowId":"wf_…","lifecycleState":"active","active":true}`。
**错误**:同 stage 的 `WORKFLOW_NO_TRIGGER_ENTRY` / `WORKFLOW_NOT_RUNNABLE`;`WORKFLOW_NOT_FOUND`。

---

## 11. deactivate_workflow(exec.go)

优雅下线:停止监听新触发,**在途 run 跑完**(lifecycle 可能经 draining)。要中止在途用 kill。

**Parameters**:`workflowId` string(必填,唯一)。
**Execute 返回**:`{"workflowId":"wf_…","lifecycleState":"inactive"|"draining","active":false}`。
**错误**:`WORKFLOW_NOT_FOUND`。

---

## 12. kill_workflow(exec.go)

紧急停止:停监听 + **立即取消所有在途 run**(可打断长步骤)。

**Parameters**:`workflowId` string(必填,唯一)。
**Execute 返回**:`{"workflowId":"wf_…","killed":N}`(N = 被杀 run 数)。
**危险倾向**:描述定位为 emergency stop;UI 应按破坏性动作呈现(与 deactivate 成对:优雅/强杀)。
**错误**:`WORKFLOW_NOT_FOUND`。

---

## 13. get_flowrun(runs.go)

按 flowrun id 读一次运行:run 头(status/error/pinned 版本)+ 每节点记录(status/result/error/iteration)。诊断失败/park 的 run。

**Parameters**:`flowrunId` string(必填,唯一)。
**Execute 返回**:`{"flowrun":{…FlowRun…},"nodes":[…FlowRunNode…],"nodeSummary"?:{…}}`。
- FlowRun:`{"id","workflowId","versionId","pinnedRefs":{entityId:versionId,…},"triggerId"?,"firingId"?,"status"(running|completed|failed|cancelled),"replayCount","error"?,"startedAt","completedAt"?,"updatedAt"}`。
- FlowRunNode:`{"id","flowrunId","nodeId"(图内局部 id),"iteration"(0起循环轮),"kind","ref","status"(completed|failed|parked),"result":{按 kind 形状},"error"?,"createdAt","completedAt"?,"updatedAt"}`。
- **节点封顶(F173)**:`maxFlowrunNodes = 80`。超过时 `nodes` 只含全部非 completed 节点(所有 failure+parked)+ 最近完成节点尾巴至 80,并附 `nodeSummary: {"totalNodes","shownNodes","byStatus":{status:count},"note":"…GET /api/v1/flowruns/{id} 取全量"}`。**最大体积被硬约束**——长循环 run 原本 ~2000 行/~650KB,现在有界。
**错误**:`FLOWRUN_ID_REQUIRED`;`FLOWRUN_NOT_FOUND`。

---

## 14. search_flowruns(runs.go)

列运行(最新在前),可按 workflow / status 过滤。**注意:parked 是节点状态、非 run 头状态**——本工具找不到待审批 run(用 list_approval_inbox)。

**Parameters**(全可选):
| 字段 | 类型 | 说明 |
|---|---|---|
| workflowId | string | 只看这个 workflow 的 run |
| status | string | running \| completed \| failed \| cancelled |
| limit | integer | 页大小,默认 50 |
| cursor | string | 不透明分页游标 |

**Execute 返回**:`{"runs":[…FlowRun 行(同上,无节点)…],"nextCursor":"…","hasMore":bool}`。
**错误**:`FLOWRUN_INVALID_STATUS`(非法 status 过滤)。

---

## 15. replay_flowrun(runs.go)

从断点重跑 **failed** run:只清 failed 节点,已完成节点保持记忆化(record-once,不重跑)。**用原 pin 的实体版本重跑**——事后修的代码不生效,要吃到修复须 trigger_workflow 起新 run。仅 failed 可 replay。

**Parameters**:`flowrunId` string(必填,唯一)。
**Execute 返回**:同 get_flowrun 的 `{"flowrun","nodes","nodeSummary"?}`——replay 同步执行(清节点→reopen→Advance),返回时 run 已到下一个终态/park。同受 80 节点封顶。
**错误**:`FLOWRUN_ID_REQUIRED`;**`FLOWRUN_NOT_REPLAYABLE`**(非 failed run)/ `FLOWRUN_NOT_FOUND`。

---

## 16. list_approval_inbox(inbox.go)

列全 workspace **park 在审批节点等人决策**的 run(最老在前)。发现待审批的**唯一**可靠途径(park run 的头仍是 running)。无参数。

**Parameters**:`{}`(零字段)。
**Execute 返回**:`{"parked":[{"flowrunId","nodeId","ref","rendered"?(渲染后的审批提示文本),"parkedAt"(RFC3339)}…],"count":N}`。刻意投影 slim 行、不吐整个 Result map(防大上游 payload 撑爆上下文)。
**错误**:基本无。
**UI 要点**:天然是"审批收件箱"列表;行 = decide_approval 所需的 (flowrunId, nodeId) + 提示文本。

---

## 17. decide_approval(runs.go)

批/拒 park 在审批节点上的 run(人在环决策)。**首决胜**——后续 decide 或超时 no-op。

**Parameters**(required: `flowrunId`, `nodeId`, `decision`):
| 字段 | 类型 | 必填 | 枚举 | 说明 |
|---|---|---|---|---|
| flowrunId | string | ✓ | | park 中的 run |
| nodeId | string | ✓ | | 图内 approval 节点 id |
| decision | string | ✓ | `yes` \| `no` | yes=批 / no=拒 |
| reason | string | | | 随决策记录 |

注:ValidateInput 只查 flowrunId;nodeId/decision 由 scheduler 校验(错节点→`FLOWRUN_APPROVAL_NOT_PARKED`,非 yes|no→`FLOWRUN_INVALID_DECISION`)。
**Execute 返回**:同 get_flowrun 的 `{"flowrun","nodes","nodeSummary"?}`——决策后 run 恢复(yes)或按分支停止(no),返回已推进后的快照。同受 80 节点封顶。
**错误**:`FLOWRUN_ID_REQUIRED`;`FLOWRUN_NOT_FOUND` / `FLOWRUN_APPROVAL_NOT_PARKED` / `FLOWRUN_INVALID_DECISION`。

---

## 横切事实(UI 通用)

- **返回格式**:全族 JSON(ToJSON 紧凑串),无 cat -n / exit footer 类原始文本模板。
- **补丁风格总结**:create/edit 都是 **ops 型**(7 动词有序流);update_node/update_edge 内层是顶层 merge-patch(input/retry 整体替换)。revert 是指针移动。无整体替换式 edit。
- **进度**:无 progress 块;create/edit 有 SSE-C args 镜像(entities 流),前端解析流式 ops 可做实时画布;flowrun 的实时推进走 entities 流的 flowrun tick(引擎侧,非本工具族发出)。
- **危险梯度**:delete_workflow(不可逆、报依赖)> kill_workflow(杀在途)> activate/stage(有 NOT_RUNNABLE 门,坏图不上线)> 其余读/温和写。danger 三级由 LLM 逐次自报(框架注入字段),工具本身无静态危险标记。
- **错误码全集**(本族可见):输入校验 `WORKFLOW_ID_REQUIRED` `FLOWRUN_ID_REQUIRED` `WORKFLOW_NAME_REQUIRED` `WORKFLOW_OPS_REQUIRED` `WORKFLOW_VERSION_POSITIVE`;domain `WORKFLOW_NOT_FOUND` `WORKFLOW_NAME_DUPLICATE` `WORKFLOW_VERSION_NOT_FOUND` `WORKFLOW_VERSION_CONFLICT` `WORKFLOW_NO_ACTIVE_VERSION` `WORKFLOW_INVALID_GRAPH` `WORKFLOW_INVALID_OPS` `WORKFLOW_REF_NOT_FOUND` `WORKFLOW_INVALID_LIFECYCLE` `WORKFLOW_NO_TRIGGER_ENTRY` `WORKFLOW_ALREADY_ACTIVE` `WORKFLOW_NOT_RUNNABLE`(details.problems);flowrun `FLOWRUN_NOT_FOUND` `FLOWRUN_NOT_REPLAYABLE` `FLOWRUN_APPROVAL_NOT_PARKED` `FLOWRUN_INVALID_ENTRY` `FLOWRUN_INVALID_DECISION` `FLOWRUN_INVALID_STATUS`。


---

# 工具普查 05 — control 系 + approval 系（+ 人在环 decide/inbox）

> 代码源:`backend/internal/app/tool/control/`(6 工具)、`backend/internal/app/tool/approval/`(6 工具)。
> **注意**:`decide_approval` 与 `list_approval_inbox` **不在 approval/ 目录**——物理住在 `backend/internal/app/tool/workflow/{runs.go,inbox.go}`(workflow 工具包),因为它们操作的是 flowrun 运行时(parked 节点),不是 approval 表实体。本文一并收录。
> **⚠️ 补正(2026-07-06 读码,全域适用)**:下列各卡「错误」列的 **wire code(如 `CONTROL_INVALID_CEL`)不出现在 tool_result 文本里**——tool_result Content 是 `errorspkg.Surface(err)` 的**纯文本 = Message + `(k=v; k=v)` details(键按字母序)**,code 只在 REST N1 错误信封。前端**不能从 tool_result 内容按 code 串匹配**;要判失败读 block `status=error` / `error` 字段(仍无 code),要拿 details 靠解析 Message 文本。故构建卡的错误呈现:底盘错误段渲纯文本即诚实,CEL 红框定位须解析 details 文本(增强、非必需)。另:control/approval 都是**整体替换**(create/edit 传完整 branches / 完整 form,edit 无 set_meta、approval 省略字段归零值);返回键是 **`activeVersionId`**(非 versionId)+ `version`(int),`ToJSON` map 序列化按字母序、勿依赖插入序。before diff 端点 `GET /{controls,approvals}/{id}/versions/{version}`(返 branches / template)存在——取数缝增强。
>
> 共性(两族全适用):
> - 全部 **lazy 工具**(Toolset.Lazy,经 search_tools 浮现,非常驻)。
> - **无 progress 流**:Tool 接口五方法无 progress writer,Execute 一次性返回。但 create/edit 实现 `BuildTool`(`Build() BuildSpec`),**loop 把流式 tool-call args delta 镜像到 entities SSE 流(SSE-C)**——前端实体面板随 LLM 打字实时填充。`BuildSpec`: control 系 `{Kind:"control", Op:"create"|"edit"}`,approval 系 `{Kind:"approval", Op:"create"|"edit"}`。**这是 UI 渲染"活构建"的唯一实时通道**。
> - **danger 无静态下限**:S18 纯信任,LLM 逐次自报 safe/cautious/dangerous,loop 据此设闸(dangerous 阻塞等用户确认)。工具代码不声明级别。
> - `inputs` 字段(create/edit 通用)= `[]schemapkg.Field`,每项 `{name:string, type:string, description?:string}`(json tag: description omitempty)。
> - 所有 Execute 返回值经 `toolapp.ToJSON` 紧凑 JSON 序列化;marshal 失败降级 `%v`。

---

## 一、control 系(`tool/control/`)

背景:control 逻辑实体(`ctl_` 前缀,版本 `ctlv_`)= 有序路由分支组,被 workflow control 节点引用,由 durable 解释器求值。**无 run/executions 工具**——绝不独立调用。

### 1. search_control
- **用途**:按关键词 + 语义相关度(name/description,内容引擎还覆盖正文)找 control 逻辑;空 query 列全部。
- **参数**:`query`(string,可选;空/省略 = 列全部)。无 PAYLOAD。
- **返回**(双路径):
  - 内容引擎路径(engine 非 nil 且 query 非空):`{"count":N, "total":M, "controls":[{id,name,description}], "nextCursor"?, "hasMore"?:true}`——description 位实为 FTS snippet;limit 20、含 archived;total>count = 截断披露。
  - 回退子串路径(引擎缺席/空 query/引擎错):`{"count":N, "controls":[{id,name,description}]}`(大小写不敏感子串过 name/description)。
- **体积**:slim 行,典型 <2KB;引擎路径封顶 20 行。
- **错误**:仅 bad args JSON(非 sentinel)。

### 2. get_control
- **用途**:取单个 control 逻辑 + active 版本(完整分支组)。
- **参数**:`controlId`(string,必填)。
- **返回**:整个 `ControlLogic` JSON:
  ```json
  {"id","name","description","activeVersionId","createdAt","updatedAt",
   "activeVersion":{"id","controlId","version","inputs":[{name,type,description?}],
     "branches":[{"port","when","emit"?}],"changeReason"?,"builtInConversationId"?,
     "createdAt","updatedAt"}}
  ```
  (workspaceId/deletedAt json:"-" 不出线;activeVersion omitempty——active 版本读失败时缺席)。
- **体积**:分支组紧凑,典型 <5KB。
- **错误**:`CONTROL_ID_REQUIRED`(ValidateInput);`CONTROL_NOT_FOUND`(Execute)。

### 3. create_control
- **用途**:创建 control 逻辑实体(有序路由分支组,写 v1 并设 active)。
- **参数**:
  | 字段 | 类型 | 必填 | 说明 |
  |---|---|---|---|
  | `name` | string | ✅ | workspace 内唯一 |
  | `description` | string | — | 一句话 |
  | `inputs` | array | — | `[{name,type,description}]`,when/emit 读 `input.*` |
  | `branches` | array | ✅(≥1) | **PAYLOAD**。每条 `{port:string 必填, when:string 必填(布尔 CEL over input.*), emit?:object(字段→CEL 串 map)}`;自上而下 first-true-wins;**末条必须 `when:"true"` 兜底** |
  | `changeReason` | string | — | 版本注记 |
- **补丁风格**:不适用(create);branches 是原子整体。
- **返回**:`{"id","name","activeVersionId","version":1}`。极小(<200B)。
- **危险倾向**:创建型,可逆(可删);LLM 通常自报 safe/cautious。
- **错误**(UI 值得呈现):
  - ValidateInput:`CONTROL_NAME_REQUIRED` / `CONTROL_BRANCHES_REQUIRED`。
  - Execute(app/domain 层):`CONTROL_INVALID_NAME`;`CONTROL_INVALID_BRANCHES`(空/port 空/port 重复);`CONTROL_NO_CATCHALL`(末条非 `when:"true"`);**`CONTROL_INVALID_CEL`——带 details `{branch,when|emit,reason}`,reason 是真 cel-go 编译错**(when/emit 只允许引用 `input` 命名空间,`payload.x`/`ctx.x` 在此即拒);`CONTROL_NAME_DUPLICATE`(UNIQUE 冲突)。

### 4. edit_control
- **用途**:用**全新完整分支组**写新版本(max+1)并立即激活;revert 可切回。
- **参数**:`controlId`(必填)、`inputs`(可选)、`branches`(必填,**PAYLOAD**,形状同 create)、`changeReason`(可选)。
- **补丁风格**:**整体替换(whole-set replace),非 ops、非字段 patch**——描述明言 "Pass the COMPLETE branch list (not a delta)"。前端 morph:直接以新 branches 全量渲染/diff 旧版本,无逐 op 语义。⚠️ **注意 name/description 不在 edit 参数里**——tool 层改不了元数据(REST 侧才有 UpdateMeta);且 edit 后旧版本经 `TrimOldestVersions` 按 `VersionCap` 裁最老版本。
- **返回**:`{"id","activeVersionId","version"}`(version = max+1)。
- **错误**:ValidateInput `CONTROL_ID_REQUIRED` / `CONTROL_BRANCHES_REQUIRED`;Execute 同 create 的分支/CEL 族 + `CONTROL_NOT_FOUND`,另有理论上的 `CONTROL_VERSION_CONFLICT`(并发编辑撞号)。

### 5. revert_control
- **用途**:把 active 指针切到既有版本号——纯指针操作,不产新版本、不删更新版本。
- **参数**:`controlId`(必填)、`version`(integer,必填,>0)。
- **返回**:`{"id","activeVersionId","version"}`(切到的版本)。
- **错误**:`CONTROL_ID_REQUIRED` / `CONTROL_VERSION_POSITIVE`(ValidateInput);`CONTROL_VERSION_NOT_FOUND`(Execute)。
- ⚠️ 描述里写 "use edit_control set_meta to also change those(name/description/tags)"——**edit_control 实际无 set_meta op 也无元数据参数**,描述与 schema 不符(见 notes)。

### 6. delete_control
- **用途**:删 control 逻辑及全部版本(软删 + purge relation 边)。**Not reversible**(对 LLM 而言);引用它的 workflow 会 capability check 失败。
- **参数**:`controlId`(必填)。
- **返回**:`{"id","deleted":true}`;若删前有存活依赖方,追加 `{"dependents":[{kind,id}...], "dependentCount":N, "note":"this entity was referenced by other entities...edit each to drop or repoint the now-dead reference"}`(删前经 `DependentRefs` 读入向 equip/link 边——边随 purge 消失,故先读)。
- **危险倾向**:**删除型,LLM 应自报 dangerous → loop 阻塞等用户确认**。UI 应突出 dependents 警示。
- **错误**:`CONTROL_ID_REQUIRED`;`CONTROL_NOT_FOUND`。

---

## 二、approval 系(`tool/approval/`)

背景:审批表实体(`apf_` 前缀,版本 `apfv_`)= markdown prompt 模板(`{{ input.* }}` CEL 插值)+ 决策规则(allowReason/timeout/timeoutBehavior),被 workflow approval 节点引用;运行时"等待中的审批"不是独立表、是 parked 的 flowrun_nodes 行。节点固定 yes/no 两出口;下游结果**只有** `{decision:"yes"|"no", reason}`,不透传 input。

### 7. search_approval
- 同 search_control 结构。**参数**:`query`(可选)。**返回**:引擎路径 `{"count","total","approvals":[{id,name,description}],"nextCursor"?,"hasMore"?}`;回退路径 `{"count","approvals":[...]}`。list key 是 `approvals`。

### 8. get_approval
- **参数**:`approvalId`(必填)。
- **返回**:整个 `ApprovalForm` JSON:
  ```json
  {"id","name","description","activeVersionId","createdAt","updatedAt",
   "activeVersion":{"id","approvalId","version","inputs":[...],
     "template","allowReason":bool,"timeout","timeoutBehavior",
     "changeReason"?,"builtInConversationId"?,"createdAt","updatedAt"}}
  ```
- **体积**:template 是 markdown,通常 <5KB。
- **错误**:`APPROVAL_ID_REQUIRED`;`APPROVAL_NOT_FOUND`。

### 9. create_approval
- **用途**:创建审批表(markdown 模板 + 决策规则,写 v1 激活)。
- **参数**:
  | 字段 | 类型 | 必填 | 说明 |
  |---|---|---|---|
  | `name` | string | ✅ | workspace 内唯一 |
  | `description` | string | — | |
  | `inputs` | array | — | `[{name,type,description}]`,template 读 `input.*` |
  | `template` | string | ✅ | **PAYLOAD**。markdown + `{{ input.* }}` CEL 插值,渲染给人看的决策说明("光秃按钮无意义"→强制必填) |
  | `allowReason` | boolean | — (默认 false) | 决策时允许可选自由文本备注 |
  | `timeout` | string | — | duration:标准 Go duration **外加 `d`(天)/`w`(周)后缀**,如 `30d`/`2h`;空 = 永不超时 |
  | `timeoutBehavior` | string | timeout 非空时✅ | 枚举 `reject`\|`approve`\|`fail` |
  | `changeReason` | string | — | |
- **返回**:`{"id","name","activeVersionId","version":1}`。
- **错误**(UI 值得呈现):
  - ValidateInput:`APPROVAL_NAME_REQUIRED` / `APPROVAL_TEMPLATE_REQUIRED`。
  - Execute:`APPROVAL_INVALID_NAME`;**`APPROVAL_INVALID_TEMPLATE`——带 details `{reason}` 真 cel-go 因**(`{{ }}` 段只允许 `input` 命名空间,`{{ payload.x }}` 即拒);**`APPROVAL_INVALID_TIMEOUT`**——覆盖四种物理违例:duration 不可解析 / 设 timeout 缺合法 behavior / **timeout 解析为 0(如 "0s",永不触发=坑,拒)** / 无 timeout 却带非法孤 behavior;`APPROVAL_NAME_DUPLICATE`。

### 10. edit_approval
- **用途**:用**完整新表**(template + 规则)写新版本并激活。
- **参数**:`approvalId`(必填)、`inputs`、`template`(必填,**PAYLOAD**)、`allowReason`、`timeout`、`timeoutBehavior`(枚举同上)、`changeReason`。
- **补丁风格**:**整体替换**——"Pass the COMPLETE form (template + rules), not a delta"。⚠️ 同 control:`allowReason`/`timeout` 等**省略即归零值**(false/""),不是"不变"——前端 morph 应把每次 edit 当全新快照渲染。name/description 不可经此工具改。旧版本按 `VersionCap` 裁。
- **返回**:`{"id","activeVersionId","version"}`。
- **错误**:`APPROVAL_ID_REQUIRED` / `APPROVAL_TEMPLATE_REQUIRED`(ValidateInput);Execute 同 create 族 + `APPROVAL_NOT_FOUND` / `APPROVAL_VERSION_CONFLICT`。

### 11. revert_approval
- 同 revert_control。**参数**:`approvalId`(必填)、`version`(integer >0)。**返回**:`{"id","activeVersionId","version"}`。
- **错误**:`APPROVAL_ID_REQUIRED` / `APPROVAL_VERSION_POSITIVE`;`APPROVAL_VERSION_NOT_FOUND`。
- ⚠️ 描述同样提到不存在的 "edit_approval set_meta"。

### 12. delete_approval
- 同 delete_control。**参数**:`approvalId`(必填)。**返回**:`{"id","deleted":true}` + 可选 dependents 注解(`dependents`/`dependentCount`/`note`)。
- **危险倾向**:删除型 → dangerous 自报预期。
- **错误**:`APPROVAL_ID_REQUIRED`;`APPROVAL_NOT_FOUND`。

---

## 三、人在环运行时(物理在 `tool/workflow/`,操作 flowrun 非表实体)

### 13. list_approval_inbox(`workflow/inbox.go`)
- **用途**:枚举 workspace 内**每个 park 在审批节点等人决策的 run**(oldest first)。是发现待审批的**唯一**忠实途径——search_flowruns 找不到(parked 是节点状态,run 头仍 "running")。对位 REST `GET /flowrun-inbox`。
- **参数**:**零参数**(`{"type":"object","properties":{}}`)。
- **返回**:`{"parked":[{"flowrunId","nodeId","ref","rendered"?,"parkedAt"(RFC3339)}], "count":N}`——刻意 slim 投影,`rendered` 是渲好的审批 prompt(取自节点 Result 的 rendered 键);**不吐整个 Result map**(防大上游 payload 撑爆上下文,F173 精神)。
- **体积**:每行主要是 rendered 文本;通常小。
- **progress/危险**:无;只读 → safe。
- **错误**:仅底层读错(无专属 sentinel)。

### 14. decide_approval(`workflow/runs.go`)
- **用途**:对 park 在审批节点上的 run 批(yes)/拒(no)——人在环决策本体。包 HTTP `:decide` 同一条 `scheduler.DecideApproval`;**首决胜**(后续 decide 或超时 no-op)。
- **参数**:
  | 字段 | 类型 | 必填 | 说明 |
  |---|---|---|---|
  | `flowrunId` | string | ✅ | park 中的 run |
  | `nodeId` | string | ✅(schema required;ValidateInput 不查,交 scheduler) | 图中审批节点 id |
  | `decision` | string | ✅ | 枚举 `yes`\|`no` |
  | `reason` | string | — | 随决策落盘的备注 |
- **返回**:决策生效(yes 续跑 / no 按节点分支停)后的 `{"flowrun":FlowRun, "nodes":[FlowRunNode...], "nodeSummary"?:{totalNodes,shownNodes,byStatus,note}}`——**节点封顶 80 行**(`capFlowrunNodes`:全部非 completed 节点 + 最近尾巴;超限附 summary 指向 REST `GET /api/v1/flowruns/{id}` 取全量)。未封顶前最坏 ~650KB(F173),现有界。
- **危险倾向**:**代表人类做审批决定**——语义上重;LLM 自报预期 cautious/dangerous。UI 若渲染此卡应突出 decision + reason。
- **错误**(UI 值得呈现):`FLOWRUN_ID_REQUIRED`(ValidateInput);`FLOWRUN_INVALID_DECISION`(decision 非 yes/no);`FLOWRUN_APPROVAL_NOT_PARKED`(节点缺/错/已决/已超时——"approval node is not awaiting a decision");flowrun not found 族。

---

## 附:UI 关键要点速览

| 维度 | control 系 | approval 系 |
|---|---|---|
| PAYLOAD 字段 | `branches`(结构化 CEL 分支数组) | `template`(markdown 长文本) |
| edit 风格 | 整体替换,无 ops | 整体替换,无 ops |
| 实时流 | SSE-C build 镜像(create/edit args delta → entities 流) | 同左 |
| 版本模型 | append-only + 自由 active 指针,revert=纯指针,edit 裁最老 | 同左 |
| 元数据 | tool 层**不可改** name/description | 同左 |
| 删除 | dependents {kind,id} 注解 + note | 同左 |
| 最富错误 | `CONTROL_INVALID_CEL` details{branch,when/emit,reason} | `APPROVAL_INVALID_TEMPLATE` details{reason} / `APPROVAL_INVALID_TIMEOUT` |


---

# 工具普查 06 — document / skill / attachment 系

> 源:`backend/internal/app/tool/{document,skill,attachment}/`。共 **15 个工具**:document 7 + skill 5 + attachment 3。
> 全体皆懒加载(Toolset.Lazy,经 search_tools / catalog 浮现)。`summary`/`danger`/`execution_group` 为框架注入,不在下列 args 内。
> **progress 流:Tool 接口无 progress emitter,任何工具执行中都不发 progress 块**。唯一"实时"信号是 **BuildTool(SSE-C)**:`create_document`/`edit_document`/`create_skill`/`edit_skill` 实现 `Build()`,loop 把**流式 tool-call args 的 delta 原样镜像到 entities SSE 流**(BuildSpec: Kind=document|skill, Op=create|edit),前端自己解析流式 args 让面板随打字填充——后端不解析、无粒度语义,就是 args 字节流。

---

## document 系(7 个,薄适配 documentapp.Service)

共性:
- domain 错误全部**软失败**——翻成英文提示串作为工具结果返回(err=nil),供 LLM 自纠;不冒泡 HTTP。只有 JSON 解析失败 / 未识别错误才真返回 error。
- ValidateInput sentinel:`DOCUMENT_ID_REQUIRED`(delete/move/read/edit 共用) / `DOCUMENT_NAME_REQUIRED`(create) / `DOCUMENT_QUERY_REQUIRED`(search)。
- domain 侧限制:content ≤ **1 MB**(`MaxContentBytes = 1<<20`);name 非空、≤256 字符、禁 `/`。
- `parentId` 处理惯例:空字符串一律视同 null(根级)。

### search_documents
- 用途:按关键词搜文档(内容引擎全文:名字+markdown 正文;引擎失败回退 legacy 名字/描述/标签子串搜)。
- args:`query` string 必填;`limit` int 可选,default 10,范围 0..50(越界 ValidateInput 报错)。无 PAYLOAD。
- 返回(JSON,两条路径**形状不同**):
  - 内容引擎路径:`{"count":N, "total":M, "documents":[{id,name,snippet}], "nextCursor"?, "hasMore"?}`(SlimPageResult;nextCursor/hasMore 仅截断时出现;hit 只有 id/name/snippet)。
  - legacy 回退路径:`{"count":N, "documents":[{id,name,path,description}]}`(**无 total**;hit 是 path/description、无 snippet)。
  - 两路共用 docHit struct(omitempty),UI 须兼容两种 hit 形状。
- 体积:典型 <2KB(≤50 条 slim hit)。
- 危险:只读。错误:limit 越界 / query 空;引擎错误静默回退不暴露。

### list_documents
- 用途:列 parentId 直系子级一层(树逐层走)。
- args:`parentId` string|null 可选(null/省略=根)。无 PAYLOAD。
- 返回:`{"count":N, "documents":[{id,name,path,position,description?}]}`——按 sibling 顺序,`position` 为 0 起兄弟序号(供 move_document 定位)。
- 体积:一层子级全量,无分页;典型 <5KB。
- 危险:只读。错误:仅 JSON 解析失败。

### read_document
- 用途:读单文档全文(markdown 正文 + 元数据)。
- 返回:**原始字符串模板**(非 JSON):
  ```
  # <name>

  Path: <path>
  ID: <id>
  Description: <desc>      ← 仅非空时
  Tags: a, b, c            ← 仅非空时

  ---

  <content 全文>
  ```
- args:`id` string 必填。
- 体积:最大 ~1MB(content 上限,不截断)。
- 危险:只读。错误:not found → 软失败串(附引导:去 search_documents / list_documents)。

### create_document 【BuildTool: document/create】
- 用途:在文档树建新文档(Notion-style 嵌套)。
- args:`name` string 必填(≤256、禁斜杠);`parentId` string|null;`description` string;**`content` string = PAYLOAD(markdown 全文)**;`tags` string[]。
- 返回(字符串模板):`Created document "<name>" (id=…, path=…).`;若重名被自动加后缀("X"→"X 2")则追加 `Note: requested name "X" was taken; auto-renamed.`——**create 撞名不报错、自动改名并告知**。
- 软失败:parent 不存在 / content 超 1MB(拒收不自动拆,`DOCUMENT_CONTENT_TOO_LARGE`)/ 名字非法。
- SSE-C:args(含 content)流式镜像 entities 流,document 面板实时填充。
- 危险:写入,可软删恢复。

### edit_document 【BuildTool: document/edit】
- 用途:改文档字段,只改提供的字段。
- **补丁风格:字段级 patch + 字段内整体替换**——`name`/`description`/`content`/`tags` 四个可选指针字段,给哪个改哪个;但 **`content` 与 `tags` 是全量替换,无 diff/ops/patch 语义**(schema description 原文 "Full replacement; no diff/patch semantics")。前端 morph 只能对新旧 content 自行 diff。
- args:`id` string 必填;`name`(改名会级联所有后代 path);`description`;**`content` = PAYLOAD(替换全文)**;`tags`。四者全缺 → 软失败串 "nothing to update…"。
- 返回:`Updated document "<name>" (id=…, path=…).`
- 软失败:not found / 兄弟重名(edit **不**自动加后缀,与 create 不对称)/ content 超 1MB / 名字非法。
- SSE-C:同 create。危险:覆盖旧文(有版本?工具层无暴露)。

### move_document
- 用途:重挂父级 / 调兄弟顺序。
- args:`id` string 必填;`parentId` string|null(null=移到根)——**schema 未标 required 但 Execute 用 raw map 检查键必须物理出现**,缺失 → 软失败串 "parentId required (pass null to move to root…)";`position` int ≥0 可选(兄弟序号 0=首,省略=追加末尾)。无 PAYLOAD。
- 返回:`Moved "<name>" to <parentId|root> (new path: <path>).`
- 软失败:doc 不存在 / 新 parent 不存在 / 环(移到自身或后代,`DOCUMENT_INVALID_PARENT`)。
- 危险:结构改动,可逆。

### delete_document
- 用途:**软删除**文档 + 全部后代(递归),用户可恢复 tombstone。
- args:`id` string 必填。
- 返回:`Deleted document <id> (no descendants).` 或 `Deleted document <id> along with N descendant(s).`
- 软失败:not found("already deleted?")。
- 危险倾向:递归删除但**软删可恢复**;无依赖计数注解(与 delete_skill 不同)。

---

## skill 系(5 个,薄适配 skillapp.Service;skill 无 DB、文件式 SKILL.md 目录,name(slug) 即身份、无 id 无版本)

共性:
- **与 document 系相反:错误不软失败**——service 错误用 `fmt.Errorf("xxx_skill: %w", err)` 包裹后作为 error 返回(loop 把 error 文本回给 LLM)。可见 sentinel:`SKILL_NOT_FOUND` / `SKILL_INVALID_NAME`(守卫 regex `^[a-z0-9][a-z0-9_-]{0,63}$`;新建另过规范形 `^[a-z0-9]+(-[a-z0-9]+)*$`——WRK-076 D3 双正则)/ `SKILL_INVALID_FRONTMATTER`(含 body 自带 frontmatter 拒收,details.reason 长解释)/ `SKILL_BODY_TOO_LARGE`(body ≤ **32KB**)/ `SKILL_NAME_CONFLICT` / `SKILL_FORK_REQUIRES_AGENT` / `SKILL_SUBAGENT_UNAVAILABLE`。description ≤1024 字符。
- ValidateInput sentinel:`SKILL_NAME_REQUIRED`(全 5 个共用)。

### activate_skill
- 用途:核心动作——加载 skill、替换 `$ARGUMENTS`/`$1..$n`/命名占位/`${CLAUDE_SESSION_ID}`、把其 allowed-tools 记为本运行预授权,然后 inline=返回渲染正文注入对话 / fork=派隔离 subagent 跑。
- args:`name` string 必填(slug);`arguments` string[] 可选(位置参数)。无 PAYLOAD。
- 返回:**原始字符串**——inline: 渲染后的 skill body(≤32KB);fork: subagent 的最终结果文本。
- 副作用(UI 相关):激活后该 skill 的 allowedTools 在本运行剩余部分**免危险确认**(预授权,非白名单)。
- 错误:not found;fork 无 agent → `SKILL_FORK_REQUIRES_AGENT`;runner 未接 → `SKILL_SUBAGENT_UNAVAILABLE`。
- 危险:取决于 skill 内容;工具本身只是注入指令。

### get_skill
- 用途:读一个 skill 全文(frontmatter+body)不激活,支撑先读后改。
- args:`name` string 必填。
- 返回(JSON,domain Skill struct 直接 ToJSON):`{"name","description","source"("user"|"ai"),"context"("inline"|"fork"),"body","frontmatter":{name,description,allowedTools?,context?,agent?,arguments?,disableModelInvocation?,userInvocable?,whenToUse?,model?,effort?,source?},"updatedAt"}`。
- 体积:≤ ~33KB(body 上限 32KB)。只读。

### create_skill 【BuildTool: skill/create】
- 用途:创作全新 skill(把刚做过的 workflow 固化成可复用能力);同名已存在 → `SKILL_NAME_CONFLICT` 报错。
- args(create/edit **共用同一 schema** saveSkillSchema):`name` string 必填(小写 slug);`description` string 必填(发现依据);**`body` string 必填 = PAYLOAD(markdown 指令,禁自带 YAML frontmatter 开头——平台从 args 组装 frontmatter,body 带 frontmatter 直接拒收)**;`allowedTools` string[];`context` enum `inline`|`fork`(默认 inline);`agent` string(fork 必填);`arguments` string[] (命名参数标签);`disableModelInvocation` bool(true=对模型隐藏、仅用户触发)。
- 返回(JSON):`{"created":"<name>"}`——极小。
- source 固定盖 `ai`(AI 作者标记)。SSE-C:args(含 body)流式镜像 entities 流。
- 危险:新建,可删。

### edit_skill 【BuildTool: skill/edit】
- 用途:改已有 skill。**补丁风格:整体替换**——覆盖整个 SKILL.md,args 同 create(name/description/body 全必填),必须先 get_skill 拿全文、改后整份传回;skill 不存在 → `SKILL_NOT_FOUND`。
- 返回(JSON):`{"updated":"<name>"}`。
- SSE-C:同 create。危险:无版本、覆盖即丢旧文。

### delete_skill
- 用途:**永久删除** skill(删目录,不可恢复——与 delete_document 的软删相反)。
- args:`name` string 必填。
- 返回(JSON):`{"deleted":"<name>"}`;若有存活实体仍 equip/link 它,追加三键:`"dependents":[{kind,id}…]`,`"dependentCount":N`,`"note":"this entity was referenced by other entities…edit each to drop or repoint the now-dead reference"`(删前经 DependentRefs 快照,relation id = skill name)。
- 危险倾向:**不可逆 + 可能破坏依赖它的 agent**——description 明说 "Cannot be undone",引导先用 get_relations 查依赖。UI 应把 dependents 键当高亮警示渲染。

---

## attachment 系(3 个,薄适配 attachmentapp.Service)

### list_attachments
- 用途:列本 workspace 上传的全部文件(新→旧),供发现后 read_attachment 拉回。
- args:**无**(空 object schema,ValidateInput 恒过)。
- 返回(JSON):`{"count":N, "attachments":[{id,filename,mime,kind,sizeBytes,createdAt}]}`——`kind` 枚举 `image|document|text|audio|video|other`;`createdAt` 格式 `2006-01-02T15:04:05Z`(UTC 秒级)。无分页、全量。
- 只读。

### read_attachment
- 用途:按 id 把已上传附件内容拉回对话。
- args:`id` string 必填(sentinel `ATTACHMENT_ID_REQUIRED` 仅空 id;未知 id 是软失败串);`offset` int 可选(字符偏移,≥0);`limitChars` int 可选(default 80000,max 120000)。
- 返回(原始字符串,按 kind 分叉):
  - `text`/`document`:走 ToContentParts 共享抽取引擎(NativeDocs 关,PDF/Office 抽成文本),多 part 以 `\n` 拼接后分页。模板首段仍是文本内联 `Attached file "<name>"(truncated)?:\n<body>` 或文档抽取 `Attached document "<name>" (text-extracted, truncated)?:\n<body>`；抽取失败降级占位 `[document "<name>" attached, but its text could not be extracted]`。超过页限时尾部追加 `[read_attachment pagination: offset=0 chars=80000 totalChars=N nextOffset=80000]`；显式 offset 越界返回自纠句。单次最大体积约 120K 字符。
  - `image`/`audio`/`video`/`other`:返回描述符长句 `Attachment "<filename>" (id …, <mime>, <N> bytes, kind <kind>): this tool cannot turn its content into text. An image is seen by the model ONLY if…`(教模型别重试、让用户描述或换 vision 模型)。
- 软失败:not found → `Attachment "<id>" not found. Call list_attachments to see available files.`
- 只读、无副作用。

### inspect_media
- 用途:按 `attachmentId` 对一个已上传 image 附件做一次内部视觉检查，给压缩后/摘要后 agent 精确复看图片细节；`read_attachment` 返回“图片不可文本抽取”后应改用它，而不是继续读 bytes。
- args:`attachmentId` string 必填(空值复用 `ATTACHMENT_ID_REQUIRED`);`question` string 必填;`crop` 可选 normalized rectangle `{x,y,width,height}`(0..1,宽高 >0);`detail` enum `default|high`；`page/startMs/endMs` 预留但 image 上会被忽略并写入 notes。
- 执行:下载原图 → 生成有界 `model-default` v2 代理/裁剪图(EXIF auto-orientation、透明/截图保 PNG、照片 JPEG、长图保可读宽度) → 解析默认 dialogue 视觉路由 → 受管 Anselm 网关优先上传代理并传短期 HTTPS URL，非受管路由用有界 data URL → 非流式聚合视觉回答。主对话只接收文本 JSON，不接收图片字节。
- 返回(JSON):`{"attachmentId","filename","mime","width","height","crop"?,"detail","transport":"managed-url|data-url","notes"?,"answer"}`。`answer` 是模型观察到的文本证据；输出 token 上限 900。
- 软失败:image 以外 kind → 说明当前只支持 image，并引导 text/doc 用 `read_attachment`；未知 id → 同 `read_attachment` 的 not found 文案；默认模型 route 无 vision → 明确说明当前默认 route 不能看图。
- progress:无。只读，但会对受管网关产生短期媒体 lease 上传；无实体写入、无持久 perception 记录。

---

## 汇总表

| 工具 | PAYLOAD 字段 | 补丁风格 | 返回格式 | Build(SSE-C) | 删除语义 |
|---|---|---|---|---|---|
| search_documents | — | — | JSON(双形状) | — | — |
| list_documents | — | — | JSON | — | — |
| read_document | — | — | 字符串模板(≤1MB) | — | — |
| create_document | content | — | 字符串句 | ✅ document/create | — |
| edit_document | content | 字段 patch;content/tags **全量替换** | 字符串句 | ✅ document/edit | — |
| move_document | — | — | 字符串句 | — | — |
| delete_document | — | — | 字符串句 | — | 软删递归可恢复 |
| activate_skill | — | — | 字符串(渲染 body / fork 结果) | — | — |
| get_skill | — | — | JSON(Skill 全量) | — | — |
| create_skill | body | — | JSON `{created}` | ✅ skill/create | — |
| edit_skill | body | **整份 SKILL.md 替换** | JSON `{updated}` | ✅ skill/edit | — |
| delete_skill | — | — | JSON `{deleted,+dependents?}` | — | **硬删不可逆** |
| list_attachments | — | — | JSON | — | — |
| read_attachment | — | — | 字符串(≤120K/页) | — | — |
| inspect_media | — | — | JSON 文本证据 | — | — |


---

# Trigger 系工具普查（`backend/internal/app/tool/trigger/`）

代码事实源：`trigger.go`（装配）· `build.go`（create/edit/delete）· `manage.go`（fire）· `query.go`（search/get）· `activations.go`（activations/firings 日志）· `sentinels.go`。
共 **9 个工具**，全部懒加载（Toolset.Lazy，经 search_tools 浮现）。**没有任何一个工具发 progress 块**——Tool 接口就是 `Execute(ctx, argsJSON) (string, error)`，包内零 progress emitter，全部一次性同步返回。summary/danger/execution_group 为框架注入，下文一律不计入 args。

Trigger 实体线缆全形（create/edit/get 返回同一形状，`triggerdomain.Trigger` struct tag）：

```json
{
  "id": "trg_<16hex>", "name": "...", "description": "...",
  "kind": "cron|webhook|fsnotify|sensor",
  "config": { ... },                      // 自由 map，按 kind 定形
  "outputs": [{"name","type","description?"}],  // schemapkg.Field
  "createdAt": "...", "updatedAt": "...",
  "refCount": 0, "listening": false,       // 运行时内存派生（多少 active workflow 在听 / listener 热否）
  "lastFiredAt": "...",                    // omitempty；最近一次 FIRED activation 时间
  "nextFireAt": "..."                      // omitempty；仅 cron，读时从表达式算
}
```

体积：单 trigger 通常 <2KB（config 是小 map，outputs 数个字段）。

---

## 1. search_triggers

- **用途**：按 keyword+语义搜 trigger（name/description/kind），空 query 列全部。
- **Params**：`query` string，可选（省略=列全部）。无分页参数。
- **返回（两条路径、形状不同——UI 注意）**：
  - **内容引擎路径**（engine 已接 + query 非空）：`{"count": n, "total": N, "triggers": [{"id","name","description"}], "nextCursor"?, "hasMore"?}`——description 是 FTS **snippet**，且**没有 kind/refCount/listening**；引擎页上限 20。
  - **回退子串路径**（engine 缺席 / query 空 / 引擎出错）：`{"count": n, "triggers": [{"id","name","description","kind","refCount","listening"}]}`——无 total/nextCursor，不分页（内存过滤全量）。
- **危险**：只读。
- **错误**：仅 bad args JSON。

## 2. get_trigger

- **用途**：取单个 trigger 全形（kind + config + 运行时状态）。
- **Params**：`triggerId` string **必填**。
- **返回**：上面的 Trigger 全形 JSON；Get 额外附 `lastFiredAt`，cron 附 `nextFireAt`（都 omitempty）。
- **危险**：只读。
- **错误**：`TRIGGER_ID_REQUIRED`（ValidateInput）· `TRIGGER_NOT_FOUND`。

## 3. create_trigger

- **用途**：新建信号源（cron/webhook/fsnotify/sensor）。注意：创建**不**启动 listener——只有 active workflow 引用它才开始听。
- **Params**：
  | 字段 | 类型 | 必填 | 说明 |
  |---|---|---|---|
  | `name` | string | ✅ | 唯一显示名 |
  | `description` | string | — | |
  | `kind` | string | ✅ | enum `cron\|webhook\|fsnotify\|sensor`，**不可变** |
  | `config` | object | ✅（结构校验按 kind） | **PAYLOAD**——source 专属配置，见下 |
  | `outputs` | array of `{name,type,description}` | — | **只对 sensor 有效**；cron/webhook/fsnotify 被 `CanonicalOutputs` 强制盖章、作者所填被忽略 |
- **config 按 kind 的物理字段**（`domain/trigger/config.go` ValidateConfig）：
  - `cron`：`expression`（5 段 cron，必填；`@every`/秒级不支持）。
  - `webhook`：`path`（挂载**子**路径，必填；实际 URL = `POST /api/v1/webhooks/{triggerId}/{path}`）；可选 `secret`（无 `signatureAlgo` = 明文头 `X-Webhook-Secret` 或 `?token=`）+ `signatureAlgo`（仅 `"hmac-sha256-hex"`，头 `X-Hub-Signature-256`）+ `signatureHeader`（改头名）。内建幂等：同 body + 同一分钟桶去重。
  - `fsnotify`：`path`（绝对路径，必填）；可选 `events`（`[create|modify|delete|rename|chmod]`）、`pattern`（glob）。
  - `sensor`：`targetKind`（enum `function|handler|mcp`）、`targetId`（须真实存在，创建时 eager 校验）、`method`（handler/mcp 必填）、`intervalSec`（≥5，`MinSensorIntervalSec`）、`condition`（CEL bool，命名空间只有 `payload`）、`output`（CEL 造 fire payload）。**电平触发**：条件持续成立则每个 interval 都 fire。
- **返回**：新 Trigger 全形 JSON（此路径**不**附运行时字段，`refCount:0, listening:false` 恒定；无 lastFiredAt/nextFireAt——Create 不走 attachRuntime）。
- **危险**：写入但无副作用（不启动 listener）。
- **错误**：`TRIGGER_NAME_REQUIRED` · `TRIGGER_INVALID_KIND` · `TRIGGER_INVALID_CONFIG` · `TRIGGER_INVALID_CRON` · `TRIGGER_INVALID_CEL`（details 带 `{field: "condition"|"output", cel, reason}`，reason 是真 cel-go 编译错——UI 可直接展示定位）· `TRIGGER_INVALID_INTERVAL` · `TRIGGER_SENSOR_TARGET_REQUIRED` · `TRIGGER_SENSOR_TARGET_NOT_FOUND`（details `{targetKind, targetId, reason}`）· `TRIGGER_NAME_DUPLICATE`。

## 4. edit_trigger

- **用途**：改 name/description/config/outputs（**kind 不可变**——换 kind = 删了重建）。trigger 若正热（listener live），新 config 立即生效（重注册 listener）。
- **Params**：`triggerId` string **必填**；`name` / `description` string 可选；`config` object 可选（**PAYLOAD**）；`outputs` array 可选（仅 sensor 有效，同 create）。
- **补丁风格（前端 morph 关键）**：**字段级 patch + config 整体替换的混合体**。
  - `name` / `description`：指针语义——缺席不改，出现即覆盖（无法"清空后区分"，传 `""` 即清空）。
  - `config`：**非 ops、非 merge——传了就是整体替换**（`if in.Config != nil { t.Config = in.Config }`），schema 描述原话 "Full replacement config"。想改一个键也必须传完整 config。
  - `outputs`：nil 不改，非 nil 整体替换（非 sensor kind 随后仍被 canonical 盖章）。
  - 没有任何 op 动词数组。UI diff 应做 **config 前后整块对比**。
- **返回**：编辑后 Trigger 全形 JSON（Edit **走** attachRuntime，含 refCount/listening/nextFireAt；不含 lastFiredAt——Edit 不查它）。
- **危险**：中——对 live trigger 的 config 改动**立即生效**。
- **错误**：同 create 的全套 config/CEL/interval/target 校验 + `TRIGGER_ID_REQUIRED` + `TRIGGER_NOT_FOUND` + `TRIGGER_NAME_DUPLICATE`。

## 5. delete_trigger

- **用途**：软删 trigger——停掉热 listener、清关系边；监听它的 workflow 从此收不到信号。
- **Params**：`triggerId` string **必填**。
- **返回**：`{"deleted": true, "triggerId": "..."}`；若删时仍有存活实体引用它，追加 `"dependents": [{"kind","id"}...]` + `"dependentCount": n` + `"note"`（固定修复提示句，见 `dependents.go` dependentsNote）。依赖读取在删**前**做（删后边已 purge、无从追）、且 advisory-only（读失败不阻删）。
- **危险**：**高**（破坏性）。工具自身无确认门——确认靠 LLM 自报 danger + 逐次内存阻塞确认（S18）。描述明确建议删前用 get_relations 查依赖。
- **错误**：`TRIGGER_ID_REQUIRED` · `TRIGGER_NOT_FOUND`。

## 6. fire_trigger

- **用途**：立刻手动 fire 一次，走**真实** firing 收件箱路径（listening workflow 的 overlap 策略 serial/skip/buffer_one/replace **生效**），主要用于测试扇出管道。无人监听也会记一条 0 扇出的 Activation。
- **Params**：`triggerId` string **必填**。**没有 payload 字段**——合成 payload 恒为 `{"manual": true}`（描述专门警告：带数据的测试跑请用 trigger_workflow，它绕过策略直接开跑；有回归测试锁死这段话，见 manage_test.go）。
- **返回**：`{"fired": true, "triggerId": "...", "activationId": "act_..."}`。
- **副作用（UI 可感知）**：每次扇出经 entities SSE 流发一条 trigger scope 的 **fire 信号**（ephemeral，content = `{activationId, kind, fired, firingCount, error}`）——trigger 面板可据此实时闪动；耐久真相是 Activation/Firing 行。manual fire 的 dedupKey 含纳秒时间戳、**永不去重**。
- **危险**：中——会真的启动监听 workflow 的运行。
- **错误**：`TRIGGER_ID_REQUIRED` · `TRIGGER_NOT_FOUND`。

## 7. search_activations

- **用途**：查 trigger 的**动作日志**——每次它"行动"（fire 与否都记）一条，回答"为什么没 fire"（sensor 探测了但条件为假 / invoke 失败，都留 returnValue + detail）。
- **Params**：`triggerId` string **必填**；`firedOnly` boolean 可选（只看真 fire 的）；`cursor` string / `limit` integer 可选（limit ≤0 → 50，orm Page 默认；最新优先）。
- **返回**：`{"count": n, "activations": [Activation...], "nextCursor": "..."}`。Activation 线缆形：
  ```json
  {"id","triggerId","kind","fired":bool,
   "returnValue":{...},   // omitempty；sensor 探测返回值（未 fire 也留）
   "payload":{...},       // omitempty；fire 出去的 payload（未 fire 为空）
   "error":"...",         // omitempty；invoke/probe 错误
   "detail":"...",        // omitempty；人话注记，如 "condition evaluated false"
   "firingCount":n, "createdAt":"..."}
  ```
- **体积注意**：`returnValue` 是 sensor 目标函数的完整返回值——一页 50 条可能相当大，UI 应折叠/截断展示。
- **危险**：只读。
- **错误**：`TRIGGER_ID_REQUIRED`。

## 8. get_activation

- **用途**：按 id 取单条 activation（fire 与否、观测到的返回值、fired payload、error/detail、扇出数）。
- **Params**：`activationId` string **必填**。
- **返回**：单个 Activation JSON（形同上）。
- **危险**：只读。
- **错误**：`TRIGGER_ACTIVATION_ID_REQUIRED` · `TRIGGER_ACTIVATION_NOT_FOUND`。

## 9. search_firings

- **用途**：查 trigger 的 **firing 收件箱**——每次 fire 对每个扇出目标 workflow 一行，带"跑没跑"处置。回答 search_activations 答不了的"fire 了但 workflow 没跑，为什么"。
- **Params**：`triggerId` string **必填**；`status` string 可选（enum `pending|started|skipped|superseded|shed`：pending=等 scheduler / started=已建 flowrun / skipped=overlap 策略跳过 / superseded=buffer_one 下被更新 firing 顶替 / shed=资源上限丢弃）；`cursor` / `limit`（limit ≤0 → 50；最新优先）。
- **返回**：`{"count": n, "firings": [Firing...], "nextCursor": "..."}`。Firing 线缆形：
  ```json
  {"id","triggerId","workflowId","activationId",
   "payload":{...},       // omitempty
   "dedupKey","status",
   "flowrunId":"...",     // omitempty；started 时指向创建的 flowrun
   "createdAt","updatedAt"}
  ```
- **危险**：只读。
- **错误**：`TRIGGER_ID_REQUIRED`。

---

## UI 呈现要点汇总

1. **edit_trigger 的 config 是整体替换**——morph 做前后整块 config diff，别按键做增量。
2. **search_triggers 两条返回形状不一致**：FTS 路径丢 kind/refCount/listening 且 description 变 snippet；渲染要容忍字段缺席。
3. **create 与 edit/get 返回的运行时字段有别**：create 恒 `refCount:0, listening:false` 且无 lastFiredAt/nextFireAt；get 最全。
4. **fire_trigger 无 payload 参数**是刻意设计（测过 agent 误传 body 被静默丢），返回三键极小。
5. `TRIGGER_INVALID_CEL` / `TRIGGER_SENSOR_TARGET_NOT_FOUND` 带结构化 details（field/cel/reason），值得在错误卡里展开而非只显示 message。
6. activations 的 `returnValue` 可能很大，需要折叠。
7. fire 的实时性走 entities SSE `fire` 信号（ephemeral）；日志真相在 activations/firings 两张表，两个 search 工具即其投影。


---

# 08 — MCP 族 + Web 族 工具普查

> 源:`backend/internal/app/tool/mcp/{mcp,system,calls,dynamic,sentinels}.go` + `backend/internal/app/tool/web/{web,fetch,search,search_byok}.go`。
> 服务层佐证:`app/mcp/{install,calltool,mcp}.go`、`domain/mcp/{mcp,call_log}.go`、`infra/mcp/{client,progress}.go`。
> 共同点:本批**没有 edit/patch 类工具**——无 ops/字段 patch/整体替换问题,morph 维度全员 N/A。
> `summary`/`danger`/`execution_group` 为框架注入,以下 Parameters 均不含。
> `toolapp.ToJSON` = `json.Marshal` 紧凑单行(非缩进);唯 WebSearch 例外用 `MarshalIndent` 两空格。

---

## MCP 管理工具(6 个固定 resident,`MCPTools()`)

### 1. list_mcp_marketplace

逛 GitHub MCP Registry 市场,返回可安装 server 目录(名/描述/runtime/env 需求)。

**Parameters**(无必填):
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `query` | string | 否 | 能力过滤词。按空白切词、OR 匹配 name+description、**按命中词数降序排**(全词命中居顶,部分命中仍出现);空/缺省 = 全目录 registry 序 |

无 PAYLOAD 字段。

**Execute 返回**(JSON):
```json
{"servers":[{"name","description","runtime","env":[{"name","description?","required"}]}],"count":N}
```
- `runtime` ∈ `node|python|docker|dotnet|remote`(remote 覆盖 runtime 位)。
- `env[].required` 是布尔——**必填/可选区分被刻意保留**(F169 修复,UI 不可把 optional 呈现成必填)。
- 体积:无过滤全目录 ~96 个 server(曾撑爆上下文,故 Description 强烈引导带 query);带 query 通常个位数~十几条。

**progress**:无。
**危险性**:只读,无。
**错误**:`ValidateInput` 恒 nil;args 解析失败静默当无过滤。上游 registry 失败 → Go err 包 `list_mcp_marketplace: …`。

---

### 2. install_mcp_server

按 registry 全名装 server(物化 runtime + 加密落盘 + 连接),装完其工具经 search_tools 可用。**产品设计只连市场 server,不支持自托管/自定义 stdio·URL**(Description 明说)。

**Parameters**:
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `name` | string | 是 | registry 全名,如 `io.github.upstash/context7` |
| `env` | object(string→string) | 否 | 环境变量(API key 等)name→value |

无 PAYLOAD(env 是小键值对)。

**Execute 返回**:`ToJSON(*ServerStatus)`:
```json
{"id":"mcp_…","name","status","connectedAt?","lastError?","lastErrorAt?",
 "consecutiveFailures","totalCalls","totalFailures",
 "tools":[{"serverName","name","description","inputSchema"}]}
```
- `status` ∈ `disconnected|connecting|ready|degraded|failed`(进程内运行态,不落盘)。
- `tools[].inputSchema` 是 server 原生 JSON Schema **原样透传**——体积可观(几十工具 × schema,几十 KB 级)。
- **连接失败仍落盘 server**(可 reconnect 恢复),此时返回的 status 可能是 `failed` + `lastError`。

**progress:有,很有戏**——`ensureEnv` 把 sandbox 物化各阶段(npx/uvx/docker pull)实时流进本 tool_call 的 `progress` 块,行格式:
```
[<stage>] <message> (<percent>%)\n   // percent>0 时
[<stage>] <message>\n               // 无百分比时
```
安装超时 3 分钟(`addServerTimeout`)。OAuth 型 remote server 会在 Execute 内**阻塞走完浏览器授权流**(发现→注册→用户同意→token)。

**危险性**:装外部代码/子进程,属重操作;但工具自身零 danger 逻辑(S18 LLM 自报)。
**错误**(sentinel,UI 可辨):
- `MCP_NAME_REQUIRED`(ValidateInput,name 空)
- `MCP_ENV_MISSING`(422)——**Details 带 `{"missing":[变量名…]}`**,UI 应展示缺哪些键
- `MCP_REGISTRY_NOT_FOUND` / `MCP_NO_RUNNABLE_PACKAGE`(422) / `MCP_NAME_CONFLICT`(409,同名已装) / `MCP_INSTALL_FAILED`(502)
- OAuth 族:`MCP_OAUTH_DISCOVERY_FAILED`/`MCP_OAUTH_REGISTRATION_FAILED`/`MCP_OAUTH_TOKEN_FAILED`/`MCP_OAUTH_AUTHORIZE_FAILED`(502)

---

### 3. uninstall_mcp_server

按已装名卸载:停进程 + 删配置,其工具即不可用。

**Parameters**:
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `name` | string | 是 | 已装 server 短名(如 `context7`) |

**Execute 返回**:**纯文本模板**(非 JSON):
```
Uninstalled MCP server "<name>".
```
**progress**:无。
**危险性**:破坏性(删配置含加密凭据),无内建确认——靠 LLM danger 自报。
**错误**:`MCP_NAME_REQUIRED`(注意:此工具 ValidateInput 走 `requireName`,实际返 `fmt.Errorf("tool/mcp: name is required")` 非 sentinel);`MCP_SERVER_NOT_FOUND`(404)。

---

### 4. reconnect_mcp

重启一个 server 的连接——"重置按钮",救 connected-但-卡死/会话失效 的 server(对标 restart_handler)。

**Parameters**:
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `name` | string | 是 | 已装 server 名 |

**Execute 返回**:`ToJSON(*ServerStatus)`(同 install,含刷新后的 tools 列表)。
**progress**:无(Reconnect 不走 ensureEnv 的 tool progress)。
**危险性**:低(重启连接)。
**错误**:同上 name 必填;`MCP_SERVER_NOT_FOUND`。

---

### 5. search_mcp_calls

列一个 server 的工具调用历史(最新在前)+ ok/failed 汇总。所有可执行体(fn/hd/ag)的"运行历史面"在 MCP 上的对应物。

**Parameters**:
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `serverId` | string | 是 | `mcp_` id |
| `tool` | string | 否 | 工具名过滤 |
| `status` | string | 否 | 枚举 `ok|failed|cancelled|timeout`(集外值报 `MCP_CALL_INVALID_STATUS` 422、Details 带合法集) |
| `limit` | integer | 否 | 页大小,默认 50 |
| `cursor` | string | 否 | 不透明分页游标 |

(domain CallFilter 还有 triggeredBy/conversationId/flowrunId 轴,但**工具面未暴露**——仅 HTTP 面用。)

**Execute 返回**(JSON):
```json
{"calls":[Call…],"nextCursor?","hasMore":bool,"aggregates":{"okCount","failedCount"}}
```
Call 行完整键见 get_mcp_call。列表页含每条的 input/output/logs 全量(未瘦身),一页 50 条可能很大。

**progress**:无。危险:只读。
**错误**:`MCP_SERVER_ID_REQUIRED`(sentinel)/`MCP_CALL_INVALID_STATUS`。

---

### 6. get_mcp_call

按 id 取一条调用记录(input/output/error/logs/时序),供 triage。

**Parameters**:
| 字段 | 类型 | 必填 |
|---|---|---|
| `callId` | string | 是(`mcl_` id) |

**Execute 返回**:`ToJSON(*Call)`:
```json
{"id":"mcl_…","serverId","tool","status","triggeredBy",
 "input?":{…原 args…},"output?":"…","errorMessage?","logs?",
 "elapsedMs","startedAt","endedAt",
 "conversationId?","messageId?","toolCallId?",
 "flowrunId?","flowrunNodeId?","flowrunIteration?","createdAt"}
```
- `status` ∈ `ok|failed|cancelled|timeout`;`triggeredBy` ∈ `chat|agent|workflow|manual`。
- `logs` = 该次调用的 progress 通知留痕,**cap 64KB**(logtail 半头半尾);失败调用**追加 server stderr 尾 ≤8KB**,带分隔行 `--- server stderr tail (server-level, may predate this call) ---`。
- `output` 无截断(server 返多少存多少)——单条记录可能很大。

**progress**:无。危险:只读。
**错误**:`MCP_CALL_ID_REQUIRED` / `MCP_CALL_NOT_FOUND`(404)。

---

## 7. mcp__<server>__<tool>(动态包装,每 server 每工具一个)

把已连接 server(status ∈ ready|degraded)的每个工具包成独立 lazy 工具,进 search_tools 检索池(**不进 resident/Overview**)。

- **name**:`mcp__<serverName>__<toolName>`(双下划线;LLM 工具名禁冒号故如此)。
- **Description**:server 通告的原文。
- **Parameters**:server 的 `inputSchema` **原样透传**——前端无法预知字段,渲染必须走通用 JSON 展示;无固定 PAYLOAD 字段。
- **ValidateInput**:恒 nil(校验交给上游 MCP server 自己)。
- **Execute 返回**:`joinContent(res.Content)` 拼出的**原始字符串**:
  - TextContent → 原文拼接;ImageContent → `[image: <mime>]`;AudioContent → `[audio: <mime>]`;ResourceLink/EmbeddedResource → `[resource: <uri>]`;未知型 → `[<Go类型>]`。
  - 本层无体积截断(仅上游 server 决定);典型是一段 JSON 或 markdown 文本。
- **progress:有**——server 若发 MCP progress notification,经 per-call token 路由实时流进本 tool_call 的 `progress` 块,行格式(`formatProgress`):
  ```
  <message> (<progress>/<total>)\n   // total>0
  <message>\n                        // 否则;message 空时置 "working…"
  ```
  同一份进度还 tee 到 ①entities 流该 server scope 的 run 终端节点(实体面板)②mcp_calls 行的 logs(64KB cap)。不发进度的 server 什么帧都不开(懒节点)。
- **超时**:每次调用 180s(`limits.Timeout.MCPCallSec`,可配)。超时→status `timeout`,ctx 取消→`cancelled`。
- **审计**:每次调用落一行 `mcp_calls`(best-effort、detached ctx,被取消也落账);**TouchEntity 自报 `(kind=mcp, id=mcp_…, name=serverName)`** 进对话触点台账(右岛)。
- **危险性**:完全取决于上游工具;适配器零 danger 逻辑,靠 LLM 逐次自报。
- **错误**(Go err,UI 可辨 code):
  - `MCP_SERVER_NOT_FOUND`(server 没了)
  - `MCP_SERVER_DOWN`(503,未连接/不可调,消息带 `status=…`)
  - `MCP_RPC_ERROR`(502,含 server 返回 `isError:true` 的情形——**Details.reason 带工具自己的报错文本**,通常点名坏字段)
  - `MCP_TOOL_TIMEOUT`(504)
  - 3 连败 server 翻 `degraded`(仍可调,软警告);一次成功回 `ready`。

---

## Web 族(2 个,`WebTools()`)

### 8. WebFetch

抓 URL(SSRF 守卫)→ utility 模型按 prompt 摘要。**不返原始 HTML**——超大页面不会灌爆上下文。抓取方式随 workspace `webFetchMode`:`local`(仅本机直 GET,URL 不出机)/ `jina`(Jina reader 优先、直 GET 兜底;`JINA_API_KEY` env 提速率档)。

**Parameters**:
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `url` | string | 是 | 绝对 http/https URL |
| `prompt` | string | 是 | 要从页面提取/摘要什么 |

无 PAYLOAD。

**Execute 返回:纯字符串,且几乎所有失败也走"成功返回 + 友好文案"而非 Go err**(UI 上工具卡看起来 completed,内容却是错误说明——呈现时要按内容判别)。分支模板:
- 成功:模型摘要文本(逐 token 流出,最终值即全文;典型几百字~几 KB)。
- `Invalid URL "<url>": <err>`
- SSRF 拒绝:`Refusing to fetch loopback/private/link-local/unspecified/multicast address: …` / `Refusing to fetch loopback host: …` / `Cannot resolve host <h>: …` / `URL has no host.`
- `Failed to fetch <url>: <err>`(超时 30s、非 2xx `http status NNN`、重定向 >10 跳、重定向进禁区 `redirect blocked: …`)
- `Fetched <url> but body was empty.`
- **JS 外壳守卫**(可读文本 <200 字符,仅 local 模式):`Fetched <url>, but the page has almost no readable text (N chars) — it is likely a JavaScript app …switch the workspace web-fetch mode to Jina.`(防弱模型编造页面内容,Phase 4 HIGH 教训)
- 摘要降级:`Summarisation unavailable (<err>). Raw content (first 4 KB):\n\n<原文≤4096B+"...[truncated]">`

抓取体积 cap:1MB(`maxFetchBytes`);重定向每跳重跑 SSRF 守卫;DNS 全答案检查防 rebinding。

**progress:有**——摘要阶段把 utility 模型的每个 text delta 实时 tee 进 `progress` 块,**用户逐字看摘要被写出来**(最终 tool result = 同一份全文)。抓取阶段无进度帧。

**危险性**:出网只读;SSRF 守卫内建。零确认逻辑。
**ValidateInput sentinel**:`WEB_EMPTY_URL` / `WEB_EMPTY_PROMPT` / `WEB_UNSUPPORTED_SCHEME`(仅 http/https)。

---

### 9. WebSearch

用 workspace 唯一配置的搜索 key(BYOK:brave/serper/tavily/bocha,provider 由 key 隐含)跑查询。**无 provider 遍历、无 MCP 代理**(搜索型 MCP server 自己经 tool/mcp 暴露工具)。

**Parameters**:
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `query` | string | 是 | 查询串 |
| `limit` | number | 否 | 默认 10,硬上限 30(0→10,>30→30) |

无 PAYLOAD。

**Execute 返回**:成功时是**两空格缩进的 pretty JSON**(全普查唯一缩进输出):
```json
{
  "query": "...",
  "source": "brave|serper|tavily|bocha",
  "results": [{"title","url","snippet"}],
  "truncated": bool
}
```
体积:≤30 条 × (title+url+snippet),典型几 KB;provider 响应体读取 cap 256KB。

**失败同样"成功返回 + 文案"**(非 Go err):
- 未配 key / key 被删:`No search backend configured for "<query>".` + 三段引导(配 search key / 装搜索 MCP / 明说 WebFetch 只可抓用户给的具体 URL、**禁止编造候选 URL 冒充搜索**)。
- key 指错类目:`The configured default search key is provider "x", which is not a search backend …`
- 缺 baseURL:`Search provider "x" has no base URL configured.`
- provider 失败:`Search via <provider> failed: <err>`(err 链含 sentinel 与上游片段 ≤200B)。

**progress**:无(单发 HTTP,10s 超时)。
**危险性**:出网只读。
**副作用**:上游 401/403 → **按 id 把该 key 标记 invalid**(apikey 域,UI 的 key 状态徽标会翻转;detached ctx best-effort)。
**sentinel**:`WEBSEARCH_EMPTY_QUERY` / `WEBSEARCH_NEGATIVE_LIMIT`(ValidateInput);`WEBSEARCH_AUTH_FAILED`(502)/`WEBSEARCH_RATE_LIMITED`(429)/`WEBSEARCH_UPSTREAM_HTTP`(502)(Execute 内包进文案返回)。

---

## UI 呈现要点速记

1. **补丁风格**:本批全员非 edit 类,无 morph 需求。
2. **progress 三处有戏**:install_mcp_server(`[stage] msg (pct%)` 安装阶段行)、mcp 动态工具(server 进度通知行)、WebFetch(摘要逐 token 打字机)。其余工具无 progress。
3. **"假成功真失败"**:WebFetch/WebSearch 把绝大多数失败包装成正常字符串结果——工具卡状态是 completed,靠文案开头(`Failed to fetch`/`Refusing to`/`No search backend`/`Search via … failed`)才能识别;MCP 族则相反,失败是真 Go err(卡应走 error 态)。
4. **动态工具 schema 不可预知**:`mcp__…` 的 args/result 都是任意 JSON/文本,只能通用渲染;名字可按 `mcp__server__tool` 三段拆出 server 徽标。
5. **大体量点**:list_mcp_marketplace 无过滤 ~96 server;install/reconnect 返回含全部 tools 的 inputSchema;search_mcp_calls 一页 50 条全量 input/output/logs;get_mcp_call 的 logs ≤64KB+8KB stderr 尾。


---

# 工具普查 09 — misc（memory / todo / conversation / ask / model / relation / toolset / blocks / mount）

来源：`backend/internal/app/tool/{memory,todo,conversation,ask,model,relation,toolset,blocks,mount}`，以代码为唯一真相（2026-07-05 读码）。
装配位置（`bootstrap/build_services.go`）：**Resident**（每回合完整定义在场）= `ask_user`、`todo_write`、`todo_read`、`search_tools`（chat 组装）；**Lazy**（system prompt 只有一行概览，经 search_tools 浮现）= memory 三件、conversation 三件、`get_model_config`、`get_relations`、`search_blocks`。mount 工具是**逐 agent 挂载动态合成**，不在 Resident/Lazy 任何一边（见末节）。
所有 JSON 结果经 `toolapp.ToJSON`（紧凑单行 `json.Marshal`；marshal 失败降级 `%v`）。summary/danger/execution_group 三字段为框架注入，下文一律不计入 args。

---

## write_memory（lazy）

保存/更新一条跨对话长期记忆（同名 upsert 原地更新）。

**Parameters**（required: name, description, content）：
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| name | string | ✓ | slug 身份：小写字母开头 + 小写/数字/`_`/`-`，≤64 字符；复用同名 = 更新 |
| description | string | ✓ | 一行摘要（进 system-prompt 记忆索引） |
| content | string | ✓ | **PAYLOAD** — markdown 全文正文 |

**补丁风格**：整体替换（同名 upsert 覆盖 description+content），无 ops、无字段 patch。

**Execute 返回**：纯字符串。成功 `Saved memory "<name>". The user can pin or edit it in their UI.`；域错降级为软字符串（非 error）：
- name 不合法 → `Cannot save memory: name "<x>" is invalid (lowercase slug — a-z start, then a-z/0-9/_/-, up to 64 chars).`
- description/content 缺 → `Cannot save memory: both description and content are required.`

写入恒为 `source=ai` 且**非 pinned**（pinned 是用户专属控制、从不暴露给 LLM）。

**progress**：无。**危险性**：写但可逆（用户可编辑/删）。
**ValidateInput sentinel**：`MEMORY_EMPTY_NAME` / `MEMORY_EMPTY_DESCRIPTION` / `MEMORY_EMPTY_CONTENT`（KindInvalid）。

---

## read_memory（lazy）

按 name 加载一条记忆的完整 markdown 正文（非 pinned 记忆在 system prompt 只有 name+description 索引，读全文靠它）。

**Parameters**（required: name）：`name` string ✓ — slug。

**Execute 返回**：原始 markdown 模板（非 JSON）：
```
### <name> (source: <ai|user>)
<description（有则一行）>

---

<content 全文>
```
体积 = 记忆正文长度（无截断）。not found → 软字符串 `Memory "<name>" not found. The system-prompt memory index lists the available names.`

**progress**：无。**危险性**：只读。**sentinel**：`MEMORY_EMPTY_NAME`。

---

## forget_memory（lazy）

按 name 删除一条记忆。**不可逆**（markdown 文件被物理移除）——描述里自declare "Irreversible"。

**Parameters**（required: name）：`name` string ✓。

**Execute 返回**：`Forgot memory "<name>".`；不存在 → 软字符串 `Memory "<name>" not found (already gone?).`

**progress**：无。**危险倾向**：删除类、不可逆——UI 值得显著标记。**sentinel**：`MEMORY_EMPTY_NAME`。

---

## todo_write（resident）

**整体替换**本对话（或 subagent 作用域）的完整任务清单——TodoWrite 语义，永远发全表、非 diff；`items: []` = 清空。清单实时广播到 messages 流（用户看板活着）。

**Parameters**（required: items）：
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| items | array | ✓ | **PAYLOAD** — 完整清单，上限 **64** 项 |
| items[].content | string | ✓ | 祈使句任务描述（trim 后非空） |
| items[].activeForm | string | – | 进行时标签（in_progress 时展示）；缺省回落 content |
| items[].status | string | – | 枚举 `pending` \| `in_progress` \| `completed`；缺省 `pending` |

**补丁风格**：**wholesale 整表替换**（无逐项 id、无 CRUD、按位置寻址）——前端 morph 应做整表 diff，不能指望 op 流。

**Execute 返回**：渲染好的 markdown 清单回显（模板，逐项一行）：
- pending → `- [ ] <content>`
- in_progress → `- [→] <activeForm>`
- completed → `- [x] <content>`
- 空表 → `(todo list cleared — no tasks)`

**progress**：无。**危险性**：safe（内部状态）。
**错误 sentinel**（KindInvalid，tool-result 串给 LLM）：`TODO_ITEMS_REQUIRED`（items 缺失，注意 `[]` 合法）/ `TODO_EMPTY_CONTENT` / `TODO_INVALID_STATUS` / `TODO_TOO_MANY_ITEMS`（>64）。

---

## todo_read（resident）

读回当前对话清单**含已完成项**（补 F39：每轮 reminder 抑制全完成清单，无读路径时 agent 编造）。

**Parameters**：无（`{"type":"object","properties":{}}`）；ValidateInput 恒 nil（接受任意输入）。

**Execute 返回**：与 todo_write 同款 render() markdown（同上三种记号 + 空表串）。

**progress**：无。**危险性**：只读。

---

## search_conversations（lazy）

按**内容**检索历史对话（hybrid 词法+语义，含 archived）。是内容回忆、**非枚举**——描述里明令不许当完整列表呈现。

**Parameters**（required: query）：
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| query | string | ✓ | 要找的内容 |
| limit | integer | – | 1–20，默认 8（≤0→8，>20 夹到 20） |

**Execute 返回** JSON：
```json
{"hits":[{"conversationId","title?","snippet?","messageId?","matchedChunks?"}],"total":N}
```
`messageId` = 命中消息（检索锚点）；只返 snippet、绝不返全文。体积小（≤20 hit × snippet）。

**progress**：无。**危险性**：只读。**sentinel**：`SEARCH_QUERY_REQUIRED`（KindInvalid）。

---

## list_conversations（lazy）

游标分页**忠实枚举**用户对话，最近活跃在前（补 F146：无枚举路径时 agent 拿搜索部分结果冒充全集）。

**Parameters**（全可选）：
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| cursor | string | – | 上页 nextCursor；首页省略 |
| limit | integer | – | 1–50，默认 20 |
| includeArchived | boolean | – | 默认 false（仅 active）；true = active+archived |

**Execute 返回** JSON：
```json
{"conversations":[{"conversationId","title","archived","pinned","lastMessageAt"(RFC3339 UTC)}],"count":N,"nextCursor?"}
```
`nextCursor` 存在 = 还有更多页。轻量行、绝不含 transcript。

**progress**：无。**危险性**：只读。

---

## manage_conversation（lazy）

对**当前**对话做 archive / unarchive / pin / unpin / rename（对话 id 取自 ctx，LLM 不传 id）。描述里两条给 UI 的产品事实：①对正在聊的线程归档形同虚设——再发任何消息**自动 unarchive**；②compaction/摘要是**自动**的、无手动动作无按钮。

**Parameters**（required: action）：
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| action | string | ✓ | 枚举 `archive` \| `unarchive` \| `pin` \| `unpin` \| `rename` |
| title | string | rename 时✓ | 新标题（rename 必填非空白，其余 action 忽略；写入前 trim） |

**补丁风格**：动词式单动作（非 ops 数组）——一次调用一个 action。

**Execute 返回** JSON：
```json
{"conversationId","action","title","archived","pinned"}
```
（更新后的对话状态回显。）ctx 无 conversationId → 软字符串 `manage_conversation is only available inside a conversation (no conversationId in context).`

**progress**：无。**危险性**：可逆状态改动（cautious 级倾向）。
**错误**：枚举外 action / rename 空标题 → `fmt.Errorf` 硬错（ValidateInput 与 Execute 双重把关）。

---

## ask_user（resident）

向用户提问并**阻塞等答案**——Execute 挂在 humanloop broker 上直到用户 accept/decline。这是人在环 UI 的核心工具之一。

**Parameters**（required: message）：
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| message | string | ✓ | 问题正文 |
| options | array of string | – | 可选的多选项（UI 应渲染成选择按钮） |

**Execute 行为**：ctx 里的 broker 收到 `humanloop.Request{Kind: ask, Tool: "ask_user", ToolCallID, ConversationID, Prompt: {message,options} JSON}` 并阻塞：
- 用户 **accept** → 返回用户答案原文（trim 后空 → `(the user submitted an empty answer)`）
- 用户 **decline** / 其它任何 action（fail-safe）→ 固定改道串：`The user declined to answer this question. Proceed without it or ask differently.`
- run 被取消 → ctx error 冒泡（硬错）
- **非交互语境**（workflow/sensor，ctx 无 broker）→ sentinel `ASK_NO_INTERACTIVE_USER`（KindUnavailable，msg "ask_user is only available in an interactive conversation; proceed without asking"）

**progress**：无（阻塞本身即 UI 事件——经 humanloop 帧、不走 progress 块）。
**sentinel**：`ASK_MESSAGE_REQUIRED`（KindInvalid）。

---

## get_model_config（lazy）

只读查看本 workspace 模型配置（防 F68：agent grep 主机 FS 泄明文 key + 臆造审计）。

**Parameters**：无。ValidateInput 恒 nil。

**Execute 返回** JSON（三段）：
```json
{
  "defaultModels": {"<scenario>": {"apiKeyId","modelId"} | "not configured"},   // scenario: dialogue / utility / agent
  "apiKeys": [{"id","provider","displayName","keyMasked","baseUrl","testStatus"}],  // 恒脱敏,永无明文
  "availableModels": [{
    "apiKeyId","provider","modelId","displayName",
    "contextWindow","maxOutput","textInputLimit","multimodalInputLimit",
    "vision","video","audio","nativeDocs","maxMediaParts","maxMediaBytes",
    "nativeOptions":[{"key","label","type","values","default"}]
  }]
}
```
availableModels 尽力而为（catalog 读失败不 fail 工具、返空数组）；能力和 nativeOptions 让 agent 能回答真实可调配置，而非猜模型文档。体积中等（key 数 × 模型目录）。

**progress**：无。**危险性**：只读、无副作用。

---

## get_relations（lazy）

查实体关系邻域（谁在用它/它在用谁），删除/重构前查影响面——HTTP neighborhood 端点的工具孪生。

**Parameters**（required: kind, id）：
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| kind | string | ✓ | 实体类型（function/handler/agent/workflow/trigger/control/approval/mcp/document/skill…，开放描述非 schema enum） |
| id | string | ✓ | 实体 id（fn_… / hd_… / wf_…） |
| depth | integer | – | 1–3，默认 1（0→1；**越界不夹、直接报错** REL_DEPTH_OUT_OF_RANGE） |

**Execute 返回** JSON：
```json
{"edges":[{"id","kind","fromKind","fromId","toKind","toId","attrs?","createdAt","updatedAt","fromName","toName"}],"count":N}
```
（RelationView = Relation 行 + fromName/toName 两个解析名。）

**progress**：无。**危险性**：只读。
**sentinel**：`REL_INVALID_REF`（kind/id 空或类型未知）；depth 越界 → `ErrDepthOutOfRange`。

---

## search_tools（resident，chat 组装）

按能力描述发现 lazy 工具的完整定义（含大 Parameters schema）；命中记入 AgentState，host 后续回合把它们纳入工具列表。排序池 = 静态 lazy 快照 + **per-request 动态 MCP 工具**（已连 MCP server 的工具，search_tools 是其唯一发现路径，F52）。

**Parameters**（required: query）：`query` string ✓ — 能力描述/关键词。

**匹配**：纯词法——query 分词后对 name+description 大小写不敏感 contains 计分，top **5**（defaultSearchToolsLimit，同分按名排）。无 embedding。

**Execute 返回**：**缩进 JSON**（`json.MarshalIndent`，两空格——本批唯一非紧凑 JSON）：
```json
{"tools":[{"name","description","parameters":<完整 JSON Schema，含框架注入的 summary/danger/execution_group 三字段（ToLLMDef 后的形）>}]}
```
无命中 → 软字符串 `No tools matched "<q>". The system prompt lists all available tools; try different keywords.`

**progress**：无。**危险性**：只读元操作。**sentinel**：`TOOLSET_EMPTY_QUERY`（KindInvalid）。

---

## search_blocks（lazy）

工作流积木面板检索——**铁律只搜六类可接线积木**：function / handler 方法 / mcp 工具 / agent / control / approval（对话/文档/skill/memory/workflow/trigger 永不出现）。搜名字、描述**和代码**。

**Parameters**（required: query）：
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| query | string | ✓ | 能力描述 |
| kinds | array of string | – | schema enum：`function`\|`handler`\|`mcp`\|`agent`\|`control`\|`approval`；省略 = 全六类 |
| limit | number | – | 默认 8，max 20 |

**Execute 返回** JSON：
```json
{"count":N,"blocks":[{"ref","kind","entityId","name","snippet?"}]}
```
`ref` 可直接接进 workflow 节点：`fn_<id>` / `hd_<id>.<method>` / `mcp:<server>/<tool>` / agent·control·approval id。每个 handler 方法 / mcp 工具各自成命中；无 ref 的命中被丢弃。
无命中 → 软字符串 `No blocks matched "<q>". Try different capability keywords, or create the block (create_function / create_handler / …).`

**progress**：无。**危险性**：只读。
**sentinel**：`SEARCH_QUERY_REQUIRED` / `SEARCH_TYPE_INVALID`（kinds 里有六类之外的值）。

---

## mount/ — agent 挂载合成工具（⚠️ 动态命名，无固定工具名）

**不是固定名工具**：`mount.Resolver` 在每次 agent invoke 时把 agent 版本的 ToolRef（`fn_<id>` / `hd_<id>.<method>` / `mcp:<server>/<tool>`）解析成绑定工具——每挂载一个工具、以目标实体命名、带目标自己的 description + input schema。agent 永远看不到 run_function/call_handler/Read/Bash 等通用工具。解析 fail-fast（挂载指向被删实体 → invoke 大声失败）；合成名撞名 → 拒整组（`ErrMountInvalid`）。三种合成形态：

### ① functionTool（name = **function 的名字**，逐实体动态）
- 用途：跑该 function（`RunFunction`，TriggeredBy=agent）。
- Parameters：**该 function 自己声明的 Inputs**（`schemapkg.ToJSONSchema(f.ActiveVersion.Inputs)`）——PAYLOAD 视 function 而定。description 缺省回落 `Run the <name> function.`
- ValidateInput 恒 nil（实体执行路径自校验）。
- 返回 JSON（`functiondomain.ExecutionResult`）：`{"ok":bool,"output":any,"errorMsg":"","elapsedMs":N,"logs?":""}`。
- **progress：无**。
- TouchEntity 自报 `(function, fn_<id>, name)` 给对话台账（右岛 touchpoint 依赖此路径识别，**不能按工具名识别**）。

### ② handlerTool（name = **`<handlerName>__<method>`**，mcp__ 风格双下划线——LLM 工具名不许 `.`）
- 用途：调该 handler 方法（`Call`，TriggeredBy=agent）。
- Parameters：该 method 的 Inputs schema。description 缺省 `Call the <method> method of the <handler> handler.`
- 返回 JSON：`{"result": <any>}`（method 返回值原样包一层）。
- **progress：有** —— method 的每个 yield 经 `loopapp.ToolProgress` 实时流成一个 `progress` 块（与 call_handler 同桥）：string yield 原样 + `\n`，非 string JSON marshal + `\n`。逐 yield 一行粒度。
- TouchEntity → `(handler, hd_<id>, <name>__<method>)`。

### ③ mcpTool（name = **`mcp__<serverName>__<toolName>`**）
- 用途：调已连 MCP server 的工具（`CallTool`，triggeredBy=agent）。
- Parameters：MCP 工具自己的 InputSchema（server 下发）。
- 返回：**MCP server 的原始字符串结果**（不包 JSON 壳），体积不可控。
- **progress：有** —— MCP progress 通知经 `mcpinfra.WithProgress(ctx, prog.Print)` 流成 progress 块。
- 解析期错误可区分（UI 值得分开显示）：server 不存在 → `MCP_SERVER_NOT_FOUND`；server 存在但离线（failed/connecting）→ `mcp server "<s>" is not connected: MCP_SERVER_NOT_CONNECTED`（指向该重连 server、非工具被删）；工具不存在 → `MCP_TOOL_NOT_FOUND`。
- TouchEntity → `(mcp, mcp_<id>, serverName)`。

**共同错误**：ref 格式坏 / 端口未接线 / 撞名 → `AGENT_MOUNT_INVALID`（`agentdomain.ErrMountInvalid`）包裹 `mount "<ref>": …` 前缀；function/handler 无 active version → `FN_NO_ACTIVE_VERSION` / `HD_NO_ACTIVE_VERSION`。另有 `CheckHealth`（不 fail-fast 版）逐挂载返 `MountHealth{ref,healthy,name?,error?}` 给 agent 创建/编辑预检——UI 的挂载健康灯数据源。

---

## 本批横向要点（给 UI）

1. **本批无 ops 型补丁工具**：todo_write 是 wholesale 整表替换（前端自行 diff 动画）；write_memory 是同名整体 upsert；manage_conversation 是单动词动作。逐 op morph 不适用于此批。
2. **文本模板返回**（非 JSON）：read_memory（`### name (source) / --- / body`）、todo_write/todo_read（`- [ ] / [→] / [x]` markdown 清单）、write_memory/forget_memory（一句话确认）、mcpTool（server 原始串）。其余全部紧凑 JSON（唯 search_tools 是缩进 JSON）。
3. **progress 块只有两处**：mount 的 handlerTool（逐 yield 一行）与 mcpTool（MCP 通知）。其余全部无中间流。
4. **软失败模式普遍**：not-found / 无命中 / ctx 缺对话 等一律返回可读字符串而非 error（LLM 自纠）；真 error 只在坏 JSON、越界 depth、非交互 ask 等。
5. **mount 工具名不可枚举**：UI 不能按工具名注册卡片皮肤，须走 TouchEntity/BuildSpec 类元信息或前缀规律（`mcp__`、`__` 分隔的 handler 方法）识别。


---

# 10 — 工具框架机制普查（后端真相，供 UI 设计）

来源（逐字核对过的代码）：
- `backend/internal/app/tool/{tool.go,fields.go,toolset.go}`、`toolset/search.go`
- `backend/internal/app/loop/{tools.go,progress.go,stream.go,emit.go}`
- `backend/internal/app/humanloop/humanloop.go`、`app/chat/{interactions.go,host.go,runner.go}`
- `backend/internal/bootstrap/build_services.go`（唯一装配点）
- `backend/internal/app/subagent/{subagent.go,emit.go,registry.go}`
- `backend/internal/pkg/limits/limits.go`

---

## 1. summary / danger / execution_group（框架三字段）

**注入**（`tool/fields.go: injectStandardFields`，经 `ToLLMDef` 在把 Tool 转成 LLM ToolDef 时）：
- 工具自己的 `Parameters()` **永不含**这三字段；工具 schema 若已占用其一 → 启动期 panic。
- 注入进 `properties`：
  - `summary`: string — "One sentence: what you're doing and why."
  - `danger`: string enum `["safe","cautious","dangerous"]` — "Risk of THIS call: safe=read-only or reversible; cautious=modifies recoverable state; dangerous=irreversible or external write (waits for user approval). Estimate conservatively."
  - `execution_group`: integer, minimum 1 — "Parallel-batch id: calls sharing a group run together; groups run in order."
- `required` 数组被改写为 `["summary","danger", ...原有required]` —— **summary+danger 排首位、必填**；execution_group 可选。
  - UI 推论：流式 args JSON 里 summary/danger 通常**最先**到达，前端可从半截 args 提早解析出摘要句。

**剥离**（`StripStandardFields`，在 Execute 前）：
- 先 `jsonrepair.Repair`（LLM ~4-8% 吐畸形 JSON），再把三键从 map 摘下、剩余重新 marshal 成纯业务 args 给 `Execute`。
- danger 缺失或非法 → 默认 **safe**（即畸形 danger 永不触发门控）；execution_group < 0 → 0。
- 完全解析不了 → 原文返回 + 零值字段，后续由 `parseToolArgs` 落到单键哨兵 `{"__anselm_unparsed_args__": "<原文>"}`，`executeTool` 检出后给 LLM 回显 "your tool arguments were not valid JSON..."（截 512 字节回显原文）。

**danger 三级语义**（纯信任、LLM 每次自报、工具不设下限）：
| 级别 | 语义 | 运行时行为 |
|---|---|---|
| `safe` | 只读或可逆 | 静默执行 |
| `cautious` | 改可恢复状态 | **执行、不阻塞**，前端应显著标记 |
| `dangerous` | 不可逆或外部写 | ctx 有 humanloop broker 时阻塞等人批准；无 broker（workflow/sensor 运行）纯信任直接跑 |

**execution_group**（`loop/tools.go: partitionByExecutionGroup`）：同显式组的调用并发跑（一批一个 WaitGroup），组间按升序串行；≤0 的调用各自分到自动组（从 max(显式+1, 1000) 起）排在显式组之后、彼此串行。

---

## 2. tool_call 块的线缆生命周期（messages 流）

块/节点 id 一律**服务端铸造** `blk_<16hex>`（provider 的 call_0/call_1 会跨回合复用，绝不上线缆）。

1. **Open**（durable）：`node.type="tool_call"`，`parentId` = 回合 message id，`content = {"name": "<toolName>"}` —— **只有 name**（Arguments/Summary/Danger omitempty，open 时全空）。
2. **Delta**（ephemeral, seq=0）：`{"chunk": "<argsDelta>"}` —— provider 的 args 增量**原样透传**。
   - ⚠️ **流中片段含未剥的框架键**：summary/danger/execution_group 的 JSON token 就混在 chunk 里逐段流下来。剥离只发生在终点（close 快照 / 落库 / Execute），**从不发生在 delta 上**。前端渲「args 打字机」时要么整段展示原始 JSON、要么自己边流边剥。
   - 由于 required 排序，summary/danger 键一般最先流到。
3. **Close**（durable，重连真相）：`{"status": "...", "result": {"type":"tool_call","content":{...}}, "error": ""}`，快照 content 为：
   ```json
   {"name": "...", "arguments": "<剥离后业务args的JSON字符串>", "summary": "...", "danger": "safe|cautious|dangerous"}
   ```
   status 随整个 LLM 步的终态：completed / cancelled / error。
4. **落库**（`assembleBlocks`）：block.Content = 剥离后 args JSON 串；`attrs = {"tool": name, "summary": ..., "danger": ...}`（summary/danger 非空才写）—— DB 重建历史与 live 快照一致。

**BuildTool 镜像（SSE-C）**：create/edit 类工具实现 `BuildTool`（声明 Kind+Op）时，同一份 args delta **同时**镜像到 entities 流（scope = `{kind: <实体kind>, id: <tool_call块id>}`，node type = build，open content `{"op":"create"|"edit"}`，close result = 最终 args 原文）——实体面板随 LLM 打字实时填充。

---

## 3. progress 块机制

- **谁发**：工具自己在 `Execute` 内调 `loopapp.ToolProgress(ctx)` 拿 writer（loop 在 `runOneTool` 里已把 tool_call id + capture 埋进 ctx）。loop 本身不发 progress。
- **线缆**：首次非空 `Write` 才懒开块 —— Open(`type="progress"`, `parentId=<tool_call块id>`, content=null) → 每次 Write/Print 一个 Delta（ephemeral，`chunk` = 写入的字节原文）→ Close 带快照 `{"text": "<全量累积>"}`（status=completed）。
- **粒度**：无固定粒度——就是工具写多少发多少。Bash 是 stdout/stderr 管道字节块 tee；install/env-fix 是离散行（`Print` 带 `\n`）；WebFetch 是 LLM 摘要的逐 token delta。
- **持久化**：随回合落库（`progressCapture` 折进 blocks，Type=progress、ParentBlockID=tool_call id、排在 tool_result **前**）；**绝不回喂 LLM**（历史投影类型白名单）。
- **数量**：无上限强制。一个 writer 一个块；Close 后 blockID 归零、再写会开**新块**，且一次 Execute 可建多个 writer——但现实工具全是「一次 Execute 一个 writer」，**典型 0 或 1 个 / tool_call**。UI 按「0..n 个 progress 兄弟 + 1 个 tool_result」建模最稳。
- **真的发 progress 的工具**（全量 grep，非测试）：
  - `Bash`（前台命令 stdout+stderr 实时滚动；结果 buf 与 progress 双写）
  - `run_function`（函数 print() 输出三写之一）
  - `call_handler`（handler method 的 yields）+ handler 常驻进程 Call 路径
  - `create_function`/`edit_function`、`create_handler`/`edit_handler`（env-fix buildSink：`✓ env ready (attempt N)` / `✗ attempt N failed: ...` 逐行）
  - `install_mcp_server`（安装阶段行 `[stage] message (NN%)`）
  - `WebFetch`（LLM 摘要逐 token「打字机」）
  - `mcp__<server>__<tool>` 动态 MCP 工具（server 的 progress notification 行）
  - agent 挂载工具 `mount.go`（agent 运行面，非 chat 注册表）
- nil 安全：无 Bridge / 无 tool_call id（REST、测试、workflow 步）全方法 no-op。

---

## 4. tool_result

- **线缆**（tool_result 无流式，一次性产出）：Open(`type="tool_result"`, `parentId=<tool_call块id>`, `content={"content":"<全文>"}`) → 紧接 Close(`{"status":"completed"|"error","result":null,"error":"<errMsg>"}`）。**内容随 open 帧，close 只带 status/error。**
- **落库**：Block{Type: tool_result, Content: 全文, ParentBlockID: tool_call id, Error: errMsg(仅失败), Attrs: `{"tool": "<name>"}`}。
- **体积上限**：`limits.Tools.ToolResultCapKB` 默认 **256**（KiB，可配）→ `capToolResult` 超限截断**保头部**，尾缀：
  `\n...[tool result truncated: %d of %d bytes shown — narrow the query (filters / head_limit / pagination) to see the rest]`
  （注意 Bash 自己的 output cap 相反**保尾部**，头缀 `...[truncated %d bytes from start]`。）
- **error 怎么落**：ValidateInput 失败 → output=`"input validation failed: "+Surface(err)`，status=error；Execute 失败 → output=`Surface(err)`（有部分输出则 `output+"\n\n"+Surface(err)`），status=error，close.error=err.Error()。`errorspkg.Surface` = 干净 Message + 结构化 Details（无 Go 调用栈）。未知工具名 → `tool %q not found`，status=error。
- **拒绝/取消的固定散文**（精确字符串，均记为 **ok=true 的正常 tool_result**、status=completed，工具**从未执行**）：
  - 危险门被拒（`humanloop.DenyFeedback`）：`The user denied running this tool. Do not retry it unless the user explicitly asks.`
  - ask_user 被拒（`humanloop.DeclineFeedback`）：`The user declined to answer this question. Proceed without it or ask differently.`
  - 运行前取消（gate 等待中 ctx 取消）：`The run was cancelled before this tool ran.`
  - ask_user 空答案：`(the user submitted an empty answer)`

---

## 5. 危险确认门（humanloop）

- **阻塞点**：`loop/tools.go: dispatchWithGate` —— side-effect 之前。条件：ctx 有 broker（chat / 嵌套 agent 运行 seed；workflow/subagent 继承 ctx，**subagent 的危险调用同样会阻塞**、整个调用栈天然 hold）**且** `danger=="dangerous"` **且** 未会话白名单 **且** active skill 未预授权（skill 的 `allowed-tools` 是预授权，命中即跳过逐次确认）。broker 是内存实现，`Broker.Request` 挂起调用 goroutine 直到 resolve 或 ctx 取消。
- **interaction 信号**（chat 注入的 Surface）：messages 流 **ephemeral Signal 帧**（seq=0，不入 replay buffer），event.id = tool_call 块 id，`node.type="interaction"`，content = `humanloop.Request` JSON：
  ```json
  {"toolCallId":"blk_...","kind":"danger","tool":"<toolName>","conversationId":"conv_...",
   "prompt":{"summary":"<LLM自报摘要>","args":{<剥离后业务args>}}}
  ```
  ask_user 同型，`kind:"ask"`、prompt=`{"message":"...","options":["..."]}`。
  **重连真相不是信号**：`GET /api/v1/conversations/{id}/interactions` 列 broker 内存 pending 表。
- **决议**：`POST /api/v1/conversations/{id}/interactions/{toolCallId}` body `{action, answer}`。合法 action 封闭集：`approve | approve_always | deny | accept | decline`（枚举外 422 `INTERACTION_INVALID_ACTION`；无待决 → `NO_PENDING_INTERACTION`）。
  - approve / approve_always → 工具落下去真执行；approve_always 额外把 (conversation, tool) 写入会话白名单。
  - deny → 工具不执行，DenyFeedback 记为 tool_result。fail-safe：非显式 approve 的任何动作都不执行。
  - 决议后 chat 发**对称 resolved 信号**（同 scope、同 `node.type="interaction"`、content=`{"toolCallId":...,"kind":"","tool":"","conversationId":...,"resolved":true}`，ephemeral），前端据此清提示 + rail 的 awaitingInput 琥珀点，不用从 tool_result 反推。**注意**：`humanloop.Request.Kind`/`Tool` 无 `omitempty`，resolved 信号里 `kind`/`tool` 作为**空串在场**（非缺席）——前端判 resolved 一律以 `resolved===true` 为准，勿假设 kind/tool 缺席。
- **always-allow 存在**：`approve_always` → `Broker.Allow(convID, tool)`，仅内存、按 (对话,工具名) 键；对话删除时 `Forget` 清掉；**后端重启即失**。无全局/跨对话白名单。

---

## 6. 全量注册表（`bootstrap/build_services.go` 唯一装配点）

**Resident（每回合完整 schema 在场，13 个）**：
`Read` `Write` `Edit`（filesystem）· `LS` `Glob` `Grep`（search）· `Bash` `BashOutput` `KillShell`（shell）· `ask_user` · `todo_write` `todo_read` · `search_tools`（chat 从 Lazy 集构建后追加，永在场）

**Lazy（system prompt 只有一行概览 name(args): purpose，经 `search_tools` 拉全 schema 或直呼名字自动激活 AutoActivator，103 个）**：

- function（10）：`search_function` `get_function` `create_function` `edit_function` `revert_function` `delete_function` `update_function_meta` `run_function` `search_function_executions` `get_function_execution`
- handler（12）：`search_handler` `get_handler` `create_handler` `edit_handler` `revert_handler` `delete_handler` `call_handler` `update_handler_config` `update_handler_meta` `restart_handler` `search_handler_calls` `get_handler_call`
- agent（10）：`search_agent` `get_agent` `create_agent` `edit_agent` `revert_agent` `delete_agent` `update_agent_meta` `invoke_agent` `search_agent_executions` `get_agent_execution`
- control（6）：`search_control` `get_control` `create_control` `edit_control` `revert_control` `delete_control`
- approval（6）：`search_approval` `get_approval` `create_approval` `edit_approval` `revert_approval` `delete_approval`
- workflow（17）：`search_workflow` `get_workflow` `create_workflow` `edit_workflow` `revert_workflow` `delete_workflow` `capability_check_workflow` `trigger_workflow` `stage_workflow` `activate_workflow` `deactivate_workflow` `kill_workflow` `get_flowrun` `search_flowruns` `replay_flowrun` `list_approval_inbox` `decide_approval`
- trigger（9）：`search_triggers` `get_trigger` `create_trigger` `edit_trigger` `delete_trigger` `fire_trigger` `search_activations` `get_activation` `search_firings`
- document（7）：`search_documents` `list_documents` `read_document` `create_document` `edit_document` `move_document` `delete_document`
- attachment（3）：`list_attachments` `read_attachment` `inspect_media`
- memory（3）：`read_memory` `write_memory` `forget_memory`
- model（1）：`get_model_config`
- mcp（6）：`list_mcp_marketplace` `install_mcp_server` `uninstall_mcp_server` `reconnect_mcp` `search_mcp_calls` `get_mcp_call`
- skill（5）：`activate_skill` `get_skill` `create_skill` `edit_skill` `delete_skill`
- blocks（1）：`search_blocks`
- conversation（3）：`search_conversations` `list_conversations` `manage_conversation`
- relation（1）：`get_relations`
- web（2）：`WebFetch` `WebSearch`
- subagent（2）：`Subagent` `get_subagent_trace`

**条件/动态（不在静态 Toolset）**：`mcp__<server>__<tool>` —— per-workspace 已装 MCP server 的动态工具，chat 每请求经 `Deps.DynamicTools` 拉取，走同一 search_tools/discovered 契约（F52）；数量随用户安装而变。

**不在 chat 注册表**（避免混淆）：agent 实体运行的挂载工具 `fn_<name>` / `hd_<name>__<method>` / mcp 挂载（`mount.go`）——agent 的工具宇宙恰是其挂载、绝非系统工具表。

合计静态 116（13 resident + 103 lazy）+ 动态 MCP N 个。Subagent 类型 enum：`Explore` / `Plan` / `general-purpose`。

---

## 7. E3 嵌套（Subagent 子树，前端渲树依赖）

线缆键名是 **`parentId`**（stream Open 帧）；落库/REST 侧是 **`parentBlockId`**（message attrs）。三层锚链：

1. loop 在 `runOneTool` 里 `SetToolCallID(ctx, tc.ID)` —— Subagent 工具的 Execute 由此得知**派它的 tool_call 块 id**。
2. `subagentapp.Spawn` 开一条 sub-message（`msg_` id，`SubagentID=subagt_...`，attrs `{"parentBlockId": "<tool_call块id>"}` 落库），并在 messages 流发 `node.type="message"` 的 Open：`parentId = <tool_call块id>`，content `{"role":"assistant","subagent":true}` —— 前端据此把整个 subagent 回合渲成 Subagent tool_call 下的实时子树。
3. 子运行 ctx `SetMessageID(subCtx, subMsgID)` → loop 的 text/reasoning/tool_call 块 Open 的 `parentId = sub-message id`，递归嵌套自然成树（subagent 自己的 tool_result/progress 再嵌各自 tool_call 下）。终了发 message 节点 Close（status/stopReason/tokens）。
- Subagent 的最终答案同时作为父 tool_call 的**普通 tool_result** 返回（非干净收尾时前缀终态原因，F150）。
- 递归双守卫：subagent 工具集永远剔除 `Subagent` 与 `get_subagent_trace`（隔离泄漏防护），且 ctx 带 SubagentID 时 Execute 直接拒。
- fork skill 不在 tool_call 下时 parentId 为空 → message 节点锚 conversation 根，仍合法。

---

## 附：对 UI 最要紧的 6 条硬事实

1. args delta 流里**混着框架键**（summary/danger/execution_group 未剥），且它们通常最先到；干净的业务 args 只在 close 快照 / DB block 里。
2. tool_result 内容整段随 **open** 帧到（无 delta）；close 只有 status/error、result=null。
3. progress 是 tool_call 的**前置兄弟**（落库序：progress* → tool_result），delta ephemeral、快照键 `{"text"}`；重连只能靠 close 快照或 REST。
4. 拒绝/取消是**成功态 tool_result**（status=completed）+ 固定散文——UI 不能拿 status 区分「被拒」，要认散文或靠 interaction resolved 信号。
5. interaction 信号 ephemeral（seq=0），重连真相 = `GET .../interactions`；决议对称信号 `resolved:true`。
6. cautious 不阻塞、不需要 UI 交互，只需显著标记；dangerous 才有确认卡。


---

# 可视化原语乐器清单(工具卡设计用)

源:`frontend/lib/core/ui/` + `core/design/tokens.dart` + `features/chat/ui/{chat_tool_card,tool_card_skins,tool_card_catalog}.dart`。
流式适性分级:**A**=逐帧喂 partial 便宜 / **B**=可喂但有代价或状态损失 / **C**=只喂 settled 终值。

## 0. 现有工具卡文法(底盘,不是原语但是画布)

- **ChatToolCard**(chat_tool_card.dart)——V3a 底盘:32px 裸行(无边框,`AnSize.row`),icon(`AnIcons.toolIcon`)+ 动词(live 时 `AnShimmerText`)+ mono target + 灰回执尾(live>3s 读秒 / 终态族回执 / 失败红标)+ chevron。生命周期 phases:argsStreaming/awaitingConfirm/running/succeeded/failed(自动展开一次)/denied/cancelled。体经两个 `AnExpandReveal` 挂:`liveBody`(在飞机器窗,完成即溶)与 `body`(用户展开体)。显示上限:通用体 4000 chars / progress 尾 12 行 / JSON 内联 ≤14 行否则 `AnJsonTree`@`AnSize.jsonViewport`(240)。
- **ToolCardSpec**(tool_card_catalog.dart)——每工具文法缝:`verb(t,{live})` 确定性动词对 / `target(state)`(须容忍 partial args)/ `receipt(t,state)` 终态回执(返 `ToolReceiptTone{none/warn/danger}`——**danger → 红 + 自动展开**,warn → 琥珀软半态不展开,none → 灰凭据)/ `body` 族体 / `bodyless`(Read:回执即卡)/ `liveBody` 活窗。未编目 → generic,绝不无声。已编:F1 Read/Write/Edit、F2 Glob/Grep/LS、F3 Bash、F4 create/edit×9 实体。
- **机器窗身份铁律**(tool_card_skins.dart 头注):机器产物必须住显式容器窗(凹陷 mono 面板),绝不借 thinking 低语语法;行保持裸动词。窗内容封顶 6000 chars + 诚实截断注记。

## 1. 代码 / 数据 / 文本渲染

| 乐器 | 渲染什么 | 关键参数 | 流式 | 约束 |
|---|---|---|---|---|
| **AnCodeEditor** | 唯一代码块/轻编辑原语:框(AnCodeSurface)+ 顶栏(copy/wrap/edit + 语言标签)+ 行号槽 + 语法高亮(唯一 `highlightCode` tokenizer);`inline` 退化为无框内联板 | `code, lang, editable, inline, compact, wrap, reading`(=内容档 mono 13/1.6 `AnText.codeReading`,行号同切;默认机器档 code 12), `onChanged/onInput`;`chromeHeight=44` 供算收合阈值 | **B**:`code` 纯 prop 可换更长串,但每次全量重新 regex 高亮 + 单 RenderParagraph 无虚拟化 → builds 族流动期故意用纯 mono、落定才换它 | 面向短片段(>~5000 行需上游截断);无界高=内容高父滚,有界=body 内滚 bar 固定;编辑态 soft-wrap |
| **AnCodeBlock** | 只读 mono 文本块(AnCodeSurface + s8 内距),无栏/行号/高亮 chrome | `text?, bare` | **A**:纯 Text,换串即重渲 | 无高亮无 copy;长内容无上限须自截 |
| **AnVersionDiff** | 单框 unified diff:逐行 LCS,增软绿/删软红,顶栏 range/note/+N−N,行号=新文件逻辑行 | `after`(必), `before`(空=全 context), `lang, range, note, bare, reading` | **C**:每 build 全量 LCS + 逐行 IntrinsicWidth,不宜逐帧;Edit 卡在 settled 用 | 面向短单字段;长行横滚;无字符级/双栏;无虚拟化 |
| **AnJsonTree** | JSON 解析成可折叠虚拟化树(TreeSliver),object/array 摘要行 + 类型着色 leaf | `data` XOR `jsonString`, `rootLabel, showRoot, openDepth`;节点封顶 2000 + "…N more",单值 500,环→[Circular],解析失败显错误行 | **C**:data 变即整树重建 → 用户展开态丢失;节点树 upfront 建 | **必须父给有界高**(TreeSliver 不能 shrink-wrap;工具卡用 `SizedBox(height: AnSize.jsonViewport)`) |
| **AnMarkdown** | chat 阅读列 markdown(gpt_markdown 门面):15/1.6 正文、标题降档、围栏码→AnCodeEditor、内联码 chip、表格→AnThinTable、引用左条、链接 scheme 闸、图片惰性占位 | `text, onLinkTap`(null=链接惰性) | **A**:text 纯 prop、容忍未闭合围栏(渲成生长中的活代码块);调用方合并 ≤1/frame。注意围栏码每帧重高亮(AnCodeEditor 代价) | SelectionArea 归宿主;图片永不取网 |
| **AnDocEditor** (+components) | Notion 式 WYSIWYG markdown 编辑器(super_editor 门面):markdown 真相、@ 提及 + / 斜杠菜单共用 caret 锚 popover;components 文件重绘 HR/引用/列表/任务勾/代码块视觉 | `initialMarkdown, onChanged, mentionSource, slashLabels, focusNode, autofocus` | **C**:是编辑器不是流视图;initialMarkdown 变=整编辑器重建 | 重(整 super_editor);工具卡内不宜 |
| **AnThinTable** | 对齐多列展示(非表格 chrome):Flutter Table 共享列轨,首列吃余量,余列 intrinsic 封顶省略;可选行 hover+单选 | `columns(List<AnTableColumn>: key,label,align), rows(List<Map<String,String>>), selectable, onRowTap` | **B**:rebuild 全表 intrinsic 重测;小数据 fine | 单行 cell、拍平字符串;海量用官方 TableView(未引入) |
| **AnKv / AnKvRow** | 紧凑定义列表:key 13 左 · value 贴右(默认内容档 valueReading 15;`dense`/`row.meta`→13);可就地编辑(铅笔/下拉)、tags 行(➕/✕ 药丸) | `rows(label,value,editable,editor,options,wrap,meta / .tags), onChanged(整列派出), mono, dense` | **A**:纯 prop 行列表,值变即重渲 | rows 按位置稳定(重排需 key);wrap 仅只读行 |
| **highlightCode**(syntax_highlighter.dart) | 唯一同步 regex tokenizer → `List<TextSpan>`;语言无关一套 regex(Py/JS/MD/JSON/CEL) | `(code, lang, colors)`;lang v1 不分支 | **A**:同步纯函数 | 铁律:绝不写第二个高亮器 |

## 2. 机器窗族(工具卡专用容器)

| 乐器 | 渲染什么 | 关键参数 | 流式 | 约束 |
|---|---|---|---|---|
| **AnSunkenPanel** | 凹陷面板:surfaceSunken 底 + r-chip + s12/s8 内距;唯一住户=用户聊天泡(WRK-066 批4,header 槽退役) | `child, inset`(15 prose 传 `AnInset.bubble`) | **A**:纯装饰容器 | 非交互填充 |
| **AnWindow**(core,替代 ToolWindow) | 机器窗当家件(WRK-066 批4):白底+hairline+card 圆角;header=命令回显(单行)/actions/maxHeight+collapsible/footer 注记;窗禁套窗 assert | `child?, header, actions, maxHeight, collapsible, footer` | **A** | 窗内长行 wrap(无横滚/无 ANSI) |
| **AnLiveTail**(core,替代 ToolLiveTail,WRK-066 批1) | 活尾巴三脸(term/mono/prose)+bare;O(tail) 反向切尾内建(AnCap.window 帽) | `text, style, tailLines, bare` | **A**:O(尾窗)/帧 | 流式期只读不可滚;回看=落定后展开 |
| **AnCodeSurface** | 代码框共享 chrome(框+白岛;AnCodeEditor/AnVersionDiff 共用) | `child, focused, bare` | A | 刻意无内距 |

## 3. 流式动效 / 揭示

| 乐器 | 渲染什么 | 关键参数 | 流式 | 约束 |
|---|---|---|---|---|
| **AnShimmerText** | 文字流光(光带左→右扫):在途标签的共享 tell(底盘 live 动词就是它) | `text, style`(必), `highlight, active, reveal`(首扫即揭示:光把词写出来) | **A**:静态文本+shader,text 换串便宜 | reducedOrAssistive→纯静态;单行短语用 |
| **AnTypewriter** | 打字机 type→hold→delete→循环;字素安全(emoji/CJK 不裂);caret 移动实/停顿呼吸 | `phrases, loop, showCaret, accentCaret, textStyle, onDone`(非循环打完触发) | **C**:phrases 内容变即**从零重打**——喂已知终值(自动命名),不是 partial 流的载体 | maxLines:1 截断;reduced→静态首句 |
| **AnExpandReveal** | 套件统一折叠揭示:ClipRect+Align heightFactor,仅向下,可安全嵌套(非 AnimatedSize) | `open, child, duration`(zero=即时) | **A**:child 高度变化自然呈现;底盘用它挂 liveBody/body | 全收后 child 移出树(不可聚焦) |
| **AnFadeCollapse** | 超长块收到定高 + 底部渐隐 + 展开/收起行 | `child, collapsible`(调用方判定,如行数>50), `expandLabel/collapseLabel`(i18n 必传), `collapsedHeight=400, fadeColor`(须配底色) | **B**:child 可在收合视口内生长(NeverScrollable viewport 裁切),但展开态是内部 state | fadeColor 默认 canvas——工具卡在 surfaceSunken 上须显式传 |
| **AnStatusDot** | 7px 语义状态点(idle灰/run accent 呼吸环/wait warn/err danger/done ok) | `status(AnStatus)` | **A** | 仅 run 动;reduced 静态 |
| **AnSkeleton** | 加载骨架(row/card/text/lines 骨形 + 扫光) | 具名构造 `.row()` 等 | A | 骨高须对齐真内容(附件卡教训:落地位移) |
| **AnDeferredLoading** | 延迟 160ms 才显 loading(防闪烁) | `child, delay=AnMotion.loaderDelay` | A | 亚阈值异步永不显示 |
| **AnEdgeFade** | 边缘渐隐 scrim(内容在边缘溶解) | `fromTop, color` | A | 调用方定位尺寸 |

## 4. 标签 / 徽章 / 微件

| 乐器 | 渲染什么 | 关键参数 | 流式 | 约束 |
|---|---|---|---|---|
| **AnChip**(替代 AnBadge,WRK-066 批5) | 芯片族当家件:filled 柔底状态徽/outlined 白岛轻芯片;copy/dot/icon/mono 热插拔 | `label, tone, look, icon, dot(AnStatusDot?), mono, copyValue, onTap, strikethrough, tooltip, semanticLabel` | A | 截断封顶 `AnSize.block`(280);truncate(AnTrunc) 三档同文件 |
| **AnTags** | 标签集 Wrap 药丸(可选 tone+健康点+✕)+ 内联添加框;`readOnly`=纯展示 | `tags(List<AnTag>), onChanged, readOnly, showAddField(三态), single` | A(展示态) | 编辑逻辑重,工具卡多用 readOnly |
| **AnRefPill** | 行内实体提及药丸:kind 字形 + label,id 非空可点派 `{kind,id}` | `kind`(后端 EntityKind 线缆值,开放集"?"兜底), `label, id, onTap` | A | 封顶 block+省略;原语不碰导航——builds 结果条接 select intent 的现成件 |
| **AnCallout** | 通栏语气提示条:severity 图标+文案+0–2动作+可关;warn/danger assertive 播报 | `severity, message, title, actions, onDismiss` | A | 通栏级,卡内偏重 |
| **AnStepper** | 步骤进度点列(done/current/upcoming) | `count, current, onStepTap, numbered` | A | 离散推进,无循环动效 |
| **AnInfoCard** | 无边信息单元:head(icon+title+meta)+ 单槽 body + actions | `title, icon, meta, child, actions` | A | 靠留白组织,无边框 |
| **AnAttachmentCard** | 已发送附件文件卡(定宽 248):图标格+文件名+meta 行;5 生命周期态(resolving 骨架/ready/missing 墓碑/failed 重试/oversized 点载) | `kind(线缆词表), filename, metaLine(调用方推), state, onTap` | A(态驱动) | 纯呈现;metaLine 归 feature |
| **AnAttachmentChip** | composer 待发附件 chip(uploading 转圈/failed 红+体即重试) | `kind, filename, meta, uploading, failed, onRetry, onRemove` | A | — |
| **AnAttachmentThumb** | 图片瓦片(96 方瓦/单图 280×240 界) | 见文件 | A | 唯一图片面 |
| **AnDisclosure** | 披露组:**常驻**旋转 chevron 头 + AnExpandReveal 体(≠AnRow hover 互换)——流式轨迹/日志的展开件 | `open, onToggle, label, leading, trailing, child` | A | 受控 |

## 5. 浮层 / 交互 chrome

| 乐器 | 渲染什么 | 关键参数 | 流式 | 约束 |
|---|---|---|---|---|
| **AnDialog**(`anConfirmRoute`) | 模态确认框:scrim+居中岛卡+焦点陷阱/Esc/点遮罩,spring 转场;v1 仅 confirm(title+message+cancel/confirm) | `title, message, confirmLabel, cancelLabel, confirmTone(primary/danger), scrim, reduced` | n/a | 富内容 openDialog 未建;单实例治理在 controller |
| **AnPopover** | 锚定浮层基座(OverlayPortal+CustomSingleChildLayout:翻转+夹取不出屏);dropdown/menu 都在其上 | `controller, overlay builder(得 anchor size)` | n/a | 点外/Esc 关 |
| **AnMenu / AnMenuSurface** | 白岛菜单(section 头+命令行) | items | n/a | min 200 / max 360×320 |
| **AnToast** | 单条 toast:自含进出+自动消隐 4s(zero=常驻),polite liveRegion,左色条 | `message, tone, duration, onDismissed` | n/a | 非锚定不夺焦 |
| **AnButton** | 统一动作钮。**三档**:lg=32/icon20(内容区控件档,15 文字旁)/ md=28/16(chrome 默认)/ sm=24/12(密集触点,KV 铅笔档);变体 ghost/primary(墨 CTA)/danger/icon;`outline/block/round(胶囊)/elevated`;`.iconOnly` 必传 semanticLabel | `label, icon, onPressed(null=惰性), variant, size, …` | n/a | 两档字重体系内的唯一按钮 |
| **AnTabs** | 文字下划线切换器 + IndexedStack 保活 panes;`flow`=随文档滚(仅选中面、不保活) | `items(key,label,count,pane), value, onSelect, flow` | n/a | tab 高 34(有意 row+2);受控 |
| **AnInteractive** | hover/press/focus + 禁用契约的统一底座(一切可点物之母) | `onTap, builder(states), expanded` | n/a | — |

## 6. AnIcons.toolIcon 覆盖面

- 精确表:`run_function→action, call_handler→handler, invoke_agent→agent, trigger_workflow→workflow, run_shell→tool, read_file→doc, write_file/edit_file→edit, web_search/web_fetch→web, search_blocks→search`。
- 关键字推断(先 lowercase):`shell|bash|exec→tool(扳手)`、`search→放大镜`、`file|read|write|doc→doc`、`web|fetch|http|url→globe`、`function/handler/agent/workflow|trigger→实体形`、`create|edit|build|forge→锤`、`mcp*→plug`;兜底=扳手。
- 即:后端 `Bash/Glob(含"file"?否——Glob 无关键字命中→…"glob"无匹配→兜底扳手)/Grep(含"grep"无匹配→扳手)…`——**注意 Glob/Grep/LS 三个检索工具走不到 `search` 分支**(名字里没有 search/file),落兜底扳手;`create_function` 会先命中 `function`(实体形)而非锤(regex 顺序 function 在 create 前)。设计师若在意图形语义,须补精确表。
- 未知键永不崩:`AnIcons.fallback` 可见"?"。

## 7. 关键 token(工具卡常用)

`AnSize.row=32`(行)/ `icon=16, iconSm=12, iconLg=20` / `jsonViewport=240` / `AnRadius.chip=12`(机器窗圆角)/ `AnInset` 阶梯(tight/snug/card/bubble)/ `AnMotion fast120/mid240/slow340/breath1800` + `AnMotionPref.reduced/reducedOrAssistive` 双门控 / 字重两档 `AnText.bodyWeight(w300)/emphasisWeight(w400)` / 字阶:内容 15(reading)vs chrome 13 锚,机器窗 mono 12(`AnText.code`)vs 阅读 mono 13(`codeReading`)。

## 明显缺口(设计师可能要而清单没有)

1. ~~**有界回滚终端窗**~~ ✅已建:`AnTermViewport`/`AnStickViewport`(有界贴底回滚,B4/WRK-066 批1)。
2. **ANSI 转义渲染**:Bash 输出若带 ANSI 色码会裸渲文字;机器窗无 ANSI→TextSpan 解析器。
3. **机器窗横滚/wrap 切换**:AnWindow 内 Text 默认 wrap,长行(diff 外)无横滚选项(copy 已补:`WindowCopyButton` 挂 `AnWindow.actions`,WRK-066 批4 后 4 用点)。
4. **流式 JSON**:AnJsonTree 每次 data 变整树重建、用户展开态丢失,且必须有界高——没有"增量长大的 JSON 视图"。
5. **确定进度(百分比/steps)**:底盘钦定"读秒绝不进度条",但下载/多步构建类工具若要 determinate 进度,除 AnStepper(离散)外无横向进度原语。
6. **并行调用聚合行**:多个 tool_call 并发时没有"N 个调用折叠成一组"的聚合原语(每次调用一条行)。
7. **人在环确认件(V6)**:chassis 只有 `awaitingConfirm` 相位(警示色行),没有内联 approve/deny 按钮卡原语。
8. **文件路径可点**:AnRefPill 只认实体 {kind,id};工具结果里的文件路径/URL 无"点击打开/跳转"药丸(AnMarkdown 链接闸只在 markdown 内)。
9. **图片结果预览**:AnMarkdown 图片是惰性占位;工具产出的图(截图类)只有 AnAttachmentThumb 一条路,无"机器窗内图片"形态。
10. **char/word 级 diff、双栏 diff**:AnVersionDiff 仅行级 unified;小编辑(一词之差)显示为整行删+整行加。
11. **增量高亮**:流动期高亮=每帧全量 regex;builds 活窗因此放弃高亮(纯 mono)——若要"流式也有色",需增量 tokenizer 或按行缓存。
12. ~~**复制整卡结果**~~ ✅已建:`WindowCopyButton` 挂 `AnWindow.actions`(复制未截断全量,WRK-056 R3 / WRK-066 批4)。


---

# Workflow 图画布勘探(census)

勘探对象:workflow 图今天怎么渲染。证据 = 源码逐行核读 + WRK-055(`docs/working/frontend/workflow-page.md`,W1–W5 全落)。

## 关键文件

| 层 | 文件 | 角色 |
|---|---|---|
| 契约 | `frontend/lib/core/contract/entities/values.dart` | `Graph`/`Node`/`Edge`/`NodeKind`/`NodePosition` freezed DTO |
| 契约 | `frontend/lib/core/contract/entities/workflow.dart` | `WorkflowVersion.graph`(raw JSON blob)+ `graphParsed`;`Flowrun`/`FlowrunNode` |
| 纯模型 | `frontend/lib/core/graph/graph_model.dart` | `layoutGraph`:回边 DFS + Sugiyama-lite + 正交路由,纯 Dart 无 widget |
| 纯模型 | `frontend/lib/core/graph/graph_run_state.dart` | `deriveRunState`:flowrun 行 → 节点态/taken/live 边(running 合成) |
| 画布 | `frontend/lib/core/ui/an_graph_canvas.dart` | `AnGraphCanvas` 1270 行:节点 widget + 边 painter + IV 视口 + 编辑面 |
| 消费 | `features/entities/ui/detail/overview/workflow_overview.dart`(framed hero)· `run_cockpit_tab.dart`(run 活图)· `workflow_editor_page.dart`(editable 满幅) | 三形态 |
| gallery | `frontend/lib/dev/gallery/catalog.dart:43-73` | 14 specimens(含空图/40 节点/敌意注入) |

## 1. 图数据模型

- **形状**:`Graph{nodes, edges}`;`Node{id, kind, ref, input(Map<String,String> CEL), retry?, pos?, notes?}`;`Edge{id, from, fromPort?, to}`(`fromPort` 仅 control/approval 分支出口)。
- **5 kind 封闭集**:`enum NodeKind {trigger, action, agent, control, approval, unknown}`——sealed + `@JsonKey(unknownEnumValue: NodeKind.unknown)` 兜底(values.dart:65)。kind→色族:trigger=violet / action=accent / agent=teal / control=warn / approval=danger(GraphColors token)。
- **位置存 workflow JSON**:`NodePosition{int x, int y}` 是后端持久化的 authoring 元数据(执行忽略)。布局规则(graph_model.dart:119-144):**全节点带 pos → 逐字用之**(归一化到 pad 起点);**任一节点缺 pos → 整图自动布局**(不混合——"手摆孤岛浮在自动网格上读作坏")。编辑器拖节点松手即发 `update_node` 存 pos。
- **布局算法 = Sugiyama-lite**(`layoutGraph`,纯函数、无头单测):
  1. 回边判定:迭代 DFS 灰节点(与后端 graph.go `BackEdges` 同算法,声明序确定);
  2. 前向边最长路定 rank(Kahn 拓扑);
  3. 8 趟中位数排序解交叉(Dart sort 不稳定,已加 index tiebreak);
  4. 网格坐标 + 交叉轴居中;LR/TB 双向。
- **几何常量**(GraphGeometry):节点 188×60 rx14、gapX 84 / gapY 44 / pad 48 / stub 22 / corner 12;回边走界外叠放通道(LR 底部 / TB 右侧,loopFirst 16 + loopGap 26)。
- **边路由**:浮动锚正交折线——端点挂到「朝向对方」的面(宽高比加权),stub 直出后拐;产出 `GraphEdgeRoute{edge, isBack, points(折点列), mid(端口药丸锚)}`。汇总为 `GraphLayout{nodeRects(按 id), routes, size, backEdgeIds}`——画布只画不量。

## 2. 渲染栈

- **混合架构**(WRK-055 拍板,业界共识):**节点 = 真 widget**(`_NodeCard`,An* token/文本/图标/Semantics/i18n 全免费),`Positioned` 在变换 Stack 内,key = `ValueKey('graphNode_$id')`;**边 = CustomPaint 底层**(`_EdgePainter`,RepaintBoundary 隔离)。零图形包依赖(graphview/fl_nodes 均否决)。
- **边怎么画**:`_rounded()` 折点列 → 圆角折线(每内拐角提前 r 停 + quadraticBezierTo 过角,r 夹到邻段一半);实心三角箭头沿末段;回边/future 边虚线 = `PathMetric.computeMetrics + extractPath` 打散(`_dash`)。运行态每边取 tier:live(accent 粗 2.6)> taken(ink 2.3)> base > future(淡虚线)。色值 build 解析后传入(painter 不读 Theme)。
- **视口**:`InteractiveViewer` + `TransformationController`(constrained:false、无限 boundary);滚轮 exp(-dy/666.67) 缩放到光标、pinch/触控板双指白拿;fit 自管(k≤1.3、居中);z 轴与 xy 同步缩放让 IV 的 `getMaxScaleOnAxis` 读到真缩放。网格点钉屏(变换外)。
- **交互全走裸 Listener 绕竞技场**:视口级 Listener 做 tap 探测(slop 6px)——节点命中用卡自身 Listener 记的 `_pressedNodeId`(不用 toScene 反算,防帧同步);边命中 = 场景坐标沿折线段距(阈 12);空白点取消选中。**选中完全受控**(`selectedNodeId`+`onNodeTap` props,页面从 URL/state 派生,画布不持有)。编辑面:整卡拖移(scene-space localDelta,slop 3,松手 `onNodeMoved` 提交 pos)、hover 出四向连接柄 → 橡皮筋 `_ConnectPainter` → `onConnect`;拖拽期间 `panEnabled=false` 压住 IV。
- **运行覆层**:`GraphRunState`(纯派生)→ 节点五态(completed/running/failed/parked/future)环色 + 状态点 + running 呼吸环(FadeTransition 0→.5→0)+ ×N 迭代叠卡影 + future 虚线框;彗星 `_CometPainter` 沿 live 边(AnimationController 1.1s,`repaint:` 直驱、树零重建)。`AnMotionPref.reducedOrAssistive` 门控装饰动效。

## 3. 增量可行性:只读 mini 画布渲不完整图

**结论:今天就能渲,零改动不崩;体验问题在「布局跳变」而非「渲染能力」。**

- `layoutGraph` 是纯函数,对不完整图天然健壮:**悬挂边跳过不崩**(graph_model.dart:168 `if (a == null || b == null) continue`)、空图 OK(gallery「空图」specimen)、无入边节点 rank 0。传部分 `Graph` 即渲。
- `AnGraphCanvas(graph: g, framed: true, toolbar: false)` 已是可用只读 mini 形态(framed = 定高 380 + hairline 框 + resize 自动重 fit)。
- **逐个流入的三个跳变源**(增量渲染的真困难):
  1. 每快照重跑 auto-layout,rank/中位数排序翻动 → 节点位置瞬移(`Positioned` 无插值);
  2. 后到的边可把先前前向边**翻成回边** → 路由风格突变(正交折线 → 界外虚线通道);
  3. read plane `didUpdateWidget` 每次换图重 fit → 视口跳(编辑面已豁免,只读面未豁免)。
- **复用量级**:
  - 路 A(零新代码):直接 `AnGraphCanvas(framed, toolbar:false)`,接受跳变;
  - 路 B(小改):`Positioned` → `AnimatedPositioned`(节点已有稳定 ValueKey,先例 an_tabs.dart:193)+ 只读面加 `refitOnChange:false` 或 fit 动画 → **~50-100 行**;
  - 路 C(独立轻件):同文件新建只读 `AnMiniGraph`(无 IV/无编辑/无 run),复用 `layoutGraph` + `_EdgePainter` 的 library-private 静态(`_rounded`/`_arrow`/`_dash` 同文件可用)→ **~200-300 行**(gallery-first 纪律须配 specimen)。

## 4. 动画钩子

- **已有的**:双惰性 AnimationController(comet 1.1s / pulse `AnMotion.breath` 1800ms)全走 `repaint:`/Listenable 直驱(房规:绝不 AnimatedBuilder 重建风暴);FadeTransition 呼吸环;RepaintBoundary 隔离模式(彗星层不连坐全场景);`AnMotionPref` reduced-motion 门控。**动画基建成熟,模式已验证。**
- **缺口但廉价**:
  - 节点浮现/淡出:无现成钩子,但节点是 keyed 真 widget → 包 FadeTransition/ScaleTransition 即可(几行/节点);
  - 边 draw-in(「接上」):无现成,但 `_dash` 已在用 `PathMetric.extractPath` → 按 progress 提取 `extractPath(0, m.length*t)` + 箭头随尖端移动 ≈ **20-30 行 painter 改动**;
  - 脉冲:呼吸环基建直接复用。
- **matched geometry:可行且有项目先例**——`AnOceanSwitcher`(matched-geometry 滑动药丸,an_ocean_switcher.dart:20)+ `an_tabs.dart:193` AnimatedPositioned。图内位移动画 = AnimatedPositioned(id 稳定、rect 来自纯布局);视口 fit 动画 = Matrix4Tween 写 `_tc.value`(~30 行)。跨面(mini→编辑器)Hero 不需要。

## 5. 「落定后回放生长」(settle-then-replay)实现路径与成本

**结论:与现有架构天然契合,是绕开增量布局跳变的正确方案;量级 ~300-450 行,同构先例(W3 运行面)已落地。**

原理优势:拿到完整图 → `layoutGraph` **一次** → 几何冻结(位置永不动、回边分类稳定)→ 按拓扑序 staggered 揭示。位置稳定使 matched geometry 都不需要——只要 fade/scale-in + 边 draw-in。

实现路径:

1. **纯模型**(`core/graph/`):导出拓扑 rank——`_autoLayout` 内已算 longest-path rank 但私有;抽 `graphRanks(Graph)`(复用公开的 `backEdgeIds` + Kahn,~30-50 行,无头单测)。回放序 = rank 升序,回边最后。
2. **揭示态**:仿 `GraphRunState` 模式加 `GraphRevealState{nodeT: Map<String,double>, edgeT: Map<String,double>}`——painter 已按 run 态参数化,「覆层态注入画布」模式已被 W3 验证。
3. **画布揭示面**:`_EdgePainter` 加 per-edge progress(extractPath 截断 + 箭头随尖端);`_NodeCard` 外包 FadeTransition+ScaleTransition(单 controller + 按 rank 的 Interval stagger;边层走 `repaint:` 直驱不重建);~120-200 行。
4. **驱动**:单 AnimationController,时长 = f(层数)(如 rank 数 × 250ms);`AnMotionPref` 门控下直落终态;~50-80 行。
5. **gallery specimen 先行**(纪律),动画拆「纯渲染 frame + 驱动 widget」可逐帧截图(见 memory gallery-first 纪律)。

风险低:所有原语(PathMetric 截路径、stagger、repaint 直驱、reduced-motion 门控、RepaintBoundary)在 an_graph_canvas.dart 同文件已有活用例。真·流式渲染(不等 settle 逐个放)才是贵一个量级的方向——需冻结/增量布局策略,settle-then-replay 正是绕开它。
