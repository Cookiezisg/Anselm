// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workflow.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WorkflowEntity {

 String get id; String get name; String get description; List<String> get tags; bool get active; String get lifecycleState; String get concurrency; bool get needsAttention; String? get attentionReason; String get lastActionBy; String get activeVersionId; DateTime get createdAt; DateTime get updatedAt; WorkflowVersion? get activeVersion;
/// Create a copy of WorkflowEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkflowEntityCopyWith<WorkflowEntity> get copyWith => _$WorkflowEntityCopyWithImpl<WorkflowEntity>(this as WorkflowEntity, _$identity);

  /// Serializes this WorkflowEntity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkflowEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.active, active) || other.active == active)&&(identical(other.lifecycleState, lifecycleState) || other.lifecycleState == lifecycleState)&&(identical(other.concurrency, concurrency) || other.concurrency == concurrency)&&(identical(other.needsAttention, needsAttention) || other.needsAttention == needsAttention)&&(identical(other.attentionReason, attentionReason) || other.attentionReason == attentionReason)&&(identical(other.lastActionBy, lastActionBy) || other.lastActionBy == lastActionBy)&&(identical(other.activeVersionId, activeVersionId) || other.activeVersionId == activeVersionId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.activeVersion, activeVersion) || other.activeVersion == activeVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,const DeepCollectionEquality().hash(tags),active,lifecycleState,concurrency,needsAttention,attentionReason,lastActionBy,activeVersionId,createdAt,updatedAt,activeVersion);

@override
String toString() {
  return 'WorkflowEntity(id: $id, name: $name, description: $description, tags: $tags, active: $active, lifecycleState: $lifecycleState, concurrency: $concurrency, needsAttention: $needsAttention, attentionReason: $attentionReason, lastActionBy: $lastActionBy, activeVersionId: $activeVersionId, createdAt: $createdAt, updatedAt: $updatedAt, activeVersion: $activeVersion)';
}


}

/// @nodoc
abstract mixin class $WorkflowEntityCopyWith<$Res>  {
  factory $WorkflowEntityCopyWith(WorkflowEntity value, $Res Function(WorkflowEntity) _then) = _$WorkflowEntityCopyWithImpl;
@useResult
$Res call({
 String id, String name, String description, List<String> tags, bool active, String lifecycleState, String concurrency, bool needsAttention, String? attentionReason, String lastActionBy, String activeVersionId, DateTime createdAt, DateTime updatedAt, WorkflowVersion? activeVersion
});


$WorkflowVersionCopyWith<$Res>? get activeVersion;

}
/// @nodoc
class _$WorkflowEntityCopyWithImpl<$Res>
    implements $WorkflowEntityCopyWith<$Res> {
  _$WorkflowEntityCopyWithImpl(this._self, this._then);

  final WorkflowEntity _self;
  final $Res Function(WorkflowEntity) _then;

/// Create a copy of WorkflowEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = null,Object? tags = null,Object? active = null,Object? lifecycleState = null,Object? concurrency = null,Object? needsAttention = null,Object? attentionReason = freezed,Object? lastActionBy = null,Object? activeVersionId = null,Object? createdAt = null,Object? updatedAt = null,Object? activeVersion = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,lifecycleState: null == lifecycleState ? _self.lifecycleState : lifecycleState // ignore: cast_nullable_to_non_nullable
as String,concurrency: null == concurrency ? _self.concurrency : concurrency // ignore: cast_nullable_to_non_nullable
as String,needsAttention: null == needsAttention ? _self.needsAttention : needsAttention // ignore: cast_nullable_to_non_nullable
as bool,attentionReason: freezed == attentionReason ? _self.attentionReason : attentionReason // ignore: cast_nullable_to_non_nullable
as String?,lastActionBy: null == lastActionBy ? _self.lastActionBy : lastActionBy // ignore: cast_nullable_to_non_nullable
as String,activeVersionId: null == activeVersionId ? _self.activeVersionId : activeVersionId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,activeVersion: freezed == activeVersion ? _self.activeVersion : activeVersion // ignore: cast_nullable_to_non_nullable
as WorkflowVersion?,
  ));
}
/// Create a copy of WorkflowEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkflowVersionCopyWith<$Res>? get activeVersion {
    if (_self.activeVersion == null) {
    return null;
  }

  return $WorkflowVersionCopyWith<$Res>(_self.activeVersion!, (value) {
    return _then(_self.copyWith(activeVersion: value));
  });
}
}


