// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TodoEntry _$TodoEntryFromJson(Map<String, dynamic> json) => _TodoEntry(
  content: json['content'] as String? ?? '',
  activeForm: json['activeForm'] as String? ?? '',
  status: json['status'] as String? ?? 'pending',
);

Map<String, dynamic> _$TodoEntryToJson(_TodoEntry instance) =>
    <String, dynamic>{
      'content': instance.content,
      'activeForm': instance.activeForm,
      'status': instance.status,
    };

_ConversationTodos _$ConversationTodosFromJson(Map<String, dynamic> json) =>
    _ConversationTodos(
      conversationId: json['conversationId'] as String? ?? '',
      subagentId: json['subagentId'] as String? ?? '',
      todos:
          (json['todos'] as List<dynamic>?)
              ?.map((e) => TodoEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <TodoEntry>[],
    );

Map<String, dynamic> _$ConversationTodosToJson(_ConversationTodos instance) =>
    <String, dynamic>{
      'conversationId': instance.conversationId,
      'subagentId': instance.subagentId,
      'todos': instance.todos.map((e) => e.toJson()).toList(),
    };
