import '../../../core/contract/entities/document.dart';
import '../../../core/contract/entities/skill.dart';
import 'document_repository.dart';

/// An in-memory, scriptable [DocumentsRepository] for `make demo` (zero backend) + widget tests. Holds a
/// flat node list (the tree is derived by `parentId`, exactly like the Live `/tree`) + a flat skill list.
/// Writes mutate in place so a demo/test can create/rename/move/delete and see the rail react. Not used by
/// the live app. 内存可脚本 fixture:扁平节点列表(按 parentId 组树)+ skill 列表;写就地改。
class FixtureDocumentsRepository implements DocumentsRepository {
  FixtureDocumentsRepository({List<DocumentNode>? documents, List<Skill>? skills})
      : _docs = List.of(documents ?? const []),
        _skills = List.of(skills ?? const []);

  final List<DocumentNode> _docs;
  final List<Skill> _skills;
  int _seq = 0;

  // A deterministic stamp for fixture-created rows (tests don't assert wall-clock). fixture 建行的确定性时刻。
  static final DateTime _t = DateTime.utc(2026, 7, 5, 9);

  String _newId() => 'doc_fixture${(_seq++).toString().padLeft(10, '0')}';

  DocumentNode _byId(String id) => _docs.firstWhere((d) => d.id == id);

  // ── documents ──────────────────────────────────────────────────────────────
  @override
  Future<List<DocumentNode>> getTree() async => List.of(_docs);
  @override
  Future<DocumentNode> getDocument(String id) async => _byId(id);
  @override
  Future<List<DocumentNode>> listChildren(String? parentId) async {
    final kids = _docs.where((d) => d.parentId == (parentId?.isEmpty == true ? null : parentId)).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return kids;
  }

  @override
  Future<DocumentNode> createDocument(
      {required String name,
      String? parentId,
      String content = '',
      String description = '',
      List<String> tags = const []}) async {
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
  Future<DocumentNode> updateDocument(String id, Map<String, dynamic> patch) async {
    final i = _docs.indexWhere((d) => d.id == id);
    final cur = _docs[i];
    final next = cur.copyWith(
      name: patch['name'] as String? ?? cur.name,
      description: patch['description'] as String? ?? cur.description,
      content: patch['content'] as String? ?? cur.content,
      tags: (patch['tags'] as List?)?.cast<String>() ?? cur.tags,
      sizeBytes: patch['content'] is String ? (patch['content'] as String).length : cur.sizeBytes,
      updatedAt: _t,
    );
    _docs[i] = next;
    return next;
  }

  @override
  Future<void> deleteDocument(String id) async {
    // Remove the node + its whole subtree (descendants by parentId chain). 删节点 + 整子树。
    final doomed = <String>{id};
    bool grew = true;
    while (grew) {
      grew = false;
      for (final d in _docs) {
        if (d.parentId != null && doomed.contains(d.parentId) && doomed.add(d.id)) grew = true;
      }
    }
    _docs.removeWhere((d) => doomed.contains(d.id));
  }

  @override
  Future<DocumentNode> moveDocument(String id, {String? parentId, int? position}) async {
    final i = _docs.indexWhere((d) => d.id == id);
    final next = _docs[i].copyWith(
      parentId: parentId,
      position: position ?? _docs[i].position,
      updatedAt: _t,
    );
    _docs[i] = next;
    return next;
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
  Future<List<Skill>> listSkills() async => [for (final s in _skills) s.copyWith(body: '')];
  @override
  Future<Skill> getSkill(String name) async => _skills.firstWhere((s) => s.name == name);
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
    final i = _skills.indexWhere((s) => s.name == name);
    final next = _skills[i].copyWith(
      description: body['description'] as String? ?? _skills[i].description,
      context: body['context'] as String? ?? _skills[i].context,
      body: body['body'] as String? ?? _skills[i].body,
      updatedAt: _t,
    );
    _skills[i] = next;
    return next;
  }

  @override
  Future<void> deleteSkill(String name) async => _skills.removeWhere((s) => s.name == name);
}
