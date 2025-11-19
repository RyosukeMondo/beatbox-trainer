// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'core.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TelemetryEventKind {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TelemetryEventKind);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TelemetryEventKind()';
}


}

/// @nodoc
class $TelemetryEventKindCopyWith<$Res>  {
$TelemetryEventKindCopyWith(TelemetryEventKind _, $Res Function(TelemetryEventKind) __);
}


/// Adds pattern-matching-related methods to [TelemetryEventKind].
extension TelemetryEventKindPatterns on TelemetryEventKind {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TelemetryEventKind_EngineStarted value)?  engineStarted,TResult Function( TelemetryEventKind_EngineStopped value)?  engineStopped,TResult Function( TelemetryEventKind_BpmChanged value)?  bpmChanged,TResult Function( TelemetryEventKind_Warning value)?  warning,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TelemetryEventKind_EngineStarted() when engineStarted != null:
return engineStarted(_that);case TelemetryEventKind_EngineStopped() when engineStopped != null:
return engineStopped(_that);case TelemetryEventKind_BpmChanged() when bpmChanged != null:
return bpmChanged(_that);case TelemetryEventKind_Warning() when warning != null:
return warning(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TelemetryEventKind_EngineStarted value)  engineStarted,required TResult Function( TelemetryEventKind_EngineStopped value)  engineStopped,required TResult Function( TelemetryEventKind_BpmChanged value)  bpmChanged,required TResult Function( TelemetryEventKind_Warning value)  warning,}){
final _that = this;
switch (_that) {
case TelemetryEventKind_EngineStarted():
return engineStarted(_that);case TelemetryEventKind_EngineStopped():
return engineStopped(_that);case TelemetryEventKind_BpmChanged():
return bpmChanged(_that);case TelemetryEventKind_Warning():
return warning(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TelemetryEventKind_EngineStarted value)?  engineStarted,TResult? Function( TelemetryEventKind_EngineStopped value)?  engineStopped,TResult? Function( TelemetryEventKind_BpmChanged value)?  bpmChanged,TResult? Function( TelemetryEventKind_Warning value)?  warning,}){
final _that = this;
switch (_that) {
case TelemetryEventKind_EngineStarted() when engineStarted != null:
return engineStarted(_that);case TelemetryEventKind_EngineStopped() when engineStopped != null:
return engineStopped(_that);case TelemetryEventKind_BpmChanged() when bpmChanged != null:
return bpmChanged(_that);case TelemetryEventKind_Warning() when warning != null:
return warning(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int bpm)?  engineStarted,TResult Function()?  engineStopped,TResult Function( int bpm)?  bpmChanged,TResult Function()?  warning,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TelemetryEventKind_EngineStarted() when engineStarted != null:
return engineStarted(_that.bpm);case TelemetryEventKind_EngineStopped() when engineStopped != null:
return engineStopped();case TelemetryEventKind_BpmChanged() when bpmChanged != null:
return bpmChanged(_that.bpm);case TelemetryEventKind_Warning() when warning != null:
return warning();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int bpm)  engineStarted,required TResult Function()  engineStopped,required TResult Function( int bpm)  bpmChanged,required TResult Function()  warning,}) {final _that = this;
switch (_that) {
case TelemetryEventKind_EngineStarted():
return engineStarted(_that.bpm);case TelemetryEventKind_EngineStopped():
return engineStopped();case TelemetryEventKind_BpmChanged():
return bpmChanged(_that.bpm);case TelemetryEventKind_Warning():
return warning();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int bpm)?  engineStarted,TResult? Function()?  engineStopped,TResult? Function( int bpm)?  bpmChanged,TResult? Function()?  warning,}) {final _that = this;
switch (_that) {
case TelemetryEventKind_EngineStarted() when engineStarted != null:
return engineStarted(_that.bpm);case TelemetryEventKind_EngineStopped() when engineStopped != null:
return engineStopped();case TelemetryEventKind_BpmChanged() when bpmChanged != null:
return bpmChanged(_that.bpm);case TelemetryEventKind_Warning() when warning != null:
return warning();case _:
  return null;

}
}

}

