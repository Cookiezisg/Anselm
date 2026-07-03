// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'run_cockpit_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RunCockpitState {

 List<Flowrun> get runs; String? get nextCursor; bool get hasMore; bool get loadingMore; String? get selectedRunId; FlowrunComposite? get selected;// the full composite of [selectedRunId] 选中 run 的完整 composite
 bool get loadingRun; String? get selectedNodeId; bool get busy;
/// Create a copy of RunCockpitState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RunCockpitStateCopyWith<RunCockpitState> get copyWith => _$RunCockpitStateCopyWithImpl<RunCockpitState>(this as RunCockpitState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RunCockpitState&&const DeepCollectionEquality().equals(other.runs, runs)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&(identical(other.selectedRunId, selectedRunId) || other.selectedRunId == selectedRunId)&&(identical(other.selected, selected) || other.selected == selected)&&(identical(other.loadingRun, loadingRun) || other.loadingRun == loadingRun)&&(identical(other.selectedNodeId, selectedNodeId) || other.selectedNodeId == selectedNodeId)&&(identical(other.busy, busy) || other.busy == busy));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(runs),nextCursor,hasMore,loadingMore,selectedRunId,selected,loadingRun,selectedNodeId,busy);

@override
String toString() {
  return 'RunCockpitState(runs: $runs, nextCursor: $nextCursor, hasMore: $hasMore, loadingMore: $loadingMore, selectedRunId: $selectedRunId, selected: $selected, loadingRun: $loadingRun, selectedNodeId: $selectedNodeId, busy: $busy)';
}


}

/// @nodoc
abstract mixin class $RunCockpitStateCopyWith<$Res>  {
  factory $RunCockpitStateCopyWith(RunCockpitState value, $Res Function(RunCockpitState) _then) = _$RunCockpitStateCopyWithImpl;
@useResult
$Res call({
 List<Flowrun> runs, String? nextCursor, bool hasMore, bool loadingMore, String? selectedRunId, FlowrunComposite? selected, bool loadingRun, String? selectedNodeId, bool busy
});


$FlowrunCompositeCopyWith<$Res>? get selected;

}
/// @nodoc
class _$RunCockpitStateCopyWithImpl<$Res>
    implements $RunCockpitStateCopyWith<$Res> {
  _$RunCockpitStateCopyWithImpl(this._self, this._then);

  final RunCockpitState _self;
  final $Res Function(RunCockpitState) _then;

/// Create a copy of RunCockpitState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? runs = null,Object? nextCursor = freezed,Object? hasMore = null,Object? loadingMore = null,Object? selectedRunId = freezed,Object? selected = freezed,Object? loadingRun = null,Object? selectedNodeId = freezed,Object? busy = null,}) {
  return _then(_self.copyWith(
runs: null == runs ? _self.runs : runs // ignore: cast_nullable_to_non_nullable
as List<Flowrun>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,selectedRunId: freezed == selectedRunId ? _self.selectedRunId : selectedRunId // ignore: cast_nullable_to_non_nullable
as String?,selected: freezed == selected ? _self.selected : selected // ignore: cast_nullable_to_non_nullable
as FlowrunComposite?,loadingRun: null == loadingRun ? _self.loadingRun : loadingRun // ignore: cast_nullable_to_non_nullable
as bool,selectedNodeId: freezed == selectedNodeId ? _self.selectedNodeId : selectedNodeId // ignore: cast_nullable_to_non_nullable
as String?,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of RunCockpitState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FlowrunCompositeCopyWith<$Res>? get selected {
    if (_self.selected == null) {
    return null;
  }

  return $FlowrunCompositeCopyWith<$Res>(_self.selected!, (value) {
    return _then(_self.copyWith(selected: value));
  });
}
}


/// Adds pattern-matching-related methods to [RunCockpitState].
extension RunCockpitStatePatterns on RunCockpitState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RunCockpitState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RunCockpitState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RunCockpitState value)  $default,){
final _that = this;
switch (_that) {
case _RunCockpitState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RunCockpitState value)?  $default,){
final _that = this;
switch (_that) {
case _RunCockpitState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Flowrun> runs,  String? nextCursor,  bool hasMore,  bool loadingMore,  String? selectedRunId,  FlowrunComposite? selected,  bool loadingRun,  String? selectedNodeId,  bool busy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RunCockpitState() when $default != null:
return $default(_that.runs,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.selectedRunId,_that.selected,_that.loadingRun,_that.selectedNodeId,_that.busy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Flowrun> runs,  String? nextCursor,  bool hasMore,  bool loadingMore,  String? selectedRunId,  FlowrunComposite? selected,  bool loadingRun,  String? selectedNodeId,  bool busy)  $default,) {final _that = this;
switch (_that) {
case _RunCockpitState():
return $default(_that.runs,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.selectedRunId,_that.selected,_that.loadingRun,_that.selectedNodeId,_that.busy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Flowrun> runs,  String? nextCursor,  bool hasMore,  bool loadingMore,  String? selectedRunId,  FlowrunComposite? selected,  bool loadingRun,  String? selectedNodeId,  bool busy)?  $default,) {final _that = this;
switch (_that) {
case _RunCockpitState() when $default != null:
return $default(_that.runs,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.selectedRunId,_that.selected,_that.loadingRun,_that.selectedNodeId,_that.busy);case _:
  return null;

}
}

}

/// @nodoc


class _RunCockpitState extends RunCockpitState {
  const _RunCockpitState({final  List<Flowrun> runs = const <Flowrun>[], this.nextCursor, this.hasMore = false, this.loadingMore = false, this.selectedRunId, this.selected, this.loadingRun = false, this.selectedNodeId, this.busy = false}): _runs = runs,super._();
  

 final  List<Flowrun> _runs;
@override@JsonKey() List<Flowrun> get runs {
  if (_runs is EqualUnmodifiableListView) return _runs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_runs);
}

@override final  String? nextCursor;
@override@JsonKey() final  bool hasMore;
@override@JsonKey() final  bool loadingMore;
@override final  String? selectedRunId;
@override final  FlowrunComposite? selected;
// the full composite of [selectedRunId] 选中 run 的完整 composite
@override@JsonKey() final  bool loadingRun;
@override final  String? selectedNodeId;
@override@JsonKey() final  bool busy;

/// Create a copy of RunCockpitState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RunCockpitStateCopyWith<_RunCockpitState> get copyWith => __$RunCockpitStateCopyWithImpl<_RunCockpitState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RunCockpitState&&const DeepCollectionEquality().equals(other._runs, _runs)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&(identical(other.selectedRunId, selectedRunId) || other.selectedRunId == selectedRunId)&&(identical(other.selected, selected) || other.selected == selected)&&(identical(other.loadingRun, loadingRun) || other.loadingRun == loadingRun)&&(identical(other.selectedNodeId, selectedNodeId) || other.selectedNodeId == selectedNodeId)&&(identical(other.busy, busy) || other.busy == busy));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_runs),nextCursor,hasMore,loadingMore,selectedRunId,selected,loadingRun,selectedNodeId,busy);

@override
String toString() {
  return 'RunCockpitState(runs: $runs, nextCursor: $nextCursor, hasMore: $hasMore, loadingMore: $loadingMore, selectedRunId: $selectedRunId, selected: $selected, loadingRun: $loadingRun, selectedNodeId: $selectedNodeId, busy: $busy)';
}


}

