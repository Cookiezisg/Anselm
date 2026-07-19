// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'handler.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HandlerEntity {

 String get id; String get name; String get description; List<String> get tags; String get activeVersionId; DateTime get createdAt; DateTime get updatedAt; HandlerVersion? get activeVersion; String? get configState; List<String> get missingConfig; String? get runtimeState;
/// Create a copy of HandlerEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HandlerEntityCopyWith<HandlerEntity> get copyWith => _$HandlerEntityCopyWithImpl<HandlerEntity>(this as HandlerEntity, _$identity);

  /// Serializes this HandlerEntity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HandlerEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.activeVersionId, activeVersionId) || other.activeVersionId == activeVersionId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.activeVersion, activeVersion) || other.activeVersion == activeVersion)&&(identical(other.configState, configState) || other.configState == configState)&&const DeepCollectionEquality().equals(other.missingConfig, missingConfig)&&(identical(other.runtimeState, runtimeState) || other.runtimeState == runtimeState));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,const DeepCollectionEquality().hash(tags),activeVersionId,createdAt,updatedAt,activeVersion,configState,const DeepCollectionEquality().hash(missingConfig),runtimeState);

@override
String toString() {
  return 'HandlerEntity(id: $id, name: $name, description: $description, tags: $tags, activeVersionId: $activeVersionId, createdAt: $createdAt, updatedAt: $updatedAt, activeVersion: $activeVersion, configState: $configState, missingConfig: $missingConfig, runtimeState: $runtimeState)';
}


}

/// @nodoc
abstract mixin class $HandlerEntityCopyWith<$Res>  {
  factory $HandlerEntityCopyWith(HandlerEntity value, $Res Function(HandlerEntity) _then) = _$HandlerEntityCopyWithImpl;
@useResult
$Res call({
 String id, String name, String description, List<String> tags, String activeVersionId, DateTime createdAt, DateTime updatedAt, HandlerVersion? activeVersion, String? configState, List<String> missingConfig, String? runtimeState
});


$HandlerVersionCopyWith<$Res>? get activeVersion;

}
/// @nodoc
class _$HandlerEntityCopyWithImpl<$Res>
    implements $HandlerEntityCopyWith<$Res> {
  _$HandlerEntityCopyWithImpl(this._self, this._then);

  final HandlerEntity _self;
  final $Res Function(HandlerEntity) _then;

/// Create a copy of HandlerEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = null,Object? tags = null,Object? activeVersionId = null,Object? createdAt = null,Object? updatedAt = null,Object? activeVersion = freezed,Object? configState = freezed,Object? missingConfig = null,Object? runtimeState = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,activeVersionId: null == activeVersionId ? _self.activeVersionId : activeVersionId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,activeVersion: freezed == activeVersion ? _self.activeVersion : activeVersion // ignore: cast_nullable_to_non_nullable
as HandlerVersion?,configState: freezed == configState ? _self.configState : configState // ignore: cast_nullable_to_non_nullable
as String?,missingConfig: null == missingConfig ? _self.missingConfig : missingConfig // ignore: cast_nullable_to_non_nullable
as List<String>,runtimeState: freezed == runtimeState ? _self.runtimeState : runtimeState // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of HandlerEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HandlerVersionCopyWith<$Res>? get activeVersion {
    if (_self.activeVersion == null) {
    return null;
  }

  return $HandlerVersionCopyWith<$Res>(_self.activeVersion!, (value) {
    return _then(_self.copyWith(activeVersion: value));
  });
}
}


