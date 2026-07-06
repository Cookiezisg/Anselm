// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_feed_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NotificationFeedState {

 List<NotificationItem> get rows; String? get nextCursor; bool get hasMore; bool get loadingMore;
/// Create a copy of NotificationFeedState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationFeedStateCopyWith<NotificationFeedState> get copyWith => _$NotificationFeedStateCopyWithImpl<NotificationFeedState>(this as NotificationFeedState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationFeedState&&const DeepCollectionEquality().equals(other.rows, rows)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(rows),nextCursor,hasMore,loadingMore);

@override
String toString() {
  return 'NotificationFeedState(rows: $rows, nextCursor: $nextCursor, hasMore: $hasMore, loadingMore: $loadingMore)';
}


}

/// @nodoc
abstract mixin class $NotificationFeedStateCopyWith<$Res>  {
  factory $NotificationFeedStateCopyWith(NotificationFeedState value, $Res Function(NotificationFeedState) _then) = _$NotificationFeedStateCopyWithImpl;
@useResult
$Res call({
 List<NotificationItem> rows, String? nextCursor, bool hasMore, bool loadingMore
});




}
/// @nodoc
class _$NotificationFeedStateCopyWithImpl<$Res>
    implements $NotificationFeedStateCopyWith<$Res> {
  _$NotificationFeedStateCopyWithImpl(this._self, this._then);

  final NotificationFeedState _self;
  final $Res Function(NotificationFeedState) _then;

/// Create a copy of NotificationFeedState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rows = null,Object? nextCursor = freezed,Object? hasMore = null,Object? loadingMore = null,}) {
  return _then(_self.copyWith(
rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as List<NotificationItem>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationFeedState].
extension NotificationFeedStatePatterns on NotificationFeedState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationFeedState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationFeedState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationFeedState value)  $default,){
final _that = this;
switch (_that) {
case _NotificationFeedState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationFeedState value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationFeedState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<NotificationItem> rows,  String? nextCursor,  bool hasMore,  bool loadingMore)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationFeedState() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<NotificationItem> rows,  String? nextCursor,  bool hasMore,  bool loadingMore)  $default,) {final _that = this;
switch (_that) {
case _NotificationFeedState():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<NotificationItem> rows,  String? nextCursor,  bool hasMore,  bool loadingMore)?  $default,) {final _that = this;
switch (_that) {
case _NotificationFeedState() when $default != null:
return $default(_that.rows,_that.nextCursor,_that.hasMore,_that.loadingMore);case _:
  return null;

}
}

}

/// @nodoc


class _NotificationFeedState implements NotificationFeedState {
  const _NotificationFeedState({final  List<NotificationItem> rows = const <NotificationItem>[], this.nextCursor, this.hasMore = false, this.loadingMore = false}): _rows = rows;
  

 final  List<NotificationItem> _rows;
@override@JsonKey() List<NotificationItem> get rows {
  if (_rows is EqualUnmodifiableListView) return _rows;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rows);
}

@override final  String? nextCursor;
@override@JsonKey() final  bool hasMore;
@override@JsonKey() final  bool loadingMore;

/// Create a copy of NotificationFeedState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationFeedStateCopyWith<_NotificationFeedState> get copyWith => __$NotificationFeedStateCopyWithImpl<_NotificationFeedState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationFeedState&&const DeepCollectionEquality().equals(other._rows, _rows)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_rows),nextCursor,hasMore,loadingMore);

@override
String toString() {
  return 'NotificationFeedState(rows: $rows, nextCursor: $nextCursor, hasMore: $hasMore, loadingMore: $loadingMore)';
}


}

/// @nodoc
abstract mixin class _$NotificationFeedStateCopyWith<$Res> implements $NotificationFeedStateCopyWith<$Res> {
  factory _$NotificationFeedStateCopyWith(_NotificationFeedState value, $Res Function(_NotificationFeedState) _then) = __$NotificationFeedStateCopyWithImpl;
@override @useResult
$Res call({
 List<NotificationItem> rows, String? nextCursor, bool hasMore, bool loadingMore
});




}
/// @nodoc
class __$NotificationFeedStateCopyWithImpl<$Res>
    implements _$NotificationFeedStateCopyWith<$Res> {
  __$NotificationFeedStateCopyWithImpl(this._self, this._then);

  final _NotificationFeedState _self;
  final $Res Function(_NotificationFeedState) _then;

/// Create a copy of NotificationFeedState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rows = null,Object? nextCursor = freezed,Object? hasMore = null,Object? loadingMore = null,}) {
  return _then(_NotificationFeedState(
rows: null == rows ? _self._rows : rows // ignore: cast_nullable_to_non_nullable
as List<NotificationItem>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
