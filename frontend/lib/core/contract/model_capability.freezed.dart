// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'model_capability.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ModelKnob {

 String get key; String get label; String get type; List<String> get values;@JsonKey(name: 'default') String get defaultValue;
/// Create a copy of ModelKnob
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModelKnobCopyWith<ModelKnob> get copyWith => _$ModelKnobCopyWithImpl<ModelKnob>(this as ModelKnob, _$identity);

  /// Serializes this ModelKnob to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModelKnob&&(identical(other.key, key) || other.key == key)&&(identical(other.label, label) || other.label == label)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.values, values)&&(identical(other.defaultValue, defaultValue) || other.defaultValue == defaultValue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,label,type,const DeepCollectionEquality().hash(values),defaultValue);

@override
String toString() {
  return 'ModelKnob(key: $key, label: $label, type: $type, values: $values, defaultValue: $defaultValue)';
}


}

/// @nodoc
abstract mixin class $ModelKnobCopyWith<$Res>  {
  factory $ModelKnobCopyWith(ModelKnob value, $Res Function(ModelKnob) _then) = _$ModelKnobCopyWithImpl;
@useResult
$Res call({
 String key, String label, String type, List<String> values,@JsonKey(name: 'default') String defaultValue
});




}
/// @nodoc
class _$ModelKnobCopyWithImpl<$Res>
    implements $ModelKnobCopyWith<$Res> {
  _$ModelKnobCopyWithImpl(this._self, this._then);

  final ModelKnob _self;
  final $Res Function(ModelKnob) _then;

/// Create a copy of ModelKnob
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? label = null,Object? type = null,Object? values = null,Object? defaultValue = null,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,values: null == values ? _self.values : values // ignore: cast_nullable_to_non_nullable
as List<String>,defaultValue: null == defaultValue ? _self.defaultValue : defaultValue // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ModelKnob].
extension ModelKnobPatterns on ModelKnob {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ModelKnob value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ModelKnob() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ModelKnob value)  $default,){
final _that = this;
switch (_that) {
case _ModelKnob():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ModelKnob value)?  $default,){
final _that = this;
switch (_that) {
case _ModelKnob() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  String label,  String type,  List<String> values, @JsonKey(name: 'default')  String defaultValue)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ModelKnob() when $default != null:
return $default(_that.key,_that.label,_that.type,_that.values,_that.defaultValue);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  String label,  String type,  List<String> values, @JsonKey(name: 'default')  String defaultValue)  $default,) {final _that = this;
switch (_that) {
case _ModelKnob():
return $default(_that.key,_that.label,_that.type,_that.values,_that.defaultValue);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  String label,  String type,  List<String> values, @JsonKey(name: 'default')  String defaultValue)?  $default,) {final _that = this;
switch (_that) {
case _ModelKnob() when $default != null:
return $default(_that.key,_that.label,_that.type,_that.values,_that.defaultValue);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ModelKnob implements ModelKnob {
  const _ModelKnob({required this.key, this.label = '', this.type = '', final  List<String> values = const <String>[], @JsonKey(name: 'default') this.defaultValue = ''}): _values = values;
  factory _ModelKnob.fromJson(Map<String, dynamic> json) => _$ModelKnobFromJson(json);

@override final  String key;
@override@JsonKey() final  String label;
@override@JsonKey() final  String type;
 final  List<String> _values;
@override@JsonKey() List<String> get values {
  if (_values is EqualUnmodifiableListView) return _values;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_values);
}

@override@JsonKey(name: 'default') final  String defaultValue;

/// Create a copy of ModelKnob
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModelKnobCopyWith<_ModelKnob> get copyWith => __$ModelKnobCopyWithImpl<_ModelKnob>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ModelKnobToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModelKnob&&(identical(other.key, key) || other.key == key)&&(identical(other.label, label) || other.label == label)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other._values, _values)&&(identical(other.defaultValue, defaultValue) || other.defaultValue == defaultValue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,label,type,const DeepCollectionEquality().hash(_values),defaultValue);

@override
String toString() {
  return 'ModelKnob(key: $key, label: $label, type: $type, values: $values, defaultValue: $defaultValue)';
}


}

