import type { ReactNode } from "react";

export function Kbd({ children }: { children: ReactNode }) {
  return (
    <kbd style={{
      fontFamily: "var(--mono)", fontSize: 11, padding: "1px 5px",
      border: "1px solid var(--border)", borderRadius: 3, background: "var(--bg-elev)",
    }}>{children}</kbd>
  );
}
