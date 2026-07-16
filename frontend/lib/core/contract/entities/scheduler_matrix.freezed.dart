// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scheduler_matrix.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MatrixCol {

 String get flowrunId; DateTime get startedAt; String get status; int? get elapsedMs;
/// Create a copy of MatrixCol
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MatrixColCopyWith<MatrixCol> get copyWith => _$MatrixColCopyWithImpl<MatrixCol>(this as MatrixCol, _$identity);

  /// Serializes this MatrixCol to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MatrixCol&&(identical(other.flowrunId, flowrunId) || other.flowrunId == flowrunId)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.elapsedMs, elapsedMs) || other.elapsedMs == elapsedMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,flowrunId,startedAt,status,elapsedMs);

@override
String toString() {
  return 'MatrixCol(flowrunId: $flowrunId, startedAt: $startedAt, status: $status, elapsedMs: $elapsedMs)';
}


}

/// @nodoc
abstract mixin class $MatrixColCopyWith<$Res>  {
  factory $MatrixColCopyWith(MatrixCol value, $Res Function(MatrixCol) _then) = _$MatrixColCopyWithImpl;
@useResult
$Res call({
 String flowrunId, DateTime startedAt, String status, int? elapsedMs
});




}
/// @nodoc
class _$MatrixColCopyWithImpl<$Res>
    implements $MatrixColCopyWith<$Res> {
  _$MatrixColCopyWithImpl(this._self, this._then);

  final MatrixCol _self;
  final $Res Function(MatrixCol) _then;

/// Create a copy of MatrixCol
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? flowrunId = null,Object? startedAt = null,Object? status = null,Object? elapsedMs = freezed,}) {
  return _then(_self.copyWith(
flowrunId: null == flowrunId ? _self.flowrunId : flowrunId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,elapsedMs: freezed == elapsedMs ? _self.elapsedMs : elapsedMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [MatrixCol].
extension MatrixColPatterns on MatrixCol {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MatrixCol value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MatrixCol() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MatrixCol value)  $default,){
final _that = this;
switch (_that) {
case _MatrixCol():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MatrixCol value)?  $default,){
final _that = this;
switch (_that) {
case _MatrixCol() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String flowrunId,  DateTime startedAt,  String status,  int? elapsedMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MatrixCol() when $default != null:
return $default(_that.flowrunId,_that.startedAt,_that.status,_that.elapsedMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String flowrunId,  DateTime startedAt,  String status,  int? elapsedMs)  $default,) {final _that = this;
switch (_that) {
case _MatrixCol():
return $default(_that.flowrunId,_that.startedAt,_that.status,_that.elapsedMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String flowrunId,  DateTime startedAt,  String status,  int? elapsedMs)?  $default,) {final _that = this;
switch (_that) {
case _MatrixCol() when $default != null:
return $default(_that.flowrunId,_that.startedAt,_that.status,_that.elapsedMs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MatrixCol implements MatrixCol {
  const _MatrixCol({this.flowrunId = '', required this.startedAt, this.status = '', this.elapsedMs});
  factory _MatrixCol.fromJson(Map<String, dynamic> json) => _$MatrixColFromJson(json);

@override@JsonKey() final  String flowrunId;
@override final  DateTime startedAt;
@override@JsonKey() final  String status;
@override final  int? elapsedMs;

/// Create a copy of MatrixCol
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MatrixColCopyWith<_MatrixCol> get copyWith => __$MatrixColCopyWithImpl<_MatrixCol>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MatrixColToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MatrixCol&&(identical(other.flowrunId, flowrunId) || other.flowrunId == flowrunId)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.elapsedMs, elapsedMs) || other.elapsedMs == elapsedMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,flowrunId,startedAt,status,elapsedMs);

@override
String toString() {
  return 'MatrixCol(flowrunId: $flowrunId, startedAt: $startedAt, status: $status, elapsedMs: $elapsedMs)';
}


}

/// @nodoc
abstract mixin class _$MatrixColCopyWith<$Res> implements $MatrixColCopyWith<$Res> {
  factory _$MatrixColCopyWith(_MatrixCol value, $Res Function(_MatrixCol) _then) = __$MatrixColCopyWithImpl;
@override @useResult
$Res call({
 String flowrunId, DateTime startedAt, String status, int? elapsedMs
});




}
/// @nodoc
class __$MatrixColCopyWithImpl<$Res>
    implements _$MatrixColCopyWith<$Res> {
  __$MatrixColCopyWithImpl(this._self, this._then);

  final _MatrixCol _self;
  final $Res Function(_MatrixCol) _then;

/// Create a copy of MatrixCol
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? flowrunId = null,Object? startedAt = null,Object? status = null,Object? elapsedMs = freezed,}) {
  return _then(_MatrixCol(
flowrunId: null == flowrunId ? _self.flowrunId : flowrunId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,elapsedMs: freezed == elapsedMs ? _self.elapsedMs : elapsedMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$MatrixRow {

 String get nodeId; String get kind;
/// Create a copy of MatrixRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MatrixRowCopyWith<MatrixRow> get copyWith => _$MatrixRowCopyWithImpl<MatrixRow>(this as MatrixRow, _$identity);

  /// Serializes this MatrixRow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MatrixRow&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.kind, kind) || other.kind == kind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,nodeId,kind);

@override
String toString() {
  return 'MatrixRow(nodeId: $nodeId, kind: $kind)';
}


}

/// @nodoc
abstract mixin class $MatrixRowCopyWith<$Res>  {
  factory $MatrixRowCopyWith(MatrixRow value, $Res Function(MatrixRow) _then) = _$MatrixRowCopyWithImpl;
@useResult
$Res call({
 String nodeId, String kind
});




}
/// @nodoc
class _$MatrixRowCopyWithImpl<$Res>
    implements $MatrixRowCopyWith<$Res> {
  _$MatrixRowCopyWithImpl(this._self, this._then);

  final MatrixRow _self;
  final $Res Function(MatrixRow) _then;

/// Create a copy of MatrixRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? nodeId = null,Object? kind = null,}) {
  return _then(_self.copyWith(
nodeId: null == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MatrixRow].
extension MatrixRowPatterns on MatrixRow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MatrixRow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MatrixRow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MatrixRow value)  $default,){
final _that = this;
switch (_that) {
case _MatrixRow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MatrixRow value)?  $default,){
final _that = this;
switch (_that) {
case _MatrixRow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String nodeId,  String kind)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MatrixRow() when $default != null:
return $default(_that.nodeId,_that.kind);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String nodeId,  String kind)  $default,) {final _that = this;
switch (_that) {
case _MatrixRow():
return $default(_that.nodeId,_that.kind);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String nodeId,  String kind)?  $default,) {final _that = this;
switch (_that) {
case _MatrixRow() when $default != null:
return $default(_that.nodeId,_that.kind);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MatrixRow implements MatrixRow {
  const _MatrixRow({this.nodeId = '', this.kind = ''});
  factory _MatrixRow.fromJson(Map<String, dynamic> json) => _$MatrixRowFromJson(json);

@override@JsonKey() final  String nodeId;
@override@JsonKey() final  String kind;

/// Create a copy of MatrixRow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MatrixRowCopyWith<_MatrixRow> get copyWith => __$MatrixRowCopyWithImpl<_MatrixRow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MatrixRowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MatrixRow&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.kind, kind) || other.kind == kind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,nodeId,kind);

@override
String toString() {
  return 'MatrixRow(nodeId: $nodeId, kind: $kind)';
}


}

/// @nodoc
abstract mixin class _$MatrixRowCopyWith<$Res> implements $MatrixRowCopyWith<$Res> {
  factory _$MatrixRowCopyWith(_MatrixRow value, $Res Function(_MatrixRow) _then) = __$MatrixRowCopyWithImpl;
@override @useResult
$Res call({
 String nodeId, String kind
});




}
/// @nodoc
class __$MatrixRowCopyWithImpl<$Res>
    implements _$MatrixRowCopyWith<$Res> {
  __$MatrixRowCopyWithImpl(this._self, this._then);

  final _MatrixRow _self;
  final $Res Function(_MatrixRow) _then;

/// Create a copy of MatrixRow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? nodeId = null,Object? kind = null,}) {
  return _then(_MatrixRow(
nodeId: null == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$MatrixCell {

 String get flowrunId; String get nodeId; String get status; int get iteration; int get iterations;
/// Create a copy of MatrixCell
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MatrixCellCopyWith<MatrixCell> get copyWith => _$MatrixCellCopyWithImpl<MatrixCell>(this as MatrixCell, _$identity);

  /// Serializes this MatrixCell to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MatrixCell&&(identical(other.flowrunId, flowrunId) || other.flowrunId == flowrunId)&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.status, status) || other.status == status)&&(identical(other.iteration, iteration) || other.iteration == iteration)&&(identical(other.iterations, iterations) || other.iterations == iterations));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,flowrunId,nodeId,status,iteration,iterations);

@override
String toString() {
  return 'MatrixCell(flowrunId: $flowrunId, nodeId: $nodeId, status: $status, iteration: $iteration, iterations: $iterations)';
}


}

/// @nodoc
abstract mixin class $MatrixCellCopyWith<$Res>  {
  factory $MatrixCellCopyWith(MatrixCell value, $Res Function(MatrixCell) _then) = _$MatrixCellCopyWithImpl;
@useResult
$Res call({
 String flowrunId, String nodeId, String status, int iteration, int iterations
});




}
/// @nodoc
class _$MatrixCellCopyWithImpl<$Res>
    implements $MatrixCellCopyWith<$Res> {
  _$MatrixCellCopyWithImpl(this._self, this._then);

  final MatrixCell _self;
  final $Res Function(MatrixCell) _then;

/// Create a copy of MatrixCell
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? flowrunId = null,Object? nodeId = null,Object? status = null,Object? iteration = null,Object? iterations = null,}) {
  return _then(_self.copyWith(
flowrunId: null == flowrunId ? _self.flowrunId : flowrunId // ignore: cast_nullable_to_non_nullable
as String,nodeId: null == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,iteration: null == iteration ? _self.iteration : iteration // ignore: cast_nullable_to_non_nullable
as int,iterations: null == iterations ? _self.iterations : iterations // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MatrixCell].
extension MatrixCellPatterns on MatrixCell {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MatrixCell value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MatrixCell() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MatrixCell value)  $default,){
final _that = this;
switch (_that) {
case _MatrixCell():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MatrixCell value)?  $default,){
final _that = this;
switch (_that) {
case _MatrixCell() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String flowrunId,  String nodeId,  String status,  int iteration,  int iterations)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MatrixCell() when $default != null:
return $default(_that.flowrunId,_that.nodeId,_that.status,_that.iteration,_that.iterations);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String flowrunId,  String nodeId,  String status,  int iteration,  int iterations)  $default,) {final _that = this;
switch (_that) {
case _MatrixCell():
return $default(_that.flowrunId,_that.nodeId,_that.status,_that.iteration,_that.iterations);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String flowrunId,  String nodeId,  String status,  int iteration,  int iterations)?  $default,) {final _that = this;
switch (_that) {
case _MatrixCell() when $default != null:
return $default(_that.flowrunId,_that.nodeId,_that.status,_that.iteration,_that.iterations);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MatrixCell implements MatrixCell {
  const _MatrixCell({this.flowrunId = '', this.nodeId = '', this.status = '', this.iteration = 0, this.iterations = 1});
  factory _MatrixCell.fromJson(Map<String, dynamic> json) => _$MatrixCellFromJson(json);

@override@JsonKey() final  String flowrunId;
@override@JsonKey() final  String nodeId;
@override@JsonKey() final  String status;
@override@JsonKey() final  int iteration;
@override@JsonKey() final  int iterations;

/// Create a copy of MatrixCell
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MatrixCellCopyWith<_MatrixCell> get copyWith => __$MatrixCellCopyWithImpl<_MatrixCell>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MatrixCellToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MatrixCell&&(identical(other.flowrunId, flowrunId) || other.flowrunId == flowrunId)&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.status, status) || other.status == status)&&(identical(other.iteration, iteration) || other.iteration == iteration)&&(identical(other.iterations, iterations) || other.iterations == iterations));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,flowrunId,nodeId,status,iteration,iterations);

@override
String toString() {
  return 'MatrixCell(flowrunId: $flowrunId, nodeId: $nodeId, status: $status, iteration: $iteration, iterations: $iterations)';
}


}

/// @nodoc
abstract mixin class _$MatrixCellCopyWith<$Res> implements $MatrixCellCopyWith<$Res> {
  factory _$MatrixCellCopyWith(_MatrixCell value, $Res Function(_MatrixCell) _then) = __$MatrixCellCopyWithImpl;
@override @useResult
$Res call({
 String flowrunId, String nodeId, String status, int iteration, int iterations
});




}
/// @nodoc
class __$MatrixCellCopyWithImpl<$Res>
    implements _$MatrixCellCopyWith<$Res> {
  __$MatrixCellCopyWithImpl(this._self, this._then);

  final _MatrixCell _self;
  final $Res Function(_MatrixCell) _then;

/// Create a copy of MatrixCell
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? flowrunId = null,Object? nodeId = null,Object? status = null,Object? iteration = null,Object? iterations = null,}) {
  return _then(_MatrixCell(
flowrunId: null == flowrunId ? _self.flowrunId : flowrunId // ignore: cast_nullable_to_non_nullable
as String,nodeId: null == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,iteration: null == iteration ? _self.iteration : iteration // ignore: cast_nullable_to_non_nullable
as int,iterations: null == iterations ? _self.iterations : iterations // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$FlowrunMatrix {

 List<MatrixCol> get cols; List<MatrixRow> get rows; List<MatrixCell> get cells;
/// Create a copy of FlowrunMatrix
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FlowrunMatrixCopyWith<FlowrunMatrix> get copyWith => _$FlowrunMatrixCopyWithImpl<FlowrunMatrix>(this as FlowrunMatrix, _$identity);

  /// Serializes this FlowrunMatrix to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FlowrunMatrix&&const DeepCollectionEquality().equals(other.cols, cols)&&const DeepCollectionEquality().equals(other.rows, rows)&&const DeepCollectionEquality().equals(other.cells, cells));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(cols),const DeepCollectionEquality().hash(rows),const DeepCollectionEquality().hash(cells));

@override
String toString() {
  return 'FlowrunMatrix(cols: $cols, rows: $rows, cells: $cells)';
}


}

/// @nodoc
abstract mixin class $FlowrunMatrixCopyWith<$Res>  {
  factory $FlowrunMatrixCopyWith(FlowrunMatrix value, $Res Function(FlowrunMatrix) _then) = _$FlowrunMatrixCopyWithImpl;
@useResult
$Res call({
 List<MatrixCol> cols, List<MatrixRow> rows, List<MatrixCell> cells
});




}
/// @nodoc
class _$FlowrunMatrixCopyWithImpl<$Res>
    implements $FlowrunMatrixCopyWith<$Res> {
  _$FlowrunMatrixCopyWithImpl(this._self, this._then);

  final FlowrunMatrix _self;
  final $Res Function(FlowrunMatrix) _then;

/// Create a copy of FlowrunMatrix
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cols = null,Object? rows = null,Object? cells = null,}) {
  return _then(_self.copyWith(
cols: null == cols ? _self.cols : cols // ignore: cast_nullable_to_non_nullable
as List<MatrixCol>,rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as List<MatrixRow>,cells: null == cells ? _self.cells : cells // ignore: cast_nullable_to_non_nullable
as List<MatrixCell>,
  ));
}

}


/// Adds pattern-matching-related methods to [FlowrunMatrix].
extension FlowrunMatrixPatterns on FlowrunMatrix {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FlowrunMatrix value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FlowrunMatrix() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FlowrunMatrix value)  $default,){
final _that = this;
switch (_that) {
case _FlowrunMatrix():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FlowrunMatrix value)?  $default,){
final _that = this;
switch (_that) {
case _FlowrunMatrix() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<MatrixCol> cols,  List<MatrixRow> rows,  List<MatrixCell> cells)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FlowrunMatrix() when $default != null:
return $default(_that.cols,_that.rows,_that.cells);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<MatrixCol> cols,  List<MatrixRow> rows,  List<MatrixCell> cells)  $default,) {final _that = this;
switch (_that) {
case _FlowrunMatrix():
return $default(_that.cols,_that.rows,_that.cells);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<MatrixCol> cols,  List<MatrixRow> rows,  List<MatrixCell> cells)?  $default,) {final _that = this;
switch (_that) {
case _FlowrunMatrix() when $default != null:
return $default(_that.cols,_that.rows,_that.cells);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FlowrunMatrix implements FlowrunMatrix {
  const _FlowrunMatrix({final  List<MatrixCol> cols = const <MatrixCol>[], final  List<MatrixRow> rows = const <MatrixRow>[], final  List<MatrixCell> cells = const <MatrixCell>[]}): _cols = cols,_rows = rows,_cells = cells;
  factory _FlowrunMatrix.fromJson(Map<String, dynamic> json) => _$FlowrunMatrixFromJson(json);

 final  List<MatrixCol> _cols;
@override@JsonKey() List<MatrixCol> get cols {
  if (_cols is EqualUnmodifiableListView) return _cols;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_cols);
}

 final  List<MatrixRow> _rows;
@override@JsonKey() List<MatrixRow> get rows {
  if (_rows is EqualUnmodifiableListView) return _rows;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rows);
}

 final  List<MatrixCell> _cells;
@override@JsonKey() List<MatrixCell> get cells {
  if (_cells is EqualUnmodifiableListView) return _cells;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_cells);
}


/// Create a copy of FlowrunMatrix
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FlowrunMatrixCopyWith<_FlowrunMatrix> get copyWith => __$FlowrunMatrixCopyWithImpl<_FlowrunMatrix>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FlowrunMatrixToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FlowrunMatrix&&const DeepCollectionEquality().equals(other._cols, _cols)&&const DeepCollectionEquality().equals(other._rows, _rows)&&const DeepCollectionEquality().equals(other._cells, _cells));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_cols),const DeepCollectionEquality().hash(_rows),const DeepCollectionEquality().hash(_cells));

@override
String toString() {
  return 'FlowrunMatrix(cols: $cols, rows: $rows, cells: $cells)';
}


}

/// @nodoc
abstract mixin class _$FlowrunMatrixCopyWith<$Res> implements $FlowrunMatrixCopyWith<$Res> {
  factory _$FlowrunMatrixCopyWith(_FlowrunMatrix value, $Res Function(_FlowrunMatrix) _then) = __$FlowrunMatrixCopyWithImpl;
@override @useResult
$Res call({
 List<MatrixCol> cols, List<MatrixRow> rows, List<MatrixCell> cells
});




}
/// @nodoc
class __$FlowrunMatrixCopyWithImpl<$Res>
    implements _$FlowrunMatrixCopyWith<$Res> {
  __$FlowrunMatrixCopyWithImpl(this._self, this._then);

  final _FlowrunMatrix _self;
  final $Res Function(_FlowrunMatrix) _then;

/// Create a copy of FlowrunMatrix
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cols = null,Object? rows = null,Object? cells = null,}) {
  return _then(_FlowrunMatrix(
cols: null == cols ? _self._cols : cols // ignore: cast_nullable_to_non_nullable
as List<MatrixCol>,rows: null == rows ? _self._rows : rows // ignore: cast_nullable_to_non_nullable
as List<MatrixRow>,cells: null == cells ? _self._cells : cells // ignore: cast_nullable_to_non_nullable
as List<MatrixCell>,
  ));
}


}

// dart format on
