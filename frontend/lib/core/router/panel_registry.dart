/// The PANEL-NAV REGISTRY (WRK-056 #8) — the single source of truth for whether an entity kind has a
/// navigable panel, and the deep-link location for one. A tool-card hit row / ref pill consults
/// [hasPanelFor] to decide if it is tappable: a kind with NO panel gets `onTap: null` (an inert row —
/// NEVER a dead link that navigates nowhere or lands on a "?" page). [panelLocationFor] returns the
/// go_router location a handler passes to `context.go`.
///
/// Why a core seam (not a feature helper): the navigable kinds live in three different feature layers
/// (entities / chat / documents), and `features/*` must not import each other (ADR 0004 «features 互不
/// 依赖»). So this encodes — in one cross-feature place — the SAME route patterns that:
///   • `app/router.dart` DECLARES (`/entities/:kind/:id`, `/chat/:id`, `/documents/:id`,
///     `/documents/skill/:name`), and
///   • the per-feature builders PRODUCE (`entityLocation` / `conversationLocation` / `documentLocation`
///     / `skillLocation`).
/// Those remain the per-feature truth; this is the read-model tool cards share. Kept in lock-step with
/// them — `panel_registry_test.dart` pins the full navigable set so a route change that isn't mirrored
/// here fails the gate. Design rule (blueprint §F07.8): navigability is decided at RUNTIME by this
/// registry, never a hand-maintained "already-built panels" list — a panel landing flips its links live.
///
/// 面板能力注册表(#8):某 kind 有无可导航面板 + deep-link 位置的单一事实源。命中行/ref pill 据 [hasPanelFor]
/// 决定可否点击——无面板 kind 传 `onTap:null`(惰性行,绝不放死链)。跨 feature 缝(features 互不依赖),故在此
/// 一处编码 app/router.dart 声明、各 feature builder 产出的同一套路由式;与之锁步,panel_registry_test 钉全集。
library;

/// The go_router location for a `{kind, id}` intent, or `null` if [wireKind] has no navigable panel.
/// [wireKind] is the backend EntityKind wire string (lowercase; `document` not `doc` — the `doc` demo
/// alias is tolerated). For `skill`, [id] IS the slug/name (skills are slug-addressed, no id).
/// `{kind,id}` intent 的 go_router 位置;无面板 kind → null。skill 的 id 即 slug。
String? panelLocationFor(String wireKind, String id) {
  switch (wireKind.toLowerCase()) {
    // The seven entities-rail kinds → /entities/<kind>/<id> (mirrors entityLocation). 七个实体 rail kind。
    case 'function':
    case 'handler':
    case 'agent':
    case 'workflow':
    case 'control':
    case 'approval':
    case 'trigger':
      return '/entities/${wireKind.toLowerCase()}/$id';
    // conversation → chat ocean (mirrors conversationLocation). 对话 → chat 海洋。
    case 'conversation':
      return '/chat/$id';
    // document → documents ocean (mirrors documentLocation); `doc` = demo alias for the same entity.
    // 文档 → documents 海洋;`doc` 是 demo 别名。
    case 'document':
    case 'doc':
      return '/documents/$id';
    // skill → documents ocean, slug-addressed (mirrors skillLocation; the "id" IS the name). 技能:slug 寻址。
    case 'skill':
      return '/documents/skill/$id';
    // No panel exists: mcp / memory / relation / block / message / node / firing / … — an inert row,
    // never a dead link. Links light up automatically the day such a panel lands. 无面板→惰性,面板落地即活。
    default:
      return null;
  }
}

/// Whether [wireKind] has a navigable panel — a tool-card row / ref pill is tappable iff this is true.
/// 某 kind 有无可导航面板(命中行/ref pill 可点当且仅当为真)。
bool hasPanelFor(String wireKind) => panelLocationFor(wireKind, '_') != null;
