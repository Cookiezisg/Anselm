// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sandbox.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SandboxRuntime {

 String get id; String get kind; String get version; int get sizeBytes; DateTime? get installedAt;
/// Create a copy of SandboxRuntime
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SandboxRuntimeCopyWith<SandboxRuntime> get copyWith => _$SandboxRuntimeCopyWithImpl<SandboxRuntime>(this as SandboxRuntime, _$identity);

  /// Serializes this SandboxRuntime to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SandboxRuntime&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.version, version) || other.version == version)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.installedAt, installedAt) || other.installedAt == installedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,version,sizeBytes,installedAt);

@override
String toString() {
  return 'SandboxRuntime(id: $id, kind: $kind, version: $version, sizeBytes: $sizeBytes, installedAt: $installedAt)';
}


}

/// @nodoc
abstract mixin class $SandboxRuntimeCopyWith<$Res>  {
  factory $SandboxRuntimeCopyWith(SandboxRuntime value, $Res Function(SandboxRuntime) _then) = _$SandboxRuntimeCopyWithImpl;
@useResult
$Res call({
 String id, String kind, String version, int sizeBytes, DateTime? installedAt
});




}
/// @nodoc
class _$SandboxRuntimeCopyWithImpl<$Res>
    implements $SandboxRuntimeCopyWith<$Res> {
  _$SandboxRuntimeCopyWithImpl(this._self, this._then);

  final SandboxRuntime _self;
  final $Res Function(SandboxRuntime) _then;

/// Create a copy of SandboxRuntime
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? version = null,Object? sizeBytes = null,Object? installedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,installedAt: freezed == installedAt ? _self.installedAt : installedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SandboxRuntime].
extension SandboxRuntimePatterns on SandboxRuntime {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SandboxRuntime value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SandboxRuntime() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SandboxRuntime value)  $default,){
final _that = this;
switch (_that) {
case _SandboxRuntime():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SandboxRuntime value)?  $default,){
final _that = this;
switch (_that) {
case _SandboxRuntime() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String kind,  String version,  int sizeBytes,  DateTime? installedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SandboxRuntime() when $default != null:
return $default(_that.id,_that.kind,_that.version,_that.sizeBytes,_that.installedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String kind,  String version,  int sizeBytes,  DateTime? installedAt)  $default,) {final _that = this;
switch (_that) {
case _SandboxRuntime():
return $default(_that.id,_that.kind,_that.version,_that.sizeBytes,_that.installedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String kind,  String version,  int sizeBytes,  DateTime? installedAt)?  $default,) {final _that = this;
switch (_that) {
case _SandboxRuntime() when $default != null:
return $default(_that.id,_that.kind,_that.version,_that.sizeBytes,_that.installedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SandboxRuntime implements SandboxRuntime {
  const _SandboxRuntime({required this.id, required this.kind, this.version = '', this.sizeBytes = 0, this.installedAt});
  factory _SandboxRuntime.fromJson(Map<String, dynamic> json) => _$SandboxRuntimeFromJson(json);

@override final  String id;
@override final  String kind;
@override@JsonKey() final  String version;
@override@JsonKey() final  int sizeBytes;
@override final  DateTime? installedAt;

/// Create a copy of SandboxRuntime
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SandboxRuntimeCopyWith<_SandboxRuntime> get copyWith => __$SandboxRuntimeCopyWithImpl<_SandboxRuntime>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SandboxRuntimeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SandboxRuntime&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.version, version) || other.version == version)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.installedAt, installedAt) || other.installedAt == installedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,version,sizeBytes,installedAt);

@override
String toString() {
  return 'SandboxRuntime(id: $id, kind: $kind, version: $version, sizeBytes: $sizeBytes, installedAt: $installedAt)';
}


}

/// @nodoc
abstract mixin class _$SandboxRuntimeCopyWith<$Res> implements $SandboxRuntimeCopyWith<$Res> {
  factory _$SandboxRuntimeCopyWith(_SandboxRuntime value, $Res Function(_SandboxRuntime) _then) = __$SandboxRuntimeCopyWithImpl;
@override @useResult
$Res call({
 String id, String kind, String version, int sizeBytes, DateTime? installedAt
});




}
/// @nodoc
class __$SandboxRuntimeCopyWithImpl<$Res>
    implements _$SandboxRuntimeCopyWith<$Res> {
  __$SandboxRuntimeCopyWithImpl(this._self, this._then);

  final _SandboxRuntime _self;
  final $Res Function(_SandboxRuntime) _then;

/// Create a copy of SandboxRuntime
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? version = null,Object? sizeBytes = null,Object? installedAt = freezed,}) {
  return _then(_SandboxRuntime(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,installedAt: freezed == installedAt ? _self.installedAt : installedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$RuntimeAvailability {

 String get kind;@JsonKey(name: 'default') String get defaultVersion; List<String> get versions; bool get pinned;
/// Create a copy of RuntimeAvailability
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RuntimeAvailabilityCopyWith<RuntimeAvailability> get copyWith => _$RuntimeAvailabilityCopyWithImpl<RuntimeAvailability>(this as RuntimeAvailability, _$identity);

  /// Serializes this RuntimeAvailability to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RuntimeAvailability&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.defaultVersion, defaultVersion) || other.defaultVersion == defaultVersion)&&const DeepCollectionEquality().equals(other.versions, versions)&&(identical(other.pinned, pinned) || other.pinned == pinned));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,defaultVersion,const DeepCollectionEquality().hash(versions),pinned);

@override
String toString() {
  return 'RuntimeAvailability(kind: $kind, defaultVersion: $defaultVersion, versions: $versions, pinned: $pinned)';
}


}

/// @nodoc
abstract mixin class $RuntimeAvailabilityCopyWith<$Res>  {
  factory $RuntimeAvailabilityCopyWith(RuntimeAvailability value, $Res Function(RuntimeAvailability) _then) = _$RuntimeAvailabilityCopyWithImpl;
@useResult
$Res call({
 String kind,@JsonKey(name: 'default') String defaultVersion, List<String> versions, bool pinned
});




}
/// @nodoc
class _$RuntimeAvailabilityCopyWithImpl<$Res>
    implements $RuntimeAvailabilityCopyWith<$Res> {
  _$RuntimeAvailabilityCopyWithImpl(this._self, this._then);

  final RuntimeAvailability _self;
  final $Res Function(RuntimeAvailability) _then;

/// Create a copy of RuntimeAvailability
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? defaultVersion = null,Object? versions = null,Object? pinned = null,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,defaultVersion: null == defaultVersion ? _self.defaultVersion : defaultVersion // ignore: cast_nullable_to_non_nullable
as String,versions: null == versions ? _self.versions : versions // ignore: cast_nullable_to_non_nullable
as List<String>,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [RuntimeAvailability].
extension RuntimeAvailabilityPatterns on RuntimeAvailability {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RuntimeAvailability value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RuntimeAvailability() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RuntimeAvailability value)  $default,){
final _that = this;
switch (_that) {
case _RuntimeAvailability():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RuntimeAvailability value)?  $default,){
final _that = this;
switch (_that) {
case _RuntimeAvailability() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String kind, @JsonKey(name: 'default')  String defaultVersion,  List<String> versions,  bool pinned)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RuntimeAvailability() when $default != null:
return $default(_that.kind,_that.defaultVersion,_that.versions,_that.pinned);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String kind, @JsonKey(name: 'default')  String defaultVersion,  List<String> versions,  bool pinned)  $default,) {final _that = this;
switch (_that) {
case _RuntimeAvailability():
return $default(_that.kind,_that.defaultVersion,_that.versions,_that.pinned);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String kind, @JsonKey(name: 'default')  String defaultVersion,  List<String> versions,  bool pinned)?  $default,) {final _that = this;
switch (_that) {
case _RuntimeAvailability() when $default != null:
return $default(_that.kind,_that.defaultVersion,_that.versions,_that.pinned);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RuntimeAvailability implements RuntimeAvailability {
  const _RuntimeAvailability({required this.kind, @JsonKey(name: 'default') this.defaultVersion = '', final  List<String> versions = const [], this.pinned = false}): _versions = versions;
  factory _RuntimeAvailability.fromJson(Map<String, dynamic> json) => _$RuntimeAvailabilityFromJson(json);

@override final  String kind;
@override@JsonKey(name: 'default') final  String defaultVersion;
 final  List<String> _versions;
@override@JsonKey() List<String> get versions {
  if (_versions is EqualUnmodifiableListView) return _versions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_versions);
}

@override@JsonKey() final  bool pinned;

/// Create a copy of RuntimeAvailability
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RuntimeAvailabilityCopyWith<_RuntimeAvailability> get copyWith => __$RuntimeAvailabilityCopyWithImpl<_RuntimeAvailability>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RuntimeAvailabilityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RuntimeAvailability&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.defaultVersion, defaultVersion) || other.defaultVersion == defaultVersion)&&const DeepCollectionEquality().equals(other._versions, _versions)&&(identical(other.pinned, pinned) || other.pinned == pinned));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,defaultVersion,const DeepCollectionEquality().hash(_versions),pinned);

