// Dashboard — landing screen when no pane is open. Phase 2 shell; real
// KPI strip + recent runs land in Phase 10.
//
// Dashboard —— 无 pane 打开时的着陆页。Phase 2 骨架；Phase 10 真实数据。

import { Icon } from "../../components/primitives/Icon.jsx";
import { useUIStore } from "../../store/ui.js";

function greeting() {
  const h = new Date().getHours();
  if (h < 6) return "凌晨好";
  if (h < 11) return "早上好";
  if (h < 14) return "中午好";
  if (h < 18) return "下午好";
  return "晚上好";
}

export function Dashboard() {
  const openPane = useUIStore((s) => s.openPane);
  return (
    <div className="dash">
      <div className="dash-inner">
        <div className="dash-greeting">
          <div className="dash-greet-text">{greeting()}</div>
          <div className="dash-greet-sub">
            {new Date().toLocaleDateString("zh-CN", {
              weekday: "long", month: "long", day: "numeric",
            })}
          </div>
        </div>

        <div className="dash-section">
          <div className="dash-section-head">
            <Icon.Sparkles style={{ width: 14, height: 14, color: "var(--accent)" }} />
            <span>开始</span>
          </div>
          <div className="dash-quick-list">
            <button className="dash-quick" onClick={() => openPane("chat")}>
              <Icon.MessageSquare /> <span>打开对话</span>
            </button>
            <button className="dash-quick" onClick={() => openPane("forge")}>
              <Icon.Hammer /> <span>锻造工具</span>
            </button>
            <button className="dash-quick" onClick={() => openPane("execute")}>
              <Icon.Play /> <span>查看运行</span>
            </button>
            <button className="dash-quick" onClick={() => openPane("config")}>
              <Icon.Settings /> <span>设置</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
