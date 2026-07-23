import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/document.dart';
import '../../../core/contract/entities/relation.dart';
import '../../../core/contract/entities/skill.dart';
import '../../../core/contract/mcp.dart';
import '../../../core/net/api_client.dart';
import '../../../core/runtime.dart';
import '../../../core/sse/frame.dart';
import '../../../core/sse/sse_gateway.dart';

/// THE data seam for the Documents ocean — every read/write for both file-like knowledge types passes
/// through here, so the whole feature swaps backends at one [libraryRepositoryProvider] override
/// (Live over the Phase-4.0 pipeline / [FixtureLibraryRepository] for demo + tests). Two collections
/// coexist honestly: **documents** are a Notion tree (`parentId` + `position` + `path`, `doc_` ids);
/// **skills** are a flat slug-keyed set (`name` IS the identity — no id, no tree, no move). Both are
/// USER-editable markdown (not AI-only versioned entities). 文档海洋数据缝:documents 树 + skills 扁平。
abstract interface class LibraryRepository {
  // ── documents (Notion tree) ───────────────────────────────────────────────
  /// The whole tree as flat metadata rows (NO content) — the sidebar assembles the hierarchy by
  /// `parentId` in one shot (bounded resource, unpaged). 整树扁平元数据(无 content),侧栏一趟组树。
  Future<List<DocumentNode>> getTree();

  /// One node WITH its markdown content (the editor's source of truth). 单节点带 markdown 正文。
  Future<DocumentNode> getDocument(String id);

  /// Direct children of [parentId] (null = root-level), full docs, position-ordered. 直接子节点。
  Future<List<DocumentNode>> listChildren(String? parentId);

  Future<DocumentNode> createDocument({
    required String name,
    String? parentId,
    String content,
    String description,
    List<String> tags,
  });

  /// Partial update (name / description / content / tags) — content PATCH IS the save (no versioning).
  /// 部分更新;存正文=PATCH content(无版本)。
  Future<DocumentNode> updateDocument(String id, Map<String, dynamic> patch);

  /// Soft-delete the whole subtree (204). 软删整子树。
  Future<void> deleteDocument(String id);

  /// Relocate / reorder (`:move`, cycle-guarded; null parentId → root, null position → append).
  Future<DocumentNode> moveDocument(
    String id, {
    String? parentId,
    int? position,
  });

  /// Deep-copy a subtree (`:duplicate` → 201, new root; null parentId → sibling of the source).
  Future<DocumentNode> duplicateDocument(String id, {String? parentId});

  // ── skills (flat, name-keyed SKILL.md files) ──────────────────────────────
  /// Every skill as light metadata (NO body). 全部 skill 轻元数据(无 body)。
  Future<List<Skill>> listSkills();

  /// One skill WITH its markdown body + full frontmatter. 单 skill 带 body + frontmatter。
  Future<Skill> getSkill(String name);

  // ── skill files（文件即真相面,WRK-076 B1/F1:裸字节双向）──────────────────
  /// Every bundled file (manifest included), path-sorted. 全部捆绑文件(含清单)。
  Future<List<SkillFile>> listSkillFiles(String name);

  /// One bundled file's raw bytes. 单文件裸字节。
  Future<List<int>> readSkillFile(String name, String path);

  /// Write one bundled file verbatim (manifest path = validated raw replace). 裸字节写(清单=带校验整替)。
  Future<void> writeSkillFile(String name, String path, List<int> bytes);

  /// Delete one bundled file (manifest refused by the backend). 删单文件(清单后端拒)。
  Future<void> deleteSkillFile(String name, String path);

  // ── skill install（安装通道,WRK-076 B4/F2）─────────────────────────────────
  /// Preview a source's candidates without touching disk. 预览来源候选,不落盘。
  Future<List<SkillInstallPreview>> inspectSkillSource(String source);

  /// Install picked candidates (names empty = all installable). 安装选中候选。
  Future<SkillInstallResult> installSkills(
    String source, {
    List<String> names,
    bool force,
  });

  /// Re-fetch an installed skill from its recorded source. 按来源重拉。
  Future<Skill> updateInstalledSkill(String name, {bool force});

  /// Open the trust gate for an installed skill's allowed-tools. 打开信任门。
  Future<Skill> approveSkillTools(String name);

  /// The skill's equip edges — entities its allowed-tools bind (fn_/hd_ ids), with display
  /// names hydrated. The file tree's «绑定» section. skill 的 equip 出边(绑定实体,带显示名)。
  Future<List<EntityRelation>> listSkillBindings(String name);

  /// The authorizable builtin-tool catalog (`GET /tools`) — the allowed-tools picker's BUILTIN
  /// candidate group (name + one-line summary). 可授权内置工具目录:选择器的内置候选组。
  Future<List<SkillToolDescriptor>> listToolCatalog();

