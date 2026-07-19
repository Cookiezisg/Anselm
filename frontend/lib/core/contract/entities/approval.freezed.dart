// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'approval.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ApprovalForm {

 String get id; String get name; String get description; String get activeVersionId; DateTime get createdAt; DateTime get updatedAt; ApprovalVersion? get activeVersion;
/// Create a copy of ApprovalForm
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApprovalFormCopyWith<ApprovalForm> get copyWith => _$ApprovalFormCopyWithImpl<ApprovalForm>(this as ApprovalForm, _$identity);

  /// Serializes this ApprovalForm to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApprovalForm&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.activeVersionId, activeVersionId) || other.activeVersionId == activeVersionId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.activeVersion, activeVersion) || other.activeVersion == activeVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,activeVersionId,createdAt,updatedAt,activeVersion);

@override
String toString() {
  return 'ApprovalForm(id: $id, name: $name, description: $description, activeVersionId: $activeVersionId, createdAt: $createdAt, updatedAt: $updatedAt, activeVersion: $activeVersion)';
}


}

/// @nodoc
abstract mixin class $ApprovalFormCopyWith<$Res>  {
  factory $ApprovalFormCopyWith(ApprovalForm value, $Res Function(ApprovalForm) _then) = _$ApprovalFormCopyWithImpl;
@useResult
$Res call({
 String id, String name, String description, String activeVersionId, DateTime createdAt, DateTime updatedAt, ApprovalVersion? activeVersion
});


$ApprovalVersionCopyWith<$Res>? get activeVersion;

}
/// @nodoc
class _$ApprovalFormCopyWithImpl<$Res>
    implements $ApprovalFormCopyWith<$Res> {
  _$ApprovalFormCopyWithImpl(this._self, this._then);

  final ApprovalForm _self;
  final $Res Function(ApprovalForm) _then;

/// Create a copy of ApprovalForm
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = null,Object? activeVersionId = null,Object? createdAt = null,Object? updatedAt = null,Object? activeVersion = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,activeVersionId: null == activeVersionId ? _self.activeVersionId : activeVersionId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,activeVersion: freezed == activeVersion ? _self.activeVersion : activeVersion // ignore: cast_nullable_to_non_nullable
as ApprovalVersion?,
  ));
}
/// Create a copy of ApprovalForm
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApprovalVersionCopyWith<$Res>? get activeVersion {
    if (_self.activeVersion == null) {
    return null;
  }

  return $ApprovalVersionCopyWith<$Res>(_self.activeVersion!, (value) {
    return _then(_self.copyWith(activeVersion: value));
  });
}
}


/// Adds pattern-matching-related methods to [ApprovalForm].
extension ApprovalFormPatterns on ApprovalForm {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApprovalForm value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApprovalForm() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApprovalForm value)  $default,){
final _that = this;
switch (_that) {
case _ApprovalForm():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApprovalForm value)?  $default,){
final _that = this;
switch (_that) {
case _ApprovalForm() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String description,  String activeVersionId,  DateTime createdAt,  DateTime updatedAt,  ApprovalVersion? activeVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApprovalForm() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.activeVersionId,_that.createdAt,_that.updatedAt,_that.activeVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String description,  String activeVersionId,  DateTime createdAt,  DateTime updatedAt,  ApprovalVersion? activeVersion)  $default,) {final _that = this;
switch (_that) {
case _ApprovalForm():
return $default(_that.id,_that.name,_that.description,_that.activeVersionId,_that.createdAt,_that.updatedAt,_that.activeVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String description,  String activeVersionId,  DateTime createdAt,  DateTime updatedAt,  ApprovalVersion? activeVersion)?  $default,) {final _that = this;
switch (_that) {
case _ApprovalForm() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.activeVersionId,_that.createdAt,_that.updatedAt,_that.activeVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApprovalForm implements ApprovalForm {
  const _ApprovalForm({required this.id, this.name = '', this.description = '', this.activeVersionId = '', required this.createdAt, required this.updatedAt, this.activeVersion});
  factory _ApprovalForm.fromJson(Map<String, dynamic> json) => _$ApprovalFormFromJson(json);

@override final  String id;
@override@JsonKey() final  String name;
@override@JsonKey() final  String description;
@override@JsonKey() final  String activeVersionId;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  ApprovalVersion? activeVersion;

/// Create a copy of ApprovalForm
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApprovalFormCopyWith<_ApprovalForm> get copyWith => __$ApprovalFormCopyWithImpl<_ApprovalForm>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApprovalFormToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApprovalForm&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.activeVersionId, activeVersionId) || other.activeVersionId == activeVersionId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.activeVersion, activeVersion) || other.activeVersion == activeVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,activeVersionId,createdAt,updatedAt,activeVersion);

@override
String toString() {
  return 'ApprovalForm(id: $id, name: $name, description: $description, activeVersionId: $activeVersionId, createdAt: $createdAt, updatedAt: $updatedAt, activeVersion: $activeVersion)';
}


}

