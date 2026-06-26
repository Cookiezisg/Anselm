// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AgentEntity {

 String get id; String get name; String get description; List<String> get tags; String get activeVersionId; DateTime get createdAt; DateTime get updatedAt; AgentVersion? get activeVersion;
/// Create a copy of AgentEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentEntityCopyWith<AgentEntity> get copyWith => _$AgentEntityCopyWithImpl<AgentEntity>(this as AgentEntity, _$identity);

  /// Serializes this AgentEntity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.activeVersionId, activeVersionId) || other.activeVersionId == activeVersionId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.activeVersion, activeVersion) || other.activeVersion == activeVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,const DeepCollectionEquality().hash(tags),activeVersionId,createdAt,updatedAt,activeVersion);

@override
String toString() {
  return 'AgentEntity(id: $id, name: $name, description: $description, tags: $tags, activeVersionId: $activeVersionId, createdAt: $createdAt, updatedAt: $updatedAt, activeVersion: $activeVersion)';
}


}

/// @nodoc
abstract mixin class $AgentEntityCopyWith<$Res>  {
  factory $AgentEntityCopyWith(AgentEntity value, $Res Function(AgentEntity) _then) = _$AgentEntityCopyWithImpl;
@useResult
$Res call({
 String id, String name, String description, List<String> tags, String activeVersionId, DateTime createdAt, DateTime updatedAt, AgentVersion? activeVersion
});


$AgentVersionCopyWith<$Res>? get activeVersion;

}
/// @nodoc
class _$AgentEntityCopyWithImpl<$Res>
    implements $AgentEntityCopyWith<$Res> {
  _$AgentEntityCopyWithImpl(this._self, this._then);

  final AgentEntity _self;
  final $Res Function(AgentEntity) _then;

/// Create a copy of AgentEntity
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
as AgentVersion?,
  ));
}
/// Create a copy of AgentEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentVersionCopyWith<$Res>? get activeVersion {
    if (_self.activeVersion == null) {
    return null;
  }

  return $AgentVersionCopyWith<$Res>(_self.activeVersion!, (value) {
    return _then(_self.copyWith(activeVersion: value));
  });
}
}


/// Adds pattern-matching-related methods to [AgentEntity].
extension AgentEntityPatterns on AgentEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentEntity value)  $default,){
final _that = this;
switch (_that) {
case _AgentEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentEntity value)?  $default,){
final _that = this;
switch (_that) {
case _AgentEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String description,  List<String> tags,  String activeVersionId,  DateTime createdAt,  DateTime updatedAt,  AgentVersion? activeVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentEntity() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String description,  List<String> tags,  String activeVersionId,  DateTime createdAt,  DateTime updatedAt,  AgentVersion? activeVersion)  $default,) {final _that = this;
switch (_that) {
case _AgentEntity():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String description,  List<String> tags,  String activeVersionId,  DateTime createdAt,  DateTime updatedAt,  AgentVersion? activeVersion)?  $default,) {final _that = this;
switch (_that) {
case _AgentEntity() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.tags,_that.activeVersionId,_that.createdAt,_that.updatedAt,_that.activeVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentEntity implements AgentEntity {
  const _AgentEntity({required this.id, this.name = '', this.description = '', final  List<String> tags = const <String>[], this.activeVersionId = '', required this.createdAt, required this.updatedAt, this.activeVersion}): _tags = tags;
  factory _AgentEntity.fromJson(Map<String, dynamic> json) => _$AgentEntityFromJson(json);

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
@override final  AgentVersion? activeVersion;

/// Create a copy of AgentEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentEntityCopyWith<_AgentEntity> get copyWith => __$AgentEntityCopyWithImpl<_AgentEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.activeVersionId, activeVersionId) || other.activeVersionId == activeVersionId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.activeVersion, activeVersion) || other.activeVersion == activeVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,const DeepCollectionEquality().hash(_tags),activeVersionId,createdAt,updatedAt,activeVersion);

@override
String toString() {
  return 'AgentEntity(id: $id, name: $name, description: $description, tags: $tags, activeVersionId: $activeVersionId, createdAt: $createdAt, updatedAt: $updatedAt, activeVersion: $activeVersion)';
}


}

/// @nodoc
abstract mixin class _$AgentEntityCopyWith<$Res> implements $AgentEntityCopyWith<$Res> {
  factory _$AgentEntityCopyWith(_AgentEntity value, $Res Function(_AgentEntity) _then) = __$AgentEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String description, List<String> tags, String activeVersionId, DateTime createdAt, DateTime updatedAt, AgentVersion? activeVersion
});


@override $AgentVersionCopyWith<$Res>? get activeVersion;

}
/// @nodoc
class __$AgentEntityCopyWithImpl<$Res>
    implements _$AgentEntityCopyWith<$Res> {
  __$AgentEntityCopyWithImpl(this._self, this._then);

  final _AgentEntity _self;
  final $Res Function(_AgentEntity) _then;

/// Create a copy of AgentEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = null,Object? tags = null,Object? activeVersionId = null,Object? createdAt = null,Object? updatedAt = null,Object? activeVersion = freezed,}) {
  return _then(_AgentEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,activeVersionId: null == activeVersionId ? _self.activeVersionId : activeVersionId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,activeVersion: freezed == activeVersion ? _self.activeVersion : activeVersion // ignore: cast_nullable_to_non_nullable
as AgentVersion?,
  ));
}

/// Create a copy of AgentEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentVersionCopyWith<$Res>? get activeVersion {
    if (_self.activeVersion == null) {
    return null;
  }

  return $AgentVersionCopyWith<$Res>(_self.activeVersion!, (value) {
    return _then(_self.copyWith(activeVersion: value));
  });
}
}