@override
String toString() {
  return 'RuntimeAvailability(kind: $kind, defaultVersion: $defaultVersion, versions: $versions, pinned: $pinned)';
}


}

/// @nodoc
abstract mixin class _$RuntimeAvailabilityCopyWith<$Res> implements $RuntimeAvailabilityCopyWith<$Res> {
  factory _$RuntimeAvailabilityCopyWith(_RuntimeAvailability value, $Res Function(_RuntimeAvailability) _then) = __$RuntimeAvailabilityCopyWithImpl;
@override @useResult
$Res call({
 String kind,@JsonKey(name: 'default') String defaultVersion, List<String> versions, bool pinned
});




}
/// @nodoc
class __$RuntimeAvailabilityCopyWithImpl<$Res>
    implements _$RuntimeAvailabilityCopyWith<$Res> {
  __$RuntimeAvailabilityCopyWithImpl(this._self, this._then);

  final _RuntimeAvailability _self;
  final $Res Function(_RuntimeAvailability) _then;

/// Create a copy of RuntimeAvailability
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? defaultVersion = null,Object? versions = null,Object? pinned = null,}) {
  return _then(_RuntimeAvailability(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,defaultVersion: null == defaultVersion ? _self.defaultVersion : defaultVersion // ignore: cast_nullable_to_non_nullable
as String,versions: null == versions ? _self._versions : versions // ignore: cast_nullable_to_non_nullable
as List<String>,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$SandboxEnv {

 String get id; String get ownerKind; String get ownerId; String get ownerName; String get runtimeId; List<String> get deps; int get sizeBytes; String get status; String? get errorMsg; DateTime? get lastUsedAt; int? get runningPid;
/// Create a copy of SandboxEnv
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SandboxEnvCopyWith<SandboxEnv> get copyWith => _$SandboxEnvCopyWithImpl<SandboxEnv>(this as SandboxEnv, _$identity);

  /// Serializes this SandboxEnv to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SandboxEnv&&(identical(other.id, id) || other.id == id)&&(identical(other.ownerKind, ownerKind) || other.ownerKind == ownerKind)&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId)&&(identical(other.ownerName, ownerName) || other.ownerName == ownerName)&&(identical(other.runtimeId, runtimeId) || other.runtimeId == runtimeId)&&const DeepCollectionEquality().equals(other.deps, deps)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.status, status) || other.status == status)&&(identical(other.errorMsg, errorMsg) || other.errorMsg == errorMsg)&&(identical(other.lastUsedAt, lastUsedAt) || other.lastUsedAt == lastUsedAt)&&(identical(other.runningPid, runningPid) || other.runningPid == runningPid));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ownerKind,ownerId,ownerName,runtimeId,const DeepCollectionEquality().hash(deps),sizeBytes,status,errorMsg,lastUsedAt,runningPid);

@override
String toString() {
  return 'SandboxEnv(id: $id, ownerKind: $ownerKind, ownerId: $ownerId, ownerName: $ownerName, runtimeId: $runtimeId, deps: $deps, sizeBytes: $sizeBytes, status: $status, errorMsg: $errorMsg, lastUsedAt: $lastUsedAt, runningPid: $runningPid)';
}


}

/// @nodoc
abstract mixin class $SandboxEnvCopyWith<$Res>  {
  factory $SandboxEnvCopyWith(SandboxEnv value, $Res Function(SandboxEnv) _then) = _$SandboxEnvCopyWithImpl;
@useResult
$Res call({
 String id, String ownerKind, String ownerId, String ownerName, String runtimeId, List<String> deps, int sizeBytes, String status, String? errorMsg, DateTime? lastUsedAt, int? runningPid
});




}
/// @nodoc
class _$SandboxEnvCopyWithImpl<$Res>
    implements $SandboxEnvCopyWith<$Res> {
  _$SandboxEnvCopyWithImpl(this._self, this._then);

  final SandboxEnv _self;
  final $Res Function(SandboxEnv) _then;

/// Create a copy of SandboxEnv
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ownerKind = null,Object? ownerId = null,Object? ownerName = null,Object? runtimeId = null,Object? deps = null,Object? sizeBytes = null,Object? status = null,Object? errorMsg = freezed,Object? lastUsedAt = freezed,Object? runningPid = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ownerKind: null == ownerKind ? _self.ownerKind : ownerKind // ignore: cast_nullable_to_non_nullable
as String,ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,ownerName: null == ownerName ? _self.ownerName : ownerName // ignore: cast_nullable_to_non_nullable
as String,runtimeId: null == runtimeId ? _self.runtimeId : runtimeId // ignore: cast_nullable_to_non_nullable
as String,deps: null == deps ? _self.deps : deps // ignore: cast_nullable_to_non_nullable
as List<String>,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,errorMsg: freezed == errorMsg ? _self.errorMsg : errorMsg // ignore: cast_nullable_to_non_nullable
as String?,lastUsedAt: freezed == lastUsedAt ? _self.lastUsedAt : lastUsedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,runningPid: freezed == runningPid ? _self.runningPid : runningPid // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [SandboxEnv].
extension SandboxEnvPatterns on SandboxEnv {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SandboxEnv value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SandboxEnv() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SandboxEnv value)  $default,){
final _that = this;
switch (_that) {
case _SandboxEnv():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SandboxEnv value)?  $default,){
final _that = this;
switch (_that) {
case _SandboxEnv() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String ownerKind,  String ownerId,  String ownerName,  String runtimeId,  List<String> deps,  int sizeBytes,  String status,  String? errorMsg,  DateTime? lastUsedAt,  int? runningPid)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SandboxEnv() when $default != null:
return $default(_that.id,_that.ownerKind,_that.ownerId,_that.ownerName,_that.runtimeId,_that.deps,_that.sizeBytes,_that.status,_that.errorMsg,_that.lastUsedAt,_that.runningPid);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String ownerKind,  String ownerId,  String ownerName,  String runtimeId,  List<String> deps,  int sizeBytes,  String status,  String? errorMsg,  DateTime? lastUsedAt,  int? runningPid)  $default,) {final _that = this;
switch (_that) {
case _SandboxEnv():
return $default(_that.id,_that.ownerKind,_that.ownerId,_that.ownerName,_that.runtimeId,_that.deps,_that.sizeBytes,_that.status,_that.errorMsg,_that.lastUsedAt,_that.runningPid);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String ownerKind,  String ownerId,  String ownerName,  String runtimeId,  List<String> deps,  int sizeBytes,  String status,  String? errorMsg,  DateTime? lastUsedAt,  int? runningPid)?  $default,) {final _that = this;
switch (_that) {
case _SandboxEnv() when $default != null:
return $default(_that.id,_that.ownerKind,_that.ownerId,_that.ownerName,_that.runtimeId,_that.deps,_that.sizeBytes,_that.status,_that.errorMsg,_that.lastUsedAt,_that.runningPid);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SandboxEnv implements SandboxEnv {
  const _SandboxEnv({required this.id, this.ownerKind = '', this.ownerId = '', this.ownerName = '', this.runtimeId = '', final  List<String> deps = const [], this.sizeBytes = 0, this.status = '', this.errorMsg, this.lastUsedAt, this.runningPid}): _deps = deps;
  factory _SandboxEnv.fromJson(Map<String, dynamic> json) => _$SandboxEnvFromJson(json);

@override final  String id;
@override@JsonKey() final  String ownerKind;
@override@JsonKey() final  String ownerId;
@override@JsonKey() final  String ownerName;
@override@JsonKey() final  String runtimeId;
 final  List<String> _deps;
@override@JsonKey() List<String> get deps {
  if (_deps is EqualUnmodifiableListView) return _deps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_deps);
}

@override@JsonKey() final  int sizeBytes;
@override@JsonKey() final  String status;
@override final  String? errorMsg;
@override final  DateTime? lastUsedAt;
@override final  int? runningPid;

/// Create a copy of SandboxEnv
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SandboxEnvCopyWith<_SandboxEnv> get copyWith => __$SandboxEnvCopyWithImpl<_SandboxEnv>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SandboxEnvToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SandboxEnv&&(identical(other.id, id) || other.id == id)&&(identical(other.ownerKind, ownerKind) || other.ownerKind == ownerKind)&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId)&&(identical(other.ownerName, ownerName) || other.ownerName == ownerName)&&(identical(other.runtimeId, runtimeId) || other.runtimeId == runtimeId)&&const DeepCollectionEquality().equals(other._deps, _deps)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.status, status) || other.status == status)&&(identical(other.errorMsg, errorMsg) || other.errorMsg == errorMsg)&&(identical(other.lastUsedAt, lastUsedAt) || other.lastUsedAt == lastUsedAt)&&(identical(other.runningPid, runningPid) || other.runningPid == runningPid));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ownerKind,ownerId,ownerName,runtimeId,const DeepCollectionEquality().hash(_deps),sizeBytes,status,errorMsg,lastUsedAt,runningPid);

