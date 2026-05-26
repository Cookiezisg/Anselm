// NoModelGate — shown when API keys exist but no model is configured for
// the chat scenario (typically after onboarding skipped or test failed).
// Mirrors NoApiKeyGate's shape so the empty states feel consistent.
//
// NoModelGate —— 有 key 但 chat scenario 未配模型时显示;形态对齐 NoApiKeyGate
// 保持空状态一致(常见于 onboarding 跳过或 testKey 失败两条路径)。

import { useTranslation } from "react-i18next";
import { Icon } from "../../components/primitives/Icon.jsx";
import { Button } from "../../components/primitives/Button.jsx";
import { useOverlayStore } from "@app/model";

export function NoModelGate() {
  const { t } = useTranslation("conv");
  // TODO(4b): pages props 化后移除 feature-tmp→app 过渡反向引用
  const setSettingsOpen = useOverlayStore((s) => s.setSettingsOpen);
  return (
    <div className="empty-shell">
      <div className="empty-shell-card">
        <div className="empty-shell-logo" style={{ background: "var(--status-warn)" }}>
          <Icon.Sparkles />
        </div>
        <div>
          <div className="empty-shell-title">{t("noModel.title")}</div>
          <div className="empty-shell-sub">
            {t("noModel.sub")}
          </div>
        </div>
        <div style={{ display: "flex", gap: 8 }}>
          <Button size="sm" variant="accent" onClick={() => setSettingsOpen(true)}>
            <Icon.ArrowRight /> {t("noModel.action")}
          </Button>
        </div>
      </div>
    </div>
  );
}
