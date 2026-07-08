// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mcp.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$McpServerStatus {

 String get id; String get name; String get status;// disconnected|connecting|ready|degraded|failed
 DateTime? get connectedAt; String? get lastError; DateTime? get lastErrorAt; int get consecutiveFailures; int get totalCalls; int get totalFailures; List<McpToolDef> get tools;
/// Create a copy of McpServerStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpServerStatusCopyWith<McpServerStatus> get copyWith => _$McpServerStatusCopyWithImpl<McpServerStatus>(this as McpServerStatus, _$identity);

  /// Serializes this McpServerStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpServerStatus&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.status, status) || other.status == status)&&(identical(other.connectedAt, connectedAt) || other.connectedAt == connectedAt)&&(identical(other.lastError, lastError) || other.lastError == lastError)&&(identical(other.lastErrorAt, lastErrorAt) || other.lastErrorAt == lastErrorAt)&&(identical(other.consecutiveFailures, consecutiveFailures) || other.consecutiveFailures == consecutiveFailures)&&(identical(other.totalCalls, totalCalls) || other.totalCalls == totalCalls)&&(identical(other.totalFailures, totalFailures) || other.totalFailures == totalFailures)&&const DeepCollectionEquality().equals(other.tools, tools));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,status,connectedAt,lastError,lastErrorAt,consecutiveFailures,totalCalls,totalFailures,const DeepCollectionEquality().hash(tools));

@override
String toString() {
  return 'McpServerStatus(id: $id, name: $name, status: $status, connectedAt: $connectedAt, lastError: $lastError, lastErrorAt: $lastErrorAt, consecutiveFailures: $consecutiveFailures, totalCalls: $totalCalls, totalFailures: $totalFailures, tools: $tools)';
}


}

/// @nodoc
abstract mixin class $McpServerStatusCopyWith<$Res>  {
  factory $McpServerStatusCopyWith(McpServerStatus value, $Res Function(McpServerStatus) _then) = _$McpServerStatusCopyWithImpl;
@useResult
$Res call({
 String id, String name, String status, DateTime? connectedAt, String? lastError, DateTime? lastErrorAt, int consecutiveFailures, int totalCalls, int totalFailures, List<McpToolDef> tools
});




}
/// @nodoc
class _$McpServerStatusCopyWithImpl<$Res>
    implements $McpServerStatusCopyWith<$Res> {
  _$McpServerStatusCopyWithImpl(this._self, this._then);

  final McpServerStatus _self;
  final $Res Function(McpServerStatus) _then;

/// Create a copy of McpServerStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? status = null,Object? connectedAt = freezed,Object? lastError = freezed,Object? lastErrorAt = freezed,Object? consecutiveFailures = null,Object? totalCalls = null,Object? totalFailures = null,Object? tools = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,connectedAt: freezed == connectedAt ? _self.connectedAt : connectedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastError: freezed == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String?,lastErrorAt: freezed == lastErrorAt ? _self.lastErrorAt : lastErrorAt // ignore: cast_nullable_to_non_nullable
as DateTime?,consecutiveFailures: null == consecutiveFailures ? _self.consecutiveFailures : consecutiveFailures // ignore: cast_nullable_to_non_nullable
as int,totalCalls: null == totalCalls ? _self.totalCalls : totalCalls // ignore: cast_nullable_to_non_nullable
as int,totalFailures: null == totalFailures ? _self.totalFailures : totalFailures // ignore: cast_nullable_to_non_nullable
as int,tools: null == tools ? _self.tools : tools // ignore: cast_nullable_to_non_nullable
as List<McpToolDef>,
  ));
}

}