/// @nodoc
abstract mixin class _$ApprovalFormCopyWith<$Res> implements $ApprovalFormCopyWith<$Res> {
  factory _$ApprovalFormCopyWith(_ApprovalForm value, $Res Function(_ApprovalForm) _then) = __$ApprovalFormCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String description, String activeVersionId, DateTime createdAt, DateTime updatedAt, ApprovalVersion? activeVersion
});


@override $ApprovalVersionCopyWith<$Res>? get activeVersion;

}
/// @nodoc
class __$ApprovalFormCopyWithImpl<$Res>
    implements _$ApprovalFormCopyWith<$Res> {
  __$ApprovalFormCopyWithImpl(this._self, this._then);

  final _ApprovalForm _self;
  final $Res Function(_ApprovalForm) _then;

/// Create a copy of ApprovalForm
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = null,Object? activeVersionId = null,Object? createdAt = null,Object? updatedAt = null,Object? activeVersion = freezed,}) {
  return _then(_ApprovalForm(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,activeVersionId: null == activeVersionId ? _self.activeVersionId : activeVersionId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,activeVersion: freezed == activeVersion ? _self.activeVersion : activeVersion // ignore: cast_nullable_to_non_nullable
as ApprovalVersion?,
  ));
}

/// Create a copy of ApprovalForm
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApprovalVersionCopyWith<$Res>? get activeVersion {
    if (_self.activeVersion == null) {
    return null;
  }

  return $ApprovalVersionCopyWith<$Res>(_self.activeVersion!, (value) {
    return _then(_self.copyWith(activeVersion: value));
  });
}
}