/// Adds pattern-matching-related methods to [WorkflowEntity].
extension WorkflowEntityPatterns on WorkflowEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkflowEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkflowEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkflowEntity value)  $default,){
final _that = this;
switch (_that) {
case _WorkflowEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkflowEntity value)?  $default,){
final _that = this;
switch (_that) {
case _WorkflowEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String description,  List<String> tags,  bool active,  String lifecycleState,  String concurrency,  bool needsAttention,  String? attentionReason,  String lastActionBy,  String activeVersionId,  DateTime createdAt,  DateTime updatedAt,  WorkflowVersion? activeVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkflowEntity() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.tags,_that.active,_that.lifecycleState,_that.concurrency,_that.needsAttention,_that.attentionReason,_that.lastActionBy,_that.activeVersionId,_that.createdAt,_that.updatedAt,_that.activeVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String description,  List<String> tags,  bool active,  String lifecycleState,  String concurrency,  bool needsAttention,  String? attentionReason,  String lastActionBy,  String activeVersionId,  DateTime createdAt,  DateTime updatedAt,  WorkflowVersion? activeVersion)  $default,) {final _that = this;
switch (_that) {
case _WorkflowEntity():
return $default(_that.id,_that.name,_that.description,_that.tags,_that.active,_that.lifecycleState,_that.concurrency,_that.needsAttention,_that.attentionReason,_that.lastActionBy,_that.activeVersionId,_that.createdAt,_that.updatedAt,_that.activeVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String description,  List<String> tags,  bool active,  String lifecycleState,  String concurrency,  bool needsAttention,  String? attentionReason,  String lastActionBy,  String activeVersionId,  DateTime createdAt,  DateTime updatedAt,  WorkflowVersion? activeVersion)?  $default,) {final _that = this;
switch (_that) {
case _WorkflowEntity() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.tags,_that.active,_that.lifecycleState,_that.concurrency,_that.needsAttention,_that.attentionReason,_that.lastActionBy,_that.activeVersionId,_that.createdAt,_that.updatedAt,_that.activeVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkflowEntity implements WorkflowEntity {
  const _WorkflowEntity({required this.id, this.name = '', this.description = '', final  List<String> tags = const <String>[], this.active = false, this.lifecycleState = '', this.concurrency = 'serial', this.needsAttention = false, this.attentionReason, this.lastActionBy = '', this.activeVersionId = '', required this.createdAt, required this.updatedAt, this.activeVersion}): _tags = tags;
  factory _WorkflowEntity.fromJson(Map<String, dynamic> json) => _$WorkflowEntityFromJson(json);

@override final  String id;
@override@JsonKey() final  String name;
@override@JsonKey() final  String description;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

@override@JsonKey() final  bool active;
@override@JsonKey() final  String lifecycleState;
@override@JsonKey() final  String concurrency;
@override@JsonKey() final  bool needsAttention;
@override final  String? attentionReason;
@override@JsonKey() final  String lastActionBy;
@override@JsonKey() final  String activeVersionId;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  WorkflowVersion? activeVersion;

/// Create a copy of WorkflowEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkflowEntityCopyWith<_WorkflowEntity> get copyWith => __$WorkflowEntityCopyWithImpl<_WorkflowEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkflowEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkflowEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.active, active) || other.active == active)&&(identical(other.lifecycleState, lifecycleState) || other.lifecycleState == lifecycleState)&&(identical(other.concurrency, concurrency) || other.concurrency == concurrency)&&(identical(other.needsAttention, needsAttention) || other.needsAttention == needsAttention)&&(identical(other.attentionReason, attentionReason) || other.attentionReason == attentionReason)&&(identical(other.lastActionBy, lastActionBy) || other.lastActionBy == lastActionBy)&&(identical(other.activeVersionId, activeVersionId) || other.activeVersionId == activeVersionId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.activeVersion, activeVersion) || other.activeVersion == activeVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,const DeepCollectionEquality().hash(_tags),active,lifecycleState,concurrency,needsAttention,attentionReason,lastActionBy,activeVersionId,createdAt,updatedAt,activeVersion);

@override
String toString() {
  return 'WorkflowEntity(id: $id, name: $name, description: $description, tags: $tags, active: $active, lifecycleState: $lifecycleState, concurrency: $concurrency, needsAttention: $needsAttention, attentionReason: $attentionReason, lastActionBy: $lastActionBy, activeVersionId: $activeVersionId, createdAt: $createdAt, updatedAt: $updatedAt, activeVersion: $activeVersion)';
}


}

/// @nodoc
abstract mixin class _$WorkflowEntityCopyWith<$Res> implements $WorkflowEntityCopyWith<$Res> {
  factory _$WorkflowEntityCopyWith(_WorkflowEntity value, $Res Function(_WorkflowEntity) _then) = __$WorkflowEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String description, List<String> tags, bool active, String lifecycleState, String concurrency, bool needsAttention, String? attentionReason, String lastActionBy, String activeVersionId, DateTime createdAt, DateTime updatedAt, WorkflowVersion? activeVersion
});


@override $WorkflowVersionCopyWith<$Res>? get activeVersion;

}
/// @nodoc
class __$WorkflowEntityCopyWithImpl<$Res>
    implements _$WorkflowEntityCopyWith<$Res> {
  __$WorkflowEntityCopyWithImpl(this._self, this._then);

  final _WorkflowEntity _self;
  final $Res Function(_WorkflowEntity) _then;

/// Create a copy of WorkflowEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = null,Object? tags = null,Object? active = null,Object? lifecycleState = null,Object? concurrency = null,Object? needsAttention = null,Object? attentionReason = freezed,Object? lastActionBy = null,Object? activeVersionId = null,Object? createdAt = null,Object? updatedAt = null,Object? activeVersion = freezed,}) {
  return _then(_WorkflowEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,lifecycleState: null == lifecycleState ? _self.lifecycleState : lifecycleState // ignore: cast_nullable_to_non_nullable
as String,concurrency: null == concurrency ? _self.concurrency : concurrency // ignore: cast_nullable_to_non_nullable
as String,needsAttention: null == needsAttention ? _self.needsAttention : needsAttention // ignore: cast_nullable_to_non_nullable
as bool,attentionReason: freezed == attentionReason ? _self.attentionReason : attentionReason // ignore: cast_nullable_to_non_nullable
as String?,lastActionBy: null == lastActionBy ? _self.lastActionBy : lastActionBy // ignore: cast_nullable_to_non_nullable
as String,activeVersionId: null == activeVersionId ? _self.activeVersionId : activeVersionId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,activeVersion: freezed == activeVersion ? _self.activeVersion : activeVersion // ignore: cast_nullable_to_non_nullable
as WorkflowVersion?,
  ));
}

