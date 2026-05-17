/* eslint-disable react/prop-types */
// Handler detail — class layout (methods) + Config (encrypted) + Calls stats

const { useState: useHdState } = React;

function HandlerDetail({ forge, onBack }) {
  const detail = Forgify.handlerDetails[forge.id] || Forgify.handlerDetails.hd_notion_001;
  const [tab, setTab] = useHdState("class");
  const [selectedMethod, setSelectedMethod] = useHdState(detail.methods[0]);

  const successRate = detail.callStats.ok / (detail.callStats.ok + detail.callStats.fail) * 100;

  return (
    <div className="page">
      <div className="page-header" style={{ paddingTop: 18 }}>
        <div className="page-header-text" style={{ gap: 6 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, fontSize: 12, color: "var(--fg-muted)" }}>
            <button onClick={onBack} className="btn btn-xs btn-ghost">← 返回</button>
            <span>·</span>
            <KindChip kind="handler" />
            <span className="cell-mono" style={{ color: "var(--fg-faint)" }}>{forge.id}</span>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <div className="page-title" style={{ fontFamily: "var(--font-mono)" }}>{forge.name}</div>
            <span className="badge muted">v{parseInt(forge.version.slice(1))}</span>
            <span className="badge success"><span className="dot" />ready</span>
          </div>
          <div className="page-subtitle">{forge.desc}</div>
        </div>
        <div className="page-actions">
          <button className="btn btn-sm"><Icon.Play /> 试调用</button>
          <button className="btn btn-sm"><Icon.GitBranch /> v{parseInt(forge.version.slice(1))} 历史</button>
          <AskAiTrigger
            context={"Handler · " + forge.name + " v" + parseInt(forge.version.slice(1))}
            suggestions={[
              "给 upsert_row 加速率限制重试",
              "把 search 加上分页",
              "把 publish 改成幂等的",
            ]}
          />
        </div>
      </div>

      <div className="page-tabs">
        {[["class", "Class"], ["config", "Config"], ["calls", "Call 历史"], ["versions", "版本"]].map(([k, l]) => (
          <button key={k} className={"page-tab" + (tab === k ? " is-active" : "")} onClick={() => setTab(k)}>{l}</button>
        ))}
      </div>

      <div className="page-body" style={{ padding: 0 }}>
        {tab === "class" && (
          <div className="hd-class">
            <aside className="hd-methods">
              <div className="hd-class-name">
                <Icon.Boxes style={{ width: 14, height: 14, marginRight: 6 }} />
                class <code style={{ fontFamily: "var(--font-mono)", color: "var(--accent)" }}>{forge.name}</code>
              </div>
              {detail.methods.map(m => (
                <button
                  key={m.name}
                  className={"hd-method" + (selectedMethod.name === m.name ? " is-active" : "")}
                  onClick={() => setSelectedMethod(m)}
                >
                  <span style={{ color: "var(--fg-faint)", fontFamily: "var(--font-mono)", fontSize: 10 }}>fn</span>
                  <span className="cell-mono">{m.name}</span>
                </button>
              ))}
            </aside>
            <main className="hd-method-detail">
              <div className="hd-method-sig">
                <span style={{ color: "var(--fg-faint)", fontFamily: "var(--font-mono)" }}>def</span>{" "}
                <span style={{ color: "var(--accent)", fontFamily: "var(--font-mono)", fontWeight: 600 }}>{selectedMethod.name}</span>
                <span style={{ fontFamily: "var(--font-mono)", color: "var(--fg-body)" }}>{selectedMethod.sig}</span>
              </div>
              <div className="hd-method-desc">{selectedMethod.desc}</div>

              <h3 className="section-label">行为</h3>
              <ul style={{ fontSize: 13, color: "var(--fg-body)", lineHeight: 1.7, paddingLeft: 18 }}>
                <li>对参数做轻校验（类型 + 必填）</li>
                <li>失败抛业务 sentinel，不要 panic</li>
                <li>速率限制 80 req/min，超出排队</li>
                <li>所有 fields 走 Notion API 的 properties schema</li>
              </ul>

              <h3 className="section-label">示例</h3>
              <pre className="codeview">
                <div className="codeview-row"><span className="codeview-ln">1</span><span className="codeview-line">notion = forgify.use(<span className="tok-str">"notion_db_writer"</span>)</span></div>
                <div className="codeview-row"><span className="codeview-ln">2</span><span className="codeview-line">notion.<span className="tok-kw">upsert_row</span>(</span></div>
                <div className="codeview-row"><span className="codeview-ln">3</span><span className="codeview-line">  key=<span className="tok-str">"2026-W20"</span>,</span></div>
                <div className="codeview-row"><span className="codeview-ln">4</span><span className="codeview-line">  fields=&#123;<span className="tok-str">"Avg HR"</span>: 142, <span className="tok-str">"Sessions"</span>: 4&#125;,</span></div>
                <div className="codeview-row"><span className="codeview-ln">5</span><span className="codeview-line">)</span></div>
              </pre>
            </main>
          </div>
        )}

        {tab === "config" && (
          <div style={{ padding: "20px 32px", display: "flex", flexDirection: "column", gap: 12, maxWidth: 600 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 12, color: "var(--fg-muted)" }}>
              <Icon.KeyRound style={{ width: 13, height: 13 }} /> Encrypted with AES-GCM · 仅本地存储
            </div>
            {Object.entries(detail.config).map(([k, v]) => (
              <div key={k} className="cfg-row">
                <div className="cfg-label">
                  {k}
                  {v.secret && <span className="badge muted" style={{ marginLeft: 6 }}>secret</span>}
                </div>
                <div className="cfg-value">
                  <input
                    type="text"
                    className="cfg-input"
                    value={v.value}
                    readOnly
                  />
                  {v.masked && <button className="icon-btn"><Icon.Eye /></button>}
                  <button className="icon-btn"><Icon.Copy /></button>
                </div>
              </div>
            ))}
            <div style={{ display: "flex", gap: 6, marginTop: 8 }}>
              <button className="btn btn-sm btn-accent"><Icon.Check /> 保存</button>
              <button className="btn btn-sm btn-danger"><Icon.Trash /> 清空</button>
            </div>
          </div>
        )}

        {tab === "calls" && (
          <div style={{ padding: "16px 32px" }}>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 12, marginBottom: 16 }}>
              <div className="stat-card">
                <div className="stat-label">成功率</div>
                <div className="stat-value">{successRate.toFixed(1)}%</div>
                <div className="stat-sub">{detail.callStats.ok} / {detail.callStats.ok + detail.callStats.fail}</div>
              </div>
              <div className="stat-card">
                <div className="stat-label">p50</div>
                <div className="stat-value">{detail.callStats.p50}<small>ms</small></div>
              </div>
              <div className="stat-card">
                <div className="stat-label">p95</div>
                <div className="stat-value">{detail.callStats.p95}<small>ms</small></div>
              </div>
              <div className="stat-card">
                <div className="stat-label">p99</div>
                <div className="stat-value">{detail.callStats.p99}<small>ms</small></div>
              </div>
            </div>

            <table className="t">
              <thead>
                <tr>
                  <th style={{ paddingLeft: 0 }}>时间</th>
                  <th>方法</th>
                  <th>状态</th>
                  <th>耗时</th>
                  <th>错误</th>
                </tr>
              </thead>
              <tbody>
                {detail.recentCalls.map((c, i) => (
                  <tr key={i}>
                    <td className="cell-mono" style={{ fontSize: 12, color: "var(--fg-muted)" }}>{c.at}</td>
                    <td><span className="cell-mono" style={{ color: "var(--accent)" }}>{c.method}</span></td>
                    <td>
                      {c.status === "ok"
                        ? <span className="badge success"><span className="dot" />ok</span>
                        : <span className="badge error"><span className="dot" />fail</span>}
                    </td>
                    <td className="cell-mono">{c.ms}ms</td>
                    <td><span style={{ color: c.status === "fail" ? "var(--status-error)" : "var(--fg-faint)", fontFamily: "var(--font-mono)", fontSize: 11 }}>{c.error || ""}</span></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {tab === "versions" && (
          <div style={{ padding: "16px 32px" }}>
            <h3 className="section-label" style={{ marginTop: 0 }}>版本历史</h3>
            <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
              {[
                { v: "v7", state: "current",  at: "2 天前", author: "ai · API 重构对话", note: "把 publish 改成幂等 + 加 search 分页" },
                { v: "v6", state: "archived", at: "8 天前", author: "ai · 用户反馈对话",   note: "支持 rich_text 字段" },
                { v: "v5", state: "archived", at: "14 天前", author: "ai · 初版",          note: "首次实现 upsert / search / delete" },
                { v: "v4", state: "archived", at: "20 天前", author: "ai · 试错版",        note: "(已废弃，schema 不兼容)" },
              ].map((row, i) => (
                <div key={i} className="version-row">
                  <VersionPill v={row} />
                  <span className="cell-mono" style={{ fontSize: 12, width: 40 }}>{row.v}</span>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 13, color: "var(--fg-strong)" }}>{row.note}</div>
                    <div style={{ fontSize: 11, color: "var(--fg-faint)", marginTop: 2 }}>{row.at} · {row.author}</div>
                  </div>
                  {row.state !== "current" && (
                    <>
                      <button className="btn btn-xs btn-ghost"><Icon.Eye /> 查看</button>
                      <button className="btn btn-xs btn-ghost"><Icon.Refresh /> 切到此版本</button>
                    </>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

window.HandlerDetail = HandlerDetail;
