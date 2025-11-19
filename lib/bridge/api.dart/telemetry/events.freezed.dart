// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'events.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MetricEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MetricEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'MetricEvent()';
}


}

/// @nodoc
class $MetricEventCopyWith<$Res>  {
$MetricEventCopyWith(MetricEvent _, $Res Function(MetricEvent) __);
}


/// Adds pattern-matching-related methods to [MetricEvent].
extension MetricEventPatterns on MetricEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( MetricEvent_Latency value)?  latency,TResult Function( MetricEvent_BufferOccupancy value)?  bufferOccupancy,TResult Function( MetricEvent_Classification value)?  classification,TResult Function( MetricEvent_JniLifecycle value)?  jniLifecycle,TResult Function( MetricEvent_Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case MetricEvent_Latency() when latency != null:
return latency(_that);case MetricEvent_BufferOccupancy() when bufferOccupancy != null:
return bufferOccupancy(_that);case MetricEvent_Classification() when classification != null:
return classification(_that);case MetricEvent_JniLifecycle() when jniLifecycle != null:
return jniLifecycle(_that);case MetricEvent_Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( MetricEvent_Latency value)  latency,required TResult Function( MetricEvent_BufferOccupancy value)  bufferOccupancy,required TResult Function( MetricEvent_Classification value)  classification,required TResult Function( MetricEvent_JniLifecycle value)  jniLifecycle,required TResult Function( MetricEvent_Error value)  error,}){
final _that = this;
switch (_that) {
case MetricEvent_Latency():
return latency(_that);case MetricEvent_BufferOccupancy():
return bufferOccupancy(_that);case MetricEvent_Classification():
return classification(_that);case MetricEvent_JniLifecycle():
return jniLifecycle(_that);case MetricEvent_Error():
return error(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( MetricEvent_Latency value)?  latency,TResult? Function( MetricEvent_BufferOccupancy value)?  bufferOccupancy,TResult? Function( MetricEvent_Classification value)?  classification,TResult? Function( MetricEvent_JniLifecycle value)?  jniLifecycle,TResult? Function( MetricEvent_Error value)?  error,}){
final _that = this;
switch (_that) {
case MetricEvent_Latency() when latency != null:
return latency(_that);case MetricEvent_BufferOccupancy() when bufferOccupancy != null:
return bufferOccupancy(_that);case MetricEvent_Classification() when classification != null:
return classification(_that);case MetricEvent_JniLifecycle() when jniLifecycle != null:
return jniLifecycle(_that);case MetricEvent_Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( double avgMs,  double maxMs,  BigInt sampleCount)?  latency,TResult Function( String channel,  double percent)?  bufferOccupancy,TResult Function( BeatboxHit sound,  double confidence,  double timingErrorMs)?  classification,TResult Function( LifecyclePhase phase,  BigInt timestampMs)?  jniLifecycle,TResult Function( DiagnosticError code,  String context)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case MetricEvent_Latency() when latency != null:
return latency(_that.avgMs,_that.maxMs,_that.sampleCount);case MetricEvent_BufferOccupancy() when bufferOccupancy != null:
return bufferOccupancy(_that.channel,_that.percent);case MetricEvent_Classification() when classification != null:
return classification(_that.sound,_that.confidence,_that.timingErrorMs);case MetricEvent_JniLifecycle() when jniLifecycle != null:
return jniLifecycle(_that.phase,_that.timestampMs);case MetricEvent_Error() when error != null:
return error(_that.code,_that.context);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( double avgMs,  double maxMs,  BigInt sampleCount)  latency,required TResult Function( String channel,  double percent)  bufferOccupancy,required TResult Function( BeatboxHit sound,  double confidence,  double timingErrorMs)  classification,required TResult Function( LifecyclePhase phase,  BigInt timestampMs)  jniLifecycle,required TResult Function( DiagnosticError code,  String context)  error,}) {final _that = this;
switch (_that) {
case MetricEvent_Latency():
return latency(_that.avgMs,_that.maxMs,_that.sampleCount);case MetricEvent_BufferOccupancy():
return bufferOccupancy(_that.channel,_that.percent);case MetricEvent_Classification():
return classification(_that.sound,_that.confidence,_that.timingErrorMs);case MetricEvent_JniLifecycle():
return jniLifecycle(_that.phase,_that.timestampMs);case MetricEvent_Error():
return error(_that.code,_that.context);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( double avgMs,  double maxMs,  BigInt sampleCount)?  latency,TResult? Function( String channel,  double percent)?  bufferOccupancy,TResult? Function( BeatboxHit sound,  double confidence,  double timingErrorMs)?  classification,TResult? Function( LifecyclePhase phase,  BigInt timestampMs)?  jniLifecycle,TResult? Function( DiagnosticError code,  String context)?  error,}) {final _that = this;
switch (_that) {
case MetricEvent_Latency() when latency != null:
return latency(_that.avgMs,_that.maxMs,_that.sampleCount);case MetricEvent_BufferOccupancy() when bufferOccupancy != null:
return bufferOccupancy(_that.channel,_that.percent);case MetricEvent_Classification() when classification != null:
return classification(_that.sound,_that.confidence,_that.timingErrorMs);case MetricEvent_JniLifecycle() when jniLifecycle != null:
return jniLifecycle(_that.phase,_that.timestampMs);case MetricEvent_Error() when error != null:
return error(_that.code,_that.context);case _:
  return null;

}
}

}

