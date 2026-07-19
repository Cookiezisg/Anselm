// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChatBlock {

 String get id; String get conversationId; String get messageId; String get parentBlockId; int get seq; String get type; Map<String, dynamic>? get attrs; String get content; String get status; String get error;// The row's write time (P1-e) — the backend has always serialized it; anchors/场次条 order
// turns by message createdAt and blocks WITHIN a turn by seq, but a block-born anchor (a
// dangerous tool, a compaction mark) timestamps by this. Nullable: live frames have no row
// time until the close snapshot lands.
// 行落盘时刻(P1-e)——后端一直在序列化;场次条按回合 createdAt 排、回合内按 seq,块生锚点
// (危险工具/压缩标记)以此计时。可空:live 帧在 close 快照前无行时刻。
 DateTime? get createdAt;
/// Create a copy of ChatBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatBlockCopyWith<ChatBlock> get copyWith => _$ChatBlockCopyWithImpl<ChatBlock>(this as ChatBlock, _$identity);

  /// Serializes this ChatBlock to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.parentBlockId, parentBlockId) || other.parentBlockId == parentBlockId)&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.attrs, attrs)&&(identical(other.content, content) || other.content == content)&&(identical(other.status, status) || other.status == status)&&(identical(other.error, error) || other.error == error)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,conversationId,messageId,parentBlockId,seq,type,const DeepCollectionEquality().hash(attrs),content,status,error,createdAt);

