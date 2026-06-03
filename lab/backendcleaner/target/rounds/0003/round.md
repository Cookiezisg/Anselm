# Round 0003 — pkg/pathguard（波次 0 · M0.1 续）

类型 / 目标：迁移 `pathguard`（AI 文件工具的路径安全守卫）+ 原则 #7 清理。

依赖扫描：
- 上游：`os` / `path/filepath` / `strings`（stdlib）。零上层依赖。
- 下游：`tool/filesystem`（read/write/edit）+ `tool/search`（glob/grep）+ `cmd/server`（M2.3/M7.1 装配）。读类调 `Allow`、写类调 `AllowWrite`。
- 考古发现：逻辑干净，但注释/变量里藏历史包袱（见下）。安全关键件——本地 agentic 平台让 AI 操作真实文件系统的刚需。

修改后完整逻辑（给人看的）：
- 数据模型：`PathGuard` 接口（`Allow` 读/`AllowWrite` 写）+ `rule{path, isDir}` + `defaultGuard{rules, writeOnlyRules}`。
- 编译期 `parseRules`：deny 字符串表 → `[]rule`；结尾 `/`=目录规则；`~/` 展开成绝对（home 未知则丢该条）；`filepath.Clean` 归一。
- 运行期 `checkRules`：强制绝对路径 → `Clean` 解析 `..`（防 traversal 绕过）→ 逐规则判：**绝对规则**锚定精确/前缀；**相对规则**（`.git`/`.env`/`node_modules`）按路径段/basename 任意位置命中。
- 两入口：`Allow` 只过主表；`AllowWrite` = 主表 ∪ 写专属表 → 实现"可读不可写"。
- 两默认表：`DefaultDenyList`（读写全拒：系统目录/凭证/浏览器登录/k8s/`~/.forgify/`）+ `DefaultWriteOnlyExtras`（可读不可写：`.git/`/`.env*`/`node_modules`/`.venv`）。

删除 / 移出（原则 #7：零历史包袱）：
- **历史演化叙述**：`V1.2 §3 final-sweep added the write-side split so...` —— 出现在接口注释、`DefaultWriteOnlyExtras`、`NewDefault`、测试分隔线，全部改写为"当前为何如此"或删除。
- **死变量 + YAGNI**：`parseRules` 里 `isRelative := ...` 算完即 `_ = isRelative`，配 `// future field if we add anchored matching` —— 整段删（rule struct 无此字段，checkRules 现场用 `filepath.IsAbs` 判）。
- **过时注释（doc-drift）**：同处注释写"经下方 `matchPath` 匹配"，但函数实际叫 `checkRules`（改名未同步）—— 删。

契约变更：无对外 API。接口 + 两默认表 + 三构造器（`New`/`NewWithWriteExtras`/`NewDefault`）是内部契约（M2.3/M7.1 下游），签名与规则内容 100% 不动。零关注点移出，不进 deps-todo。

新测试：全用例保留（凭证/系统/forgify/Linux 运行时/Windows 凭证/浏览器登录/kube·docker deny + 正常放行 + 相对路径拒 + 目录规则自身及子孙 + 文件精确匹配 + `~` 展开 + traversal Clean + 空表放行 + 段匹配 + AllowWrite `.git`/`.env`/node_modules + `.env.example` 不误伤），清掉 `V1.2` 字样。

验证：`gofmt -l` 净；`go build -o /dev/null ./...` OK；`go vet` OK；`go test ./internal/pkg/pathguard` 绿；残留 grep `V1.2|matchPath|isRelative` 零命中。

是否更干净：逻辑/规则/接口与现状一致；#7 清掉历史叙述、死变量、过时注释。与 tokencount（纯搬）对比 —— **此件是"搬 + 清"范本**：功能不动，删掉为旧版本/不存在未来设计而留的噪音。

覆盖状态：pathguard 标 cleaned。

下一步：`userpath` 考古 → 余 wikilink/jsonrepair/limits + `modelcaps` 判定 → M0.2 `infra/db`。
