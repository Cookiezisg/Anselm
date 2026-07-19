// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'function.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FunctionEntity {

 String get id; String get name; String get description; List<String> get tags; String get activeVersionId; DateTime get createdAt; DateTime get updatedAt; FunctionVersion? get activeVersion;
/// Create a copy of FunctionEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FunctionEntityCopyWith<FunctionEntity> get copyWith => _$FunctionEntityCopyWithImpl<FunctionEntity>(this as FunctionEntity, _$identity);

  /// Serializes this FunctionEntity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FunctionEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.activeVersionId, activeVersionId) || other.activeVersionId == activeVersionId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.activeVersion, activeVersion) || other.activeVersion == activeVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,const DeepCollectionEquality().hash(tags),activeVersionId,createdAt,updatedAt,activeVersion);

@override
String toString() {
  return 'FunctionEntity(id: $id, name: $name, description: $description, tags: $tags, activeVersionId: $activeVersionId, createdAt: $createdAt, updatedAt: $updatedAt, activeVersion: $activeVersion)';
}


}

/// @nodoc
abstract mixin class $FunctionEntityCopyWith<$Res>  {
  factory $FunctionEntityCopyWith(FunctionEntity value, $Res Function(FunctionEntity) _then) = _$FunctionEntityCopyWithImpl;
@useResult
$Res call({
 String id, String name, String description, List<String> tags, String activeVersionId, DateTime createdAt, DateTime updatedAt, FunctionVersion? activeVersion
});


$FunctionVersionCopyWith<$Res>? get activeVersion;

}
/// @nodoc
class _$FunctionEntityCopyWithImpl<$Res>
    implements $FunctionEntityCopyWith<$Res> {
  _$FunctionEntityCopyWithImpl(this._self, this._then);

  final FunctionEntity _self;
  final $Res Function(FunctionEntity) _then;

/// Create a copy of FunctionEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = null,Object? tags = null,Object? activeVersionId = null,Object? createdAt = null,Object? updatedAt = null,Object? activeVersion = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,activeVersionId: null == activeVersionId ? _self.activeVersionId : activeVersionId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,activeVersion: freezed == activeVersion ? _self.activeVersion : activeVersion // ignore: cast_nullable_to_non_nullable
as FunctionVersion?,
  ));
}
/// Create a copy of FunctionEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FunctionVersionCopyWith<$Res>? get activeVersion {
    if (_self.activeVersion == null) {
    return null;
  }

  return $FunctionVersionCopyWith<$Res>(_self.activeVersion!, (value) {
    return _then(_self.copyWith(activeVersion: value));
  });
}
}


/// Adds pattern-matching-related methods to [FunctionEntity].
extension FunctionEntityPatterns on FunctionEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FunctionEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FunctionEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FunctionEntity value)  $default,){
final _that = this;
switch (_that) {
case _FunctionEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FunctionEntity value)?  $default,){
final _that = this;
switch (_that) {
case _FunctionEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String description,  List<String> tags,  String activeVersionId,  DateTime createdAt,  DateTime updatedAt,  FunctionVersion? activeVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FunctionEntity() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.tags,_that.activeVersionId,_that.createdAt,_that.updatedAt,_that.activeVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String description,  List<String> tags,  String activeVersionId,  DateTime createdAt,  DateTime updatedAt,  FunctionVersion? activeVersion)  $default,) {final _that = this;
switch (_that) {
case _FunctionEntity():
return $default(_that.id,_that.name,_that.description,_that.tags,_that.activeVersionId,_that.createdAt,_that.updatedAt,_that.activeVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String description,  List<String> tags,  String activeVersionId,  DateTime createdAt,  DateTime updatedAt,  FunctionVersion? activeVersion)?  $default,) {final _that = this;
switch (_that) {
case _FunctionEntity() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.tags,_that.activeVersionId,_that.createdAt,_that.updatedAt,_that.activeVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FunctionEntity implements FunctionEntity {
  const _FunctionEntity({required this.id, this.name = '', this.description = '', final  List<String> tags = const <String>[], this.activeVersionId = '', required this.createdAt, required this.updatedAt, this.activeVersion}): _tags = tags;
  factory _FunctionEntity.fromJson(Map<String, dynamic> json) => _$FunctionEntityFromJson(json);

@override final  String id;
@override@JsonKey() final  String name;
@override@JsonKey() final  String description;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

@override@JsonKey() final  String activeVersionId;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  FunctionVersion? activeVersion;

/// Create a copy of FunctionEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FunctionEntityCopyWith<_FunctionEntity> get copyWith => __$FunctionEntityCopyWithImpl<_FunctionEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FunctionEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FunctionEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.activeVersionId, activeVersionId) || other.activeVersionId == activeVersionId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.activeVersion, activeVersion) || other.activeVersion == activeVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,const DeepCollectionEquality().hash(_tags),activeVersionId,createdAt,updatedAt,activeVersion);

@override
String toString() {
  return 'FunctionEntity(id: $id, name: $name, description: $description, tags: $tags, activeVersionId: $activeVersionId, createdAt: $createdAt, updatedAt: $updatedAt, activeVersion: $activeVersion)';
}


}

/// @nodoc
abstract mixin class _$FunctionEntityCopyWith<$Res> implements $FunctionEntityCopyWith<$Res> {
  factory _$FunctionEntityCopyWith(_FunctionEntity value, $Res Function(_FunctionEntity) _then) = __$FunctionEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String description, List<String> tags, String activeVersionId, DateTime createdAt, DateTime updatedAt, FunctionVersion? activeVersion
});


@override $FunctionVersionCopyWith<$Res>? get activeVersion;

}
/// @nodoc
class __$FunctionEntityCopyWithImpl<$Res>
    implements _$FunctionEntityCopyWith<$Res> {
  __$FunctionEntityCopyWithImpl(this._self, this._then);

  final _FunctionEntity _self;
  final $Res Function(_FunctionEntity) _then;

/// Create a copy of FunctionEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = null,Object? tags = null,Object? activeVersionId = null,Object? createdAt = null,Object? updatedAt = null,Object? activeVersion = freezed,}) {
  return _then(_FunctionEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,activeVersionId: null == activeVersionId ? _self.activeVersionId : activeVersionId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,activeVersion: freezed == activeVersion ? _self.activeVersion : activeVersion // ignore: cast_nullable_to_non_nullable
as FunctionVersion?,
  ));
}

