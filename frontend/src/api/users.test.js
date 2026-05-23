// api/users — local profile CRUD hooks.

import { beforeEach, describe, expect, it, vi } from "vitest";
import { waitFor } from "@testing-library/react";
import { setupFetchSpy, renderMutation } from "./_testHarness.js";
import { useCreateUser, useUpdateUser, useDeleteUser } from "./users.js";

let calls;
beforeEach(async () => {
  calls = setupFetchSpy();
  const bridge = await import("../bridge/wails.js");
  await bridge.initBaseUrl();
});

describe("useCreateUser", () => {
  it("postsToUsersWithBody", async () => {
    const { result } = await renderMutation(useCreateUser);
    result.current.mutate({ username: "alice" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/users", method: "POST" });
    expect(JSON.parse(calls[0].body)).toEqual({ username: "alice" });
  });

  it("invalidatesUsersOnSuccess", async () => {
    const { result, client } = await renderMutation(useCreateUser);
    const spy = vi.spyOn(client, "invalidateQueries");
    result.current.mutate({ username: "alice" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(spy).toHaveBeenCalledWith({ queryKey: ["users"] });
  });
});

describe("useUpdateUser", () => {
  it("patchesUserById_withDestructuredArg", async () => {
    const { result } = await renderMutation(useUpdateUser);
    result.current.mutate({ id: "u_1", patch: { username: "bob" } });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/users/u_1", method: "PATCH" });
    expect(JSON.parse(calls[0].body)).toEqual({ username: "bob" });
  });
});

describe("useDeleteUser", () => {
  it("deletesById", async () => {
    const { result } = await renderMutation(useDeleteUser);
    result.current.mutate("u_kill");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/users/u_kill", method: "DELETE" });
  });
});
