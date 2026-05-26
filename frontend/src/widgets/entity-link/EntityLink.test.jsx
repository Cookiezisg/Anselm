// EntityLink — prefix routing + display name + click navigation.

import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { usePaneStore } from "@app/model";
import { setNavigator } from "@shared/lib/navigation";

vi.mock("../../hooks/useEntityName.js", () => ({
  useEntityName: vi.fn(() => null),
}));

import { useEntityName } from "../../hooks/useEntityName.js";
import { EntityLink } from "./EntityLink.jsx";

beforeEach(() => {
  usePaneStore.setState({
    openPanes: ["chat"], activeConv: null, activeNarrowPane: null,
    focusEntity: {},
  });
  setNavigator({
    openConv: (id) => { usePaneStore.getState().setActiveConv(id); usePaneStore.getState().openPane("chat"); },
    openEntity: (pane, id) => usePaneStore.getState().openEntity(pane, id),
    openPane: (pane) => usePaneStore.getState().openPane(pane),
    setActiveDocument: (id) => { usePaneStore.getState().setActiveDocument(id); usePaneStore.getState().openPane("documents"); },
  });
  useEntityName.mockReturnValue(null);
});

describe("EntityLink", () => {
  it("noResolvedName_displaysIdAsLabel", () => {
    render(<EntityLink id="fn_abc" />);
    expect(screen.getByText("fn_abc")).toBeInTheDocument();
  });

  it("resolvedName_displaysHumanName", () => {
    useEntityName.mockReturnValue("My Function");
    render(<EntityLink id="fn_abc" />);
    expect(screen.getByText("My Function")).toBeInTheDocument();
  });

  it("title_includesIdEvenWhenNameResolved", () => {
    useEntityName.mockReturnValue("My Function");
    const { container } = render(<EntityLink id="fn_abc" />);
    expect(container.querySelector("button").title).toContain("fn_abc");
    expect(container.querySelector("button").title).toContain("My Function");
  });

  it("convPrefix_clickActivatesChatPaneAndConv", async () => {
    render(<EntityLink id="cv_xyz" />);
    await userEvent.click(screen.getByRole("button"));
    expect(usePaneStore.getState().activeConv).toBe("cv_xyz");
    expect(usePaneStore.getState().openPanes).toContain("chat");
  });

  it("functionPrefix_clickOpensForgePaneWithFocus", async () => {
    render(<EntityLink id="fn_xyz" />);
    await userEvent.click(screen.getByRole("button"));
    expect(usePaneStore.getState().focusEntity.forge).toBe("fn_xyz");
  });

  it("docPrefix_clickOpensDocumentsPane", async () => {
    render(<EntityLink id="doc_xyz" />);
    await userEvent.click(screen.getByRole("button"));
    expect(usePaneStore.getState().focusEntity.documents).toBe("doc_xyz");
  });

  it("unknownPrefix_fallsBackToForgePane", async () => {
    render(<EntityLink id="zzz_abc" />);
    await userEvent.click(screen.getByRole("button"));
    expect(usePaneStore.getState().focusEntity.forge).toBe("zzz_abc");
  });
});
