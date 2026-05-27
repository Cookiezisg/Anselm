import { useUIStore } from "@/stores/ui";

export function ToastTray() {
  const { toasts, dismissToast } = useUIStore();
  return (
    <div style={{
      position: "fixed", bottom: 16, right: 16,
      display: "flex", flexDirection: "column", gap: 8, zIndex: 200,
    }}>
      {toasts.map((t) => (
        <div key={t.id} className={`pill ${t.kind ?? "info"}`}
          style={{ padding: "8px 14px", minWidth: 240, cursor: "pointer" }}
          onClick={() => dismissToast(t.id)}>
          {t.title && <strong style={{ marginRight: 6 }}>{t.title}</strong>}
          <span>{t.desc}</span>
        </div>
      ))}
    </div>
  );
}