/// @nodoc
abstract mixin class _$ModelKnobCopyWith<$Res> implements $ModelKnobCopyWith<$Res> {
  factory _$ModelKnobCopyWith(_ModelKnob value, $Res Function(_ModelKnob) _then) = __$ModelKnobCopyWithImpl;
@override @useResult
$Res call({
 String key, String label, String type, List<String> values,@JsonKey(name: 'default') String defaultValue
});




}
/// @nodoc
class __$ModelKnobCopyWithImpl<$Res>
    implements _$ModelKnobCopyWith<$Res> {
  __$ModelKnobCopyWithImpl(this._self, this._then);

  final _ModelKnob _self;
  final $Res Function(_ModelKnob) _then;

/// Create a copy of ModelKnob
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? label = null,Object? type = null,Object? values = null,Object? defaultValue = null,}) {
  return _then(_ModelKnob(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,values: null == values ? _self._values : values // ignore: cast_nullable_to_non_nullable
as List<String>,defaultValue: null == defaultValue ? _self.defaultValue : defaultValue // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ModelCapability {

 String get apiKeyId; String get keyName; String get provider; String get modelId; String get displayName; int get contextWindow; int get maxOutput; int get textInputLimit; int get multimodalInputLimit; bool get vision; bool get video; bool get audio; bool get nativeDocs; int get maxMediaParts; int get maxMediaBytes; List<ModelKnob> get knobs;
/// Create a copy of ModelCapability
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModelCapabilityCopyWith<ModelCapability> get copyWith => _$ModelCapabilityCopyWithImpl<ModelCapability>(this as ModelCapability, _$identity);

  /// Serializes this ModelCapability to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModelCapability&&(identical(other.apiKeyId, apiKeyId) || other.apiKeyId == apiKeyId)&&(identical(other.keyName, keyName) || other.keyName == keyName)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.contextWindow, contextWindow) || other.contextWindow == contextWindow)&&(identical(other.maxOutput, maxOutput) || other.maxOutput == maxOutput)&&(identical(other.textInputLimit, textInputLimit) || other.textInputLimit == textInputLimit)&&(identical(other.multimodalInputLimit, multimodalInputLimit) || other.multimodalInputLimit == multimodalInputLimit)&&(identical(other.vision, vision) || other.vision == vision)&&(identical(other.video, video) || other.video == video)&&(identical(other.audio, audio) || other.audio == audio)&&(identical(other.nativeDocs, nativeDocs) || other.nativeDocs == nativeDocs)&&(identical(other.maxMediaParts, maxMediaParts) || other.maxMediaParts == maxMediaParts)&&(identical(other.maxMediaBytes, maxMediaBytes) || other.maxMediaBytes == maxMediaBytes)&&const DeepCollectionEquality().equals(other.knobs, knobs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,apiKeyId,keyName,provider,modelId,displayName,contextWindow,maxOutput,textInputLimit,multimodalInputLimit,vision,video,audio,nativeDocs,maxMediaParts,maxMediaBytes,const DeepCollectionEquality().hash(knobs));

@override
String toString() {
  return 'ModelCapability(apiKeyId: $apiKeyId, keyName: $keyName, provider: $provider, modelId: $modelId, displayName: $displayName, contextWindow: $contextWindow, maxOutput: $maxOutput, textInputLimit: $textInputLimit, multimodalInputLimit: $multimodalInputLimit, vision: $vision, video: $video, audio: $audio, nativeDocs: $nativeDocs, maxMediaParts: $maxMediaParts, maxMediaBytes: $maxMediaBytes, knobs: $knobs)';
}


}

/// @nodoc
abstract mixin class $ModelCapabilityCopyWith<$Res>  {
  factory $ModelCapabilityCopyWith(ModelCapability value, $Res Function(ModelCapability) _then) = _$ModelCapabilityCopyWithImpl;
@useResult
$Res call({
 String apiKeyId, String keyName, String provider, String modelId, String displayName, int contextWindow, int maxOutput, int textInputLimit, int multimodalInputLimit, bool vision, bool video, bool audio, bool nativeDocs, int maxMediaParts, int maxMediaBytes, List<ModelKnob> knobs
});




}
/// @nodoc
class _$ModelCapabilityCopyWithImpl<$Res>
    implements $ModelCapabilityCopyWith<$Res> {
  _$ModelCapabilityCopyWithImpl(this._self, this._then);

  final ModelCapability _self;
  final $Res Function(ModelCapability) _then;

/// Create a copy of ModelCapability
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? apiKeyId = null,Object? keyName = null,Object? provider = null,Object? modelId = null,Object? displayName = null,Object? contextWindow = null,Object? maxOutput = null,Object? textInputLimit = null,Object? multimodalInputLimit = null,Object? vision = null,Object? video = null,Object? audio = null,Object? nativeDocs = null,Object? maxMediaParts = null,Object? maxMediaBytes = null,Object? knobs = null,}) {
  return _then(_self.copyWith(
apiKeyId: null == apiKeyId ? _self.apiKeyId : apiKeyId // ignore: cast_nullable_to_non_nullable
as String,keyName: null == keyName ? _self.keyName : keyName // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,contextWindow: null == contextWindow ? _self.contextWindow : contextWindow // ignore: cast_nullable_to_non_nullable
as int,maxOutput: null == maxOutput ? _self.maxOutput : maxOutput // ignore: cast_nullable_to_non_nullable
as int,textInputLimit: null == textInputLimit ? _self.textInputLimit : textInputLimit // ignore: cast_nullable_to_non_nullable
as int,multimodalInputLimit: null == multimodalInputLimit ? _self.multimodalInputLimit : multimodalInputLimit // ignore: cast_nullable_to_non_nullable
as int,vision: null == vision ? _self.vision : vision // ignore: cast_nullable_to_non_nullable
as bool,video: null == video ? _self.video : video // ignore: cast_nullable_to_non_nullable
as bool,audio: null == audio ? _self.audio : audio // ignore: cast_nullable_to_non_nullable
as bool,nativeDocs: null == nativeDocs ? _self.nativeDocs : nativeDocs // ignore: cast_nullable_to_non_nullable
as bool,maxMediaParts: null == maxMediaParts ? _self.maxMediaParts : maxMediaParts // ignore: cast_nullable_to_non_nullable
as int,maxMediaBytes: null == maxMediaBytes ? _self.maxMediaBytes : maxMediaBytes // ignore: cast_nullable_to_non_nullable
as int,knobs: null == knobs ? _self.knobs : knobs // ignore: cast_nullable_to_non_nullable
as List<ModelKnob>,
  ));
}

}