/// Create a copy of WorkflowEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkflowVersionCopyWith<$Res>? get activeVersion {
    if (_self.activeVersion == null) {
    return null;
  }

  return $WorkflowVersionCopyWith<$Res>(_self.activeVersion!, (value) {
    return _then(_self.copyWith(activeVersion: value));
  });
}
}


/// @nodoc
mixin _$WorkflowVersion {

 String get id; String get workflowId; int get version; String get graph; String? get changeReason; String? get builtInConversationId; DateTime get createdAt; DateTime get updatedAt; Graph? get graphParsed;
/// Create a copy of WorkflowVersion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkflowVersionCopyWith<WorkflowVersion> get copyWith => _$WorkflowVersionCopyWithImpl<WorkflowVersion>(this as WorkflowVersion, _$identity);

  /// Serializes this WorkflowVersion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkflowVersion&&(identical(other.id, id) || other.id == id)&&(identical(other.workflowId, workflowId) || other.workflowId == workflowId)&&(identical(other.version, version) || other.version == version)&&(identical(other.graph, graph) || other.graph == graph)&&(identical(other.changeReason, changeReason) || other.changeReason == changeReason)&&(identical(other.builtInConversationId, builtInConversationId) || other.builtInConversationId == builtInConversationId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.graphParsed, graphParsed) || other.graphParsed == graphParsed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,workflowId,version,graph,changeReason,builtInConversationId,createdAt,updatedAt,graphParsed);

@override
String toString() {
  return 'WorkflowVersion(id: $id, workflowId: $workflowId, version: $version, graph: $graph, changeReason: $changeReason, builtInConversationId: $builtInConversationId, createdAt: $createdAt, updatedAt: $updatedAt, graphParsed: $graphParsed)';
}


}

/// @nodoc
abstract mixin class $WorkflowVersionCopyWith<$Res>  {
  factory $WorkflowVersionCopyWith(WorkflowVersion value, $Res Function(WorkflowVersion) _then) = _$WorkflowVersionCopyWithImpl;
@useResult
$Res call({
 String id, String workflowId, int version, String graph, String? changeReason, String? builtInConversationId, DateTime createdAt, DateTime updatedAt, Graph? graphParsed
});


$GraphCopyWith<$Res>? get graphParsed;

}
/// @nodoc
class _$WorkflowVersionCopyWithImpl<$Res>
    implements $WorkflowVersionCopyWith<$Res> {
  _$WorkflowVersionCopyWithImpl(this._self, this._then);

  final WorkflowVersion _self;
  final $Res Function(WorkflowVersion) _then;

/// Create a copy of WorkflowVersion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workflowId = null,Object? version = null,Object? graph = null,Object? changeReason = freezed,Object? builtInConversationId = freezed,Object? createdAt = null,Object? updatedAt = null,Object? graphParsed = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workflowId: null == workflowId ? _self.workflowId : workflowId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,graph: null == graph ? _self.graph : graph // ignore: cast_nullable_to_non_nullable
as String,changeReason: freezed == changeReason ? _self.changeReason : changeReason // ignore: cast_nullable_to_non_nullable
as String?,builtInConversationId: freezed == builtInConversationId ? _self.builtInConversationId : builtInConversationId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,graphParsed: freezed == graphParsed ? _self.graphParsed : graphParsed // ignore: cast_nullable_to_non_nullable
as Graph?,
  ));
}
/// Create a copy of WorkflowVersion
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GraphCopyWith<$Res>? get graphParsed {
    if (_self.graphParsed == null) {
    return null;
  }

  return $GraphCopyWith<$Res>(_self.graphParsed!, (value) {
    return _then(_self.copyWith(graphParsed: value));
  });
}
}