/// @nodoc


class MetricEvent_Latency extends MetricEvent {
  const MetricEvent_Latency({required this.avgMs, required this.maxMs, required this.sampleCount}): super._();
  

 final  double avgMs;
 final  double maxMs;
 final  BigInt sampleCount;

/// Create a copy of MetricEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetricEvent_LatencyCopyWith<MetricEvent_Latency> get copyWith => _$MetricEvent_LatencyCopyWithImpl<MetricEvent_Latency>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MetricEvent_Latency&&(identical(other.avgMs, avgMs) || other.avgMs == avgMs)&&(identical(other.maxMs, maxMs) || other.maxMs == maxMs)&&(identical(other.sampleCount, sampleCount) || other.sampleCount == sampleCount));
}


@override
int get hashCode => Object.hash(runtimeType,avgMs,maxMs,sampleCount);

@override
String toString() {
  return 'MetricEvent.latency(avgMs: $avgMs, maxMs: $maxMs, sampleCount: $sampleCount)';
}


}

/// @nodoc
abstract mixin class $MetricEvent_LatencyCopyWith<$Res> implements $MetricEventCopyWith<$Res> {
  factory $MetricEvent_LatencyCopyWith(MetricEvent_Latency value, $Res Function(MetricEvent_Latency) _then) = _$MetricEvent_LatencyCopyWithImpl;
@useResult
$Res call({
 double avgMs, double maxMs, BigInt sampleCount
});




}
/// @nodoc
class _$MetricEvent_LatencyCopyWithImpl<$Res>
    implements $MetricEvent_LatencyCopyWith<$Res> {
  _$MetricEvent_LatencyCopyWithImpl(this._self, this._then);

  final MetricEvent_Latency _self;
  final $Res Function(MetricEvent_Latency) _then;

/// Create a copy of MetricEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? avgMs = null,Object? maxMs = null,Object? sampleCount = null,}) {
  return _then(MetricEvent_Latency(
avgMs: null == avgMs ? _self.avgMs : avgMs // ignore: cast_nullable_to_non_nullable
as double,maxMs: null == maxMs ? _self.maxMs : maxMs // ignore: cast_nullable_to_non_nullable
as double,sampleCount: null == sampleCount ? _self.sampleCount : sampleCount // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class MetricEvent_BufferOccupancy extends MetricEvent {
  const MetricEvent_BufferOccupancy({required this.channel, required this.percent}): super._();
  

 final  String channel;
 final  double percent;

/// Create a copy of MetricEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetricEvent_BufferOccupancyCopyWith<MetricEvent_BufferOccupancy> get copyWith => _$MetricEvent_BufferOccupancyCopyWithImpl<MetricEvent_BufferOccupancy>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MetricEvent_BufferOccupancy&&(identical(other.channel, channel) || other.channel == channel)&&(identical(other.percent, percent) || other.percent == percent));
}


@override
int get hashCode => Object.hash(runtimeType,channel,percent);

@override
String toString() {
  return 'MetricEvent.bufferOccupancy(channel: $channel, percent: $percent)';
}


}

/// @nodoc
abstract mixin class $MetricEvent_BufferOccupancyCopyWith<$Res> implements $MetricEventCopyWith<$Res> {
  factory $MetricEvent_BufferOccupancyCopyWith(MetricEvent_BufferOccupancy value, $Res Function(MetricEvent_BufferOccupancy) _then) = _$MetricEvent_BufferOccupancyCopyWithImpl;
@useResult
$Res call({
 String channel, double percent
});




}
/// @nodoc
class _$MetricEvent_BufferOccupancyCopyWithImpl<$Res>
    implements $MetricEvent_BufferOccupancyCopyWith<$Res> {
  _$MetricEvent_BufferOccupancyCopyWithImpl(this._self, this._then);

  final MetricEvent_BufferOccupancy _self;
  final $Res Function(MetricEvent_BufferOccupancy) _then;

/// Create a copy of MetricEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? channel = null,Object? percent = null,}) {
  return _then(MetricEvent_BufferOccupancy(
channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as String,percent: null == percent ? _self.percent : percent // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class MetricEvent_Classification extends MetricEvent {
  const MetricEvent_Classification({required this.sound, required this.confidence, required this.timingErrorMs}): super._();
  

 final  BeatboxHit sound;
 final  double confidence;
 final  double timingErrorMs;

/// Create a copy of MetricEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetricEvent_ClassificationCopyWith<MetricEvent_Classification> get copyWith => _$MetricEvent_ClassificationCopyWithImpl<MetricEvent_Classification>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MetricEvent_Classification&&(identical(other.sound, sound) || other.sound == sound)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&(identical(other.timingErrorMs, timingErrorMs) || other.timingErrorMs == timingErrorMs));
}


@override
int get hashCode => Object.hash(runtimeType,sound,confidence,timingErrorMs);

@override
String toString() {
  return 'MetricEvent.classification(sound: $sound, confidence: $confidence, timingErrorMs: $timingErrorMs)';
}


}

/// @nodoc
abstract mixin class $MetricEvent_ClassificationCopyWith<$Res> implements $MetricEventCopyWith<$Res> {
  factory $MetricEvent_ClassificationCopyWith(MetricEvent_Classification value, $Res Function(MetricEvent_Classification) _then) = _$MetricEvent_ClassificationCopyWithImpl;
@useResult
$Res call({
 BeatboxHit sound, double confidence, double timingErrorMs
});




}
/// @nodoc
class _$MetricEvent_ClassificationCopyWithImpl<$Res>
    implements $MetricEvent_ClassificationCopyWith<$Res> {
  _$MetricEvent_ClassificationCopyWithImpl(this._self, this._then);

  final MetricEvent_Classification _self;
  final $Res Function(MetricEvent_Classification) _then;

/// Create a copy of MetricEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sound = null,Object? confidence = null,Object? timingErrorMs = null,}) {
  return _then(MetricEvent_Classification(
sound: null == sound ? _self.sound : sound // ignore: cast_nullable_to_non_nullable
as BeatboxHit,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,timingErrorMs: null == timingErrorMs ? _self.timingErrorMs : timingErrorMs // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class MetricEvent_JniLifecycle extends MetricEvent {
  const MetricEvent_JniLifecycle({required this.phase, required this.timestampMs}): super._();
  

 final  LifecyclePhase phase;
 final  BigInt timestampMs;

/// Create a copy of MetricEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetricEvent_JniLifecycleCopyWith<MetricEvent_JniLifecycle> get copyWith => _$MetricEvent_JniLifecycleCopyWithImpl<MetricEvent_JniLifecycle>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MetricEvent_JniLifecycle&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.timestampMs, timestampMs) || other.timestampMs == timestampMs));
}


@override
int get hashCode => Object.hash(runtimeType,phase,timestampMs);

@override
String toString() {
  return 'MetricEvent.jniLifecycle(phase: $phase, timestampMs: $timestampMs)';
}


}

/// @nodoc
abstract mixin class $MetricEvent_JniLifecycleCopyWith<$Res> implements $MetricEventCopyWith<$Res> {
  factory $MetricEvent_JniLifecycleCopyWith(MetricEvent_JniLifecycle value, $Res Function(MetricEvent_JniLifecycle) _then) = _$MetricEvent_JniLifecycleCopyWithImpl;
@useResult
$Res call({
 LifecyclePhase phase, BigInt timestampMs
});




}
/// @nodoc
class _$MetricEvent_JniLifecycleCopyWithImpl<$Res>
    implements $MetricEvent_JniLifecycleCopyWith<$Res> {
  _$MetricEvent_JniLifecycleCopyWithImpl(this._self, this._then);

  final MetricEvent_JniLifecycle _self;
  final $Res Function(MetricEvent_JniLifecycle) _then;

/// Create a copy of MetricEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? phase = null,Object? timestampMs = null,}) {
  return _then(MetricEvent_JniLifecycle(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as LifecyclePhase,timestampMs: null == timestampMs ? _self.timestampMs : timestampMs // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class MetricEvent_Error extends MetricEvent {
  const MetricEvent_Error({required this.code, required this.context}): super._();
  

 final  DiagnosticError code;
 final  String context;

/// Create a copy of MetricEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetricEvent_ErrorCopyWith<MetricEvent_Error> get copyWith => _$MetricEvent_ErrorCopyWithImpl<MetricEvent_Error>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MetricEvent_Error&&(identical(other.code, code) || other.code == code)&&(identical(other.context, context) || other.context == context));
}


@override
int get hashCode => Object.hash(runtimeType,code,context);

@override
String toString() {
  return 'MetricEvent.error(code: $code, context: $context)';
}


}

/// @nodoc
abstract mixin class $MetricEvent_ErrorCopyWith<$Res> implements $MetricEventCopyWith<$Res> {
  factory $MetricEvent_ErrorCopyWith(MetricEvent_Error value, $Res Function(MetricEvent_Error) _then) = _$MetricEvent_ErrorCopyWithImpl;
@useResult
$Res call({
 DiagnosticError code, String context
});




}
/// @nodoc
class _$MetricEvent_ErrorCopyWithImpl<$Res>
    implements $MetricEvent_ErrorCopyWith<$Res> {
  _$MetricEvent_ErrorCopyWithImpl(this._self, this._then);

  final MetricEvent_Error _self;
  final $Res Function(MetricEvent_Error) _then;

/// Create a copy of MetricEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? code = null,Object? context = null,}) {
  return _then(MetricEvent_Error(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as DiagnosticError,context: null == context ? _self.context : context // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
