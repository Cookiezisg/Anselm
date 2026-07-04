// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trigger.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TriggerEntity {

 String get id; String get name; String get description;@JsonKey(unknownEnumValue: TriggerSource.unknown) TriggerSource get kind; Map<String, dynamic> get config; List<Field> get outputs; DateTime get createdAt; DateTime get updatedAt; int get refCount; bool get listening; DateTime? get lastFiredAt; DateTime? get nextFireAt;
/// Create a copy of TriggerEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TriggerEntityCopyWith<TriggerEntity> get copyWith => _$TriggerEntityCopyWithImpl<TriggerEntity>(this as TriggerEntity, _$identity);

  /// Serializes this TriggerEntity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TriggerEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.kind, kind) || other.kind == kind)&&const DeepCollectionEquality().equals(other.config, config)&&const DeepCollectionEquality().equals(other.outputs, outputs)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.refCount, refCount) || other.refCount == refCount)&&(identical(other.listening, listening) || other.listening == listening)&&(identical(other.lastFiredAt, lastFiredAt) || other.lastFiredAt == lastFiredAt)&&(identical(other.nextFireAt, nextFireAt) || other.nextFireAt == nextFireAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,kind,const DeepCollectionEquality().hash(config),const DeepCollectionEquality().hash(outputs),createdAt,updatedAt,refCount,listening,lastFiredAt,nextFireAt);

@override
String toString() {
  return 'TriggerEntity(id: $id, name: $name, description: $description, kind: $kind, config: $config, outputs: $outputs, createdAt: $createdAt, updatedAt: $updatedAt, refCount: $refCount, listening: $listening, lastFiredAt: $lastFiredAt, nextFireAt: $nextFireAt)';
}


}

