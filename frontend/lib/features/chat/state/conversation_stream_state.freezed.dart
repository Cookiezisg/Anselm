// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conversation_stream_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConversationStreamState {

 TranscriptPhase get phase; String? get error; String? get nextCursor; bool get hasMoreOlder; bool get loadingOlder;
/// Create a copy of ConversationStreamState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationStreamStateCopyWith<ConversationStreamState> get copyWith => _$ConversationStreamStateCopyWithImpl<ConversationStreamState>(this as ConversationStreamState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationStreamState&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.error, error) || other.error == error)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMoreOlder, hasMoreOlder) || other.hasMoreOlder == hasMoreOlder)&&(identical(other.loadingOlder, loadingOlder) || other.loadingOlder == loadingOlder));
}


@override
int get hashCode => Object.hash(runtimeType,phase,error,nextCursor,hasMoreOlder,loadingOlder);

@override
String toString() {
  return 'ConversationStreamState(phase: $phase, error: $error, nextCursor: $nextCursor, hasMoreOlder: $hasMoreOlder, loadingOlder: $loadingOlder)';
}


}

/// @nodoc
abstract mixin class $ConversationStreamStateCopyWith<$Res>  {
  factory $ConversationStreamStateCopyWith(ConversationStreamState value, $Res Function(ConversationStreamState) _then) = _$ConversationStreamStateCopyWithImpl;
@useResult
$Res call({
 TranscriptPhase phase, String? error, String? nextCursor, bool hasMoreOlder, bool loadingOlder
});




}
/// @nodoc
class _$ConversationStreamStateCopyWithImpl<$Res>
    implements $ConversationStreamStateCopyWith<$Res> {
  _$ConversationStreamStateCopyWithImpl(this._self, this._then);

  final ConversationStreamState _self;
  final $Res Function(ConversationStreamState) _then;

/// Create a copy of ConversationStreamState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? phase = null,Object? error = freezed,Object? nextCursor = freezed,Object? hasMoreOlder = null,Object? loadingOlder = null,}) {
  return _then(_self.copyWith(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as TranscriptPhase,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMoreOlder: null == hasMoreOlder ? _self.hasMoreOlder : hasMoreOlder // ignore: cast_nullable_to_non_nullable
as bool,loadingOlder: null == loadingOlder ? _self.loadingOlder : loadingOlder // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ConversationStreamState].
extension ConversationStreamStatePatterns on ConversationStreamState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConversationStreamState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConversationStreamState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConversationStreamState value)  $default,){
final _that = this;
switch (_that) {
case _ConversationStreamState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConversationStreamState value)?  $default,){
final _that = this;
switch (_that) {
case _ConversationStreamState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TranscriptPhase phase,  String? error,  String? nextCursor,  bool hasMoreOlder,  bool loadingOlder)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConversationStreamState() when $default != null:
return $default(_that.phase,_that.error,_that.nextCursor,_that.hasMoreOlder,_that.loadingOlder);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TranscriptPhase phase,  String? error,  String? nextCursor,  bool hasMoreOlder,  bool loadingOlder)  $default,) {final _that = this;
switch (_that) {
case _ConversationStreamState():
return $default(_that.phase,_that.error,_that.nextCursor,_that.hasMoreOlder,_that.loadingOlder);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TranscriptPhase phase,  String? error,  String? nextCursor,  bool hasMoreOlder,  bool loadingOlder)?  $default,) {final _that = this;
switch (_that) {
case _ConversationStreamState() when $default != null:
return $default(_that.phase,_that.error,_that.nextCursor,_that.hasMoreOlder,_that.loadingOlder);case _:
  return null;

}
}

}

/// @nodoc


class _ConversationStreamState implements ConversationStreamState {
  const _ConversationStreamState({this.phase = TranscriptPhase.hydrating, this.error, this.nextCursor, this.hasMoreOlder = false, this.loadingOlder = false});
  

@override@JsonKey() final  TranscriptPhase phase;
@override final  String? error;
@override final  String? nextCursor;
@override@JsonKey() final  bool hasMoreOlder;
@override@JsonKey() final  bool loadingOlder;

/// Create a copy of ConversationStreamState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversationStreamStateCopyWith<_ConversationStreamState> get copyWith => __$ConversationStreamStateCopyWithImpl<_ConversationStreamState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConversationStreamState&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.error, error) || other.error == error)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMoreOlder, hasMoreOlder) || other.hasMoreOlder == hasMoreOlder)&&(identical(other.loadingOlder, loadingOlder) || other.loadingOlder == loadingOlder));
}


@override
int get hashCode => Object.hash(runtimeType,phase,error,nextCursor,hasMoreOlder,loadingOlder);

@override
String toString() {
  return 'ConversationStreamState(phase: $phase, error: $error, nextCursor: $nextCursor, hasMoreOlder: $hasMoreOlder, loadingOlder: $loadingOlder)';
}


}

/// @nodoc
abstract mixin class _$ConversationStreamStateCopyWith<$Res> implements $ConversationStreamStateCopyWith<$Res> {
  factory _$ConversationStreamStateCopyWith(_ConversationStreamState value, $Res Function(_ConversationStreamState) _then) = __$ConversationStreamStateCopyWithImpl;
@override @useResult
$Res call({
 TranscriptPhase phase, String? error, String? nextCursor, bool hasMoreOlder, bool loadingOlder
});




}
/// @nodoc
class __$ConversationStreamStateCopyWithImpl<$Res>
    implements _$ConversationStreamStateCopyWith<$Res> {
  __$ConversationStreamStateCopyWithImpl(this._self, this._then);

  final _ConversationStreamState _self;
  final $Res Function(_ConversationStreamState) _then;

/// Create a copy of ConversationStreamState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? phase = null,Object? error = freezed,Object? nextCursor = freezed,Object? hasMoreOlder = null,Object? loadingOlder = null,}) {
  return _then(_ConversationStreamState(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as TranscriptPhase,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMoreOlder: null == hasMoreOlder ? _self.hasMoreOlder : hasMoreOlder // ignore: cast_nullable_to_non_nullable
as bool,loadingOlder: null == loadingOlder ? _self.loadingOlder : loadingOlder // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
