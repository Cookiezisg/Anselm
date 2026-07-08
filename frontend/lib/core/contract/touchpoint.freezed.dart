// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'touchpoint.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Touchpoint {

 String get id; String get conversationId; String get itemKind; String get itemId; String get itemName;@JsonKey(unknownEnumValue: TouchpointVerb.unknown) TouchpointVerb get verb;@JsonKey(unknownEnumValue: TouchpointActor.unknown) TouchpointActor get lastActor; int get count; DateTime get firstAt; DateTime get lastAt; String get lastMessageId;
/// Create a copy of Touchpoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TouchpointCopyWith<Touchpoint> get copyWith => _$TouchpointCopyWithImpl<Touchpoint>(this as Touchpoint, _$identity);

  /// Serializes this Touchpoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Touchpoint&&(identical(other.id, id) || other.id == id)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.itemKind, itemKind) || other.itemKind == itemKind)&&(identical(other.itemId, itemId) || other.itemId == itemId)&&(identical(other.itemName, itemName) || other.itemName == itemName)&&(identical(other.verb, verb) || other.verb == verb)&&(identical(other.lastActor, lastActor) || other.lastActor == lastActor)&&(identical(other.count, count) || other.count == count)&&(identical(other.firstAt, firstAt) || other.firstAt == firstAt)&&(identical(other.lastAt, lastAt) || other.lastAt == lastAt)&&(identical(other.lastMessageId, lastMessageId) || other.lastMessageId == lastMessageId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,conversationId,itemKind,itemId,itemName,verb,lastActor,count,firstAt,lastAt,lastMessageId);

@override
String toString() {
  return 'Touchpoint(id: $id, conversationId: $conversationId, itemKind: $itemKind, itemId: $itemId, itemName: $itemName, verb: $verb, lastActor: $lastActor, count: $count, firstAt: $firstAt, lastAt: $lastAt, lastMessageId: $lastMessageId)';
}


}