  /// Installed MCP servers with their live tools (`GET /mcp-servers`) — the picker's MCP candidate
  /// group (a tool authorizes as `mcp__<server>__<tool>`). 已装 MCP server + 工具:选择器 MCP 候选组。
  Future<List<McpServerStatus>> listMcpServers();

  /// Create (strict conflict → 409 SKILL_NAME_CONFLICT; source forced to user). body = the create payload
  /// `{name, description, body, allowedTools, context, agent, arguments, …}`. 建(严格冲突)。
  Future<Skill> createSkill(Map<String, dynamic> body);

  /// Replace in place (PUT — no partial, no rename; name is identity). body omits `name`. 全覆盖。
  Future<Skill> replaceSkill(String name, Map<String, dynamic> body);

  Future<void> deleteSkill(String name);

  // ── graph 关系图 ──────────────────────────────────────────────────────────
  /// Who links to this document: incoming `link` edges (bodies whose `[[id]]` wikilinks target it), names
  /// hydrated fresh server-side. 谁链到此文档:入向 link 边(wikilink 指它的正文),名服务端新鲜 hydrate。
  Future<List<EntityRelation>> listBacklinks(String documentId);

  // ── realtime 实时 ─────────────────────────────────────────────────────────
  /// Lifecycle signals off the notifications stream — one per durable `document.*` / `skill.*`
  /// notification, carrying the domain, the action verb and the row id (documentId / skill name; ''
  /// when the payload has none). The DB row is the truth — the signal only says WHERE to look again,
  /// which lets the list providers patch ONE row in place on `updated` (the autosave-echo hot path)
  /// instead of refetching the whole tree. 通知流生命周期信号:每条 durable `document.*`/`skill.*`
  /// 帧一发,携域+动作+行 id(payload 无 id 则 '')。DB 行是真相——信号只说去哪看,列表 provider 据此
  /// 在 `updated`(自动存回声热路径)就地补一行,而非整树重取。
  Stream<LibrarySignal> lifecycleSignals();
}

/// One library lifecycle signal: `domain` ∈ {document, skill}, `action` = the verb after the dot
/// (created/updated/deleted/moved…, open set), `id` = documentId / skill name ('' if absent).
/// 一条 library 生命周期信号:域 + 点后动词(开放集)+ 行 id(缺则空串)。
typedef LibrarySignal = ({String domain, String action, String id});

/// The production seam over the Phase-4.0 ApiClient. Holds no state; every method is a thin
/// envelope-decode. Bounded lists (`/tree`, children, `/skills`) come back as `{data:[…]}` with no
/// cursor — [ApiClient.getPage] parses the list and yields a null cursor. 生产缝:薄信封解码。
class LiveLibraryRepository implements LibraryRepository {
  LiveLibraryRepository(this._api, {SseGateway? sse}) : _sse = sse;

  final ApiClient _api;
  final SseGateway? _sse;
  static const String _docs = '/api/v1/documents';
  static const String _skills = '/api/v1/skills';
  static const String _tools = '/api/v1/tools';
  static const String _mcpServers = '/api/v1/mcp-servers';

  @override
  Future<List<DocumentNode>> getTree() async =>
      (await _api.getPage('$_docs/tree', DocumentNode.fromJson)).items;
  @override
  Future<DocumentNode> getDocument(String id) =>
      _api.getEntity('$_docs/$id', DocumentNode.fromJson);
  @override
  Future<List<DocumentNode>> listChildren(String? parentId) async =>
      (await _api.getPage(
        _docs,
        DocumentNode.fromJson,
        query: {
          if (parentId != null && parentId.isNotEmpty) 'parentId': parentId,
        },
      )).items;
  @override
  Future<DocumentNode> createDocument({
    required String name,
    String? parentId,
    String content = '',
    String description = '',
    List<String> tags = const [],
  }) => _api.postEntity(
    _docs,
    DocumentNode.fromJson,
    body: {
      'name': name,
      'parentId': ?parentId,
      'content': content,
      'description': description,
      'tags': tags,
    },
  );
  @override
  Future<DocumentNode> updateDocument(String id, Map<String, dynamic> patch) =>
      _api.patchEntity('$_docs/$id', DocumentNode.fromJson, body: patch);
  @override
  Future<void> deleteDocument(String id) => _api.delete('$_docs/$id');
  @override
  Future<DocumentNode> moveDocument(
    String id, {
    String? parentId,
    int? position,
  }) => _api.postEntity(
    '$_docs/$id:move',
    DocumentNode.fromJson,
    body: {'parentId': ?parentId, 'position': ?position},
  );
  @override
  Future<DocumentNode> duplicateDocument(String id, {String? parentId}) =>
      _api.postEntity(
        '$_docs/$id:duplicate',
        DocumentNode.fromJson,
        body: {'parentId': ?parentId},
      );

