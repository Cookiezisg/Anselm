import 'package:freezed_annotation/freezed_annotation.dart';

part 'todo.freezed.dart';
part 'todo.g.dart';

/// One task-list entry — the backend's todo wire shape exactly ({content, activeForm, status}; ≤64
/// entries, NO id, whole-list replace semantics). [activeForm] is the in-progress phrasing («正在扫描
/// 日志…») the rundown shows while [status] == in_progress. 一条任务项(无 id,整表替换):activeForm 是
/// in_progress 期的进行时文案。
@freezed
abstract class TodoEntry with _$TodoEntry {
  const factory TodoEntry({
    @Default('') String content,
    @Default('') String activeForm,
    @Default('pending') String status, // pending | in_progress | completed
  }) = _TodoEntry;

  factory TodoEntry.fromJson(Map<String, dynamic> json) => _$TodoEntryFromJson(json);
}

/// One conversation's (or one subagent's) whole todo list — `GET /conversations/{id}/todos` and the
/// durable `todo` Signal's payload share this shape. [subagentId] "" = the conversation's own list.
/// 一份完整清单(GET 与 durable todo 信号共形);subagentId 空=会话主清单。
@freezed
abstract class ConversationTodos with _$ConversationTodos {
  const ConversationTodos._();

  const factory ConversationTodos({
    @Default('') String conversationId,
    @Default('') String subagentId,
    @Default(<TodoEntry>[]) List<TodoEntry> todos,
  }) = _ConversationTodos;

  factory ConversationTodos.fromJson(Map<String, dynamic> json) =>
      _$ConversationTodosFromJson(json);

  int get completed => todos.where((t) => t.status == 'completed').length;
}