/// Adds pattern-matching-related methods to [McpServerStatus].
extension McpServerStatusPatterns on McpServerStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpServerStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpServerStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpServerStatus value)  $default,){
final _that = this;
switch (_that) {
case _McpServerStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpServerStatus value)?  $default,){
final _that = this;
switch (_that) {
case _McpServerStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String status,  DateTime? connectedAt,  String? lastError,  DateTime? lastErrorAt,  int consecutiveFailures,  int totalCalls,  int totalFailures,  List<McpToolDef> tools)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpServerStatus() when $default != null:
return $default(_that.id,_that.name,_that.status,_that.connectedAt,_that.lastError,_that.lastErrorAt,_that.consecutiveFailures,_that.totalCalls,_that.totalFailures,_that.tools);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String status,  DateTime? connectedAt,  String? lastError,  DateTime? lastErrorAt,  int consecutiveFailures,  int totalCalls,  int totalFailures,  List<McpToolDef> tools)  $default,) {final _that = this;
switch (_that) {
case _McpServerStatus():
return $default(_that.id,_that.name,_that.status,_that.connectedAt,_that.lastError,_that.lastErrorAt,_that.consecutiveFailures,_that.totalCalls,_that.totalFailures,_that.tools);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String status,  DateTime? connectedAt,  String? lastError,  DateTime? lastErrorAt,  int consecutiveFailures,  int totalCalls,  int totalFailures,  List<McpToolDef> tools)?  $default,) {final _that = this;
switch (_that) {
case _McpServerStatus() when $default != null:
return $default(_that.id,_that.name,_that.status,_that.connectedAt,_that.lastError,_that.lastErrorAt,_that.consecutiveFailures,_that.totalCalls,_that.totalFailures,_that.tools);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _McpServerStatus implements McpServerStatus {
  const _McpServerStatus({required this.id, required this.name, this.status = 'disconnected', this.connectedAt, this.lastError, this.lastErrorAt, this.consecutiveFailures = 0, this.totalCalls = 0, this.totalFailures = 0, final  List<McpToolDef> tools = const []}): _tools = tools;
  factory _McpServerStatus.fromJson(Map<String, dynamic> json) => _$McpServerStatusFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey() final  String status;
// disconnected|connecting|ready|degraded|failed
@override final  DateTime? connectedAt;
@override final  String? lastError;
@override final  DateTime? lastErrorAt;
@override@JsonKey() final  int consecutiveFailures;
@override@JsonKey() final  int totalCalls;
@override@JsonKey() final  int totalFailures;
 final  List<McpToolDef> _tools;
@override@JsonKey() List<McpToolDef> get tools {
  if (_tools is EqualUnmodifiableListView) return _tools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tools);
}


/// Create a copy of McpServerStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpServerStatusCopyWith<_McpServerStatus> get copyWith => __$McpServerStatusCopyWithImpl<_McpServerStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpServerStatusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpServerStatus&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.status, status) || other.status == status)&&(identical(other.connectedAt, connectedAt) || other.connectedAt == connectedAt)&&(identical(other.lastError, lastError) || other.lastError == lastError)&&(identical(other.lastErrorAt, lastErrorAt) || other.lastErrorAt == lastErrorAt)&&(identical(other.consecutiveFailures, consecutiveFailures) || other.consecutiveFailures == consecutiveFailures)&&(identical(other.totalCalls, totalCalls) || other.totalCalls == totalCalls)&&(identical(other.totalFailures, totalFailures) || other.totalFailures == totalFailures)&&const DeepCollectionEquality().equals(other._tools, _tools));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,status,connectedAt,lastError,lastErrorAt,consecutiveFailures,totalCalls,totalFailures,const DeepCollectionEquality().hash(_tools));

@override
String toString() {
  return 'McpServerStatus(id: $id, name: $name, status: $status, connectedAt: $connectedAt, lastError: $lastError, lastErrorAt: $lastErrorAt, consecutiveFailures: $consecutiveFailures, totalCalls: $totalCalls, totalFailures: $totalFailures, tools: $tools)';
}


}

/// @nodoc
abstract mixin class _$McpServerStatusCopyWith<$Res> implements $McpServerStatusCopyWith<$Res> {
  factory _$McpServerStatusCopyWith(_McpServerStatus value, $Res Function(_McpServerStatus) _then) = __$McpServerStatusCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String status, DateTime? connectedAt, String? lastError, DateTime? lastErrorAt, int consecutiveFailures, int totalCalls, int totalFailures, List<McpToolDef> tools
});




}
/// @nodoc
class __$McpServerStatusCopyWithImpl<$Res>
    implements _$McpServerStatusCopyWith<$Res> {
  __$McpServerStatusCopyWithImpl(this._self, this._then);

  final _McpServerStatus _self;
  final $Res Function(_McpServerStatus) _then;

/// Create a copy of McpServerStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? status = null,Object? connectedAt = freezed,Object? lastError = freezed,Object? lastErrorAt = freezed,Object? consecutiveFailures = null,Object? totalCalls = null,Object? totalFailures = null,Object? tools = null,}) {
  return _then(_McpServerStatus(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,connectedAt: freezed == connectedAt ? _self.connectedAt : connectedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastError: freezed == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String?,lastErrorAt: freezed == lastErrorAt ? _self.lastErrorAt : lastErrorAt // ignore: cast_nullable_to_non_nullable
as DateTime?,consecutiveFailures: null == consecutiveFailures ? _self.consecutiveFailures : consecutiveFailures // ignore: cast_nullable_to_non_nullable
as int,totalCalls: null == totalCalls ? _self.totalCalls : totalCalls // ignore: cast_nullable_to_non_nullable
as int,totalFailures: null == totalFailures ? _self.totalFailures : totalFailures // ignore: cast_nullable_to_non_nullable
as int,tools: null == tools ? _self._tools : tools // ignore: cast_nullable_to_non_nullable
as List<McpToolDef>,
  ));
}


}


