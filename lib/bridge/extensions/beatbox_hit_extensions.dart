import '../api.dart/analysis/classifier.dart';

extension BeatboxHitExtensions on BeatboxHit {
  String get displayName {
    switch (this) {
      case BeatboxHit.kick:
        return 'KICK';
      case BeatboxHit.snare:
        return 'SNARE';
      case BeatboxHit.hiHat:
        return 'HI-HAT';
      case BeatboxHit.closedHiHat:
        return 'CLOSED HI-HAT';
      case BeatboxHit.openHiHat:
        return 'OPEN HI-HAT';
      case BeatboxHit.kSnare:
        return 'K-SNARE';
      case BeatboxHit.unknown:
        return 'UNKNOWN';
    }
  }
}
