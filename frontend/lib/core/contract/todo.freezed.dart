// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'todo.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TodoEntry {

 String get content; String get activeForm; String get status;
/// Create a copy of TodoEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TodoEntryCopyWith<TodoEntry> get copyWith => _$TodoEntryCopyWithImpl<TodoEntry>(this as TodoEntry, _$identity);

  /// Serializes this TodoEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TodoEntry&&(identical(other.content, content) || other.content == content)&&(identical(other.activeForm, activeForm) || other.activeForm == activeForm)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,content,activeForm,status);

@override
String toString() {
  return 'TodoEntry(content: $content, activeForm: $activeForm, status: $status)';
}


}

/// @nodoc
abstract mixin class $TodoEntryCopyWith<$Res>  {
  factory $TodoEntryCopyWith(TodoEntry value, $Res Function(TodoEntry) _then) = _$TodoEntryCopyWithImpl;
@useResult
$Res call({
 String content, String activeForm, String status
});




}
/// @nodoc
class _$TodoEntryCopyWithImpl<$Res>
    implements $TodoEntryCopyWith<$Res> {
  _$TodoEntryCopyWithImpl(this._self, this._then);

  final TodoEntry _self;
  final $Res Function(TodoEntry) _then;

/// Create a copy of TodoEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? content = null,Object? activeForm = null,Object? status = null,}) {
  return _then(_self.copyWith(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,activeForm: null == activeForm ? _self.activeForm : activeForm // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TodoEntry].
extension TodoEntryPatterns on TodoEntry {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TodoEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TodoEntry() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TodoEntry value)  $default,){
final _that = this;
switch (_that) {
case _TodoEntry():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TodoEntry value)?  $default,){
final _that = this;
switch (_that) {
case _TodoEntry() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String content,  String activeForm,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TodoEntry() when $default != null:
return $default(_that.content,_that.activeForm,_that.status);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String content,  String activeForm,  String status)  $default,) {final _that = this;
switch (_that) {
case _TodoEntry():
return $default(_that.content,_that.activeForm,_that.status);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String content,  String activeForm,  String status)?  $default,) {final _that = this;
switch (_that) {
case _TodoEntry() when $default != null:
return $default(_that.content,_that.activeForm,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TodoEntry implements TodoEntry {
  const _TodoEntry({this.content = '', this.activeForm = '', this.status = 'pending'});
  factory _TodoEntry.fromJson(Map<String, dynamic> json) => _$TodoEntryFromJson(json);

@override@JsonKey() final  String content;
@override@JsonKey() final  String activeForm;
@override@JsonKey() final  String status;

/// Create a copy of TodoEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TodoEntryCopyWith<_TodoEntry> get copyWith => __$TodoEntryCopyWithImpl<_TodoEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TodoEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TodoEntry&&(identical(other.content, content) || other.content == content)&&(identical(other.activeForm, activeForm) || other.activeForm == activeForm)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,content,activeForm,status);

@override
String toString() {
  return 'TodoEntry(content: $content, activeForm: $activeForm, status: $status)';
}


}

/// @nodoc
abstract mixin class _$TodoEntryCopyWith<$Res> implements $TodoEntryCopyWith<$Res> {
  factory _$TodoEntryCopyWith(_TodoEntry value, $Res Function(_TodoEntry) _then) = __$TodoEntryCopyWithImpl;
@override @useResult
$Res call({
 String content, String activeForm, String status
});




}
/// @nodoc
class __$TodoEntryCopyWithImpl<$Res>
    implements _$TodoEntryCopyWith<$Res> {
  __$TodoEntryCopyWithImpl(this._self, this._then);

  final _TodoEntry _self;
  final $Res Function(_TodoEntry) _then;

/// Create a copy of TodoEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? content = null,Object? activeForm = null,Object? status = null,}) {
  return _then(_TodoEntry(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,activeForm: null == activeForm ? _self.activeForm : activeForm // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ConversationTodos {

 String get conversationId; String get subagentId; List<TodoEntry> get todos;
/// Create a copy of ConversationTodos
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationTodosCopyWith<ConversationTodos> get copyWith => _$ConversationTodosCopyWithImpl<ConversationTodos>(this as ConversationTodos, _$identity);

  /// Serializes this ConversationTodos to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationTodos&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.subagentId, subagentId) || other.subagentId == subagentId)&&const DeepCollectionEquality().equals(other.todos, todos));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,conversationId,subagentId,const DeepCollectionEquality().hash(todos));

@override
String toString() {
  return 'ConversationTodos(conversationId: $conversationId, subagentId: $subagentId, todos: $todos)';
}


}

/// @nodoc
abstract mixin class $ConversationTodosCopyWith<$Res>  {
  factory $ConversationTodosCopyWith(ConversationTodos value, $Res Function(ConversationTodos) _then) = _$ConversationTodosCopyWithImpl;
@useResult
$Res call({
 String conversationId, String subagentId, List<TodoEntry> todos
});




}
/// @nodoc
class _$ConversationTodosCopyWithImpl<$Res>
    implements $ConversationTodosCopyWith<$Res> {
  _$ConversationTodosCopyWithImpl(this._self, this._then);

  final ConversationTodos _self;
  final $Res Function(ConversationTodos) _then;

/// Create a copy of ConversationTodos
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? conversationId = null,Object? subagentId = null,Object? todos = null,}) {
  return _then(_self.copyWith(
conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,subagentId: null == subagentId ? _self.subagentId : subagentId // ignore: cast_nullable_to_non_nullable
as String,todos: null == todos ? _self.todos : todos // ignore: cast_nullable_to_non_nullable
as List<TodoEntry>,
  ));
}

}


/// Adds pattern-matching-related methods to [ConversationTodos].
extension ConversationTodosPatterns on ConversationTodos {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConversationTodos value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConversationTodos() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConversationTodos value)  $default,){
final _that = this;
switch (_that) {
case _ConversationTodos():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConversationTodos value)?  $default,){
final _that = this;
switch (_that) {
case _ConversationTodos() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String conversationId,  String subagentId,  List<TodoEntry> todos)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConversationTodos() when $default != null:
return $default(_that.conversationId,_that.subagentId,_that.todos);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String conversationId,  String subagentId,  List<TodoEntry> todos)  $default,) {final _that = this;
switch (_that) {
case _ConversationTodos():
return $default(_that.conversationId,_that.subagentId,_that.todos);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String conversationId,  String subagentId,  List<TodoEntry> todos)?  $default,) {final _that = this;
switch (_that) {
case _ConversationTodos() when $default != null:
return $default(_that.conversationId,_that.subagentId,_that.todos);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ConversationTodos extends ConversationTodos {
  const _ConversationTodos({this.conversationId = '', this.subagentId = '', final  List<TodoEntry> todos = const <TodoEntry>[]}): _todos = todos,super._();
  factory _ConversationTodos.fromJson(Map<String, dynamic> json) => _$ConversationTodosFromJson(json);

@override@JsonKey() final  String conversationId;
@override@JsonKey() final  String subagentId;
 final  List<TodoEntry> _todos;
@override@JsonKey() List<TodoEntry> get todos {
  if (_todos is EqualUnmodifiableListView) return _todos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_todos);
}


/// Create a copy of ConversationTodos
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversationTodosCopyWith<_ConversationTodos> get copyWith => __$ConversationTodosCopyWithImpl<_ConversationTodos>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConversationTodosToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConversationTodos&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.subagentId, subagentId) || other.subagentId == subagentId)&&const DeepCollectionEquality().equals(other._todos, _todos));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,conversationId,subagentId,const DeepCollectionEquality().hash(_todos));

@override
String toString() {
  return 'ConversationTodos(conversationId: $conversationId, subagentId: $subagentId, todos: $todos)';
}


}

/// @nodoc
abstract mixin class _$ConversationTodosCopyWith<$Res> implements $ConversationTodosCopyWith<$Res> {
  factory _$ConversationTodosCopyWith(_ConversationTodos value, $Res Function(_ConversationTodos) _then) = __$ConversationTodosCopyWithImpl;
@override @useResult
$Res call({
 String conversationId, String subagentId, List<TodoEntry> todos
});




}
/// @nodoc
class __$ConversationTodosCopyWithImpl<$Res>
    implements _$ConversationTodosCopyWith<$Res> {
  __$ConversationTodosCopyWithImpl(this._self, this._then);

  final _ConversationTodos _self;
  final $Res Function(_ConversationTodos) _then;

/// Create a copy of ConversationTodos
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? conversationId = null,Object? subagentId = null,Object? todos = null,}) {
  return _then(_ConversationTodos(
conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,subagentId: null == subagentId ? _self.subagentId : subagentId // ignore: cast_nullable_to_non_nullable
as String,todos: null == todos ? _self._todos : todos // ignore: cast_nullable_to_non_nullable
as List<TodoEntry>,
  ));
}


}

// dart format on