/// @nodoc
abstract mixin class $TouchpointCopyWith<$Res>  {
  factory $TouchpointCopyWith(Touchpoint value, $Res Function(Touchpoint) _then) = _$TouchpointCopyWithImpl;
@useResult
$Res call({
 String id, String conversationId, String itemKind, String itemId, String itemName,@JsonKey(unknownEnumValue: TouchpointVerb.unknown) TouchpointVerb verb,@JsonKey(unknownEnumValue: TouchpointActor.unknown) TouchpointActor lastActor, int count, DateTime firstAt, DateTime lastAt, String lastMessageId
});




}
/// @nodoc
class _$TouchpointCopyWithImpl<$Res>
    implements $TouchpointCopyWith<$Res> {
  _$TouchpointCopyWithImpl(this._self, this._then);

  final Touchpoint _self;
  final $Res Function(Touchpoint) _then;

/// Create a copy of Touchpoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? conversationId = null,Object? itemKind = null,Object? itemId = null,Object? itemName = null,Object? verb = null,Object? lastActor = null,Object? count = null,Object? firstAt = null,Object? lastAt = null,Object? lastMessageId = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,itemKind: null == itemKind ? _self.itemKind : itemKind // ignore: cast_nullable_to_non_nullable
as String,itemId: null == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as String,itemName: null == itemName ? _self.itemName : itemName // ignore: cast_nullable_to_non_nullable
as String,verb: null == verb ? _self.verb : verb // ignore: cast_nullable_to_non_nullable
as TouchpointVerb,lastActor: null == lastActor ? _self.lastActor : lastActor // ignore: cast_nullable_to_non_nullable
as TouchpointActor,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,firstAt: null == firstAt ? _self.firstAt : firstAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastAt: null == lastAt ? _self.lastAt : lastAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastMessageId: null == lastMessageId ? _self.lastMessageId : lastMessageId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Touchpoint].
extension TouchpointPatterns on Touchpoint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Touchpoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Touchpoint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Touchpoint value)  $default,){
final _that = this;
switch (_that) {
case _Touchpoint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Touchpoint value)?  $default,){
final _that = this;
switch (_that) {
case _Touchpoint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String conversationId,  String itemKind,  String itemId,  String itemName, @JsonKey(unknownEnumValue: TouchpointVerb.unknown)  TouchpointVerb verb, @JsonKey(unknownEnumValue: TouchpointActor.unknown)  TouchpointActor lastActor,  int count,  DateTime firstAt,  DateTime lastAt,  String lastMessageId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Touchpoint() when $default != null:
return $default(_that.id,_that.conversationId,_that.itemKind,_that.itemId,_that.itemName,_that.verb,_that.lastActor,_that.count,_that.firstAt,_that.lastAt,_that.lastMessageId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String conversationId,  String itemKind,  String itemId,  String itemName, @JsonKey(unknownEnumValue: TouchpointVerb.unknown)  TouchpointVerb verb, @JsonKey(unknownEnumValue: TouchpointActor.unknown)  TouchpointActor lastActor,  int count,  DateTime firstAt,  DateTime lastAt,  String lastMessageId)  $default,) {final _that = this;
switch (_that) {
case _Touchpoint():
return $default(_that.id,_that.conversationId,_that.itemKind,_that.itemId,_that.itemName,_that.verb,_that.lastActor,_that.count,_that.firstAt,_that.lastAt,_that.lastMessageId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String conversationId,  String itemKind,  String itemId,  String itemName, @JsonKey(unknownEnumValue: TouchpointVerb.unknown)  TouchpointVerb verb, @JsonKey(unknownEnumValue: TouchpointActor.unknown)  TouchpointActor lastActor,  int count,  DateTime firstAt,  DateTime lastAt,  String lastMessageId)?  $default,) {final _that = this;
switch (_that) {
case _Touchpoint() when $default != null:
return $default(_that.id,_that.conversationId,_that.itemKind,_that.itemId,_that.itemName,_that.verb,_that.lastActor,_that.count,_that.firstAt,_that.lastAt,_that.lastMessageId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Touchpoint extends Touchpoint {
  const _Touchpoint({required this.id, this.conversationId = '', this.itemKind = '', this.itemId = '', this.itemName = '', @JsonKey(unknownEnumValue: TouchpointVerb.unknown) this.verb = TouchpointVerb.unknown, @JsonKey(unknownEnumValue: TouchpointActor.unknown) this.lastActor = TouchpointActor.unknown, this.count = 0, required this.firstAt, required this.lastAt, this.lastMessageId = ''}): super._();
  factory _Touchpoint.fromJson(Map<String, dynamic> json) => _$TouchpointFromJson(json);

@override final  String id;
@override@JsonKey() final  String conversationId;
@override@JsonKey() final  String itemKind;
@override@JsonKey() final  String itemId;
@override@JsonKey() final  String itemName;
@override@JsonKey(unknownEnumValue: TouchpointVerb.unknown) final  TouchpointVerb verb;
@override@JsonKey(unknownEnumValue: TouchpointActor.unknown) final  TouchpointActor lastActor;
@override@JsonKey() final  int count;
@override final  DateTime firstAt;
@override final  DateTime lastAt;
@override@JsonKey() final  String lastMessageId;

/// Create a copy of Touchpoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TouchpointCopyWith<_Touchpoint> get copyWith => __$TouchpointCopyWithImpl<_Touchpoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TouchpointToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Touchpoint&&(identical(other.id, id) || other.id == id)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.itemKind, itemKind) || other.itemKind == itemKind)&&(identical(other.itemId, itemId) || other.itemId == itemId)&&(identical(other.itemName, itemName) || other.itemName == itemName)&&(identical(other.verb, verb) || other.verb == verb)&&(identical(other.lastActor, lastActor) || other.lastActor == lastActor)&&(identical(other.count, count) || other.count == count)&&(identical(other.firstAt, firstAt) || other.firstAt == firstAt)&&(identical(other.lastAt, lastAt) || other.lastAt == lastAt)&&(identical(other.lastMessageId, lastMessageId) || other.lastMessageId == lastMessageId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,conversationId,itemKind,itemId,itemName,verb,lastActor,count,firstAt,lastAt,lastMessageId);

@override
String toString() {
  return 'Touchpoint(id: $id, conversationId: $conversationId, itemKind: $itemKind, itemId: $itemId, itemName: $itemName, verb: $verb, lastActor: $lastActor, count: $count, firstAt: $firstAt, lastAt: $lastAt, lastMessageId: $lastMessageId)';
}


}

/// @nodoc
abstract mixin class _$TouchpointCopyWith<$Res> implements $TouchpointCopyWith<$Res> {
  factory _$TouchpointCopyWith(_Touchpoint value, $Res Function(_Touchpoint) _then) = __$TouchpointCopyWithImpl;
@override @useResult
$Res call({
 String id, String conversationId, String itemKind, String itemId, String itemName,@JsonKey(unknownEnumValue: TouchpointVerb.unknown) TouchpointVerb verb,@JsonKey(unknownEnumValue: TouchpointActor.unknown) TouchpointActor lastActor, int count, DateTime firstAt, DateTime lastAt, String lastMessageId
});




}
/// @nodoc
class __$TouchpointCopyWithImpl<$Res>
    implements _$TouchpointCopyWith<$Res> {
  __$TouchpointCopyWithImpl(this._self, this._then);

  final _Touchpoint _self;
  final $Res Function(_Touchpoint) _then;

/// Create a copy of Touchpoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? conversationId = null,Object? itemKind = null,Object? itemId = null,Object? itemName = null,Object? verb = null,Object? lastActor = null,Object? count = null,Object? firstAt = null,Object? lastAt = null,Object? lastMessageId = null,}) {
  return _then(_Touchpoint(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,itemKind: null == itemKind ? _self.itemKind : itemKind // ignore: cast_nullable_to_non_nullable
as String,itemId: null == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as String,itemName: null == itemName ? _self.itemName : itemName // ignore: cast_nullable_to_non_nullable
as String,verb: null == verb ? _self.verb : verb // ignore: cast_nullable_to_non_nullable
as TouchpointVerb,lastActor: null == lastActor ? _self.lastActor : lastActor // ignore: cast_nullable_to_non_nullable
as TouchpointActor,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,firstAt: null == firstAt ? _self.firstAt : firstAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastAt: null == lastAt ? _self.lastAt : lastAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastMessageId: null == lastMessageId ? _self.lastMessageId : lastMessageId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
