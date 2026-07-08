// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'api_key.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ApiKey {

 String get id; String get provider; String get displayName; String get keyMasked; String get baseUrl; String get apiFormat; String get testStatus; String get testError; DateTime? get lastTestedAt; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of ApiKey
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiKeyCopyWith<ApiKey> get copyWith => _$ApiKeyCopyWithImpl<ApiKey>(this as ApiKey, _$identity);

  /// Serializes this ApiKey to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiKey&&(identical(other.id, id) || other.id == id)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.keyMasked, keyMasked) || other.keyMasked == keyMasked)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.apiFormat, apiFormat) || other.apiFormat == apiFormat)&&(identical(other.testStatus, testStatus) || other.testStatus == testStatus)&&(identical(other.testError, testError) || other.testError == testError)&&(identical(other.lastTestedAt, lastTestedAt) || other.lastTestedAt == lastTestedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,provider,displayName,keyMasked,baseUrl,apiFormat,testStatus,testError,lastTestedAt,createdAt,updatedAt);

@override
String toString() {
  return 'ApiKey(id: $id, provider: $provider, displayName: $displayName, keyMasked: $keyMasked, baseUrl: $baseUrl, apiFormat: $apiFormat, testStatus: $testStatus, testError: $testError, lastTestedAt: $lastTestedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ApiKeyCopyWith<$Res>  {
  factory $ApiKeyCopyWith(ApiKey value, $Res Function(ApiKey) _then) = _$ApiKeyCopyWithImpl;
@useResult
$Res call({
 String id, String provider, String displayName, String keyMasked, String baseUrl, String apiFormat, String testStatus, String testError, DateTime? lastTestedAt, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$ApiKeyCopyWithImpl<$Res>
    implements $ApiKeyCopyWith<$Res> {
  _$ApiKeyCopyWithImpl(this._self, this._then);

  final ApiKey _self;
  final $Res Function(ApiKey) _then;

/// Create a copy of ApiKey
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? provider = null,Object? displayName = null,Object? keyMasked = null,Object? baseUrl = null,Object? apiFormat = null,Object? testStatus = null,Object? testError = null,Object? lastTestedAt = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,keyMasked: null == keyMasked ? _self.keyMasked : keyMasked // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,apiFormat: null == apiFormat ? _self.apiFormat : apiFormat // ignore: cast_nullable_to_non_nullable
as String,testStatus: null == testStatus ? _self.testStatus : testStatus // ignore: cast_nullable_to_non_nullable
as String,testError: null == testError ? _self.testError : testError // ignore: cast_nullable_to_non_nullable
as String,lastTestedAt: freezed == lastTestedAt ? _self.lastTestedAt : lastTestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [ApiKey].
extension ApiKeyPatterns on ApiKey {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApiKey value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApiKey() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApiKey value)  $default,){
final _that = this;
switch (_that) {
case _ApiKey():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApiKey value)?  $default,){
final _that = this;
switch (_that) {
case _ApiKey() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String provider,  String displayName,  String keyMasked,  String baseUrl,  String apiFormat,  String testStatus,  String testError,  DateTime? lastTestedAt,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApiKey() when $default != null:
return $default(_that.id,_that.provider,_that.displayName,_that.keyMasked,_that.baseUrl,_that.apiFormat,_that.testStatus,_that.testError,_that.lastTestedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String provider,  String displayName,  String keyMasked,  String baseUrl,  String apiFormat,  String testStatus,  String testError,  DateTime? lastTestedAt,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ApiKey():
return $default(_that.id,_that.provider,_that.displayName,_that.keyMasked,_that.baseUrl,_that.apiFormat,_that.testStatus,_that.testError,_that.lastTestedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String provider,  String displayName,  String keyMasked,  String baseUrl,  String apiFormat,  String testStatus,  String testError,  DateTime? lastTestedAt,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ApiKey() when $default != null:
return $default(_that.id,_that.provider,_that.displayName,_that.keyMasked,_that.baseUrl,_that.apiFormat,_that.testStatus,_that.testError,_that.lastTestedAt,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApiKey implements ApiKey {
  const _ApiKey({required this.id, required this.provider, required this.displayName, this.keyMasked = '', this.baseUrl = '', this.apiFormat = '', this.testStatus = 'pending', this.testError = '', this.lastTestedAt, required this.createdAt, required this.updatedAt});
  factory _ApiKey.fromJson(Map<String, dynamic> json) => _$ApiKeyFromJson(json);

@override final  String id;
@override final  String provider;
@override final  String displayName;
@override@JsonKey() final  String keyMasked;
@override@JsonKey() final  String baseUrl;
@override@JsonKey() final  String apiFormat;
@override@JsonKey() final  String testStatus;
@override@JsonKey() final  String testError;
@override final  DateTime? lastTestedAt;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of ApiKey
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApiKeyCopyWith<_ApiKey> get copyWith => __$ApiKeyCopyWithImpl<_ApiKey>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApiKeyToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApiKey&&(identical(other.id, id) || other.id == id)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.keyMasked, keyMasked) || other.keyMasked == keyMasked)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.apiFormat, apiFormat) || other.apiFormat == apiFormat)&&(identical(other.testStatus, testStatus) || other.testStatus == testStatus)&&(identical(other.testError, testError) || other.testError == testError)&&(identical(other.lastTestedAt, lastTestedAt) || other.lastTestedAt == lastTestedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,provider,displayName,keyMasked,baseUrl,apiFormat,testStatus,testError,lastTestedAt,createdAt,updatedAt);

@override
String toString() {
  return 'ApiKey(id: $id, provider: $provider, displayName: $displayName, keyMasked: $keyMasked, baseUrl: $baseUrl, apiFormat: $apiFormat, testStatus: $testStatus, testError: $testError, lastTestedAt: $lastTestedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ApiKeyCopyWith<$Res> implements $ApiKeyCopyWith<$Res> {
  factory _$ApiKeyCopyWith(_ApiKey value, $Res Function(_ApiKey) _then) = __$ApiKeyCopyWithImpl;
@override @useResult
$Res call({
 String id, String provider, String displayName, String keyMasked, String baseUrl, String apiFormat, String testStatus, String testError, DateTime? lastTestedAt, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$ApiKeyCopyWithImpl<$Res>
    implements _$ApiKeyCopyWith<$Res> {
  __$ApiKeyCopyWithImpl(this._self, this._then);

  final _ApiKey _self;
  final $Res Function(_ApiKey) _then;

/// Create a copy of ApiKey
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? provider = null,Object? displayName = null,Object? keyMasked = null,Object? baseUrl = null,Object? apiFormat = null,Object? testStatus = null,Object? testError = null,Object? lastTestedAt = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_ApiKey(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,keyMasked: null == keyMasked ? _self.keyMasked : keyMasked // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,apiFormat: null == apiFormat ? _self.apiFormat : apiFormat // ignore: cast_nullable_to_non_nullable
as String,testStatus: null == testStatus ? _self.testStatus : testStatus // ignore: cast_nullable_to_non_nullable
as String,testError: null == testError ? _self.testError : testError // ignore: cast_nullable_to_non_nullable
as String,lastTestedAt: freezed == lastTestedAt ? _self.lastTestedAt : lastTestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$ProviderMeta {

 String get name; String get displayName; String get defaultBaseUrl; bool get baseUrlRequired; bool get managed; String get category;
/// Create a copy of ProviderMeta
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderMetaCopyWith<ProviderMeta> get copyWith => _$ProviderMetaCopyWithImpl<ProviderMeta>(this as ProviderMeta, _$identity);

  /// Serializes this ProviderMeta to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderMeta&&(identical(other.name, name) || other.name == name)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.defaultBaseUrl, defaultBaseUrl) || other.defaultBaseUrl == defaultBaseUrl)&&(identical(other.baseUrlRequired, baseUrlRequired) || other.baseUrlRequired == baseUrlRequired)&&(identical(other.managed, managed) || other.managed == managed)&&(identical(other.category, category) || other.category == category));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,displayName,defaultBaseUrl,baseUrlRequired,managed,category);

@override
String toString() {
  return 'ProviderMeta(name: $name, displayName: $displayName, defaultBaseUrl: $defaultBaseUrl, baseUrlRequired: $baseUrlRequired, managed: $managed, category: $category)';
}


}

/// @nodoc
abstract mixin class $ProviderMetaCopyWith<$Res>  {
  factory $ProviderMetaCopyWith(ProviderMeta value, $Res Function(ProviderMeta) _then) = _$ProviderMetaCopyWithImpl;
@useResult
$Res call({
 String name, String displayName, String defaultBaseUrl, bool baseUrlRequired, bool managed, String category
});




}
/// @nodoc
class _$ProviderMetaCopyWithImpl<$Res>
    implements $ProviderMetaCopyWith<$Res> {
  _$ProviderMetaCopyWithImpl(this._self, this._then);

  final ProviderMeta _self;
  final $Res Function(ProviderMeta) _then;

/// Create a copy of ProviderMeta
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? displayName = null,Object? defaultBaseUrl = null,Object? baseUrlRequired = null,Object? managed = null,Object? category = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,defaultBaseUrl: null == defaultBaseUrl ? _self.defaultBaseUrl : defaultBaseUrl // ignore: cast_nullable_to_non_nullable
as String,baseUrlRequired: null == baseUrlRequired ? _self.baseUrlRequired : baseUrlRequired // ignore: cast_nullable_to_non_nullable
as bool,managed: null == managed ? _self.managed : managed // ignore: cast_nullable_to_non_nullable
as bool,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ProviderMeta].
extension ProviderMetaPatterns on ProviderMeta {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderMeta value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderMeta() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderMeta value)  $default,){
final _that = this;
switch (_that) {
case _ProviderMeta():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderMeta value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderMeta() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String displayName,  String defaultBaseUrl,  bool baseUrlRequired,  bool managed,  String category)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderMeta() when $default != null:
return $default(_that.name,_that.displayName,_that.defaultBaseUrl,_that.baseUrlRequired,_that.managed,_that.category);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String displayName,  String defaultBaseUrl,  bool baseUrlRequired,  bool managed,  String category)  $default,) {final _that = this;
switch (_that) {
case _ProviderMeta():
return $default(_that.name,_that.displayName,_that.defaultBaseUrl,_that.baseUrlRequired,_that.managed,_that.category);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String displayName,  String defaultBaseUrl,  bool baseUrlRequired,  bool managed,  String category)?  $default,) {final _that = this;
switch (_that) {
case _ProviderMeta() when $default != null:
return $default(_that.name,_that.displayName,_that.defaultBaseUrl,_that.baseUrlRequired,_that.managed,_that.category);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderMeta implements ProviderMeta {
  const _ProviderMeta({required this.name, required this.displayName, this.defaultBaseUrl = '', this.baseUrlRequired = false, this.managed = false, this.category = 'llm'});
  factory _ProviderMeta.fromJson(Map<String, dynamic> json) => _$ProviderMetaFromJson(json);

@override final  String name;
@override final  String displayName;
@override@JsonKey() final  String defaultBaseUrl;
@override@JsonKey() final  bool baseUrlRequired;
@override@JsonKey() final  bool managed;
@override@JsonKey() final  String category;

/// Create a copy of ProviderMeta
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderMetaCopyWith<_ProviderMeta> get copyWith => __$ProviderMetaCopyWithImpl<_ProviderMeta>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderMetaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderMeta&&(identical(other.name, name) || other.name == name)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.defaultBaseUrl, defaultBaseUrl) || other.defaultBaseUrl == defaultBaseUrl)&&(identical(other.baseUrlRequired, baseUrlRequired) || other.baseUrlRequired == baseUrlRequired)&&(identical(other.managed, managed) || other.managed == managed)&&(identical(other.category, category) || other.category == category));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,displayName,defaultBaseUrl,baseUrlRequired,managed,category);

@override
String toString() {
  return 'ProviderMeta(name: $name, displayName: $displayName, defaultBaseUrl: $defaultBaseUrl, baseUrlRequired: $baseUrlRequired, managed: $managed, category: $category)';
}


}

/// @nodoc
abstract mixin class _$ProviderMetaCopyWith<$Res> implements $ProviderMetaCopyWith<$Res> {
  factory _$ProviderMetaCopyWith(_ProviderMeta value, $Res Function(_ProviderMeta) _then) = __$ProviderMetaCopyWithImpl;
@override @useResult
$Res call({
 String name, String displayName, String defaultBaseUrl, bool baseUrlRequired, bool managed, String category
});




}
/// @nodoc
class __$ProviderMetaCopyWithImpl<$Res>
    implements _$ProviderMetaCopyWith<$Res> {
  __$ProviderMetaCopyWithImpl(this._self, this._then);

  final _ProviderMeta _self;
  final $Res Function(_ProviderMeta) _then;

/// Create a copy of ProviderMeta
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? displayName = null,Object? defaultBaseUrl = null,Object? baseUrlRequired = null,Object? managed = null,Object? category = null,}) {
  return _then(_ProviderMeta(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,defaultBaseUrl: null == defaultBaseUrl ? _self.defaultBaseUrl : defaultBaseUrl // ignore: cast_nullable_to_non_nullable
as String,baseUrlRequired: null == baseUrlRequired ? _self.baseUrlRequired : baseUrlRequired // ignore: cast_nullable_to_non_nullable
as bool,managed: null == managed ? _self.managed : managed // ignore: cast_nullable_to_non_nullable
as bool,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$FreetierQuota {

 int get limit; int get used; int get remaining; String get resetAt; bool get available;
/// Create a copy of FreetierQuota
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FreetierQuotaCopyWith<FreetierQuota> get copyWith => _$FreetierQuotaCopyWithImpl<FreetierQuota>(this as FreetierQuota, _$identity);

  /// Serializes this FreetierQuota to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FreetierQuota&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.used, used) || other.used == used)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.resetAt, resetAt) || other.resetAt == resetAt)&&(identical(other.available, available) || other.available == available));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,limit,used,remaining,resetAt,available);

@override
String toString() {
  return 'FreetierQuota(limit: $limit, used: $used, remaining: $remaining, resetAt: $resetAt, available: $available)';
}


}

/// @nodoc
abstract mixin class $FreetierQuotaCopyWith<$Res>  {
  factory $FreetierQuotaCopyWith(FreetierQuota value, $Res Function(FreetierQuota) _then) = _$FreetierQuotaCopyWithImpl;
@useResult
$Res call({
 int limit, int used, int remaining, String resetAt, bool available
});




}
/// @nodoc
class _$FreetierQuotaCopyWithImpl<$Res>
    implements $FreetierQuotaCopyWith<$Res> {
  _$FreetierQuotaCopyWithImpl(this._self, this._then);

  final FreetierQuota _self;
  final $Res Function(FreetierQuota) _then;

/// Create a copy of FreetierQuota
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? limit = null,Object? used = null,Object? remaining = null,Object? resetAt = null,Object? available = null,}) {
  return _then(_self.copyWith(
limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,used: null == used ? _self.used : used // ignore: cast_nullable_to_non_nullable
as int,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,resetAt: null == resetAt ? _self.resetAt : resetAt // ignore: cast_nullable_to_non_nullable
as String,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [FreetierQuota].
extension FreetierQuotaPatterns on FreetierQuota {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FreetierQuota value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FreetierQuota() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FreetierQuota value)  $default,){
final _that = this;
switch (_that) {
case _FreetierQuota():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FreetierQuota value)?  $default,){
final _that = this;
switch (_that) {
case _FreetierQuota() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int limit,  int used,  int remaining,  String resetAt,  bool available)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FreetierQuota() when $default != null:
return $default(_that.limit,_that.used,_that.remaining,_that.resetAt,_that.available);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int limit,  int used,  int remaining,  String resetAt,  bool available)  $default,) {final _that = this;
switch (_that) {
case _FreetierQuota():
return $default(_that.limit,_that.used,_that.remaining,_that.resetAt,_that.available);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int limit,  int used,  int remaining,  String resetAt,  bool available)?  $default,) {final _that = this;
switch (_that) {
case _FreetierQuota() when $default != null:
return $default(_that.limit,_that.used,_that.remaining,_that.resetAt,_that.available);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FreetierQuota implements FreetierQuota {
  const _FreetierQuota({required this.limit, required this.used, required this.remaining, this.resetAt = '', this.available = true});
  factory _FreetierQuota.fromJson(Map<String, dynamic> json) => _$FreetierQuotaFromJson(json);

@override final  int limit;
@override final  int used;
@override final  int remaining;
@override@JsonKey() final  String resetAt;
@override@JsonKey() final  bool available;

/// Create a copy of FreetierQuota
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FreetierQuotaCopyWith<_FreetierQuota> get copyWith => __$FreetierQuotaCopyWithImpl<_FreetierQuota>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FreetierQuotaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FreetierQuota&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.used, used) || other.used == used)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.resetAt, resetAt) || other.resetAt == resetAt)&&(identical(other.available, available) || other.available == available));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,limit,used,remaining,resetAt,available);

@override
String toString() {
  return 'FreetierQuota(limit: $limit, used: $used, remaining: $remaining, resetAt: $resetAt, available: $available)';
}


}

/// @nodoc
abstract mixin class _$FreetierQuotaCopyWith<$Res> implements $FreetierQuotaCopyWith<$Res> {
  factory _$FreetierQuotaCopyWith(_FreetierQuota value, $Res Function(_FreetierQuota) _then) = __$FreetierQuotaCopyWithImpl;
@override @useResult
$Res call({
 int limit, int used, int remaining, String resetAt, bool available
});




}
/// @nodoc
class __$FreetierQuotaCopyWithImpl<$Res>
    implements _$FreetierQuotaCopyWith<$Res> {
  __$FreetierQuotaCopyWithImpl(this._self, this._then);

  final _FreetierQuota _self;
  final $Res Function(_FreetierQuota) _then;

/// Create a copy of FreetierQuota
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? limit = null,Object? used = null,Object? remaining = null,Object? resetAt = null,Object? available = null,}) {
  return _then(_FreetierQuota(
limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,used: null == used ? _self.used : used // ignore: cast_nullable_to_non_nullable
as int,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,resetAt: null == resetAt ? _self.resetAt : resetAt // ignore: cast_nullable_to_non_nullable
as String,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
