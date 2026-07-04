// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'entity_row.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$EntityRow {

 EntityKind get kind; String get id; String get name; String get description; List<String> get tags; DateTime get createdAt; DateTime get updatedAt;// handler badges
 String? get configState; String? get runtimeState; int get missingConfigCount;// workflow badges
 bool? get active; String? get lifecycleState; bool get needsAttention;// trigger badge — read-derived: is its listener hot (≥1 active workflow references it). trigger 徽:listener 热否。
 bool? get listening;
/// Create a copy of EntityRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EntityRowCopyWith<EntityRow> get copyWith => _$EntityRowCopyWithImpl<EntityRow>(this as EntityRow, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EntityRow&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.configState, configState) || other.configState == configState)&&(identical(other.runtimeState, runtimeState) || other.runtimeState == runtimeState)&&(identical(other.missingConfigCount, missingConfigCount) || other.missingConfigCount == missingConfigCount)&&(identical(other.active, active) || other.active == active)&&(identical(other.lifecycleState, lifecycleState) || other.lifecycleState == lifecycleState)&&(identical(other.needsAttention, needsAttention) || other.needsAttention == needsAttention)&&(identical(other.listening, listening) || other.listening == listening));
}


@override
int get hashCode => Object.hash(runtimeType,kind,id,name,description,const DeepCollectionEquality().hash(tags),createdAt,updatedAt,configState,runtimeState,missingConfigCount,active,lifecycleState,needsAttention,listening);

@override
String toString() {
  return 'EntityRow(kind: $kind, id: $id, name: $name, description: $description, tags: $tags, createdAt: $createdAt, updatedAt: $updatedAt, configState: $configState, runtimeState: $runtimeState, missingConfigCount: $missingConfigCount, active: $active, lifecycleState: $lifecycleState, needsAttention: $needsAttention, listening: $listening)';
}


}

/// @nodoc
abstract mixin class $EntityRowCopyWith<$Res>  {
  factory $EntityRowCopyWith(EntityRow value, $Res Function(EntityRow) _then) = _$EntityRowCopyWithImpl;
@useResult
$Res call({
 EntityKind kind, String id, String name, String description, List<String> tags, DateTime createdAt, DateTime updatedAt, String? configState, String? runtimeState, int missingConfigCount, bool? active, String? lifecycleState, bool needsAttention, bool? listening
});




}
/// @nodoc
class _$EntityRowCopyWithImpl<$Res>
    implements $EntityRowCopyWith<$Res> {
  _$EntityRowCopyWithImpl(this._self, this._then);

  final EntityRow _self;
  final $Res Function(EntityRow) _then;

/// Create a copy of EntityRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? id = null,Object? name = null,Object? description = null,Object? tags = null,Object? createdAt = null,Object? updatedAt = null,Object? configState = freezed,Object? runtimeState = freezed,Object? missingConfigCount = null,Object? active = freezed,Object? lifecycleState = freezed,Object? needsAttention = null,Object? listening = freezed,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as EntityKind,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,configState: freezed == configState ? _self.configState : configState // ignore: cast_nullable_to_non_nullable
as String?,runtimeState: freezed == runtimeState ? _self.runtimeState : runtimeState // ignore: cast_nullable_to_non_nullable
as String?,missingConfigCount: null == missingConfigCount ? _self.missingConfigCount : missingConfigCount // ignore: cast_nullable_to_non_nullable
as int,active: freezed == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool?,lifecycleState: freezed == lifecycleState ? _self.lifecycleState : lifecycleState // ignore: cast_nullable_to_non_nullable
as String?,needsAttention: null == needsAttention ? _self.needsAttention : needsAttention // ignore: cast_nullable_to_non_nullable
as bool,listening: freezed == listening ? _self.listening : listening // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [EntityRow].
extension EntityRowPatterns on EntityRow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EntityRow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EntityRow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EntityRow value)  $default,){
final _that = this;
switch (_that) {
case _EntityRow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EntityRow value)?  $default,){
final _that = this;
switch (_that) {
case _EntityRow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( EntityKind kind,  String id,  String name,  String description,  List<String> tags,  DateTime createdAt,  DateTime updatedAt,  String? configState,  String? runtimeState,  int missingConfigCount,  bool? active,  String? lifecycleState,  bool needsAttention,  bool? listening)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EntityRow() when $default != null:
return $default(_that.kind,_that.id,_that.name,_that.description,_that.tags,_that.createdAt,_that.updatedAt,_that.configState,_that.runtimeState,_that.missingConfigCount,_that.active,_that.lifecycleState,_that.needsAttention,_that.listening);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( EntityKind kind,  String id,  String name,  String description,  List<String> tags,  DateTime createdAt,  DateTime updatedAt,  String? configState,  String? runtimeState,  int missingConfigCount,  bool? active,  String? lifecycleState,  bool needsAttention,  bool? listening)  $default,) {final _that = this;
switch (_that) {
case _EntityRow():
return $default(_that.kind,_that.id,_that.name,_that.description,_that.tags,_that.createdAt,_that.updatedAt,_that.configState,_that.runtimeState,_that.missingConfigCount,_that.active,_that.lifecycleState,_that.needsAttention,_that.listening);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( EntityKind kind,  String id,  String name,  String description,  List<String> tags,  DateTime createdAt,  DateTime updatedAt,  String? configState,  String? runtimeState,  int missingConfigCount,  bool? active,  String? lifecycleState,  bool needsAttention,  bool? listening)?  $default,) {final _that = this;
switch (_that) {
case _EntityRow() when $default != null:
return $default(_that.kind,_that.id,_that.name,_that.description,_that.tags,_that.createdAt,_that.updatedAt,_that.configState,_that.runtimeState,_that.missingConfigCount,_that.active,_that.lifecycleState,_that.needsAttention,_that.listening);case _:
  return null;

}
}

}

/// @nodoc


class _EntityRow implements EntityRow {
  const _EntityRow({required this.kind, required this.id, this.name = '', this.description = '', final  List<String> tags = const <String>[], required this.createdAt, required this.updatedAt, this.configState, this.runtimeState, this.missingConfigCount = 0, this.active, this.lifecycleState, this.needsAttention = false, this.listening}): _tags = tags;
  

@override final  EntityKind kind;
@override final  String id;
@override@JsonKey() final  String name;
@override@JsonKey() final  String description;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

@override final  DateTime createdAt;
@override final  DateTime updatedAt;
// handler badges
@override final  String? configState;
@override final  String? runtimeState;
@override@JsonKey() final  int missingConfigCount;
// workflow badges
@override final  bool? active;
@override final  String? lifecycleState;
@override@JsonKey() final  bool needsAttention;
// trigger badge — read-derived: is its listener hot (≥1 active workflow references it). trigger 徽:listener 热否。
@override final  bool? listening;

/// Create a copy of EntityRow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EntityRowCopyWith<_EntityRow> get copyWith => __$EntityRowCopyWithImpl<_EntityRow>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EntityRow&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.configState, configState) || other.configState == configState)&&(identical(other.runtimeState, runtimeState) || other.runtimeState == runtimeState)&&(identical(other.missingConfigCount, missingConfigCount) || other.missingConfigCount == missingConfigCount)&&(identical(other.active, active) || other.active == active)&&(identical(other.lifecycleState, lifecycleState) || other.lifecycleState == lifecycleState)&&(identical(other.needsAttention, needsAttention) || other.needsAttention == needsAttention)&&(identical(other.listening, listening) || other.listening == listening));
}


@override
int get hashCode => Object.hash(runtimeType,kind,id,name,description,const DeepCollectionEquality().hash(_tags),createdAt,updatedAt,configState,runtimeState,missingConfigCount,active,lifecycleState,needsAttention,listening);

@override
String toString() {
  return 'EntityRow(kind: $kind, id: $id, name: $name, description: $description, tags: $tags, createdAt: $createdAt, updatedAt: $updatedAt, configState: $configState, runtimeState: $runtimeState, missingConfigCount: $missingConfigCount, active: $active, lifecycleState: $lifecycleState, needsAttention: $needsAttention, listening: $listening)';
}


}