/// Adds pattern-matching-related methods to [HandlerEntity].
extension HandlerEntityPatterns on HandlerEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HandlerEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HandlerEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HandlerEntity value)  $default,){
final _that = this;
switch (_that) {
case _HandlerEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HandlerEntity value)?  $default,){
final _that = this;
switch (_that) {
case _HandlerEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String description,  List<String> tags,  String activeVersionId,  DateTime createdAt,  DateTime updatedAt,  HandlerVersion? activeVersion,  String? configState,  List<String> missingConfig,  String? runtimeState)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HandlerEntity() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.tags,_that.activeVersionId,_that.createdAt,_that.updatedAt,_that.activeVersion,_that.configState,_that.missingConfig,_that.runtimeState);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String description,  List<String> tags,  String activeVersionId,  DateTime createdAt,  DateTime updatedAt,  HandlerVersion? activeVersion,  String? configState,  List<String> missingConfig,  String? runtimeState)  $default,) {final _that = this;
switch (_that) {
case _HandlerEntity():
return $default(_that.id,_that.name,_that.description,_that.tags,_that.activeVersionId,_that.createdAt,_that.updatedAt,_that.activeVersion,_that.configState,_that.missingConfig,_that.runtimeState);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String description,  List<String> tags,  String activeVersionId,  DateTime createdAt,  DateTime updatedAt,  HandlerVersion? activeVersion,  String? configState,  List<String> missingConfig,  String? runtimeState)?  $default,) {final _that = this;
switch (_that) {
case _HandlerEntity() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.tags,_that.activeVersionId,_that.createdAt,_that.updatedAt,_that.activeVersion,_that.configState,_that.missingConfig,_that.runtimeState);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HandlerEntity implements HandlerEntity {
  const _HandlerEntity({required this.id, this.name = '', this.description = '', final  List<String> tags = const <String>[], this.activeVersionId = '', required this.createdAt, required this.updatedAt, this.activeVersion, this.configState, final  List<String> missingConfig = const <String>[], this.runtimeState}): _tags = tags,_missingConfig = missingConfig;
  factory _HandlerEntity.fromJson(Map<String, dynamic> json) => _$HandlerEntityFromJson(json);

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
@override final  HandlerVersion? activeVersion;
@override final  String? configState;
 final  List<String> _missingConfig;
@override@JsonKey() List<String> get missingConfig {
  if (_missingConfig is EqualUnmodifiableListView) return _missingConfig;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_missingConfig);
}

@override final  String? runtimeState;

/// Create a copy of HandlerEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HandlerEntityCopyWith<_HandlerEntity> get copyWith => __$HandlerEntityCopyWithImpl<_HandlerEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HandlerEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HandlerEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.activeVersionId, activeVersionId) || other.activeVersionId == activeVersionId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.activeVersion, activeVersion) || other.activeVersion == activeVersion)&&(identical(other.configState, configState) || other.configState == configState)&&const DeepCollectionEquality().equals(other._missingConfig, _missingConfig)&&(identical(other.runtimeState, runtimeState) || other.runtimeState == runtimeState));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,const DeepCollectionEquality().hash(_tags),activeVersionId,createdAt,updatedAt,activeVersion,configState,const DeepCollectionEquality().hash(_missingConfig),runtimeState);

@override
String toString() {
  return 'HandlerEntity(id: $id, name: $name, description: $description, tags: $tags, activeVersionId: $activeVersionId, createdAt: $createdAt, updatedAt: $updatedAt, activeVersion: $activeVersion, configState: $configState, missingConfig: $missingConfig, runtimeState: $runtimeState)';
}


}

/// @nodoc
abstract mixin class _$HandlerEntityCopyWith<$Res> implements $HandlerEntityCopyWith<$Res> {
  factory _$HandlerEntityCopyWith(_HandlerEntity value, $Res Function(_HandlerEntity) _then) = __$HandlerEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String description, List<String> tags, String activeVersionId, DateTime createdAt, DateTime updatedAt, HandlerVersion? activeVersion, String? configState, List<String> missingConfig, String? runtimeState
});


@override $HandlerVersionCopyWith<$Res>? get activeVersion;

}
/// @nodoc
class __$HandlerEntityCopyWithImpl<$Res>
    implements _$HandlerEntityCopyWith<$Res> {
  __$HandlerEntityCopyWithImpl(this._self, this._then);

  final _HandlerEntity _self;
  final $Res Function(_HandlerEntity) _then;

/// Create a copy of HandlerEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = null,Object? tags = null,Object? activeVersionId = null,Object? createdAt = null,Object? updatedAt = null,Object? activeVersion = freezed,Object? configState = freezed,Object? missingConfig = null,Object? runtimeState = freezed,}) {
  return _then(_HandlerEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,activeVersionId: null == activeVersionId ? _self.activeVersionId : activeVersionId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,activeVersion: freezed == activeVersion ? _self.activeVersion : activeVersion // ignore: cast_nullable_to_non_nullable
as HandlerVersion?,configState: freezed == configState ? _self.configState : configState // ignore: cast_nullable_to_non_nullable
as String?,missingConfig: null == missingConfig ? _self._missingConfig : missingConfig // ignore: cast_nullable_to_non_nullable
as List<String>,runtimeState: freezed == runtimeState ? _self.runtimeState : runtimeState // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of HandlerEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HandlerVersionCopyWith<$Res>? get activeVersion {
    if (_self.activeVersion == null) {
    return null;
  }

  return $HandlerVersionCopyWith<$Res>(_self.activeVersion!, (value) {
    return _then(_self.copyWith(activeVersion: value));
  });
}
}


/// @nodoc
mixin _$HandlerConfig {

 Map<String, dynamic> get config; String? get configState; List<String> get missingConfig; List<InitArgSpec> get schema;
/// Create a copy of HandlerConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HandlerConfigCopyWith<HandlerConfig> get copyWith => _$HandlerConfigCopyWithImpl<HandlerConfig>(this as HandlerConfig, _$identity);

  /// Serializes this HandlerConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HandlerConfig&&const DeepCollectionEquality().equals(other.config, config)&&(identical(other.configState, configState) || other.configState == configState)&&const DeepCollectionEquality().equals(other.missingConfig, missingConfig)&&const DeepCollectionEquality().equals(other.schema, schema));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(config),configState,const DeepCollectionEquality().hash(missingConfig),const DeepCollectionEquality().hash(schema));

@override
String toString() {
  return 'HandlerConfig(config: $config, configState: $configState, missingConfig: $missingConfig, schema: $schema)';
}


}

