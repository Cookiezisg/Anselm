// Button — variant + size + loading class composition.

import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { Button } from "./Button.jsx";

describe("Button", () => {
  it("variantPrimary_addsBtnPrimary", () => {
    const { container } = render(<Button variant="primary">x</Button>);
    expect(container.querySelector(".btn.btn-primary")).toBeTruthy();
  });

  it("variantAccent_addsBtnAccent", () => {
    const { container } = render(<Button variant="accent">x</Button>);
    expect(container.querySelector(".btn-accent")).toBeTruthy();
  });

  it("variantDanger_addsBtnDanger", () => {
    const { container } = render(<Button variant="danger">x</Button>);
    expect(container.querySelector(".btn-danger")).toBeTruthy();
  });

  it("sizeXs_addsBtnXs", () => {
    const { container } = render(<Button size="xs">x</Button>);
    expect(container.querySelector(".btn-xs")).toBeTruthy();
  });

  it("loading_addsIsLoadingClass_disablesButton_showsSpinner", () => {
    const { container } = render(<Button loading>x</Button>);
    const btn = container.querySelector(".btn");
    expect(btn.classList.contains("is-loading")).toBe(true);
    expect(btn.disabled).toBe(true);
    expect(container.querySelector(".spinner")).toBeTruthy();
  });

  it("disabledProp_disablesButton", () => {
    const { container } = render(<Button disabled>x</Button>);
    expect(container.querySelector("button").disabled).toBe(true);
  });

  it("click_callsOnClick", async () => {
    const onClick = vi.fn();
    render(<Button onClick={onClick}>click me</Button>);
    await userEvent.click(screen.getByText("click me"));
    expect(onClick).toHaveBeenCalled();
  });

  it("forwardsRef_toUnderlyingButton", () => {
    const ref = { current: null };
    render(<Button ref={ref}>x</Button>);
    expect(ref.current).toBeInstanceOf(HTMLButtonElement);
  });
});
