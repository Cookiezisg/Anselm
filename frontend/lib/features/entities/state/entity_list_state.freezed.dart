// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'entity_list_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$EntityListState {

 List<EntityRow> get rows; String? get nextCursor; bool get hasMore; bool get loadingMore;
/// Create a copy of EntityListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EntityListStateCopyWith<EntityListState> get copyWith => _$EntityListStateCopyWithImpl<EntityListState>(this as EntityListState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EntityListState&&const DeepCollectionEquality().equals(other.rows, rows)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(rows),nextCursor,hasMore,loadingMore);

@override
String toString() {
  return 'EntityListState(rows: $rows, nextCursor: $nextCursor, hasMore: $hasMore, loadingMore: $loadingMore)';
}


}

/// @nodoc
abstract mixin class $EntityListStateCopyWith<$Res>  {
  factory $EntityListStateCopyWith(EntityListState value, $Res Function(EntityListState) _then) = _$EntityListStateCopyWithImpl;
@useResult
$Res call({
 List<EntityRow> rows, String? nextCursor, bool hasMore, bool loadingMore
});




}
/// @nodoc
class _$EntityListStateCopyWithImpl<$Res>
    implements $EntityListStateCopyWith<$Res> {
  _$EntityListStateCopyWithImpl(this._self, this._then);

  final EntityListState _self;
  final $Res Function(EntityListState) _then;

/// Create a copy of EntityListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rows = null,Object? nextCursor = freezed,Object? hasMore = null,Object? loadingMore = null,}) {
  return _then(_self.copyWith(
rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as List<EntityRow>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [EntityListState].
extension EntityListStatePatterns on EntityListState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EntityListState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EntityListState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EntityListState value)  $default,){
final _that = this;
switch (_that) {
case _EntityListState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EntityListState value)?  $default,){
final _that = this;
switch (_that) {
case _EntityListState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<EntityRow> rows,  String? nextCursor,  bool hasMore,  bool loadingMore)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EntityListState() when $default != null:
return $default(_that.rows,_that.nextCursor,_that.hasMore,_that.loadingMore);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<EntityRow> rows,  String? nextCursor,  bool hasMore,  bool loadingMore)  $default,) {final _that = this;
switch (_that) {
case _EntityListState():
return $default(_that.rows,_that.nextCursor,_that.hasMore,_that.loadingMore);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<EntityRow> rows,  String? nextCursor,  bool hasMore,  bool loadingMore)?  $default,) {final _that = this;
switch (_that) {
case _EntityListState() when $default != null:
return $default(_that.rows,_that.nextCursor,_that.hasMore,_that.loadingMore);case _:
  return null;

}
}

}

/// @nodoc


class _EntityListState implements EntityListState {
  const _EntityListState({final  List<EntityRow> rows = const <EntityRow>[], this.nextCursor, this.hasMore = false, this.loadingMore = false}): _rows = rows;
  

 final  List<EntityRow> _rows;
@override@JsonKey() List<EntityRow> get rows {
  if (_rows is EqualUnmodifiableListView) return _rows;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rows);
}

@override final  String? nextCursor;
@override@JsonKey() final  bool hasMore;
@override@JsonKey() final  bool loadingMore;

/// Create a copy of EntityListState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EntityListStateCopyWith<_EntityListState> get copyWith => __$EntityListStateCopyWithImpl<_EntityListState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EntityListState&&const DeepCollectionEquality().equals(other._rows, _rows)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_rows),nextCursor,hasMore,loadingMore);

@override
String toString() {
  return 'EntityListState(rows: $rows, nextCursor: $nextCursor, hasMore: $hasMore, loadingMore: $loadingMore)';
}


}

/// @nodoc
abstract mixin class _$EntityListStateCopyWith<$Res> implements $EntityListStateCopyWith<$Res> {
  factory _$EntityListStateCopyWith(_EntityListState value, $Res Function(_EntityListState) _then) = __$EntityListStateCopyWithImpl;
@override @useResult
$Res call({
 List<EntityRow> rows, String? nextCursor, bool hasMore, bool loadingMore
});




}
/// @nodoc
class __$EntityListStateCopyWithImpl<$Res>
    implements _$EntityListStateCopyWith<$Res> {
  __$EntityListStateCopyWithImpl(this._self, this._then);

  final _EntityListState _self;
  final $Res Function(_EntityListState) _then;

/// Create a copy of EntityListState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rows = null,Object? nextCursor = freezed,Object? hasMore = null,Object? loadingMore = null,}) {
  return _then(_EntityListState(
rows: null == rows ? _self._rows : rows // ignore: cast_nullable_to_non_nullable
as List<EntityRow>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