/// @nodoc
mixin _$McpToolDef {

 String get serverName; String get name; String get description; Map<String, dynamic>? get inputSchema;
/// Create a copy of McpToolDef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpToolDefCopyWith<McpToolDef> get copyWith => _$McpToolDefCopyWithImpl<McpToolDef>(this as McpToolDef, _$identity);

  /// Serializes this McpToolDef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpToolDef&&(identical(other.serverName, serverName) || other.serverName == serverName)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.inputSchema, inputSchema));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serverName,name,description,const DeepCollectionEquality().hash(inputSchema));

@override
String toString() {
  return 'McpToolDef(serverName: $serverName, name: $name, description: $description, inputSchema: $inputSchema)';
}


}

/// @nodoc
abstract mixin class $McpToolDefCopyWith<$Res>  {
  factory $McpToolDefCopyWith(McpToolDef value, $Res Function(McpToolDef) _then) = _$McpToolDefCopyWithImpl;
@useResult
$Res call({
 String serverName, String name, String description, Map<String, dynamic>? inputSchema
});




}
/// @nodoc
class _$McpToolDefCopyWithImpl<$Res>
    implements $McpToolDefCopyWith<$Res> {
  _$McpToolDefCopyWithImpl(this._self, this._then);

  final McpToolDef _self;
  final $Res Function(McpToolDef) _then;

/// Create a copy of McpToolDef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? serverName = null,Object? name = null,Object? description = null,Object? inputSchema = freezed,}) {
  return _then(_self.copyWith(
serverName: null == serverName ? _self.serverName : serverName // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,inputSchema: freezed == inputSchema ? _self.inputSchema : inputSchema // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

}


/// Adds pattern-matching-related methods to [McpToolDef].
extension McpToolDefPatterns on McpToolDef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpToolDef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpToolDef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpToolDef value)  $default,){
final _that = this;
switch (_that) {
case _McpToolDef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpToolDef value)?  $default,){
final _that = this;
switch (_that) {
case _McpToolDef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String serverName,  String name,  String description,  Map<String, dynamic>? inputSchema)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpToolDef() when $default != null:
return $default(_that.serverName,_that.name,_that.description,_that.inputSchema);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String serverName,  String name,  String description,  Map<String, dynamic>? inputSchema)  $default,) {final _that = this;
switch (_that) {
case _McpToolDef():
return $default(_that.serverName,_that.name,_that.description,_that.inputSchema);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String serverName,  String name,  String description,  Map<String, dynamic>? inputSchema)?  $default,) {final _that = this;
switch (_that) {
case _McpToolDef() when $default != null:
return $default(_that.serverName,_that.name,_that.description,_that.inputSchema);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _McpToolDef implements McpToolDef {
  const _McpToolDef({this.serverName = '', required this.name, this.description = '', final  Map<String, dynamic>? inputSchema}): _inputSchema = inputSchema;
  factory _McpToolDef.fromJson(Map<String, dynamic> json) => _$McpToolDefFromJson(json);

@override@JsonKey() final  String serverName;
@override final  String name;
@override@JsonKey() final  String description;
 final  Map<String, dynamic>? _inputSchema;
@override Map<String, dynamic>? get inputSchema {
  final value = _inputSchema;
  if (value == null) return null;
  if (_inputSchema is EqualUnmodifiableMapView) return _inputSchema;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of McpToolDef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpToolDefCopyWith<_McpToolDef> get copyWith => __$McpToolDefCopyWithImpl<_McpToolDef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpToolDefToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpToolDef&&(identical(other.serverName, serverName) || other.serverName == serverName)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._inputSchema, _inputSchema));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serverName,name,description,const DeepCollectionEquality().hash(_inputSchema));

@override
String toString() {
  return 'McpToolDef(serverName: $serverName, name: $name, description: $description, inputSchema: $inputSchema)';
}


}

