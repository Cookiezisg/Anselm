// Select — custom dropdown primitive replacing native <select>. Styled
// trigger + self-drawn popover so the control looks like the app's fields
// across themes (native <select> renders the raw OS menu). Controlled:
// caller owns `value`, we emit `onChange(value)`.
//
// Select —— 自绘下拉，替代 native <select>。trigger 跟字段同款、popover 自画，
// 跨主题一致。受控：value 由调用方持有，选中回调 onChange(value)。

import React, { useEffect, useRef, useState } from "react";
import { Icon } from "./Icon";

type SelectOption =
  | string
  | { value: string; label?: string };

type NormalizedOption = { value: string; label: string };

type SelectProps = {
  value: string;
  onChange: (value: string) => void;
  options: SelectOption[];
  placeholder?: string;
  mono?: boolean;
  disabled?: boolean;
  ariaLabel?: string;
};

function normalize(options: SelectOption[]): NormalizedOption[] {
  return options.map((o) =>
    typeof o === "string" ? { value: o, label: o } : { value: o.value, label: o.label ?? o.value }
  );
}

export function Select({
  value,
  onChange,
  options,
  placeholder,
  mono = false,
  disabled = false,
  ariaLabel,
}: SelectProps) {
  const opts = normalize(options);
  const selectedIdx = opts.findIndex((o) => o.value === value);
  const selected = selectedIdx >= 0 ? opts[selectedIdx] : null;

  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(-1);
  const rootRef = useRef<HTMLDivElement>(null);
  const popRef = useRef<HTMLDivElement>(null);

  // Close on outside mousedown only while open — listener self-removes.
  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", onDown);
    return () => document.removeEventListener("mousedown", onDown);
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const node = popRef.current?.children[active] as HTMLElement | undefined;
    node?.scrollIntoView({ block: "nearest" });
  }, [open, active]);

  const openPopover = () => {
    setActive(selectedIdx >= 0 ? selectedIdx : 0);
    setOpen(true);
  };

  const pick = (idx: number) => {
    onChange(opts[idx].value);
    setOpen(false);
  };

  const onKeyDown = (e: React.KeyboardEvent<HTMLButtonElement>) => {
    if (disabled) return;
    if (!open) {
      if (e.key === "Enter" || e.key === " " || e.key === "ArrowDown" || e.key === "ArrowUp") {
        e.preventDefault();
        openPopover();
      }
      return;
    }
    if (e.key === "Escape") {
      e.preventDefault();
      e.stopPropagation();
      setOpen(false);
    } else if (e.key === "ArrowDown") {
      e.preventDefault();
      setActive((i) => Math.min(i + 1, opts.length - 1));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setActive((i) => Math.max(i - 1, 0));
    } else if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      if (active >= 0) pick(active);
    }
  };

  return (
    <div ref={rootRef} className={"sel" + (open ? " is-open" : "")}>
      <button
        type="button"
        className="sel-trigger"
        disabled={disabled}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-label={ariaLabel}
        onClick={() => (open ? setOpen(false) : openPopover())}
        onKeyDown={onKeyDown}
      >
        <span className={"sel-val" + (mono ? " is-mono" : "") + (selected ? "" : " is-placeholder")}>
          {selected ? selected.label : placeholder}
        </span>
        <svg className="sel-chev" viewBox="0 0 24 24"><path d="M6 9l6 6 6-6" /></svg>
      </button>
      {open && (
        <div ref={popRef} className="sel-pop" role="listbox">
          {opts.map((o, i) => (
            <div
              key={o.value}
              role="option"
              aria-selected={o.value === value}
              className={
                "sel-opt" +
                (mono ? " is-mono" : "") +
                (o.value === value ? " is-selected" : "") +
                (i === active ? " is-active" : "")
              }
              onMouseEnter={() => setActive(i)}
              onClick={() => pick(i)}
            >
              {o.label}
              {o.value === value && <Icon.Check className="sel-ck" />}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
