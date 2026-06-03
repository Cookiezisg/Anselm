# Round 0005 — pkg/wikilink 剥成纯抽取（波次 0 · M0.1 续）

类型 / 目标：迁移 `wikilink` 并**剥离实体类型知识** —— 从"抽取 + 识别"降为纯文本抽取。

依赖扫描：
- 上游（旧）：`regexp` + `idgen`（用 `KindForID`）。**新版去掉 idgen 依赖，仅 regexp。**
- 下游：`document/relations.go`（M1.10）。

它是什么：从 markdown 抽 `[[<prefix>_<16hex>]]` 双链。旧版顺手用 `idgen.KindForID` 把前缀映射成实体 Kind。

考古发现（分层问题）：
- `idgen.KindByPrefix` 的值 = `relationdomain.EntityKind*` 常量（注释明说 + 下游 `ref.Kind == relationdomain.EntityKindDocument` 印证）。
- 「前缀→EntityKind」是 **relation domain 的业务知识**，却被塞进 `idgen`（pkg 地基），让 idgen + wikilink 两个地基件越界知道实体类型。

修改后完整逻辑：
- `wikilink.Parse(body) []Ref{ID, Count}`：正则 `\[\[([a-z]+_[0-9a-f]{16})\]\]` 抽所有 ID 形态 token、dedup + 计数。**不解析 Kind、不按前缀过滤**（任何格式合法 token 都返回）。
- Kind 解析与过滤后移给调用方（relation 持表、document 消费）。
- wikilink 由此变成跟 tokencount 一样的纯地基工具（零业务知识、零内部依赖）。

为何不聚合成"正则工具包"：盘点 20 个 pkg，import regexp 的非测试文件**仅 wikilink 一个**；jsonrepair/llmparse 不用正则。按"用了正则"聚包 = 按实现细节归类（util 反模式）；为单个工具建泛化包 = 过早抽象（#6/#7）。Go 范式是小而专（path/filepath、net/url）。聚合的正确触发：出现第二个**职责同轴**成员时再聚（轴 = 领域职责，非实现手段）。

契约变更：`wikilink.Parse` 返回 `[]ParsedRef{Kind,ID,Count}` → `[]Ref{ID,Count}`。**内部 Go API**，影响 document（M1.10）内部依赖，不进 contract-changes.md（对外契约表）；记 deps-todo R0005 节。

删除 / 移出（全记 deps-todo R0005）：前缀→EntityKind 映射 + `KindForID` → relation（M1.4）；未知前缀过滤 + Kind 解析 → document（M1.10）；Kind 映射测试用例 → relation 测试。

新测试：保留 空/无匹配/单条/dedup 计数/malformed 跳过/大小写/name-based 不匹配；新增 `ReturnsAllIdShapedTokens` 固定「不按前缀过滤」新语义；删 Kind 相关两例（移 relation）。

验证：`gofmt -l` 净；`go build -o /dev/null ./...` OK；`go vet` OK；`go test ./internal/pkg/wikilink` 绿。

是否更干净：✅ wikilink 从"地基件背 EntityKind 知识"→「纯文本抽取叶子」；分层归位（实体类型知识回 relation domain）。

覆盖状态：wikilink 标 cleaned；Kind 映射 + 过滤 + 测试入 deps-todo（M1.4 / M1.10）。

下一步：`jsonrepair` 考古 → 余 limits + `modelcaps`/`modelcatalog` 判定 → M0.2 `infra/db`。
