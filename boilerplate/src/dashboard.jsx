/* eslint-disable react/prop-types */
// Dashboard — daily-summary empty state. Replaces the generic "morning" welcome.

const { useState: useDashState } = React;

function Dashboard({ openPane, openConv }) {
  const running   = Forgify.flowruns.filter(f => f.status === "running");
  const waiting   = Forgify.flowruns.filter(f => f.status === "waiting_approval");
  const failed    = Forgify.flowruns.filter(f => f.status === "failed");
  const completed = Forgify.flowruns.filter(f => f.status === "completed");
  const todayCount = 47;
  const successRate = 94;

  const greeting = (() => {
    const h = new Date().getHours();
    if (h < 6)  return "凌晨好";
    if (h < 11) return "早上好";
    if (h < 14) return "中午好";
    if (h < 18) return "下午好";
    return "晚上好";
  })();

  return (
    <div className="dash">
      <div className="dash-inner">
        <div className="dash-greeting">
          <div className="dash-greet-text">{greeting}，Sun</div>
          <div className="dash-greet-sub">{new Date().toLocaleDateString("zh-CN", { weekday: "long", month: "long", day: "numeric" })}</div>
        </div>

        {/* KPI row */}
        <div className="dash-kpis">
          <div className="dash-kpi" onClick={() => openPane("execute")}>
            <div className="dash-kpi-num">{todayCount}</div>
            <div className="dash-kpi-label">今日运行</div>
            <div className="dash-kpi-sub">{successRate}% 成功率</div>
          </div>
          <div className={"dash-kpi" + (running.length ? " is-active" : "")} onClick={() => openPane("execute")}>
            <div className="dash-kpi-num">{running.length}</div>
            <div className="dash-kpi-label">运行中</div>
            <div className="dash-kpi-sub">
              {running.length ? running[0].workflow : "没有正在跑的"}
            </div>
          </div>
          <div className={"dash-kpi" + (waiting.length ? " is-warn" : "")} onClick={() => openPane("execute")}>
            <div className="dash-kpi-num">{waiting.length}</div>
            <div className="dash-kpi-label">待批准</div>
            <div className="dash-kpi-sub">
              {waiting.length ? waiting[0].workflow + " · " + relTime(waiting[0].startedAt) : "无"}
            </div>
          </div>
          <div className={"dash-kpi" + (failed.length ? " is-error" : "")} onClick={() => openPane("execute")}>
            <div className="dash-kpi-num">{failed.length}</div>
            <div className="dash-kpi-label">需关注</div>
            <div className="dash-kpi-sub">
              {failed.length ? failed[0].workflow + " · " + relTime(failed[0].startedAt) : "无"}
            </div>
          </div>
        </div>

        {/* Action rows */}
        {waiting.length > 0 && (
          <div className="dash-section">
            <div className="dash-section-head">
              <Icon.Pause style={{ width: 14, height: 14, color: "var(--status-warn)" }} />
              <span>等待审批</span>
              <span className="dash-section-count">{waiting.length}</span>
            </div>
            <div className="dash-card-list">
              {waiting.map(fr => (
                <div key={fr.id} className="dash-action-card">
                  <div className="dash-action-meta">
                    <div className="dash-action-title">{fr.workflow}</div>
                    <div className="dash-action-sub">
                      节点 {fr.nodes.done}/{fr.nodes.total} · 由 <code style={{ fontFamily: "var(--font-mono)" }}>{fr.trigger}</code> 触发 · {relTime(fr.startedAt)}
                    </div>
                  </div>
                  <div className="dash-action-buttons">
                    <button className="btn btn-xs btn-ghost" onClick={() => openPane("execute")}>查看</button>
                    <button className="btn btn-xs btn-danger"><Icon.X /> 拒绝</button>
                    <button className="btn btn-xs btn-accent"><Icon.Check /> 批准并继续</button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {failed.length > 0 && (
          <div className="dash-section">
            <div className="dash-section-head">
              <Icon.AlertCircle style={{ width: 14, height: 14, color: "var(--status-error)" }} />
              <span>最近的失败</span>
              <span className="dash-section-count">{failed.length}</span>
            </div>
            <div className="dash-card-list">
              {failed.map(fr => (
                <div key={fr.id} className="dash-action-card is-error">
                  <div className="dash-action-meta">
                    <div className="dash-action-title">{fr.workflow}</div>
                    <div className="dash-action-sub">
                      <span style={{ color: "var(--status-error)" }}>{fr.error || "节点失败"}</span> · {relTime(fr.startedAt)}
                    </div>
                  </div>
                  <div className="dash-action-buttons">
                    <button className="btn btn-xs btn-ghost" onClick={() => openPane("execute")}>查看日志</button>
                    <button className="btn btn-xs"><Icon.Sparkles /> AI 排查</button>
                    <button className="btn btn-xs"><Icon.Refresh /> 从失败处重跑</button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {running.length > 0 && (
          <div className="dash-section">
            <div className="dash-section-head">
              <span className="spinner" style={{ width: 12, height: 12 }} />
              <span>正在跑</span>
              <span className="dash-section-count">{running.length}</span>
            </div>
            <div className="dash-card-list">
              {running.map(fr => (
                <div key={fr.id} className="dash-action-card">
                  <div className="dash-action-meta">
                    <div className="dash-action-title">{fr.workflow}</div>
                    <div className="dash-action-sub">
                      节点 {fr.nodes.done}/{fr.nodes.total} · 已跑 {fmtDuration(fr.durationMs)}
                    </div>
                    <div className="progress-bar" style={{ width: 240, marginTop: 6 }}>
                      <div style={{ width: (fr.nodes.done / fr.nodes.total * 100) + "%" }} />
                    </div>
                  </div>
                  <div className="dash-action-buttons">
                    <button className="btn btn-xs btn-ghost" onClick={() => openPane("execute")}>查看</button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Recent conversations + quick actions */}
        <div className="dash-grid-2">
          <div className="dash-section">
            <div className="dash-section-head">
              <Icon.MessageSquare style={{ width: 14, height: 14 }} />
              <span>继续对话</span>
            </div>
            <div className="dash-conv-list">
              {Forgify.conversations.slice(0, 4).map(c => (
                <button key={c.id} className="dash-conv" onClick={() => { openConv(c.id); }}>
                  <div className="dash-conv-title">{c.title}</div>
                  <div className="dash-conv-sub">{relTime(c.updatedAt)} · {c.model}</div>
                </button>
              ))}
            </div>
          </div>

          <div className="dash-section">
            <div className="dash-section-head">
              <Icon.Sparkles style={{ width: 14, height: 14, color: "var(--accent)" }} />
              <span>开始新的</span>
            </div>
            <div className="dash-quick-list">
              <button className="dash-quick" onClick={() => openConv(null)}>
                <Icon.Plus /> <span>新对话</span>
              </button>
              <button className="dash-quick" onClick={() => openPane("forge")}>
                <Icon.Hammer /> <span>新建 Function / Handler / Workflow</span>
              </button>
              <button className="dash-quick" onClick={() => openPane("documents")}>
                <Icon.FileText /> <span>新文档</span>
              </button>
              <button className="dash-quick" onClick={() => openPane("skills")}>
                <Icon.Sparkles /> <span>导入 Skill</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

window.Dashboard = Dashboard;
