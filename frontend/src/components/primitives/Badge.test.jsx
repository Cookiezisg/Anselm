// Badge — kind class + optional dot rendering.

import { describe, expect, it } from "vitest";
import { render } from "@testing-library/react";
import { Badge } from "./Badge.jsx";

describe("Badge", () => {
  it("withKind_addsKindClass", () => {
    const { container } = render(<Badge kind="success">ok</Badge>);
    expect(container.querySelector(".badge.success")).toBeTruthy();
  });

  it("withKind_addsDotByDefault", () => {
    const { container } = render(<Badge kind="error">x</Badge>);
    expect(container.querySelector(".dot")).toBeTruthy();
  });

  it("dotFalse_omitsDot", () => {
    const { container } = render(<Badge kind="warn" dot={false}>x</Badge>);
    expect(container.querySelector(".dot")).toBeNull();
  });

  it("kindMuted_alwaysOmitsDot", () => {
    const { container } = render(<Badge kind="muted">x</Badge>);
    expect(container.querySelector(".dot")).toBeNull();
  });

  it("noKind_omitsDot", () => {
    const { container } = render(<Badge>x</Badge>);
    expect(container.querySelector(".dot")).toBeNull();
  });

  it("passesThroughExtraClassName", () => {
    const { container } = render(<Badge className="foo">x</Badge>);
    expect(container.querySelector(".badge.foo")).toBeTruthy();
  });
});
