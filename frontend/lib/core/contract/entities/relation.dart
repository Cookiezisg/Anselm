import 'package:freezed_annotation/freezed_annotation.dart';

part 'relation.freezed.dart';
part 'relation.g.dart';

/// One edge in the workspace's entity-relation graph — read-only derived data (the backend diff-syncs
/// edges on entity writes; there is no edge CRUD). [kind] is the closed 4-verb set `create|edit|equip|
/// link`; a document's `[[id]]` wikilinks materialize as `link` out-edges, so BACKLINKS of a document =
/// incoming `link` edges (`GET /relations?toKind=document&toId=…&kind=link`). [fromName]/[toName] are
/// hydrated FRESH at read time via the backend's Namer registry — a renamed linker always shows its
/// current title; a deleted one falls back to the raw id. relation.go:28。
///
/// 关系图一条边——只读派生数据(边随实体写 diff-sync,无边 CRUD)。kind=4 动词封闭集;文档 `[[id]]` wikilink
/// 落成 link 出边,故文档的 backlinks=入向 link 边。fromName/toName 读时新鲜 hydrate(改名跟随;删了回落裸 id)。
@freezed
abstract class EntityRelation with _$EntityRelation {
  const factory EntityRelation({
    required String id,
    @Default('') String kind,
    @Default('') String fromKind,
    @Default('') String fromId,
    @Default('') String fromName,
    @Default('') String toKind,
    @Default('') String toId,
    @Default('') String toName,
  }) = _EntityRelation;
  factory EntityRelation.fromJson(Map<String, dynamic> json) => _$EntityRelationFromJson(json);
}