/// @nodoc
mixin _$ApprovalVersion {

 String get id; String get approvalId; int get version; List<Field> get inputs; String get template; bool get allowReason; String get timeout; String get timeoutBehavior; String? get changeReason; String? get builtInConversationId; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of ApprovalVersion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApprovalVersionCopyWith<ApprovalVersion> get copyWith => _$ApprovalVersionCopyWithImpl<ApprovalVersion>(this as ApprovalVersion, _$identity);

  /// Serializes this ApprovalVersion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApprovalVersion&&(identical(other.id, id) || other.id == id)&&(identical(other.approvalId, approvalId) || other.approvalId == approvalId)&&(identical(other.version, version) || other.version == version)&&const DeepCollectionEquality().equals(other.inputs, inputs)&&(identical(other.template, template) || other.template == template)&&(identical(other.allowReason, allowReason) || other.allowReason == allowReason)&&(identical(other.timeout, timeout) || other.timeout == timeout)&&(identical(other.timeoutBehavior, timeoutBehavior) || other.timeoutBehavior == timeoutBehavior)&&(identical(other.changeReason, changeReason) || other.changeReason == changeReason)&&(identical(other.builtInConversationId, builtInConversationId) || other.builtInConversationId == builtInConversationId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,approvalId,version,const DeepCollectionEquality().hash(inputs),template,allowReason,timeout,timeoutBehavior,changeReason,builtInConversationId,createdAt,updatedAt);

@override
String toString() {
  return 'ApprovalVersion(id: $id, approvalId: $approvalId, version: $version, inputs: $inputs, template: $template, allowReason: $allowReason, timeout: $timeout, timeoutBehavior: $timeoutBehavior, changeReason: $changeReason, builtInConversationId: $builtInConversationId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ApprovalVersionCopyWith<$Res>  {
  factory $ApprovalVersionCopyWith(ApprovalVersion value, $Res Function(ApprovalVersion) _then) = _$ApprovalVersionCopyWithImpl;
@useResult
$Res call({
 String id, String approvalId, int version, List<Field> inputs, String template, bool allowReason, String timeout, String timeoutBehavior, String? changeReason, String? builtInConversationId, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$ApprovalVersionCopyWithImpl<$Res>
    implements $ApprovalVersionCopyWith<$Res> {
  _$ApprovalVersionCopyWithImpl(this._self, this._then);

  final ApprovalVersion _self;
  final $Res Function(ApprovalVersion) _then;

/// Create a copy of ApprovalVersion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? approvalId = null,Object? version = null,Object? inputs = null,Object? template = null,Object? allowReason = null,Object? timeout = null,Object? timeoutBehavior = null,Object? changeReason = freezed,Object? builtInConversationId = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,approvalId: null == approvalId ? _self.approvalId : approvalId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,inputs: null == inputs ? _self.inputs : inputs // ignore: cast_nullable_to_non_nullable
as List<Field>,template: null == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as String,allowReason: null == allowReason ? _self.allowReason : allowReason // ignore: cast_nullable_to_non_nullable
as bool,timeout: null == timeout ? _self.timeout : timeout // ignore: cast_nullable_to_non_nullable
as String,timeoutBehavior: null == timeoutBehavior ? _self.timeoutBehavior : timeoutBehavior // ignore: cast_nullable_to_non_nullable
as String,changeReason: freezed == changeReason ? _self.changeReason : changeReason // ignore: cast_nullable_to_non_nullable
as String?,builtInConversationId: freezed == builtInConversationId ? _self.builtInConversationId : builtInConversationId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [ApprovalVersion].
extension ApprovalVersionPatterns on ApprovalVersion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApprovalVersion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApprovalVersion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApprovalVersion value)  $default,){
final _that = this;
switch (_that) {
case _ApprovalVersion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApprovalVersion value)?  $default,){
final _that = this;
switch (_that) {
case _ApprovalVersion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String approvalId,  int version,  List<Field> inputs,  String template,  bool allowReason,  String timeout,  String timeoutBehavior,  String? changeReason,  String? builtInConversationId,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApprovalVersion() when $default != null:
return $default(_that.id,_that.approvalId,_that.version,_that.inputs,_that.template,_that.allowReason,_that.timeout,_that.timeoutBehavior,_that.changeReason,_that.builtInConversationId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String approvalId,  int version,  List<Field> inputs,  String template,  bool allowReason,  String timeout,  String timeoutBehavior,  String? changeReason,  String? builtInConversationId,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ApprovalVersion():
return $default(_that.id,_that.approvalId,_that.version,_that.inputs,_that.template,_that.allowReason,_that.timeout,_that.timeoutBehavior,_that.changeReason,_that.builtInConversationId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String approvalId,  int version,  List<Field> inputs,  String template,  bool allowReason,  String timeout,  String timeoutBehavior,  String? changeReason,  String? builtInConversationId,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ApprovalVersion() when $default != null:
return $default(_that.id,_that.approvalId,_that.version,_that.inputs,_that.template,_that.allowReason,_that.timeout,_that.timeoutBehavior,_that.changeReason,_that.builtInConversationId,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApprovalVersion implements ApprovalVersion {
  const _ApprovalVersion({required this.id, required this.approvalId, required this.version, final  List<Field> inputs = const <Field>[], this.template = '', this.allowReason = false, this.timeout = '', this.timeoutBehavior = '', this.changeReason, this.builtInConversationId, required this.createdAt, required this.updatedAt}): _inputs = inputs;
  factory _ApprovalVersion.fromJson(Map<String, dynamic> json) => _$ApprovalVersionFromJson(json);

@override final  String id;
@override final  String approvalId;
@override final  int version;
 final  List<Field> _inputs;
@override@JsonKey() List<Field> get inputs {
  if (_inputs is EqualUnmodifiableListView) return _inputs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_inputs);
}

@override@JsonKey() final  String template;
@override@JsonKey() final  bool allowReason;
@override@JsonKey() final  String timeout;
@override@JsonKey() final  String timeoutBehavior;
@override final  String? changeReason;
@override final  String? builtInConversationId;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of ApprovalVersion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApprovalVersionCopyWith<_ApprovalVersion> get copyWith => __$ApprovalVersionCopyWithImpl<_ApprovalVersion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApprovalVersionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApprovalVersion&&(identical(other.id, id) || other.id == id)&&(identical(other.approvalId, approvalId) || other.approvalId == approvalId)&&(identical(other.version, version) || other.version == version)&&const DeepCollectionEquality().equals(other._inputs, _inputs)&&(identical(other.template, template) || other.template == template)&&(identical(other.allowReason, allowReason) || other.allowReason == allowReason)&&(identical(other.timeout, timeout) || other.timeout == timeout)&&(identical(other.timeoutBehavior, timeoutBehavior) || other.timeoutBehavior == timeoutBehavior)&&(identical(other.changeReason, changeReason) || other.changeReason == changeReason)&&(identical(other.builtInConversationId, builtInConversationId) || other.builtInConversationId == builtInConversationId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,approvalId,version,const DeepCollectionEquality().hash(_inputs),template,allowReason,timeout,timeoutBehavior,changeReason,builtInConversationId,createdAt,updatedAt);

@override
String toString() {
  return 'ApprovalVersion(id: $id, approvalId: $approvalId, version: $version, inputs: $inputs, template: $template, allowReason: $allowReason, timeout: $timeout, timeoutBehavior: $timeoutBehavior, changeReason: $changeReason, builtInConversationId: $builtInConversationId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ApprovalVersionCopyWith<$Res> implements $ApprovalVersionCopyWith<$Res> {
  factory _$ApprovalVersionCopyWith(_ApprovalVersion value, $Res Function(_ApprovalVersion) _then) = __$ApprovalVersionCopyWithImpl;
@override @useResult
$Res call({
 String id, String approvalId, int version, List<Field> inputs, String template, bool allowReason, String timeout, String timeoutBehavior, String? changeReason, String? builtInConversationId, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$ApprovalVersionCopyWithImpl<$Res>
    implements _$ApprovalVersionCopyWith<$Res> {
  __$ApprovalVersionCopyWithImpl(this._self, this._then);

  final _ApprovalVersion _self;
  final $Res Function(_ApprovalVersion) _then;

/// Create a copy of ApprovalVersion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? approvalId = null,Object? version = null,Object? inputs = null,Object? template = null,Object? allowReason = null,Object? timeout = null,Object? timeoutBehavior = null,Object? changeReason = freezed,Object? builtInConversationId = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_ApprovalVersion(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,approvalId: null == approvalId ? _self.approvalId : approvalId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,inputs: null == inputs ? _self._inputs : inputs // ignore: cast_nullable_to_non_nullable
as List<Field>,template: null == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as String,allowReason: null == allowReason ? _self.allowReason : allowReason // ignore: cast_nullable_to_non_nullable
as bool,timeout: null == timeout ? _self.timeout : timeout // ignore: cast_nullable_to_non_nullable
as String,timeoutBehavior: null == timeoutBehavior ? _self.timeoutBehavior : timeoutBehavior // ignore: cast_nullable_to_non_nullable
as String,changeReason: freezed == changeReason ? _self.changeReason : changeReason // ignore: cast_nullable_to_non_nullable
as String?,builtInConversationId: freezed == builtInConversationId ? _self.builtInConversationId : builtInConversationId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
