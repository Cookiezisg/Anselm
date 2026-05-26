// KindChip — kind → class + label mapping.

import { describe, expect, it } from "vitest";
import { render } from "@testing-library/react";
import { KindChip } from "./KindChip.tsx";

describe("KindChip", () => {
  it.each([
    ["function", "fn", "Function"],
    ["handler",  "hd", "Handler"],
    ["workflow", "wf", "Workflow"],
    ["skill",    "sk", "Skill"],
    ["mcp",      "mcp","MCP"],
  ])("kind=%s_renders_%s_class_%s_label", (kind, cls, label) => {
    const { container } = render(<KindChip kind={kind} />);
    expect(container.querySelector(`.kind-chip.${cls}`)).toBeTruthy();
    expect(container.textContent).toBe(label);
  });

  it("unknownKind_fallsBackToFnClass_butLabelEchoesKind", () => {
    const { container } = render(<KindChip kind="alien" />);
    expect(container.querySelector(".kind-chip.fn")).toBeTruthy();
    expect(container.textContent).toBe("alien");
  });
});
