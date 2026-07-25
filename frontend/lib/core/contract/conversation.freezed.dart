// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conversation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Conversation {

 String get id; String get title; bool get autoTitled; bool get archived; bool get pinned; ModelRef? get modelOverride; DateTime get createdAt; DateTime get updatedAt; DateTime get lastMessageAt; bool get isGenerating; bool get awaitingInput; bool get hasUnread; String get forkedFromConversationId; String get forkedFromMessageId; String get workDir;
/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationCopyWith<Conversation> get copyWith => _$ConversationCopyWithImpl<Conversation>(this as Conversation, _$identity);

  /// Serializes this Conversation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Conversation&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.autoTitled, autoTitled) || other.autoTitled == autoTitled)&&(identical(other.archived, archived) || other.archived == archived)&&(identical(other.pinned, pinned) || other.pinned == pinned)&&(identical(other.modelOverride, modelOverride) || other.modelOverride == modelOverride)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.isGenerating, isGenerating) || other.isGenerating == isGenerating)&&(identical(other.awaitingInput, awaitingInput) || other.awaitingInput == awaitingInput)&&(identical(other.hasUnread, hasUnread) || other.hasUnread == hasUnread)&&(identical(other.forkedFromConversationId, forkedFromConversationId) || other.forkedFromConversationId == forkedFromConversationId)&&(identical(other.forkedFromMessageId, forkedFromMessageId) || other.forkedFromMessageId == forkedFromMessageId)&&(identical(other.workDir, workDir) || other.workDir == workDir));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,autoTitled,archived,pinned,modelOverride,createdAt,updatedAt,lastMessageAt,isGenerating,awaitingInput,hasUnread,forkedFromConversationId,forkedFromMessageId,workDir);

@override
String toString() {
  return 'Conversation(id: $id, title: $title, autoTitled: $autoTitled, archived: $archived, pinned: $pinned, modelOverride: $modelOverride, createdAt: $createdAt, updatedAt: $updatedAt, lastMessageAt: $lastMessageAt, isGenerating: $isGenerating, awaitingInput: $awaitingInput, hasUnread: $hasUnread, forkedFromConversationId: $forkedFromConversationId, forkedFromMessageId: $forkedFromMessageId, workDir: $workDir)';
}


}

/// @nodoc
abstract mixin class $ConversationCopyWith<$Res>  {
  factory $ConversationCopyWith(Conversation value, $Res Function(Conversation) _then) = _$ConversationCopyWithImpl;
@useResult
$Res call({
 String id, String title, bool autoTitled, bool archived, bool pinned, ModelRef? modelOverride, DateTime createdAt, DateTime updatedAt, DateTime lastMessageAt, bool isGenerating, bool awaitingInput, bool hasUnread, String forkedFromConversationId, String forkedFromMessageId, String workDir
});


$ModelRefCopyWith<$Res>? get modelOverride;

}
/// @nodoc
class _$ConversationCopyWithImpl<$Res>
    implements $ConversationCopyWith<$Res> {
  _$ConversationCopyWithImpl(this._self, this._then);

  final Conversation _self;
  final $Res Function(Conversation) _then;

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? autoTitled = null,Object? archived = null,Object? pinned = null,Object? modelOverride = freezed,Object? createdAt = null,Object? updatedAt = null,Object? lastMessageAt = null,Object? isGenerating = null,Object? awaitingInput = null,Object? hasUnread = null,Object? forkedFromConversationId = null,Object? forkedFromMessageId = null,Object? workDir = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,autoTitled: null == autoTitled ? _self.autoTitled : autoTitled // ignore: cast_nullable_to_non_nullable
as bool,archived: null == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as bool,modelOverride: freezed == modelOverride ? _self.modelOverride : modelOverride // ignore: cast_nullable_to_non_nullable
as ModelRef?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastMessageAt: null == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime,isGenerating: null == isGenerating ? _self.isGenerating : isGenerating // ignore: cast_nullable_to_non_nullable
as bool,awaitingInput: null == awaitingInput ? _self.awaitingInput : awaitingInput // ignore: cast_nullable_to_non_nullable
as bool,hasUnread: null == hasUnread ? _self.hasUnread : hasUnread // ignore: cast_nullable_to_non_nullable
as bool,forkedFromConversationId: null == forkedFromConversationId ? _self.forkedFromConversationId : forkedFromConversationId // ignore: cast_nullable_to_non_nullable
as String,forkedFromMessageId: null == forkedFromMessageId ? _self.forkedFromMessageId : forkedFromMessageId // ignore: cast_nullable_to_non_nullable
as String,workDir: null == workDir ? _self.workDir : workDir // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelRefCopyWith<$Res>? get modelOverride {
    if (_self.modelOverride == null) {
    return null;
  }

  return $ModelRefCopyWith<$Res>(_self.modelOverride!, (value) {
    return _then(_self.copyWith(modelOverride: value));
  });
}
}


