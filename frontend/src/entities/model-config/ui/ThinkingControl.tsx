// ThinkingControl — renders the appropriate thinking-mode control based on
// the model's capability shape. "none"/undefined renders nothing; "toggle"
// renders a 3-way segmented control (auto/on/off); "effort" renders a Select
// over the effortValues plus auto and off; "budget" renders a number input
// for token budget plus auto and off options.
//
// 根据模型能力 thinkingShape 渲染对应的 thinking 控件；none/undefined 不渲染。

import { useTranslation } from "react-i18next";
import { Select } from "@shared/ui/Select";
import type { ModelCapability, ThinkingSpec } from "../model/types";

interface Props {
  capability: ModelCapability | undefined;
  value: ThinkingSpec | undefined;
  onChange: (t: ThinkingSpec | undefined) => void;
  disabled?: boolean;
}

// Decode the current value into a segmented-control key for toggle/effort shapes.
function modeKey(value: ThinkingSpec | undefined): "auto" | "on" | "off" {
  if (!value || value.mode === "auto") return "auto";
  if (value.mode === "off") return "off";
  return "on";
}

export function ThinkingControl({ capability, value, onChange, disabled }: Props) {
  const { t } = useTranslation("settings");
  const shape = capability?.thinkingShape;

  if (!shape || shape === "none") return null;

  if (shape === "toggle") {
    const active = modeKey(value);
    return (
      <div className="set-mc-think">
        <div className="onb-klabel">{t("modelDefaults.thinking.label")}</div>
        <div className="set-seg">
          <button
            type="button"
            disabled={disabled}
            className={"set-seg-opt" + (active === "auto" ? " is-on" : "")}
            onClick={() => onChange(undefined)}
          >
            {t("modelDefaults.thinking.auto")}
          </button>
          <button
            type="button"
            disabled={disabled}
            className={"set-seg-opt" + (active === "on" ? " is-on" : "")}
            onClick={() => onChange({ mode: "on" })}
          >
            {t("modelDefaults.thinking.on")}
          </button>
          <button
            type="button"
            disabled={disabled}
            className={"set-seg-opt" + (active === "off" ? " is-on" : "")}
            onClick={() => onChange({ mode: "off" })}
          >
            {t("modelDefaults.thinking.off")}
          </button>
        </div>
      </div>
    );
  }

  if (shape === "effort") {
    const currentEffort = value?.mode === "on" ? (value.effort ?? "") : value?.mode === "off" ? "__off__" : "__auto__";
    const options = [
      { value: "__auto__", label: t("modelDefaults.thinking.auto") },
      ...(capability?.effortValues ?? []).map((v) => ({ value: v, label: v })),
      { value: "__off__", label: t("modelDefaults.thinking.off") },
    ];
    const handleChange = (v: string) => {
      if (v === "__auto__") { onChange(undefined); return; }
      if (v === "__off__") { onChange({ mode: "off" }); return; }
      onChange({ mode: "on", effort: v });
    };
    return (
      <div className="set-mc-think">
        <div className="onb-klabel">{t("modelDefaults.thinking.effortLabel")}</div>
        <Select
          options={options}
          value={currentEffort}
          onChange={handleChange}
          disabled={disabled}
          ariaLabel={t("modelDefaults.thinking.effortLabel")}
        />
      </div>
    );
  }

  if (shape === "budget") {
    const budgetMin = capability?.budgetMin ?? 0;
    const budgetMax = capability?.budgetMax ?? 100000;
    const active = modeKey(value);
    const currentBudget = value?.mode === "on" ? (value.budget ?? budgetMin) : budgetMin;
    return (
      <div className="set-mc-think">
        <div className="onb-klabel">{t("modelDefaults.thinking.budgetLabel")}</div>
        <div className="set-seg" style={{ marginBottom: 8 }}>
          <button
            type="button"
            disabled={disabled}
            className={"set-seg-opt" + (active === "auto" ? " is-on" : "")}
            onClick={() => onChange(undefined)}
          >
            {t("modelDefaults.thinking.auto")}
          </button>
          <button
            type="button"
            disabled={disabled}
            className={"set-seg-opt" + (active === "on" ? " is-on" : "")}
            onClick={() => onChange({ mode: "on", budget: currentBudget })}
          >
            {t("modelDefaults.thinking.on")}
          </button>
          <button
            type="button"
            disabled={disabled}
            className={"set-seg-opt" + (active === "off" ? " is-on" : "")}
            onClick={() => onChange({ mode: "off" })}
          >
            {t("modelDefaults.thinking.off")}
          </button>
        </div>
        {active === "on" && (
          <input
            type="number"
            className="onb-input"
            style={{ height: 34, fontSize: "var(--fs-13)", padding: "0 10px" }}
            min={budgetMin}
            max={budgetMax}
            value={currentBudget}
            disabled={disabled}
            aria-label={t("modelDefaults.thinking.budgetLabel")}
            onChange={(e) => {
              const n = parseInt(e.target.value, 10);
              if (!isNaN(n)) onChange({ mode: "on", budget: n });
            }}
          />
        )}
      </div>
    );
  }

  return null;
}
