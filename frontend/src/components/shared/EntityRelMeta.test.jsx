// EntityRelMeta — neighborhood query → dedupe + cap + empty-render skip.

import { beforeEach, describe, expect, it, vi } from "vitest";
import { render } from "@testing-library/react";

vi.mock("../../api/relations.js", () => ({
  useNeighborhood: vi.fn(),
}));

vi.mock("./EntityLink.jsx", () => ({
  EntityLink: ({ id }) => <span data-testid="entity-link">{id}</span>,
}));

vi.mock("./RelGraph.jsx", () => ({
  RelMore: () => null,
}));

import { useNeighborhood } from "../../api/relations.js";
import { EntityRelMeta } from "./EntityRelMeta.jsx";

beforeEach(() => useNeighborhood.mockReset());

describe("EntityRelMeta", () => {
  it("missingEntityId_rendersNothing", () => {
    useNeighborhood.mockReturnValue({ data: [] });
    const { container } = render(<EntityRelMeta />);
    expect(container.firstChild).toBeNull();
  });

  it("zeroRelations_rendersNothing", () => {
    useNeighborhood.mockReturnValue({ data: [] });
    const { container } = render(<EntityRelMeta entityId="fn_a" kind="function" />);
    expect(container.firstChild).toBeNull();
  });

  it("pickOtherSideOfEdge_byEntityIdComparison", () => {
    useNeighborhood.mockReturnValue({
      data: [
        { fromId: "fn_a", toId: "fn_b", fromKind: "function", toKind: "function" },
        { fromId: "fn_c", toId: "fn_a" },
      ],
    });
    const { getAllByTestId } = render(<EntityRelMeta entityId="fn_a" kind="function" />);
    const ids = getAllByTestId("entity-link").map((e) => e.textContent);
    expect(ids).toEqual(["fn_b", "fn_c"]);
  });

  it("dedupes_multiEdgePairs_listEachNeighbourOnce", () => {
    useNeighborhood.mockReturnValue({
      data: [
        { fromId: "fn_a", toId: "fn_b" },
        { fromId: "fn_a", toId: "fn_b" },
      ],
    });
    const { getAllByTestId } = render(<EntityRelMeta entityId="fn_a" kind="function" />);
    expect(getAllByTestId("entity-link")).toHaveLength(1);
  });

  it("capsToLimit", () => {
    useNeighborhood.mockReturnValue({
      data: [
        { fromId: "fn_a", toId: "fn_b" },
        { fromId: "fn_a", toId: "fn_c" },
        { fromId: "fn_a", toId: "fn_d" },
        { fromId: "fn_a", toId: "fn_e" },
        { fromId: "fn_a", toId: "fn_f" },
      ],
    });
    const { getAllByTestId } = render(<EntityRelMeta entityId="fn_a" kind="function" limit={2} />);
    expect(getAllByTestId("entity-link")).toHaveLength(2);
  });

  it("noKind_guessedFromPrefix", () => {
    useNeighborhood.mockReturnValue({ data: [{ fromId: "fn_a", toId: "fn_b" }] });
    render(<EntityRelMeta entityId="fn_a" />);
    expect(useNeighborhood).toHaveBeenCalledWith({ kind: "function", id: "fn_a", depth: 1 });
  });
});
