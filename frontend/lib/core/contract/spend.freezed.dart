// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'spend.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SpendRow {

 String get date; String get category; String get provider; String get model; int get units;@JsonKey(name: 'estPUSD') int get estPUSD;
/// Create a copy of SpendRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpendRowCopyWith<SpendRow> get copyWith => _$SpendRowCopyWithImpl<SpendRow>(this as SpendRow, _$identity);

  /// Serializes this SpendRow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpendRow&&(identical(other.date, date) || other.date == date)&&(identical(other.category, category) || other.category == category)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.model, model) || other.model == model)&&(identical(other.units, units) || other.units == units)&&(identical(other.estPUSD, estPUSD) || other.estPUSD == estPUSD));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,category,provider,model,units,estPUSD);

@override
String toString() {
  return 'SpendRow(date: $date, category: $category, provider: $provider, model: $model, units: $units, estPUSD: $estPUSD)';
}


}

/// @nodoc
abstract mixin class $SpendRowCopyWith<$Res>  {
  factory $SpendRowCopyWith(SpendRow value, $Res Function(SpendRow) _then) = _$SpendRowCopyWithImpl;
@useResult
$Res call({
 String date, String category, String provider, String model, int units,@JsonKey(name: 'estPUSD') int estPUSD
});




}
/// @nodoc
class _$SpendRowCopyWithImpl<$Res>
    implements $SpendRowCopyWith<$Res> {
  _$SpendRowCopyWithImpl(this._self, this._then);

  final SpendRow _self;
  final $Res Function(SpendRow) _then;

/// Create a copy of SpendRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? category = null,Object? provider = null,Object? model = null,Object? units = null,Object? estPUSD = null,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,units: null == units ? _self.units : units // ignore: cast_nullable_to_non_nullable
as int,estPUSD: null == estPUSD ? _self.estPUSD : estPUSD // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SpendRow].
extension SpendRowPatterns on SpendRow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpendRow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpendRow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpendRow value)  $default,){
final _that = this;
switch (_that) {
case _SpendRow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpendRow value)?  $default,){
final _that = this;
switch (_that) {
case _SpendRow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String date,  String category,  String provider,  String model,  int units, @JsonKey(name: 'estPUSD')  int estPUSD)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpendRow() when $default != null:
return $default(_that.date,_that.category,_that.provider,_that.model,_that.units,_that.estPUSD);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String date,  String category,  String provider,  String model,  int units, @JsonKey(name: 'estPUSD')  int estPUSD)  $default,) {final _that = this;
switch (_that) {
case _SpendRow():
return $default(_that.date,_that.category,_that.provider,_that.model,_that.units,_that.estPUSD);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String date,  String category,  String provider,  String model,  int units, @JsonKey(name: 'estPUSD')  int estPUSD)?  $default,) {final _that = this;
switch (_that) {
case _SpendRow() when $default != null:
return $default(_that.date,_that.category,_that.provider,_that.model,_that.units,_that.estPUSD);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SpendRow implements SpendRow {
  const _SpendRow({this.date = '', this.category = '', this.provider = '', this.model = '', this.units = 0, @JsonKey(name: 'estPUSD') this.estPUSD = 0});
  factory _SpendRow.fromJson(Map<String, dynamic> json) => _$SpendRowFromJson(json);

@override@JsonKey() final  String date;
@override@JsonKey() final  String category;
@override@JsonKey() final  String provider;
@override@JsonKey() final  String model;
@override@JsonKey() final  int units;
@override@JsonKey(name: 'estPUSD') final  int estPUSD;

/// Create a copy of SpendRow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpendRowCopyWith<_SpendRow> get copyWith => __$SpendRowCopyWithImpl<_SpendRow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SpendRowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpendRow&&(identical(other.date, date) || other.date == date)&&(identical(other.category, category) || other.category == category)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.model, model) || other.model == model)&&(identical(other.units, units) || other.units == units)&&(identical(other.estPUSD, estPUSD) || other.estPUSD == estPUSD));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,category,provider,model,units,estPUSD);

@override
String toString() {
  return 'SpendRow(date: $date, category: $category, provider: $provider, model: $model, units: $units, estPUSD: $estPUSD)';
}


}

/// @nodoc
abstract mixin class _$SpendRowCopyWith<$Res> implements $SpendRowCopyWith<$Res> {
  factory _$SpendRowCopyWith(_SpendRow value, $Res Function(_SpendRow) _then) = __$SpendRowCopyWithImpl;
@override @useResult
$Res call({
 String date, String category, String provider, String model, int units,@JsonKey(name: 'estPUSD') int estPUSD
});




}
/// @nodoc
class __$SpendRowCopyWithImpl<$Res>
    implements _$SpendRowCopyWith<$Res> {
  __$SpendRowCopyWithImpl(this._self, this._then);

  final _SpendRow _self;
  final $Res Function(_SpendRow) _then;

/// Create a copy of SpendRow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? category = null,Object? provider = null,Object? model = null,Object? units = null,Object? estPUSD = null,}) {
  return _then(_SpendRow(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,units: null == units ? _self.units : units // ignore: cast_nullable_to_non_nullable
as int,estPUSD: null == estPUSD ? _self.estPUSD : estPUSD // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