@override
String toString() {
  return 'ChatBlock(id: $id, conversationId: $conversationId, messageId: $messageId, parentBlockId: $parentBlockId, seq: $seq, type: $type, attrs: $attrs, content: $content, status: $status, error: $error, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $ChatBlockCopyWith<$Res>  {
  factory $ChatBlockCopyWith(ChatBlock value, $Res Function(ChatBlock) _then) = _$ChatBlockCopyWithImpl;
@useResult
$Res call({
 String id, String conversationId, String messageId, String parentBlockId, int seq, String type, Map<String, dynamic>? attrs, String content, String status, String error, DateTime? createdAt
});




}
/// @nodoc
class _$ChatBlockCopyWithImpl<$Res>
    implements $ChatBlockCopyWith<$Res> {
  _$ChatBlockCopyWithImpl(this._self, this._then);

  final ChatBlock _self;
  final $Res Function(ChatBlock) _then;

/// Create a copy of ChatBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? conversationId = null,Object? messageId = null,Object? parentBlockId = null,Object? seq = null,Object? type = null,Object? attrs = freezed,Object? content = null,Object? status = null,Object? error = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,parentBlockId: null == parentBlockId ? _self.parentBlockId : parentBlockId // ignore: cast_nullable_to_non_nullable
as String,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,attrs: freezed == attrs ? _self.attrs : attrs // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatBlock].
extension ChatBlockPatterns on ChatBlock {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatBlock value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatBlock() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatBlock value)  $default,){
final _that = this;
switch (_that) {
case _ChatBlock():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatBlock value)?  $default,){
final _that = this;
switch (_that) {
case _ChatBlock() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String conversationId,  String messageId,  String parentBlockId,  int seq,  String type,  Map<String, dynamic>? attrs,  String content,  String status,  String error,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatBlock() when $default != null:
return $default(_that.id,_that.conversationId,_that.messageId,_that.parentBlockId,_that.seq,_that.type,_that.attrs,_that.content,_that.status,_that.error,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String conversationId,  String messageId,  String parentBlockId,  int seq,  String type,  Map<String, dynamic>? attrs,  String content,  String status,  String error,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _ChatBlock():
return $default(_that.id,_that.conversationId,_that.messageId,_that.parentBlockId,_that.seq,_that.type,_that.attrs,_that.content,_that.status,_that.error,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String conversationId,  String messageId,  String parentBlockId,  int seq,  String type,  Map<String, dynamic>? attrs,  String content,  String status,  String error,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _ChatBlock() when $default != null:
return $default(_that.id,_that.conversationId,_that.messageId,_that.parentBlockId,_that.seq,_that.type,_that.attrs,_that.content,_that.status,_that.error,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChatBlock implements ChatBlock {
  const _ChatBlock({required this.id, this.conversationId = '', this.messageId = '', this.parentBlockId = '', this.seq = 0, required this.type, final  Map<String, dynamic>? attrs, this.content = '', this.status = '', this.error = '', this.createdAt}): _attrs = attrs;
  factory _ChatBlock.fromJson(Map<String, dynamic> json) => _$ChatBlockFromJson(json);

@override final  String id;
@override@JsonKey() final  String conversationId;
@override@JsonKey() final  String messageId;
@override@JsonKey() final  String parentBlockId;
@override@JsonKey() final  int seq;
@override final  String type;
 final  Map<String, dynamic>? _attrs;
@override Map<String, dynamic>? get attrs {
  final value = _attrs;
  if (value == null) return null;
  if (_attrs is EqualUnmodifiableMapView) return _attrs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey() final  String content;
@override@JsonKey() final  String status;
@override@JsonKey() final  String error;
// The row's write time (P1-e) — the backend has always serialized it; anchors/场次条 order
// turns by message createdAt and blocks WITHIN a turn by seq, but a block-born anchor (a
// dangerous tool, a compaction mark) timestamps by this. Nullable: live frames have no row
// time until the close snapshot lands.
// 行落盘时刻(P1-e)——后端一直在序列化;场次条按回合 createdAt 排、回合内按 seq,块生锚点
// (危险工具/压缩标记)以此计时。可空:live 帧在 close 快照前无行时刻。
@override final  DateTime? createdAt;

/// Create a copy of ChatBlock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatBlockCopyWith<_ChatBlock> get copyWith => __$ChatBlockCopyWithImpl<_ChatBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatBlockToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.parentBlockId, parentBlockId) || other.parentBlockId == parentBlockId)&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other._attrs, _attrs)&&(identical(other.content, content) || other.content == content)&&(identical(other.status, status) || other.status == status)&&(identical(other.error, error) || other.error == error)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,conversationId,messageId,parentBlockId,seq,type,const DeepCollectionEquality().hash(_attrs),content,status,error,createdAt);

@override
String toString() {
  return 'ChatBlock(id: $id, conversationId: $conversationId, messageId: $messageId, parentBlockId: $parentBlockId, seq: $seq, type: $type, attrs: $attrs, content: $content, status: $status, error: $error, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$ChatBlockCopyWith<$Res> implements $ChatBlockCopyWith<$Res> {
  factory _$ChatBlockCopyWith(_ChatBlock value, $Res Function(_ChatBlock) _then) = __$ChatBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, String conversationId, String messageId, String parentBlockId, int seq, String type, Map<String, dynamic>? attrs, String content, String status, String error, DateTime? createdAt
});




}
/// @nodoc
class __$ChatBlockCopyWithImpl<$Res>
    implements _$ChatBlockCopyWith<$Res> {
  __$ChatBlockCopyWithImpl(this._self, this._then);

  final _ChatBlock _self;
  final $Res Function(_ChatBlock) _then;

/// Create a copy of ChatBlock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? conversationId = null,Object? messageId = null,Object? parentBlockId = null,Object? seq = null,Object? type = null,Object? attrs = freezed,Object? content = null,Object? status = null,Object? error = null,Object? createdAt = freezed,}) {
  return _then(_ChatBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,parentBlockId: null == parentBlockId ? _self.parentBlockId : parentBlockId // ignore: cast_nullable_to_non_nullable
as String,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,attrs: freezed == attrs ? _self._attrs : attrs // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$ChatMessage {

 String get id; String get conversationId; String get subagentId; String get role; String get status; String get stopReason; String get errorCode; String get errorMessage; int get inputTokens; int get outputTokens; String get provider; String get modelId; Map<String, dynamic>? get attrs; List<ChatBlock> get blocks; DateTime get createdAt;
/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatMessageCopyWith<ChatMessage> get copyWith => _$ChatMessageCopyWithImpl<ChatMessage>(this as ChatMessage, _$identity);

  /// Serializes this ChatMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.subagentId, subagentId) || other.subagentId == subagentId)&&(identical(other.role, role) || other.role == role)&&(identical(other.status, status) || other.status == status)&&(identical(other.stopReason, stopReason) || other.stopReason == stopReason)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.inputTokens, inputTokens) || other.inputTokens == inputTokens)&&(identical(other.outputTokens, outputTokens) || other.outputTokens == outputTokens)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&const DeepCollectionEquality().equals(other.attrs, attrs)&&const DeepCollectionEquality().equals(other.blocks, blocks)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,conversationId,subagentId,role,status,stopReason,errorCode,errorMessage,inputTokens,outputTokens,provider,modelId,const DeepCollectionEquality().hash(attrs),const DeepCollectionEquality().hash(blocks),createdAt);

@override
String toString() {
  return 'ChatMessage(id: $id, conversationId: $conversationId, subagentId: $subagentId, role: $role, status: $status, stopReason: $stopReason, errorCode: $errorCode, errorMessage: $errorMessage, inputTokens: $inputTokens, outputTokens: $outputTokens, provider: $provider, modelId: $modelId, attrs: $attrs, blocks: $blocks, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $ChatMessageCopyWith<$Res>  {
  factory $ChatMessageCopyWith(ChatMessage value, $Res Function(ChatMessage) _then) = _$ChatMessageCopyWithImpl;
@useResult
$Res call({
 String id, String conversationId, String subagentId, String role, String status, String stopReason, String errorCode, String errorMessage, int inputTokens, int outputTokens, String provider, String modelId, Map<String, dynamic>? attrs, List<ChatBlock> blocks, DateTime createdAt
});




}
/// @nodoc
class _$ChatMessageCopyWithImpl<$Res>
    implements $ChatMessageCopyWith<$Res> {
  _$ChatMessageCopyWithImpl(this._self, this._then);

  final ChatMessage _self;
  final $Res Function(ChatMessage) _then;

/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? conversationId = null,Object? subagentId = null,Object? role = null,Object? status = null,Object? stopReason = null,Object? errorCode = null,Object? errorMessage = null,Object? inputTokens = null,Object? outputTokens = null,Object? provider = null,Object? modelId = null,Object? attrs = freezed,Object? blocks = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,subagentId: null == subagentId ? _self.subagentId : subagentId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,stopReason: null == stopReason ? _self.stopReason : stopReason // ignore: cast_nullable_to_non_nullable
as String,errorCode: null == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String,errorMessage: null == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String,inputTokens: null == inputTokens ? _self.inputTokens : inputTokens // ignore: cast_nullable_to_non_nullable
as int,outputTokens: null == outputTokens ? _self.outputTokens : outputTokens // ignore: cast_nullable_to_non_nullable
as int,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,attrs: freezed == attrs ? _self.attrs : attrs // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,blocks: null == blocks ? _self.blocks : blocks // ignore: cast_nullable_to_non_nullable
as List<ChatBlock>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatMessage].
extension ChatMessagePatterns on ChatMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatMessage value)  $default,){
final _that = this;
switch (_that) {
case _ChatMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatMessage value)?  $default,){
final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String conversationId,  String subagentId,  String role,  String status,  String stopReason,  String errorCode,  String errorMessage,  int inputTokens,  int outputTokens,  String provider,  String modelId,  Map<String, dynamic>? attrs,  List<ChatBlock> blocks,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
return $default(_that.id,_that.conversationId,_that.subagentId,_that.role,_that.status,_that.stopReason,_that.errorCode,_that.errorMessage,_that.inputTokens,_that.outputTokens,_that.provider,_that.modelId,_that.attrs,_that.blocks,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String conversationId,  String subagentId,  String role,  String status,  String stopReason,  String errorCode,  String errorMessage,  int inputTokens,  int outputTokens,  String provider,  String modelId,  Map<String, dynamic>? attrs,  List<ChatBlock> blocks,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _ChatMessage():
return $default(_that.id,_that.conversationId,_that.subagentId,_that.role,_that.status,_that.stopReason,_that.errorCode,_that.errorMessage,_that.inputTokens,_that.outputTokens,_that.provider,_that.modelId,_that.attrs,_that.blocks,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String conversationId,  String subagentId,  String role,  String status,  String stopReason,  String errorCode,  String errorMessage,  int inputTokens,  int outputTokens,  String provider,  String modelId,  Map<String, dynamic>? attrs,  List<ChatBlock> blocks,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
return $default(_that.id,_that.conversationId,_that.subagentId,_that.role,_that.status,_that.stopReason,_that.errorCode,_that.errorMessage,_that.inputTokens,_that.outputTokens,_that.provider,_that.modelId,_that.attrs,_that.blocks,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChatMessage implements ChatMessage {
  const _ChatMessage({required this.id, this.conversationId = '', this.subagentId = '', required this.role, this.status = '', this.stopReason = '', this.errorCode = '', this.errorMessage = '', this.inputTokens = 0, this.outputTokens = 0, this.provider = '', this.modelId = '', final  Map<String, dynamic>? attrs, final  List<ChatBlock> blocks = const <ChatBlock>[], required this.createdAt}): _attrs = attrs,_blocks = blocks;
  factory _ChatMessage.fromJson(Map<String, dynamic> json) => _$ChatMessageFromJson(json);

@override final  String id;
@override@JsonKey() final  String conversationId;
@override@JsonKey() final  String subagentId;
@override final  String role;
@override@JsonKey() final  String status;
@override@JsonKey() final  String stopReason;
@override@JsonKey() final  String errorCode;
@override@JsonKey() final  String errorMessage;
@override@JsonKey() final  int inputTokens;
@override@JsonKey() final  int outputTokens;
@override@JsonKey() final  String provider;
@override@JsonKey() final  String modelId;
 final  Map<String, dynamic>? _attrs;
@override Map<String, dynamic>? get attrs {
  final value = _attrs;
  if (value == null) return null;
  if (_attrs is EqualUnmodifiableMapView) return _attrs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  List<ChatBlock> _blocks;
@override@JsonKey() List<ChatBlock> get blocks {
  if (_blocks is EqualUnmodifiableListView) return _blocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_blocks);
}

@override final  DateTime createdAt;

/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatMessageCopyWith<_ChatMessage> get copyWith => __$ChatMessageCopyWithImpl<_ChatMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.subagentId, subagentId) || other.subagentId == subagentId)&&(identical(other.role, role) || other.role == role)&&(identical(other.status, status) || other.status == status)&&(identical(other.stopReason, stopReason) || other.stopReason == stopReason)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.inputTokens, inputTokens) || other.inputTokens == inputTokens)&&(identical(other.outputTokens, outputTokens) || other.outputTokens == outputTokens)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&const DeepCollectionEquality().equals(other._attrs, _attrs)&&const DeepCollectionEquality().equals(other._blocks, _blocks)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,conversationId,subagentId,role,status,stopReason,errorCode,errorMessage,inputTokens,outputTokens,provider,modelId,const DeepCollectionEquality().hash(_attrs),const DeepCollectionEquality().hash(_blocks),createdAt);

@override
String toString() {
  return 'ChatMessage(id: $id, conversationId: $conversationId, subagentId: $subagentId, role: $role, status: $status, stopReason: $stopReason, errorCode: $errorCode, errorMessage: $errorMessage, inputTokens: $inputTokens, outputTokens: $outputTokens, provider: $provider, modelId: $modelId, attrs: $attrs, blocks: $blocks, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$ChatMessageCopyWith<$Res> implements $ChatMessageCopyWith<$Res> {
  factory _$ChatMessageCopyWith(_ChatMessage value, $Res Function(_ChatMessage) _then) = __$ChatMessageCopyWithImpl;
@override @useResult
$Res call({
 String id, String conversationId, String subagentId, String role, String status, String stopReason, String errorCode, String errorMessage, int inputTokens, int outputTokens, String provider, String modelId, Map<String, dynamic>? attrs, List<ChatBlock> blocks, DateTime createdAt
});




}
/// @nodoc
class __$ChatMessageCopyWithImpl<$Res>
    implements _$ChatMessageCopyWith<$Res> {
  __$ChatMessageCopyWithImpl(this._self, this._then);

  final _ChatMessage _self;
  final $Res Function(_ChatMessage) _then;

/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? conversationId = null,Object? subagentId = null,Object? role = null,Object? status = null,Object? stopReason = null,Object? errorCode = null,Object? errorMessage = null,Object? inputTokens = null,Object? outputTokens = null,Object? provider = null,Object? modelId = null,Object? attrs = freezed,Object? blocks = null,Object? createdAt = null,}) {
  return _then(_ChatMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,subagentId: null == subagentId ? _self.subagentId : subagentId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,stopReason: null == stopReason ? _self.stopReason : stopReason // ignore: cast_nullable_to_non_nullable
as String,errorCode: null == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String,errorMessage: null == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String,inputTokens: null == inputTokens ? _self.inputTokens : inputTokens // ignore: cast_nullable_to_non_nullable
as int,outputTokens: null == outputTokens ? _self.outputTokens : outputTokens // ignore: cast_nullable_to_non_nullable
as int,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,attrs: freezed == attrs ? _self._attrs : attrs // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,blocks: null == blocks ? _self._blocks : blocks // ignore: cast_nullable_to_non_nullable
as List<ChatBlock>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
