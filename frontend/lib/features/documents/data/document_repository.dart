import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/document.dart';
import '../../../core/contract/entities/skill.dart';
import '../../../core/net/api_client.dart';
import '../../../core/runtime.dart';

/// THE data seam for the Documents ocean — every read/write for both file-like knowledge types passes
/// through here, so the whole feature swaps backends at one [documentsRepositoryProvider] override
/// (Live over the Phase-4.0 pipeline / [FixtureDocumentsRepository] for demo + tests). Two collections
/// coexist honestly: **documents** are a Notion tree (`parentId` + `position` + `path`, `doc_` ids);
/// **skills** are a flat slug-keyed set (`name` IS the identity — no id, no tree, no move). Both are
/// USER-editable markdown (not AI-only versioned entities). 文档海洋数据缝:documents 树 + skills 扁平。
abstract interface class DocumentsRepository {
  // ── documents (Notion tree) ───────────────────────────────────────────────
  /// The whole tree as flat metadata rows (NO content) — the sidebar assembles the hierarchy by
  /// `parentId` in one shot (bounded resource, unpaged). 整树扁平元数据(无 content),侧栏一趟组树。
  Future<List<DocumentNode>> getTree();

  /// One node WITH its markdown content (the editor's source of truth). 单节点带 markdown 正文。
  Future<DocumentNode> getDocument(String id);

  /// Direct children of [parentId] (null = root-level), full docs, position-ordered. 直接子节点。
  Future<List<DocumentNode>> listChildren(String? parentId);

  Future<DocumentNode> createDocument(
      {required String name, String? parentId, String content, String description, List<String> tags});

  /// Partial update (name / description / content / tags) — content PATCH IS the save (no versioning).
  /// 部分更新;存正文=PATCH content(无版本)。
  Future<DocumentNode> updateDocument(String id, Map<String, dynamic> patch);

  /// Soft-delete the whole subtree (204). 软删整子树。
  Future<void> deleteDocument(String id);

  /// Relocate / reorder (`:move`, cycle-guarded; null parentId → root, null position → append).
  Future<DocumentNode> moveDocument(String id, {String? parentId, int? position});

  /// Deep-copy a subtree (`:duplicate` → 201, new root; null parentId → sibling of the source).
  Future<DocumentNode> duplicateDocument(String id, {String? parentId});

  // ── skills (flat, name-keyed SKILL.md files) ──────────────────────────────
  /// Every skill as light metadata (NO body). 全部 skill 轻元数据(无 body)。
  Future<List<Skill>> listSkills();

  /// One skill WITH its markdown body + full frontmatter. 单 skill 带 body + frontmatter。
  Future<Skill> getSkill(String name);

  /// Create (strict conflict → 409 SKILL_NAME_CONFLICT; source forced to user). body = the create payload
  /// `{name, description, body, allowedTools, context, agent, arguments, …}`. 建(严格冲突)。
  Future<Skill> createSkill(Map<String, dynamic> body);

  /// Replace in place (PUT — no partial, no rename; name is identity). body omits `name`. 全覆盖。
  Future<Skill> replaceSkill(String name, Map<String, dynamic> body);

  Future<void> deleteSkill(String name);
}

/// The production seam over the Phase-4.0 ApiClient. Holds no state; every method is a thin
/// envelope-decode. Bounded lists (`/tree`, children, `/skills`) come back as `{data:[…]}` with no
/// cursor — [ApiClient.getPage] parses the list and yields a null cursor. 生产缝:薄信封解码。
class LiveDocumentsRepository implements DocumentsRepository {
  LiveDocumentsRepository(this._api);

  final ApiClient _api;
  static const String _docs = '/api/v1/documents';
  static const String _skills = '/api/v1/skills';

  @override
  Future<List<DocumentNode>> getTree() async =>
      (await _api.getPage('$_docs/tree', DocumentNode.fromJson)).items;
  @override
  Future<DocumentNode> getDocument(String id) =>
      _api.getEntity('$_docs/$id', DocumentNode.fromJson);
  @override
  Future<List<DocumentNode>> listChildren(String? parentId) async => (await _api.getPage(
        _docs,
        DocumentNode.fromJson,
        query: {if (parentId != null && parentId.isNotEmpty) 'parentId': parentId},
      ))
          .items;
  @override
  Future<DocumentNode> createDocument(
          {required String name,
          String? parentId,
          String content = '',
          String description = '',
          List<String> tags = const []}) =>
      _api.postEntity(_docs, DocumentNode.fromJson,
          body: {'name': name, 'parentId': ?parentId, 'content': content, 'description': description, 'tags': tags});
  @override
  Future<DocumentNode> updateDocument(String id, Map<String, dynamic> patch) =>
      _api.patchEntity('$_docs/$id', DocumentNode.fromJson, body: patch);
  @override
  Future<void> deleteDocument(String id) => _api.delete('$_docs/$id');
  @override
  Future<DocumentNode> moveDocument(String id, {String? parentId, int? position}) =>
      _api.postEntity('$_docs/$id:move', DocumentNode.fromJson,
          body: {'parentId': ?parentId, 'position': ?position});
  @override
  Future<DocumentNode> duplicateDocument(String id, {String? parentId}) =>
      _api.postEntity('$_docs/$id:duplicate', DocumentNode.fromJson, body: {'parentId': ?parentId});

  @override
  Future<List<Skill>> listSkills() async => (await _api.getPage(_skills, Skill.fromJson)).items;
  @override
  Future<Skill> getSkill(String name) => _api.getEntity('$_skills/$name', Skill.fromJson);
  @override
  Future<Skill> createSkill(Map<String, dynamic> body) =>
      _api.postEntity(_skills, Skill.fromJson, body: body);
  @override
  Future<Skill> replaceSkill(String name, Map<String, dynamic> body) =>
      _api.patchEntity('$_skills/$name', Skill.fromJson, body: body, put: true);
  @override
  Future<void> deleteSkill(String name) => _api.delete('$_skills/$name');
}

/// The Documents feature's data seam, as a provider — defaults to Live; demo / gallery / tests override
/// THIS ONE provider with a [FixtureDocumentsRepository] via ProviderScope. 单点切换后端。
final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  return LiveDocumentsRepository(ref.watch(apiClientProvider));
});
