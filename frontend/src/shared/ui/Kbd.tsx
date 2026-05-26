// Kbd — keyboard shortcut chip. boilerplate `kbd` element is already styled
// in base.css; this is just a convenience React wrapper.

import React from "react";

type KbdProps = {
  children?: React.ReactNode;
  className?: string;
};

export function Kbd({ children, className = "" }: KbdProps) {
  return <kbd className={className}>{children}</kbd>;
}