/// @nodoc
mixin _$AgentVersion {

 String get id; String get agentId; int get version; String get prompt; String? get skill; List<String> get knowledge; List<ToolRef> get tools; List<Field> get inputs; List<Field> get outputs; ModelRef? get modelOverride; String? get changeReason; String? get builtInConversationId; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of AgentVersion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentVersionCopyWith<AgentVersion> get copyWith => _$AgentVersionCopyWithImpl<AgentVersion>(this as AgentVersion, _$identity);

  /// Serializes this AgentVersion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentVersion&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.version, version) || other.version == version)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.skill, skill) || other.skill == skill)&&const DeepCollectionEquality().equals(other.knowledge, knowledge)&&const DeepCollectionEquality().equals(other.tools, tools)&&const DeepCollectionEquality().equals(other.inputs, inputs)&&const DeepCollectionEquality().equals(other.outputs, outputs)&&(identical(other.modelOverride, modelOverride) || other.modelOverride == modelOverride)&&(identical(other.changeReason, changeReason) || other.changeReason == changeReason)&&(identical(other.builtInConversationId, builtInConversationId) || other.builtInConversationId == builtInConversationId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,version,prompt,skill,const DeepCollectionEquality().hash(knowledge),const DeepCollectionEquality().hash(tools),const DeepCollectionEquality().hash(inputs),const DeepCollectionEquality().hash(outputs),modelOverride,changeReason,builtInConversationId,createdAt,updatedAt);

@override
String toString() {
  return 'AgentVersion(id: $id, agentId: $agentId, version: $version, prompt: $prompt, skill: $skill, knowledge: $knowledge, tools: $tools, inputs: $inputs, outputs: $outputs, modelOverride: $modelOverride, changeReason: $changeReason, builtInConversationId: $builtInConversationId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $AgentVersionCopyWith<$Res>  {
  factory $AgentVersionCopyWith(AgentVersion value, $Res Function(AgentVersion) _then) = _$AgentVersionCopyWithImpl;
@useResult
$Res call({
 String id, String agentId, int version, String prompt, String? skill, List<String> knowledge, List<ToolRef> tools, List<Field> inputs, List<Field> outputs, ModelRef? modelOverride, String? changeReason, String? builtInConversationId, DateTime createdAt, DateTime updatedAt
});


$ModelRefCopyWith<$Res>? get modelOverride;

}
/// @nodoc
class _$AgentVersionCopyWithImpl<$Res>
    implements $AgentVersionCopyWith<$Res> {
  _$AgentVersionCopyWithImpl(this._self, this._then);

  final AgentVersion _self;
  final $Res Function(AgentVersion) _then;

/// Create a copy of AgentVersion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? agentId = null,Object? version = null,Object? prompt = null,Object? skill = freezed,Object? knowledge = null,Object? tools = null,Object? inputs = null,Object? outputs = null,Object? modelOverride = freezed,Object? changeReason = freezed,Object? builtInConversationId = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,skill: freezed == skill ? _self.skill : skill // ignore: cast_nullable_to_non_nullable
as String?,knowledge: null == knowledge ? _self.knowledge : knowledge // ignore: cast_nullable_to_non_nullable
as List<String>,tools: null == tools ? _self.tools : tools // ignore: cast_nullable_to_non_nullable
as List<ToolRef>,inputs: null == inputs ? _self.inputs : inputs // ignore: cast_nullable_to_non_nullable
as List<Field>,outputs: null == outputs ? _self.outputs : outputs // ignore: cast_nullable_to_non_nullable
as List<Field>,modelOverride: freezed == modelOverride ? _self.modelOverride : modelOverride // ignore: cast_nullable_to_non_nullable
as ModelRef?,changeReason: freezed == changeReason ? _self.changeReason : changeReason // ignore: cast_nullable_to_non_nullable
as String?,builtInConversationId: freezed == builtInConversationId ? _self.builtInConversationId : builtInConversationId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of AgentVersion
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


/// Adds pattern-matching-related methods to [AgentVersion].
extension AgentVersionPatterns on AgentVersion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentVersion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentVersion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentVersion value)  $default,){
final _that = this;
switch (_that) {
case _AgentVersion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentVersion value)?  $default,){
final _that = this;
switch (_that) {
case _AgentVersion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String agentId,  int version,  String prompt,  String? skill,  List<String> knowledge,  List<ToolRef> tools,  List<Field> inputs,  List<Field> outputs,  ModelRef? modelOverride,  String? changeReason,  String? builtInConversationId,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentVersion() when $default != null:
return $default(_that.id,_that.agentId,_that.version,_that.prompt,_that.skill,_that.knowledge,_that.tools,_that.inputs,_that.outputs,_that.modelOverride,_that.changeReason,_that.builtInConversationId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String agentId,  int version,  String prompt,  String? skill,  List<String> knowledge,  List<ToolRef> tools,  List<Field> inputs,  List<Field> outputs,  ModelRef? modelOverride,  String? changeReason,  String? builtInConversationId,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _AgentVersion():
return $default(_that.id,_that.agentId,_that.version,_that.prompt,_that.skill,_that.knowledge,_that.tools,_that.inputs,_that.outputs,_that.modelOverride,_that.changeReason,_that.builtInConversationId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String agentId,  int version,  String prompt,  String? skill,  List<String> knowledge,  List<ToolRef> tools,  List<Field> inputs,  List<Field> outputs,  ModelRef? modelOverride,  String? changeReason,  String? builtInConversationId,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _AgentVersion() when $default != null:
return $default(_that.id,_that.agentId,_that.version,_that.prompt,_that.skill,_that.knowledge,_that.tools,_that.inputs,_that.outputs,_that.modelOverride,_that.changeReason,_that.builtInConversationId,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentVersion implements AgentVersion {
  const _AgentVersion({required this.id, required this.agentId, required this.version, this.prompt = '', this.skill, final  List<String> knowledge = const <String>[], final  List<ToolRef> tools = const <ToolRef>[], final  List<Field> inputs = const <Field>[], final  List<Field> outputs = const <Field>[], this.modelOverride, this.changeReason, this.builtInConversationId, required this.createdAt, required this.updatedAt}): _knowledge = knowledge,_tools = tools,_inputs = inputs,_outputs = outputs;
  factory _AgentVersion.fromJson(Map<String, dynamic> json) => _$AgentVersionFromJson(json);

@override final  String id;
@override final  String agentId;
@override final  int version;
@override@JsonKey() final  String prompt;
@override final  String? skill;
 final  List<String> _knowledge;
@override@JsonKey() List<String> get knowledge {
  if (_knowledge is EqualUnmodifiableListView) return _knowledge;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_knowledge);
}

 final  List<ToolRef> _tools;
@override@JsonKey() List<ToolRef> get tools {
  if (_tools is EqualUnmodifiableListView) return _tools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tools);
}

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

@override final  ModelRef? modelOverride;
@override final  String? changeReason;
@override final  String? builtInConversationId;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of AgentVersion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentVersionCopyWith<_AgentVersion> get copyWith => __$AgentVersionCopyWithImpl<_AgentVersion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentVersionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentVersion&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.version, version) || other.version == version)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.skill, skill) || other.skill == skill)&&const DeepCollectionEquality().equals(other._knowledge, _knowledge)&&const DeepCollectionEquality().equals(other._tools, _tools)&&const DeepCollectionEquality().equals(other._inputs, _inputs)&&const DeepCollectionEquality().equals(other._outputs, _outputs)&&(identical(other.modelOverride, modelOverride) || other.modelOverride == modelOverride)&&(identical(other.changeReason, changeReason) || other.changeReason == changeReason)&&(identical(other.builtInConversationId, builtInConversationId) || other.builtInConversationId == builtInConversationId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,version,prompt,skill,const DeepCollectionEquality().hash(_knowledge),const DeepCollectionEquality().hash(_tools),const DeepCollectionEquality().hash(_inputs),const DeepCollectionEquality().hash(_outputs),modelOverride,changeReason,builtInConversationId,createdAt,updatedAt);

