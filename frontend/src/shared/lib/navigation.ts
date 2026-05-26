// Navigation DIP port — app injects the real implementation at startup;
// widgets/features call navigate.* (downstream), never import app directly.
//
// 导航 DIP 注册点；与 shared/api/authProvider 同构：app 注入实现，
// 下层 widgets/features 调 navigate.*，解 widget→app 反向依赖。

export interface Navigator {
  openConv(id: string): void;
  openEntity(pane: string, id: string): void;
  openPane(pane: string): void;
  setActiveDocument(id: string): void;
}

const noop: Navigator = {
  openConv() {},
  openEntity() {},
  openPane() {},
  setActiveDocument() {},
};

let _nav: Navigator = noop;

export function setNavigator(n: Navigator): void {
  _nav = n;
}

export const navigate: Navigator = {
  openConv: (id) => _nav.openConv(id),
  openEntity: (pane, id) => _nav.openEntity(pane, id),
  openPane: (pane) => _nav.openPane(pane),
  setActiveDocument: (id) => _nav.setActiveDocument(id),
};
