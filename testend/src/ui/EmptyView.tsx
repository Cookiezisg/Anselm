import type { ReactNode } from "react";

export function EmptyView({ children }: { children?: ReactNode }) {
  return <div className="empty">{children ?? "no data"}</div>;
}