/// Create a copy of FunctionEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FunctionVersionCopyWith<$Res>? get activeVersion {
    if (_self.activeVersion == null) {
    return null;
  }

  return $FunctionVersionCopyWith<$Res>(_self.activeVersion!, (value) {
    return _then(_self.copyWith(activeVersion: value));
  });
}
}


/// @nodoc
mixin _$FunctionVersion {

 String get id; String get functionId; int get version; String get code; List<Field> get inputs; List<Field> get outputs; List<String> get dependencies; String get pythonVersion; String get envId; String get envStatus; String? get envError; DateTime? get envSyncedAt; String? get changeReason; String? get builtInConversationId; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of FunctionVersion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FunctionVersionCopyWith<FunctionVersion> get copyWith => _$FunctionVersionCopyWithImpl<FunctionVersion>(this as FunctionVersion, _$identity);

  /// Serializes this FunctionVersion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FunctionVersion&&(identical(other.id, id) || other.id == id)&&(identical(other.functionId, functionId) || other.functionId == functionId)&&(identical(other.version, version) || other.version == version)&&(identical(other.code, code) || other.code == code)&&const DeepCollectionEquality().equals(other.inputs, inputs)&&const DeepCollectionEquality().equals(other.outputs, outputs)&&const DeepCollectionEquality().equals(other.dependencies, dependencies)&&(identical(other.pythonVersion, pythonVersion) || other.pythonVersion == pythonVersion)&&(identical(other.envId, envId) || other.envId == envId)&&(identical(other.envStatus, envStatus) || other.envStatus == envStatus)&&(identical(other.envError, envError) || other.envError == envError)&&(identical(other.envSyncedAt, envSyncedAt) || other.envSyncedAt == envSyncedAt)&&(identical(other.changeReason, changeReason) || other.changeReason == changeReason)&&(identical(other.builtInConversationId, builtInConversationId) || other.builtInConversationId == builtInConversationId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,functionId,version,code,const DeepCollectionEquality().hash(inputs),const DeepCollectionEquality().hash(outputs),const DeepCollectionEquality().hash(dependencies),pythonVersion,envId,envStatus,envError,envSyncedAt,changeReason,builtInConversationId,createdAt,updatedAt);

@override
String toString() {
  return 'FunctionVersion(id: $id, functionId: $functionId, version: $version, code: $code, inputs: $inputs, outputs: $outputs, dependencies: $dependencies, pythonVersion: $pythonVersion, envId: $envId, envStatus: $envStatus, envError: $envError, envSyncedAt: $envSyncedAt, changeReason: $changeReason, builtInConversationId: $builtInConversationId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $FunctionVersionCopyWith<$Res>  {
  factory $FunctionVersionCopyWith(FunctionVersion value, $Res Function(FunctionVersion) _then) = _$FunctionVersionCopyWithImpl;
@useResult
$Res call({
 String id, String functionId, int version, String code, List<Field> inputs, List<Field> outputs, List<String> dependencies, String pythonVersion, String envId, String envStatus, String? envError, DateTime? envSyncedAt, String? changeReason, String? builtInConversationId, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$FunctionVersionCopyWithImpl<$Res>
    implements $FunctionVersionCopyWith<$Res> {
  _$FunctionVersionCopyWithImpl(this._self, this._then);

  final FunctionVersion _self;
  final $Res Function(FunctionVersion) _then;

/// Create a copy of FunctionVersion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? functionId = null,Object? version = null,Object? code = null,Object? inputs = null,Object? outputs = null,Object? dependencies = null,Object? pythonVersion = null,Object? envId = null,Object? envStatus = null,Object? envError = freezed,Object? envSyncedAt = freezed,Object? changeReason = freezed,Object? builtInConversationId = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,functionId: null == functionId ? _self.functionId : functionId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,inputs: null == inputs ? _self.inputs : inputs // ignore: cast_nullable_to_non_nullable
as List<Field>,outputs: null == outputs ? _self.outputs : outputs // ignore: cast_nullable_to_non_nullable
as List<Field>,dependencies: null == dependencies ? _self.dependencies : dependencies // ignore: cast_nullable_to_non_nullable
as List<String>,pythonVersion: null == pythonVersion ? _self.pythonVersion : pythonVersion // ignore: cast_nullable_to_non_nullable
as String,envId: null == envId ? _self.envId : envId // ignore: cast_nullable_to_non_nullable
as String,envStatus: null == envStatus ? _self.envStatus : envStatus // ignore: cast_nullable_to_non_nullable
as String,envError: freezed == envError ? _self.envError : envError // ignore: cast_nullable_to_non_nullable
as String?,envSyncedAt: freezed == envSyncedAt ? _self.envSyncedAt : envSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,changeReason: freezed == changeReason ? _self.changeReason : changeReason // ignore: cast_nullable_to_non_nullable
as String?,builtInConversationId: freezed == builtInConversationId ? _self.builtInConversationId : builtInConversationId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [FunctionVersion].
extension FunctionVersionPatterns on FunctionVersion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FunctionVersion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FunctionVersion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FunctionVersion value)  $default,){
final _that = this;
switch (_that) {
case _FunctionVersion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FunctionVersion value)?  $default,){
final _that = this;
switch (_that) {
case _FunctionVersion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String functionId,  int version,  String code,  List<Field> inputs,  List<Field> outputs,  List<String> dependencies,  String pythonVersion,  String envId,  String envStatus,  String? envError,  DateTime? envSyncedAt,  String? changeReason,  String? builtInConversationId,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FunctionVersion() when $default != null:
return $default(_that.id,_that.functionId,_that.version,_that.code,_that.inputs,_that.outputs,_that.dependencies,_that.pythonVersion,_that.envId,_that.envStatus,_that.envError,_that.envSyncedAt,_that.changeReason,_that.builtInConversationId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String functionId,  int version,  String code,  List<Field> inputs,  List<Field> outputs,  List<String> dependencies,  String pythonVersion,  String envId,  String envStatus,  String? envError,  DateTime? envSyncedAt,  String? changeReason,  String? builtInConversationId,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _FunctionVersion():
return $default(_that.id,_that.functionId,_that.version,_that.code,_that.inputs,_that.outputs,_that.dependencies,_that.pythonVersion,_that.envId,_that.envStatus,_that.envError,_that.envSyncedAt,_that.changeReason,_that.builtInConversationId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String functionId,  int version,  String code,  List<Field> inputs,  List<Field> outputs,  List<String> dependencies,  String pythonVersion,  String envId,  String envStatus,  String? envError,  DateTime? envSyncedAt,  String? changeReason,  String? builtInConversationId,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _FunctionVersion() when $default != null:
return $default(_that.id,_that.functionId,_that.version,_that.code,_that.inputs,_that.outputs,_that.dependencies,_that.pythonVersion,_that.envId,_that.envStatus,_that.envError,_that.envSyncedAt,_that.changeReason,_that.builtInConversationId,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FunctionVersion implements FunctionVersion {
  const _FunctionVersion({required this.id, required this.functionId, required this.version, this.code = '', final  List<Field> inputs = const <Field>[], final  List<Field> outputs = const <Field>[], final  List<String> dependencies = const <String>[], this.pythonVersion = '3.12', this.envId = '', this.envStatus = '', this.envError, this.envSyncedAt, this.changeReason, this.builtInConversationId, required this.createdAt, required this.updatedAt}): _inputs = inputs,_outputs = outputs,_dependencies = dependencies;
  factory _FunctionVersion.fromJson(Map<String, dynamic> json) => _$FunctionVersionFromJson(json);

@override final  String id;
@override final  String functionId;
@override final  int version;
@override@JsonKey() final  String code;
 final  List<Field> _inputs;
@override@JsonKey() List<Field> get inputs {
  if (_inputs is EqualUnmodifiableListView) return _inputs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_inputs);
}

 final  List<Field> _outputs;
@override@JsonKey() List<Field> get outputs {
  if (_outputs is EqualUnmodifiableListView) return _outputs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_outputs);
}

 final  List<String> _dependencies;
@override@JsonKey() List<String> get dependencies {
  if (_dependencies is EqualUnmodifiableListView) return _dependencies;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_dependencies);
}

@override@JsonKey() final  String pythonVersion;
@override@JsonKey() final  String envId;
@override@JsonKey() final  String envStatus;
@override final  String? envError;
@override final  DateTime? envSyncedAt;
@override final  String? changeReason;
@override final  String? builtInConversationId;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of FunctionVersion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FunctionVersionCopyWith<_FunctionVersion> get copyWith => __$FunctionVersionCopyWithImpl<_FunctionVersion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FunctionVersionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FunctionVersion&&(identical(other.id, id) || other.id == id)&&(identical(other.functionId, functionId) || other.functionId == functionId)&&(identical(other.version, version) || other.version == version)&&(identical(other.code, code) || other.code == code)&&const DeepCollectionEquality().equals(other._inputs, _inputs)&&const DeepCollectionEquality().equals(other._outputs, _outputs)&&const DeepCollectionEquality().equals(other._dependencies, _dependencies)&&(identical(other.pythonVersion, pythonVersion) || other.pythonVersion == pythonVersion)&&(identical(other.envId, envId) || other.envId == envId)&&(identical(other.envStatus, envStatus) || other.envStatus == envStatus)&&(identical(other.envError, envError) || other.envError == envError)&&(identical(other.envSyncedAt, envSyncedAt) || other.envSyncedAt == envSyncedAt)&&(identical(other.changeReason, changeReason) || other.changeReason == changeReason)&&(identical(other.builtInConversationId, builtInConversationId) || other.builtInConversationId == builtInConversationId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,functionId,version,code,const DeepCollectionEquality().hash(_inputs),const DeepCollectionEquality().hash(_outputs),const DeepCollectionEquality().hash(_dependencies),pythonVersion,envId,envStatus,envError,envSyncedAt,changeReason,builtInConversationId,createdAt,updatedAt);

@override
String toString() {
  return 'FunctionVersion(id: $id, functionId: $functionId, version: $version, code: $code, inputs: $inputs, outputs: $outputs, dependencies: $dependencies, pythonVersion: $pythonVersion, envId: $envId, envStatus: $envStatus, envError: $envError, envSyncedAt: $envSyncedAt, changeReason: $changeReason, builtInConversationId: $builtInConversationId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$FunctionVersionCopyWith<$Res> implements $FunctionVersionCopyWith<$Res> {
  factory _$FunctionVersionCopyWith(_FunctionVersion value, $Res Function(_FunctionVersion) _then) = __$FunctionVersionCopyWithImpl;
@override @useResult
$Res call({
 String id, String functionId, int version, String code, List<Field> inputs, List<Field> outputs, List<String> dependencies, String pythonVersion, String envId, String envStatus, String? envError, DateTime? envSyncedAt, String? changeReason, String? builtInConversationId, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$FunctionVersionCopyWithImpl<$Res>
    implements _$FunctionVersionCopyWith<$Res> {
  __$FunctionVersionCopyWithImpl(this._self, this._then);

  final _FunctionVersion _self;
  final $Res Function(_FunctionVersion) _then;

/// Create a copy of FunctionVersion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? functionId = null,Object? version = null,Object? code = null,Object? inputs = null,Object? outputs = null,Object? dependencies = null,Object? pythonVersion = null,Object? envId = null,Object? envStatus = null,Object? envError = freezed,Object? envSyncedAt = freezed,Object? changeReason = freezed,Object? builtInConversationId = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_FunctionVersion(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,functionId: null == functionId ? _self.functionId : functionId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,inputs: null == inputs ? _self._inputs : inputs // ignore: cast_nullable_to_non_nullable
as List<Field>,outputs: null == outputs ? _self._outputs : outputs // ignore: cast_nullable_to_non_nullable
as List<Field>,dependencies: null == dependencies ? _self._dependencies : dependencies // ignore: cast_nullable_to_non_nullable
as List<String>,pythonVersion: null == pythonVersion ? _self.pythonVersion : pythonVersion // ignore: cast_nullable_to_non_nullable
as String,envId: null == envId ? _self.envId : envId // ignore: cast_nullable_to_non_nullable
as String,envStatus: null == envStatus ? _self.envStatus : envStatus // ignore: cast_nullable_to_non_nullable
as String,envError: freezed == envError ? _self.envError : envError // ignore: cast_nullable_to_non_nullable
as String?,envSyncedAt: freezed == envSyncedAt ? _self.envSyncedAt : envSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,changeReason: freezed == changeReason ? _self.changeReason : changeReason // ignore: cast_nullable_to_non_nullable
as String?,builtInConversationId: freezed == builtInConversationId ? _self.builtInConversationId : builtInConversationId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$FunctionExecution {

 String get id; String get functionId; String get versionId; String get status; String get triggeredBy; Map<String, Object?> get input; Object? get output; String? get errorMessage; String? get logs; int get elapsedMs; DateTime? get startedAt; DateTime? get endedAt; String? get conversationId; String? get messageId; String? get toolCallId; String? get flowrunId; String? get flowrunNodeId; int? get flowrunIteration; DateTime get createdAt;
/// Create a copy of FunctionExecution
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FunctionExecutionCopyWith<FunctionExecution> get copyWith => _$FunctionExecutionCopyWithImpl<FunctionExecution>(this as FunctionExecution, _$identity);

  /// Serializes this FunctionExecution to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FunctionExecution&&(identical(other.id, id) || other.id == id)&&(identical(other.functionId, functionId) || other.functionId == functionId)&&(identical(other.versionId, versionId) || other.versionId == versionId)&&(identical(other.status, status) || other.status == status)&&(identical(other.triggeredBy, triggeredBy) || other.triggeredBy == triggeredBy)&&const DeepCollectionEquality().equals(other.input, input)&&const DeepCollectionEquality().equals(other.output, output)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.logs, logs) || other.logs == logs)&&(identical(other.elapsedMs, elapsedMs) || other.elapsedMs == elapsedMs)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.flowrunId, flowrunId) || other.flowrunId == flowrunId)&&(identical(other.flowrunNodeId, flowrunNodeId) || other.flowrunNodeId == flowrunNodeId)&&(identical(other.flowrunIteration, flowrunIteration) || other.flowrunIteration == flowrunIteration)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,functionId,versionId,status,triggeredBy,const DeepCollectionEquality().hash(input),const DeepCollectionEquality().hash(output),errorMessage,logs,elapsedMs,startedAt,endedAt,conversationId,messageId,toolCallId,flowrunId,flowrunNodeId,flowrunIteration,createdAt]);

@override
String toString() {
  return 'FunctionExecution(id: $id, functionId: $functionId, versionId: $versionId, status: $status, triggeredBy: $triggeredBy, input: $input, output: $output, errorMessage: $errorMessage, logs: $logs, elapsedMs: $elapsedMs, startedAt: $startedAt, endedAt: $endedAt, conversationId: $conversationId, messageId: $messageId, toolCallId: $toolCallId, flowrunId: $flowrunId, flowrunNodeId: $flowrunNodeId, flowrunIteration: $flowrunIteration, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $FunctionExecutionCopyWith<$Res>  {
  factory $FunctionExecutionCopyWith(FunctionExecution value, $Res Function(FunctionExecution) _then) = _$FunctionExecutionCopyWithImpl;
@useResult
$Res call({
 String id, String functionId, String versionId, String status, String triggeredBy, Map<String, Object?> input, Object? output, String? errorMessage, String? logs, int elapsedMs, DateTime? startedAt, DateTime? endedAt, String? conversationId, String? messageId, String? toolCallId, String? flowrunId, String? flowrunNodeId, int? flowrunIteration, DateTime createdAt
});




}
/// @nodoc
class _$FunctionExecutionCopyWithImpl<$Res>
    implements $FunctionExecutionCopyWith<$Res> {
  _$FunctionExecutionCopyWithImpl(this._self, this._then);

  final FunctionExecution _self;
  final $Res Function(FunctionExecution) _then;

/// Create a copy of FunctionExecution
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? functionId = null,Object? versionId = null,Object? status = null,Object? triggeredBy = null,Object? input = null,Object? output = freezed,Object? errorMessage = freezed,Object? logs = freezed,Object? elapsedMs = null,Object? startedAt = freezed,Object? endedAt = freezed,Object? conversationId = freezed,Object? messageId = freezed,Object? toolCallId = freezed,Object? flowrunId = freezed,Object? flowrunNodeId = freezed,Object? flowrunIteration = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,functionId: null == functionId ? _self.functionId : functionId // ignore: cast_nullable_to_non_nullable
as String,versionId: null == versionId ? _self.versionId : versionId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,triggeredBy: null == triggeredBy ? _self.triggeredBy : triggeredBy // ignore: cast_nullable_to_non_nullable
as String,input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,output: freezed == output ? _self.output : output ,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,logs: freezed == logs ? _self.logs : logs // ignore: cast_nullable_to_non_nullable
as String?,elapsedMs: null == elapsedMs ? _self.elapsedMs : elapsedMs // ignore: cast_nullable_to_non_nullable
as int,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,conversationId: freezed == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String?,messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String?,toolCallId: freezed == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String?,flowrunId: freezed == flowrunId ? _self.flowrunId : flowrunId // ignore: cast_nullable_to_non_nullable
as String?,flowrunNodeId: freezed == flowrunNodeId ? _self.flowrunNodeId : flowrunNodeId // ignore: cast_nullable_to_non_nullable
as String?,flowrunIteration: freezed == flowrunIteration ? _self.flowrunIteration : flowrunIteration // ignore: cast_nullable_to_non_nullable
as int?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [FunctionExecution].
extension FunctionExecutionPatterns on FunctionExecution {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FunctionExecution value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FunctionExecution() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FunctionExecution value)  $default,){
final _that = this;
switch (_that) {
case _FunctionExecution():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FunctionExecution value)?  $default,){
final _that = this;
switch (_that) {
case _FunctionExecution() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String functionId,  String versionId,  String status,  String triggeredBy,  Map<String, Object?> input,  Object? output,  String? errorMessage,  String? logs,  int elapsedMs,  DateTime? startedAt,  DateTime? endedAt,  String? conversationId,  String? messageId,  String? toolCallId,  String? flowrunId,  String? flowrunNodeId,  int? flowrunIteration,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FunctionExecution() when $default != null:
return $default(_that.id,_that.functionId,_that.versionId,_that.status,_that.triggeredBy,_that.input,_that.output,_that.errorMessage,_that.logs,_that.elapsedMs,_that.startedAt,_that.endedAt,_that.conversationId,_that.messageId,_that.toolCallId,_that.flowrunId,_that.flowrunNodeId,_that.flowrunIteration,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String functionId,  String versionId,  String status,  String triggeredBy,  Map<String, Object?> input,  Object? output,  String? errorMessage,  String? logs,  int elapsedMs,  DateTime? startedAt,  DateTime? endedAt,  String? conversationId,  String? messageId,  String? toolCallId,  String? flowrunId,  String? flowrunNodeId,  int? flowrunIteration,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _FunctionExecution():
return $default(_that.id,_that.functionId,_that.versionId,_that.status,_that.triggeredBy,_that.input,_that.output,_that.errorMessage,_that.logs,_that.elapsedMs,_that.startedAt,_that.endedAt,_that.conversationId,_that.messageId,_that.toolCallId,_that.flowrunId,_that.flowrunNodeId,_that.flowrunIteration,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String functionId,  String versionId,  String status,  String triggeredBy,  Map<String, Object?> input,  Object? output,  String? errorMessage,  String? logs,  int elapsedMs,  DateTime? startedAt,  DateTime? endedAt,  String? conversationId,  String? messageId,  String? toolCallId,  String? flowrunId,  String? flowrunNodeId,  int? flowrunIteration,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _FunctionExecution() when $default != null:
return $default(_that.id,_that.functionId,_that.versionId,_that.status,_that.triggeredBy,_that.input,_that.output,_that.errorMessage,_that.logs,_that.elapsedMs,_that.startedAt,_that.endedAt,_that.conversationId,_that.messageId,_that.toolCallId,_that.flowrunId,_that.flowrunNodeId,_that.flowrunIteration,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FunctionExecution implements FunctionExecution {
  const _FunctionExecution({required this.id, required this.functionId, this.versionId = '', this.status = '', this.triggeredBy = '', final  Map<String, Object?> input = const <String, Object?>{}, this.output, this.errorMessage, this.logs, this.elapsedMs = 0, this.startedAt, this.endedAt, this.conversationId, this.messageId, this.toolCallId, this.flowrunId, this.flowrunNodeId, this.flowrunIteration, required this.createdAt}): _input = input;
  factory _FunctionExecution.fromJson(Map<String, dynamic> json) => _$FunctionExecutionFromJson(json);

@override final  String id;
@override final  String functionId;
@override@JsonKey() final  String versionId;
@override@JsonKey() final  String status;
@override@JsonKey() final  String triggeredBy;
 final  Map<String, Object?> _input;
@override@JsonKey() Map<String, Object?> get input {
  if (_input is EqualUnmodifiableMapView) return _input;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_input);
}

@override final  Object? output;
@override final  String? errorMessage;
@override final  String? logs;
@override@JsonKey() final  int elapsedMs;
@override final  DateTime? startedAt;
@override final  DateTime? endedAt;
@override final  String? conversationId;
@override final  String? messageId;
@override final  String? toolCallId;
@override final  String? flowrunId;
@override final  String? flowrunNodeId;
@override final  int? flowrunIteration;
@override final  DateTime createdAt;

/// Create a copy of FunctionExecution
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FunctionExecutionCopyWith<_FunctionExecution> get copyWith => __$FunctionExecutionCopyWithImpl<_FunctionExecution>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FunctionExecutionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FunctionExecution&&(identical(other.id, id) || other.id == id)&&(identical(other.functionId, functionId) || other.functionId == functionId)&&(identical(other.versionId, versionId) || other.versionId == versionId)&&(identical(other.status, status) || other.status == status)&&(identical(other.triggeredBy, triggeredBy) || other.triggeredBy == triggeredBy)&&const DeepCollectionEquality().equals(other._input, _input)&&const DeepCollectionEquality().equals(other.output, output)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.logs, logs) || other.logs == logs)&&(identical(other.elapsedMs, elapsedMs) || other.elapsedMs == elapsedMs)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.flowrunId, flowrunId) || other.flowrunId == flowrunId)&&(identical(other.flowrunNodeId, flowrunNodeId) || other.flowrunNodeId == flowrunNodeId)&&(identical(other.flowrunIteration, flowrunIteration) || other.flowrunIteration == flowrunIteration)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,functionId,versionId,status,triggeredBy,const DeepCollectionEquality().hash(_input),const DeepCollectionEquality().hash(output),errorMessage,logs,elapsedMs,startedAt,endedAt,conversationId,messageId,toolCallId,flowrunId,flowrunNodeId,flowrunIteration,createdAt]);

@override
String toString() {
  return 'FunctionExecution(id: $id, functionId: $functionId, versionId: $versionId, status: $status, triggeredBy: $triggeredBy, input: $input, output: $output, errorMessage: $errorMessage, logs: $logs, elapsedMs: $elapsedMs, startedAt: $startedAt, endedAt: $endedAt, conversationId: $conversationId, messageId: $messageId, toolCallId: $toolCallId, flowrunId: $flowrunId, flowrunNodeId: $flowrunNodeId, flowrunIteration: $flowrunIteration, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$FunctionExecutionCopyWith<$Res> implements $FunctionExecutionCopyWith<$Res> {
  factory _$FunctionExecutionCopyWith(_FunctionExecution value, $Res Function(_FunctionExecution) _then) = __$FunctionExecutionCopyWithImpl;
@override @useResult
$Res call({
 String id, String functionId, String versionId, String status, String triggeredBy, Map<String, Object?> input, Object? output, String? errorMessage, String? logs, int elapsedMs, DateTime? startedAt, DateTime? endedAt, String? conversationId, String? messageId, String? toolCallId, String? flowrunId, String? flowrunNodeId, int? flowrunIteration, DateTime createdAt
});




}
/// @nodoc
class __$FunctionExecutionCopyWithImpl<$Res>
    implements _$FunctionExecutionCopyWith<$Res> {
  __$FunctionExecutionCopyWithImpl(this._self, this._then);

  final _FunctionExecution _self;
  final $Res Function(_FunctionExecution) _then;

/// Create a copy of FunctionExecution
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? functionId = null,Object? versionId = null,Object? status = null,Object? triggeredBy = null,Object? input = null,Object? output = freezed,Object? errorMessage = freezed,Object? logs = freezed,Object? elapsedMs = null,Object? startedAt = freezed,Object? endedAt = freezed,Object? conversationId = freezed,Object? messageId = freezed,Object? toolCallId = freezed,Object? flowrunId = freezed,Object? flowrunNodeId = freezed,Object? flowrunIteration = freezed,Object? createdAt = null,}) {
  return _then(_FunctionExecution(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,functionId: null == functionId ? _self.functionId : functionId // ignore: cast_nullable_to_non_nullable
as String,versionId: null == versionId ? _self.versionId : versionId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,triggeredBy: null == triggeredBy ? _self.triggeredBy : triggeredBy // ignore: cast_nullable_to_non_nullable
as String,input: null == input ? _self._input : input // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,output: freezed == output ? _self.output : output ,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,logs: freezed == logs ? _self.logs : logs // ignore: cast_nullable_to_non_nullable
as String?,elapsedMs: null == elapsedMs ? _self.elapsedMs : elapsedMs // ignore: cast_nullable_to_non_nullable
as int,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,conversationId: freezed == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String?,messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String?,toolCallId: freezed == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String?,flowrunId: freezed == flowrunId ? _self.flowrunId : flowrunId // ignore: cast_nullable_to_non_nullable
as String?,flowrunNodeId: freezed == flowrunNodeId ? _self.flowrunNodeId : flowrunNodeId // ignore: cast_nullable_to_non_nullable
as String?,flowrunIteration: freezed == flowrunIteration ? _self.flowrunIteration : flowrunIteration // ignore: cast_nullable_to_non_nullable
as int?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$FunctionRunResult {

 bool get ok; Object? get output; String get errorMsg; int get elapsedMs; String? get logs;
/// Create a copy of FunctionRunResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FunctionRunResultCopyWith<FunctionRunResult> get copyWith => _$FunctionRunResultCopyWithImpl<FunctionRunResult>(this as FunctionRunResult, _$identity);

  /// Serializes this FunctionRunResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FunctionRunResult&&(identical(other.ok, ok) || other.ok == ok)&&const DeepCollectionEquality().equals(other.output, output)&&(identical(other.errorMsg, errorMsg) || other.errorMsg == errorMsg)&&(identical(other.elapsedMs, elapsedMs) || other.elapsedMs == elapsedMs)&&(identical(other.logs, logs) || other.logs == logs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ok,const DeepCollectionEquality().hash(output),errorMsg,elapsedMs,logs);

@override
String toString() {
  return 'FunctionRunResult(ok: $ok, output: $output, errorMsg: $errorMsg, elapsedMs: $elapsedMs, logs: $logs)';
}


}

/// @nodoc
abstract mixin class $FunctionRunResultCopyWith<$Res>  {
  factory $FunctionRunResultCopyWith(FunctionRunResult value, $Res Function(FunctionRunResult) _then) = _$FunctionRunResultCopyWithImpl;
@useResult
$Res call({
 bool ok, Object? output, String errorMsg, int elapsedMs, String? logs
});




}
/// @nodoc
class _$FunctionRunResultCopyWithImpl<$Res>
    implements $FunctionRunResultCopyWith<$Res> {
  _$FunctionRunResultCopyWithImpl(this._self, this._then);

  final FunctionRunResult _self;
  final $Res Function(FunctionRunResult) _then;

/// Create a copy of FunctionRunResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ok = null,Object? output = freezed,Object? errorMsg = null,Object? elapsedMs = null,Object? logs = freezed,}) {
  return _then(_self.copyWith(
ok: null == ok ? _self.ok : ok // ignore: cast_nullable_to_non_nullable
as bool,output: freezed == output ? _self.output : output ,errorMsg: null == errorMsg ? _self.errorMsg : errorMsg // ignore: cast_nullable_to_non_nullable
as String,elapsedMs: null == elapsedMs ? _self.elapsedMs : elapsedMs // ignore: cast_nullable_to_non_nullable
as int,logs: freezed == logs ? _self.logs : logs // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FunctionRunResult].
extension FunctionRunResultPatterns on FunctionRunResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FunctionRunResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FunctionRunResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FunctionRunResult value)  $default,){
final _that = this;
switch (_that) {
case _FunctionRunResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FunctionRunResult value)?  $default,){
final _that = this;
switch (_that) {
case _FunctionRunResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool ok,  Object? output,  String errorMsg,  int elapsedMs,  String? logs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FunctionRunResult() when $default != null:
return $default(_that.ok,_that.output,_that.errorMsg,_that.elapsedMs,_that.logs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool ok,  Object? output,  String errorMsg,  int elapsedMs,  String? logs)  $default,) {final _that = this;
switch (_that) {
case _FunctionRunResult():
return $default(_that.ok,_that.output,_that.errorMsg,_that.elapsedMs,_that.logs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool ok,  Object? output,  String errorMsg,  int elapsedMs,  String? logs)?  $default,) {final _that = this;
switch (_that) {
case _FunctionRunResult() when $default != null:
return $default(_that.ok,_that.output,_that.errorMsg,_that.elapsedMs,_that.logs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FunctionRunResult implements FunctionRunResult {
  const _FunctionRunResult({this.ok = false, this.output, this.errorMsg = '', this.elapsedMs = 0, this.logs});
  factory _FunctionRunResult.fromJson(Map<String, dynamic> json) => _$FunctionRunResultFromJson(json);

@override@JsonKey() final  bool ok;
@override final  Object? output;
@override@JsonKey() final  String errorMsg;
@override@JsonKey() final  int elapsedMs;
@override final  String? logs;

/// Create a copy of FunctionRunResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FunctionRunResultCopyWith<_FunctionRunResult> get copyWith => __$FunctionRunResultCopyWithImpl<_FunctionRunResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FunctionRunResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FunctionRunResult&&(identical(other.ok, ok) || other.ok == ok)&&const DeepCollectionEquality().equals(other.output, output)&&(identical(other.errorMsg, errorMsg) || other.errorMsg == errorMsg)&&(identical(other.elapsedMs, elapsedMs) || other.elapsedMs == elapsedMs)&&(identical(other.logs, logs) || other.logs == logs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ok,const DeepCollectionEquality().hash(output),errorMsg,elapsedMs,logs);

@override
String toString() {
  return 'FunctionRunResult(ok: $ok, output: $output, errorMsg: $errorMsg, elapsedMs: $elapsedMs, logs: $logs)';
}


}

/// @nodoc
abstract mixin class _$FunctionRunResultCopyWith<$Res> implements $FunctionRunResultCopyWith<$Res> {
  factory _$FunctionRunResultCopyWith(_FunctionRunResult value, $Res Function(_FunctionRunResult) _then) = __$FunctionRunResultCopyWithImpl;
@override @useResult
$Res call({
 bool ok, Object? output, String errorMsg, int elapsedMs, String? logs
});




}
/// @nodoc
class __$FunctionRunResultCopyWithImpl<$Res>
    implements _$FunctionRunResultCopyWith<$Res> {
  __$FunctionRunResultCopyWithImpl(this._self, this._then);

  final _FunctionRunResult _self;
  final $Res Function(_FunctionRunResult) _then;

/// Create a copy of FunctionRunResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ok = null,Object? output = freezed,Object? errorMsg = null,Object? elapsedMs = null,Object? logs = freezed,}) {
  return _then(_FunctionRunResult(
ok: null == ok ? _self.ok : ok // ignore: cast_nullable_to_non_nullable
as bool,output: freezed == output ? _self.output : output ,errorMsg: null == errorMsg ? _self.errorMsg : errorMsg // ignore: cast_nullable_to_non_nullable
as String,elapsedMs: null == elapsedMs ? _self.elapsedMs : elapsedMs // ignore: cast_nullable_to_non_nullable
as int,logs: freezed == logs ? _self.logs : logs // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
