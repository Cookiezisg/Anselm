import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/document.dart';
import '../../../core/contract/entities/relation.dart';
import '../../../core/contract/entities/skill.dart';
import '../../../core/contract/mcp.dart';
import '../../../core/router/navigation.dart';
import '../data/document_repository.dart';
import '../model/doc_outline.dart';

/// The Documents ocean's server-state, over the [documentsRepositoryProvider] seam. The rail watches the
/// tree + skill lists; the center watches the selected node's full content. Selection derives ONE-WAY from
/// the URL. 文档海洋的 server-state:rail 看树+skill 列表,中心看选中节点正文;选区由 URL 单向派生。

/// The whole document tree as flat metadata (no content) — the rail assembles the hierarchy by parentId.
/// Self-refreshing: subscribes to the repository's notifications-stream lifecycle signals and refetches on
/// any `document.*` event (an AI tool edit, a write from another surface) — DEBOUNCED, because content
/// saves also emit `document.updated` (the backend fires before diffing), so continuous typing would
/// otherwise refetch the tree every autosave. Deliberately does NOT touch [openDocumentProvider]: the
/// open editor is the writer — an SSE echo of its own save must never rebuild it mid-keystroke.
///
/// 整树扁平元数据(rail 组树)。自刷新:订阅通知流生命周期信号,任何 `document.*` 事件即重取(AI 工具改/别处写)
/// ——**去抖**(正文保存也发 updated,连续打字否则每次自动存都重取树)。刻意不动 openDocumentProvider:打开的
/// 编辑器是写者,自己保存的 SSE 回声绝不能把它中途重建(丢光标)。
final documentTreeProvider =
    AsyncNotifierProvider<DocumentTreeList, List<DocumentNode>>(
      DocumentTreeList.new,
    );

class DocumentTreeList extends AsyncNotifier<List<DocumentNode>> {
  Timer? _debounce;

  @override
  Future<List<DocumentNode>> build() {
    final repo = ref.watch(documentsRepositoryProvider);
    final sub = repo.lifecycleSignals().listen((domain) {
      if (domain != 'document') return;
      _debounce?.cancel();
      // 批7 立法1 豁免锚:state 层树刷新防抖。exempt: state-layer refresh debounce.
      _debounce = Timer(
        const Duration(milliseconds: 400),
        () => ref.invalidateSelf(),
      );
    });
    ref.onDispose(() {
      _debounce?.cancel();
      sub.cancel();
    });
    return repo.getTree();
  }
}

/// Every skill as light metadata (no body). Same self-refresh, keyed on `skill.*`. 全部 skill;同款自刷新。
final skillListProvider = AsyncNotifierProvider<SkillList, List<Skill>>(
  SkillList.new,
);

class SkillList extends AsyncNotifier<List<Skill>> {
  Timer? _debounce;

  @override
  Future<List<Skill>> build() {
    final repo = ref.watch(documentsRepositoryProvider);
    final sub = repo.lifecycleSignals().listen((domain) {
      if (domain != 'skill') return;
      _debounce?.cancel();
      _debounce = Timer(
        const Duration(milliseconds: 400),
        () => ref.invalidateSelf(),
      );
    });
    ref.onDispose(() {
      _debounce?.cancel();
      sub.cancel();
    });
    return repo.listSkills();
  }
}

/// A selected navigator node — a document (by `doc_` id) or a skill (by slug name). `isSkill` disambiguates
/// which collection [id] indexes. 选中的导航节点:document(doc_ id)或 skill(slug 名);isSkill 消歧。
typedef DocSelection = ({bool isSkill, String id});

