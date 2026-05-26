// NoApiKeyGate — first-run friendly empty state shown when no API key
// is configured. Click opens the settings modal.
//
// NoApiKeyGate —— 没有任何 API key 时显示的首次运行引导；点击打开设置浮层。

import { useTranslation } from "react-i18next";
import { Icon } from "../../components/primitives/Icon.jsx";
import { Button } from "../../components/primitives/Button.jsx";
import { useOverlayStore } from "@app/model";

export function NoApiKeyGate() {
  const { t } = useTranslation("conv");
  // TODO(4b): pages props 化后移除 feature-tmp→app 过渡反向引用
  const setSettingsOpen = useOverlayStore((s) => s.setSettingsOpen);
  return (
    <div className="empty-shell">
      <div className="empty-shell-card">
        <div className="empty-shell-logo" style={{ background: "var(--status-warn)" }}>
          <Icon.KeyRound />
        </div>
        <div>
          <div className="empty-shell-title">{t("noApiKey.title")}</div>
          <div className="empty-shell-sub">
            {t("noApiKey.sub")} <code style={{ fontFamily: "var(--font-mono)" }}>~/.forgify/</code>
          </div>
        </div>
        <div style={{ display: "flex", gap: 8 }}>
          <Button size="sm" variant="accent" onClick={() => setSettingsOpen(true)}>
            <Icon.Plus /> {t("noApiKey.action")}
          </Button>
        </div>
      </div>
    </div>
  );
}
