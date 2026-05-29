// ThinkingControl unit tests — shape-driven render + emission behaviour.

import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { ThinkingControl } from "./ThinkingControl.tsx";
import type { ModelCapability, ThinkingSpec } from "../model/types";

function makeCap(override: Partial<ModelCapability> = {}): ModelCapability {
  return {
    provider: "anthropic",
    modelId: "claude-sonnet-4-5",
    thinkingShape: "none",
    effortValues: [],
    budgetMin: 1024,
    budgetMax: 32000,
    contextWindow: 200000,
    maxOutput: 16000,
    contextMode: "full",
    ...override,
  };
}

describe("ThinkingControl — shape none", () => {
  it("noneShape_rendersNothing", () => {
    const { container } = render(
      <ThinkingControl capability={makeCap({ thinkingShape: "none" })} value={undefined} onChange={() => {}} />,
    );
    expect(container.firstChild).toBeNull();
  });

  it("undefinedCapability_rendersNothing", () => {
    const { container } = render(
      <ThinkingControl capability={undefined} value={undefined} onChange={() => {}} />,
    );
    expect(container.firstChild).toBeNull();
  });
});

describe("ThinkingControl — shape toggle", () => {
  const cap = makeCap({ thinkingShape: "toggle" });

  it("toggle_rendersThreeOptions", () => {
    render(<ThinkingControl capability={cap} value={undefined} onChange={() => {}} />);
    expect(screen.getByText("自动")).toBeInTheDocument();
    expect(screen.getByText("开")).toBeInTheDocument();
    expect(screen.getByText("关")).toBeInTheDocument();
  });

  it("toggle_autoOption_emitsUndefined", () => {
    const onChange = vi.fn();
    render(<ThinkingControl capability={cap} value={{ mode: "on" }} onChange={onChange} />);
    fireEvent.click(screen.getByText("自动"));
    expect(onChange).toHaveBeenCalledWith(undefined);
  });

  it("toggle_onOption_emitsModeOn", () => {
    const onChange = vi.fn();
    render(<ThinkingControl capability={cap} value={undefined} onChange={onChange} />);
    fireEvent.click(screen.getByText("开"));
    expect(onChange).toHaveBeenCalledWith({ mode: "on" });
  });

  it("toggle_offOption_emitsModeOff", () => {
    const onChange = vi.fn();
    render(<ThinkingControl capability={cap} value={undefined} onChange={onChange} />);
    fireEvent.click(screen.getByText("关"));
    expect(onChange).toHaveBeenCalledWith({ mode: "off" });
  });
});

describe("ThinkingControl — shape effort", () => {
  const cap = makeCap({ thinkingShape: "effort", effortValues: ["low", "medium", "high"] });

  it("effort_rendersEffortLabelAndSelect", () => {
    render(<ThinkingControl capability={cap} value={undefined} onChange={() => {}} />);
    expect(screen.getByText("思考强度")).toBeInTheDocument();
  });

  it("effort_selectingEffortValue_emitsOnWithEffort", () => {
    const onChange = vi.fn();
    render(<ThinkingControl capability={cap} value={undefined} onChange={onChange} />);
    // Open the Select popover then click "medium".
    const trigger = screen.getByRole("button", { name: "思考强度" });
    fireEvent.click(trigger);
    fireEvent.click(screen.getByText("medium"));
    expect(onChange).toHaveBeenCalledWith({ mode: "on", effort: "medium" });
  });

  it("effort_selectingAuto_emitsUndefined", () => {
    const onChange = vi.fn();
    render(<ThinkingControl capability={cap} value={{ mode: "on", effort: "high" }} onChange={onChange} />);
    const trigger = screen.getByRole("button", { name: "思考强度" });
    fireEvent.click(trigger);
    fireEvent.click(screen.getAllByText("自动")[0]);
    expect(onChange).toHaveBeenCalledWith(undefined);
  });

  it("effort_selectingOff_emitsModeOff", () => {
    const onChange = vi.fn();
    render(<ThinkingControl capability={cap} value={undefined} onChange={onChange} />);
    const trigger = screen.getByRole("button", { name: "思考强度" });
    fireEvent.click(trigger);
    fireEvent.click(screen.getByText("关"));
    expect(onChange).toHaveBeenCalledWith({ mode: "off" });
  });
});

describe("ThinkingControl — shape budget", () => {
  const cap = makeCap({ thinkingShape: "budget", budgetMin: 1024, budgetMax: 32000 });

  it("budget_rendersBudgetLabel", () => {
    render(<ThinkingControl capability={cap} value={undefined} onChange={() => {}} />);
    expect(screen.getByText("思考预算 (tokens)")).toBeInTheDocument();
  });

  it("budget_onMode_showsNumberInput", () => {
    render(<ThinkingControl capability={cap} value={{ mode: "on", budget: 4096 }} onChange={() => {}} />);
    const input = screen.getByRole("spinbutton") as HTMLInputElement;
    expect(input).toBeInTheDocument();
    expect(input.value).toBe("4096");
  });

  it("budget_autoMode_hidesNumberInput", () => {
    render(<ThinkingControl capability={cap} value={undefined} onChange={() => {}} />);
    expect(screen.queryByRole("spinbutton")).not.toBeInTheDocument();
  });

  it("budget_numberInput_emitsOnWithBudget", () => {
    const onChange = vi.fn();
    render(<ThinkingControl capability={cap} value={{ mode: "on", budget: 4096 }} onChange={onChange} />);
    const input = screen.getByRole("spinbutton");
    fireEvent.change(input, { target: { value: "8000" } });
    expect(onChange).toHaveBeenCalledWith({ mode: "on", budget: 8000 });
  });

  it("budget_offMode_emitsModeOff", () => {
    const onChange = vi.fn();
    render(<ThinkingControl capability={cap} value={undefined} onChange={onChange} />);
    // Click 关 (off) segmented button
    const offBtn = screen.getByText("关");
    fireEvent.click(offBtn);
    expect(onChange).toHaveBeenCalledWith({ mode: "off" });
  });
});