/// Adds pattern-matching-related methods to [ModelCapability].
extension ModelCapabilityPatterns on ModelCapability {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ModelCapability value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ModelCapability() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ModelCapability value)  $default,){
final _that = this;
switch (_that) {
case _ModelCapability():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ModelCapability value)?  $default,){
final _that = this;
switch (_that) {
case _ModelCapability() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String apiKeyId,  String keyName,  String provider,  String modelId,  String displayName,  int contextWindow,  int maxOutput,  int textInputLimit,  int multimodalInputLimit,  bool vision,  bool video,  bool audio,  bool nativeDocs,  int maxMediaParts,  int maxMediaBytes,  List<ModelKnob> knobs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ModelCapability() when $default != null:
return $default(_that.apiKeyId,_that.keyName,_that.provider,_that.modelId,_that.displayName,_that.contextWindow,_that.maxOutput,_that.textInputLimit,_that.multimodalInputLimit,_that.vision,_that.video,_that.audio,_that.nativeDocs,_that.maxMediaParts,_that.maxMediaBytes,_that.knobs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String apiKeyId,  String keyName,  String provider,  String modelId,  String displayName,  int contextWindow,  int maxOutput,  int textInputLimit,  int multimodalInputLimit,  bool vision,  bool video,  bool audio,  bool nativeDocs,  int maxMediaParts,  int maxMediaBytes,  List<ModelKnob> knobs)  $default,) {final _that = this;
switch (_that) {
case _ModelCapability():
return $default(_that.apiKeyId,_that.keyName,_that.provider,_that.modelId,_that.displayName,_that.contextWindow,_that.maxOutput,_that.textInputLimit,_that.multimodalInputLimit,_that.vision,_that.video,_that.audio,_that.nativeDocs,_that.maxMediaParts,_that.maxMediaBytes,_that.knobs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String apiKeyId,  String keyName,  String provider,  String modelId,  String displayName,  int contextWindow,  int maxOutput,  int textInputLimit,  int multimodalInputLimit,  bool vision,  bool video,  bool audio,  bool nativeDocs,  int maxMediaParts,  int maxMediaBytes,  List<ModelKnob> knobs)?  $default,) {final _that = this;
switch (_that) {
case _ModelCapability() when $default != null:
return $default(_that.apiKeyId,_that.keyName,_that.provider,_that.modelId,_that.displayName,_that.contextWindow,_that.maxOutput,_that.textInputLimit,_that.multimodalInputLimit,_that.vision,_that.video,_that.audio,_that.nativeDocs,_that.maxMediaParts,_that.maxMediaBytes,_that.knobs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ModelCapability implements ModelCapability {
  const _ModelCapability({required this.apiKeyId, this.keyName = '', this.provider = '', required this.modelId, this.displayName = '', this.contextWindow = 0, this.maxOutput = 0, this.textInputLimit = 0, this.multimodalInputLimit = 0, this.vision = false, this.video = false, this.audio = false, this.nativeDocs = false, this.maxMediaParts = 0, this.maxMediaBytes = 0, final  List<ModelKnob> knobs = const <ModelKnob>[]}): _knobs = knobs;
  factory _ModelCapability.fromJson(Map<String, dynamic> json) => _$ModelCapabilityFromJson(json);

@override final  String apiKeyId;
@override@JsonKey() final  String keyName;
@override@JsonKey() final  String provider;
@override final  String modelId;
@override@JsonKey() final  String displayName;
@override@JsonKey() final  int contextWindow;
@override@JsonKey() final  int maxOutput;
@override@JsonKey() final  int textInputLimit;
@override@JsonKey() final  int multimodalInputLimit;
@override@JsonKey() final  bool vision;
@override@JsonKey() final  bool video;
@override@JsonKey() final  bool audio;
@override@JsonKey() final  bool nativeDocs;
@override@JsonKey() final  int maxMediaParts;
@override@JsonKey() final  int maxMediaBytes;
 final  List<ModelKnob> _knobs;
@override@JsonKey() List<ModelKnob> get knobs {
  if (_knobs is EqualUnmodifiableListView) return _knobs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_knobs);
}


/// Create a copy of ModelCapability
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModelCapabilityCopyWith<_ModelCapability> get copyWith => __$ModelCapabilityCopyWithImpl<_ModelCapability>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ModelCapabilityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModelCapability&&(identical(other.apiKeyId, apiKeyId) || other.apiKeyId == apiKeyId)&&(identical(other.keyName, keyName) || other.keyName == keyName)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.contextWindow, contextWindow) || other.contextWindow == contextWindow)&&(identical(other.maxOutput, maxOutput) || other.maxOutput == maxOutput)&&(identical(other.textInputLimit, textInputLimit) || other.textInputLimit == textInputLimit)&&(identical(other.multimodalInputLimit, multimodalInputLimit) || other.multimodalInputLimit == multimodalInputLimit)&&(identical(other.vision, vision) || other.vision == vision)&&(identical(other.video, video) || other.video == video)&&(identical(other.audio, audio) || other.audio == audio)&&(identical(other.nativeDocs, nativeDocs) || other.nativeDocs == nativeDocs)&&(identical(other.maxMediaParts, maxMediaParts) || other.maxMediaParts == maxMediaParts)&&(identical(other.maxMediaBytes, maxMediaBytes) || other.maxMediaBytes == maxMediaBytes)&&const DeepCollectionEquality().equals(other._knobs, _knobs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,apiKeyId,keyName,provider,modelId,displayName,contextWindow,maxOutput,textInputLimit,multimodalInputLimit,vision,video,audio,nativeDocs,maxMediaParts,maxMediaBytes,const DeepCollectionEquality().hash(_knobs));

@override
String toString() {
  return 'ModelCapability(apiKeyId: $apiKeyId, keyName: $keyName, provider: $provider, modelId: $modelId, displayName: $displayName, contextWindow: $contextWindow, maxOutput: $maxOutput, textInputLimit: $textInputLimit, multimodalInputLimit: $multimodalInputLimit, vision: $vision, video: $video, audio: $audio, nativeDocs: $nativeDocs, maxMediaParts: $maxMediaParts, maxMediaBytes: $maxMediaBytes, knobs: $knobs)';
}


}

/// @nodoc
abstract mixin class _$ModelCapabilityCopyWith<$Res> implements $ModelCapabilityCopyWith<$Res> {
  factory _$ModelCapabilityCopyWith(_ModelCapability value, $Res Function(_ModelCapability) _then) = __$ModelCapabilityCopyWithImpl;
@override @useResult
$Res call({
 String apiKeyId, String keyName, String provider, String modelId, String displayName, int contextWindow, int maxOutput, int textInputLimit, int multimodalInputLimit, bool vision, bool video, bool audio, bool nativeDocs, int maxMediaParts, int maxMediaBytes, List<ModelKnob> knobs
});




}
/// @nodoc
class __$ModelCapabilityCopyWithImpl<$Res>
    implements _$ModelCapabilityCopyWith<$Res> {
  __$ModelCapabilityCopyWithImpl(this._self, this._then);

  final _ModelCapability _self;
  final $Res Function(_ModelCapability) _then;

/// Create a copy of ModelCapability
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? apiKeyId = null,Object? keyName = null,Object? provider = null,Object? modelId = null,Object? displayName = null,Object? contextWindow = null,Object? maxOutput = null,Object? textInputLimit = null,Object? multimodalInputLimit = null,Object? vision = null,Object? video = null,Object? audio = null,Object? nativeDocs = null,Object? maxMediaParts = null,Object? maxMediaBytes = null,Object? knobs = null,}) {
  return _then(_ModelCapability(
apiKeyId: null == apiKeyId ? _self.apiKeyId : apiKeyId // ignore: cast_nullable_to_non_nullable
as String,keyName: null == keyName ? _self.keyName : keyName // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,contextWindow: null == contextWindow ? _self.contextWindow : contextWindow // ignore: cast_nullable_to_non_nullable
as int,maxOutput: null == maxOutput ? _self.maxOutput : maxOutput // ignore: cast_nullable_to_non_nullable
as int,textInputLimit: null == textInputLimit ? _self.textInputLimit : textInputLimit // ignore: cast_nullable_to_non_nullable
as int,multimodalInputLimit: null == multimodalInputLimit ? _self.multimodalInputLimit : multimodalInputLimit // ignore: cast_nullable_to_non_nullable
as int,vision: null == vision ? _self.vision : vision // ignore: cast_nullable_to_non_nullable
as bool,video: null == video ? _self.video : video // ignore: cast_nullable_to_non_nullable
as bool,audio: null == audio ? _self.audio : audio // ignore: cast_nullable_to_non_nullable
as bool,nativeDocs: null == nativeDocs ? _self.nativeDocs : nativeDocs // ignore: cast_nullable_to_non_nullable
as bool,maxMediaParts: null == maxMediaParts ? _self.maxMediaParts : maxMediaParts // ignore: cast_nullable_to_non_nullable
as int,maxMediaBytes: null == maxMediaBytes ? _self.maxMediaBytes : maxMediaBytes // ignore: cast_nullable_to_non_nullable
as int,knobs: null == knobs ? _self._knobs : knobs // ignore: cast_nullable_to_non_nullable
as List<ModelKnob>,
  ));
}


}

// dart format on
