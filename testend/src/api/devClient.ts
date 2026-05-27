import { useUsersStore } from "@/stores/users";

export interface ApiErrorShape {
  code: string;
  message: string;
  details?: unknown;
}

export class ApiError extends Error {
  code: string;
  status: number;
  details?: unknown;
  constructor(payload: ApiErrorShape, status: number) {
    super(payload.message);
    this.code = payload.code;
    this.status = status;
    this.details = payload.details;
  }
}

export interface PageResponse<T> {
  data: T[];
  nextCursor?: string;
  hasMore?: boolean;
}

function activeUserHeader(): HeadersInit {
  const uid = useUsersStore.getState().activeId;
  return uid ? { "X-Forgify-User-ID": uid } : {};
}

async function request<T>(
  method: string,
  path: string,
  body?: unknown,
  extraHeaders?: HeadersInit,
): Promise<T> {
  const res = await fetch(path, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...activeUserHeader(),
      ...extraHeaders,
    },
    body: body == null ? undefined : JSON.stringify(body),
  });
  if (res.status === 204) return undefined as T;
  const ct = res.headers.get("content-type") || "";
  if (!ct.includes("application/json")) {
    if (!res.ok) throw new ApiError({ code: "NETWORK", message: res.statusText }, res.status);
    return (await res.text()) as unknown as T;
  }
  const json = await res.json();
  if (!res.ok) {
    const err = (json?.error ?? { code: "NETWORK", message: res.statusText }) as ApiErrorShape;
    throw new ApiError(err, res.status);
  }
  if (Object.prototype.hasOwnProperty.call(json, "data")) return json.data as T;
  return json as T;
}

export const getJSON  = <T>(path: string) => request<T>("GET", path);
export const postJSON = <T>(path: string, body?: unknown) => request<T>("POST", path, body);
export const patchJSON = <T>(path: string, body?: unknown) => request<T>("PATCH", path, body);
export const putJSON  = <T>(path: string, body?: unknown) => request<T>("PUT", path, body);
export const delJSON  = <T>(path: string) => request<T>("DELETE", path);

export async function getPage<T>(
  path: string,
  query?: Record<string, string | number | undefined>,
): Promise<PageResponse<T>> {
  const qs = query
    ? "?" + Object.entries(query)
        .filter(([, v]) => v !== undefined && v !== "")
        .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`)
        .join("&")
    : "";
  const res = await fetch(path + qs, { headers: activeUserHeader() });
  const json = await res.json();
  if (!res.ok) throw new ApiError(json?.error ?? { code: "NETWORK", message: res.statusText }, res.status);
  return { data: json.data ?? [], nextCursor: json.nextCursor, hasMore: json.hasMore ?? false };
}
