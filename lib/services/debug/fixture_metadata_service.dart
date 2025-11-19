import '../../bridge/api.dart/api/diagnostics.dart' as diagnostics_api;
import '../../bridge/api.dart/testing/fixture_manifest.dart';

/// Contract for loading fixture metadata shared between CLI + Debug Lab flows.
abstract class IFixtureMetadataService {
  /// Retrieve the full manifest, optionally bypassing cached data.
  Future<List<FixtureManifestEntry>> loadCatalog({bool forceRefresh = false});

  /// Retrieve a single manifest entry by fixture id.
  Future<FixtureManifestEntry?> loadById(
    String id, {
    bool forceRefresh = false,
  });

  /// Indicates whether catalog data is already cached locally.
  bool get hasCache;
}

/// Loads + caches fixture metadata surfaced in Debug Lab and diagnostics CLIs.
class FixtureMetadataService implements IFixtureMetadataService {
  FixtureMetadataService({Duration cacheTtl = const Duration(minutes: 10)})
    : _cacheTtl = cacheTtl;

  final Duration _cacheTtl;
  DateTime? _lastLoadedAt;
  List<FixtureManifestEntry>? _orderedCache;
  final Map<String, FixtureManifestEntry> _cacheIndex = {};

  @override
  bool get hasCache => _orderedCache != null && _cacheIndex.isNotEmpty;

  bool _isCacheFresh() {
    final loadedAt = _lastLoadedAt;
    if (_orderedCache == null || loadedAt == null) {
      return false;
    }
    return DateTime.now().difference(loadedAt) < _cacheTtl;
  }

  @override
  Future<List<FixtureManifestEntry>> loadCatalog({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _isCacheFresh()) {
      return List.unmodifiable(_orderedCache!);
    }

    try {
      final fixtures = diagnostics_api.loadFixtureCatalog();
      _storeCatalog(fixtures);
      return List.unmodifiable(_orderedCache!);
    } catch (error, stackTrace) {
      throw FixtureMetadataException(
        'Failed to load fixture catalog',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<FixtureManifestEntry?> loadById(
    String id, {
    bool forceRefresh = false,
  }) async {
    if (id.trim().isEmpty) {
      throw FixtureMetadataException('Fixture id cannot be empty');
    }

    if (!forceRefresh && _isCacheFresh()) {
      return _cacheIndex[id];
    }

    // Prefer manifest cache for stale-but-present data to keep UI responsive.
    final cached = _cacheIndex[id];
    if (cached != null && !forceRefresh) {
      return cached;
    }

    try {
      final entry = diagnostics_api.fixtureMetadataForId(id: id);
      if (entry != null) {
        _upsertEntry(entry);
      }
      return entry;
    } catch (error, stackTrace) {
      throw FixtureMetadataException(
        'Failed to load fixture metadata for $id',
        error,
        stackTrace,
      );
    }
  }

  void _storeCatalog(List<FixtureManifestEntry> fixtures) {
    _orderedCache = List<FixtureManifestEntry>.from(fixtures);
    _cacheIndex
      ..clear()
      ..addEntries(fixtures.map((entry) => MapEntry(entry.id, entry)));
    _lastLoadedAt = DateTime.now();
  }

  void _upsertEntry(FixtureManifestEntry entry) {
    _cacheIndex[entry.id] = entry;
    if (_orderedCache == null) {
      _orderedCache = [entry];
    } else {
      final index = _orderedCache!.indexWhere((value) => value.id == entry.id);
      if (index == -1) {
        _orderedCache!.add(entry);
      } else {
        _orderedCache![index] = entry;
      }
    }
    _lastLoadedAt ??= DateTime.now();
  }
}

/// Domain-specific exception exposed to the UI/controller layers.
class FixtureMetadataException implements Exception {
  FixtureMetadataException(this.message, [this.cause, this.stackTrace]);

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() =>
      'FixtureMetadataException(message: $message, cause: $cause)';
}