/// @nodoc
abstract mixin class $TriggerEntityCopyWith<$Res>  {
  factory $TriggerEntityCopyWith(TriggerEntity value, $Res Function(TriggerEntity) _then) = _$TriggerEntityCopyWithImpl;
@useResult
$Res call({
 String id, String name, String description,@JsonKey(unknownEnumValue: TriggerSource.unknown) TriggerSource kind, Map<String, dynamic> config, List<Field> outputs, DateTime createdAt, DateTime updatedAt, int refCount, bool listening, DateTime? lastFiredAt, DateTime? nextFireAt
});




}
/// @nodoc
class _$TriggerEntityCopyWithImpl<$Res>
    implements $TriggerEntityCopyWith<$Res> {
  _$TriggerEntityCopyWithImpl(this._self, this._then);

  final TriggerEntity _self;
  final $Res Function(TriggerEntity) _then;

/// Create a copy of TriggerEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = null,Object? kind = null,Object? config = null,Object? outputs = null,Object? createdAt = null,Object? updatedAt = null,Object? refCount = null,Object? listening = null,Object? lastFiredAt = freezed,Object? nextFireAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as TriggerSource,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,outputs: null == outputs ? _self.outputs : outputs // ignore: cast_nullable_to_non_nullable
as List<Field>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,refCount: null == refCount ? _self.refCount : refCount // ignore: cast_nullable_to_non_nullable
as int,listening: null == listening ? _self.listening : listening // ignore: cast_nullable_to_non_nullable
as bool,lastFiredAt: freezed == lastFiredAt ? _self.lastFiredAt : lastFiredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,nextFireAt: freezed == nextFireAt ? _self.nextFireAt : nextFireAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [TriggerEntity].
extension TriggerEntityPatterns on TriggerEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TriggerEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TriggerEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TriggerEntity value)  $default,){
final _that = this;
switch (_that) {
case _TriggerEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TriggerEntity value)?  $default,){
final _that = this;
switch (_that) {
case _TriggerEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String description, @JsonKey(unknownEnumValue: TriggerSource.unknown)  TriggerSource kind,  Map<String, dynamic> config,  List<Field> outputs,  DateTime createdAt,  DateTime updatedAt,  int refCount,  bool listening,  DateTime? lastFiredAt,  DateTime? nextFireAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TriggerEntity() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.kind,_that.config,_that.outputs,_that.createdAt,_that.updatedAt,_that.refCount,_that.listening,_that.lastFiredAt,_that.nextFireAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String description, @JsonKey(unknownEnumValue: TriggerSource.unknown)  TriggerSource kind,  Map<String, dynamic> config,  List<Field> outputs,  DateTime createdAt,  DateTime updatedAt,  int refCount,  bool listening,  DateTime? lastFiredAt,  DateTime? nextFireAt)  $default,) {final _that = this;
switch (_that) {
case _TriggerEntity():
return $default(_that.id,_that.name,_that.description,_that.kind,_that.config,_that.outputs,_that.createdAt,_that.updatedAt,_that.refCount,_that.listening,_that.lastFiredAt,_that.nextFireAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String description, @JsonKey(unknownEnumValue: TriggerSource.unknown)  TriggerSource kind,  Map<String, dynamic> config,  List<Field> outputs,  DateTime createdAt,  DateTime updatedAt,  int refCount,  bool listening,  DateTime? lastFiredAt,  DateTime? nextFireAt)?  $default,) {final _that = this;
switch (_that) {
case _TriggerEntity() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.kind,_that.config,_that.outputs,_that.createdAt,_that.updatedAt,_that.refCount,_that.listening,_that.lastFiredAt,_that.nextFireAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TriggerEntity implements TriggerEntity {
  const _TriggerEntity({required this.id, this.name = '', this.description = '', @JsonKey(unknownEnumValue: TriggerSource.unknown) this.kind = TriggerSource.unknown, final  Map<String, dynamic> config = const <String, dynamic>{}, final  List<Field> outputs = const <Field>[], required this.createdAt, required this.updatedAt, this.refCount = 0, this.listening = false, this.lastFiredAt, this.nextFireAt}): _config = config,_outputs = outputs;
  factory _TriggerEntity.fromJson(Map<String, dynamic> json) => _$TriggerEntityFromJson(json);

@override final  String id;
@override@JsonKey() final  String name;
@override@JsonKey() final  String description;
@override@JsonKey(unknownEnumValue: TriggerSource.unknown) final  TriggerSource kind;
 final  Map<String, dynamic> _config;
@override@JsonKey() Map<String, dynamic> get config {
  if (_config is EqualUnmodifiableMapView) return _config;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_config);
}

 final  List<Field> _outputs;
@override@JsonKey() List<Field> get outputs {
  if (_outputs is EqualUnmodifiableListView) return _outputs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_outputs);
}

@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override@JsonKey() final  int refCount;
@override@JsonKey() final  bool listening;
@override final  DateTime? lastFiredAt;
@override final  DateTime? nextFireAt;

/// Create a copy of TriggerEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TriggerEntityCopyWith<_TriggerEntity> get copyWith => __$TriggerEntityCopyWithImpl<_TriggerEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TriggerEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TriggerEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.kind, kind) || other.kind == kind)&&const DeepCollectionEquality().equals(other._config, _config)&&const DeepCollectionEquality().equals(other._outputs, _outputs)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.refCount, refCount) || other.refCount == refCount)&&(identical(other.listening, listening) || other.listening == listening)&&(identical(other.lastFiredAt, lastFiredAt) || other.lastFiredAt == lastFiredAt)&&(identical(other.nextFireAt, nextFireAt) || other.nextFireAt == nextFireAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,kind,const DeepCollectionEquality().hash(_config),const DeepCollectionEquality().hash(_outputs),createdAt,updatedAt,refCount,listening,lastFiredAt,nextFireAt);

@override
String toString() {
  return 'TriggerEntity(id: $id, name: $name, description: $description, kind: $kind, config: $config, outputs: $outputs, createdAt: $createdAt, updatedAt: $updatedAt, refCount: $refCount, listening: $listening, lastFiredAt: $lastFiredAt, nextFireAt: $nextFireAt)';
}


}

/// @nodoc
abstract mixin class _$TriggerEntityCopyWith<$Res> implements $TriggerEntityCopyWith<$Res> {
  factory _$TriggerEntityCopyWith(_TriggerEntity value, $Res Function(_TriggerEntity) _then) = __$TriggerEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String description,@JsonKey(unknownEnumValue: TriggerSource.unknown) TriggerSource kind, Map<String, dynamic> config, List<Field> outputs, DateTime createdAt, DateTime updatedAt, int refCount, bool listening, DateTime? lastFiredAt, DateTime? nextFireAt
});




}
/// @nodoc
class __$TriggerEntityCopyWithImpl<$Res>
    implements _$TriggerEntityCopyWith<$Res> {
  __$TriggerEntityCopyWithImpl(this._self, this._then);

  final _TriggerEntity _self;
  final $Res Function(_TriggerEntity) _then;

/// Create a copy of TriggerEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = null,Object? kind = null,Object? config = null,Object? outputs = null,Object? createdAt = null,Object? updatedAt = null,Object? refCount = null,Object? listening = null,Object? lastFiredAt = freezed,Object? nextFireAt = freezed,}) {
  return _then(_TriggerEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as TriggerSource,config: null == config ? _self._config : config // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,outputs: null == outputs ? _self._outputs : outputs // ignore: cast_nullable_to_non_nullable
as List<Field>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,refCount: null == refCount ? _self.refCount : refCount // ignore: cast_nullable_to_non_nullable
as int,listening: null == listening ? _self.listening : listening // ignore: cast_nullable_to_non_nullable
as bool,lastFiredAt: freezed == lastFiredAt ? _self.lastFiredAt : lastFiredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,nextFireAt: freezed == nextFireAt ? _self.nextFireAt : nextFireAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$Activation {

 String get id; String get triggerId;@JsonKey(unknownEnumValue: TriggerSource.unknown) TriggerSource get kind; bool get fired; Map<String, dynamic> get returnValue; Map<String, dynamic> get payload; String get error; String get detail; int get firingCount; DateTime get createdAt;
/// Create a copy of Activation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActivationCopyWith<Activation> get copyWith => _$ActivationCopyWithImpl<Activation>(this as Activation, _$identity);

  /// Serializes this Activation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Activation&&(identical(other.id, id) || other.id == id)&&(identical(other.triggerId, triggerId) || other.triggerId == triggerId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.fired, fired) || other.fired == fired)&&const DeepCollectionEquality().equals(other.returnValue, returnValue)&&const DeepCollectionEquality().equals(other.payload, payload)&&(identical(other.error, error) || other.error == error)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.firingCount, firingCount) || other.firingCount == firingCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,triggerId,kind,fired,const DeepCollectionEquality().hash(returnValue),const DeepCollectionEquality().hash(payload),error,detail,firingCount,createdAt);

@override
String toString() {
  return 'Activation(id: $id, triggerId: $triggerId, kind: $kind, fired: $fired, returnValue: $returnValue, payload: $payload, error: $error, detail: $detail, firingCount: $firingCount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $ActivationCopyWith<$Res>  {
  factory $ActivationCopyWith(Activation value, $Res Function(Activation) _then) = _$ActivationCopyWithImpl;
@useResult
$Res call({
 String id, String triggerId,@JsonKey(unknownEnumValue: TriggerSource.unknown) TriggerSource kind, bool fired, Map<String, dynamic> returnValue, Map<String, dynamic> payload, String error, String detail, int firingCount, DateTime createdAt
});




}
/// @nodoc
class _$ActivationCopyWithImpl<$Res>
    implements $ActivationCopyWith<$Res> {
  _$ActivationCopyWithImpl(this._self, this._then);

  final Activation _self;
  final $Res Function(Activation) _then;

/// Create a copy of Activation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? triggerId = null,Object? kind = null,Object? fired = null,Object? returnValue = null,Object? payload = null,Object? error = null,Object? detail = null,Object? firingCount = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,triggerId: null == triggerId ? _self.triggerId : triggerId // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as TriggerSource,fired: null == fired ? _self.fired : fired // ignore: cast_nullable_to_non_nullable
as bool,returnValue: null == returnValue ? _self.returnValue : returnValue // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String,firingCount: null == firingCount ? _self.firingCount : firingCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Activation].
extension ActivationPatterns on Activation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Activation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Activation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Activation value)  $default,){
final _that = this;
switch (_that) {
case _Activation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Activation value)?  $default,){
final _that = this;
switch (_that) {
case _Activation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String triggerId, @JsonKey(unknownEnumValue: TriggerSource.unknown)  TriggerSource kind,  bool fired,  Map<String, dynamic> returnValue,  Map<String, dynamic> payload,  String error,  String detail,  int firingCount,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Activation() when $default != null:
return $default(_that.id,_that.triggerId,_that.kind,_that.fired,_that.returnValue,_that.payload,_that.error,_that.detail,_that.firingCount,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String triggerId, @JsonKey(unknownEnumValue: TriggerSource.unknown)  TriggerSource kind,  bool fired,  Map<String, dynamic> returnValue,  Map<String, dynamic> payload,  String error,  String detail,  int firingCount,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _Activation():
return $default(_that.id,_that.triggerId,_that.kind,_that.fired,_that.returnValue,_that.payload,_that.error,_that.detail,_that.firingCount,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String triggerId, @JsonKey(unknownEnumValue: TriggerSource.unknown)  TriggerSource kind,  bool fired,  Map<String, dynamic> returnValue,  Map<String, dynamic> payload,  String error,  String detail,  int firingCount,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Activation() when $default != null:
return $default(_that.id,_that.triggerId,_that.kind,_that.fired,_that.returnValue,_that.payload,_that.error,_that.detail,_that.firingCount,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Activation implements Activation {
  const _Activation({required this.id, this.triggerId = '', @JsonKey(unknownEnumValue: TriggerSource.unknown) this.kind = TriggerSource.unknown, this.fired = false, final  Map<String, dynamic> returnValue = const <String, dynamic>{}, final  Map<String, dynamic> payload = const <String, dynamic>{}, this.error = '', this.detail = '', this.firingCount = 0, required this.createdAt}): _returnValue = returnValue,_payload = payload;
  factory _Activation.fromJson(Map<String, dynamic> json) => _$ActivationFromJson(json);

@override final  String id;
@override@JsonKey() final  String triggerId;
@override@JsonKey(unknownEnumValue: TriggerSource.unknown) final  TriggerSource kind;
@override@JsonKey() final  bool fired;
 final  Map<String, dynamic> _returnValue;
@override@JsonKey() Map<String, dynamic> get returnValue {
  if (_returnValue is EqualUnmodifiableMapView) return _returnValue;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_returnValue);
}

 final  Map<String, dynamic> _payload;
@override@JsonKey() Map<String, dynamic> get payload {
  if (_payload is EqualUnmodifiableMapView) return _payload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_payload);
}

@override@JsonKey() final  String error;
@override@JsonKey() final  String detail;
@override@JsonKey() final  int firingCount;
@override final  DateTime createdAt;

/// Create a copy of Activation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActivationCopyWith<_Activation> get copyWith => __$ActivationCopyWithImpl<_Activation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActivationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Activation&&(identical(other.id, id) || other.id == id)&&(identical(other.triggerId, triggerId) || other.triggerId == triggerId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.fired, fired) || other.fired == fired)&&const DeepCollectionEquality().equals(other._returnValue, _returnValue)&&const DeepCollectionEquality().equals(other._payload, _payload)&&(identical(other.error, error) || other.error == error)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.firingCount, firingCount) || other.firingCount == firingCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,triggerId,kind,fired,const DeepCollectionEquality().hash(_returnValue),const DeepCollectionEquality().hash(_payload),error,detail,firingCount,createdAt);

@override
String toString() {
  return 'Activation(id: $id, triggerId: $triggerId, kind: $kind, fired: $fired, returnValue: $returnValue, payload: $payload, error: $error, detail: $detail, firingCount: $firingCount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$ActivationCopyWith<$Res> implements $ActivationCopyWith<$Res> {
  factory _$ActivationCopyWith(_Activation value, $Res Function(_Activation) _then) = __$ActivationCopyWithImpl;
@override @useResult
$Res call({
 String id, String triggerId,@JsonKey(unknownEnumValue: TriggerSource.unknown) TriggerSource kind, bool fired, Map<String, dynamic> returnValue, Map<String, dynamic> payload, String error, String detail, int firingCount, DateTime createdAt
});




}
/// @nodoc
class __$ActivationCopyWithImpl<$Res>
    implements _$ActivationCopyWith<$Res> {
  __$ActivationCopyWithImpl(this._self, this._then);

  final _Activation _self;
  final $Res Function(_Activation) _then;

/// Create a copy of Activation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? triggerId = null,Object? kind = null,Object? fired = null,Object? returnValue = null,Object? payload = null,Object? error = null,Object? detail = null,Object? firingCount = null,Object? createdAt = null,}) {
  return _then(_Activation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,triggerId: null == triggerId ? _self.triggerId : triggerId // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as TriggerSource,fired: null == fired ? _self.fired : fired // ignore: cast_nullable_to_non_nullable
as bool,returnValue: null == returnValue ? _self._returnValue : returnValue // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,payload: null == payload ? _self._payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String,firingCount: null == firingCount ? _self.firingCount : firingCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$Firing {

 String get id; String get triggerId; String get workflowId; String get activationId; Map<String, dynamic> get payload; String get dedupKey;@JsonKey(unknownEnumValue: FiringStatus.unknown) FiringStatus get status; String get flowrunId; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of Firing
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FiringCopyWith<Firing> get copyWith => _$FiringCopyWithImpl<Firing>(this as Firing, _$identity);

  /// Serializes this Firing to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Firing&&(identical(other.id, id) || other.id == id)&&(identical(other.triggerId, triggerId) || other.triggerId == triggerId)&&(identical(other.workflowId, workflowId) || other.workflowId == workflowId)&&(identical(other.activationId, activationId) || other.activationId == activationId)&&const DeepCollectionEquality().equals(other.payload, payload)&&(identical(other.dedupKey, dedupKey) || other.dedupKey == dedupKey)&&(identical(other.status, status) || other.status == status)&&(identical(other.flowrunId, flowrunId) || other.flowrunId == flowrunId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,triggerId,workflowId,activationId,const DeepCollectionEquality().hash(payload),dedupKey,status,flowrunId,createdAt,updatedAt);

@override
String toString() {
  return 'Firing(id: $id, triggerId: $triggerId, workflowId: $workflowId, activationId: $activationId, payload: $payload, dedupKey: $dedupKey, status: $status, flowrunId: $flowrunId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $FiringCopyWith<$Res>  {
  factory $FiringCopyWith(Firing value, $Res Function(Firing) _then) = _$FiringCopyWithImpl;
@useResult
$Res call({
 String id, String triggerId, String workflowId, String activationId, Map<String, dynamic> payload, String dedupKey,@JsonKey(unknownEnumValue: FiringStatus.unknown) FiringStatus status, String flowrunId, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$FiringCopyWithImpl<$Res>
    implements $FiringCopyWith<$Res> {
  _$FiringCopyWithImpl(this._self, this._then);

  final Firing _self;
  final $Res Function(Firing) _then;

/// Create a copy of Firing
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? triggerId = null,Object? workflowId = null,Object? activationId = null,Object? payload = null,Object? dedupKey = null,Object? status = null,Object? flowrunId = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,triggerId: null == triggerId ? _self.triggerId : triggerId // ignore: cast_nullable_to_non_nullable
as String,workflowId: null == workflowId ? _self.workflowId : workflowId // ignore: cast_nullable_to_non_nullable
as String,activationId: null == activationId ? _self.activationId : activationId // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,dedupKey: null == dedupKey ? _self.dedupKey : dedupKey // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as FiringStatus,flowrunId: null == flowrunId ? _self.flowrunId : flowrunId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Firing].
extension FiringPatterns on Firing {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Firing value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Firing() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Firing value)  $default,){
final _that = this;
switch (_that) {
case _Firing():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Firing value)?  $default,){
final _that = this;
switch (_that) {
case _Firing() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String triggerId,  String workflowId,  String activationId,  Map<String, dynamic> payload,  String dedupKey, @JsonKey(unknownEnumValue: FiringStatus.unknown)  FiringStatus status,  String flowrunId,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Firing() when $default != null:
return $default(_that.id,_that.triggerId,_that.workflowId,_that.activationId,_that.payload,_that.dedupKey,_that.status,_that.flowrunId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String triggerId,  String workflowId,  String activationId,  Map<String, dynamic> payload,  String dedupKey, @JsonKey(unknownEnumValue: FiringStatus.unknown)  FiringStatus status,  String flowrunId,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Firing():
return $default(_that.id,_that.triggerId,_that.workflowId,_that.activationId,_that.payload,_that.dedupKey,_that.status,_that.flowrunId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String triggerId,  String workflowId,  String activationId,  Map<String, dynamic> payload,  String dedupKey, @JsonKey(unknownEnumValue: FiringStatus.unknown)  FiringStatus status,  String flowrunId,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Firing() when $default != null:
return $default(_that.id,_that.triggerId,_that.workflowId,_that.activationId,_that.payload,_that.dedupKey,_that.status,_that.flowrunId,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Firing implements Firing {
  const _Firing({required this.id, this.triggerId = '', this.workflowId = '', this.activationId = '', final  Map<String, dynamic> payload = const <String, dynamic>{}, this.dedupKey = '', @JsonKey(unknownEnumValue: FiringStatus.unknown) this.status = FiringStatus.unknown, this.flowrunId = '', required this.createdAt, required this.updatedAt}): _payload = payload;
  factory _Firing.fromJson(Map<String, dynamic> json) => _$FiringFromJson(json);

@override final  String id;
@override@JsonKey() final  String triggerId;
@override@JsonKey() final  String workflowId;
@override@JsonKey() final  String activationId;
 final  Map<String, dynamic> _payload;
@override@JsonKey() Map<String, dynamic> get payload {
  if (_payload is EqualUnmodifiableMapView) return _payload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_payload);
}

@override@JsonKey() final  String dedupKey;
@override@JsonKey(unknownEnumValue: FiringStatus.unknown) final  FiringStatus status;
@override@JsonKey() final  String flowrunId;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of Firing
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FiringCopyWith<_Firing> get copyWith => __$FiringCopyWithImpl<_Firing>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FiringToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Firing&&(identical(other.id, id) || other.id == id)&&(identical(other.triggerId, triggerId) || other.triggerId == triggerId)&&(identical(other.workflowId, workflowId) || other.workflowId == workflowId)&&(identical(other.activationId, activationId) || other.activationId == activationId)&&const DeepCollectionEquality().equals(other._payload, _payload)&&(identical(other.dedupKey, dedupKey) || other.dedupKey == dedupKey)&&(identical(other.status, status) || other.status == status)&&(identical(other.flowrunId, flowrunId) || other.flowrunId == flowrunId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,triggerId,workflowId,activationId,const DeepCollectionEquality().hash(_payload),dedupKey,status,flowrunId,createdAt,updatedAt);

@override
String toString() {
  return 'Firing(id: $id, triggerId: $triggerId, workflowId: $workflowId, activationId: $activationId, payload: $payload, dedupKey: $dedupKey, status: $status, flowrunId: $flowrunId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$FiringCopyWith<$Res> implements $FiringCopyWith<$Res> {
  factory _$FiringCopyWith(_Firing value, $Res Function(_Firing) _then) = __$FiringCopyWithImpl;
@override @useResult
$Res call({
 String id, String triggerId, String workflowId, String activationId, Map<String, dynamic> payload, String dedupKey,@JsonKey(unknownEnumValue: FiringStatus.unknown) FiringStatus status, String flowrunId, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$FiringCopyWithImpl<$Res>
    implements _$FiringCopyWith<$Res> {
  __$FiringCopyWithImpl(this._self, this._then);

  final _Firing _self;
  final $Res Function(_Firing) _then;

/// Create a copy of Firing
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? triggerId = null,Object? workflowId = null,Object? activationId = null,Object? payload = null,Object? dedupKey = null,Object? status = null,Object? flowrunId = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Firing(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,triggerId: null == triggerId ? _self.triggerId : triggerId // ignore: cast_nullable_to_non_nullable
as String,workflowId: null == workflowId ? _self.workflowId : workflowId // ignore: cast_nullable_to_non_nullable
as String,activationId: null == activationId ? _self.activationId : activationId // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self._payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,dedupKey: null == dedupKey ? _self.dedupKey : dedupKey // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as FiringStatus,flowrunId: null == flowrunId ? _self.flowrunId : flowrunId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
