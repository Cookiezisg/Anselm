// SettingsPopover — quick theme/accent/density tweaks anchored to the
// sidebar settings button. Click outside to close. Heavier settings live
// in Config pane.
//
// SettingsPopover —— sidebar 设置按钮锚定的快捷面板；点击外部关闭。

import { useEffect, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Icon } from "../primitives/Icon.jsx";
import { useUIStore } from "../../store/ui.js";
import { useSettings } from "../../store/settings.js";
import { scaleIn } from "../../motion/tokens.js";

const THEMES = [["system", "系统"], ["light", "明"], ["dark", "暗"]];
const DENSITIES = [["compact", "紧凑"], ["cozy", "适中"], ["comfortable", "舒展"]];
const ACCENTS = [
  ["claude", "#d97757"], ["blue", "#2383e2"],
  ["ink", "#37352f"], ["green", "#0f7b6c"], ["purple", "#6940a5"],
];
const LANGS = [["zh", "中文"], ["en", "English"]];

export function SettingsPopover() {
  const open = useUIStore((s) => s.settingsPopOpen);
  const setOpen = useUIStore((s) => s.setSettingsPopOpen);
  const openPane = useUIStore((s) => s.openPane);
  const settings = useSettings();
  const ref = useRef(null);

  useEffect(() => {
    if (!open) return;
    const onClick = (e) => {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false);
    };
    setTimeout(() => window.addEventListener("click", onClick), 0);
    return () => window.removeEventListener("click", onClick);
  }, [open, setOpen]);

  return (
    <AnimatePresence>
      {open && (
        <motion.div
          ref={ref}
          className="settings-pop"
          {...scaleIn}
          onClick={(e) => e.stopPropagation()}
          style={{ position: "fixed", left: 16, bottom: 60, zIndex: 90 }}
        >
          <div className="settings-pop-row">
            <span>主题</span>
            <div style={{ display: "flex", gap: 4 }}>
              {THEMES.map(([v, l]) => (
                <button
                  key={v}
                  className={"btn btn-xs" + (settings.theme === v ? " btn-primary" : " btn-ghost")}
                  onClick={() => settings.set({ theme: v })}
                >
                  {l}
                </button>
              ))}
            </div>
          </div>

          <div className="settings-pop-row">
            <span>Accent</span>
            <div className="settings-pop-swatches">
              {ACCENTS.map(([k, c]) => (
                <button
                  key={k}
                  className={"settings-pop-swatch" + (settings.accent === k ? " is-active" : "")}
                  style={{ background: c }}
                  onClick={() => settings.set({ accent: k })}
                  title={k}
                />
              ))}
            </div>
          </div>

          <div className="settings-pop-row">
            <span>密度</span>
            <div style={{ display: "flex", gap: 4 }}>
              {DENSITIES.map(([v, l]) => (
                <button
                  key={v}
                  className={"btn btn-xs" + (settings.density === v ? " btn-primary" : " btn-ghost")}
                  onClick={() => settings.set({ density: v })}
                >
                  {l}
                </button>
              ))}
            </div>
          </div>

          <div className="settings-pop-row">
            <span>语言</span>
            <div style={{ display: "flex", gap: 4 }}>
              {LANGS.map(([v, l]) => (
                <button
                  key={v}
                  className={"btn btn-xs" + (settings.lang === v ? " btn-primary" : " btn-ghost")}
                  onClick={() => settings.set({ lang: v })}
                >
                  {l}
                </button>
              ))}
            </div>
          </div>

          <div style={{ borderTop: "1px solid var(--border-soft)", paddingTop: 8, display: "flex", flexDirection: "column", gap: 4 }}>
            <button
              className="settings-pop-link"
              onClick={() => { setOpen(false); openPane("config"); }}
            >
              <Icon.KeyRound /> API Keys / Model / Sandbox / 数据…
            </button>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
