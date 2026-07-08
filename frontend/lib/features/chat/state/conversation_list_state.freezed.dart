// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conversation_list_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConversationListState {

 List<Conversation> get rows; String? get nextCursor; bool get hasMore; bool get loadingMore;// The loadMore tail FAILED (WRK-059 M9): the rail swaps the auto-firing sentinel for a manual
// retry row — a persistent server error must not become a per-RTT retry storm.
// loadMore 尾部失败(M9):rail 把自动触发哨兵换成手动重试行——持久服务端错误绝不成 per-RTT 风暴。
 bool get loadMoreFailed;
/// Create a copy of ConversationListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationListStateCopyWith<ConversationListState> get copyWith => _$ConversationListStateCopyWithImpl<ConversationListState>(this as ConversationListState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationListState&&const DeepCollectionEquality().equals(other.rows, rows)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&(identical(other.loadMoreFailed, loadMoreFailed) || other.loadMoreFailed == loadMoreFailed));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(rows),nextCursor,hasMore,loadingMore,loadMoreFailed);

@override
String toString() {
  return 'ConversationListState(rows: $rows, nextCursor: $nextCursor, hasMore: $hasMore, loadingMore: $loadingMore, loadMoreFailed: $loadMoreFailed)';
}


}

/// @nodoc
abstract mixin class $ConversationListStateCopyWith<$Res>  {
  factory $ConversationListStateCopyWith(ConversationListState value, $Res Function(ConversationListState) _then) = _$ConversationListStateCopyWithImpl;
@useResult
$Res call({
 List<Conversation> rows, String? nextCursor, bool hasMore, bool loadingMore, bool loadMoreFailed
});




}
/// @nodoc
class _$ConversationListStateCopyWithImpl<$Res>
    implements $ConversationListStateCopyWith<$Res> {
  _$ConversationListStateCopyWithImpl(this._self, this._then);

  final ConversationListState _self;
  final $Res Function(ConversationListState) _then;

/// Create a copy of ConversationListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rows = null,Object? nextCursor = freezed,Object? hasMore = null,Object? loadingMore = null,Object? loadMoreFailed = null,}) {
  return _then(_self.copyWith(
rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as List<Conversation>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,loadMoreFailed: null == loadMoreFailed ? _self.loadMoreFailed : loadMoreFailed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ConversationListState].
extension ConversationListStatePatterns on ConversationListState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConversationListState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConversationListState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConversationListState value)  $default,){
final _that = this;
switch (_that) {
case _ConversationListState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConversationListState value)?  $default,){
final _that = this;
switch (_that) {
case _ConversationListState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Conversation> rows,  String? nextCursor,  bool hasMore,  bool loadingMore,  bool loadMoreFailed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConversationListState() when $default != null:
return $default(_that.rows,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.loadMoreFailed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Conversation> rows,  String? nextCursor,  bool hasMore,  bool loadingMore,  bool loadMoreFailed)  $default,) {final _that = this;
switch (_that) {
case _ConversationListState():
return $default(_that.rows,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.loadMoreFailed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Conversation> rows,  String? nextCursor,  bool hasMore,  bool loadingMore,  bool loadMoreFailed)?  $default,) {final _that = this;
switch (_that) {
case _ConversationListState() when $default != null:
return $default(_that.rows,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.loadMoreFailed);case _:
  return null;

}
}

}

/// @nodoc


class _ConversationListState implements ConversationListState {
  const _ConversationListState({final  List<Conversation> rows = const <Conversation>[], this.nextCursor, this.hasMore = false, this.loadingMore = false, this.loadMoreFailed = false}): _rows = rows;
  

 final  List<Conversation> _rows;
@override@JsonKey() List<Conversation> get rows {
  if (_rows is EqualUnmodifiableListView) return _rows;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rows);
}

@override final  String? nextCursor;
@override@JsonKey() final  bool hasMore;
@override@JsonKey() final  bool loadingMore;
// The loadMore tail FAILED (WRK-059 M9): the rail swaps the auto-firing sentinel for a manual
// retry row — a persistent server error must not become a per-RTT retry storm.
// loadMore 尾部失败(M9):rail 把自动触发哨兵换成手动重试行——持久服务端错误绝不成 per-RTT 风暴。
@override@JsonKey() final  bool loadMoreFailed;

/// Create a copy of ConversationListState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversationListStateCopyWith<_ConversationListState> get copyWith => __$ConversationListStateCopyWithImpl<_ConversationListState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConversationListState&&const DeepCollectionEquality().equals(other._rows, _rows)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&(identical(other.loadMoreFailed, loadMoreFailed) || other.loadMoreFailed == loadMoreFailed));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_rows),nextCursor,hasMore,loadingMore,loadMoreFailed);

@override
String toString() {
  return 'ConversationListState(rows: $rows, nextCursor: $nextCursor, hasMore: $hasMore, loadingMore: $loadingMore, loadMoreFailed: $loadMoreFailed)';
}


}

/// @nodoc
abstract mixin class _$ConversationListStateCopyWith<$Res> implements $ConversationListStateCopyWith<$Res> {
  factory _$ConversationListStateCopyWith(_ConversationListState value, $Res Function(_ConversationListState) _then) = __$ConversationListStateCopyWithImpl;
@override @useResult
$Res call({
 List<Conversation> rows, String? nextCursor, bool hasMore, bool loadingMore, bool loadMoreFailed
});




}
/// @nodoc
class __$ConversationListStateCopyWithImpl<$Res>
    implements _$ConversationListStateCopyWith<$Res> {
  __$ConversationListStateCopyWithImpl(this._self, this._then);

  final _ConversationListState _self;
  final $Res Function(_ConversationListState) _then;

/// Create a copy of ConversationListState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rows = null,Object? nextCursor = freezed,Object? hasMore = null,Object? loadingMore = null,Object? loadMoreFailed = null,}) {
  return _then(_ConversationListState(
rows: null == rows ? _self._rows : rows // ignore: cast_nullable_to_non_nullable
as List<Conversation>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,loadMoreFailed: null == loadMoreFailed ? _self.loadMoreFailed : loadMoreFailed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