/// @nodoc
abstract mixin class _$EntityRowCopyWith<$Res> implements $EntityRowCopyWith<$Res> {
  factory _$EntityRowCopyWith(_EntityRow value, $Res Function(_EntityRow) _then) = __$EntityRowCopyWithImpl;
@override @useResult
$Res call({
 EntityKind kind, String id, String name, String description, List<String> tags, DateTime createdAt, DateTime updatedAt, String? configState, String? runtimeState, int missingConfigCount, bool? active, String? lifecycleState, bool needsAttention, bool? listening
});




}
/// @nodoc
class __$EntityRowCopyWithImpl<$Res>
    implements _$EntityRowCopyWith<$Res> {
  __$EntityRowCopyWithImpl(this._self, this._then);

  final _EntityRow _self;
  final $Res Function(_EntityRow) _then;

/// Create a copy of EntityRow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? id = null,Object? name = null,Object? description = null,Object? tags = null,Object? createdAt = null,Object? updatedAt = null,Object? configState = freezed,Object? runtimeState = freezed,Object? missingConfigCount = null,Object? active = freezed,Object? lifecycleState = freezed,Object? needsAttention = null,Object? listening = freezed,}) {
  return _then(_EntityRow(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as EntityKind,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,configState: freezed == configState ? _self.configState : configState // ignore: cast_nullable_to_non_nullable
as String?,runtimeState: freezed == runtimeState ? _self.runtimeState : runtimeState // ignore: cast_nullable_to_non_nullable
as String?,missingConfigCount: null == missingConfigCount ? _self.missingConfigCount : missingConfigCount // ignore: cast_nullable_to_non_nullable
as int,active: freezed == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool?,lifecycleState: freezed == lifecycleState ? _self.lifecycleState : lifecycleState // ignore: cast_nullable_to_non_nullable
as String?,needsAttention: null == needsAttention ? _self.needsAttention : needsAttention // ignore: cast_nullable_to_non_nullable
as bool,listening: freezed == listening ? _self.listening : listening // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

// dart format on