/// @nodoc
abstract mixin class _$RunCockpitStateCopyWith<$Res> implements $RunCockpitStateCopyWith<$Res> {
  factory _$RunCockpitStateCopyWith(_RunCockpitState value, $Res Function(_RunCockpitState) _then) = __$RunCockpitStateCopyWithImpl;
@override @useResult
$Res call({
 List<Flowrun> runs, String? nextCursor, bool hasMore, bool loadingMore, String? selectedRunId, FlowrunComposite? selected, bool loadingRun, String? selectedNodeId, bool busy
});


@override $FlowrunCompositeCopyWith<$Res>? get selected;

}
/// @nodoc
class __$RunCockpitStateCopyWithImpl<$Res>
    implements _$RunCockpitStateCopyWith<$Res> {
  __$RunCockpitStateCopyWithImpl(this._self, this._then);

  final _RunCockpitState _self;
  final $Res Function(_RunCockpitState) _then;

/// Create a copy of RunCockpitState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? runs = null,Object? nextCursor = freezed,Object? hasMore = null,Object? loadingMore = null,Object? selectedRunId = freezed,Object? selected = freezed,Object? loadingRun = null,Object? selectedNodeId = freezed,Object? busy = null,}) {
  return _then(_RunCockpitState(
runs: null == runs ? _self._runs : runs // ignore: cast_nullable_to_non_nullable
as List<Flowrun>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,selectedRunId: freezed == selectedRunId ? _self.selectedRunId : selectedRunId // ignore: cast_nullable_to_non_nullable
as String?,selected: freezed == selected ? _self.selected : selected // ignore: cast_nullable_to_non_nullable
as FlowrunComposite?,loadingRun: null == loadingRun ? _self.loadingRun : loadingRun // ignore: cast_nullable_to_non_nullable
as bool,selectedNodeId: freezed == selectedNodeId ? _self.selectedNodeId : selectedNodeId // ignore: cast_nullable_to_non_nullable
as String?,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of RunCockpitState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FlowrunCompositeCopyWith<$Res>? get selected {
    if (_self.selected == null) {
    return null;
  }

  return $FlowrunCompositeCopyWith<$Res>(_self.selected!, (value) {
    return _then(_self.copyWith(selected: value));
  });
}
}

// dart format on
