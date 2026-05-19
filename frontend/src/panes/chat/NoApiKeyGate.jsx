// NoApiKeyGate — first-run friendly empty state shown when no API key
// is configured. Click leads into Config pane.
//
// NoApiKeyGate —— 没有任何 API key 时显示的首次运行引导；点击进 Config pane。

import { Icon } from "../../components/primitives/Icon.jsx";
import { Button } from "../../components/primitives/Button.jsx";
import { useUIStore } from "../../store/ui.js";

export function NoApiKeyGate() {
  const openPane = useUIStore((s) => s.openPane);
  return (
    <div className="empty-shell">
      <div className="empty-shell-card">
        <div className="empty-shell-logo" style={{ background: "var(--status-warn)" }}>
          <Icon.KeyRound />
        </div>
        <div>
          <div className="empty-shell-title">先来配一个 API Key</div>
          <div className="empty-shell-sub">
            key 加密存在 <code style={{ fontFamily: "var(--font-mono)" }}>~/.forgify/</code>，不上传。
          </div>
        </div>
        <div style={{ display: "flex", gap: 8 }}>
          <Button size="sm" onClick={() => openPane("config")}>
            查看 Provider 列表
          </Button>
          <Button size="sm" variant="accent" onClick={() => openPane("config")}>
            <Icon.Plus /> 现在去添加
          </Button>
        </div>
      </div>
    </div>
  );
}
