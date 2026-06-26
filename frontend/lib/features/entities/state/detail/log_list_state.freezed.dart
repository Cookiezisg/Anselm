// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'log_list_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LogListState {

 List<LogRow> get rows; ExecutionAggregates get aggregates; bool get hasAggregate; String? get nextCursor; bool get hasMore; bool get loadingMore; Set<String> get openIds; Map<String, FlowrunComposite> get flowruns;
/// Create a copy of LogListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LogListStateCopyWith<LogListState> get copyWith => _$LogListStateCopyWithImpl<LogListState>(this as LogListState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LogListState&&const DeepCollectionEquality().equals(other.rows, rows)&&(identical(other.aggregates, aggregates) || other.aggregates == aggregates)&&(identical(other.hasAggregate, hasAggregate) || other.hasAggregate == hasAggregate)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&const DeepCollectionEquality().equals(other.openIds, openIds)&&const DeepCollectionEquality().equals(other.flowruns, flowruns));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(rows),aggregates,hasAggregate,nextCursor,hasMore,loadingMore,const DeepCollectionEquality().hash(openIds),const DeepCollectionEquality().hash(flowruns));

@override
String toString() {
  return 'LogListState(rows: $rows, aggregates: $aggregates, hasAggregate: $hasAggregate, nextCursor: $nextCursor, hasMore: $hasMore, loadingMore: $loadingMore, openIds: $openIds, flowruns: $flowruns)';
}


}

/// @nodoc
abstract mixin class $LogListStateCopyWith<$Res>  {
  factory $LogListStateCopyWith(LogListState value, $Res Function(LogListState) _then) = _$LogListStateCopyWithImpl;
@useResult
$Res call({
 List<LogRow> rows, ExecutionAggregates aggregates, bool hasAggregate, String? nextCursor, bool hasMore, bool loadingMore, Set<String> openIds, Map<String, FlowrunComposite> flowruns
});


$ExecutionAggregatesCopyWith<$Res> get aggregates;

}
/// @nodoc
class _$LogListStateCopyWithImpl<$Res>
    implements $LogListStateCopyWith<$Res> {
  _$LogListStateCopyWithImpl(this._self, this._then);

  final LogListState _self;
  final $Res Function(LogListState) _then;

/// Create a copy of LogListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rows = null,Object? aggregates = null,Object? hasAggregate = null,Object? nextCursor = freezed,Object? hasMore = null,Object? loadingMore = null,Object? openIds = null,Object? flowruns = null,}) {
  return _then(_self.copyWith(
rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as List<LogRow>,aggregates: null == aggregates ? _self.aggregates : aggregates // ignore: cast_nullable_to_non_nullable
as ExecutionAggregates,hasAggregate: null == hasAggregate ? _self.hasAggregate : hasAggregate // ignore: cast_nullable_to_non_nullable
as bool,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,openIds: null == openIds ? _self.openIds : openIds // ignore: cast_nullable_to_non_nullable
as Set<String>,flowruns: null == flowruns ? _self.flowruns : flowruns // ignore: cast_nullable_to_non_nullable
as Map<String, FlowrunComposite>,
  ));
}
/// Create a copy of LogListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExecutionAggregatesCopyWith<$Res> get aggregates {
  
  return $ExecutionAggregatesCopyWith<$Res>(_self.aggregates, (value) {
    return _then(_self.copyWith(aggregates: value));
  });
}
}


/// Adds pattern-matching-related methods to [LogListState].
extension LogListStatePatterns on LogListState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LogListState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LogListState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LogListState value)  $default,){
final _that = this;
switch (_that) {
case _LogListState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LogListState value)?  $default,){
final _that = this;
switch (_that) {
case _LogListState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<LogRow> rows,  ExecutionAggregates aggregates,  bool hasAggregate,  String? nextCursor,  bool hasMore,  bool loadingMore,  Set<String> openIds,  Map<String, FlowrunComposite> flowruns)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LogListState() when $default != null:
return $default(_that.rows,_that.aggregates,_that.hasAggregate,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.openIds,_that.flowruns);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<LogRow> rows,  ExecutionAggregates aggregates,  bool hasAggregate,  String? nextCursor,  bool hasMore,  bool loadingMore,  Set<String> openIds,  Map<String, FlowrunComposite> flowruns)  $default,) {final _that = this;
switch (_that) {
case _LogListState():
return $default(_that.rows,_that.aggregates,_that.hasAggregate,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.openIds,_that.flowruns);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<LogRow> rows,  ExecutionAggregates aggregates,  bool hasAggregate,  String? nextCursor,  bool hasMore,  bool loadingMore,  Set<String> openIds,  Map<String, FlowrunComposite> flowruns)?  $default,) {final _that = this;
switch (_that) {
case _LogListState() when $default != null:
return $default(_that.rows,_that.aggregates,_that.hasAggregate,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.openIds,_that.flowruns);case _:
  return null;

}
}

}