/// The current selection — a READ-ONLY shim derived ONE-WAY from the URL (mirrors SelectedEntity /
/// SelectedConversation). It listens to the router delegate and re-parses `/documents/:id` and
/// `/documents/skill/:name` on every navigation; there is no select()/clear() — the ONLY way to change
/// selection is to navigate (rail rows `context.go(documentLocation(id) / skillLocation(name))`, deselect
/// = `go('/')`). URL is the single source of truth → refresh / deep-link / back-forward all survive.
/// null = nothing open → the center shows its empty state.
///
/// 当前选区——从 URL **单向**派生的只读 shim(镜像 SelectedEntity/SelectedConversation)。监听 router delegate、
/// 每次导航重解析 `/documents/:id` 与 `/documents/skill/:name`;无 select()/clear()——改选区唯一途径是导航
/// (rail 行 `context.go(...)`,取消=go('/'))。URL 是唯一真相源 → 刷新/深链/前进后退都不丢;空=中心空态。
class SelectedDocController extends Notifier<DocSelection?> {
  @override
  DocSelection? build() {
    final delegate = ref.watch(goRouterProvider).routerDelegate;
    void onRoute() => state = _parse(delegate.currentConfiguration.uri);
    delegate.addListener(onRoute);
    ref.onDispose(() => delegate.removeListener(onRoute));
    return _parse(delegate.currentConfiguration.uri);
  }

  static DocSelection? _parse(Uri uri) {
    final segs = uri.pathSegments;
    // Skills are slug-addressed under the reserved `skill` segment (3 segs); anything else 2-seg under
    // /documents is a page id. Existence isn't checkable at the route layer (same rule as entities).
    // skill 走保留段 skill(3 段、slug 寻址);其余 /documents/<id> 即页;存在性路由层不可校(同 entities)。
    if (segs.length == 3 && segs[0] == 'documents' && segs[1] == 'skill') {
      return (isSkill: true, id: segs[2]);
    }
    if (segs.length == 2 && segs[0] == 'documents') {
      return (isSkill: false, id: segs[1]);
    }
    return null;
  }
}

final selectedDocProvider =
    NotifierProvider<SelectedDocController, DocSelection?>(
      SelectedDocController.new,
    );

/// The selected skill FILE — one-way derived from the URL query `?file=<rel>` (null = the
/// manifest/default view). Same delegate-listen pattern as [SelectedDocController].
/// 当前 skill 文件选区——URL query `?file=<rel>` 单向派生(null=清单/默认视图)。
class SelectedSkillFileController extends Notifier<String?> {
  @override
  String? build() {
    final delegate = ref.watch(goRouterProvider).routerDelegate;
    void onRoute() => state = _parse(delegate.currentConfiguration.uri);
    delegate.addListener(onRoute);
    ref.onDispose(() => delegate.removeListener(onRoute));
    return _parse(delegate.currentConfiguration.uri);
  }

  static String? _parse(Uri uri) {
    final segs = uri.pathSegments;
    if (segs.length == 3 && segs[0] == 'documents' && segs[1] == 'skill') {
      final f = uri.queryParameters['file'];
      return (f == null || f.isEmpty) ? null : f;
    }
    return null;
  }
}

final selectedSkillFileProvider =
    NotifierProvider<SelectedSkillFileController, String?>(
      SelectedSkillFileController.new,
    );

/// Every bundled file of a skill (manifest included), for the file strip + inspector group.
/// skill 的捆绑文件列表(含清单),供文件条+右岛文件组。
final skillFilesProvider = FutureProvider.autoDispose
    .family<List<SkillFile>, String>(
      (ref, name) =>
          ref.watch(documentsRepositoryProvider).listSkillFiles(name),
    );

/// The manifest's dual-mode switch (rich text default / raw source) — a provider so BOTH the
/// inspector's panel menu and the ocean read/toggle one truth (WRK-076 F3). Resets per skill.
/// 清单双模开关(富文本默认/源码)——provider 使右岛菜单与海洋同读一份真相;按 skill 重置。
class SkillManifestSourceMode extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void reset() => state = false;
}

final skillManifestSourceModeProvider =
    NotifierProvider<SkillManifestSourceMode, bool>(
      SkillManifestSourceMode.new,
    );