/// Adds pattern-matching-related methods to [WorkflowVersion].
extension WorkflowVersionPatterns on WorkflowVersion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkflowVersion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkflowVersion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkflowVersion value)  $default,){
final _that = this;
switch (_that) {
case _WorkflowVersion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkflowVersion value)?  $default,){
final _that = this;
switch (_that) {
case _WorkflowVersion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workflowId,  int version,  String graph,  String? changeReason,  String? builtInConversationId,  DateTime createdAt,  DateTime updatedAt,  Graph? graphParsed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkflowVersion() when $default != null:
return $default(_that.id,_that.workflowId,_that.version,_that.graph,_that.changeReason,_that.builtInConversationId,_that.createdAt,_that.updatedAt,_that.graphParsed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workflowId,  int version,  String graph,  String? changeReason,  String? builtInConversationId,  DateTime createdAt,  DateTime updatedAt,  Graph? graphParsed)  $default,) {final _that = this;
switch (_that) {
case _WorkflowVersion():
return $default(_that.id,_that.workflowId,_that.version,_that.graph,_that.changeReason,_that.builtInConversationId,_that.createdAt,_that.updatedAt,_that.graphParsed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workflowId,  int version,  String graph,  String? changeReason,  String? builtInConversationId,  DateTime createdAt,  DateTime updatedAt,  Graph? graphParsed)?  $default,) {final _that = this;
switch (_that) {
case _WorkflowVersion() when $default != null:
return $default(_that.id,_that.workflowId,_that.version,_that.graph,_that.changeReason,_that.builtInConversationId,_that.createdAt,_that.updatedAt,_that.graphParsed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkflowVersion implements WorkflowVersion {
  const _WorkflowVersion({required this.id, required this.workflowId, required this.version, this.graph = '', this.changeReason, this.builtInConversationId, required this.createdAt, required this.updatedAt, this.graphParsed});
  factory _WorkflowVersion.fromJson(Map<String, dynamic> json) => _$WorkflowVersionFromJson(json);

@override final  String id;
@override final  String workflowId;
@override final  int version;
@override@JsonKey() final  String graph;
@override final  String? changeReason;
@override final  String? builtInConversationId;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  Graph? graphParsed;

/// Create a copy of WorkflowVersion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkflowVersionCopyWith<_WorkflowVersion> get copyWith => __$WorkflowVersionCopyWithImpl<_WorkflowVersion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkflowVersionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkflowVersion&&(identical(other.id, id) || other.id == id)&&(identical(other.workflowId, workflowId) || other.workflowId == workflowId)&&(identical(other.version, version) || other.version == version)&&(identical(other.graph, graph) || other.graph == graph)&&(identical(other.changeReason, changeReason) || other.changeReason == changeReason)&&(identical(other.builtInConversationId, builtInConversationId) || other.builtInConversationId == builtInConversationId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.graphParsed, graphParsed) || other.graphParsed == graphParsed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,workflowId,version,graph,changeReason,builtInConversationId,createdAt,updatedAt,graphParsed);

@override
String toString() {
  return 'WorkflowVersion(id: $id, workflowId: $workflowId, version: $version, graph: $graph, changeReason: $changeReason, builtInConversationId: $builtInConversationId, createdAt: $createdAt, updatedAt: $updatedAt, graphParsed: $graphParsed)';
}


}

/// @nodoc
abstract mixin class _$WorkflowVersionCopyWith<$Res> implements $WorkflowVersionCopyWith<$Res> {
  factory _$WorkflowVersionCopyWith(_WorkflowVersion value, $Res Function(_WorkflowVersion) _then) = __$WorkflowVersionCopyWithImpl;
@override @useResult
$Res call({
 String id, String workflowId, int version, String graph, String? changeReason, String? builtInConversationId, DateTime createdAt, DateTime updatedAt, Graph? graphParsed
});


@override $GraphCopyWith<$Res>? get graphParsed;

}
/// @nodoc
class __$WorkflowVersionCopyWithImpl<$Res>
    implements _$WorkflowVersionCopyWith<$Res> {
  __$WorkflowVersionCopyWithImpl(this._self, this._then);

  final _WorkflowVersion _self;
  final $Res Function(_WorkflowVersion) _then;

/// Create a copy of WorkflowVersion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workflowId = null,Object? version = null,Object? graph = null,Object? changeReason = freezed,Object? builtInConversationId = freezed,Object? createdAt = null,Object? updatedAt = null,Object? graphParsed = freezed,}) {
  return _then(_WorkflowVersion(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workflowId: null == workflowId ? _self.workflowId : workflowId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,graph: null == graph ? _self.graph : graph // ignore: cast_nullable_to_non_nullable
as String,changeReason: freezed == changeReason ? _self.changeReason : changeReason // ignore: cast_nullable_to_non_nullable
as String?,builtInConversationId: freezed == builtInConversationId ? _self.builtInConversationId : builtInConversationId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,graphParsed: freezed == graphParsed ? _self.graphParsed : graphParsed // ignore: cast_nullable_to_non_nullable
as Graph?,
  ));
}

/// Create a copy of WorkflowVersion
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GraphCopyWith<$Res>? get graphParsed {
    if (_self.graphParsed == null) {
    return null;
  }

  return $GraphCopyWith<$Res>(_self.graphParsed!, (value) {
    return _then(_self.copyWith(graphParsed: value));
  });
}
}


/// @nodoc
mixin _$Flowrun {

 String get id; String get workflowId; String get versionId; Map<String, String> get pinnedRefs; String? get triggerId; String? get firingId; String get status; int get replayCount; String? get error; DateTime? get startedAt; DateTime? get completedAt; DateTime get updatedAt;
/// Create a copy of Flowrun
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FlowrunCopyWith<Flowrun> get copyWith => _$FlowrunCopyWithImpl<Flowrun>(this as Flowrun, _$identity);

  /// Serializes this Flowrun to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Flowrun&&(identical(other.id, id) || other.id == id)&&(identical(other.workflowId, workflowId) || other.workflowId == workflowId)&&(identical(other.versionId, versionId) || other.versionId == versionId)&&const DeepCollectionEquality().equals(other.pinnedRefs, pinnedRefs)&&(identical(other.triggerId, triggerId) || other.triggerId == triggerId)&&(identical(other.firingId, firingId) || other.firingId == firingId)&&(identical(other.status, status) || other.status == status)&&(identical(other.replayCount, replayCount) || other.replayCount == replayCount)&&(identical(other.error, error) || other.error == error)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,workflowId,versionId,const DeepCollectionEquality().hash(pinnedRefs),triggerId,firingId,status,replayCount,error,startedAt,completedAt,updatedAt);

@override
String toString() {
  return 'Flowrun(id: $id, workflowId: $workflowId, versionId: $versionId, pinnedRefs: $pinnedRefs, triggerId: $triggerId, firingId: $firingId, status: $status, replayCount: $replayCount, error: $error, startedAt: $startedAt, completedAt: $completedAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $FlowrunCopyWith<$Res>  {
  factory $FlowrunCopyWith(Flowrun value, $Res Function(Flowrun) _then) = _$FlowrunCopyWithImpl;
@useResult
$Res call({
 String id, String workflowId, String versionId, Map<String, String> pinnedRefs, String? triggerId, String? firingId, String status, int replayCount, String? error, DateTime? startedAt, DateTime? completedAt, DateTime updatedAt
});




}
/// @nodoc
class _$FlowrunCopyWithImpl<$Res>
    implements $FlowrunCopyWith<$Res> {
  _$FlowrunCopyWithImpl(this._self, this._then);

  final Flowrun _self;
  final $Res Function(Flowrun) _then;

/// Create a copy of Flowrun
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workflowId = null,Object? versionId = null,Object? pinnedRefs = null,Object? triggerId = freezed,Object? firingId = freezed,Object? status = null,Object? replayCount = null,Object? error = freezed,Object? startedAt = freezed,Object? completedAt = freezed,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workflowId: null == workflowId ? _self.workflowId : workflowId // ignore: cast_nullable_to_non_nullable
as String,versionId: null == versionId ? _self.versionId : versionId // ignore: cast_nullable_to_non_nullable
as String,pinnedRefs: null == pinnedRefs ? _self.pinnedRefs : pinnedRefs // ignore: cast_nullable_to_non_nullable
as Map<String, String>,triggerId: freezed == triggerId ? _self.triggerId : triggerId // ignore: cast_nullable_to_non_nullable
as String?,firingId: freezed == firingId ? _self.firingId : firingId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,replayCount: null == replayCount ? _self.replayCount : replayCount // ignore: cast_nullable_to_non_nullable
as int,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Flowrun].
extension FlowrunPatterns on Flowrun {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Flowrun value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Flowrun() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Flowrun value)  $default,){
final _that = this;
switch (_that) {
case _Flowrun():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Flowrun value)?  $default,){
final _that = this;
switch (_that) {
case _Flowrun() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workflowId,  String versionId,  Map<String, String> pinnedRefs,  String? triggerId,  String? firingId,  String status,  int replayCount,  String? error,  DateTime? startedAt,  DateTime? completedAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Flowrun() when $default != null:
return $default(_that.id,_that.workflowId,_that.versionId,_that.pinnedRefs,_that.triggerId,_that.firingId,_that.status,_that.replayCount,_that.error,_that.startedAt,_that.completedAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workflowId,  String versionId,  Map<String, String> pinnedRefs,  String? triggerId,  String? firingId,  String status,  int replayCount,  String? error,  DateTime? startedAt,  DateTime? completedAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Flowrun():
return $default(_that.id,_that.workflowId,_that.versionId,_that.pinnedRefs,_that.triggerId,_that.firingId,_that.status,_that.replayCount,_that.error,_that.startedAt,_that.completedAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workflowId,  String versionId,  Map<String, String> pinnedRefs,  String? triggerId,  String? firingId,  String status,  int replayCount,  String? error,  DateTime? startedAt,  DateTime? completedAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Flowrun() when $default != null:
return $default(_that.id,_that.workflowId,_that.versionId,_that.pinnedRefs,_that.triggerId,_that.firingId,_that.status,_that.replayCount,_that.error,_that.startedAt,_that.completedAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Flowrun implements Flowrun {
  const _Flowrun({required this.id, required this.workflowId, this.versionId = '', final  Map<String, String> pinnedRefs = const <String, String>{}, this.triggerId, this.firingId, this.status = '', this.replayCount = 0, this.error, this.startedAt, this.completedAt, required this.updatedAt}): _pinnedRefs = pinnedRefs;
  factory _Flowrun.fromJson(Map<String, dynamic> json) => _$FlowrunFromJson(json);

@override final  String id;
@override final  String workflowId;
@override@JsonKey() final  String versionId;
 final  Map<String, String> _pinnedRefs;
@override@JsonKey() Map<String, String> get pinnedRefs {
  if (_pinnedRefs is EqualUnmodifiableMapView) return _pinnedRefs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_pinnedRefs);
}

@override final  String? triggerId;
@override final  String? firingId;
@override@JsonKey() final  String status;
@override@JsonKey() final  int replayCount;
@override final  String? error;
@override final  DateTime? startedAt;
@override final  DateTime? completedAt;
@override final  DateTime updatedAt;

/// Create a copy of Flowrun
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FlowrunCopyWith<_Flowrun> get copyWith => __$FlowrunCopyWithImpl<_Flowrun>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FlowrunToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Flowrun&&(identical(other.id, id) || other.id == id)&&(identical(other.workflowId, workflowId) || other.workflowId == workflowId)&&(identical(other.versionId, versionId) || other.versionId == versionId)&&const DeepCollectionEquality().equals(other._pinnedRefs, _pinnedRefs)&&(identical(other.triggerId, triggerId) || other.triggerId == triggerId)&&(identical(other.firingId, firingId) || other.firingId == firingId)&&(identical(other.status, status) || other.status == status)&&(identical(other.replayCount, replayCount) || other.replayCount == replayCount)&&(identical(other.error, error) || other.error == error)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,workflowId,versionId,const DeepCollectionEquality().hash(_pinnedRefs),triggerId,firingId,status,replayCount,error,startedAt,completedAt,updatedAt);

@override
String toString() {
  return 'Flowrun(id: $id, workflowId: $workflowId, versionId: $versionId, pinnedRefs: $pinnedRefs, triggerId: $triggerId, firingId: $firingId, status: $status, replayCount: $replayCount, error: $error, startedAt: $startedAt, completedAt: $completedAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$FlowrunCopyWith<$Res> implements $FlowrunCopyWith<$Res> {
  factory _$FlowrunCopyWith(_Flowrun value, $Res Function(_Flowrun) _then) = __$FlowrunCopyWithImpl;
@override @useResult
$Res call({
 String id, String workflowId, String versionId, Map<String, String> pinnedRefs, String? triggerId, String? firingId, String status, int replayCount, String? error, DateTime? startedAt, DateTime? completedAt, DateTime updatedAt
});




}
/// @nodoc
class __$FlowrunCopyWithImpl<$Res>
    implements _$FlowrunCopyWith<$Res> {
  __$FlowrunCopyWithImpl(this._self, this._then);

  final _Flowrun _self;
  final $Res Function(_Flowrun) _then;

/// Create a copy of Flowrun
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workflowId = null,Object? versionId = null,Object? pinnedRefs = null,Object? triggerId = freezed,Object? firingId = freezed,Object? status = null,Object? replayCount = null,Object? error = freezed,Object? startedAt = freezed,Object? completedAt = freezed,Object? updatedAt = null,}) {
  return _then(_Flowrun(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workflowId: null == workflowId ? _self.workflowId : workflowId // ignore: cast_nullable_to_non_nullable
as String,versionId: null == versionId ? _self.versionId : versionId // ignore: cast_nullable_to_non_nullable
as String,pinnedRefs: null == pinnedRefs ? _self._pinnedRefs : pinnedRefs // ignore: cast_nullable_to_non_nullable
as Map<String, String>,triggerId: freezed == triggerId ? _self.triggerId : triggerId // ignore: cast_nullable_to_non_nullable
as String?,firingId: freezed == firingId ? _self.firingId : firingId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,replayCount: null == replayCount ? _self.replayCount : replayCount // ignore: cast_nullable_to_non_nullable
as int,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$FlowrunNode {

 String get id; String get flowrunId; String get nodeId; int get iteration; String get kind; String get ref; String get status; Map<String, Object?> get result; String? get error; DateTime get createdAt; DateTime? get completedAt; DateTime get updatedAt;
/// Create a copy of FlowrunNode
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FlowrunNodeCopyWith<FlowrunNode> get copyWith => _$FlowrunNodeCopyWithImpl<FlowrunNode>(this as FlowrunNode, _$identity);

  /// Serializes this FlowrunNode to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FlowrunNode&&(identical(other.id, id) || other.id == id)&&(identical(other.flowrunId, flowrunId) || other.flowrunId == flowrunId)&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.iteration, iteration) || other.iteration == iteration)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.result, result)&&(identical(other.error, error) || other.error == error)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,flowrunId,nodeId,iteration,kind,ref,status,const DeepCollectionEquality().hash(result),error,createdAt,completedAt,updatedAt);

@override
String toString() {
  return 'FlowrunNode(id: $id, flowrunId: $flowrunId, nodeId: $nodeId, iteration: $iteration, kind: $kind, ref: $ref, status: $status, result: $result, error: $error, createdAt: $createdAt, completedAt: $completedAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $FlowrunNodeCopyWith<$Res>  {
  factory $FlowrunNodeCopyWith(FlowrunNode value, $Res Function(FlowrunNode) _then) = _$FlowrunNodeCopyWithImpl;
@useResult
$Res call({
 String id, String flowrunId, String nodeId, int iteration, String kind, String ref, String status, Map<String, Object?> result, String? error, DateTime createdAt, DateTime? completedAt, DateTime updatedAt
});




}
/// @nodoc
class _$FlowrunNodeCopyWithImpl<$Res>
    implements $FlowrunNodeCopyWith<$Res> {
  _$FlowrunNodeCopyWithImpl(this._self, this._then);

  final FlowrunNode _self;
  final $Res Function(FlowrunNode) _then;

/// Create a copy of FlowrunNode
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? flowrunId = null,Object? nodeId = null,Object? iteration = null,Object? kind = null,Object? ref = null,Object? status = null,Object? result = null,Object? error = freezed,Object? createdAt = null,Object? completedAt = freezed,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,flowrunId: null == flowrunId ? _self.flowrunId : flowrunId // ignore: cast_nullable_to_non_nullable
as String,nodeId: null == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String,iteration: null == iteration ? _self.iteration : iteration // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,result: null == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [FlowrunNode].
extension FlowrunNodePatterns on FlowrunNode {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FlowrunNode value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FlowrunNode() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FlowrunNode value)  $default,){
final _that = this;
switch (_that) {
case _FlowrunNode():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FlowrunNode value)?  $default,){
final _that = this;
switch (_that) {
case _FlowrunNode() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String flowrunId,  String nodeId,  int iteration,  String kind,  String ref,  String status,  Map<String, Object?> result,  String? error,  DateTime createdAt,  DateTime? completedAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FlowrunNode() when $default != null:
return $default(_that.id,_that.flowrunId,_that.nodeId,_that.iteration,_that.kind,_that.ref,_that.status,_that.result,_that.error,_that.createdAt,_that.completedAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String flowrunId,  String nodeId,  int iteration,  String kind,  String ref,  String status,  Map<String, Object?> result,  String? error,  DateTime createdAt,  DateTime? completedAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _FlowrunNode():
return $default(_that.id,_that.flowrunId,_that.nodeId,_that.iteration,_that.kind,_that.ref,_that.status,_that.result,_that.error,_that.createdAt,_that.completedAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String flowrunId,  String nodeId,  int iteration,  String kind,  String ref,  String status,  Map<String, Object?> result,  String? error,  DateTime createdAt,  DateTime? completedAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _FlowrunNode() when $default != null:
return $default(_that.id,_that.flowrunId,_that.nodeId,_that.iteration,_that.kind,_that.ref,_that.status,_that.result,_that.error,_that.createdAt,_that.completedAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FlowrunNode implements FlowrunNode {
  const _FlowrunNode({required this.id, required this.flowrunId, required this.nodeId, this.iteration = 0, this.kind = '', this.ref = '', this.status = '', final  Map<String, Object?> result = const <String, Object?>{}, this.error, required this.createdAt, this.completedAt, required this.updatedAt}): _result = result;
  factory _FlowrunNode.fromJson(Map<String, dynamic> json) => _$FlowrunNodeFromJson(json);

@override final  String id;
@override final  String flowrunId;
@override final  String nodeId;
@override@JsonKey() final  int iteration;
@override@JsonKey() final  String kind;
@override@JsonKey() final  String ref;
@override@JsonKey() final  String status;
 final  Map<String, Object?> _result;
@override@JsonKey() Map<String, Object?> get result {
  if (_result is EqualUnmodifiableMapView) return _result;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_result);
}

@override final  String? error;
@override final  DateTime createdAt;
@override final  DateTime? completedAt;
@override final  DateTime updatedAt;

/// Create a copy of FlowrunNode
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FlowrunNodeCopyWith<_FlowrunNode> get copyWith => __$FlowrunNodeCopyWithImpl<_FlowrunNode>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FlowrunNodeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FlowrunNode&&(identical(other.id, id) || other.id == id)&&(identical(other.flowrunId, flowrunId) || other.flowrunId == flowrunId)&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.iteration, iteration) || other.iteration == iteration)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._result, _result)&&(identical(other.error, error) || other.error == error)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,flowrunId,nodeId,iteration,kind,ref,status,const DeepCollectionEquality().hash(_result),error,createdAt,completedAt,updatedAt);

@override
String toString() {
  return 'FlowrunNode(id: $id, flowrunId: $flowrunId, nodeId: $nodeId, iteration: $iteration, kind: $kind, ref: $ref, status: $status, result: $result, error: $error, createdAt: $createdAt, completedAt: $completedAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$FlowrunNodeCopyWith<$Res> implements $FlowrunNodeCopyWith<$Res> {
  factory _$FlowrunNodeCopyWith(_FlowrunNode value, $Res Function(_FlowrunNode) _then) = __$FlowrunNodeCopyWithImpl;
@override @useResult
$Res call({
 String id, String flowrunId, String nodeId, int iteration, String kind, String ref, String status, Map<String, Object?> result, String? error, DateTime createdAt, DateTime? completedAt, DateTime updatedAt
});




}
/// @nodoc
class __$FlowrunNodeCopyWithImpl<$Res>
    implements _$FlowrunNodeCopyWith<$Res> {
  __$FlowrunNodeCopyWithImpl(this._self, this._then);

  final _FlowrunNode _self;
  final $Res Function(_FlowrunNode) _then;

/// Create a copy of FlowrunNode
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? flowrunId = null,Object? nodeId = null,Object? iteration = null,Object? kind = null,Object? ref = null,Object? status = null,Object? result = null,Object? error = freezed,Object? createdAt = null,Object? completedAt = freezed,Object? updatedAt = null,}) {
  return _then(_FlowrunNode(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,flowrunId: null == flowrunId ? _self.flowrunId : flowrunId // ignore: cast_nullable_to_non_nullable
as String,nodeId: null == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String,iteration: null == iteration ? _self.iteration : iteration // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,result: null == result ? _self._result : result // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$FlowrunComposite {

 Flowrun get flowrun; List<FlowrunNode> get nodes; String? get nextCursor;
/// Create a copy of FlowrunComposite
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FlowrunCompositeCopyWith<FlowrunComposite> get copyWith => _$FlowrunCompositeCopyWithImpl<FlowrunComposite>(this as FlowrunComposite, _$identity);

  /// Serializes this FlowrunComposite to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FlowrunComposite&&(identical(other.flowrun, flowrun) || other.flowrun == flowrun)&&const DeepCollectionEquality().equals(other.nodes, nodes)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,flowrun,const DeepCollectionEquality().hash(nodes),nextCursor);

@override
String toString() {
  return 'FlowrunComposite(flowrun: $flowrun, nodes: $nodes, nextCursor: $nextCursor)';
}


}

/// @nodoc
abstract mixin class $FlowrunCompositeCopyWith<$Res>  {
  factory $FlowrunCompositeCopyWith(FlowrunComposite value, $Res Function(FlowrunComposite) _then) = _$FlowrunCompositeCopyWithImpl;
@useResult
$Res call({
 Flowrun flowrun, List<FlowrunNode> nodes, String? nextCursor
});


$FlowrunCopyWith<$Res> get flowrun;

}
/// @nodoc
class _$FlowrunCompositeCopyWithImpl<$Res>
    implements $FlowrunCompositeCopyWith<$Res> {
  _$FlowrunCompositeCopyWithImpl(this._self, this._then);

  final FlowrunComposite _self;
  final $Res Function(FlowrunComposite) _then;

/// Create a copy of FlowrunComposite
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? flowrun = null,Object? nodes = null,Object? nextCursor = freezed,}) {
  return _then(_self.copyWith(
flowrun: null == flowrun ? _self.flowrun : flowrun // ignore: cast_nullable_to_non_nullable
as Flowrun,nodes: null == nodes ? _self.nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<FlowrunNode>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of FlowrunComposite
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FlowrunCopyWith<$Res> get flowrun {
  
  return $FlowrunCopyWith<$Res>(_self.flowrun, (value) {
    return _then(_self.copyWith(flowrun: value));
  });
}
}


/// Adds pattern-matching-related methods to [FlowrunComposite].
extension FlowrunCompositePatterns on FlowrunComposite {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FlowrunComposite value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FlowrunComposite() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FlowrunComposite value)  $default,){
final _that = this;
switch (_that) {
case _FlowrunComposite():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FlowrunComposite value)?  $default,){
final _that = this;
switch (_that) {
case _FlowrunComposite() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Flowrun flowrun,  List<FlowrunNode> nodes,  String? nextCursor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FlowrunComposite() when $default != null:
return $default(_that.flowrun,_that.nodes,_that.nextCursor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Flowrun flowrun,  List<FlowrunNode> nodes,  String? nextCursor)  $default,) {final _that = this;
switch (_that) {
case _FlowrunComposite():
return $default(_that.flowrun,_that.nodes,_that.nextCursor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Flowrun flowrun,  List<FlowrunNode> nodes,  String? nextCursor)?  $default,) {final _that = this;
switch (_that) {
case _FlowrunComposite() when $default != null:
return $default(_that.flowrun,_that.nodes,_that.nextCursor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FlowrunComposite implements FlowrunComposite {
  const _FlowrunComposite({required this.flowrun, final  List<FlowrunNode> nodes = const <FlowrunNode>[], this.nextCursor}): _nodes = nodes;
  factory _FlowrunComposite.fromJson(Map<String, dynamic> json) => _$FlowrunCompositeFromJson(json);

@override final  Flowrun flowrun;
 final  List<FlowrunNode> _nodes;
@override@JsonKey() List<FlowrunNode> get nodes {
  if (_nodes is EqualUnmodifiableListView) return _nodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nodes);
}

@override final  String? nextCursor;

/// Create a copy of FlowrunComposite
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FlowrunCompositeCopyWith<_FlowrunComposite> get copyWith => __$FlowrunCompositeCopyWithImpl<_FlowrunComposite>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FlowrunCompositeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FlowrunComposite&&(identical(other.flowrun, flowrun) || other.flowrun == flowrun)&&const DeepCollectionEquality().equals(other._nodes, _nodes)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,flowrun,const DeepCollectionEquality().hash(_nodes),nextCursor);

@override
String toString() {
  return 'FlowrunComposite(flowrun: $flowrun, nodes: $nodes, nextCursor: $nextCursor)';
}


}

/// @nodoc
abstract mixin class _$FlowrunCompositeCopyWith<$Res> implements $FlowrunCompositeCopyWith<$Res> {
  factory _$FlowrunCompositeCopyWith(_FlowrunComposite value, $Res Function(_FlowrunComposite) _then) = __$FlowrunCompositeCopyWithImpl;
@override @useResult
$Res call({
 Flowrun flowrun, List<FlowrunNode> nodes, String? nextCursor
});


@override $FlowrunCopyWith<$Res> get flowrun;

}
/// @nodoc
class __$FlowrunCompositeCopyWithImpl<$Res>
    implements _$FlowrunCompositeCopyWith<$Res> {
  __$FlowrunCompositeCopyWithImpl(this._self, this._then);

  final _FlowrunComposite _self;
  final $Res Function(_FlowrunComposite) _then;

/// Create a copy of FlowrunComposite
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? flowrun = null,Object? nodes = null,Object? nextCursor = freezed,}) {
  return _then(_FlowrunComposite(
flowrun: null == flowrun ? _self.flowrun : flowrun // ignore: cast_nullable_to_non_nullable
as Flowrun,nodes: null == nodes ? _self._nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<FlowrunNode>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of FlowrunComposite
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FlowrunCopyWith<$Res> get flowrun {
  
  return $FlowrunCopyWith<$Res>(_self.flowrun, (value) {
    return _then(_self.copyWith(flowrun: value));
  });
}
}

// dart format on