/// @nodoc


class _LogListState implements LogListState {
  const _LogListState({final  List<LogRow> rows = const <LogRow>[], this.aggregates = const ExecutionAggregates(), this.hasAggregate = false, this.nextCursor, this.hasMore = false, this.loadingMore = false, final  Set<String> openIds = const <String>{}, final  Map<String, FlowrunComposite> flowruns = const <String, FlowrunComposite>{}}): _rows = rows,_openIds = openIds,_flowruns = flowruns;
  

 final  List<LogRow> _rows;
@override@JsonKey() List<LogRow> get rows {
  if (_rows is EqualUnmodifiableListView) return _rows;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rows);
}

@override@JsonKey() final  ExecutionAggregates aggregates;
@override@JsonKey() final  bool hasAggregate;
@override final  String? nextCursor;
@override@JsonKey() final  bool hasMore;
@override@JsonKey() final  bool loadingMore;
 final  Set<String> _openIds;
@override@JsonKey() Set<String> get openIds {
  if (_openIds is EqualUnmodifiableSetView) return _openIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_openIds);
}

 final  Map<String, FlowrunComposite> _flowruns;
@override@JsonKey() Map<String, FlowrunComposite> get flowruns {
  if (_flowruns is EqualUnmodifiableMapView) return _flowruns;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_flowruns);
}


/// Create a copy of LogListState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LogListStateCopyWith<_LogListState> get copyWith => __$LogListStateCopyWithImpl<_LogListState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LogListState&&const DeepCollectionEquality().equals(other._rows, _rows)&&(identical(other.aggregates, aggregates) || other.aggregates == aggregates)&&(identical(other.hasAggregate, hasAggregate) || other.hasAggregate == hasAggregate)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&const DeepCollectionEquality().equals(other._openIds, _openIds)&&const DeepCollectionEquality().equals(other._flowruns, _flowruns));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_rows),aggregates,hasAggregate,nextCursor,hasMore,loadingMore,const DeepCollectionEquality().hash(_openIds),const DeepCollectionEquality().hash(_flowruns));

@override
String toString() {
  return 'LogListState(rows: $rows, aggregates: $aggregates, hasAggregate: $hasAggregate, nextCursor: $nextCursor, hasMore: $hasMore, loadingMore: $loadingMore, openIds: $openIds, flowruns: $flowruns)';
}


}

/// @nodoc
abstract mixin class _$LogListStateCopyWith<$Res> implements $LogListStateCopyWith<$Res> {
  factory _$LogListStateCopyWith(_LogListState value, $Res Function(_LogListState) _then) = __$LogListStateCopyWithImpl;
@override @useResult
$Res call({
 List<LogRow> rows, ExecutionAggregates aggregates, bool hasAggregate, String? nextCursor, bool hasMore, bool loadingMore, Set<String> openIds, Map<String, FlowrunComposite> flowruns
});


@override $ExecutionAggregatesCopyWith<$Res> get aggregates;

}
/// @nodoc
class __$LogListStateCopyWithImpl<$Res>
    implements _$LogListStateCopyWith<$Res> {
  __$LogListStateCopyWithImpl(this._self, this._then);

  final _LogListState _self;
  final $Res Function(_LogListState) _then;

/// Create a copy of LogListState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rows = null,Object? aggregates = null,Object? hasAggregate = null,Object? nextCursor = freezed,Object? hasMore = null,Object? loadingMore = null,Object? openIds = null,Object? flowruns = null,}) {
  return _then(_LogListState(
rows: null == rows ? _self._rows : rows // ignore: cast_nullable_to_non_nullable
as List<LogRow>,aggregates: null == aggregates ? _self.aggregates : aggregates // ignore: cast_nullable_to_non_nullable
as ExecutionAggregates,hasAggregate: null == hasAggregate ? _self.hasAggregate : hasAggregate // ignore: cast_nullable_to_non_nullable
as bool,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,openIds: null == openIds ? _self._openIds : openIds // ignore: cast_nullable_to_non_nullable
as Set<String>,flowruns: null == flowruns ? _self._flowruns : flowruns // ignore: cast_nullable_to_non_nullable
as Map<String, FlowrunComposite>,
  ));
}

/// Create a copy of LogListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExecutionAggregatesCopyWith<$Res> get aggregates {
  
  return $ExecutionAggregatesCopyWith<$Res>(_self.aggregates, (value) {
    return _then(_self.copyWith(aggregates: value));
  });
}
}

// dart format on
