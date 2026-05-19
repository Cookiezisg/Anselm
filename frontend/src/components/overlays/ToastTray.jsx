// ToastTray — bottom-right stack. Toasts animate in (slide up + fade)
// and out via Framer Motion AnimatePresence + layout transitions.
//
// ToastTray —— 右下角；Framer Motion AnimatePresence + layout 动画。

import { AnimatePresence, motion } from "framer-motion";
import { Icon } from "../primitives/Icon.jsx";
import { useUIStore } from "../../store/ui.js";

export function ToastTray() {
  const toasts = useUIStore((s) => s.toasts);
  const dismiss = useUIStore((s) => s.dismissToast);

  return (
    <div className="toast-tray">
      <AnimatePresence initial={false}>
        {toasts.map((t) => (
          <motion.div
            key={t.id}
            layout
            initial={{ opacity: 0, y: 16, scale: 0.97 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 4, scale: 0.96 }}
            transition={{ duration: 0.22, ease: [0.2, 0.8, 0.2, 1] }}
            className={"toast" + (t.kind ? " is-" + t.kind : "")}
          >
            <div className="toast-icon">
              {t.kind === "error" ? <Icon.AlertCircle />
               : t.kind === "warn" ? <Icon.AlertCircle />
               : <Icon.CheckCircle />}
            </div>
            <div className="toast-body">
              {t.title && <div className="toast-title">{t.title}</div>}
              {t.desc && <div className="toast-desc">{t.desc}</div>}
            </div>
            {t.undo && (
              <button className="btn btn-xs btn-ghost" onClick={() => { t.undo(); dismiss(t.id); }}>
                <Icon.Refresh /> 撤销
              </button>
            )}
            <button className="icon-btn" onClick={() => dismiss(t.id)}><Icon.X /></button>
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  );
}
