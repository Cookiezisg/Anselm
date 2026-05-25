// Select — trigger renders selected label; popover open/close, option pick,
// keyboard nav, disabled gating.

import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { Select } from "./Select.jsx";

const opts = ["alpha", "beta", "gamma"];

describe("Select", () => {
  it("rendersSelectedValue_onTrigger", () => {
    render(<Select value="beta" onChange={() => {}} options={opts} />);
    expect(screen.getByRole("button")).toHaveTextContent("beta");
  });

  it("placeholder_whenNoValue", () => {
    const { container } = render(
      <Select value="" onChange={() => {}} options={opts} placeholder="pick one" />
    );
    expect(screen.getByRole("button")).toHaveTextContent("pick one");
    expect(container.querySelector(".sel-val.is-placeholder")).toBeTruthy();
  });

  it("clickTrigger_opensListbox", async () => {
    render(<Select value="alpha" onChange={() => {}} options={opts} />);
    expect(screen.queryByRole("listbox")).toBeNull();
    await userEvent.click(screen.getByRole("button"));
    expect(screen.getByRole("listbox")).toBeTruthy();
    expect(screen.getAllByRole("option")).toHaveLength(3);
  });

  it("clickOption_callsOnChangeWithValue_andCloses", async () => {
    const onChange = vi.fn();
    render(<Select value="alpha" onChange={onChange} options={opts} />);
    await userEvent.click(screen.getByRole("button"));
    await userEvent.click(screen.getByRole("option", { name: "gamma" }));
    expect(onChange).toHaveBeenCalledWith("gamma");
    expect(screen.queryByRole("listbox")).toBeNull();
  });

  it("escape_closesPopover", async () => {
    render(<Select value="alpha" onChange={() => {}} options={opts} />);
    await userEvent.click(screen.getByRole("button"));
    expect(screen.getByRole("listbox")).toBeTruthy();
    await userEvent.keyboard("{Escape}");
    expect(screen.queryByRole("listbox")).toBeNull();
  });

  it("arrowDownThenEnter_selectsNextOption", async () => {
    const onChange = vi.fn();
    render(<Select value="alpha" onChange={onChange} options={opts} />);
    const trigger = screen.getByRole("button");
    trigger.focus();
    await userEvent.keyboard("{ArrowDown}"); // opens, highlight starts at selected (alpha, idx 0)
    await userEvent.keyboard("{ArrowDown}"); // → beta
    await userEvent.keyboard("{Enter}");
    expect(onChange).toHaveBeenCalledWith("beta");
  });

  it("objectOptions_useValueAndLabel", async () => {
    const onChange = vi.fn();
    render(
      <Select
        value="a"
        onChange={onChange}
        options={[{ value: "a", label: "Apple" }, { value: "b", label: "Banana" }]}
      />
    );
    expect(screen.getByRole("button")).toHaveTextContent("Apple");
    await userEvent.click(screen.getByRole("button"));
    await userEvent.click(screen.getByRole("option", { name: "Banana" }));
    expect(onChange).toHaveBeenCalledWith("b");
  });

  it("disabled_showsNoPopoverOnClick", async () => {
    render(<Select value="alpha" onChange={() => {}} options={opts} disabled />);
    const trigger = screen.getByRole("button");
    expect(trigger.disabled).toBe(true);
    await userEvent.click(trigger);
    expect(screen.queryByRole("listbox")).toBeNull();
  });

  it("mono_addsMonoClassToValueAndOptions", async () => {
    const { container } = render(<Select value="alpha" onChange={() => {}} options={opts} mono />);
    expect(container.querySelector(".sel-val.is-mono")).toBeTruthy();
    await userEvent.click(screen.getByRole("button"));
    expect(container.querySelector(".sel-opt.is-mono")).toBeTruthy();
  });

  it("clickOutside_closesPopover", async () => {
    render(
      <div>
        <button>outside</button>
        <Select value="alpha" onChange={() => {}} options={opts} />
      </div>
    );
    await userEvent.click(screen.getByRole("button", { name: "alpha" }));
    expect(screen.getByRole("listbox")).toBeTruthy();
    await userEvent.click(screen.getByRole("button", { name: "outside" }));
    expect(screen.queryByRole("listbox")).toBeNull();
  });
});
