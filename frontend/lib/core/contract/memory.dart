import 'package:freezed_annotation/freezed_annotation.dart';

part 'memory.freezed.dart';
part 'memory.g.dart';

/// One file-backed memory — `GET /memories` rows (slug name IS the identity; no id). `pinned`
/// memories ride every conversation's context. `source` is the immutable author (user | ai);
/// `updatedAt` is the file mtime. On UPDATE the backend ignores body pinned/source (F147) —
/// pinning goes through :pin/:unpin only.
///
/// 文件式记忆一行(slug 名即身份,无 id)。pinned 常驻每次对话上下文;source 为不可变作者;updatedAt=
/// 文件 mtime。更新时后端忽略 body 的 pinned/source(F147)——固定只走 pin/unpin 端点。
@freezed
abstract class Memory with _$Memory {
  const factory Memory({
    required String name,
    @Default('') String description,
    @Default('') String content,
    @Default(false) bool pinned,
    @Default('user') String source,
    DateTime? updatedAt,
  }) = _Memory;

  factory Memory.fromJson(Map<String, dynamic> json) => _$MemoryFromJson(json);
}