  @override
  Future<List<Skill>> listSkills() async =>
      (await _api.getPage(_skills, Skill.fromJson)).items;
  @override
  Future<Skill> getSkill(String name) =>
      _api.getEntity('$_skills/$name', Skill.fromJson);
  @override
  Future<Skill> createSkill(Map<String, dynamic> body) =>
      _api.postEntity(_skills, Skill.fromJson, body: body);
  @override
  Future<Skill> replaceSkill(String name, Map<String, dynamic> body) =>
      _api.patchEntity('$_skills/$name', Skill.fromJson, body: body, put: true);
  @override
  Future<void> deleteSkill(String name) => _api.delete('$_skills/$name');

  @override
  Future<List<SkillFile>> listSkillFiles(String name) async =>
      (await _api.getPage('$_skills/$name/files', SkillFile.fromJson)).items;

  @override
  Future<List<int>> readSkillFile(String name, String path) =>
      _api.getBytes('$_skills/$name/files/$path');

  @override
  Future<void> writeSkillFile(String name, String path, List<int> bytes) =>
      _api.putBytes('$_skills/$name/files/$path', bytes);

  @override
  Future<void> deleteSkillFile(String name, String path) =>
      _api.delete('$_skills/$name/files/$path');

  @override
  Future<List<SkillInstallPreview>> inspectSkillSource(String source) async =>
      (await _api.postPage(
        '$_skills:inspect-source',
        SkillInstallPreview.fromJson,
        body: {'source': source},
      )).items;

  @override
  Future<SkillInstallResult> installSkills(
    String source, {
    List<String> names = const [],
    bool force = false,
  }) => _api.postEntity(
    '$_skills:install',
    SkillInstallResult.fromJson,
    body: {'source': source, 'names': names, 'force': force},
  );

  @override
  Future<Skill> updateInstalledSkill(String name, {bool force = false}) =>
      _api.postEntity(
        '$_skills/$name:update',
        Skill.fromJson,
        body: {'force': force},
      );

  @override
  Future<Skill> approveSkillTools(String name) =>
      _api.postEntity('$_skills/$name:approve-tools', Skill.fromJson);

  @override
  Future<List<EntityRelation>> listSkillBindings(String name) async =>
      (await _api.getPage(
        '/api/v1/relations',
        EntityRelation.fromJson,
        query: {
          'fromKind': 'skill',
          'fromId': name,
          'kind': 'equip',
          'limit': 100,
        },
      )).items;

  @override
  Future<List<SkillToolDescriptor>> listToolCatalog() async =>
      (await _api.getPage(_tools, SkillToolDescriptor.fromJson)).items;

  @override
  Future<List<McpServerStatus>> listMcpServers() async =>
      (await _api.getPage(_mcpServers, McpServerStatus.fromJson)).items;

  @override
  Future<List<EntityRelation>> listBacklinks(
    String documentId,
  ) async => (await _api.getPage(
    '/api/v1/relations',
    EntityRelation.fromJson,
    // The to-pair must be given together (REL_INCOMPLETE_FILTER); kind=link narrows to wikilinks
    // (drop it and equip mounts would show too). Explicit 100 cap — plenty for a panel list.
    // to 对须成对给;kind=link 只取 wikilink(不带会混进 equip 挂载);显式 100 上限。
    query: {
      'toKind': 'document',
      'toId': documentId,
      'kind': 'link',
      'limit': 100,
    },
  )).items;

  @override
  Stream<LibrarySignal> lifecycleSignals() {
    final sse = _sse;
    if (sse == null) return const Stream.empty();
    // The notifications stream is low-frequency and shares one scope (scope.kind="notification"), so a
    // `.where` over the raw feed is correct here (same rationale as the entities repository). Only durable
    // frames count (seq>0 — ephemeral frames never signal a library change). The domain+action live in
    // `node.type` ("document.updated"); the row id in the payload (`documentId` / `name` — the two
    // domains' emit contracts, app/document + app/skill). notifications 低频且共用单 scope,对原始
    // feed `.where` 正确(同 entities 仓);只认 durable;域.动作在 node.type,行 id 在 payload
    // (documentId/name,两域的 emit 契约)。
    return sse
        .rawStream(StreamName.notifications)
        .where((env) => env.durable)
        .map((env) {
          final frame = env.frame;
          if (frame is! FrameSignal) return null;
          final type = frame.node.type;
          final dot = type.indexOf('.');
          if (dot <= 0) return null;
          final domain = type.substring(0, dot);
          if (domain != 'document' && domain != 'skill') return null;
          final content = frame.node.content;
          final idField = domain == 'document' ? 'documentId' : 'name';
          return (
            domain: domain,
            action: type.substring(dot + 1),
            id: content?[idField] as String? ?? '',
          );
        })
        .where((s) => s != null)
        .cast<LibrarySignal>();
  }
}

/// The Documents feature's data seam, as a provider — defaults to Live; demo / gallery / tests override
/// THIS ONE provider with a [FixtureLibraryRepository] via ProviderScope. 单点切换后端。
final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LiveLibraryRepository(
    ref.watch(apiClientProvider),
    sse: ref.watch(sseGatewayProvider),
  );
});