/// The skill's equip bindings (fn_/hd_ entities its allowed-tools reference), display names
/// hydrated from the relation edges — the file tree's «绑定» section. skill 的 equip 绑定。
final skillBindingsProvider = FutureProvider.autoDispose
    .family<List<EntityRelation>, String>(
      (ref, name) =>
          ref.watch(documentsRepositoryProvider).listSkillBindings(name),
    );

/// The authorizable builtin-tool catalog (`GET /tools`) — the allowed-tools picker's BUILTIN
/// candidate group. Bounded system-fixed set; autoDispose (fetched when a picker opens, dropped
/// after). 可授权内置工具目录:选择器内置候选组(有界固定集,开选择器时取、关后弃)。
final toolCatalogProvider =
    FutureProvider.autoDispose<List<SkillToolDescriptor>>(
      (ref) => ref.watch(documentsRepositoryProvider).listToolCatalog(),
    );

/// Installed MCP servers + their live tools (`GET /mcp-servers`) — the picker's MCP candidate group.
/// autoDispose. 已装 MCP server + 工具:选择器 MCP 候选组。
final mcpServersForToolsProvider =
    FutureProvider.autoDispose<List<McpServerStatus>>(
      (ref) => ref.watch(documentsRepositoryProvider).listMcpServers(),
    );

/// One bundled file's RAW bytes (image/font previews need bytes, not text). 单捆绑文件裸字节。
final skillFileBytesProvider = FutureProvider.autoDispose
    .family<List<int>, ({String name, String path})>(
      (ref, key) => ref
          .watch(documentsRepositoryProvider)
          .readSkillFile(key.name, key.path),
    );

/// One bundled file's TEXT content (lenient decode — the editor surface; binaries render a
/// read-only note instead of going through here). 单捆绑文件文本内容(宽容解码)。
final skillFileTextProvider = FutureProvider.autoDispose
    .family<String, ({String name, String path})>(
      (ref, key) async => utf8.decode(
        await ref
            .watch(documentsRepositoryProvider)
            .readSkillFile(key.name, key.path),
        allowMalformed: true,
      ),
    );

/// The id of a document the rail JUST created via the ACTIVE «+ New page / row +» path — the ocean
/// autofocuses that document's title (select-all) once on mount, then clears this. Only the active-create
/// path sets it; the passive draft-landing path focuses the body naturally (the user just starts typing).
/// A modern [Notifier] (NOT the legacy StateProvider — project stance, runtime.dart). rail 主动新建的 doc id:
/// 海洋挂载时自动聚焦其标题(全选)一次后清空;仅主动新建设置它(被动草稿自然聚焦正文)。用现代 Notifier。
class FocusNewDocTitle extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}

final focusNewDocTitleProvider = NotifierProvider<FocusNewDocTitle, String?>(
  FocusNewDocTitle.new,
);

/// The id of the just-created draft the PASSIVE landing editor has ADOPTED — set the instant the draft
/// POSTs its first edit. While `selectedDocProvider.id == this`, the ocean keeps the SAME draft editor
/// mounted instead of handing off to a fresh `_DocEditView`, so the create is seamless (no remount, no
/// cursor/content loss). Cleared when selection moves to any other node. 被动草稿转正 id:草稿首次编辑即 POST
/// 后置此;当选区仍是它时,海洋保持草稿编辑器不换手(无重挂、光标/内容不丢);选区他移即清。
class AdoptedDraftDoc extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}

final adoptedDraftDocProvider = NotifierProvider<AdoptedDraftDoc, String?>(
  AdoptedDraftDoc.new,
);

/// The route location for a document page — the rail navigates here to select. Mirrors entityLocation.
/// 文档页的路由位置——rail 导航至此以选中。镜像 entityLocation。
String documentLocation(String id) => '/documents/$id';

