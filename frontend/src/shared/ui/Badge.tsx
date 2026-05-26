// Badge — boilerplate `.badge` with kind + optional dot.
// kind: success | error | warn | info | streaming | muted | (none = neutral)
//
// streaming kind ships a pulse-dot (CSS @keyframes pulse-dot) — drives the
// "agent is working" surface.

import React from "react";

type BadgeKind = "success" | "error" | "warn" | "info" | "streaming" | "muted";

type BadgeProps = React.HTMLAttributes<HTMLSpanElement> & {
  kind?: BadgeKind;
  dot?: boolean;
  children?: React.ReactNode;
  className?: string;
};

export function Badge({ kind, dot = true, children, className = "", ...rest }: BadgeProps) {
  const cls = ["badge", kind, className].filter(Boolean).join(" ");
  return (
    <span className={cls} {...rest}>
      {dot && kind && kind !== "muted" && <span className="dot" />}
      {children}
    </span>
  );
}