@override
String toString() {
  return 'AgentVersion(id: $id, agentId: $agentId, version: $version, prompt: $prompt, skill: $skill, knowledge: $knowledge, tools: $tools, inputs: $inputs, outputs: $outputs, modelOverride: $modelOverride, changeReason: $changeReason, builtInConversationId: $builtInConversationId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$AgentVersionCopyWith<$Res> implements $AgentVersionCopyWith<$Res> {
  factory _$AgentVersionCopyWith(_AgentVersion value, $Res Function(_AgentVersion) _then) = __$AgentVersionCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, int version, String prompt, String? skill, List<String> knowledge, List<ToolRef> tools, List<Field> inputs, List<Field> outputs, ModelRef? modelOverride, String? changeReason, String? builtInConversationId, DateTime createdAt, DateTime updatedAt
});


@override $ModelRefCopyWith<$Res>? get modelOverride;

}
/// @nodoc
class __$AgentVersionCopyWithImpl<$Res>
    implements _$AgentVersionCopyWith<$Res> {
  __$AgentVersionCopyWithImpl(this._self, this._then);

  final _AgentVersion _self;
  final $Res Function(_AgentVersion) _then;

/// Create a copy of AgentVersion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? version = null,Object? prompt = null,Object? skill = freezed,Object? knowledge = null,Object? tools = null,Object? inputs = null,Object? outputs = null,Object? modelOverride = freezed,Object? changeReason = freezed,Object? builtInConversationId = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_AgentVersion(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,skill: freezed == skill ? _self.skill : skill // ignore: cast_nullable_to_non_nullable
as String?,knowledge: null == knowledge ? _self._knowledge : knowledge // ignore: cast_nullable_to_non_nullable
as List<String>,tools: null == tools ? _self._tools : tools // ignore: cast_nullable_to_non_nullable
as List<ToolRef>,inputs: null == inputs ? _self._inputs : inputs // ignore: cast_nullable_to_non_nullable
as List<Field>,outputs: null == outputs ? _self._outputs : outputs // ignore: cast_nullable_to_non_nullable
as List<Field>,modelOverride: freezed == modelOverride ? _self.modelOverride : modelOverride // ignore: cast_nullable_to_non_nullable
as ModelRef?,changeReason: freezed == changeReason ? _self.changeReason : changeReason // ignore: cast_nullable_to_non_nullable
as String?,builtInConversationId: freezed == builtInConversationId ? _self.builtInConversationId : builtInConversationId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of AgentVersion
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
mixin _$AgentExecution {

 String get id; String get agentId; String get versionId; String get status; String get triggeredBy; Map<String, Object?> get input; Object? get output; String? get errorMessage; int get elapsedMs; String? get modelId; String? get apiKeyId; String? get provider; Object? get transcript; DateTime? get startedAt; DateTime? get endedAt; String? get conversationId; String? get messageId; String? get toolCallId; String? get flowrunId; String? get flowrunNodeId; int? get flowrunIteration; DateTime get createdAt;
/// Create a copy of AgentExecution
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentExecutionCopyWith<AgentExecution> get copyWith => _$AgentExecutionCopyWithImpl<AgentExecution>(this as AgentExecution, _$identity);

  /// Serializes this AgentExecution to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentExecution&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.versionId, versionId) || other.versionId == versionId)&&(identical(other.status, status) || other.status == status)&&(identical(other.triggeredBy, triggeredBy) || other.triggeredBy == triggeredBy)&&const DeepCollectionEquality().equals(other.input, input)&&const DeepCollectionEquality().equals(other.output, output)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.elapsedMs, elapsedMs) || other.elapsedMs == elapsedMs)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.apiKeyId, apiKeyId) || other.apiKeyId == apiKeyId)&&(identical(other.provider, provider) || other.provider == provider)&&const DeepCollectionEquality().equals(other.transcript, transcript)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.flowrunId, flowrunId) || other.flowrunId == flowrunId)&&(identical(other.flowrunNodeId, flowrunNodeId) || other.flowrunNodeId == flowrunNodeId)&&(identical(other.flowrunIteration, flowrunIteration) || other.flowrunIteration == flowrunIteration)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,agentId,versionId,status,triggeredBy,const DeepCollectionEquality().hash(input),const DeepCollectionEquality().hash(output),errorMessage,elapsedMs,modelId,apiKeyId,provider,const DeepCollectionEquality().hash(transcript),startedAt,endedAt,conversationId,messageId,toolCallId,flowrunId,flowrunNodeId,flowrunIteration,createdAt]);

@override
String toString() {
  return 'AgentExecution(id: $id, agentId: $agentId, versionId: $versionId, status: $status, triggeredBy: $triggeredBy, input: $input, output: $output, errorMessage: $errorMessage, elapsedMs: $elapsedMs, modelId: $modelId, apiKeyId: $apiKeyId, provider: $provider, transcript: $transcript, startedAt: $startedAt, endedAt: $endedAt, conversationId: $conversationId, messageId: $messageId, toolCallId: $toolCallId, flowrunId: $flowrunId, flowrunNodeId: $flowrunNodeId, flowrunIteration: $flowrunIteration, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $AgentExecutionCopyWith<$Res>  {
  factory $AgentExecutionCopyWith(AgentExecution value, $Res Function(AgentExecution) _then) = _$AgentExecutionCopyWithImpl;
@useResult
$Res call({
 String id, String agentId, String versionId, String status, String triggeredBy, Map<String, Object?> input, Object? output, String? errorMessage, int elapsedMs, String? modelId, String? apiKeyId, String? provider, Object? transcript, DateTime? startedAt, DateTime? endedAt, String? conversationId, String? messageId, String? toolCallId, String? flowrunId, String? flowrunNodeId, int? flowrunIteration, DateTime createdAt
});




}
/// @nodoc
class _$AgentExecutionCopyWithImpl<$Res>
    implements $AgentExecutionCopyWith<$Res> {
  _$AgentExecutionCopyWithImpl(this._self, this._then);

  final AgentExecution _self;
  final $Res Function(AgentExecution) _then;

/// Create a copy of AgentExecution
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? agentId = null,Object? versionId = null,Object? status = null,Object? triggeredBy = null,Object? input = null,Object? output = freezed,Object? errorMessage = freezed,Object? elapsedMs = null,Object? modelId = freezed,Object? apiKeyId = freezed,Object? provider = freezed,Object? transcript = freezed,Object? startedAt = freezed,Object? endedAt = freezed,Object? conversationId = freezed,Object? messageId = freezed,Object? toolCallId = freezed,Object? flowrunId = freezed,Object? flowrunNodeId = freezed,Object? flowrunIteration = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,versionId: null == versionId ? _self.versionId : versionId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,triggeredBy: null == triggeredBy ? _self.triggeredBy : triggeredBy // ignore: cast_nullable_to_non_nullable
as String,input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,output: freezed == output ? _self.output : output ,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,elapsedMs: null == elapsedMs ? _self.elapsedMs : elapsedMs // ignore: cast_nullable_to_non_nullable
as int,modelId: freezed == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String?,apiKeyId: freezed == apiKeyId ? _self.apiKeyId : apiKeyId // ignore: cast_nullable_to_non_nullable
as String?,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,transcript: freezed == transcript ? _self.transcript : transcript ,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
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


/// Adds pattern-matching-related methods to [AgentExecution].
extension AgentExecutionPatterns on AgentExecution {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentExecution value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentExecution() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentExecution value)  $default,){
final _that = this;
switch (_that) {
case _AgentExecution():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentExecution value)?  $default,){
final _that = this;
switch (_that) {
case _AgentExecution() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String agentId,  String versionId,  String status,  String triggeredBy,  Map<String, Object?> input,  Object? output,  String? errorMessage,  int elapsedMs,  String? modelId,  String? apiKeyId,  String? provider,  Object? transcript,  DateTime? startedAt,  DateTime? endedAt,  String? conversationId,  String? messageId,  String? toolCallId,  String? flowrunId,  String? flowrunNodeId,  int? flowrunIteration,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentExecution() when $default != null:
return $default(_that.id,_that.agentId,_that.versionId,_that.status,_that.triggeredBy,_that.input,_that.output,_that.errorMessage,_that.elapsedMs,_that.modelId,_that.apiKeyId,_that.provider,_that.transcript,_that.startedAt,_that.endedAt,_that.conversationId,_that.messageId,_that.toolCallId,_that.flowrunId,_that.flowrunNodeId,_that.flowrunIteration,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String agentId,  String versionId,  String status,  String triggeredBy,  Map<String, Object?> input,  Object? output,  String? errorMessage,  int elapsedMs,  String? modelId,  String? apiKeyId,  String? provider,  Object? transcript,  DateTime? startedAt,  DateTime? endedAt,  String? conversationId,  String? messageId,  String? toolCallId,  String? flowrunId,  String? flowrunNodeId,  int? flowrunIteration,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _AgentExecution():
return $default(_that.id,_that.agentId,_that.versionId,_that.status,_that.triggeredBy,_that.input,_that.output,_that.errorMessage,_that.elapsedMs,_that.modelId,_that.apiKeyId,_that.provider,_that.transcript,_that.startedAt,_that.endedAt,_that.conversationId,_that.messageId,_that.toolCallId,_that.flowrunId,_that.flowrunNodeId,_that.flowrunIteration,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String agentId,  String versionId,  String status,  String triggeredBy,  Map<String, Object?> input,  Object? output,  String? errorMessage,  int elapsedMs,  String? modelId,  String? apiKeyId,  String? provider,  Object? transcript,  DateTime? startedAt,  DateTime? endedAt,  String? conversationId,  String? messageId,  String? toolCallId,  String? flowrunId,  String? flowrunNodeId,  int? flowrunIteration,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _AgentExecution() when $default != null:
return $default(_that.id,_that.agentId,_that.versionId,_that.status,_that.triggeredBy,_that.input,_that.output,_that.errorMessage,_that.elapsedMs,_that.modelId,_that.apiKeyId,_that.provider,_that.transcript,_that.startedAt,_that.endedAt,_that.conversationId,_that.messageId,_that.toolCallId,_that.flowrunId,_that.flowrunNodeId,_that.flowrunIteration,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentExecution implements AgentExecution {
  const _AgentExecution({required this.id, required this.agentId, this.versionId = '', this.status = '', this.triggeredBy = '', final  Map<String, Object?> input = const <String, Object?>{}, this.output, this.errorMessage, this.elapsedMs = 0, this.modelId, this.apiKeyId, this.provider, this.transcript, this.startedAt, this.endedAt, this.conversationId, this.messageId, this.toolCallId, this.flowrunId, this.flowrunNodeId, this.flowrunIteration, required this.createdAt}): _input = input;
  factory _AgentExecution.fromJson(Map<String, dynamic> json) => _$AgentExecutionFromJson(json);

@override final  String id;
@override final  String agentId;
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
@override@JsonKey() final  int elapsedMs;
@override final  String? modelId;
@override final  String? apiKeyId;
@override final  String? provider;
@override final  Object? transcript;
@override final  DateTime? startedAt;
@override final  DateTime? endedAt;
@override final  String? conversationId;
@override final  String? messageId;
@override final  String? toolCallId;
@override final  String? flowrunId;
@override final  String? flowrunNodeId;
@override final  int? flowrunIteration;
@override final  DateTime createdAt;

/// Create a copy of AgentExecution
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentExecutionCopyWith<_AgentExecution> get copyWith => __$AgentExecutionCopyWithImpl<_AgentExecution>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentExecutionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentExecution&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.versionId, versionId) || other.versionId == versionId)&&(identical(other.status, status) || other.status == status)&&(identical(other.triggeredBy, triggeredBy) || other.triggeredBy == triggeredBy)&&const DeepCollectionEquality().equals(other._input, _input)&&const DeepCollectionEquality().equals(other.output, output)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.elapsedMs, elapsedMs) || other.elapsedMs == elapsedMs)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.apiKeyId, apiKeyId) || other.apiKeyId == apiKeyId)&&(identical(other.provider, provider) || other.provider == provider)&&const DeepCollectionEquality().equals(other.transcript, transcript)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.flowrunId, flowrunId) || other.flowrunId == flowrunId)&&(identical(other.flowrunNodeId, flowrunNodeId) || other.flowrunNodeId == flowrunNodeId)&&(identical(other.flowrunIteration, flowrunIteration) || other.flowrunIteration == flowrunIteration)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,agentId,versionId,status,triggeredBy,const DeepCollectionEquality().hash(_input),const DeepCollectionEquality().hash(output),errorMessage,elapsedMs,modelId,apiKeyId,provider,const DeepCollectionEquality().hash(transcript),startedAt,endedAt,conversationId,messageId,toolCallId,flowrunId,flowrunNodeId,flowrunIteration,createdAt]);

