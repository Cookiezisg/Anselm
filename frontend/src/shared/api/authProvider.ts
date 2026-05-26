// DIP registration points for auth identity. httpClient and sse share
// these — one provider per process, injected by app on startup.
//
// DIP 注册点；httpClient 和 sse 共用同一份，由 app 启动时注入真实 provider。
// 默认 provider 返回 null（不调 settings），app 未注入前 _onAuthFailure 是
// noop。阶段4a.5 注入 session store 后 settings 引用消失。

let _userIdProvider: () => string | null = () => null;
let _onAuthFailure: () => void = () => {};

export function setUserIdProvider(fn: () => string | null): void {
  _userIdProvider = fn;
}

export function setOnAuthFailure(fn: () => void): void {
  _onAuthFailure = fn;
}

export function getUserId(): string | null {
  return _userIdProvider();
}

export function notifyAuthFailure(): void {
  _onAuthFailure();
}
