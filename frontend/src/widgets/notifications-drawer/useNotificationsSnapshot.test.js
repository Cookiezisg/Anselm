// useNotificationsSnapshot — REST snapshot endpoint shape.

import { beforeEach, describe, expect, it } from "vitest";
import { waitFor } from "@testing-library/react";
import { setupFetchSpy, renderQuery } from "@shared/lib/testHarness";
import { useNotificationsSnapshot } from "./useNotificationsSnapshot.js";

let calls;
beforeEach(async () => {
  calls = setupFetchSpy();
  const bridge = await import("@shared/bridge/wails");
  await bridge.initBaseUrl();
  const { useSessionStore } = await import("@entities/session");
  useSessionStore.setState({ currentUserId: "u_test" });
});

describe("useNotificationsSnapshot", () => {
  it("defaultLimit50", async () => {
    await renderQuery(() => useNotificationsSnapshot());
    await waitFor(() => expect(calls.length).toBeGreaterThan(0));
    expect(calls[0].url).toBe("/api/v1/notifications?limit=50");
  });

  it("customLimit_passedAsQueryParam", async () => {
    await renderQuery(() => useNotificationsSnapshot(200));
    expect(calls[0].url).toBe("/api/v1/notifications?limit=200");
  });
});