@override
String toString() {
  return 'SandboxEnv(id: $id, ownerKind: $ownerKind, ownerId: $ownerId, ownerName: $ownerName, runtimeId: $runtimeId, deps: $deps, sizeBytes: $sizeBytes, status: $status, errorMsg: $errorMsg, lastUsedAt: $lastUsedAt, runningPid: $runningPid)';
}


}

/// @nodoc
abstract mixin class _$SandboxEnvCopyWith<$Res> implements $SandboxEnvCopyWith<$Res> {
  factory _$SandboxEnvCopyWith(_SandboxEnv value, $Res Function(_SandboxEnv) _then) = __$SandboxEnvCopyWithImpl;
@override @useResult
$Res call({
 String id, String ownerKind, String ownerId, String ownerName, String runtimeId, List<String> deps, int sizeBytes, String status, String? errorMsg, DateTime? lastUsedAt, int? runningPid
});




}
/// @nodoc
class __$SandboxEnvCopyWithImpl<$Res>
    implements _$SandboxEnvCopyWith<$Res> {
  __$SandboxEnvCopyWithImpl(this._self, this._then);

  final _SandboxEnv _self;
  final $Res Function(_SandboxEnv) _then;

/// Create a copy of SandboxEnv
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ownerKind = null,Object? ownerId = null,Object? ownerName = null,Object? runtimeId = null,Object? deps = null,Object? sizeBytes = null,Object? status = null,Object? errorMsg = freezed,Object? lastUsedAt = freezed,Object? runningPid = freezed,}) {
  return _then(_SandboxEnv(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ownerKind: null == ownerKind ? _self.ownerKind : ownerKind // ignore: cast_nullable_to_non_nullable
as String,ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,ownerName: null == ownerName ? _self.ownerName : ownerName // ignore: cast_nullable_to_non_nullable
as String,runtimeId: null == runtimeId ? _self.runtimeId : runtimeId // ignore: cast_nullable_to_non_nullable
as String,deps: null == deps ? _self._deps : deps // ignore: cast_nullable_to_non_nullable
as List<String>,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,errorMsg: freezed == errorMsg ? _self.errorMsg : errorMsg // ignore: cast_nullable_to_non_nullable
as String?,lastUsedAt: freezed == lastUsedAt ? _self.lastUsedAt : lastUsedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,runningPid: freezed == runningPid ? _self.runningPid : runningPid // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$SandboxBootstrap {

 bool get ok; String? get error;
/// Create a copy of SandboxBootstrap
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SandboxBootstrapCopyWith<SandboxBootstrap> get copyWith => _$SandboxBootstrapCopyWithImpl<SandboxBootstrap>(this as SandboxBootstrap, _$identity);

  /// Serializes this SandboxBootstrap to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SandboxBootstrap&&(identical(other.ok, ok) || other.ok == ok)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ok,error);

@override
String toString() {
  return 'SandboxBootstrap(ok: $ok, error: $error)';
}


}

/// @nodoc
abstract mixin class $SandboxBootstrapCopyWith<$Res>  {
  factory $SandboxBootstrapCopyWith(SandboxBootstrap value, $Res Function(SandboxBootstrap) _then) = _$SandboxBootstrapCopyWithImpl;
@useResult
$Res call({
 bool ok, String? error
});




}
/// @nodoc
class _$SandboxBootstrapCopyWithImpl<$Res>
    implements $SandboxBootstrapCopyWith<$Res> {
  _$SandboxBootstrapCopyWithImpl(this._self, this._then);

  final SandboxBootstrap _self;
  final $Res Function(SandboxBootstrap) _then;

/// Create a copy of SandboxBootstrap
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ok = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
ok: null == ok ? _self.ok : ok // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SandboxBootstrap].
extension SandboxBootstrapPatterns on SandboxBootstrap {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SandboxBootstrap value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SandboxBootstrap() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SandboxBootstrap value)  $default,){
final _that = this;
switch (_that) {
case _SandboxBootstrap():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SandboxBootstrap value)?  $default,){
final _that = this;
switch (_that) {
case _SandboxBootstrap() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool ok,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SandboxBootstrap() when $default != null:
return $default(_that.ok,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool ok,  String? error)  $default,) {final _that = this;
switch (_that) {
case _SandboxBootstrap():
return $default(_that.ok,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool ok,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _SandboxBootstrap() when $default != null:
return $default(_that.ok,_that.error);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SandboxBootstrap implements SandboxBootstrap {
  const _SandboxBootstrap({this.ok = false, this.error});
  factory _SandboxBootstrap.fromJson(Map<String, dynamic> json) => _$SandboxBootstrapFromJson(json);

@override@JsonKey() final  bool ok;
@override final  String? error;

/// Create a copy of SandboxBootstrap
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SandboxBootstrapCopyWith<_SandboxBootstrap> get copyWith => __$SandboxBootstrapCopyWithImpl<_SandboxBootstrap>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SandboxBootstrapToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SandboxBootstrap&&(identical(other.ok, ok) || other.ok == ok)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ok,error);

@override
String toString() {
  return 'SandboxBootstrap(ok: $ok, error: $error)';
}


}

/// @nodoc
abstract mixin class _$SandboxBootstrapCopyWith<$Res> implements $SandboxBootstrapCopyWith<$Res> {
  factory _$SandboxBootstrapCopyWith(_SandboxBootstrap value, $Res Function(_SandboxBootstrap) _then) = __$SandboxBootstrapCopyWithImpl;
@override @useResult
$Res call({
 bool ok, String? error
});




}
/// @nodoc
class __$SandboxBootstrapCopyWithImpl<$Res>
    implements _$SandboxBootstrapCopyWith<$Res> {
  __$SandboxBootstrapCopyWithImpl(this._self, this._then);

  final _SandboxBootstrap _self;
  final $Res Function(_SandboxBootstrap) _then;

/// Create a copy of SandboxBootstrap
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ok = null,Object? error = freezed,}) {
  return _then(_SandboxBootstrap(
ok: null == ok ? _self.ok : ok // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