/// @nodoc
abstract mixin class $HandlerConfigCopyWith<$Res>  {
  factory $HandlerConfigCopyWith(HandlerConfig value, $Res Function(HandlerConfig) _then) = _$HandlerConfigCopyWithImpl;
@useResult
$Res call({
 Map<String, dynamic> config, String? configState, List<String> missingConfig, List<InitArgSpec> schema
});




}
/// @nodoc
class _$HandlerConfigCopyWithImpl<$Res>
    implements $HandlerConfigCopyWith<$Res> {
  _$HandlerConfigCopyWithImpl(this._self, this._then);

  final HandlerConfig _self;
  final $Res Function(HandlerConfig) _then;

/// Create a copy of HandlerConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? config = null,Object? configState = freezed,Object? missingConfig = null,Object? schema = null,}) {
  return _then(_self.copyWith(
config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,configState: freezed == configState ? _self.configState : configState // ignore: cast_nullable_to_non_nullable
as String?,missingConfig: null == missingConfig ? _self.missingConfig : missingConfig // ignore: cast_nullable_to_non_nullable
as List<String>,schema: null == schema ? _self.schema : schema // ignore: cast_nullable_to_non_nullable
as List<InitArgSpec>,
  ));
}

}


/// Adds pattern-matching-related methods to [HandlerConfig].
extension HandlerConfigPatterns on HandlerConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HandlerConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HandlerConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HandlerConfig value)  $default,){
final _that = this;
switch (_that) {
case _HandlerConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HandlerConfig value)?  $default,){
final _that = this;
switch (_that) {
case _HandlerConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, dynamic> config,  String? configState,  List<String> missingConfig,  List<InitArgSpec> schema)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HandlerConfig() when $default != null:
return $default(_that.config,_that.configState,_that.missingConfig,_that.schema);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, dynamic> config,  String? configState,  List<String> missingConfig,  List<InitArgSpec> schema)  $default,) {final _that = this;
switch (_that) {
case _HandlerConfig():
return $default(_that.config,_that.configState,_that.missingConfig,_that.schema);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, dynamic> config,  String? configState,  List<String> missingConfig,  List<InitArgSpec> schema)?  $default,) {final _that = this;
switch (_that) {
case _HandlerConfig() when $default != null:
return $default(_that.config,_that.configState,_that.missingConfig,_that.schema);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HandlerConfig implements HandlerConfig {
  const _HandlerConfig({final  Map<String, dynamic> config = const <String, dynamic>{}, this.configState, final  List<String> missingConfig = const <String>[], final  List<InitArgSpec> schema = const <InitArgSpec>[]}): _config = config,_missingConfig = missingConfig,_schema = schema;
  factory _HandlerConfig.fromJson(Map<String, dynamic> json) => _$HandlerConfigFromJson(json);

 final  Map<String, dynamic> _config;
@override@JsonKey() Map<String, dynamic> get config {
  if (_config is EqualUnmodifiableMapView) return _config;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_config);
}

@override final  String? configState;
 final  List<String> _missingConfig;
@override@JsonKey() List<String> get missingConfig {
  if (_missingConfig is EqualUnmodifiableListView) return _missingConfig;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_missingConfig);
}

 final  List<InitArgSpec> _schema;
@override@JsonKey() List<InitArgSpec> get schema {
  if (_schema is EqualUnmodifiableListView) return _schema;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_schema);
}


/// Create a copy of HandlerConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HandlerConfigCopyWith<_HandlerConfig> get copyWith => __$HandlerConfigCopyWithImpl<_HandlerConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HandlerConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HandlerConfig&&const DeepCollectionEquality().equals(other._config, _config)&&(identical(other.configState, configState) || other.configState == configState)&&const DeepCollectionEquality().equals(other._missingConfig, _missingConfig)&&const DeepCollectionEquality().equals(other._schema, _schema));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_config),configState,const DeepCollectionEquality().hash(_missingConfig),const DeepCollectionEquality().hash(_schema));

@override
String toString() {
  return 'HandlerConfig(config: $config, configState: $configState, missingConfig: $missingConfig, schema: $schema)';
}


}

/// @nodoc
abstract mixin class _$HandlerConfigCopyWith<$Res> implements $HandlerConfigCopyWith<$Res> {
  factory _$HandlerConfigCopyWith(_HandlerConfig value, $Res Function(_HandlerConfig) _then) = __$HandlerConfigCopyWithImpl;
@override @useResult
$Res call({
 Map<String, dynamic> config, String? configState, List<String> missingConfig, List<InitArgSpec> schema
});




}
/// @nodoc
class __$HandlerConfigCopyWithImpl<$Res>
    implements _$HandlerConfigCopyWith<$Res> {
  __$HandlerConfigCopyWithImpl(this._self, this._then);

  final _HandlerConfig _self;
  final $Res Function(_HandlerConfig) _then;

/// Create a copy of HandlerConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? config = null,Object? configState = freezed,Object? missingConfig = null,Object? schema = null,}) {
  return _then(_HandlerConfig(
config: null == config ? _self._config : config // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,configState: freezed == configState ? _self.configState : configState // ignore: cast_nullable_to_non_nullable
as String?,missingConfig: null == missingConfig ? _self._missingConfig : missingConfig // ignore: cast_nullable_to_non_nullable
as List<String>,schema: null == schema ? _self._schema : schema // ignore: cast_nullable_to_non_nullable
as List<InitArgSpec>,
  ));
}


}


