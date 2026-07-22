import '../../../core/contract/entities/document.dart';
import '../../../core/contract/entities/relation.dart';
import 'dart:convert';

import '../../../core/contract/entities/skill.dart';
import '../../../core/contract/mcp.dart';
import 'document_repository.dart';

/// An in-memory, scriptable [DocumentsRepository] for `make demo` (zero backend) + widget tests. Holds a
/// flat node list (the tree is derived by `parentId`, exactly like the Live `/tree`) + a flat skill list.
/// Writes mutate in place so a demo/test can create/rename/move/delete and see the rail react. Not used by
/// the live app. 内存可脚本 fixture:扁平节点列表(按 parentId 组树)+ skill 列表;写就地改。
class FixtureDocumentsRepository implements DocumentsRepository {
  FixtureDocumentsRepository({
    List<DocumentNode>? documents,
    List<Skill>? skills,
    Map<String, Map<String, String>>? skillFiles,
  }) : _docs = List.of(documents ?? const []),
       _skills = List.of(skills ?? const []),
       _skillFiles = {
         for (final e in (skillFiles ?? const {}).entries)
           e.key: Map.of(e.value),
       };

  final List<DocumentNode> _docs;
  final List<Skill> _skills;

  /// skill → (rel path → text content)。demo 的 folder skill 文件面（清单不在此表——它由
  /// [Skill.body]+frontmatter 派生渲染,与真后端「清单也是文件」的差异是 demo 已知取舍）。
  final Map<String, Map<String, String>> _skillFiles;
  int _seq = 0;

  // A deterministic stamp for fixture-created rows (tests don't assert wall-clock). fixture 建行的确定性时刻。
  static final DateTime _t = DateTime.utc(2026, 7, 5, 9);

  String _newId() => 'doc_fixture${(_seq++).toString().padLeft(10, '0')}';

  DocumentNode _byId(String id) => _docs.firstWhere((d) => d.id == id);

