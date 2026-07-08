// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transcript_nav.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MessagesWindow {

// Wire key `data` — the window envelope keeps its coordinates top-level BESIDE the array
// (the same rule as the paged envelope). 线缆键 `data`——窗 envelope 坐标在顶层与数组并列。
@JsonKey(name: 'data') List<ChatMessage> get messages; String get targetId; String get olderCursor; String get newerCursor; bool get hasOlder; bool get hasNewer;
/// Create a copy of MessagesWindow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagesWindowCopyWith<MessagesWindow> get copyWith => _$MessagesWindowCopyWithImpl<MessagesWindow>(this as MessagesWindow, _$identity);

  /// Serializes this MessagesWindow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagesWindow&&const DeepCollectionEquality().equals(other.messages, messages)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.olderCursor, olderCursor) || other.olderCursor == olderCursor)&&(identical(other.newerCursor, newerCursor) || other.newerCursor == newerCursor)&&(identical(other.hasOlder, hasOlder) || other.hasOlder == hasOlder)&&(identical(other.hasNewer, hasNewer) || other.hasNewer == hasNewer));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(messages),targetId,olderCursor,newerCursor,hasOlder,hasNewer);

@override
String toString() {
  return 'MessagesWindow(messages: $messages, targetId: $targetId, olderCursor: $olderCursor, newerCursor: $newerCursor, hasOlder: $hasOlder, hasNewer: $hasNewer)';
}


}

