// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'attachment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AttachmentMeta {

 String get id; String get sha256; String get filename; String get mimeType; int get sizeBytes; String get kind; DateTime? get createdAt; AttachmentPreparation? get preparation;
/// Create a copy of AttachmentMeta
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AttachmentMetaCopyWith<AttachmentMeta> get copyWith => _$AttachmentMetaCopyWithImpl<AttachmentMeta>(this as AttachmentMeta, _$identity);

  /// Serializes this AttachmentMeta to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AttachmentMeta&&(identical(other.id, id) || other.id == id)&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.filename, filename) || other.filename == filename)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.preparation, preparation) || other.preparation == preparation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sha256,filename,mimeType,sizeBytes,kind,createdAt,preparation);

@override
String toString() {
  return 'AttachmentMeta(id: $id, sha256: $sha256, filename: $filename, mimeType: $mimeType, sizeBytes: $sizeBytes, kind: $kind, createdAt: $createdAt, preparation: $preparation)';
}


}

/// @nodoc
abstract mixin class $AttachmentMetaCopyWith<$Res>  {
  factory $AttachmentMetaCopyWith(AttachmentMeta value, $Res Function(AttachmentMeta) _then) = _$AttachmentMetaCopyWithImpl;
@useResult
$Res call({
 String id, String sha256, String filename, String mimeType, int sizeBytes, String kind, DateTime? createdAt, AttachmentPreparation? preparation
});


$AttachmentPreparationCopyWith<$Res>? get preparation;

}
/// @nodoc
class _$AttachmentMetaCopyWithImpl<$Res>
    implements $AttachmentMetaCopyWith<$Res> {
  _$AttachmentMetaCopyWithImpl(this._self, this._then);

  final AttachmentMeta _self;
  final $Res Function(AttachmentMeta) _then;

/// Create a copy of AttachmentMeta
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sha256 = null,Object? filename = null,Object? mimeType = null,Object? sizeBytes = null,Object? kind = null,Object? createdAt = freezed,Object? preparation = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,filename: null == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,preparation: freezed == preparation ? _self.preparation : preparation // ignore: cast_nullable_to_non_nullable
as AttachmentPreparation?,
  ));
}
/// Create a copy of AttachmentMeta
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AttachmentPreparationCopyWith<$Res>? get preparation {
    if (_self.preparation == null) {
    return null;
  }

  return $AttachmentPreparationCopyWith<$Res>(_self.preparation!, (value) {
    return _then(_self.copyWith(preparation: value));
  });
}
}


/// Adds pattern-matching-related methods to [AttachmentMeta].
extension AttachmentMetaPatterns on AttachmentMeta {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AttachmentMeta value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AttachmentMeta() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AttachmentMeta value)  $default,){
final _that = this;
switch (_that) {
case _AttachmentMeta():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AttachmentMeta value)?  $default,){
final _that = this;
switch (_that) {
case _AttachmentMeta() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String sha256,  String filename,  String mimeType,  int sizeBytes,  String kind,  DateTime? createdAt,  AttachmentPreparation? preparation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AttachmentMeta() when $default != null:
return $default(_that.id,_that.sha256,_that.filename,_that.mimeType,_that.sizeBytes,_that.kind,_that.createdAt,_that.preparation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String sha256,  String filename,  String mimeType,  int sizeBytes,  String kind,  DateTime? createdAt,  AttachmentPreparation? preparation)  $default,) {final _that = this;
switch (_that) {
case _AttachmentMeta():
return $default(_that.id,_that.sha256,_that.filename,_that.mimeType,_that.sizeBytes,_that.kind,_that.createdAt,_that.preparation);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String sha256,  String filename,  String mimeType,  int sizeBytes,  String kind,  DateTime? createdAt,  AttachmentPreparation? preparation)?  $default,) {final _that = this;
switch (_that) {
case _AttachmentMeta() when $default != null:
return $default(_that.id,_that.sha256,_that.filename,_that.mimeType,_that.sizeBytes,_that.kind,_that.createdAt,_that.preparation);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AttachmentMeta implements AttachmentMeta {
  const _AttachmentMeta({required this.id, this.sha256 = '', this.filename = '', this.mimeType = '', this.sizeBytes = 0, this.kind = 'other', this.createdAt, this.preparation});
  factory _AttachmentMeta.fromJson(Map<String, dynamic> json) => _$AttachmentMetaFromJson(json);

@override final  String id;
@override@JsonKey() final  String sha256;
@override@JsonKey() final  String filename;
@override@JsonKey() final  String mimeType;
@override@JsonKey() final  int sizeBytes;
@override@JsonKey() final  String kind;
@override final  DateTime? createdAt;
@override final  AttachmentPreparation? preparation;

/// Create a copy of AttachmentMeta
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AttachmentMetaCopyWith<_AttachmentMeta> get copyWith => __$AttachmentMetaCopyWithImpl<_AttachmentMeta>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AttachmentMetaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AttachmentMeta&&(identical(other.id, id) || other.id == id)&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.filename, filename) || other.filename == filename)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.preparation, preparation) || other.preparation == preparation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sha256,filename,mimeType,sizeBytes,kind,createdAt,preparation);