/// @nodoc
mixin _$HandlerVersion {

 String get id; String get handlerId; int get version; String get imports; String get initBody; String get shutdownBody; List<MethodSpec> get methods; List<InitArgSpec> get initArgsSchema; List<String> get dependencies; String get pythonVersion; String get envId; String get envStatus; String? get envError; DateTime? get envSyncedAt; String? get changeReason; String? get builtInConversationId; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of HandlerVersion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HandlerVersionCopyWith<HandlerVersion> get copyWith => _$HandlerVersionCopyWithImpl<HandlerVersion>(this as HandlerVersion, _$identity);

  /// Serializes this HandlerVersion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HandlerVersion&&(identical(other.id, id) || other.id == id)&&(identical(other.handlerId, handlerId) || other.handlerId == handlerId)&&(identical(other.version, version) || other.version == version)&&(identical(other.imports, imports) || other.imports == imports)&&(identical(other.initBody, initBody) || other.initBody == initBody)&&(identical(other.shutdownBody, shutdownBody) || other.shutdownBody == shutdownBody)&&const DeepCollectionEquality().equals(other.methods, methods)&&const DeepCollectionEquality().equals(other.initArgsSchema, initArgsSchema)&&const DeepCollectionEquality().equals(other.dependencies, dependencies)&&(identical(other.pythonVersion, pythonVersion) || other.pythonVersion == pythonVersion)&&(identical(other.envId, envId) || other.envId == envId)&&(identical(other.envStatus, envStatus) || other.envStatus == envStatus)&&(identical(other.envError, envError) || other.envError == envError)&&(identical(other.envSyncedAt, envSyncedAt) || other.envSyncedAt == envSyncedAt)&&(identical(other.changeReason, changeReason) || other.changeReason == changeReason)&&(identical(other.builtInConversationId, builtInConversationId) || other.builtInConversationId == builtInConversationId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,handlerId,version,imports,initBody,shutdownBody,const DeepCollectionEquality().hash(methods),const DeepCollectionEquality().hash(initArgsSchema),const DeepCollectionEquality().hash(dependencies),pythonVersion,envId,envStatus,envError,envSyncedAt,changeReason,builtInConversationId,createdAt,updatedAt);

@override
String toString() {
  return 'HandlerVersion(id: $id, handlerId: $handlerId, version: $version, imports: $imports, initBody: $initBody, shutdownBody: $shutdownBody, methods: $methods, initArgsSchema: $initArgsSchema, dependencies: $dependencies, pythonVersion: $pythonVersion, envId: $envId, envStatus: $envStatus, envError: $envError, envSyncedAt: $envSyncedAt, changeReason: $changeReason, builtInConversationId: $builtInConversationId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $HandlerVersionCopyWith<$Res>  {
  factory $HandlerVersionCopyWith(HandlerVersion value, $Res Function(HandlerVersion) _then) = _$HandlerVersionCopyWithImpl;
@useResult
$Res call({
 String id, String handlerId, int version, String imports, String initBody, String shutdownBody, List<MethodSpec> methods, List<InitArgSpec> initArgsSchema, List<String> dependencies, String pythonVersion, String envId, String envStatus, String? envError, DateTime? envSyncedAt, String? changeReason, String? builtInConversationId, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$HandlerVersionCopyWithImpl<$Res>
    implements $HandlerVersionCopyWith<$Res> {
  _$HandlerVersionCopyWithImpl(this._self, this._then);

  final HandlerVersion _self;
  final $Res Function(HandlerVersion) _then;

/// Create a copy of HandlerVersion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? handlerId = null,Object? version = null,Object? imports = null,Object? initBody = null,Object? shutdownBody = null,Object? methods = null,Object? initArgsSchema = null,Object? dependencies = null,Object? pythonVersion = null,Object? envId = null,Object? envStatus = null,Object? envError = freezed,Object? envSyncedAt = freezed,Object? changeReason = freezed,Object? builtInConversationId = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,handlerId: null == handlerId ? _self.handlerId : handlerId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,imports: null == imports ? _self.imports : imports // ignore: cast_nullable_to_non_nullable
as String,initBody: null == initBody ? _self.initBody : initBody // ignore: cast_nullable_to_non_nullable
as String,shutdownBody: null == shutdownBody ? _self.shutdownBody : shutdownBody // ignore: cast_nullable_to_non_nullable
as String,methods: null == methods ? _self.methods : methods // ignore: cast_nullable_to_non_nullable
as List<MethodSpec>,initArgsSchema: null == initArgsSchema ? _self.initArgsSchema : initArgsSchema // ignore: cast_nullable_to_non_nullable
as List<InitArgSpec>,dependencies: null == dependencies ? _self.dependencies : dependencies // ignore: cast_nullable_to_non_nullable
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


/// Adds pattern-matching-related methods to [HandlerVersion].
extension HandlerVersionPatterns on HandlerVersion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HandlerVersion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HandlerVersion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HandlerVersion value)  $default,){
final _that = this;
switch (_that) {
case _HandlerVersion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HandlerVersion value)?  $default,){
final _that = this;
switch (_that) {
case _HandlerVersion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String handlerId,  int version,  String imports,  String initBody,  String shutdownBody,  List<MethodSpec> methods,  List<InitArgSpec> initArgsSchema,  List<String> dependencies,  String pythonVersion,  String envId,  String envStatus,  String? envError,  DateTime? envSyncedAt,  String? changeReason,  String? builtInConversationId,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HandlerVersion() when $default != null:
return $default(_that.id,_that.handlerId,_that.version,_that.imports,_that.initBody,_that.shutdownBody,_that.methods,_that.initArgsSchema,_that.dependencies,_that.pythonVersion,_that.envId,_that.envStatus,_that.envError,_that.envSyncedAt,_that.changeReason,_that.builtInConversationId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String handlerId,  int version,  String imports,  String initBody,  String shutdownBody,  List<MethodSpec> methods,  List<InitArgSpec> initArgsSchema,  List<String> dependencies,  String pythonVersion,  String envId,  String envStatus,  String? envError,  DateTime? envSyncedAt,  String? changeReason,  String? builtInConversationId,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _HandlerVersion():
return $default(_that.id,_that.handlerId,_that.version,_that.imports,_that.initBody,_that.shutdownBody,_that.methods,_that.initArgsSchema,_that.dependencies,_that.pythonVersion,_that.envId,_that.envStatus,_that.envError,_that.envSyncedAt,_that.changeReason,_that.builtInConversationId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String handlerId,  int version,  String imports,  String initBody,  String shutdownBody,  List<MethodSpec> methods,  List<InitArgSpec> initArgsSchema,  List<String> dependencies,  String pythonVersion,  String envId,  String envStatus,  String? envError,  DateTime? envSyncedAt,  String? changeReason,  String? builtInConversationId,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _HandlerVersion() when $default != null:
return $default(_that.id,_that.handlerId,_that.version,_that.imports,_that.initBody,_that.shutdownBody,_that.methods,_that.initArgsSchema,_that.dependencies,_that.pythonVersion,_that.envId,_that.envStatus,_that.envError,_that.envSyncedAt,_that.changeReason,_that.builtInConversationId,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HandlerVersion implements HandlerVersion {
  const _HandlerVersion({required this.id, required this.handlerId, required this.version, this.imports = '', this.initBody = '', this.shutdownBody = '', final  List<MethodSpec> methods = const <MethodSpec>[], final  List<InitArgSpec> initArgsSchema = const <InitArgSpec>[], final  List<String> dependencies = const <String>[], this.pythonVersion = '3.12', this.envId = '', this.envStatus = '', this.envError, this.envSyncedAt, this.changeReason, this.builtInConversationId, required this.createdAt, required this.updatedAt}): _methods = methods,_initArgsSchema = initArgsSchema,_dependencies = dependencies;
  factory _HandlerVersion.fromJson(Map<String, dynamic> json) => _$HandlerVersionFromJson(json);

@override final  String id;
@override final  String handlerId;
@override final  int version;
@override@JsonKey() final  String imports;
@override@JsonKey() final  String initBody;
@override@JsonKey() final  String shutdownBody;
 final  List<MethodSpec> _methods;
@override@JsonKey() List<MethodSpec> get methods {
  if (_methods is EqualUnmodifiableListView) return _methods;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_methods);
}

 final  List<InitArgSpec> _initArgsSchema;
@override@JsonKey() List<InitArgSpec> get initArgsSchema {
  if (_initArgsSchema is EqualUnmodifiableListView) return _initArgsSchema;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_initArgsSchema);
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

/// Create a copy of HandlerVersion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HandlerVersionCopyWith<_HandlerVersion> get copyWith => __$HandlerVersionCopyWithImpl<_HandlerVersion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HandlerVersionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HandlerVersion&&(identical(other.id, id) || other.id == id)&&(identical(other.handlerId, handlerId) || other.handlerId == handlerId)&&(identical(other.version, version) || other.version == version)&&(identical(other.imports, imports) || other.imports == imports)&&(identical(other.initBody, initBody) || other.initBody == initBody)&&(identical(other.shutdownBody, shutdownBody) || other.shutdownBody == shutdownBody)&&const DeepCollectionEquality().equals(other._methods, _methods)&&const DeepCollectionEquality().equals(other._initArgsSchema, _initArgsSchema)&&const DeepCollectionEquality().equals(other._dependencies, _dependencies)&&(identical(other.pythonVersion, pythonVersion) || other.pythonVersion == pythonVersion)&&(identical(other.envId, envId) || other.envId == envId)&&(identical(other.envStatus, envStatus) || other.envStatus == envStatus)&&(identical(other.envError, envError) || other.envError == envError)&&(identical(other.envSyncedAt, envSyncedAt) || other.envSyncedAt == envSyncedAt)&&(identical(other.changeReason, changeReason) || other.changeReason == changeReason)&&(identical(other.builtInConversationId, builtInConversationId) || other.builtInConversationId == builtInConversationId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,handlerId,version,imports,initBody,shutdownBody,const DeepCollectionEquality().hash(_methods),const DeepCollectionEquality().hash(_initArgsSchema),const DeepCollectionEquality().hash(_dependencies),pythonVersion,envId,envStatus,envError,envSyncedAt,changeReason,builtInConversationId,createdAt,updatedAt);

@override
String toString() {
  return 'HandlerVersion(id: $id, handlerId: $handlerId, version: $version, imports: $imports, initBody: $initBody, shutdownBody: $shutdownBody, methods: $methods, initArgsSchema: $initArgsSchema, dependencies: $dependencies, pythonVersion: $pythonVersion, envId: $envId, envStatus: $envStatus, envError: $envError, envSyncedAt: $envSyncedAt, changeReason: $changeReason, builtInConversationId: $builtInConversationId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$HandlerVersionCopyWith<$Res> implements $HandlerVersionCopyWith<$Res> {
  factory _$HandlerVersionCopyWith(_HandlerVersion value, $Res Function(_HandlerVersion) _then) = __$HandlerVersionCopyWithImpl;
@override @useResult
$Res call({
 String id, String handlerId, int version, String imports, String initBody, String shutdownBody, List<MethodSpec> methods, List<InitArgSpec> initArgsSchema, List<String> dependencies, String pythonVersion, String envId, String envStatus, String? envError, DateTime? envSyncedAt, String? changeReason, String? builtInConversationId, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$HandlerVersionCopyWithImpl<$Res>
    implements _$HandlerVersionCopyWith<$Res> {
  __$HandlerVersionCopyWithImpl(this._self, this._then);

  final _HandlerVersion _self;
  final $Res Function(_HandlerVersion) _then;

/// Create a copy of HandlerVersion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? handlerId = null,Object? version = null,Object? imports = null,Object? initBody = null,Object? shutdownBody = null,Object? methods = null,Object? initArgsSchema = null,Object? dependencies = null,Object? pythonVersion = null,Object? envId = null,Object? envStatus = null,Object? envError = freezed,Object? envSyncedAt = freezed,Object? changeReason = freezed,Object? builtInConversationId = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_HandlerVersion(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,handlerId: null == handlerId ? _self.handlerId : handlerId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,imports: null == imports ? _self.imports : imports // ignore: cast_nullable_to_non_nullable
as String,initBody: null == initBody ? _self.initBody : initBody // ignore: cast_nullable_to_non_nullable
as String,shutdownBody: null == shutdownBody ? _self.shutdownBody : shutdownBody // ignore: cast_nullable_to_non_nullable
as String,methods: null == methods ? _self._methods : methods // ignore: cast_nullable_to_non_nullable
as List<MethodSpec>,initArgsSchema: null == initArgsSchema ? _self._initArgsSchema : initArgsSchema // ignore: cast_nullable_to_non_nullable
as List<InitArgSpec>,dependencies: null == dependencies ? _self._dependencies : dependencies // ignore: cast_nullable_to_non_nullable
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
mixin _$HandlerCall {

 String get id; String get handlerId; String get versionId; String get method; String? get instanceId; String get status; String get triggeredBy; Map<String, Object?> get input; Object? get output; String? get errorMessage; String? get logs; int get elapsedMs; DateTime? get startedAt; DateTime? get endedAt; String? get conversationId; String? get messageId; String? get toolCallId; String? get flowrunId; String? get flowrunNodeId; int? get flowrunIteration; DateTime get createdAt;
/// Create a copy of HandlerCall
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HandlerCallCopyWith<HandlerCall> get copyWith => _$HandlerCallCopyWithImpl<HandlerCall>(this as HandlerCall, _$identity);

  /// Serializes this HandlerCall to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HandlerCall&&(identical(other.id, id) || other.id == id)&&(identical(other.handlerId, handlerId) || other.handlerId == handlerId)&&(identical(other.versionId, versionId) || other.versionId == versionId)&&(identical(other.method, method) || other.method == method)&&(identical(other.instanceId, instanceId) || other.instanceId == instanceId)&&(identical(other.status, status) || other.status == status)&&(identical(other.triggeredBy, triggeredBy) || other.triggeredBy == triggeredBy)&&const DeepCollectionEquality().equals(other.input, input)&&const DeepCollectionEquality().equals(other.output, output)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.logs, logs) || other.logs == logs)&&(identical(other.elapsedMs, elapsedMs) || other.elapsedMs == elapsedMs)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.flowrunId, flowrunId) || other.flowrunId == flowrunId)&&(identical(other.flowrunNodeId, flowrunNodeId) || other.flowrunNodeId == flowrunNodeId)&&(identical(other.flowrunIteration, flowrunIteration) || other.flowrunIteration == flowrunIteration)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,handlerId,versionId,method,instanceId,status,triggeredBy,const DeepCollectionEquality().hash(input),const DeepCollectionEquality().hash(output),errorMessage,logs,elapsedMs,startedAt,endedAt,conversationId,messageId,toolCallId,flowrunId,flowrunNodeId,flowrunIteration,createdAt]);

@override
String toString() {
  return 'HandlerCall(id: $id, handlerId: $handlerId, versionId: $versionId, method: $method, instanceId: $instanceId, status: $status, triggeredBy: $triggeredBy, input: $input, output: $output, errorMessage: $errorMessage, logs: $logs, elapsedMs: $elapsedMs, startedAt: $startedAt, endedAt: $endedAt, conversationId: $conversationId, messageId: $messageId, toolCallId: $toolCallId, flowrunId: $flowrunId, flowrunNodeId: $flowrunNodeId, flowrunIteration: $flowrunIteration, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $HandlerCallCopyWith<$Res>  {
  factory $HandlerCallCopyWith(HandlerCall value, $Res Function(HandlerCall) _then) = _$HandlerCallCopyWithImpl;
@useResult
$Res call({
 String id, String handlerId, String versionId, String method, String? instanceId, String status, String triggeredBy, Map<String, Object?> input, Object? output, String? errorMessage, String? logs, int elapsedMs, DateTime? startedAt, DateTime? endedAt, String? conversationId, String? messageId, String? toolCallId, String? flowrunId, String? flowrunNodeId, int? flowrunIteration, DateTime createdAt
});




}
/// @nodoc
class _$HandlerCallCopyWithImpl<$Res>
    implements $HandlerCallCopyWith<$Res> {
  _$HandlerCallCopyWithImpl(this._self, this._then);

  final HandlerCall _self;
  final $Res Function(HandlerCall) _then;

/// Create a copy of HandlerCall
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? handlerId = null,Object? versionId = null,Object? method = null,Object? instanceId = freezed,Object? status = null,Object? triggeredBy = null,Object? input = null,Object? output = freezed,Object? errorMessage = freezed,Object? logs = freezed,Object? elapsedMs = null,Object? startedAt = freezed,Object? endedAt = freezed,Object? conversationId = freezed,Object? messageId = freezed,Object? toolCallId = freezed,Object? flowrunId = freezed,Object? flowrunNodeId = freezed,Object? flowrunIteration = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,handlerId: null == handlerId ? _self.handlerId : handlerId // ignore: cast_nullable_to_non_nullable
as String,versionId: null == versionId ? _self.versionId : versionId // ignore: cast_nullable_to_non_nullable
as String,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,instanceId: freezed == instanceId ? _self.instanceId : instanceId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
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


/// Adds pattern-matching-related methods to [HandlerCall].
extension HandlerCallPatterns on HandlerCall {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HandlerCall value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HandlerCall() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HandlerCall value)  $default,){
final _that = this;
switch (_that) {
case _HandlerCall():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HandlerCall value)?  $default,){
final _that = this;
switch (_that) {
case _HandlerCall() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String handlerId,  String versionId,  String method,  String? instanceId,  String status,  String triggeredBy,  Map<String, Object?> input,  Object? output,  String? errorMessage,  String? logs,  int elapsedMs,  DateTime? startedAt,  DateTime? endedAt,  String? conversationId,  String? messageId,  String? toolCallId,  String? flowrunId,  String? flowrunNodeId,  int? flowrunIteration,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HandlerCall() when $default != null:
return $default(_that.id,_that.handlerId,_that.versionId,_that.method,_that.instanceId,_that.status,_that.triggeredBy,_that.input,_that.output,_that.errorMessage,_that.logs,_that.elapsedMs,_that.startedAt,_that.endedAt,_that.conversationId,_that.messageId,_that.toolCallId,_that.flowrunId,_that.flowrunNodeId,_that.flowrunIteration,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String handlerId,  String versionId,  String method,  String? instanceId,  String status,  String triggeredBy,  Map<String, Object?> input,  Object? output,  String? errorMessage,  String? logs,  int elapsedMs,  DateTime? startedAt,  DateTime? endedAt,  String? conversationId,  String? messageId,  String? toolCallId,  String? flowrunId,  String? flowrunNodeId,  int? flowrunIteration,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _HandlerCall():
return $default(_that.id,_that.handlerId,_that.versionId,_that.method,_that.instanceId,_that.status,_that.triggeredBy,_that.input,_that.output,_that.errorMessage,_that.logs,_that.elapsedMs,_that.startedAt,_that.endedAt,_that.conversationId,_that.messageId,_that.toolCallId,_that.flowrunId,_that.flowrunNodeId,_that.flowrunIteration,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String handlerId,  String versionId,  String method,  String? instanceId,  String status,  String triggeredBy,  Map<String, Object?> input,  Object? output,  String? errorMessage,  String? logs,  int elapsedMs,  DateTime? startedAt,  DateTime? endedAt,  String? conversationId,  String? messageId,  String? toolCallId,  String? flowrunId,  String? flowrunNodeId,  int? flowrunIteration,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _HandlerCall() when $default != null:
return $default(_that.id,_that.handlerId,_that.versionId,_that.method,_that.instanceId,_that.status,_that.triggeredBy,_that.input,_that.output,_that.errorMessage,_that.logs,_that.elapsedMs,_that.startedAt,_that.endedAt,_that.conversationId,_that.messageId,_that.toolCallId,_that.flowrunId,_that.flowrunNodeId,_that.flowrunIteration,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HandlerCall implements HandlerCall {
  const _HandlerCall({required this.id, required this.handlerId, this.versionId = '', this.method = '', this.instanceId, this.status = '', this.triggeredBy = '', final  Map<String, Object?> input = const <String, Object?>{}, this.output, this.errorMessage, this.logs, this.elapsedMs = 0, this.startedAt, this.endedAt, this.conversationId, this.messageId, this.toolCallId, this.flowrunId, this.flowrunNodeId, this.flowrunIteration, required this.createdAt}): _input = input;
  factory _HandlerCall.fromJson(Map<String, dynamic> json) => _$HandlerCallFromJson(json);

@override final  String id;
@override final  String handlerId;
@override@JsonKey() final  String versionId;
@override@JsonKey() final  String method;
@override final  String? instanceId;
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

/// Create a copy of HandlerCall
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HandlerCallCopyWith<_HandlerCall> get copyWith => __$HandlerCallCopyWithImpl<_HandlerCall>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HandlerCallToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HandlerCall&&(identical(other.id, id) || other.id == id)&&(identical(other.handlerId, handlerId) || other.handlerId == handlerId)&&(identical(other.versionId, versionId) || other.versionId == versionId)&&(identical(other.method, method) || other.method == method)&&(identical(other.instanceId, instanceId) || other.instanceId == instanceId)&&(identical(other.status, status) || other.status == status)&&(identical(other.triggeredBy, triggeredBy) || other.triggeredBy == triggeredBy)&&const DeepCollectionEquality().equals(other._input, _input)&&const DeepCollectionEquality().equals(other.output, output)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.logs, logs) || other.logs == logs)&&(identical(other.elapsedMs, elapsedMs) || other.elapsedMs == elapsedMs)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.flowrunId, flowrunId) || other.flowrunId == flowrunId)&&(identical(other.flowrunNodeId, flowrunNodeId) || other.flowrunNodeId == flowrunNodeId)&&(identical(other.flowrunIteration, flowrunIteration) || other.flowrunIteration == flowrunIteration)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,handlerId,versionId,method,instanceId,status,triggeredBy,const DeepCollectionEquality().hash(_input),const DeepCollectionEquality().hash(output),errorMessage,logs,elapsedMs,startedAt,endedAt,conversationId,messageId,toolCallId,flowrunId,flowrunNodeId,flowrunIteration,createdAt]);

@override
String toString() {
  return 'HandlerCall(id: $id, handlerId: $handlerId, versionId: $versionId, method: $method, instanceId: $instanceId, status: $status, triggeredBy: $triggeredBy, input: $input, output: $output, errorMessage: $errorMessage, logs: $logs, elapsedMs: $elapsedMs, startedAt: $startedAt, endedAt: $endedAt, conversationId: $conversationId, messageId: $messageId, toolCallId: $toolCallId, flowrunId: $flowrunId, flowrunNodeId: $flowrunNodeId, flowrunIteration: $flowrunIteration, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$HandlerCallCopyWith<$Res> implements $HandlerCallCopyWith<$Res> {
  factory _$HandlerCallCopyWith(_HandlerCall value, $Res Function(_HandlerCall) _then) = __$HandlerCallCopyWithImpl;
@override @useResult
$Res call({
 String id, String handlerId, String versionId, String method, String? instanceId, String status, String triggeredBy, Map<String, Object?> input, Object? output, String? errorMessage, String? logs, int elapsedMs, DateTime? startedAt, DateTime? endedAt, String? conversationId, String? messageId, String? toolCallId, String? flowrunId, String? flowrunNodeId, int? flowrunIteration, DateTime createdAt
});




}
/// @nodoc
class __$HandlerCallCopyWithImpl<$Res>
    implements _$HandlerCallCopyWith<$Res> {
  __$HandlerCallCopyWithImpl(this._self, this._then);

  final _HandlerCall _self;
  final $Res Function(_HandlerCall) _then;

/// Create a copy of HandlerCall
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? handlerId = null,Object? versionId = null,Object? method = null,Object? instanceId = freezed,Object? status = null,Object? triggeredBy = null,Object? input = null,Object? output = freezed,Object? errorMessage = freezed,Object? logs = freezed,Object? elapsedMs = null,Object? startedAt = freezed,Object? endedAt = freezed,Object? conversationId = freezed,Object? messageId = freezed,Object? toolCallId = freezed,Object? flowrunId = freezed,Object? flowrunNodeId = freezed,Object? flowrunIteration = freezed,Object? createdAt = null,}) {
  return _then(_HandlerCall(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,handlerId: null == handlerId ? _self.handlerId : handlerId // ignore: cast_nullable_to_non_nullable
as String,versionId: null == versionId ? _self.versionId : versionId // ignore: cast_nullable_to_non_nullable
as String,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,instanceId: freezed == instanceId ? _self.instanceId : instanceId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
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

// dart format on
