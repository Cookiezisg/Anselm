// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'relation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EntityRelation {

 String get id; String get kind; String get fromKind; String get fromId; String get fromName; String get toKind; String get toId; String get toName;
/// Create a copy of EntityRelation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EntityRelationCopyWith<EntityRelation> get copyWith => _$EntityRelationCopyWithImpl<EntityRelation>(this as EntityRelation, _$identity);

  /// Serializes this EntityRelation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EntityRelation&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.fromKind, fromKind) || other.fromKind == fromKind)&&(identical(other.fromId, fromId) || other.fromId == fromId)&&(identical(other.fromName, fromName) || other.fromName == fromName)&&(identical(other.toKind, toKind) || other.toKind == toKind)&&(identical(other.toId, toId) || other.toId == toId)&&(identical(other.toName, toName) || other.toName == toName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,fromKind,fromId,fromName,toKind,toId,toName);

@override
String toString() {
  return 'EntityRelation(id: $id, kind: $kind, fromKind: $fromKind, fromId: $fromId, fromName: $fromName, toKind: $toKind, toId: $toId, toName: $toName)';
}


}

/// @nodoc
abstract mixin class $EntityRelationCopyWith<$Res>  {
  factory $EntityRelationCopyWith(EntityRelation value, $Res Function(EntityRelation) _then) = _$EntityRelationCopyWithImpl;
@useResult
$Res call({
 String id, String kind, String fromKind, String fromId, String fromName, String toKind, String toId, String toName
});




}
/// @nodoc
class _$EntityRelationCopyWithImpl<$Res>
    implements $EntityRelationCopyWith<$Res> {
  _$EntityRelationCopyWithImpl(this._self, this._then);

  final EntityRelation _self;
  final $Res Function(EntityRelation) _then;

/// Create a copy of EntityRelation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? fromKind = null,Object? fromId = null,Object? fromName = null,Object? toKind = null,Object? toId = null,Object? toName = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,fromKind: null == fromKind ? _self.fromKind : fromKind // ignore: cast_nullable_to_non_nullable
as String,fromId: null == fromId ? _self.fromId : fromId // ignore: cast_nullable_to_non_nullable
as String,fromName: null == fromName ? _self.fromName : fromName // ignore: cast_nullable_to_non_nullable
as String,toKind: null == toKind ? _self.toKind : toKind // ignore: cast_nullable_to_non_nullable
as String,toId: null == toId ? _self.toId : toId // ignore: cast_nullable_to_non_nullable
as String,toName: null == toName ? _self.toName : toName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [EntityRelation].
extension EntityRelationPatterns on EntityRelation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EntityRelation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EntityRelation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EntityRelation value)  $default,){
final _that = this;
switch (_that) {
case _EntityRelation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EntityRelation value)?  $default,){
final _that = this;
switch (_that) {
case _EntityRelation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String kind,  String fromKind,  String fromId,  String fromName,  String toKind,  String toId,  String toName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EntityRelation() when $default != null:
return $default(_that.id,_that.kind,_that.fromKind,_that.fromId,_that.fromName,_that.toKind,_that.toId,_that.toName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String kind,  String fromKind,  String fromId,  String fromName,  String toKind,  String toId,  String toName)  $default,) {final _that = this;
switch (_that) {
case _EntityRelation():
return $default(_that.id,_that.kind,_that.fromKind,_that.fromId,_that.fromName,_that.toKind,_that.toId,_that.toName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String kind,  String fromKind,  String fromId,  String fromName,  String toKind,  String toId,  String toName)?  $default,) {final _that = this;
switch (_that) {
case _EntityRelation() when $default != null:
return $default(_that.id,_that.kind,_that.fromKind,_that.fromId,_that.fromName,_that.toKind,_that.toId,_that.toName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EntityRelation implements EntityRelation {
  const _EntityRelation({required this.id, this.kind = '', this.fromKind = '', this.fromId = '', this.fromName = '', this.toKind = '', this.toId = '', this.toName = ''});
  factory _EntityRelation.fromJson(Map<String, dynamic> json) => _$EntityRelationFromJson(json);

@override final  String id;
@override@JsonKey() final  String kind;
@override@JsonKey() final  String fromKind;
@override@JsonKey() final  String fromId;
@override@JsonKey() final  String fromName;
@override@JsonKey() final  String toKind;
@override@JsonKey() final  String toId;
@override@JsonKey() final  String toName;

/// Create a copy of EntityRelation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EntityRelationCopyWith<_EntityRelation> get copyWith => __$EntityRelationCopyWithImpl<_EntityRelation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EntityRelationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EntityRelation&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.fromKind, fromKind) || other.fromKind == fromKind)&&(identical(other.fromId, fromId) || other.fromId == fromId)&&(identical(other.fromName, fromName) || other.fromName == fromName)&&(identical(other.toKind, toKind) || other.toKind == toKind)&&(identical(other.toId, toId) || other.toId == toId)&&(identical(other.toName, toName) || other.toName == toName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,fromKind,fromId,fromName,toKind,toId,toName);

@override
String toString() {
  return 'EntityRelation(id: $id, kind: $kind, fromKind: $fromKind, fromId: $fromId, fromName: $fromName, toKind: $toKind, toId: $toId, toName: $toName)';
}


}

/// @nodoc
abstract mixin class _$EntityRelationCopyWith<$Res> implements $EntityRelationCopyWith<$Res> {
  factory _$EntityRelationCopyWith(_EntityRelation value, $Res Function(_EntityRelation) _then) = __$EntityRelationCopyWithImpl;
@override @useResult
$Res call({
 String id, String kind, String fromKind, String fromId, String fromName, String toKind, String toId, String toName
});




}
/// @nodoc
class __$EntityRelationCopyWithImpl<$Res>
    implements _$EntityRelationCopyWith<$Res> {
  __$EntityRelationCopyWithImpl(this._self, this._then);

  final _EntityRelation _self;
  final $Res Function(_EntityRelation) _then;

/// Create a copy of EntityRelation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? fromKind = null,Object? fromId = null,Object? fromName = null,Object? toKind = null,Object? toId = null,Object? toName = null,}) {
  return _then(_EntityRelation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,fromKind: null == fromKind ? _self.fromKind : fromKind // ignore: cast_nullable_to_non_nullable
as String,fromId: null == fromId ? _self.fromId : fromId // ignore: cast_nullable_to_non_nullable
as String,fromName: null == fromName ? _self.fromName : fromName // ignore: cast_nullable_to_non_nullable
as String,toKind: null == toKind ? _self.toKind : toKind // ignore: cast_nullable_to_non_nullable
as String,toId: null == toId ? _self.toId : toId // ignore: cast_nullable_to_non_nullable
as String,toName: null == toName ? _self.toName : toName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