  // ── documents ──────────────────────────────────────────────────────────────
  // Mirror the Live `/tree` projection: metadata only (content stripped) + a hasContent bool (≡ backend
  // size_bytes>0) that drives the rail's empty-page vs written-doc icon (B4). 镜像 Live /tree:去正文 +
  // hasContent(≡ size_bytes>0),驱动 rail 空页/已写页 icon。
  @override
  Future<List<DocumentNode>> getTree() async => [
    for (final d in _docs)
      d.copyWith(content: '', hasContent: d.content.isNotEmpty),
  ];
  @override
  Future<DocumentNode> getDocument(String id) async => _byId(id);
  @override
  Future<List<DocumentNode>> listChildren(String? parentId) async {
    final kids =
        _docs
            .where(
              (d) =>
                  d.parentId == (parentId?.isEmpty == true ? null : parentId),
            )
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position));
    return kids;
  }

  @override
  Future<DocumentNode> createDocument({
    required String name,
    String? parentId,
    String content = '',
    String description = '',
    List<String> tags = const [],
  }) async {
    final siblings = _docs.where((d) => d.parentId == parentId);
    final node = DocumentNode(
      id: _newId(),
      parentId: parentId,
      name: name,
      description: description,
      content: content,
      tags: tags,
      position: siblings.length,
      path: '${parentId == null ? '' : _byId(parentId).path}/$name',
      sizeBytes: content.length,
      createdAt: _t,
      updatedAt: _t,
    );
    _docs.add(node);
    return node;
  }

  @override
  Future<DocumentNode> updateDocument(
    String id,
    Map<String, dynamic> patch,
  ) async {
    final i = _docs.indexWhere((d) => d.id == id);
    final cur = _docs[i];
    final next = cur.copyWith(
      name: patch['name'] as String? ?? cur.name,
      description: patch['description'] as String? ?? cur.description,
      content: patch['content'] as String? ?? cur.content,
      tags: (patch['tags'] as List?)?.cast<String>() ?? cur.tags,
      sizeBytes: patch['content'] is String
          ? (patch['content'] as String).length
          : cur.sizeBytes,
      updatedAt: _t,
    );
    _docs[i] = next;
    // A rename shifts the materialized path of the node + its whole subtree (backend cascades). 改名级联 path。
    if (patch['name'] is String) _recomputePaths(id);
    return _docs[i];
  }

  /// Recompute the materialized `path` of [id] + its subtree from the current parent chain — the backend
  /// cascades paths on rename/move; a stale fixture path would lie to path-reading UI. 按当前父链重算子树 path。
  void _recomputePaths(String id) {
    final i = _docs.indexWhere((d) => d.id == id);
    if (i < 0) return;
    final d = _docs[i];
    final parentPath = d.parentId == null ? '' : _byId(d.parentId!).path;
    _docs[i] = d.copyWith(path: '$parentPath/${d.name}');
    for (final child in [..._docs.where((c) => c.parentId == id)]) {
      _recomputePaths(child.id);
    }
  }

  @override
  Future<void> deleteDocument(String id) async {
    // Remove the node + its whole subtree (descendants by parentId chain). 删节点 + 整子树。
    final doomed = <String>{id};
    bool grew = true;
    while (grew) {
      grew = false;
      for (final d in _docs) {
        if (d.parentId != null &&
            doomed.contains(d.parentId) &&
            doomed.add(d.id)) {
          grew = true;
        }
      }
    }
    _docs.removeWhere((d) => doomed.contains(d.id));
  }

  @override
  Future<DocumentNode> moveDocument(
    String id, {
    String? parentId,
    int? position,
  }) async {
    final i = _docs.indexWhere((d) => d.id == id);
    // Mirror the backend: position omitted → APPEND among the new parent's children (not "keep the old
    // number", which is meaningless under a different parent); an explicit position shifts the siblings it
    // lands among (stable insert-at-index). 镜像后端:省略=追加新父末尾;显式=按 index 插入、让位兄弟顺移。
    final siblings = [
      for (final d in _docs)
        if (d.parentId == parentId && d.id != id) d,
    ]..sort((a, b) => a.position.compareTo(b.position));
    final at = position == null || position < 0 || position > siblings.length
        ? siblings.length
        : position;
    for (var s = 0; s < siblings.length; s++) {
      final want = s < at ? s : s + 1;
      if (siblings[s].position != want) {
        _docs[_docs.indexWhere((d) => d.id == siblings[s].id)] = siblings[s]
            .copyWith(position: want);
      }
    }
    _docs[i] = _docs[i].copyWith(
      parentId: parentId,
      position: at,
      updatedAt: _t,
    );
    // Reparenting shifts the whole subtree's materialized paths (backend cascades). 改父级联子树 path。
    _recomputePaths(id);
    return _docs[_docs.indexWhere((d) => d.id == id)];
  }

  @override
  Future<DocumentNode> duplicateDocument(String id, {String? parentId}) async {
    final src = _byId(id);
    final copy = src.copyWith(
      id: _newId(),
      name: '${src.name} copy',
      parentId: parentId ?? src.parentId,
      updatedAt: _t,
    );
    _docs.add(copy);
    return copy;
  }

  // ── skills ───────────────────────────────────────────────────────────────
  @override
  Future<List<Skill>> listSkills() async => [
    for (final s in _skills) s.copyWith(body: ''),
  ];
  @override
  Future<Skill> getSkill(String name) async =>
      _skills.firstWhere((s) => s.name == name);
  @override
  Future<Skill> createSkill(Map<String, dynamic> body) async {
    final s = Skill(
      name: body['name'] as String? ?? '',
      description: body['description'] as String? ?? '',
      source: kSkillSourceUser,
      context: body['context'] as String? ?? kSkillContextInline,
      body: body['body'] as String? ?? '',
      updatedAt: _t,
    );
    _skills.add(s);
    return s;
  }

  @override
  Future<Skill> replaceSkill(String name, Map<String, dynamic> body) async {
    // FULL-replace, mirroring the backend PUT: omitted fields RESET to their zero values, and the
    // frontmatter carries every CONFIG field — an agent/tools/arguments/toggle edit must actually land
    // (the old partial copy silently dropped them). 全覆盖照后端 PUT:缺省字段归零;frontmatter 带全部配置
    // 字段(agent/工具/参数/开关的编辑必须真落——旧的部分拷贝会静默丢掉)。
    final i = _skills.indexWhere((s) => s.name == name);
    final cur = _skills[i];
    final desc = body['description'] as String? ?? '';
    final context = body['context'] as String? ?? '';
    final next = cur.copyWith(
      description: desc,
      context: context,
      body: body['body'] as String? ?? '',
      frontmatter: cur.frontmatter.copyWith(
        description: desc,
        context: context,
        agent: body['agent'] as String? ?? '',
        allowedTools: [
          ...(body['allowedTools'] as List? ?? const []),
        ].cast<String>(),
        arguments: [...(body['arguments'] as List? ?? const [])].cast<String>(),
        disableModelInvocation:
            body['disableModelInvocation'] as bool? ?? false,
        userInvocable: body['userInvocable'] as bool? ?? false,
      ),
      updatedAt: _t,
    );
    _skills[i] = next;
    return next;
  }

  @override
  Future<void> deleteSkill(String name) async =>
      _skills.removeWhere((s) => s.name == name);

  // ── skill files（demo:内存文件表;清单行为 Skill 派生渲染）────────────────────
  String _renderManifest(Skill s) =>
      '---\nname: ${s.name}\ndescription: ${s.description}\n---\n${s.body}\n';

  @override
  Future<List<SkillFile>> listSkillFiles(String name) async {
    final s = await getSkill(name);
    final files = _skillFiles[name] ?? const <String, String>{};
    final out = [
      SkillFile(
        path: kSkillManifestFileName,
        size: _renderManifest(s).length,
        updatedAt: s.updatedAt,
      ),
      for (final e in files.entries)
        SkillFile(path: e.key, size: e.value.length, updatedAt: s.updatedAt),
    ]..sort((a, b) => a.path.compareTo(b.path));
    return out;
  }

  @override
  Future<List<int>> readSkillFile(String name, String path) async {
    if (path == kSkillManifestFileName) {
      return utf8.encode(_renderManifest(await getSkill(name)));
    }
    final content = _skillFiles[name]?[path];
    if (content == null) throw StateError('no such file: $path');
    return utf8.encode(content);
  }

  @override
  Future<void> writeSkillFile(String name, String path, List<int> bytes) async {
    final text = utf8.decode(bytes);
    if (path == kSkillManifestFileName) {
      // demo 清单整替:只回填 body(围栏后正文),frontmatter 简化保留。
      final i = _skills.indexWhere((s) => s.name == name);
      final parts = text.split('---');
      final body = parts.length >= 3
          ? parts.sublist(2).join('---').trim()
          : text;
      _skills[i] = _skills[i].copyWith(body: body, updatedAt: _t);
      return;
    }
    (_skillFiles[name] ??= {})[path] = text;
  }

  @override
  Future<void> deleteSkillFile(String name, String path) async {
    _skillFiles[name]?.remove(path);
  }

  // ── skill install（demo:固定假来源,一次可装两个样例 skill）───────────────────
  @override
  Future<List<SkillInstallPreview>> inspectSkillSource(String source) async => [
    SkillInstallPreview(
      name: 'demo-pdf',
      description: 'Fill and read PDF forms',
      allowedTools: const ['run_function'],
      fileCount: 3,
      totalBytes: 2048,
      installable: true,
      alreadyExists: _skills.any((s) => s.name == 'demo-pdf'),
    ),
    const SkillInstallPreview(
      name: 'broken-one',
      reason: 'manifest frontmatter does not parse',
      fileCount: 1,
      totalBytes: 64,
    ),
  ];

  @override
  Future<SkillInstallResult> installSkills(
    String source, {
    List<String> names = const [],
    bool force = false,
  }) async {
    if (_skills.any((s) => s.name == 'demo-pdf') && !force) {
      return const SkillInstallResult(
        skipped: {'demo-pdf': 'already exists (pass force to overwrite)'},
      );
    }
    _skills.removeWhere((s) => s.name == 'demo-pdf');
    _skills.add(
      Skill(
        name: 'demo-pdf',
        description: 'Fill and read PDF forms',
        source: kSkillSourceInstalled,
        context: kSkillContextInline,
        body: 'Use scripts/fill.py to fill forms.',
        frontmatter: const Frontmatter(
          name: 'demo-pdf',
          description: 'Fill and read PDF forms',
          allowedTools: ['run_function'],
          license: 'MIT',
        ),
        provenance: Provenance(source: source, installedAt: _t),
        updatedAt: _t,
      ),
    );
    (_skillFiles['demo-pdf'] ??= {})['scripts/fill.py'] = "print('fill')";
    return const SkillInstallResult(installed: ['demo-pdf']);
  }

  @override
  Future<Skill> updateInstalledSkill(String name, {bool force = false}) async =>
      getSkill(name);

  @override
  Future<List<EntityRelation>> listSkillBindings(String name) async {
    final s = await getSkill(name);
    return [
      for (final ref in s.frontmatter.allowedTools)
        if (ref.startsWith('fn_') || ref.startsWith('hd_'))
          EntityRelation(
            id: 'rel_${name}_$ref',
            kind: 'equip',
            fromKind: 'skill',
            fromId: name,
            fromName: name,
            toKind: ref.startsWith('fn_') ? 'function' : 'handler',
            toId: ref,
            toName: ref.startsWith('fn_') ? 'demo-function' : 'demo-handler',
          ),
    ];
  }

  @override
  Future<Skill> approveSkillTools(String name) async {
    final i = _skills.indexWhere((s) => s.name == name);
    final cur = _skills[i];
    _skills[i] = cur.copyWith(
      provenance: (cur.provenance ?? Provenance(installedAt: _t)).copyWith(
        toolsApproved: true,
      ),
    );
    return _skills[i];
  }

  @override
  Future<List<SkillToolDescriptor>> listToolCatalog() async => const [
    SkillToolDescriptor(name: 'Bash', summary: 'Run a shell command.'),
    SkillToolDescriptor(name: 'Edit', summary: 'Replace a span in a file.'),
    SkillToolDescriptor(name: 'Glob', summary: 'List files by glob pattern.'),
    SkillToolDescriptor(
      name: 'Grep',
      summary: 'Search file contents by regex.',
    ),
    SkillToolDescriptor(name: 'Read', summary: 'Read a file.'),
    SkillToolDescriptor(name: 'Write', summary: 'Write a file (overwrites).'),
    SkillToolDescriptor(
      name: 'activate_skill',
      summary: 'Activate a skill by name.',
    ),
    SkillToolDescriptor(
      name: 'run_function',
      summary: 'Run a function entity by id.',
    ),
  ];

  @override
  Future<List<McpServerStatus>> listMcpServers() async => const [
    McpServerStatus(
      id: 'mcp_demogithub01',
      name: 'github',
      status: 'ready',
      tools: [
        McpToolDef(name: 'create_issue'),
        McpToolDef(name: 'list_pulls'),
      ],
    ),
    McpServerStatus(
      id: 'mcp_demofs0000001',
      name: 'filesystem',
      status: 'ready',
      tools: [McpToolDef(name: 'read_file')],
    ),
  ];

  // No backend, no stream — the demo's writes all go through the rail, which invalidates directly.
  // 零后端零流:demo 的写全走 rail、直接 invalidate。
  @override
  Stream<String> lifecycleSignals() => const Stream.empty();

  /// Derived honestly the way the backend does: scan every document body for `[[<id>]]` wikilinks
  /// targeting [documentId] (names hydrated from the live rows). 照后端方式诚实派生:扫全部正文的 `[[id]]`。
  @override
  Future<List<EntityRelation>> listBacklinks(String documentId) async => [
    for (final d in _docs)
      if (d.id != documentId && d.content.contains('[[$documentId]]'))
        EntityRelation(
          id: 'rel_${d.id}_$documentId',
          kind: 'link',
          fromKind: 'document',
          fromId: d.id,
          fromName: d.name,
          toKind: 'document',
          toId: documentId,
          toName: _byId(documentId).name,
        ),
  ];
}