/// @nodoc


class TelemetryEventKind_EngineStarted extends TelemetryEventKind {
  const TelemetryEventKind_EngineStarted({required this.bpm}): super._();
  

 final  int bpm;

/// Create a copy of TelemetryEventKind
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TelemetryEventKind_EngineStartedCopyWith<TelemetryEventKind_EngineStarted> get copyWith => _$TelemetryEventKind_EngineStartedCopyWithImpl<TelemetryEventKind_EngineStarted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TelemetryEventKind_EngineStarted&&(identical(other.bpm, bpm) || other.bpm == bpm));
}


@override
int get hashCode => Object.hash(runtimeType,bpm);

@override
String toString() {
  return 'TelemetryEventKind.engineStarted(bpm: $bpm)';
}


}

/// @nodoc
abstract mixin class $TelemetryEventKind_EngineStartedCopyWith<$Res> implements $TelemetryEventKindCopyWith<$Res> {
  factory $TelemetryEventKind_EngineStartedCopyWith(TelemetryEventKind_EngineStarted value, $Res Function(TelemetryEventKind_EngineStarted) _then) = _$TelemetryEventKind_EngineStartedCopyWithImpl;
@useResult
$Res call({
 int bpm
});




}
/// @nodoc
class _$TelemetryEventKind_EngineStartedCopyWithImpl<$Res>
    implements $TelemetryEventKind_EngineStartedCopyWith<$Res> {
  _$TelemetryEventKind_EngineStartedCopyWithImpl(this._self, this._then);

  final TelemetryEventKind_EngineStarted _self;
  final $Res Function(TelemetryEventKind_EngineStarted) _then;

/// Create a copy of TelemetryEventKind
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? bpm = null,}) {
  return _then(TelemetryEventKind_EngineStarted(
bpm: null == bpm ? _self.bpm : bpm // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class TelemetryEventKind_EngineStopped extends TelemetryEventKind {
  const TelemetryEventKind_EngineStopped(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TelemetryEventKind_EngineStopped);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TelemetryEventKind.engineStopped()';
}


}




/// @nodoc


class TelemetryEventKind_BpmChanged extends TelemetryEventKind {
  const TelemetryEventKind_BpmChanged({required this.bpm}): super._();
  

 final  int bpm;

/// Create a copy of TelemetryEventKind
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TelemetryEventKind_BpmChangedCopyWith<TelemetryEventKind_BpmChanged> get copyWith => _$TelemetryEventKind_BpmChangedCopyWithImpl<TelemetryEventKind_BpmChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TelemetryEventKind_BpmChanged&&(identical(other.bpm, bpm) || other.bpm == bpm));
}


@override
int get hashCode => Object.hash(runtimeType,bpm);

@override
String toString() {
  return 'TelemetryEventKind.bpmChanged(bpm: $bpm)';
}


}

/// @nodoc
abstract mixin class $TelemetryEventKind_BpmChangedCopyWith<$Res> implements $TelemetryEventKindCopyWith<$Res> {
  factory $TelemetryEventKind_BpmChangedCopyWith(TelemetryEventKind_BpmChanged value, $Res Function(TelemetryEventKind_BpmChanged) _then) = _$TelemetryEventKind_BpmChangedCopyWithImpl;
@useResult
$Res call({
 int bpm
});




}
/// @nodoc
class _$TelemetryEventKind_BpmChangedCopyWithImpl<$Res>
    implements $TelemetryEventKind_BpmChangedCopyWith<$Res> {
  _$TelemetryEventKind_BpmChangedCopyWithImpl(this._self, this._then);

  final TelemetryEventKind_BpmChanged _self;
  final $Res Function(TelemetryEventKind_BpmChanged) _then;

/// Create a copy of TelemetryEventKind
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? bpm = null,}) {
  return _then(TelemetryEventKind_BpmChanged(
bpm: null == bpm ? _self.bpm : bpm // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class TelemetryEventKind_Warning extends TelemetryEventKind {
  const TelemetryEventKind_Warning(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TelemetryEventKind_Warning);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TelemetryEventKind.warning()';
}


}




// dart format on
