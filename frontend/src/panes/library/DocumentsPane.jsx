// DocumentsPane — Phase 5 backend feature; current frontend renders a
// list when data exists, friendly placeholder otherwise.
//
// DocumentsPane —— Phase 5 后端能力；有数据则列出，否则占位。

import { Icon } from "../../components/primitives/Icon.jsx";
import { useDocuments } from "../../api/library.js";
import { RelTime } from "../../components/shared/RelTime.jsx";

export function DocumentsPane() {
  const { data: docs = [], isLoading } = useDocuments();

  return (
    <div className="page">
      <div className="page-header">
        <div className="page-header-text">
          <div className="page-title"><Icon.FileText /> 文档</div>
          <div className="page-subtitle">LLM-ranked attach 库</div>
        </div>
      </div>
      <div className="page-body" style={{ padding: 24, overflowY: "auto" }}>
        {isLoading ? <div className="empty"><div className="sub">加载中…</div></div>
          : docs.length === 0 ? (
            <div className="empty">
              <Icon.FileText className="icon" />
              <div className="title">还没有文档</div>
              <div className="sub">把 markdown 文件放进 ~/.forgify/documents/ 即可被发现</div>
            </div>
          ) : (
            <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
              {docs.map((d) => (
                <div key={d.id} className="card" style={{ flexDirection: "row", alignItems: "center", gap: 12, cursor: "default" }}>
                  <Icon.FileText style={{ width: 16, height: 16, color: "var(--fg-muted)" }} />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div className="card-title">{d.title || d.name || d.id}</div>
                    <div className="card-desc" style={{ marginTop: 2 }}>
                      <RelTime ts={d.updatedAt || d.createdAt} />
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
      </div>
    </div>
  );
}
