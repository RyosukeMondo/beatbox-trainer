// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'calibration.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CalibrationError {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CalibrationError);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CalibrationError()';
}


}

/// @nodoc
class $CalibrationErrorCopyWith<$Res>  {
$CalibrationErrorCopyWith(CalibrationError _, $Res Function(CalibrationError) __);
}


/// Adds pattern-matching-related methods to [CalibrationError].
extension CalibrationErrorPatterns on CalibrationError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( CalibrationError_InsufficientSamples value)?  insufficientSamples,TResult Function( CalibrationError_InvalidFeatures value)?  invalidFeatures,TResult Function( CalibrationError_NotComplete value)?  notComplete,TResult Function( CalibrationError_AlreadyInProgress value)?  alreadyInProgress,TResult Function( CalibrationError_StatePoisoned value)?  statePoisoned,TResult Function( CalibrationError_Timeout value)?  timeout,required TResult orElse(),}){
final _that = this;
switch (_that) {
case CalibrationError_InsufficientSamples() when insufficientSamples != null:
return insufficientSamples(_that);case CalibrationError_InvalidFeatures() when invalidFeatures != null:
return invalidFeatures(_that);case CalibrationError_NotComplete() when notComplete != null:
return notComplete(_that);case CalibrationError_AlreadyInProgress() when alreadyInProgress != null:
return alreadyInProgress(_that);case CalibrationError_StatePoisoned() when statePoisoned != null:
return statePoisoned(_that);case CalibrationError_Timeout() when timeout != null:
return timeout(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( CalibrationError_InsufficientSamples value)  insufficientSamples,required TResult Function( CalibrationError_InvalidFeatures value)  invalidFeatures,required TResult Function( CalibrationError_NotComplete value)  notComplete,required TResult Function( CalibrationError_AlreadyInProgress value)  alreadyInProgress,required TResult Function( CalibrationError_StatePoisoned value)  statePoisoned,required TResult Function( CalibrationError_Timeout value)  timeout,}){
final _that = this;
switch (_that) {
case CalibrationError_InsufficientSamples():
return insufficientSamples(_that);case CalibrationError_InvalidFeatures():
return invalidFeatures(_that);case CalibrationError_NotComplete():
return notComplete(_that);case CalibrationError_AlreadyInProgress():
return alreadyInProgress(_that);case CalibrationError_StatePoisoned():
return statePoisoned(_that);case CalibrationError_Timeout():
return timeout(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( CalibrationError_InsufficientSamples value)?  insufficientSamples,TResult? Function( CalibrationError_InvalidFeatures value)?  invalidFeatures,TResult? Function( CalibrationError_NotComplete value)?  notComplete,TResult? Function( CalibrationError_AlreadyInProgress value)?  alreadyInProgress,TResult? Function( CalibrationError_StatePoisoned value)?  statePoisoned,TResult? Function( CalibrationError_Timeout value)?  timeout,}){
final _that = this;
switch (_that) {
case CalibrationError_InsufficientSamples() when insufficientSamples != null:
return insufficientSamples(_that);case CalibrationError_InvalidFeatures() when invalidFeatures != null:
return invalidFeatures(_that);case CalibrationError_NotComplete() when notComplete != null:
return notComplete(_that);case CalibrationError_AlreadyInProgress() when alreadyInProgress != null:
return alreadyInProgress(_that);case CalibrationError_StatePoisoned() when statePoisoned != null:
return statePoisoned(_that);case CalibrationError_Timeout() when timeout != null:
return timeout(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( BigInt required_,  BigInt collected)?  insufficientSamples,TResult Function( String reason)?  invalidFeatures,TResult Function()?  notComplete,TResult Function()?  alreadyInProgress,TResult Function()?  statePoisoned,TResult Function( String reason)?  timeout,required TResult orElse(),}) {final _that = this;
switch (_that) {
case CalibrationError_InsufficientSamples() when insufficientSamples != null:
return insufficientSamples(_that.required_,_that.collected);case CalibrationError_InvalidFeatures() when invalidFeatures != null:
return invalidFeatures(_that.reason);case CalibrationError_NotComplete() when notComplete != null:
return notComplete();case CalibrationError_AlreadyInProgress() when alreadyInProgress != null:
return alreadyInProgress();case CalibrationError_StatePoisoned() when statePoisoned != null:
return statePoisoned();case CalibrationError_Timeout() when timeout != null:
return timeout(_that.reason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( BigInt required_,  BigInt collected)  insufficientSamples,required TResult Function( String reason)  invalidFeatures,required TResult Function()  notComplete,required TResult Function()  alreadyInProgress,required TResult Function()  statePoisoned,required TResult Function( String reason)  timeout,}) {final _that = this;
switch (_that) {
case CalibrationError_InsufficientSamples():
return insufficientSamples(_that.required_,_that.collected);case CalibrationError_InvalidFeatures():
return invalidFeatures(_that.reason);case CalibrationError_NotComplete():
return notComplete();case CalibrationError_AlreadyInProgress():
return alreadyInProgress();case CalibrationError_StatePoisoned():
return statePoisoned();case CalibrationError_Timeout():
return timeout(_that.reason);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( BigInt required_,  BigInt collected)?  insufficientSamples,TResult? Function( String reason)?  invalidFeatures,TResult? Function()?  notComplete,TResult? Function()?  alreadyInProgress,TResult? Function()?  statePoisoned,TResult? Function( String reason)?  timeout,}) {final _that = this;
switch (_that) {
case CalibrationError_InsufficientSamples() when insufficientSamples != null:
return insufficientSamples(_that.required_,_that.collected);case CalibrationError_InvalidFeatures() when invalidFeatures != null:
return invalidFeatures(_that.reason);case CalibrationError_NotComplete() when notComplete != null:
return notComplete();case CalibrationError_AlreadyInProgress() when alreadyInProgress != null:
return alreadyInProgress();case CalibrationError_StatePoisoned() when statePoisoned != null:
return statePoisoned();case CalibrationError_Timeout() when timeout != null:
return timeout(_that.reason);case _:
  return null;

}
}

}

/// @nodoc


class CalibrationError_InsufficientSamples extends CalibrationError {
  const CalibrationError_InsufficientSamples({required this.required_, required this.collected}): super._();
  

 final  BigInt required_;
 final  BigInt collected;

/// Create a copy of CalibrationError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CalibrationError_InsufficientSamplesCopyWith<CalibrationError_InsufficientSamples> get copyWith => _$CalibrationError_InsufficientSamplesCopyWithImpl<CalibrationError_InsufficientSamples>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CalibrationError_InsufficientSamples&&(identical(other.required_, required_) || other.required_ == required_)&&(identical(other.collected, collected) || other.collected == collected));
}


@override
int get hashCode => Object.hash(runtimeType,required_,collected);

@override
String toString() {
  return 'CalibrationError.insufficientSamples(required_: $required_, collected: $collected)';
}


}

/// @nodoc
abstract mixin class $CalibrationError_InsufficientSamplesCopyWith<$Res> implements $CalibrationErrorCopyWith<$Res> {
  factory $CalibrationError_InsufficientSamplesCopyWith(CalibrationError_InsufficientSamples value, $Res Function(CalibrationError_InsufficientSamples) _then) = _$CalibrationError_InsufficientSamplesCopyWithImpl;
@useResult
$Res call({
 BigInt required_, BigInt collected
});




}
/// @nodoc
class _$CalibrationError_InsufficientSamplesCopyWithImpl<$Res>
    implements $CalibrationError_InsufficientSamplesCopyWith<$Res> {
  _$CalibrationError_InsufficientSamplesCopyWithImpl(this._self, this._then);

  final CalibrationError_InsufficientSamples _self;
  final $Res Function(CalibrationError_InsufficientSamples) _then;

/// Create a copy of CalibrationError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? required_ = null,Object? collected = null,}) {
  return _then(CalibrationError_InsufficientSamples(
required_: null == required_ ? _self.required_ : required_ // ignore: cast_nullable_to_non_nullable
as BigInt,collected: null == collected ? _self.collected : collected // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class CalibrationError_InvalidFeatures extends CalibrationError {
  const CalibrationError_InvalidFeatures({required this.reason}): super._();
  

 final  String reason;

/// Create a copy of CalibrationError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CalibrationError_InvalidFeaturesCopyWith<CalibrationError_InvalidFeatures> get copyWith => _$CalibrationError_InvalidFeaturesCopyWithImpl<CalibrationError_InvalidFeatures>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CalibrationError_InvalidFeatures&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,reason);

@override
String toString() {
  return 'CalibrationError.invalidFeatures(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $CalibrationError_InvalidFeaturesCopyWith<$Res> implements $CalibrationErrorCopyWith<$Res> {
  factory $CalibrationError_InvalidFeaturesCopyWith(CalibrationError_InvalidFeatures value, $Res Function(CalibrationError_InvalidFeatures) _then) = _$CalibrationError_InvalidFeaturesCopyWithImpl;
@useResult
$Res call({
 String reason
});




}
/// @nodoc
class _$CalibrationError_InvalidFeaturesCopyWithImpl<$Res>
    implements $CalibrationError_InvalidFeaturesCopyWith<$Res> {
  _$CalibrationError_InvalidFeaturesCopyWithImpl(this._self, this._then);

  final CalibrationError_InvalidFeatures _self;
  final $Res Function(CalibrationError_InvalidFeatures) _then;

/// Create a copy of CalibrationError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(CalibrationError_InvalidFeatures(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CalibrationError_NotComplete extends CalibrationError {
  const CalibrationError_NotComplete(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CalibrationError_NotComplete);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CalibrationError.notComplete()';
}


}




/// @nodoc


class CalibrationError_AlreadyInProgress extends CalibrationError {
  const CalibrationError_AlreadyInProgress(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CalibrationError_AlreadyInProgress);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CalibrationError.alreadyInProgress()';
}


}




/// @nodoc


class CalibrationError_StatePoisoned extends CalibrationError {
  const CalibrationError_StatePoisoned(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CalibrationError_StatePoisoned);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CalibrationError.statePoisoned()';
}


}




/// @nodoc


class CalibrationError_Timeout extends CalibrationError {
  const CalibrationError_Timeout({required this.reason}): super._();
  

 final  String reason;

/// Create a copy of CalibrationError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CalibrationError_TimeoutCopyWith<CalibrationError_Timeout> get copyWith => _$CalibrationError_TimeoutCopyWithImpl<CalibrationError_Timeout>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CalibrationError_Timeout&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,reason);

@override
String toString() {
  return 'CalibrationError.timeout(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $CalibrationError_TimeoutCopyWith<$Res> implements $CalibrationErrorCopyWith<$Res> {
  factory $CalibrationError_TimeoutCopyWith(CalibrationError_Timeout value, $Res Function(CalibrationError_Timeout) _then) = _$CalibrationError_TimeoutCopyWithImpl;
@useResult
$Res call({
 String reason
});




}
/// @nodoc
class _$CalibrationError_TimeoutCopyWithImpl<$Res>
    implements $CalibrationError_TimeoutCopyWith<$Res> {
  _$CalibrationError_TimeoutCopyWithImpl(this._self, this._then);

  final CalibrationError_Timeout _self;
  final $Res Function(CalibrationError_Timeout) _then;

/// Create a copy of CalibrationError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(CalibrationError_Timeout(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