@override
String toString() {
  return 'AgentExecution(id: $id, agentId: $agentId, versionId: $versionId, status: $status, triggeredBy: $triggeredBy, input: $input, output: $output, errorMessage: $errorMessage, elapsedMs: $elapsedMs, modelId: $modelId, apiKeyId: $apiKeyId, provider: $provider, transcript: $transcript, startedAt: $startedAt, endedAt: $endedAt, conversationId: $conversationId, messageId: $messageId, toolCallId: $toolCallId, flowrunId: $flowrunId, flowrunNodeId: $flowrunNodeId, flowrunIteration: $flowrunIteration, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$AgentExecutionCopyWith<$Res> implements $AgentExecutionCopyWith<$Res> {
  factory _$AgentExecutionCopyWith(_AgentExecution value, $Res Function(_AgentExecution) _then) = __$AgentExecutionCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String versionId, String status, String triggeredBy, Map<String, Object?> input, Object? output, String? errorMessage, int elapsedMs, String? modelId, String? apiKeyId, String? provider, Object? transcript, DateTime? startedAt, DateTime? endedAt, String? conversationId, String? messageId, String? toolCallId, String? flowrunId, String? flowrunNodeId, int? flowrunIteration, DateTime createdAt
});




}
/// @nodoc
class __$AgentExecutionCopyWithImpl<$Res>
    implements _$AgentExecutionCopyWith<$Res> {
  __$AgentExecutionCopyWithImpl(this._self, this._then);

  final _AgentExecution _self;
  final $Res Function(_AgentExecution) _then;

/// Create a copy of AgentExecution
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? versionId = null,Object? status = null,Object? triggeredBy = null,Object? input = null,Object? output = freezed,Object? errorMessage = freezed,Object? elapsedMs = null,Object? modelId = freezed,Object? apiKeyId = freezed,Object? provider = freezed,Object? transcript = freezed,Object? startedAt = freezed,Object? endedAt = freezed,Object? conversationId = freezed,Object? messageId = freezed,Object? toolCallId = freezed,Object? flowrunId = freezed,Object? flowrunNodeId = freezed,Object? flowrunIteration = freezed,Object? createdAt = null,}) {
  return _then(_AgentExecution(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,versionId: null == versionId ? _self.versionId : versionId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,triggeredBy: null == triggeredBy ? _self.triggeredBy : triggeredBy // ignore: cast_nullable_to_non_nullable
as String,input: null == input ? _self._input : input // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,output: freezed == output ? _self.output : output ,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,elapsedMs: null == elapsedMs ? _self.elapsedMs : elapsedMs // ignore: cast_nullable_to_non_nullable
as int,modelId: freezed == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String?,apiKeyId: freezed == apiKeyId ? _self.apiKeyId : apiKeyId // ignore: cast_nullable_to_non_nullable
as String?,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,transcript: freezed == transcript ? _self.transcript : transcript ,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
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
mixin _$InvokeResult {

 String get executionId; bool get ok; Object? get output; String get status; String? get stopReason; int get steps; int get tokensIn; int get tokensOut; String? get errorMsg; int get elapsedMs;
/// Create a copy of InvokeResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvokeResultCopyWith<InvokeResult> get copyWith => _$InvokeResultCopyWithImpl<InvokeResult>(this as InvokeResult, _$identity);

  /// Serializes this InvokeResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvokeResult&&(identical(other.executionId, executionId) || other.executionId == executionId)&&(identical(other.ok, ok) || other.ok == ok)&&const DeepCollectionEquality().equals(other.output, output)&&(identical(other.status, status) || other.status == status)&&(identical(other.stopReason, stopReason) || other.stopReason == stopReason)&&(identical(other.steps, steps) || other.steps == steps)&&(identical(other.tokensIn, tokensIn) || other.tokensIn == tokensIn)&&(identical(other.tokensOut, tokensOut) || other.tokensOut == tokensOut)&&(identical(other.errorMsg, errorMsg) || other.errorMsg == errorMsg)&&(identical(other.elapsedMs, elapsedMs) || other.elapsedMs == elapsedMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,executionId,ok,const DeepCollectionEquality().hash(output),status,stopReason,steps,tokensIn,tokensOut,errorMsg,elapsedMs);

@override
String toString() {
  return 'InvokeResult(executionId: $executionId, ok: $ok, output: $output, status: $status, stopReason: $stopReason, steps: $steps, tokensIn: $tokensIn, tokensOut: $tokensOut, errorMsg: $errorMsg, elapsedMs: $elapsedMs)';
}


}

/// @nodoc
abstract mixin class $InvokeResultCopyWith<$Res>  {
  factory $InvokeResultCopyWith(InvokeResult value, $Res Function(InvokeResult) _then) = _$InvokeResultCopyWithImpl;
@useResult
$Res call({
 String executionId, bool ok, Object? output, String status, String? stopReason, int steps, int tokensIn, int tokensOut, String? errorMsg, int elapsedMs
});




}
/// @nodoc
class _$InvokeResultCopyWithImpl<$Res>
    implements $InvokeResultCopyWith<$Res> {
  _$InvokeResultCopyWithImpl(this._self, this._then);

  final InvokeResult _self;
  final $Res Function(InvokeResult) _then;

/// Create a copy of InvokeResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? executionId = null,Object? ok = null,Object? output = freezed,Object? status = null,Object? stopReason = freezed,Object? steps = null,Object? tokensIn = null,Object? tokensOut = null,Object? errorMsg = freezed,Object? elapsedMs = null,}) {
  return _then(_self.copyWith(
executionId: null == executionId ? _self.executionId : executionId // ignore: cast_nullable_to_non_nullable
as String,ok: null == ok ? _self.ok : ok // ignore: cast_nullable_to_non_nullable
as bool,output: freezed == output ? _self.output : output ,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,stopReason: freezed == stopReason ? _self.stopReason : stopReason // ignore: cast_nullable_to_non_nullable
as String?,steps: null == steps ? _self.steps : steps // ignore: cast_nullable_to_non_nullable
as int,tokensIn: null == tokensIn ? _self.tokensIn : tokensIn // ignore: cast_nullable_to_non_nullable
as int,tokensOut: null == tokensOut ? _self.tokensOut : tokensOut // ignore: cast_nullable_to_non_nullable
as int,errorMsg: freezed == errorMsg ? _self.errorMsg : errorMsg // ignore: cast_nullable_to_non_nullable
as String?,elapsedMs: null == elapsedMs ? _self.elapsedMs : elapsedMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [InvokeResult].
extension InvokeResultPatterns on InvokeResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InvokeResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InvokeResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InvokeResult value)  $default,){
final _that = this;
switch (_that) {
case _InvokeResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InvokeResult value)?  $default,){
final _that = this;
switch (_that) {
case _InvokeResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String executionId,  bool ok,  Object? output,  String status,  String? stopReason,  int steps,  int tokensIn,  int tokensOut,  String? errorMsg,  int elapsedMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InvokeResult() when $default != null:
return $default(_that.executionId,_that.ok,_that.output,_that.status,_that.stopReason,_that.steps,_that.tokensIn,_that.tokensOut,_that.errorMsg,_that.elapsedMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String executionId,  bool ok,  Object? output,  String status,  String? stopReason,  int steps,  int tokensIn,  int tokensOut,  String? errorMsg,  int elapsedMs)  $default,) {final _that = this;
switch (_that) {
case _InvokeResult():
return $default(_that.executionId,_that.ok,_that.output,_that.status,_that.stopReason,_that.steps,_that.tokensIn,_that.tokensOut,_that.errorMsg,_that.elapsedMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String executionId,  bool ok,  Object? output,  String status,  String? stopReason,  int steps,  int tokensIn,  int tokensOut,  String? errorMsg,  int elapsedMs)?  $default,) {final _that = this;
switch (_that) {
case _InvokeResult() when $default != null:
return $default(_that.executionId,_that.ok,_that.output,_that.status,_that.stopReason,_that.steps,_that.tokensIn,_that.tokensOut,_that.errorMsg,_that.elapsedMs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InvokeResult implements InvokeResult {
  const _InvokeResult({this.executionId = '', this.ok = false, this.output, this.status = '', this.stopReason, this.steps = 0, this.tokensIn = 0, this.tokensOut = 0, this.errorMsg, this.elapsedMs = 0});
  factory _InvokeResult.fromJson(Map<String, dynamic> json) => _$InvokeResultFromJson(json);

@override@JsonKey() final  String executionId;
@override@JsonKey() final  bool ok;
@override final  Object? output;
@override@JsonKey() final  String status;
@override final  String? stopReason;
@override@JsonKey() final  int steps;
@override@JsonKey() final  int tokensIn;
@override@JsonKey() final  int tokensOut;
@override final  String? errorMsg;
@override@JsonKey() final  int elapsedMs;

/// Create a copy of InvokeResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvokeResultCopyWith<_InvokeResult> get copyWith => __$InvokeResultCopyWithImpl<_InvokeResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InvokeResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvokeResult&&(identical(other.executionId, executionId) || other.executionId == executionId)&&(identical(other.ok, ok) || other.ok == ok)&&const DeepCollectionEquality().equals(other.output, output)&&(identical(other.status, status) || other.status == status)&&(identical(other.stopReason, stopReason) || other.stopReason == stopReason)&&(identical(other.steps, steps) || other.steps == steps)&&(identical(other.tokensIn, tokensIn) || other.tokensIn == tokensIn)&&(identical(other.tokensOut, tokensOut) || other.tokensOut == tokensOut)&&(identical(other.errorMsg, errorMsg) || other.errorMsg == errorMsg)&&(identical(other.elapsedMs, elapsedMs) || other.elapsedMs == elapsedMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,executionId,ok,const DeepCollectionEquality().hash(output),status,stopReason,steps,tokensIn,tokensOut,errorMsg,elapsedMs);

@override
String toString() {
  return 'InvokeResult(executionId: $executionId, ok: $ok, output: $output, status: $status, stopReason: $stopReason, steps: $steps, tokensIn: $tokensIn, tokensOut: $tokensOut, errorMsg: $errorMsg, elapsedMs: $elapsedMs)';
}


}

/// @nodoc
abstract mixin class _$InvokeResultCopyWith<$Res> implements $InvokeResultCopyWith<$Res> {
  factory _$InvokeResultCopyWith(_InvokeResult value, $Res Function(_InvokeResult) _then) = __$InvokeResultCopyWithImpl;
@override @useResult
$Res call({
 String executionId, bool ok, Object? output, String status, String? stopReason, int steps, int tokensIn, int tokensOut, String? errorMsg, int elapsedMs
});




}
/// @nodoc
class __$InvokeResultCopyWithImpl<$Res>
    implements _$InvokeResultCopyWith<$Res> {
  __$InvokeResultCopyWithImpl(this._self, this._then);

  final _InvokeResult _self;
  final $Res Function(_InvokeResult) _then;

/// Create a copy of InvokeResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? executionId = null,Object? ok = null,Object? output = freezed,Object? status = null,Object? stopReason = freezed,Object? steps = null,Object? tokensIn = null,Object? tokensOut = null,Object? errorMsg = freezed,Object? elapsedMs = null,}) {
  return _then(_InvokeResult(
executionId: null == executionId ? _self.executionId : executionId // ignore: cast_nullable_to_non_nullable
as String,ok: null == ok ? _self.ok : ok // ignore: cast_nullable_to_non_nullable
as bool,output: freezed == output ? _self.output : output ,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,stopReason: freezed == stopReason ? _self.stopReason : stopReason // ignore: cast_nullable_to_non_nullable
as String?,steps: null == steps ? _self.steps : steps // ignore: cast_nullable_to_non_nullable
as int,tokensIn: null == tokensIn ? _self.tokensIn : tokensIn // ignore: cast_nullable_to_non_nullable
as int,tokensOut: null == tokensOut ? _self.tokensOut : tokensOut // ignore: cast_nullable_to_non_nullable
as int,errorMsg: freezed == errorMsg ? _self.errorMsg : errorMsg // ignore: cast_nullable_to_non_nullable
as String?,elapsedMs: null == elapsedMs ? _self.elapsedMs : elapsedMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$MountHealth {

 String get ref; String? get name; bool get healthy; String? get error;
/// Create a copy of MountHealth
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountHealthCopyWith<MountHealth> get copyWith => _$MountHealthCopyWithImpl<MountHealth>(this as MountHealth, _$identity);

  /// Serializes this MountHealth to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountHealth&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.name, name) || other.name == name)&&(identical(other.healthy, healthy) || other.healthy == healthy)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ref,name,healthy,error);

@override
String toString() {
  return 'MountHealth(ref: $ref, name: $name, healthy: $healthy, error: $error)';
}


}

/// @nodoc
abstract mixin class $MountHealthCopyWith<$Res>  {
  factory $MountHealthCopyWith(MountHealth value, $Res Function(MountHealth) _then) = _$MountHealthCopyWithImpl;
@useResult
$Res call({
 String ref, String? name, bool healthy, String? error
});




}
/// @nodoc
class _$MountHealthCopyWithImpl<$Res>
    implements $MountHealthCopyWith<$Res> {
  _$MountHealthCopyWithImpl(this._self, this._then);

  final MountHealth _self;
  final $Res Function(MountHealth) _then;

/// Create a copy of MountHealth
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ref = null,Object? name = freezed,Object? healthy = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,healthy: null == healthy ? _self.healthy : healthy // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MountHealth].
extension MountHealthPatterns on MountHealth {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountHealth value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountHealth() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountHealth value)  $default,){
final _that = this;
switch (_that) {
case _MountHealth():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountHealth value)?  $default,){
final _that = this;
switch (_that) {
case _MountHealth() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ref,  String? name,  bool healthy,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountHealth() when $default != null:
return $default(_that.ref,_that.name,_that.healthy,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ref,  String? name,  bool healthy,  String? error)  $default,) {final _that = this;
switch (_that) {
case _MountHealth():
return $default(_that.ref,_that.name,_that.healthy,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ref,  String? name,  bool healthy,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _MountHealth() when $default != null:
return $default(_that.ref,_that.name,_that.healthy,_that.error);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MountHealth implements MountHealth {
  const _MountHealth({required this.ref, this.name, this.healthy = false, this.error});
  factory _MountHealth.fromJson(Map<String, dynamic> json) => _$MountHealthFromJson(json);

@override final  String ref;
@override final  String? name;
@override@JsonKey() final  bool healthy;
@override final  String? error;

/// Create a copy of MountHealth
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountHealthCopyWith<_MountHealth> get copyWith => __$MountHealthCopyWithImpl<_MountHealth>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MountHealthToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountHealth&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.name, name) || other.name == name)&&(identical(other.healthy, healthy) || other.healthy == healthy)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ref,name,healthy,error);

@override
String toString() {
  return 'MountHealth(ref: $ref, name: $name, healthy: $healthy, error: $error)';
}


}

/// @nodoc
abstract mixin class _$MountHealthCopyWith<$Res> implements $MountHealthCopyWith<$Res> {
  factory _$MountHealthCopyWith(_MountHealth value, $Res Function(_MountHealth) _then) = __$MountHealthCopyWithImpl;
@override @useResult
$Res call({
 String ref, String? name, bool healthy, String? error
});




}
/// @nodoc
class __$MountHealthCopyWithImpl<$Res>
    implements _$MountHealthCopyWith<$Res> {
  __$MountHealthCopyWithImpl(this._self, this._then);

  final _MountHealth _self;
  final $Res Function(_MountHealth) _then;

/// Create a copy of MountHealth
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ref = null,Object? name = freezed,Object? healthy = null,Object? error = freezed,}) {
  return _then(_MountHealth(
ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,healthy: null == healthy ? _self.healthy : healthy // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$MountHealthReport {

 List<MountHealth> get mounts; bool get allHealthy;
/// Create a copy of MountHealthReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountHealthReportCopyWith<MountHealthReport> get copyWith => _$MountHealthReportCopyWithImpl<MountHealthReport>(this as MountHealthReport, _$identity);

  /// Serializes this MountHealthReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountHealthReport&&const DeepCollectionEquality().equals(other.mounts, mounts)&&(identical(other.allHealthy, allHealthy) || other.allHealthy == allHealthy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(mounts),allHealthy);

@override
String toString() {
  return 'MountHealthReport(mounts: $mounts, allHealthy: $allHealthy)';
}


}

/// @nodoc
abstract mixin class $MountHealthReportCopyWith<$Res>  {
  factory $MountHealthReportCopyWith(MountHealthReport value, $Res Function(MountHealthReport) _then) = _$MountHealthReportCopyWithImpl;
@useResult
$Res call({
 List<MountHealth> mounts, bool allHealthy
});




}
/// @nodoc
class _$MountHealthReportCopyWithImpl<$Res>
    implements $MountHealthReportCopyWith<$Res> {
  _$MountHealthReportCopyWithImpl(this._self, this._then);

  final MountHealthReport _self;
  final $Res Function(MountHealthReport) _then;

/// Create a copy of MountHealthReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mounts = null,Object? allHealthy = null,}) {
  return _then(_self.copyWith(
mounts: null == mounts ? _self.mounts : mounts // ignore: cast_nullable_to_non_nullable
as List<MountHealth>,allHealthy: null == allHealthy ? _self.allHealthy : allHealthy // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [MountHealthReport].
extension MountHealthReportPatterns on MountHealthReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountHealthReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountHealthReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountHealthReport value)  $default,){
final _that = this;
switch (_that) {
case _MountHealthReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountHealthReport value)?  $default,){
final _that = this;
switch (_that) {
case _MountHealthReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<MountHealth> mounts,  bool allHealthy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountHealthReport() when $default != null:
return $default(_that.mounts,_that.allHealthy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<MountHealth> mounts,  bool allHealthy)  $default,) {final _that = this;
switch (_that) {
case _MountHealthReport():
return $default(_that.mounts,_that.allHealthy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<MountHealth> mounts,  bool allHealthy)?  $default,) {final _that = this;
switch (_that) {
case _MountHealthReport() when $default != null:
return $default(_that.mounts,_that.allHealthy);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MountHealthReport implements MountHealthReport {
  const _MountHealthReport({final  List<MountHealth> mounts = const <MountHealth>[], this.allHealthy = false}): _mounts = mounts;
  factory _MountHealthReport.fromJson(Map<String, dynamic> json) => _$MountHealthReportFromJson(json);

 final  List<MountHealth> _mounts;
@override@JsonKey() List<MountHealth> get mounts {
  if (_mounts is EqualUnmodifiableListView) return _mounts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_mounts);
}

@override@JsonKey() final  bool allHealthy;

/// Create a copy of MountHealthReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountHealthReportCopyWith<_MountHealthReport> get copyWith => __$MountHealthReportCopyWithImpl<_MountHealthReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MountHealthReportToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountHealthReport&&const DeepCollectionEquality().equals(other._mounts, _mounts)&&(identical(other.allHealthy, allHealthy) || other.allHealthy == allHealthy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_mounts),allHealthy);

@override
String toString() {
  return 'MountHealthReport(mounts: $mounts, allHealthy: $allHealthy)';
}


}

/// @nodoc
abstract mixin class _$MountHealthReportCopyWith<$Res> implements $MountHealthReportCopyWith<$Res> {
  factory _$MountHealthReportCopyWith(_MountHealthReport value, $Res Function(_MountHealthReport) _then) = __$MountHealthReportCopyWithImpl;
@override @useResult
$Res call({
 List<MountHealth> mounts, bool allHealthy
});




}
/// @nodoc
class __$MountHealthReportCopyWithImpl<$Res>
    implements _$MountHealthReportCopyWith<$Res> {
  __$MountHealthReportCopyWithImpl(this._self, this._then);

  final _MountHealthReport _self;
  final $Res Function(_MountHealthReport) _then;

/// Create a copy of MountHealthReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mounts = null,Object? allHealthy = null,}) {
  return _then(_MountHealthReport(
mounts: null == mounts ? _self._mounts : mounts // ignore: cast_nullable_to_non_nullable
as List<MountHealth>,allHealthy: null == allHealthy ? _self.allHealthy : allHealthy // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
