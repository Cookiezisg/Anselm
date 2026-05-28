// entities/apikey + entities/model-config — api-keys + providers + model-configs hooks.
// Migrated from src/api/config.test.js (4b.5 recovery).

import { beforeEach, describe, expect, it, vi } from "vitest";
import { waitFor } from "@testing-library/react";
import { setupFetchSpy, renderMutation, type FetchCall } from "../../../shared/api/_testHarness";
import {
  useCreateApiKey, useUpdateApiKey, useDeleteApiKey, useTestApiKey,
} from "./apikey.js";
import { useUpsertModelConfig } from "../../model-config/api/model-config.js";

let calls: FetchCall[];
beforeEach(async () => {
  calls = setupFetchSpy();
  const bridge = await import("../../../shared/bridge/wails.js");
  await bridge.initBaseUrl();
});

describe("api-key mutations", () => {
  it("useCreateApiKey_postsAndInvalidates", async () => {
    const { result, client } = await renderMutation(useCreateApiKey);
    const spy = vi.spyOn(client, "invalidateQueries");
    result.current.mutate({ provider: "openai", displayName: "test", key: "sk-x" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/api-keys", method: "POST" });
    expect(spy).toHaveBeenCalledWith({ queryKey: ["api-keys"] });
  });

  it("useUpdateApiKey_patchesById", async () => {
    const { result } = await renderMutation(() => useUpdateApiKey("aki_1"));
    result.current.mutate({ displayName: "new" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/api-keys/aki_1", method: "PATCH" });
  });

  it("useDeleteApiKey_deletesById", async () => {
    const { result } = await renderMutation(useDeleteApiKey);
    result.current.mutate("aki_kill");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/api-keys/aki_kill", method: "DELETE" });
  });

  it("useTestApiKey_postsToTestActionSuffix", async () => {
    const { result } = await renderMutation(useTestApiKey);
    result.current.mutate("aki_check");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/api-keys/aki_check:test", method: "POST" });
  });
});

describe("useUpsertModelConfig", () => {
  it("putsToScenarioPath_excludesScenarioFromBody", async () => {
    const { result } = await renderMutation(useUpsertModelConfig);
    result.current.mutate({ scenario: "dialogue", apiKeyId: "aki_x", modelId: "gpt-4" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({
      url: "/api/v1/model-configs/dialogue",
      method: "PUT",
    });
    const body = JSON.parse(calls[0].body);
    expect(body.scenario).toBeUndefined();
    expect(body.apiKeyId).toBe("aki_x");
    expect(body.modelId).toBe("gpt-4");
  });
});
