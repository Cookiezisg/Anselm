import 'package:freezed_annotation/freezed_annotation.dart';

part 'document.freezed.dart';
part 'document.g.dart';

/// A document — one node in the workspace's Notion-style markdown tree (parent/children, ordered,
/// path-addressed). USER-editable **file-like knowledge**, NOT an AI-only versioned Quadrinity entity:
/// [content] is a plain markdown string the user edits directly (round-tripped by the Notion editor),
/// [description]/[tags] are out-of-band metadata columns (NOT frontmatter in the body). [parentId] null =
/// root-level. A node can be BOTH a page and a folder — no isFolder discriminator; a content-less node
/// with children just "reads like a folder". document.go:21。
@freezed
abstract class DocumentNode with _$DocumentNode {
  const factory DocumentNode({
    required String id,
    String? parentId,
    @Default('') String name,
    @Default('') String description,
    @Default('') String content, // omitted by GET /tree (metadata only) → empty; full node via GET /{id}
    @Default(false) bool hasContent, // GET /tree only: body non-empty (≡ sizeBytes>0) → drives empty-page vs written-doc icon
    @Default(<String>[]) List<String> tags,
    @Default(0) int position,
    @Default('') String path,
    @Default(0) int sizeBytes,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _DocumentNode;
  factory DocumentNode.fromJson(Map<String, dynamic> json) => _$DocumentNodeFromJson(json);
}

/// Physical guardrails mirrored from the backend (document.go:39/45) for client-side pre-validation.
/// 后端物理护栏,供客户端预校验。
const int kDocumentMaxContentBytes = 1 << 20; // 1 MB — DOCUMENT_CONTENT_TOO_LARGE past this
const int kDocumentMaxNameLength = 256; // DOCUMENT_INVALID_NAME past this / on empty / on '/'
