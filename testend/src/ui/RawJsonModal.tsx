import { useEffect } from "react";
import { useUIStore } from "@/stores/ui";

export function RawJsonModal() {
  const { rawJson, closeRaw } = useUIStore();
  useEffect(() => {
    const h = (e: KeyboardEvent) => { if (e.key === "Escape") closeRaw(); };
    if (rawJson.open) window.addEventListener("keydown", h);
    return () => window.removeEventListener("keydown", h);
  }, [rawJson.open, closeRaw]);
  if (!rawJson.open) return null;
  return (
    <div onClick={closeRaw} style={{
      position: "fixed", inset: 0, background: "rgba(0,0,0,0.4)",
      display: "flex", alignItems: "center", justifyContent: "center", zIndex: 100,
    }}>
      <div onClick={(e) => e.stopPropagation()} style={{
        background: "var(--bg-paper)", border: "1px solid var(--border)",
        borderRadius: 8, padding: 16, maxWidth: "80vw", maxHeight: "80vh",
        overflow: "auto", minWidth: 480,
      }}>
        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 12 }}>
          <strong>{rawJson.title ?? "Raw JSON"}</strong>
          <button onClick={closeRaw} style={{
            background: "none", border: "none", cursor: "pointer", color: "var(--fg-muted)",
          }}>✕</button>
        </div>
        <pre className="raw-json">{JSON.stringify(rawJson.payload, null, 2)}</pre>
      </div>
    </div>
  );
}
