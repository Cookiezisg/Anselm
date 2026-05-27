// @ts-nocheck
// entities/relation/api — useAllRelations / useRelationFilter / useNeighborhood
// query key + URL shapes. Migrated from src/api/relations.test.js (4b.5 recovery).

import { beforeEach, describe, expect, it } from "vitest";
import { waitFor } from "@testing-library/react";
import { setupFetchSpy, renderQuery } from "../../../shared/api/_testHarness.js";
import { useAllRelations, useRelationFilter, useNeighborhood } from "./relation.js";

let calls;
beforeEach(async () => {
  calls = setupFetchSpy();
  const bridge = await import("../../../shared/bridge/wails.js");
  await bridge.initBaseUrl();
});

describe("useAllRelations", () => {
  it("getsRelationsWithHighLimit", async () => {
    await renderQuery(useAllRelations);
    await waitFor(() => expect(calls.length).toBeGreaterThan(0));
    expect(calls[0].url).toBe("/api/v1/relations?limit=1000");
  });
});

describe("useRelationFilter", () => {
  it("noFilter_returnsPlainEndpoint", async () => {
    await renderQuery(() => useRelationFilter());
    expect(calls[0].url).toBe("/api/v1/relations");
  });

  it("withFilter_serialisesAsQueryString", async () => {
    await renderQuery(() => useRelationFilter({ fromKind: "function", kind: "uses" }));
    expect(calls[0].url).toMatch(/fromKind=function/);
    expect(calls[0].url).toMatch(/kind=uses/);
  });
});

describe("useNeighborhood", () => {
  it("enabledOnlyWhenKindAndIdSet", async () => {
    const { renderHook } = await import("@testing-library/react");
    const { QueryClient, QueryClientProvider } = await import("@tanstack/react-query");
    const { createElement } = await import("react");
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    const wrap = ({ children }) => createElement(QueryClientProvider, { client }, children);
    renderHook(() => useNeighborhood({ kind: "", id: "" }), { wrapper: wrap });
    await new Promise((r) => setTimeout(r, 30));
    expect(calls.length).toBe(0);
  });

  it("urlEncodesKindAndIdAndDepth", async () => {
    await renderQuery(() => useNeighborhood({ kind: "function", id: "fn_x", depth: 2 }));
    expect(calls[0].url).toContain("kind=function");
    expect(calls[0].url).toContain("id=fn_x");
    expect(calls[0].url).toContain("depth=2");
  });
});
