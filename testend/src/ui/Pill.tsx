import type { ReactNode } from "react";

export function Pill({
  children, kind,
}: {
  children: ReactNode;
  kind?: "success" | "error" | "warn" | "info" | "streaming";
}) {
  return <span className={`pill ${kind ?? ""}`}>{children}</span>;
}