/// Adds pattern-matching-related methods to [Conversation].
extension ConversationPatterns on Conversation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Conversation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Conversation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Conversation value)  $default,){
final _that = this;
switch (_that) {
case _Conversation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Conversation value)?  $default,){
final _that = this;
switch (_that) {
case _Conversation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  bool autoTitled,  bool archived,  bool pinned,  ModelRef? modelOverride,  DateTime createdAt,  DateTime updatedAt,  DateTime lastMessageAt,  bool isGenerating,  bool awaitingInput,  bool hasUnread,  String forkedFromConversationId,  String forkedFromMessageId,  String workDir)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Conversation() when $default != null:
return $default(_that.id,_that.title,_that.autoTitled,_that.archived,_that.pinned,_that.modelOverride,_that.createdAt,_that.updatedAt,_that.lastMessageAt,_that.isGenerating,_that.awaitingInput,_that.hasUnread,_that.forkedFromConversationId,_that.forkedFromMessageId,_that.workDir);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  bool autoTitled,  bool archived,  bool pinned,  ModelRef? modelOverride,  DateTime createdAt,  DateTime updatedAt,  DateTime lastMessageAt,  bool isGenerating,  bool awaitingInput,  bool hasUnread,  String forkedFromConversationId,  String forkedFromMessageId,  String workDir)  $default,) {final _that = this;
switch (_that) {
case _Conversation():
return $default(_that.id,_that.title,_that.autoTitled,_that.archived,_that.pinned,_that.modelOverride,_that.createdAt,_that.updatedAt,_that.lastMessageAt,_that.isGenerating,_that.awaitingInput,_that.hasUnread,_that.forkedFromConversationId,_that.forkedFromMessageId,_that.workDir);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  bool autoTitled,  bool archived,  bool pinned,  ModelRef? modelOverride,  DateTime createdAt,  DateTime updatedAt,  DateTime lastMessageAt,  bool isGenerating,  bool awaitingInput,  bool hasUnread,  String forkedFromConversationId,  String forkedFromMessageId,  String workDir)?  $default,) {final _that = this;
switch (_that) {
case _Conversation() when $default != null:
return $default(_that.id,_that.title,_that.autoTitled,_that.archived,_that.pinned,_that.modelOverride,_that.createdAt,_that.updatedAt,_that.lastMessageAt,_that.isGenerating,_that.awaitingInput,_that.hasUnread,_that.forkedFromConversationId,_that.forkedFromMessageId,_that.workDir);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Conversation implements Conversation {
  const _Conversation({required this.id, this.title = '', this.autoTitled = false, this.archived = false, this.pinned = false, this.modelOverride, required this.createdAt, required this.updatedAt, required this.lastMessageAt, this.isGenerating = false, this.awaitingInput = false, this.hasUnread = false, this.forkedFromConversationId = '', this.forkedFromMessageId = '', this.workDir = ''});
  factory _Conversation.fromJson(Map<String, dynamic> json) => _$ConversationFromJson(json);

@override final  String id;
@override@JsonKey() final  String title;
@override@JsonKey() final  bool autoTitled;
@override@JsonKey() final  bool archived;
@override@JsonKey() final  bool pinned;
@override final  ModelRef? modelOverride;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  DateTime lastMessageAt;
@override@JsonKey() final  bool isGenerating;
@override@JsonKey() final  bool awaitingInput;
@override@JsonKey() final  bool hasUnread;
@override@JsonKey() final  String forkedFromConversationId;
@override@JsonKey() final  String forkedFromMessageId;
@override@JsonKey() final  String workDir;

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversationCopyWith<_Conversation> get copyWith => __$ConversationCopyWithImpl<_Conversation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConversationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Conversation&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.autoTitled, autoTitled) || other.autoTitled == autoTitled)&&(identical(other.archived, archived) || other.archived == archived)&&(identical(other.pinned, pinned) || other.pinned == pinned)&&(identical(other.modelOverride, modelOverride) || other.modelOverride == modelOverride)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.isGenerating, isGenerating) || other.isGenerating == isGenerating)&&(identical(other.awaitingInput, awaitingInput) || other.awaitingInput == awaitingInput)&&(identical(other.hasUnread, hasUnread) || other.hasUnread == hasUnread)&&(identical(other.forkedFromConversationId, forkedFromConversationId) || other.forkedFromConversationId == forkedFromConversationId)&&(identical(other.forkedFromMessageId, forkedFromMessageId) || other.forkedFromMessageId == forkedFromMessageId)&&(identical(other.workDir, workDir) || other.workDir == workDir));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,autoTitled,archived,pinned,modelOverride,createdAt,updatedAt,lastMessageAt,isGenerating,awaitingInput,hasUnread,forkedFromConversationId,forkedFromMessageId,workDir);