@override
String toString() {
  return 'AttachmentMeta(id: $id, sha256: $sha256, filename: $filename, mimeType: $mimeType, sizeBytes: $sizeBytes, kind: $kind, createdAt: $createdAt, preparation: $preparation)';
}


}

/// @nodoc
abstract mixin class _$AttachmentMetaCopyWith<$Res> implements $AttachmentMetaCopyWith<$Res> {
  factory _$AttachmentMetaCopyWith(_AttachmentMeta value, $Res Function(_AttachmentMeta) _then) = __$AttachmentMetaCopyWithImpl;
@override @useResult
$Res call({
 String id, String sha256, String filename, String mimeType, int sizeBytes, String kind, DateTime? createdAt, AttachmentPreparation? preparation
});


@override $AttachmentPreparationCopyWith<$Res>? get preparation;

}
/// @nodoc
class __$AttachmentMetaCopyWithImpl<$Res>
    implements _$AttachmentMetaCopyWith<$Res> {
  __$AttachmentMetaCopyWithImpl(this._self, this._then);

  final _AttachmentMeta _self;
  final $Res Function(_AttachmentMeta) _then;

/// Create a copy of AttachmentMeta
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sha256 = null,Object? filename = null,Object? mimeType = null,Object? sizeBytes = null,Object? kind = null,Object? createdAt = freezed,Object? preparation = freezed,}) {
  return _then(_AttachmentMeta(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,filename: null == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,preparation: freezed == preparation ? _self.preparation : preparation // ignore: cast_nullable_to_non_nullable
as AttachmentPreparation?,
  ));
}

/// Create a copy of AttachmentMeta
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AttachmentPreparationCopyWith<$Res>? get preparation {
    if (_self.preparation == null) {
    return null;
  }

  return $AttachmentPreparationCopyWith<$Res>(_self.preparation!, (value) {
    return _then(_self.copyWith(preparation: value));
  });
}
}