/// @nodoc
abstract mixin class _$McpToolDefCopyWith<$Res> implements $McpToolDefCopyWith<$Res> {
  factory _$McpToolDefCopyWith(_McpToolDef value, $Res Function(_McpToolDef) _then) = __$McpToolDefCopyWithImpl;
@override @useResult
$Res call({
 String serverName, String name, String description, Map<String, dynamic>? inputSchema
});




}
/// @nodoc
class __$McpToolDefCopyWithImpl<$Res>
    implements _$McpToolDefCopyWith<$Res> {
  __$McpToolDefCopyWithImpl(this._self, this._then);

  final _McpToolDef _self;
  final $Res Function(_McpToolDef) _then;

/// Create a copy of McpToolDef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? serverName = null,Object? name = null,Object? description = null,Object? inputSchema = freezed,}) {
  return _then(_McpToolDef(
serverName: null == serverName ? _self.serverName : serverName // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,inputSchema: freezed == inputSchema ? _self._inputSchema : inputSchema // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}


}


/// @nodoc
mixin _$McpRegistryEntry {

 String get name;// full slug e.g. io.github.upstash/context7 完整 slug
 String get description; String get prerequisite;
/// Create a copy of McpRegistryEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpRegistryEntryCopyWith<McpRegistryEntry> get copyWith => _$McpRegistryEntryCopyWithImpl<McpRegistryEntry>(this as McpRegistryEntry, _$identity);

  /// Serializes this McpRegistryEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpRegistryEntry&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.prerequisite, prerequisite) || other.prerequisite == prerequisite));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,prerequisite);

@override
String toString() {
  return 'McpRegistryEntry(name: $name, description: $description, prerequisite: $prerequisite)';
}


}

/// @nodoc
abstract mixin class $McpRegistryEntryCopyWith<$Res>  {
  factory $McpRegistryEntryCopyWith(McpRegistryEntry value, $Res Function(McpRegistryEntry) _then) = _$McpRegistryEntryCopyWithImpl;
@useResult
$Res call({
 String name, String description, String prerequisite
});




}
/// @nodoc
class _$McpRegistryEntryCopyWithImpl<$Res>
    implements $McpRegistryEntryCopyWith<$Res> {
  _$McpRegistryEntryCopyWithImpl(this._self, this._then);

  final McpRegistryEntry _self;
  final $Res Function(McpRegistryEntry) _then;

/// Create a copy of McpRegistryEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = null,Object? prerequisite = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,prerequisite: null == prerequisite ? _self.prerequisite : prerequisite // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [McpRegistryEntry].
extension McpRegistryEntryPatterns on McpRegistryEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpRegistryEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpRegistryEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpRegistryEntry value)  $default,){
final _that = this;
switch (_that) {
case _McpRegistryEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpRegistryEntry value)?  $default,){
final _that = this;
switch (_that) {
case _McpRegistryEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String description,  String prerequisite)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpRegistryEntry() when $default != null:
return $default(_that.name,_that.description,_that.prerequisite);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String description,  String prerequisite)  $default,) {final _that = this;
switch (_that) {
case _McpRegistryEntry():
return $default(_that.name,_that.description,_that.prerequisite);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String description,  String prerequisite)?  $default,) {final _that = this;
switch (_that) {
case _McpRegistryEntry() when $default != null:
return $default(_that.name,_that.description,_that.prerequisite);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _McpRegistryEntry implements McpRegistryEntry {
  const _McpRegistryEntry({required this.name, this.description = '', this.prerequisite = ''});
  factory _McpRegistryEntry.fromJson(Map<String, dynamic> json) => _$McpRegistryEntryFromJson(json);

@override final  String name;
// full slug e.g. io.github.upstash/context7 完整 slug
@override@JsonKey() final  String description;
@override@JsonKey() final  String prerequisite;

/// Create a copy of McpRegistryEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpRegistryEntryCopyWith<_McpRegistryEntry> get copyWith => __$McpRegistryEntryCopyWithImpl<_McpRegistryEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpRegistryEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpRegistryEntry&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.prerequisite, prerequisite) || other.prerequisite == prerequisite));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,prerequisite);

@override
String toString() {
  return 'McpRegistryEntry(name: $name, description: $description, prerequisite: $prerequisite)';
}


}

/// @nodoc
abstract mixin class _$McpRegistryEntryCopyWith<$Res> implements $McpRegistryEntryCopyWith<$Res> {
  factory _$McpRegistryEntryCopyWith(_McpRegistryEntry value, $Res Function(_McpRegistryEntry) _then) = __$McpRegistryEntryCopyWithImpl;
@override @useResult
$Res call({
 String name, String description, String prerequisite
});




}
/// @nodoc
class __$McpRegistryEntryCopyWithImpl<$Res>
    implements _$McpRegistryEntryCopyWith<$Res> {
  __$McpRegistryEntryCopyWithImpl(this._self, this._then);

  final _McpRegistryEntry _self;
  final $Res Function(_McpRegistryEntry) _then;

/// Create a copy of McpRegistryEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = null,Object? prerequisite = null,}) {
  return _then(_McpRegistryEntry(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,prerequisite: null == prerequisite ? _self.prerequisite : prerequisite // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$McpRegistryPlan {

 String get transport; String get runtime; bool get oauth; List<McpEnvVar> get envVars; String get prerequisite;
/// Create a copy of McpRegistryPlan
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpRegistryPlanCopyWith<McpRegistryPlan> get copyWith => _$McpRegistryPlanCopyWithImpl<McpRegistryPlan>(this as McpRegistryPlan, _$identity);

  /// Serializes this McpRegistryPlan to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpRegistryPlan&&(identical(other.transport, transport) || other.transport == transport)&&(identical(other.runtime, runtime) || other.runtime == runtime)&&(identical(other.oauth, oauth) || other.oauth == oauth)&&const DeepCollectionEquality().equals(other.envVars, envVars)&&(identical(other.prerequisite, prerequisite) || other.prerequisite == prerequisite));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,transport,runtime,oauth,const DeepCollectionEquality().hash(envVars),prerequisite);

@override
String toString() {
  return 'McpRegistryPlan(transport: $transport, runtime: $runtime, oauth: $oauth, envVars: $envVars, prerequisite: $prerequisite)';
}


}

/// @nodoc
abstract mixin class $McpRegistryPlanCopyWith<$Res>  {
  factory $McpRegistryPlanCopyWith(McpRegistryPlan value, $Res Function(McpRegistryPlan) _then) = _$McpRegistryPlanCopyWithImpl;
@useResult
$Res call({
 String transport, String runtime, bool oauth, List<McpEnvVar> envVars, String prerequisite
});




}
/// @nodoc
class _$McpRegistryPlanCopyWithImpl<$Res>
    implements $McpRegistryPlanCopyWith<$Res> {
  _$McpRegistryPlanCopyWithImpl(this._self, this._then);

  final McpRegistryPlan _self;
  final $Res Function(McpRegistryPlan) _then;

/// Create a copy of McpRegistryPlan
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? transport = null,Object? runtime = null,Object? oauth = null,Object? envVars = null,Object? prerequisite = null,}) {
  return _then(_self.copyWith(
transport: null == transport ? _self.transport : transport // ignore: cast_nullable_to_non_nullable
as String,runtime: null == runtime ? _self.runtime : runtime // ignore: cast_nullable_to_non_nullable
as String,oauth: null == oauth ? _self.oauth : oauth // ignore: cast_nullable_to_non_nullable
as bool,envVars: null == envVars ? _self.envVars : envVars // ignore: cast_nullable_to_non_nullable
as List<McpEnvVar>,prerequisite: null == prerequisite ? _self.prerequisite : prerequisite // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [McpRegistryPlan].
extension McpRegistryPlanPatterns on McpRegistryPlan {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpRegistryPlan value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpRegistryPlan() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpRegistryPlan value)  $default,){
final _that = this;
switch (_that) {
case _McpRegistryPlan():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpRegistryPlan value)?  $default,){
final _that = this;
switch (_that) {
case _McpRegistryPlan() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String transport,  String runtime,  bool oauth,  List<McpEnvVar> envVars,  String prerequisite)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpRegistryPlan() when $default != null:
return $default(_that.transport,_that.runtime,_that.oauth,_that.envVars,_that.prerequisite);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String transport,  String runtime,  bool oauth,  List<McpEnvVar> envVars,  String prerequisite)  $default,) {final _that = this;
switch (_that) {
case _McpRegistryPlan():
return $default(_that.transport,_that.runtime,_that.oauth,_that.envVars,_that.prerequisite);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String transport,  String runtime,  bool oauth,  List<McpEnvVar> envVars,  String prerequisite)?  $default,) {final _that = this;
switch (_that) {
case _McpRegistryPlan() when $default != null:
return $default(_that.transport,_that.runtime,_that.oauth,_that.envVars,_that.prerequisite);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _McpRegistryPlan implements McpRegistryPlan {
  const _McpRegistryPlan({required this.transport, this.runtime = '', this.oauth = false, final  List<McpEnvVar> envVars = const [], this.prerequisite = ''}): _envVars = envVars;
  factory _McpRegistryPlan.fromJson(Map<String, dynamic> json) => _$McpRegistryPlanFromJson(json);

@override final  String transport;
@override@JsonKey() final  String runtime;
@override@JsonKey() final  bool oauth;
 final  List<McpEnvVar> _envVars;
@override@JsonKey() List<McpEnvVar> get envVars {
  if (_envVars is EqualUnmodifiableListView) return _envVars;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_envVars);
}

@override@JsonKey() final  String prerequisite;

/// Create a copy of McpRegistryPlan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpRegistryPlanCopyWith<_McpRegistryPlan> get copyWith => __$McpRegistryPlanCopyWithImpl<_McpRegistryPlan>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpRegistryPlanToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpRegistryPlan&&(identical(other.transport, transport) || other.transport == transport)&&(identical(other.runtime, runtime) || other.runtime == runtime)&&(identical(other.oauth, oauth) || other.oauth == oauth)&&const DeepCollectionEquality().equals(other._envVars, _envVars)&&(identical(other.prerequisite, prerequisite) || other.prerequisite == prerequisite));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,transport,runtime,oauth,const DeepCollectionEquality().hash(_envVars),prerequisite);

@override
String toString() {
  return 'McpRegistryPlan(transport: $transport, runtime: $runtime, oauth: $oauth, envVars: $envVars, prerequisite: $prerequisite)';
}


}

/// @nodoc
abstract mixin class _$McpRegistryPlanCopyWith<$Res> implements $McpRegistryPlanCopyWith<$Res> {
  factory _$McpRegistryPlanCopyWith(_McpRegistryPlan value, $Res Function(_McpRegistryPlan) _then) = __$McpRegistryPlanCopyWithImpl;
@override @useResult
$Res call({
 String transport, String runtime, bool oauth, List<McpEnvVar> envVars, String prerequisite
});




}
/// @nodoc
class __$McpRegistryPlanCopyWithImpl<$Res>
    implements _$McpRegistryPlanCopyWith<$Res> {
  __$McpRegistryPlanCopyWithImpl(this._self, this._then);

  final _McpRegistryPlan _self;
  final $Res Function(_McpRegistryPlan) _then;

/// Create a copy of McpRegistryPlan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? transport = null,Object? runtime = null,Object? oauth = null,Object? envVars = null,Object? prerequisite = null,}) {
  return _then(_McpRegistryPlan(
transport: null == transport ? _self.transport : transport // ignore: cast_nullable_to_non_nullable
as String,runtime: null == runtime ? _self.runtime : runtime // ignore: cast_nullable_to_non_nullable
as String,oauth: null == oauth ? _self.oauth : oauth // ignore: cast_nullable_to_non_nullable
as bool,envVars: null == envVars ? _self._envVars : envVars // ignore: cast_nullable_to_non_nullable
as List<McpEnvVar>,prerequisite: null == prerequisite ? _self.prerequisite : prerequisite // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$McpEnvVar {

 String get name; String get description; bool get isSecret; bool get required;
/// Create a copy of McpEnvVar
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpEnvVarCopyWith<McpEnvVar> get copyWith => _$McpEnvVarCopyWithImpl<McpEnvVar>(this as McpEnvVar, _$identity);

  /// Serializes this McpEnvVar to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpEnvVar&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.isSecret, isSecret) || other.isSecret == isSecret)&&(identical(other.required, required) || other.required == required));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,isSecret,required);

@override
String toString() {
  return 'McpEnvVar(name: $name, description: $description, isSecret: $isSecret, required: $required)';
}


}

/// @nodoc
abstract mixin class $McpEnvVarCopyWith<$Res>  {
  factory $McpEnvVarCopyWith(McpEnvVar value, $Res Function(McpEnvVar) _then) = _$McpEnvVarCopyWithImpl;
@useResult
$Res call({
 String name, String description, bool isSecret, bool required
});




}
/// @nodoc
class _$McpEnvVarCopyWithImpl<$Res>
    implements $McpEnvVarCopyWith<$Res> {
  _$McpEnvVarCopyWithImpl(this._self, this._then);

  final McpEnvVar _self;
  final $Res Function(McpEnvVar) _then;

/// Create a copy of McpEnvVar
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = null,Object? isSecret = null,Object? required = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,isSecret: null == isSecret ? _self.isSecret : isSecret // ignore: cast_nullable_to_non_nullable
as bool,required: null == required ? _self.required : required // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [McpEnvVar].
extension McpEnvVarPatterns on McpEnvVar {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpEnvVar value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpEnvVar() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpEnvVar value)  $default,){
final _that = this;
switch (_that) {
case _McpEnvVar():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpEnvVar value)?  $default,){
final _that = this;
switch (_that) {
case _McpEnvVar() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String description,  bool isSecret,  bool required)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpEnvVar() when $default != null:
return $default(_that.name,_that.description,_that.isSecret,_that.required);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String description,  bool isSecret,  bool required)  $default,) {final _that = this;
switch (_that) {
case _McpEnvVar():
return $default(_that.name,_that.description,_that.isSecret,_that.required);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String description,  bool isSecret,  bool required)?  $default,) {final _that = this;
switch (_that) {
case _McpEnvVar() when $default != null:
return $default(_that.name,_that.description,_that.isSecret,_that.required);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _McpEnvVar implements McpEnvVar {
  const _McpEnvVar({required this.name, this.description = '', this.isSecret = false, this.required = false});
  factory _McpEnvVar.fromJson(Map<String, dynamic> json) => _$McpEnvVarFromJson(json);

@override final  String name;
@override@JsonKey() final  String description;
@override@JsonKey() final  bool isSecret;
@override@JsonKey() final  bool required;

/// Create a copy of McpEnvVar
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpEnvVarCopyWith<_McpEnvVar> get copyWith => __$McpEnvVarCopyWithImpl<_McpEnvVar>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpEnvVarToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpEnvVar&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.isSecret, isSecret) || other.isSecret == isSecret)&&(identical(other.required, required) || other.required == required));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,isSecret,required);

@override
String toString() {
  return 'McpEnvVar(name: $name, description: $description, isSecret: $isSecret, required: $required)';
}


}

/// @nodoc
abstract mixin class _$McpEnvVarCopyWith<$Res> implements $McpEnvVarCopyWith<$Res> {
  factory _$McpEnvVarCopyWith(_McpEnvVar value, $Res Function(_McpEnvVar) _then) = __$McpEnvVarCopyWithImpl;
@override @useResult
$Res call({
 String name, String description, bool isSecret, bool required
});




}
/// @nodoc
class __$McpEnvVarCopyWithImpl<$Res>
    implements _$McpEnvVarCopyWith<$Res> {
  __$McpEnvVarCopyWithImpl(this._self, this._then);

  final _McpEnvVar _self;
  final $Res Function(_McpEnvVar) _then;

/// Create a copy of McpEnvVar
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = null,Object? isSecret = null,Object? required = null,}) {
  return _then(_McpEnvVar(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,isSecret: null == isSecret ? _self.isSecret : isSecret // ignore: cast_nullable_to_non_nullable
as bool,required: null == required ? _self.required : required // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$McpCall {

 String get id; String get serverId; String get tool; String get status;// ok|failed|cancelled|timeout
 String get triggeredBy;// chat|agent|workflow|manual
 String? get errorMessage; int get elapsedMs; DateTime? get startedAt; DateTime? get createdAt;
/// Create a copy of McpCall
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpCallCopyWith<McpCall> get copyWith => _$McpCallCopyWithImpl<McpCall>(this as McpCall, _$identity);

  /// Serializes this McpCall to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpCall&&(identical(other.id, id) || other.id == id)&&(identical(other.serverId, serverId) || other.serverId == serverId)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.status, status) || other.status == status)&&(identical(other.triggeredBy, triggeredBy) || other.triggeredBy == triggeredBy)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.elapsedMs, elapsedMs) || other.elapsedMs == elapsedMs)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,serverId,tool,status,triggeredBy,errorMessage,elapsedMs,startedAt,createdAt);

@override
String toString() {
  return 'McpCall(id: $id, serverId: $serverId, tool: $tool, status: $status, triggeredBy: $triggeredBy, errorMessage: $errorMessage, elapsedMs: $elapsedMs, startedAt: $startedAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $McpCallCopyWith<$Res>  {
  factory $McpCallCopyWith(McpCall value, $Res Function(McpCall) _then) = _$McpCallCopyWithImpl;
@useResult
$Res call({
 String id, String serverId, String tool, String status, String triggeredBy, String? errorMessage, int elapsedMs, DateTime? startedAt, DateTime? createdAt
});




}
/// @nodoc
class _$McpCallCopyWithImpl<$Res>
    implements $McpCallCopyWith<$Res> {
  _$McpCallCopyWithImpl(this._self, this._then);

  final McpCall _self;
  final $Res Function(McpCall) _then;

/// Create a copy of McpCall
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? serverId = null,Object? tool = null,Object? status = null,Object? triggeredBy = null,Object? errorMessage = freezed,Object? elapsedMs = null,Object? startedAt = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,serverId: null == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,triggeredBy: null == triggeredBy ? _self.triggeredBy : triggeredBy // ignore: cast_nullable_to_non_nullable
as String,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,elapsedMs: null == elapsedMs ? _self.elapsedMs : elapsedMs // ignore: cast_nullable_to_non_nullable
as int,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [McpCall].
extension McpCallPatterns on McpCall {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpCall value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpCall() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpCall value)  $default,){
final _that = this;
switch (_that) {
case _McpCall():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpCall value)?  $default,){
final _that = this;
switch (_that) {
case _McpCall() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String serverId,  String tool,  String status,  String triggeredBy,  String? errorMessage,  int elapsedMs,  DateTime? startedAt,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpCall() when $default != null:
return $default(_that.id,_that.serverId,_that.tool,_that.status,_that.triggeredBy,_that.errorMessage,_that.elapsedMs,_that.startedAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String serverId,  String tool,  String status,  String triggeredBy,  String? errorMessage,  int elapsedMs,  DateTime? startedAt,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _McpCall():
return $default(_that.id,_that.serverId,_that.tool,_that.status,_that.triggeredBy,_that.errorMessage,_that.elapsedMs,_that.startedAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String serverId,  String tool,  String status,  String triggeredBy,  String? errorMessage,  int elapsedMs,  DateTime? startedAt,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _McpCall() when $default != null:
return $default(_that.id,_that.serverId,_that.tool,_that.status,_that.triggeredBy,_that.errorMessage,_that.elapsedMs,_that.startedAt,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _McpCall implements McpCall {
  const _McpCall({required this.id, this.serverId = '', this.tool = '', this.status = '', this.triggeredBy = '', this.errorMessage, this.elapsedMs = 0, this.startedAt, this.createdAt});
  factory _McpCall.fromJson(Map<String, dynamic> json) => _$McpCallFromJson(json);

@override final  String id;
@override@JsonKey() final  String serverId;
@override@JsonKey() final  String tool;
@override@JsonKey() final  String status;
// ok|failed|cancelled|timeout
@override@JsonKey() final  String triggeredBy;
// chat|agent|workflow|manual
@override final  String? errorMessage;
@override@JsonKey() final  int elapsedMs;
@override final  DateTime? startedAt;
@override final  DateTime? createdAt;

/// Create a copy of McpCall
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpCallCopyWith<_McpCall> get copyWith => __$McpCallCopyWithImpl<_McpCall>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpCallToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpCall&&(identical(other.id, id) || other.id == id)&&(identical(other.serverId, serverId) || other.serverId == serverId)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.status, status) || other.status == status)&&(identical(other.triggeredBy, triggeredBy) || other.triggeredBy == triggeredBy)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.elapsedMs, elapsedMs) || other.elapsedMs == elapsedMs)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,serverId,tool,status,triggeredBy,errorMessage,elapsedMs,startedAt,createdAt);

@override
String toString() {
  return 'McpCall(id: $id, serverId: $serverId, tool: $tool, status: $status, triggeredBy: $triggeredBy, errorMessage: $errorMessage, elapsedMs: $elapsedMs, startedAt: $startedAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$McpCallCopyWith<$Res> implements $McpCallCopyWith<$Res> {
  factory _$McpCallCopyWith(_McpCall value, $Res Function(_McpCall) _then) = __$McpCallCopyWithImpl;
@override @useResult
$Res call({
 String id, String serverId, String tool, String status, String triggeredBy, String? errorMessage, int elapsedMs, DateTime? startedAt, DateTime? createdAt
});




}
/// @nodoc
class __$McpCallCopyWithImpl<$Res>
    implements _$McpCallCopyWith<$Res> {
  __$McpCallCopyWithImpl(this._self, this._then);

  final _McpCall _self;
  final $Res Function(_McpCall) _then;

/// Create a copy of McpCall
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? serverId = null,Object? tool = null,Object? status = null,Object? triggeredBy = null,Object? errorMessage = freezed,Object? elapsedMs = null,Object? startedAt = freezed,Object? createdAt = freezed,}) {
  return _then(_McpCall(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,serverId: null == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,triggeredBy: null == triggeredBy ? _self.triggeredBy : triggeredBy // ignore: cast_nullable_to_non_nullable
as String,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,elapsedMs: null == elapsedMs ? _self.elapsedMs : elapsedMs // ignore: cast_nullable_to_non_nullable
as int,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
