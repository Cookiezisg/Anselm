// testend/src/App.tsx — P1 minimal 4-col shell. Real layout components land in P2.
//
// P1 最简骨架;真正的 TopBar / ConvSidebar / ChatPanel / TabNav 在 P2 装。
import { Outlet } from "react-router-dom";

export function App() {
  return (
    <div className="app-root">
      <div style={{
        height: 36, borderBottom: "1px solid var(--border)",
        padding: "0 12px", display: "flex", alignItems: "center",
        fontSize: 12, color: "var(--fg-muted)",
      }}>
        Forgify Dev Console V3 — scaffold (P1)
      </div>
      <div className="layout">
        <aside style={{ width: 200, borderRight: "1px solid var(--border)", background: "var(--bg-sidebar)" }}>
          <div className="empty">col1 (P2)</div>
        </aside>
        <section style={{ width: 420, borderRight: "1px solid var(--border)" }}>
          <div className="empty">col2 chat (P2)</div>
        </section>
        <aside style={{ width: 220, borderRight: "1px solid var(--border)", background: "var(--bg-sidebar)" }}>
          <div className="empty">col3 nav (P2)</div>
        </aside>
        <main className="tab-content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
