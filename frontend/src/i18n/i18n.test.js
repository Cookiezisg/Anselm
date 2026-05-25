import { describe, it, expect } from "vitest";
import { resources } from "./resources.js";

function flatKeys(obj, prefix = "") {
  return Object.entries(obj).flatMap(([k, v]) =>
    v && typeof v === "object" && !Array.isArray(v)
      ? flatKeys(v, `${prefix}${k}.`)
      : [`${prefix}${k}`]
  );
}

describe("i18n resources", () => {
  it("zh and en expose the same namespaces", () => {
    expect(Object.keys(resources.zh).sort()).toEqual(Object.keys(resources.en).sort());
  });
  it("every namespace has identical key sets in zh and en", () => {
    for (const ns of Object.keys(resources.zh)) {
      expect(flatKeys(resources.en[ns]).sort()).toEqual(flatKeys(resources.zh[ns]).sort());
    }
  });
});
