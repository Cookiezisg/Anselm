/* eslint-disable react/prop-types */
// Function detail — code + version dropdown + diff drawer + runs + schema

const { useState: useFnState } = React;

function VersionPill({ v }) {
  if (v.state === "pending")  return <span className="badge warn"><span className="dot" />pending</span>;
  if (v.state === "current")  return <span className="badge success"><span className="dot" />current</span>;
  if (v.state === "archived") return <span className="badge muted"><span className="dot" style={{ background: "var(--fg-faint)" }} />archived</span>;
  return <span className="badge">{v.state}</span>;
}

function CodeView({ src }) {
  // Naive Python syntax highlighter — keyword + string + comment + def
  const KEYS = new Set(["def", "return", "for", "in", "if", "else", "elif", "from", "import", "class", "is", "not", "None", "True", "False", "and", "or", "len", "sum", "lambda", "with", "as"]);
  const BUILTINS = new Set(["len", "sum", "range", "list", "dict", "tuple", "set", "str", "int", "float"]);
  const lines = src.split("\n");
  return (
    <pre className="codeview">
      {lines.map((line, i) => (
        <div key={i} className="codeview-row">
          <span className="codeview-ln">{i + 1}</span>
          <span className="codeview-line">
            {line.split(/(\s+|[(),:.\[\]'"])/g).map((tok, j) => {
              if (tok.startsWith("'") || tok.startsWith('"')) return <span key={j} className="tok-str">{tok}</span>;
              if (tok.startsWith("#")) return <span key={j} className="tok-com">{tok}</span>;
              if (KEYS.has(tok)) return <span key={j} className="tok-kw">{tok}</span>;
              if (BUILTINS.has(tok)) return <span key={j} className="tok-bi">{tok}</span>;
              if (/^\d+(\.\d+)?$/.test(tok)) return <span key={j} className="tok-num">{tok}</span>;
              return <span key={j}>{tok}</span>;
            })}
          </span>
        </div>
      ))}
    </pre>
  );
}

function FunctionDetail({ forge, onBack }) {
  const detail = Forgify.functionDetails[forge.id] || Forgify.functionDetails.fn_aggregate_week;
  const [version, setVersion] = useFnState(detail.versions[0]);
  const [diffOpen, setDiffOpen] = useFnState(forge.status === "pending");

  const isPending = version.state === "pending";

  return (
    <div className="page">
      <div className="page-header" style={{ paddingTop: 18 }}>
        <div className="page-header-text" style={{ gap: 6 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, fontSize: 12, color: "var(--fg-muted)" }}>
            <button onClick={onBack} className="btn btn-xs btn-ghost">← 返回</button>
            <span>·</span>
            <KindChip kind="function" />
            <span className="cell-mono" style={{ color: "var(--fg-faint)" }}>{forge.id}</span>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <div className="page-title" style={{ fontFamily: "var(--font-mono)" }}>{forge.name}</div>
            <div className="version-dropdown">
              <button className="btn btn-sm">
                <Icon.GitBranch /> {version.v}
                <Icon.ChevronDown />
              </button>
            </div>
            <VersionPill v={version} />
          </div>
          <div className="page-subtitle">
            {forge.desc}
            {isPending && (
              <> · 由对话 <a onClick={() => window.Shell?.openConv("cv_a1")} style={{ cursor: "pointer" }}>CSV → Notion 同步脚本</a> 锻造产生</>
            )}
          </div>
        </div>
        <div className="page-actions">
          {isPending ? (
            <>
              <button className="btn btn-sm btn-danger" onClick={() => {
                window.Shell?.toast?.({ kind: "warn", title: "已 Revert", desc: forge.name + " · 撤销将恢复 pending", undo: () => {} });
              }}><Icon.X /> Revert</button>
              <button className="btn btn-sm" onClick={() => setDiffOpen(d => !d)}>
                <Icon.GitBranch /> {diffOpen ? "隐藏 diff" : "显示 diff"}
              </button>
              <button className="btn btn-sm btn-accent" onClick={() => {
                window.Shell?.toast?.({ kind: "success", title: "已 Accept", desc: forge.name + " · 成为当前版本", undo: () => {} });
              }}><Icon.Check /> Accept</button>
            </>
          ) : (
            <>
              <button className="btn btn-sm"><Icon.Play /> 试跑</button>
              <AskAiTrigger
                context={"Function · " + forge.name + " " + version.v}
                suggestions={[
                  "把超时改成 60 秒",
                  "在失败时通知 Slack",
                  "给关键路径加一个测试 case",
                ]}
              />
              <button className="btn btn-sm"><Icon.MoreHorizontal /></button>
            </>
          )}
        </div>
      </div>

      <div className="split">
        <div className="pane-main">
          {/* Versions row */}
          <div className="fn-versions">
            {detail.versions.map((v, i) => (
              <button
                key={i}
                className={"fn-version" + (v.v === version.v ? " is-active" : "")}
                onClick={() => setVersion(v)}
              >
                <VersionPill v={v} />
                <span className="cell-mono" style={{ fontSize: 11 }}>{v.v}</span>
                <span style={{ color: "var(--fg-faint)", fontSize: 11 }}>{v.at} · {v.author}</span>
              </button>
            ))}
          </div>

          {isPending && diffOpen && (
            <div className="diff" style={{ margin: "16px 0" }}>
              <div className="diff-head">
                <span>aggregate_week.py · v1 → v2 (pending)</span>
                <div className="stats">
                  <span className="add">+10</span>
                  <span className="del">-1</span>
                </div>
              </div>
              <div className="diff-body">
                {Forgify.pendingDiff.map((row, i) => (
                  <div key={i} className={"diff-row " + (row.type === "hunk" ? "hunk" : row.type)}>
                    {row.type === "hunk" ? (
                      <div className="code" style={{ gridColumn: "1 / -1" }}>{row.text}</div>
                    ) : (
                      <>
                        <div className="ln">{row.type === "add" ? "+" : row.type === "del" ? "-" : " "}</div>
                        <div className="ln">{i}</div>
                        <div className="code">{row.code}</div>
                      </>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          <h3 className="section-label">代码</h3>
          <CodeView src={detail.code} />
        </div>

        <aside className="pane-aside">
          <div className="aside-section">
            <div className="aside-label">契约</div>
            <div className="aside-kv">
              <div className="k">输入</div><div className="v" style={{ whiteSpace: "normal" }}>{detail.schema.inputs}</div>
              <div className="k">输出</div><div className="v" style={{ whiteSpace: "normal" }}>{detail.schema.outputs}</div>
              <div className="k">运行环境</div><div className="v">{detail.schema.sandbox}</div>
            </div>
          </div>

          <div className="aside-section">
            <div className="aside-label">最近试跑</div>
            <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
              {detail.runs.map((r, i) => (
                <div key={i} style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 12, color: "var(--fg-muted)" }}>
                  <span className="dot" style={{ width: 6, height: 6, borderRadius: "50%", background: r.status === "ok" ? "var(--status-success)" : "var(--status-error)" }} />
                  <span style={{ flex: 1, fontFamily: "var(--font-mono)" }}>{r.at}</span>
                  <span style={{ fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--fg-faint)" }}>{r.duration}</span>
                </div>
              ))}
            </div>
            <div style={{ marginTop: 6, fontSize: 11, color: "var(--fg-faint)" }}>
              {detail.runs[2]?.status === "fail" ? `最近一次失败：${detail.runs[2].input}` : ""}
            </div>
          </div>

          <div className="aside-section">
            <div className="aside-label">被引用</div>
            <div style={{ display: "flex", flexDirection: "column", gap: 4, fontSize: 12 }}>
              <div className="cell-flex"><KindChip kind="workflow" /><span className="cell-mono">weekly-training-summary</span></div>
            </div>
          </div>
        </aside>
      </div>
    </div>
  );
}

window.FunctionDetail = FunctionDetail;
window.VersionPill = VersionPill;
window.CodeView = CodeView;
