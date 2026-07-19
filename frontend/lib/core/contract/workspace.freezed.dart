// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workspace.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ModelRef {

 String get apiKeyId; String get modelId; Map<String, String> get options;
/// Create a copy of ModelRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModelRefCopyWith<ModelRef> get copyWith => _$ModelRefCopyWithImpl<ModelRef>(this as ModelRef, _$identity);

  /// Serializes this ModelRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModelRef&&(identical(other.apiKeyId, apiKeyId) || other.apiKeyId == apiKeyId)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&const DeepCollectionEquality().equals(other.options, options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,apiKeyId,modelId,const DeepCollectionEquality().hash(options));

@override
String toString() {
  return 'ModelRef(apiKeyId: $apiKeyId, modelId: $modelId, options: $options)';
}


}

/// @nodoc
abstract mixin class $ModelRefCopyWith<$Res>  {
  factory $ModelRefCopyWith(ModelRef value, $Res Function(ModelRef) _then) = _$ModelRefCopyWithImpl;
@useResult
$Res call({
 String apiKeyId, String modelId, Map<String, String> options
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
@pragma('vm:prefer-inline') @override $Res call({Object? apiKeyId = null,Object? modelId = null,Object? options = null,}) {
  return _then(_self.copyWith(
apiKeyId: null == apiKeyId ? _self.apiKeyId : apiKeyId // ignore: cast_nullable_to_non_nullable
as String,modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String apiKeyId,  String modelId,  Map<String, String> options)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ModelRef() when $default != null:
return $default(_that.apiKeyId,_that.modelId,_that.options);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String apiKeyId,  String modelId,  Map<String, String> options)  $default,) {final _that = this;
switch (_that) {
case _ModelRef():
return $default(_that.apiKeyId,_that.modelId,_that.options);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String apiKeyId,  String modelId,  Map<String, String> options)?  $default,) {final _that = this;
switch (_that) {
case _ModelRef() when $default != null:
return $default(_that.apiKeyId,_that.modelId,_that.options);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ModelRef implements ModelRef {
  const _ModelRef({required this.apiKeyId, required this.modelId, final  Map<String, String> options = const <String, String>{}}): _options = options;
  factory _ModelRef.fromJson(Map<String, dynamic> json) => _$ModelRefFromJson(json);

@override final  String apiKeyId;
@override final  String modelId;
 final  Map<String, String> _options;
@override@JsonKey() Map<String, String> get options {
  if (_options is EqualUnmodifiableMapView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_options);
}


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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModelRef&&(identical(other.apiKeyId, apiKeyId) || other.apiKeyId == apiKeyId)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&const DeepCollectionEquality().equals(other._options, _options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,apiKeyId,modelId,const DeepCollectionEquality().hash(_options));

@override
String toString() {
  return 'ModelRef(apiKeyId: $apiKeyId, modelId: $modelId, options: $options)';
}


}

/// @nodoc
abstract mixin class _$ModelRefCopyWith<$Res> implements $ModelRefCopyWith<$Res> {
  factory _$ModelRefCopyWith(_ModelRef value, $Res Function(_ModelRef) _then) = __$ModelRefCopyWithImpl;
@override @useResult
$Res call({
 String apiKeyId, String modelId, Map<String, String> options
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
@override @pragma('vm:prefer-inline') $Res call({Object? apiKeyId = null,Object? modelId = null,Object? options = null,}) {
  return _then(_ModelRef(
apiKeyId: null == apiKeyId ? _self.apiKeyId : apiKeyId // ignore: cast_nullable_to_non_nullable
as String,modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}


/// @nodoc
mixin _$Workspace {

 String get id; String get name; String? get avatarColor; String get language; ModelRef? get defaultDialogue; ModelRef? get defaultUtility; ModelRef? get defaultAgent; String? get defaultSearchKeyId; String? get webFetchMode;// local | jina
 DateTime? get lastUsedAt; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceCopyWith<Workspace> get copyWith => _$WorkspaceCopyWithImpl<Workspace>(this as Workspace, _$identity);

  /// Serializes this Workspace to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Workspace&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.avatarColor, avatarColor) || other.avatarColor == avatarColor)&&(identical(other.language, language) || other.language == language)&&(identical(other.defaultDialogue, defaultDialogue) || other.defaultDialogue == defaultDialogue)&&(identical(other.defaultUtility, defaultUtility) || other.defaultUtility == defaultUtility)&&(identical(other.defaultAgent, defaultAgent) || other.defaultAgent == defaultAgent)&&(identical(other.defaultSearchKeyId, defaultSearchKeyId) || other.defaultSearchKeyId == defaultSearchKeyId)&&(identical(other.webFetchMode, webFetchMode) || other.webFetchMode == webFetchMode)&&(identical(other.lastUsedAt, lastUsedAt) || other.lastUsedAt == lastUsedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,avatarColor,language,defaultDialogue,defaultUtility,defaultAgent,defaultSearchKeyId,webFetchMode,lastUsedAt,createdAt,updatedAt);

@override
String toString() {
  return 'Workspace(id: $id, name: $name, avatarColor: $avatarColor, language: $language, defaultDialogue: $defaultDialogue, defaultUtility: $defaultUtility, defaultAgent: $defaultAgent, defaultSearchKeyId: $defaultSearchKeyId, webFetchMode: $webFetchMode, lastUsedAt: $lastUsedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $WorkspaceCopyWith<$Res>  {
  factory $WorkspaceCopyWith(Workspace value, $Res Function(Workspace) _then) = _$WorkspaceCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? avatarColor, String language, ModelRef? defaultDialogue, ModelRef? defaultUtility, ModelRef? defaultAgent, String? defaultSearchKeyId, String? webFetchMode, DateTime? lastUsedAt, DateTime createdAt, DateTime updatedAt
});


$ModelRefCopyWith<$Res>? get defaultDialogue;$ModelRefCopyWith<$Res>? get defaultUtility;$ModelRefCopyWith<$Res>? get defaultAgent;

}
/// @nodoc
class _$WorkspaceCopyWithImpl<$Res>
    implements $WorkspaceCopyWith<$Res> {
  _$WorkspaceCopyWithImpl(this._self, this._then);

  final Workspace _self;
  final $Res Function(Workspace) _then;

/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? avatarColor = freezed,Object? language = null,Object? defaultDialogue = freezed,Object? defaultUtility = freezed,Object? defaultAgent = freezed,Object? defaultSearchKeyId = freezed,Object? webFetchMode = freezed,Object? lastUsedAt = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,avatarColor: freezed == avatarColor ? _self.avatarColor : avatarColor // ignore: cast_nullable_to_non_nullable
as String?,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,defaultDialogue: freezed == defaultDialogue ? _self.defaultDialogue : defaultDialogue // ignore: cast_nullable_to_non_nullable
as ModelRef?,defaultUtility: freezed == defaultUtility ? _self.defaultUtility : defaultUtility // ignore: cast_nullable_to_non_nullable
as ModelRef?,defaultAgent: freezed == defaultAgent ? _self.defaultAgent : defaultAgent // ignore: cast_nullable_to_non_nullable
as ModelRef?,defaultSearchKeyId: freezed == defaultSearchKeyId ? _self.defaultSearchKeyId : defaultSearchKeyId // ignore: cast_nullable_to_non_nullable
as String?,webFetchMode: freezed == webFetchMode ? _self.webFetchMode : webFetchMode // ignore: cast_nullable_to_non_nullable
as String?,lastUsedAt: freezed == lastUsedAt ? _self.lastUsedAt : lastUsedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelRefCopyWith<$Res>? get defaultDialogue {
    if (_self.defaultDialogue == null) {
    return null;
  }

  return $ModelRefCopyWith<$Res>(_self.defaultDialogue!, (value) {
    return _then(_self.copyWith(defaultDialogue: value));
  });
}/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelRefCopyWith<$Res>? get defaultUtility {
    if (_self.defaultUtility == null) {
    return null;
  }

  return $ModelRefCopyWith<$Res>(_self.defaultUtility!, (value) {
    return _then(_self.copyWith(defaultUtility: value));
  });
}/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelRefCopyWith<$Res>? get defaultAgent {
    if (_self.defaultAgent == null) {
    return null;
  }

  return $ModelRefCopyWith<$Res>(_self.defaultAgent!, (value) {
    return _then(_self.copyWith(defaultAgent: value));
  });
}
}


/// Adds pattern-matching-related methods to [Workspace].
extension WorkspacePatterns on Workspace {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Workspace value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Workspace() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Workspace value)  $default,){
final _that = this;
switch (_that) {
case _Workspace():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Workspace value)?  $default,){
final _that = this;
switch (_that) {
case _Workspace() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? avatarColor,  String language,  ModelRef? defaultDialogue,  ModelRef? defaultUtility,  ModelRef? defaultAgent,  String? defaultSearchKeyId,  String? webFetchMode,  DateTime? lastUsedAt,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Workspace() when $default != null:
return $default(_that.id,_that.name,_that.avatarColor,_that.language,_that.defaultDialogue,_that.defaultUtility,_that.defaultAgent,_that.defaultSearchKeyId,_that.webFetchMode,_that.lastUsedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? avatarColor,  String language,  ModelRef? defaultDialogue,  ModelRef? defaultUtility,  ModelRef? defaultAgent,  String? defaultSearchKeyId,  String? webFetchMode,  DateTime? lastUsedAt,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Workspace():
return $default(_that.id,_that.name,_that.avatarColor,_that.language,_that.defaultDialogue,_that.defaultUtility,_that.defaultAgent,_that.defaultSearchKeyId,_that.webFetchMode,_that.lastUsedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? avatarColor,  String language,  ModelRef? defaultDialogue,  ModelRef? defaultUtility,  ModelRef? defaultAgent,  String? defaultSearchKeyId,  String? webFetchMode,  DateTime? lastUsedAt,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Workspace() when $default != null:
return $default(_that.id,_that.name,_that.avatarColor,_that.language,_that.defaultDialogue,_that.defaultUtility,_that.defaultAgent,_that.defaultSearchKeyId,_that.webFetchMode,_that.lastUsedAt,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Workspace implements Workspace {
  const _Workspace({required this.id, required this.name, this.avatarColor, required this.language, this.defaultDialogue, this.defaultUtility, this.defaultAgent, this.defaultSearchKeyId, this.webFetchMode, this.lastUsedAt, required this.createdAt, required this.updatedAt});
  factory _Workspace.fromJson(Map<String, dynamic> json) => _$WorkspaceFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? avatarColor;
@override final  String language;
@override final  ModelRef? defaultDialogue;
@override final  ModelRef? defaultUtility;
@override final  ModelRef? defaultAgent;
@override final  String? defaultSearchKeyId;
@override final  String? webFetchMode;
// local | jina
@override final  DateTime? lastUsedAt;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceCopyWith<_Workspace> get copyWith => __$WorkspaceCopyWithImpl<_Workspace>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkspaceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Workspace&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.avatarColor, avatarColor) || other.avatarColor == avatarColor)&&(identical(other.language, language) || other.language == language)&&(identical(other.defaultDialogue, defaultDialogue) || other.defaultDialogue == defaultDialogue)&&(identical(other.defaultUtility, defaultUtility) || other.defaultUtility == defaultUtility)&&(identical(other.defaultAgent, defaultAgent) || other.defaultAgent == defaultAgent)&&(identical(other.defaultSearchKeyId, defaultSearchKeyId) || other.defaultSearchKeyId == defaultSearchKeyId)&&(identical(other.webFetchMode, webFetchMode) || other.webFetchMode == webFetchMode)&&(identical(other.lastUsedAt, lastUsedAt) || other.lastUsedAt == lastUsedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,avatarColor,language,defaultDialogue,defaultUtility,defaultAgent,defaultSearchKeyId,webFetchMode,lastUsedAt,createdAt,updatedAt);

@override
String toString() {
  return 'Workspace(id: $id, name: $name, avatarColor: $avatarColor, language: $language, defaultDialogue: $defaultDialogue, defaultUtility: $defaultUtility, defaultAgent: $defaultAgent, defaultSearchKeyId: $defaultSearchKeyId, webFetchMode: $webFetchMode, lastUsedAt: $lastUsedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceCopyWith<$Res> implements $WorkspaceCopyWith<$Res> {
  factory _$WorkspaceCopyWith(_Workspace value, $Res Function(_Workspace) _then) = __$WorkspaceCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? avatarColor, String language, ModelRef? defaultDialogue, ModelRef? defaultUtility, ModelRef? defaultAgent, String? defaultSearchKeyId, String? webFetchMode, DateTime? lastUsedAt, DateTime createdAt, DateTime updatedAt
});


@override $ModelRefCopyWith<$Res>? get defaultDialogue;@override $ModelRefCopyWith<$Res>? get defaultUtility;@override $ModelRefCopyWith<$Res>? get defaultAgent;

}
/// @nodoc
class __$WorkspaceCopyWithImpl<$Res>
    implements _$WorkspaceCopyWith<$Res> {
  __$WorkspaceCopyWithImpl(this._self, this._then);

  final _Workspace _self;
  final $Res Function(_Workspace) _then;

/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? avatarColor = freezed,Object? language = null,Object? defaultDialogue = freezed,Object? defaultUtility = freezed,Object? defaultAgent = freezed,Object? defaultSearchKeyId = freezed,Object? webFetchMode = freezed,Object? lastUsedAt = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Workspace(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,avatarColor: freezed == avatarColor ? _self.avatarColor : avatarColor // ignore: cast_nullable_to_non_nullable
as String?,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,defaultDialogue: freezed == defaultDialogue ? _self.defaultDialogue : defaultDialogue // ignore: cast_nullable_to_non_nullable
as ModelRef?,defaultUtility: freezed == defaultUtility ? _self.defaultUtility : defaultUtility // ignore: cast_nullable_to_non_nullable
as ModelRef?,defaultAgent: freezed == defaultAgent ? _self.defaultAgent : defaultAgent // ignore: cast_nullable_to_non_nullable
as ModelRef?,defaultSearchKeyId: freezed == defaultSearchKeyId ? _self.defaultSearchKeyId : defaultSearchKeyId // ignore: cast_nullable_to_non_nullable
as String?,webFetchMode: freezed == webFetchMode ? _self.webFetchMode : webFetchMode // ignore: cast_nullable_to_non_nullable
as String?,lastUsedAt: freezed == lastUsedAt ? _self.lastUsedAt : lastUsedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelRefCopyWith<$Res>? get defaultDialogue {
    if (_self.defaultDialogue == null) {
    return null;
  }

  return $ModelRefCopyWith<$Res>(_self.defaultDialogue!, (value) {
    return _then(_self.copyWith(defaultDialogue: value));
  });
}/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelRefCopyWith<$Res>? get defaultUtility {
    if (_self.defaultUtility == null) {
    return null;
  }

  return $ModelRefCopyWith<$Res>(_self.defaultUtility!, (value) {
    return _then(_self.copyWith(defaultUtility: value));
  });
}/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelRefCopyWith<$Res>? get defaultAgent {
    if (_self.defaultAgent == null) {
    return null;
  }

  return $ModelRefCopyWith<$Res>(_self.defaultAgent!, (value) {
    return _then(_self.copyWith(defaultAgent: value));
  });
}
}


/// @nodoc
mixin _$WorkspaceStats {

 int get conversations; int get functions; int get handlers; int get agents; int get workflows; int get documents; int get runningFlowruns; int get generatingConversations; int get blobBytes;
/// Create a copy of WorkspaceStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceStatsCopyWith<WorkspaceStats> get copyWith => _$WorkspaceStatsCopyWithImpl<WorkspaceStats>(this as WorkspaceStats, _$identity);

  /// Serializes this WorkspaceStats to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceStats&&(identical(other.conversations, conversations) || other.conversations == conversations)&&(identical(other.functions, functions) || other.functions == functions)&&(identical(other.handlers, handlers) || other.handlers == handlers)&&(identical(other.agents, agents) || other.agents == agents)&&(identical(other.workflows, workflows) || other.workflows == workflows)&&(identical(other.documents, documents) || other.documents == documents)&&(identical(other.runningFlowruns, runningFlowruns) || other.runningFlowruns == runningFlowruns)&&(identical(other.generatingConversations, generatingConversations) || other.generatingConversations == generatingConversations)&&(identical(other.blobBytes, blobBytes) || other.blobBytes == blobBytes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,conversations,functions,handlers,agents,workflows,documents,runningFlowruns,generatingConversations,blobBytes);

@override
String toString() {
  return 'WorkspaceStats(conversations: $conversations, functions: $functions, handlers: $handlers, agents: $agents, workflows: $workflows, documents: $documents, runningFlowruns: $runningFlowruns, generatingConversations: $generatingConversations, blobBytes: $blobBytes)';
}


}

/// @nodoc
abstract mixin class $WorkspaceStatsCopyWith<$Res>  {
  factory $WorkspaceStatsCopyWith(WorkspaceStats value, $Res Function(WorkspaceStats) _then) = _$WorkspaceStatsCopyWithImpl;
@useResult
$Res call({
 int conversations, int functions, int handlers, int agents, int workflows, int documents, int runningFlowruns, int generatingConversations, int blobBytes
});




}
/// @nodoc
class _$WorkspaceStatsCopyWithImpl<$Res>
    implements $WorkspaceStatsCopyWith<$Res> {
  _$WorkspaceStatsCopyWithImpl(this._self, this._then);

  final WorkspaceStats _self;
  final $Res Function(WorkspaceStats) _then;

/// Create a copy of WorkspaceStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? conversations = null,Object? functions = null,Object? handlers = null,Object? agents = null,Object? workflows = null,Object? documents = null,Object? runningFlowruns = null,Object? generatingConversations = null,Object? blobBytes = null,}) {
  return _then(_self.copyWith(
conversations: null == conversations ? _self.conversations : conversations // ignore: cast_nullable_to_non_nullable
as int,functions: null == functions ? _self.functions : functions // ignore: cast_nullable_to_non_nullable
as int,handlers: null == handlers ? _self.handlers : handlers // ignore: cast_nullable_to_non_nullable
as int,agents: null == agents ? _self.agents : agents // ignore: cast_nullable_to_non_nullable
as int,workflows: null == workflows ? _self.workflows : workflows // ignore: cast_nullable_to_non_nullable
as int,documents: null == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as int,runningFlowruns: null == runningFlowruns ? _self.runningFlowruns : runningFlowruns // ignore: cast_nullable_to_non_nullable
as int,generatingConversations: null == generatingConversations ? _self.generatingConversations : generatingConversations // ignore: cast_nullable_to_non_nullable
as int,blobBytes: null == blobBytes ? _self.blobBytes : blobBytes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkspaceStats].
extension WorkspaceStatsPatterns on WorkspaceStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceStats value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceStats value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int conversations,  int functions,  int handlers,  int agents,  int workflows,  int documents,  int runningFlowruns,  int generatingConversations,  int blobBytes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceStats() when $default != null:
return $default(_that.conversations,_that.functions,_that.handlers,_that.agents,_that.workflows,_that.documents,_that.runningFlowruns,_that.generatingConversations,_that.blobBytes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int conversations,  int functions,  int handlers,  int agents,  int workflows,  int documents,  int runningFlowruns,  int generatingConversations,  int blobBytes)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceStats():
return $default(_that.conversations,_that.functions,_that.handlers,_that.agents,_that.workflows,_that.documents,_that.runningFlowruns,_that.generatingConversations,_that.blobBytes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int conversations,  int functions,  int handlers,  int agents,  int workflows,  int documents,  int runningFlowruns,  int generatingConversations,  int blobBytes)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceStats() when $default != null:
return $default(_that.conversations,_that.functions,_that.handlers,_that.agents,_that.workflows,_that.documents,_that.runningFlowruns,_that.generatingConversations,_that.blobBytes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkspaceStats implements WorkspaceStats {
  const _WorkspaceStats({this.conversations = 0, this.functions = 0, this.handlers = 0, this.agents = 0, this.workflows = 0, this.documents = 0, this.runningFlowruns = 0, this.generatingConversations = 0, this.blobBytes = 0});
  factory _WorkspaceStats.fromJson(Map<String, dynamic> json) => _$WorkspaceStatsFromJson(json);

@override@JsonKey() final  int conversations;
@override@JsonKey() final  int functions;
@override@JsonKey() final  int handlers;
@override@JsonKey() final  int agents;
@override@JsonKey() final  int workflows;
@override@JsonKey() final  int documents;
@override@JsonKey() final  int runningFlowruns;
@override@JsonKey() final  int generatingConversations;
@override@JsonKey() final  int blobBytes;

/// Create a copy of WorkspaceStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceStatsCopyWith<_WorkspaceStats> get copyWith => __$WorkspaceStatsCopyWithImpl<_WorkspaceStats>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkspaceStatsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceStats&&(identical(other.conversations, conversations) || other.conversations == conversations)&&(identical(other.functions, functions) || other.functions == functions)&&(identical(other.handlers, handlers) || other.handlers == handlers)&&(identical(other.agents, agents) || other.agents == agents)&&(identical(other.workflows, workflows) || other.workflows == workflows)&&(identical(other.documents, documents) || other.documents == documents)&&(identical(other.runningFlowruns, runningFlowruns) || other.runningFlowruns == runningFlowruns)&&(identical(other.generatingConversations, generatingConversations) || other.generatingConversations == generatingConversations)&&(identical(other.blobBytes, blobBytes) || other.blobBytes == blobBytes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,conversations,functions,handlers,agents,workflows,documents,runningFlowruns,generatingConversations,blobBytes);

@override
String toString() {
  return 'WorkspaceStats(conversations: $conversations, functions: $functions, handlers: $handlers, agents: $agents, workflows: $workflows, documents: $documents, runningFlowruns: $runningFlowruns, generatingConversations: $generatingConversations, blobBytes: $blobBytes)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceStatsCopyWith<$Res> implements $WorkspaceStatsCopyWith<$Res> {
  factory _$WorkspaceStatsCopyWith(_WorkspaceStats value, $Res Function(_WorkspaceStats) _then) = __$WorkspaceStatsCopyWithImpl;
@override @useResult
$Res call({
 int conversations, int functions, int handlers, int agents, int workflows, int documents, int runningFlowruns, int generatingConversations, int blobBytes
});




}
/// @nodoc
class __$WorkspaceStatsCopyWithImpl<$Res>
    implements _$WorkspaceStatsCopyWith<$Res> {
  __$WorkspaceStatsCopyWithImpl(this._self, this._then);

  final _WorkspaceStats _self;
  final $Res Function(_WorkspaceStats) _then;

/// Create a copy of WorkspaceStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? conversations = null,Object? functions = null,Object? handlers = null,Object? agents = null,Object? workflows = null,Object? documents = null,Object? runningFlowruns = null,Object? generatingConversations = null,Object? blobBytes = null,}) {
  return _then(_WorkspaceStats(
conversations: null == conversations ? _self.conversations : conversations // ignore: cast_nullable_to_non_nullable
as int,functions: null == functions ? _self.functions : functions // ignore: cast_nullable_to_non_nullable
as int,handlers: null == handlers ? _self.handlers : handlers // ignore: cast_nullable_to_non_nullable
as int,agents: null == agents ? _self.agents : agents // ignore: cast_nullable_to_non_nullable
as int,workflows: null == workflows ? _self.workflows : workflows // ignore: cast_nullable_to_non_nullable
as int,documents: null == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as int,runningFlowruns: null == runningFlowruns ? _self.runningFlowruns : runningFlowruns // ignore: cast_nullable_to_non_nullable
as int,generatingConversations: null == generatingConversations ? _self.generatingConversations : generatingConversations // ignore: cast_nullable_to_non_nullable
as int,blobBytes: null == blobBytes ? _self.blobBytes : blobBytes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