@override
String toString() {
  return 'Conversation(id: $id, title: $title, autoTitled: $autoTitled, archived: $archived, pinned: $pinned, modelOverride: $modelOverride, createdAt: $createdAt, updatedAt: $updatedAt, lastMessageAt: $lastMessageAt, isGenerating: $isGenerating, awaitingInput: $awaitingInput, hasUnread: $hasUnread, forkedFromConversationId: $forkedFromConversationId, forkedFromMessageId: $forkedFromMessageId, workDir: $workDir)';
}


}

/// @nodoc
abstract mixin class _$ConversationCopyWith<$Res> implements $ConversationCopyWith<$Res> {
  factory _$ConversationCopyWith(_Conversation value, $Res Function(_Conversation) _then) = __$ConversationCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, bool autoTitled, bool archived, bool pinned, ModelRef? modelOverride, DateTime createdAt, DateTime updatedAt, DateTime lastMessageAt, bool isGenerating, bool awaitingInput, bool hasUnread, String forkedFromConversationId, String forkedFromMessageId, String workDir
});


@override $ModelRefCopyWith<$Res>? get modelOverride;

}
/// @nodoc
class __$ConversationCopyWithImpl<$Res>
    implements _$ConversationCopyWith<$Res> {
  __$ConversationCopyWithImpl(this._self, this._then);

  final _Conversation _self;
  final $Res Function(_Conversation) _then;

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? autoTitled = null,Object? archived = null,Object? pinned = null,Object? modelOverride = freezed,Object? createdAt = null,Object? updatedAt = null,Object? lastMessageAt = null,Object? isGenerating = null,Object? awaitingInput = null,Object? hasUnread = null,Object? forkedFromConversationId = null,Object? forkedFromMessageId = null,Object? workDir = null,}) {
  return _then(_Conversation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,autoTitled: null == autoTitled ? _self.autoTitled : autoTitled // ignore: cast_nullable_to_non_nullable
as bool,archived: null == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as bool,modelOverride: freezed == modelOverride ? _self.modelOverride : modelOverride // ignore: cast_nullable_to_non_nullable
as ModelRef?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastMessageAt: null == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime,isGenerating: null == isGenerating ? _self.isGenerating : isGenerating // ignore: cast_nullable_to_non_nullable
as bool,awaitingInput: null == awaitingInput ? _self.awaitingInput : awaitingInput // ignore: cast_nullable_to_non_nullable
as bool,hasUnread: null == hasUnread ? _self.hasUnread : hasUnread // ignore: cast_nullable_to_non_nullable
as bool,forkedFromConversationId: null == forkedFromConversationId ? _self.forkedFromConversationId : forkedFromConversationId // ignore: cast_nullable_to_non_nullable
as String,forkedFromMessageId: null == forkedFromMessageId ? _self.forkedFromMessageId : forkedFromMessageId // ignore: cast_nullable_to_non_nullable
as String,workDir: null == workDir ? _self.workDir : workDir // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelRefCopyWith<$Res>? get modelOverride {
    if (_self.modelOverride == null) {
    return null;
  }

  return $ModelRefCopyWith<$Res>(_self.modelOverride!, (value) {
    return _then(_self.copyWith(modelOverride: value));
  });
}
}