/// @nodoc
abstract mixin class $MessagesWindowCopyWith<$Res>  {
  factory $MessagesWindowCopyWith(MessagesWindow value, $Res Function(MessagesWindow) _then) = _$MessagesWindowCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'data') List<ChatMessage> messages, String targetId, String olderCursor, String newerCursor, bool hasOlder, bool hasNewer
});




}
/// @nodoc
class _$MessagesWindowCopyWithImpl<$Res>
    implements $MessagesWindowCopyWith<$Res> {
  _$MessagesWindowCopyWithImpl(this._self, this._then);

  final MessagesWindow _self;
  final $Res Function(MessagesWindow) _then;

/// Create a copy of MessagesWindow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messages = null,Object? targetId = null,Object? olderCursor = null,Object? newerCursor = null,Object? hasOlder = null,Object? hasNewer = null,}) {
  return _then(_self.copyWith(
messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<ChatMessage>,targetId: null == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String,olderCursor: null == olderCursor ? _self.olderCursor : olderCursor // ignore: cast_nullable_to_non_nullable
as String,newerCursor: null == newerCursor ? _self.newerCursor : newerCursor // ignore: cast_nullable_to_non_nullable
as String,hasOlder: null == hasOlder ? _self.hasOlder : hasOlder // ignore: cast_nullable_to_non_nullable
as bool,hasNewer: null == hasNewer ? _self.hasNewer : hasNewer // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [MessagesWindow].
extension MessagesWindowPatterns on MessagesWindow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessagesWindow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessagesWindow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessagesWindow value)  $default,){
final _that = this;
switch (_that) {
case _MessagesWindow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessagesWindow value)?  $default,){
final _that = this;
switch (_that) {
case _MessagesWindow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'data')  List<ChatMessage> messages,  String targetId,  String olderCursor,  String newerCursor,  bool hasOlder,  bool hasNewer)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessagesWindow() when $default != null:
return $default(_that.messages,_that.targetId,_that.olderCursor,_that.newerCursor,_that.hasOlder,_that.hasNewer);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'data')  List<ChatMessage> messages,  String targetId,  String olderCursor,  String newerCursor,  bool hasOlder,  bool hasNewer)  $default,) {final _that = this;
switch (_that) {
case _MessagesWindow():
return $default(_that.messages,_that.targetId,_that.olderCursor,_that.newerCursor,_that.hasOlder,_that.hasNewer);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'data')  List<ChatMessage> messages,  String targetId,  String olderCursor,  String newerCursor,  bool hasOlder,  bool hasNewer)?  $default,) {final _that = this;
switch (_that) {
case _MessagesWindow() when $default != null:
return $default(_that.messages,_that.targetId,_that.olderCursor,_that.newerCursor,_that.hasOlder,_that.hasNewer);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessagesWindow implements MessagesWindow {
  const _MessagesWindow({@JsonKey(name: 'data') final  List<ChatMessage> messages = const <ChatMessage>[], this.targetId = '', this.olderCursor = '', this.newerCursor = '', this.hasOlder = false, this.hasNewer = false}): _messages = messages;
  factory _MessagesWindow.fromJson(Map<String, dynamic> json) => _$MessagesWindowFromJson(json);

// Wire key `data` — the window envelope keeps its coordinates top-level BESIDE the array
// (the same rule as the paged envelope). 线缆键 `data`——窗 envelope 坐标在顶层与数组并列。
 final  List<ChatMessage> _messages;
// Wire key `data` — the window envelope keeps its coordinates top-level BESIDE the array
// (the same rule as the paged envelope). 线缆键 `data`——窗 envelope 坐标在顶层与数组并列。
@override@JsonKey(name: 'data') List<ChatMessage> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}

@override@JsonKey() final  String targetId;
@override@JsonKey() final  String olderCursor;
@override@JsonKey() final  String newerCursor;
@override@JsonKey() final  bool hasOlder;
@override@JsonKey() final  bool hasNewer;

/// Create a copy of MessagesWindow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessagesWindowCopyWith<_MessagesWindow> get copyWith => __$MessagesWindowCopyWithImpl<_MessagesWindow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessagesWindowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessagesWindow&&const DeepCollectionEquality().equals(other._messages, _messages)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.olderCursor, olderCursor) || other.olderCursor == olderCursor)&&(identical(other.newerCursor, newerCursor) || other.newerCursor == newerCursor)&&(identical(other.hasOlder, hasOlder) || other.hasOlder == hasOlder)&&(identical(other.hasNewer, hasNewer) || other.hasNewer == hasNewer));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_messages),targetId,olderCursor,newerCursor,hasOlder,hasNewer);

@override
String toString() {
  return 'MessagesWindow(messages: $messages, targetId: $targetId, olderCursor: $olderCursor, newerCursor: $newerCursor, hasOlder: $hasOlder, hasNewer: $hasNewer)';
}


}

/// @nodoc
abstract mixin class _$MessagesWindowCopyWith<$Res> implements $MessagesWindowCopyWith<$Res> {
  factory _$MessagesWindowCopyWith(_MessagesWindow value, $Res Function(_MessagesWindow) _then) = __$MessagesWindowCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'data') List<ChatMessage> messages, String targetId, String olderCursor, String newerCursor, bool hasOlder, bool hasNewer
});




}
/// @nodoc
class __$MessagesWindowCopyWithImpl<$Res>
    implements _$MessagesWindowCopyWith<$Res> {
  __$MessagesWindowCopyWithImpl(this._self, this._then);

  final _MessagesWindow _self;
  final $Res Function(_MessagesWindow) _then;

/// Create a copy of MessagesWindow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messages = null,Object? targetId = null,Object? olderCursor = null,Object? newerCursor = null,Object? hasOlder = null,Object? hasNewer = null,}) {
  return _then(_MessagesWindow(
messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<ChatMessage>,targetId: null == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String,olderCursor: null == olderCursor ? _self.olderCursor : olderCursor // ignore: cast_nullable_to_non_nullable
as String,newerCursor: null == newerCursor ? _self.newerCursor : newerCursor // ignore: cast_nullable_to_non_nullable
as String,hasOlder: null == hasOlder ? _self.hasOlder : hasOlder // ignore: cast_nullable_to_non_nullable
as bool,hasNewer: null == hasNewer ? _self.hasNewer : hasNewer // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$TranscriptAnchor {

 String get kind; String get messageId; String get blockId; String get title; int get count; DateTime get at;
/// Create a copy of TranscriptAnchor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TranscriptAnchorCopyWith<TranscriptAnchor> get copyWith => _$TranscriptAnchorCopyWithImpl<TranscriptAnchor>(this as TranscriptAnchor, _$identity);

  /// Serializes this TranscriptAnchor to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TranscriptAnchor&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.blockId, blockId) || other.blockId == blockId)&&(identical(other.title, title) || other.title == title)&&(identical(other.count, count) || other.count == count)&&(identical(other.at, at) || other.at == at));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,messageId,blockId,title,count,at);

@override
String toString() {
  return 'TranscriptAnchor(kind: $kind, messageId: $messageId, blockId: $blockId, title: $title, count: $count, at: $at)';
}


}

/// @nodoc
abstract mixin class $TranscriptAnchorCopyWith<$Res>  {
  factory $TranscriptAnchorCopyWith(TranscriptAnchor value, $Res Function(TranscriptAnchor) _then) = _$TranscriptAnchorCopyWithImpl;
@useResult
$Res call({
 String kind, String messageId, String blockId, String title, int count, DateTime at
});




}
/// @nodoc
class _$TranscriptAnchorCopyWithImpl<$Res>
    implements $TranscriptAnchorCopyWith<$Res> {
  _$TranscriptAnchorCopyWithImpl(this._self, this._then);

  final TranscriptAnchor _self;
  final $Res Function(TranscriptAnchor) _then;

/// Create a copy of TranscriptAnchor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? messageId = null,Object? blockId = null,Object? title = null,Object? count = null,Object? at = null,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,blockId: null == blockId ? _self.blockId : blockId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [TranscriptAnchor].
extension TranscriptAnchorPatterns on TranscriptAnchor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TranscriptAnchor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TranscriptAnchor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TranscriptAnchor value)  $default,){
final _that = this;
switch (_that) {
case _TranscriptAnchor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TranscriptAnchor value)?  $default,){
final _that = this;
switch (_that) {
case _TranscriptAnchor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String kind,  String messageId,  String blockId,  String title,  int count,  DateTime at)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TranscriptAnchor() when $default != null:
return $default(_that.kind,_that.messageId,_that.blockId,_that.title,_that.count,_that.at);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String kind,  String messageId,  String blockId,  String title,  int count,  DateTime at)  $default,) {final _that = this;
switch (_that) {
case _TranscriptAnchor():
return $default(_that.kind,_that.messageId,_that.blockId,_that.title,_that.count,_that.at);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String kind,  String messageId,  String blockId,  String title,  int count,  DateTime at)?  $default,) {final _that = this;
switch (_that) {
case _TranscriptAnchor() when $default != null:
return $default(_that.kind,_that.messageId,_that.blockId,_that.title,_that.count,_that.at);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TranscriptAnchor implements TranscriptAnchor {
  const _TranscriptAnchor({required this.kind, this.messageId = '', this.blockId = '', this.title = '', this.count = 0, required this.at});
  factory _TranscriptAnchor.fromJson(Map<String, dynamic> json) => _$TranscriptAnchorFromJson(json);

@override final  String kind;
@override@JsonKey() final  String messageId;
@override@JsonKey() final  String blockId;
@override@JsonKey() final  String title;
@override@JsonKey() final  int count;
@override final  DateTime at;

/// Create a copy of TranscriptAnchor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TranscriptAnchorCopyWith<_TranscriptAnchor> get copyWith => __$TranscriptAnchorCopyWithImpl<_TranscriptAnchor>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TranscriptAnchorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TranscriptAnchor&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.blockId, blockId) || other.blockId == blockId)&&(identical(other.title, title) || other.title == title)&&(identical(other.count, count) || other.count == count)&&(identical(other.at, at) || other.at == at));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,messageId,blockId,title,count,at);

@override
String toString() {
  return 'TranscriptAnchor(kind: $kind, messageId: $messageId, blockId: $blockId, title: $title, count: $count, at: $at)';
}


}

/// @nodoc
abstract mixin class _$TranscriptAnchorCopyWith<$Res> implements $TranscriptAnchorCopyWith<$Res> {
  factory _$TranscriptAnchorCopyWith(_TranscriptAnchor value, $Res Function(_TranscriptAnchor) _then) = __$TranscriptAnchorCopyWithImpl;
@override @useResult
$Res call({
 String kind, String messageId, String blockId, String title, int count, DateTime at
});




}
/// @nodoc
class __$TranscriptAnchorCopyWithImpl<$Res>
    implements _$TranscriptAnchorCopyWith<$Res> {
  __$TranscriptAnchorCopyWithImpl(this._self, this._then);

  final _TranscriptAnchor _self;
  final $Res Function(_TranscriptAnchor) _then;

/// Create a copy of TranscriptAnchor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? messageId = null,Object? blockId = null,Object? title = null,Object? count = null,Object? at = null,}) {
  return _then(_TranscriptAnchor(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,blockId: null == blockId ? _self.blockId : blockId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