/// @nodoc
mixin _$AttachmentPreparation {

 String get status; String get phase; String get target; int get width; int get height; String get mimeType; int get sizeBytes; String get errorCode; bool get canCancel; bool get canRetry; DateTime? get updatedAt;
/// Create a copy of AttachmentPreparation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AttachmentPreparationCopyWith<AttachmentPreparation> get copyWith => _$AttachmentPreparationCopyWithImpl<AttachmentPreparation>(this as AttachmentPreparation, _$identity);

  /// Serializes this AttachmentPreparation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AttachmentPreparation&&(identical(other.status, status) || other.status == status)&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.target, target) || other.target == target)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.canCancel, canCancel) || other.canCancel == canCancel)&&(identical(other.canRetry, canRetry) || other.canRetry == canRetry)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,phase,target,width,height,mimeType,sizeBytes,errorCode,canCancel,canRetry,updatedAt);

@override
String toString() {
  return 'AttachmentPreparation(status: $status, phase: $phase, target: $target, width: $width, height: $height, mimeType: $mimeType, sizeBytes: $sizeBytes, errorCode: $errorCode, canCancel: $canCancel, canRetry: $canRetry, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $AttachmentPreparationCopyWith<$Res>  {
  factory $AttachmentPreparationCopyWith(AttachmentPreparation value, $Res Function(AttachmentPreparation) _then) = _$AttachmentPreparationCopyWithImpl;
@useResult
$Res call({
 String status, String phase, String target, int width, int height, String mimeType, int sizeBytes, String errorCode, bool canCancel, bool canRetry, DateTime? updatedAt
});




}
/// @nodoc
class _$AttachmentPreparationCopyWithImpl<$Res>
    implements $AttachmentPreparationCopyWith<$Res> {
  _$AttachmentPreparationCopyWithImpl(this._self, this._then);

  final AttachmentPreparation _self;
  final $Res Function(AttachmentPreparation) _then;

/// Create a copy of AttachmentPreparation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? phase = null,Object? target = null,Object? width = null,Object? height = null,Object? mimeType = null,Object? sizeBytes = null,Object? errorCode = null,Object? canCancel = null,Object? canRetry = null,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,errorCode: null == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String,canCancel: null == canCancel ? _self.canCancel : canCancel // ignore: cast_nullable_to_non_nullable
as bool,canRetry: null == canRetry ? _self.canRetry : canRetry // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [AttachmentPreparation].
extension AttachmentPreparationPatterns on AttachmentPreparation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AttachmentPreparation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AttachmentPreparation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AttachmentPreparation value)  $default,){
final _that = this;
switch (_that) {
case _AttachmentPreparation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AttachmentPreparation value)?  $default,){
final _that = this;
switch (_that) {
case _AttachmentPreparation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String status,  String phase,  String target,  int width,  int height,  String mimeType,  int sizeBytes,  String errorCode,  bool canCancel,  bool canRetry,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AttachmentPreparation() when $default != null:
return $default(_that.status,_that.phase,_that.target,_that.width,_that.height,_that.mimeType,_that.sizeBytes,_that.errorCode,_that.canCancel,_that.canRetry,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String status,  String phase,  String target,  int width,  int height,  String mimeType,  int sizeBytes,  String errorCode,  bool canCancel,  bool canRetry,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _AttachmentPreparation():
return $default(_that.status,_that.phase,_that.target,_that.width,_that.height,_that.mimeType,_that.sizeBytes,_that.errorCode,_that.canCancel,_that.canRetry,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String status,  String phase,  String target,  int width,  int height,  String mimeType,  int sizeBytes,  String errorCode,  bool canCancel,  bool canRetry,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _AttachmentPreparation() when $default != null:
return $default(_that.status,_that.phase,_that.target,_that.width,_that.height,_that.mimeType,_that.sizeBytes,_that.errorCode,_that.canCancel,_that.canRetry,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AttachmentPreparation implements AttachmentPreparation {
  const _AttachmentPreparation({this.status = 'not_required', this.phase = '', this.target = '', this.width = 0, this.height = 0, this.mimeType = '', this.sizeBytes = 0, this.errorCode = '', this.canCancel = false, this.canRetry = false, this.updatedAt});
  factory _AttachmentPreparation.fromJson(Map<String, dynamic> json) => _$AttachmentPreparationFromJson(json);

@override@JsonKey() final  String status;
@override@JsonKey() final  String phase;
@override@JsonKey() final  String target;
@override@JsonKey() final  int width;
@override@JsonKey() final  int height;
@override@JsonKey() final  String mimeType;
@override@JsonKey() final  int sizeBytes;
@override@JsonKey() final  String errorCode;
@override@JsonKey() final  bool canCancel;
@override@JsonKey() final  bool canRetry;
@override final  DateTime? updatedAt;

/// Create a copy of AttachmentPreparation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AttachmentPreparationCopyWith<_AttachmentPreparation> get copyWith => __$AttachmentPreparationCopyWithImpl<_AttachmentPreparation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AttachmentPreparationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AttachmentPreparation&&(identical(other.status, status) || other.status == status)&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.target, target) || other.target == target)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.canCancel, canCancel) || other.canCancel == canCancel)&&(identical(other.canRetry, canRetry) || other.canRetry == canRetry)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,phase,target,width,height,mimeType,sizeBytes,errorCode,canCancel,canRetry,updatedAt);

@override
String toString() {
  return 'AttachmentPreparation(status: $status, phase: $phase, target: $target, width: $width, height: $height, mimeType: $mimeType, sizeBytes: $sizeBytes, errorCode: $errorCode, canCancel: $canCancel, canRetry: $canRetry, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$AttachmentPreparationCopyWith<$Res> implements $AttachmentPreparationCopyWith<$Res> {
  factory _$AttachmentPreparationCopyWith(_AttachmentPreparation value, $Res Function(_AttachmentPreparation) _then) = __$AttachmentPreparationCopyWithImpl;
@override @useResult
$Res call({
 String status, String phase, String target, int width, int height, String mimeType, int sizeBytes, String errorCode, bool canCancel, bool canRetry, DateTime? updatedAt
});




}
/// @nodoc
class __$AttachmentPreparationCopyWithImpl<$Res>
    implements _$AttachmentPreparationCopyWith<$Res> {
  __$AttachmentPreparationCopyWithImpl(this._self, this._then);

  final _AttachmentPreparation _self;
  final $Res Function(_AttachmentPreparation) _then;

/// Create a copy of AttachmentPreparation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? phase = null,Object? target = null,Object? width = null,Object? height = null,Object? mimeType = null,Object? sizeBytes = null,Object? errorCode = null,Object? canCancel = null,Object? canRetry = null,Object? updatedAt = freezed,}) {
  return _then(_AttachmentPreparation(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,errorCode: null == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String,canCancel: null == canCancel ? _self.canCancel : canCancel // ignore: cast_nullable_to_non_nullable
as bool,canRetry: null == canRetry ? _self.canRetry : canRetry // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