/// @nodoc
mixin _$ModelRef {

 String get apiKeyId; String get modelId;
/// Create a copy of ModelRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModelRefCopyWith<ModelRef> get copyWith => _$ModelRefCopyWithImpl<ModelRef>(this as ModelRef, _$identity);

  /// Serializes this ModelRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModelRef&&(identical(other.apiKeyId, apiKeyId) || other.apiKeyId == apiKeyId)&&(identical(other.modelId, modelId) || other.modelId == modelId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,apiKeyId,modelId);

@override
String toString() {
  return 'ModelRef(apiKeyId: $apiKeyId, modelId: $modelId)';
}


}

/// @nodoc
abstract mixin class $ModelRefCopyWith<$Res>  {
  factory $ModelRefCopyWith(ModelRef value, $Res Function(ModelRef) _then) = _$ModelRefCopyWithImpl;
@useResult
$Res call({
 String apiKeyId, String modelId
});




}
/// @nodoc
class _$ModelRefCopyWithImpl<$Res>
    implements $ModelRefCopyWith<$Res> {
  _$ModelRefCopyWithImpl(this._self, this._then);

  final ModelRef _self;
  final $Res Function(ModelRef) _then;

/// Create a copy of ModelRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? apiKeyId = null,Object? modelId = null,}) {
  return _then(_self.copyWith(
apiKeyId: null == apiKeyId ? _self.apiKeyId : apiKeyId // ignore: cast_nullable_to_non_nullable
as String,modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ModelRef].
extension ModelRefPatterns on ModelRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ModelRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ModelRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ModelRef value)  $default,){
final _that = this;
switch (_that) {
case _ModelRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ModelRef value)?  $default,){
final _that = this;
switch (_that) {
case _ModelRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String apiKeyId,  String modelId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ModelRef() when $default != null:
return $default(_that.apiKeyId,_that.modelId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String apiKeyId,  String modelId)  $default,) {final _that = this;
switch (_that) {
case _ModelRef():
return $default(_that.apiKeyId,_that.modelId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String apiKeyId,  String modelId)?  $default,) {final _that = this;
switch (_that) {
case _ModelRef() when $default != null:
return $default(_that.apiKeyId,_that.modelId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ModelRef implements ModelRef {
  const _ModelRef({this.apiKeyId = '', this.modelId = ''});
  factory _ModelRef.fromJson(Map<String, dynamic> json) => _$ModelRefFromJson(json);

@override@JsonKey() final  String apiKeyId;
@override@JsonKey() final  String modelId;

/// Create a copy of ModelRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModelRefCopyWith<_ModelRef> get copyWith => __$ModelRefCopyWithImpl<_ModelRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ModelRefToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModelRef&&(identical(other.apiKeyId, apiKeyId) || other.apiKeyId == apiKeyId)&&(identical(other.modelId, modelId) || other.modelId == modelId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,apiKeyId,modelId);

@override
String toString() {
  return 'ModelRef(apiKeyId: $apiKeyId, modelId: $modelId)';
}


}

/// @nodoc
abstract mixin class _$ModelRefCopyWith<$Res> implements $ModelRefCopyWith<$Res> {
  factory _$ModelRefCopyWith(_ModelRef value, $Res Function(_ModelRef) _then) = __$ModelRefCopyWithImpl;
@override @useResult
$Res call({
 String apiKeyId, String modelId
});




}
/// @nodoc
class __$ModelRefCopyWithImpl<$Res>
    implements _$ModelRefCopyWith<$Res> {
  __$ModelRefCopyWithImpl(this._self, this._then);

  final _ModelRef _self;
  final $Res Function(_ModelRef) _then;

/// Create a copy of ModelRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? apiKeyId = null,Object? modelId = null,}) {
  return _then(_ModelRef(
apiKeyId: null == apiKeyId ? _self.apiKeyId : apiKeyId // ignore: cast_nullable_to_non_nullable
as String,modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$WorkDirGroup {

 String get workDir; int get activeCount; int get archivedCount; DateTime get lastMessageAt;
/// Create a copy of WorkDirGroup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkDirGroupCopyWith<WorkDirGroup> get copyWith => _$WorkDirGroupCopyWithImpl<WorkDirGroup>(this as WorkDirGroup, _$identity);

  /// Serializes this WorkDirGroup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkDirGroup&&(identical(other.workDir, workDir) || other.workDir == workDir)&&(identical(other.activeCount, activeCount) || other.activeCount == activeCount)&&(identical(other.archivedCount, archivedCount) || other.archivedCount == archivedCount)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,workDir,activeCount,archivedCount,lastMessageAt);

@override
String toString() {
  return 'WorkDirGroup(workDir: $workDir, activeCount: $activeCount, archivedCount: $archivedCount, lastMessageAt: $lastMessageAt)';
}


}

/// @nodoc
abstract mixin class $WorkDirGroupCopyWith<$Res>  {
  factory $WorkDirGroupCopyWith(WorkDirGroup value, $Res Function(WorkDirGroup) _then) = _$WorkDirGroupCopyWithImpl;
@useResult
$Res call({
 String workDir, int activeCount, int archivedCount, DateTime lastMessageAt
});




}
/// @nodoc
class _$WorkDirGroupCopyWithImpl<$Res>
    implements $WorkDirGroupCopyWith<$Res> {
  _$WorkDirGroupCopyWithImpl(this._self, this._then);

  final WorkDirGroup _self;
  final $Res Function(WorkDirGroup) _then;

/// Create a copy of WorkDirGroup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? workDir = null,Object? activeCount = null,Object? archivedCount = null,Object? lastMessageAt = null,}) {
  return _then(_self.copyWith(
workDir: null == workDir ? _self.workDir : workDir // ignore: cast_nullable_to_non_nullable
as String,activeCount: null == activeCount ? _self.activeCount : activeCount // ignore: cast_nullable_to_non_nullable
as int,archivedCount: null == archivedCount ? _self.archivedCount : archivedCount // ignore: cast_nullable_to_non_nullable
as int,lastMessageAt: null == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkDirGroup].
extension WorkDirGroupPatterns on WorkDirGroup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkDirGroup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkDirGroup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkDirGroup value)  $default,){
final _that = this;
switch (_that) {
case _WorkDirGroup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkDirGroup value)?  $default,){
final _that = this;
switch (_that) {
case _WorkDirGroup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String workDir,  int activeCount,  int archivedCount,  DateTime lastMessageAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkDirGroup() when $default != null:
return $default(_that.workDir,_that.activeCount,_that.archivedCount,_that.lastMessageAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String workDir,  int activeCount,  int archivedCount,  DateTime lastMessageAt)  $default,) {final _that = this;
switch (_that) {
case _WorkDirGroup():
return $default(_that.workDir,_that.activeCount,_that.archivedCount,_that.lastMessageAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String workDir,  int activeCount,  int archivedCount,  DateTime lastMessageAt)?  $default,) {final _that = this;
switch (_that) {
case _WorkDirGroup() when $default != null:
return $default(_that.workDir,_that.activeCount,_that.archivedCount,_that.lastMessageAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkDirGroup implements WorkDirGroup {
  const _WorkDirGroup({this.workDir = '', this.activeCount = 0, this.archivedCount = 0, required this.lastMessageAt});
  factory _WorkDirGroup.fromJson(Map<String, dynamic> json) => _$WorkDirGroupFromJson(json);

@override@JsonKey() final  String workDir;
@override@JsonKey() final  int activeCount;
@override@JsonKey() final  int archivedCount;
@override final  DateTime lastMessageAt;

/// Create a copy of WorkDirGroup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkDirGroupCopyWith<_WorkDirGroup> get copyWith => __$WorkDirGroupCopyWithImpl<_WorkDirGroup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkDirGroupToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkDirGroup&&(identical(other.workDir, workDir) || other.workDir == workDir)&&(identical(other.activeCount, activeCount) || other.activeCount == activeCount)&&(identical(other.archivedCount, archivedCount) || other.archivedCount == archivedCount)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,workDir,activeCount,archivedCount,lastMessageAt);

@override
String toString() {
  return 'WorkDirGroup(workDir: $workDir, activeCount: $activeCount, archivedCount: $archivedCount, lastMessageAt: $lastMessageAt)';
}


}

/// @nodoc
abstract mixin class _$WorkDirGroupCopyWith<$Res> implements $WorkDirGroupCopyWith<$Res> {
  factory _$WorkDirGroupCopyWith(_WorkDirGroup value, $Res Function(_WorkDirGroup) _then) = __$WorkDirGroupCopyWithImpl;
@override @useResult
$Res call({
 String workDir, int activeCount, int archivedCount, DateTime lastMessageAt
});




}
/// @nodoc
class __$WorkDirGroupCopyWithImpl<$Res>
    implements _$WorkDirGroupCopyWith<$Res> {
  __$WorkDirGroupCopyWithImpl(this._self, this._then);

  final _WorkDirGroup _self;
  final $Res Function(_WorkDirGroup) _then;

/// Create a copy of WorkDirGroup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? workDir = null,Object? activeCount = null,Object? archivedCount = null,Object? lastMessageAt = null,}) {
  return _then(_WorkDirGroup(
workDir: null == workDir ? _self.workDir : workDir // ignore: cast_nullable_to_non_nullable
as String,activeCount: null == activeCount ? _self.activeCount : activeCount // ignore: cast_nullable_to_non_nullable
as int,archivedCount: null == archivedCount ? _self.archivedCount : archivedCount // ignore: cast_nullable_to_non_nullable
as int,lastMessageAt: null == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$WorkDirInfo {

 String get path; bool get exists; bool get isGitRepo; String get branch; bool get dirty;
/// Create a copy of WorkDirInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkDirInfoCopyWith<WorkDirInfo> get copyWith => _$WorkDirInfoCopyWithImpl<WorkDirInfo>(this as WorkDirInfo, _$identity);

  /// Serializes this WorkDirInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkDirInfo&&(identical(other.path, path) || other.path == path)&&(identical(other.exists, exists) || other.exists == exists)&&(identical(other.isGitRepo, isGitRepo) || other.isGitRepo == isGitRepo)&&(identical(other.branch, branch) || other.branch == branch)&&(identical(other.dirty, dirty) || other.dirty == dirty));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,exists,isGitRepo,branch,dirty);

@override
String toString() {
  return 'WorkDirInfo(path: $path, exists: $exists, isGitRepo: $isGitRepo, branch: $branch, dirty: $dirty)';
}


}

/// @nodoc
abstract mixin class $WorkDirInfoCopyWith<$Res>  {
  factory $WorkDirInfoCopyWith(WorkDirInfo value, $Res Function(WorkDirInfo) _then) = _$WorkDirInfoCopyWithImpl;
@useResult
$Res call({
 String path, bool exists, bool isGitRepo, String branch, bool dirty
});




}
/// @nodoc
class _$WorkDirInfoCopyWithImpl<$Res>
    implements $WorkDirInfoCopyWith<$Res> {
  _$WorkDirInfoCopyWithImpl(this._self, this._then);

  final WorkDirInfo _self;
  final $Res Function(WorkDirInfo) _then;

/// Create a copy of WorkDirInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? exists = null,Object? isGitRepo = null,Object? branch = null,Object? dirty = null,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,exists: null == exists ? _self.exists : exists // ignore: cast_nullable_to_non_nullable
as bool,isGitRepo: null == isGitRepo ? _self.isGitRepo : isGitRepo // ignore: cast_nullable_to_non_nullable
as bool,branch: null == branch ? _self.branch : branch // ignore: cast_nullable_to_non_nullable
as String,dirty: null == dirty ? _self.dirty : dirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkDirInfo].
extension WorkDirInfoPatterns on WorkDirInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkDirInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkDirInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkDirInfo value)  $default,){
final _that = this;
switch (_that) {
case _WorkDirInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkDirInfo value)?  $default,){
final _that = this;
switch (_that) {
case _WorkDirInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path,  bool exists,  bool isGitRepo,  String branch,  bool dirty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkDirInfo() when $default != null:
return $default(_that.path,_that.exists,_that.isGitRepo,_that.branch,_that.dirty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path,  bool exists,  bool isGitRepo,  String branch,  bool dirty)  $default,) {final _that = this;
switch (_that) {
case _WorkDirInfo():
return $default(_that.path,_that.exists,_that.isGitRepo,_that.branch,_that.dirty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path,  bool exists,  bool isGitRepo,  String branch,  bool dirty)?  $default,) {final _that = this;
switch (_that) {
case _WorkDirInfo() when $default != null:
return $default(_that.path,_that.exists,_that.isGitRepo,_that.branch,_that.dirty);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkDirInfo implements WorkDirInfo {
  const _WorkDirInfo({this.path = '', this.exists = false, this.isGitRepo = false, this.branch = '', this.dirty = false});
  factory _WorkDirInfo.fromJson(Map<String, dynamic> json) => _$WorkDirInfoFromJson(json);

@override@JsonKey() final  String path;
@override@JsonKey() final  bool exists;
@override@JsonKey() final  bool isGitRepo;
@override@JsonKey() final  String branch;
@override@JsonKey() final  bool dirty;

/// Create a copy of WorkDirInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkDirInfoCopyWith<_WorkDirInfo> get copyWith => __$WorkDirInfoCopyWithImpl<_WorkDirInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkDirInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkDirInfo&&(identical(other.path, path) || other.path == path)&&(identical(other.exists, exists) || other.exists == exists)&&(identical(other.isGitRepo, isGitRepo) || other.isGitRepo == isGitRepo)&&(identical(other.branch, branch) || other.branch == branch)&&(identical(other.dirty, dirty) || other.dirty == dirty));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,exists,isGitRepo,branch,dirty);

@override
String toString() {
  return 'WorkDirInfo(path: $path, exists: $exists, isGitRepo: $isGitRepo, branch: $branch, dirty: $dirty)';
}


}

/// @nodoc
abstract mixin class _$WorkDirInfoCopyWith<$Res> implements $WorkDirInfoCopyWith<$Res> {
  factory _$WorkDirInfoCopyWith(_WorkDirInfo value, $Res Function(_WorkDirInfo) _then) = __$WorkDirInfoCopyWithImpl;
@override @useResult
$Res call({
 String path, bool exists, bool isGitRepo, String branch, bool dirty
});




}
/// @nodoc
class __$WorkDirInfoCopyWithImpl<$Res>
    implements _$WorkDirInfoCopyWith<$Res> {
  __$WorkDirInfoCopyWithImpl(this._self, this._then);

  final _WorkDirInfo _self;
  final $Res Function(_WorkDirInfo) _then;

/// Create a copy of WorkDirInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? exists = null,Object? isGitRepo = null,Object? branch = null,Object? dirty = null,}) {
  return _then(_WorkDirInfo(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,exists: null == exists ? _self.exists : exists // ignore: cast_nullable_to_non_nullable
as bool,isGitRepo: null == isGitRepo ? _self.isGitRepo : isGitRepo // ignore: cast_nullable_to_non_nullable
as bool,branch: null == branch ? _self.branch : branch // ignore: cast_nullable_to_non_nullable
as String,dirty: null == dirty ? _self.dirty : dirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