/// The route location for a skill (slug-addressed — the guard regex `^[a-z0-9][a-z0-9_-]{0,63}$` is
/// URL-safe by construction). skill 的路由位置(slug 寻址,守卫正则天然 URL 安全)。
String skillLocation(String name) => '/documents/skill/$name';

/// The route location for one bundled file inside a skill (query-addressed — a multi-segment
/// rel path needs no new route). skill 内单文件路由位置(query 寻址,多段相对路径零新路由)。
String skillFileLocation(String name, String rel) =>
    "/documents/skill/$name?file=${Uri.encodeQueryComponent(rel)}";

/// The open document WITH content (fetched on select; autoDispose releases it on deselect). 打开的文档(带正文)。
final openDocumentProvider = FutureProvider.autoDispose
    .family<DocumentNode, String>(
      (ref, id) => ref.watch(documentsRepositoryProvider).getDocument(id),
    );

/// The open skill WITH body + frontmatter (fetched on select). 打开的 skill(带 body + frontmatter)。
final openSkillProvider = FutureProvider.autoDispose.family<Skill, String>(
  (ref, name) => ref.watch(documentsRepositoryProvider).getSkill(name),
);

/// The LIVE outline of the open document/skill — the inspector's table of contents. FED by the editor
/// view (seeded from the loaded markdown, re-fed on every edit) rather than derived from a provider: the
/// open content provider is deliberately never invalidated mid-edit (cursor), so it can't be the source.
/// 打开文档的**活**大纲(右岛目录)。由编辑视图喂(载入播种 + 每次编辑重喂)——打开内容 provider 编辑中刻意
/// 不失效(保光标),当不了源。
final docOutlineProvider =
    NotifierProvider<DocOutlineController, List<DocOutlineEntry>>(
      DocOutlineController.new,
    );

class DocOutlineController extends Notifier<List<DocOutlineEntry>> {
  @override
  List<DocOutlineEntry> build() => const [];

  void set(List<DocOutlineEntry> entries) => state = entries;
  void clear() => state = const [];
}

/// The outline entry the CENTER viewport is currently reading — the LAST heading scrolled up past the
/// head band (null = still above the first heading). Fed by the edit view's scroll listener; the
/// inspector's outline highlights it live. 中心视口正在读的大纲项——最后一个滚过头带的标题(null=还在首个
/// 标题之上)。编辑视图滚动监听喂;右岛大纲实时高亮。
final docOutlineActiveProvider =
    NotifierProvider<DocOutlineActiveController, int?>(
      DocOutlineActiveController.new,
    );

class DocOutlineActiveController extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? index) {
    if (state != index) state = index;
  }
}

/// An outline-row tap → "scroll the editor to the N-th heading". A (tick, index) pair so tapping the SAME
/// heading twice still re-fires (state must change to notify). 大纲点击意图:(tick,index) 对,重复点同项也触发。
final outlineJumpProvider =
    NotifierProvider<OutlineJumpController, ({int tick, int index})?>(
      OutlineJumpController.new,
    );

class OutlineJumpController extends Notifier<({int tick, int index})?> {
  @override
  ({int tick, int index})? build() => null;

  void jump(int index) => state = (tick: (state?.tick ?? 0) + 1, index: index);
}

/// The open document's BACKLINKS — incoming `link` edges (whose bodies `[[id]]`-wikilink it), names
/// hydrated server-side. Watches the tree so a linker's rename/delete refreshes the panel (link edges
/// re-sync on body writes, which also signal the tree). 打开文档的 backlinks(入向 link 边);watch 树使
/// 链接方改名/删除后面板跟新(边随正文写 re-sync,正文写也会信号树)。
final backlinksProvider = FutureProvider.autoDispose
    .family<List<EntityRelation>, String>((ref, id) async {
      ref.watch(documentTreeProvider); // refresh alongside the tree 随树刷新
      return ref.watch(documentsRepositoryProvider).listBacklinks(id);
    });
