import { useState } from "react";
import { ERROR_CODES } from "@frontend/shared/api/errorCodes";
import { errorKey, kindForCode } from "@frontend/shared/api/errorMap";
import { Pill } from "@/ui";

export function Errors() {
  const [filter, setFilter] = useState("");
  const codes = Object.values(ERROR_CODES).filter((c) =>
    !filter || c.toLowerCase().includes(filter.toLowerCase())
  );
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
      <div style={{ padding: 8, borderBottom: "1px solid var(--border)" }}>
        <input value={filter} onChange={(e) => setFilter(e.target.value)} placeholder="filter code…" style={{
          width: "100%", padding: "4px 8px", border: "1px solid var(--border)",
          borderRadius: 3, fontSize: 12,
        }} />
      </div>
      <div style={{ flex: 1, overflow: "auto" }}>
        <table className="dt">
          <thead><tr><th>code</th><th>i18n key</th><th>kind</th></tr></thead>
          <tbody>
            {codes.map((c) => (
              <tr key={c}>
                <td className="mono">{c}</td>
                <td className="muted mono">{errorKey(c)}</td>
                <td><Pill kind={kindForCode(c) === "warn" ? "warn" : "error"}>{kindForCode(c)}</Pill></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
