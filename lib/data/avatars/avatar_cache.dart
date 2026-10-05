import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Avatar images on disk, so they show after a restart and offline without
/// downloading them again.
///
/// GitHub's avatar host resizes on request (the `s` parameter), so each
/// avatar is stored at the sizes the app has asked for. Like SDWebImage, a
/// size already cached is reused before downloading: a larger cached size is
/// scaled down instead of downloading a smaller one, and offline a smaller
/// cached size is scaled up rather than showing nothing.
///
/// A file older than [maxAge] is downloaded again; if that fails (e.g.
/// offline), the old file is still used. [trim] keeps the files within
/// [maxBytes], removing the least recently used first; the app calls it when
/// it goes to the background, like SDWebImage, rather than on every write.
///
/// A file's modification time records when it was downloaded, and its
/// access time when it was last used.
class AvatarCache {
  AvatarCache(
    this._http, {
    required this.directory,
    this.maxBytes = defaultMaxBytes,
    this._now = DateTime.now,
  });

  final http.Client _http;
  final Directory directory;
  final int maxBytes;
  final DateTime Function() _now;

  /// GitHub can change an avatar without changing its URL.
  static const maxAge = Duration(days: 7);

  /// Thousands of list-sized avatars, at a few KB each.
  static const defaultMaxBytes = 20 * 1024 * 1024;

  static const _gitHubAvatarHost = 'avatars.githubusercontent.com';

  /// Each avatar's cached sizes, built from [directory] on first use. It may
  /// list files since deleted (by [trim] or the OS); [load] checks.
  Future<Map<String, Map<int, File>>>? _index;

  var _writes = 0;

  /// The image at [url] for display at [pixels] wide, from disk when a
  /// fresh copy at least that large is cached, otherwise downloaded at that
  /// size.
  ///
  /// Throws if the download fails and no size of the avatar is cached.
  Future<Uint8List> load(Uri url, {required int pixels}) async {
    final avatar = _avatarKey(url);
    final size = _resizes(url) ? pixels : 0;
    final cached = await _cachedSizes(avatar);

    // The closest larger fresh size: the least to download, decode and scale.
    for (final file in _largerFirst(cached, size)) {
      final stat = await file.stat();
      if (stat.type == FileSystemEntityType.notFound) continue;
      if (_now().difference(stat.modified) < maxAge) return _read(file);
    }
    final Uint8List bytes;
    try {
      bytes = await _download(_requestUrl(url, size));
    } on Object {
      // Any size, however old, beats a placeholder.
      for (final file in [
        ..._largerFirst(cached, size),
        ..._smallerFirst(cached, size),
      ]) {
        if (await file.exists()) return _read(file);
      }
      rethrow;
    }
    // Caching is best effort: a full disk mustn't hide a downloaded avatar.
    try {
      await _store(avatar, size, bytes);
    } on FileSystemException {
      // Not cached this time.
    }
    return bytes;
  }

  /// Deletes every cached size of [url], e.g. because the one [load]
  /// returned doesn't decode, so the next [load] downloads it again.
  Future<void> remove(Uri url) async {
    final cached = await _cachedSizes(_avatarKey(url));
    final files = [...cached.values];
    cached.clear();
    for (final file in files) {
      await _delete(file);
    }
  }

  /// Removes leftover temporary files, then the least recently used files
  /// until the rest fit in [maxBytes].
  ///
  /// Old files stay while there is room: offline, they are all there is.
  /// Passes may overlap: a file another pass already deleted is skipped.
  Future<void> trim() async {
    if (!await directory.exists()) return;
    final files = <({File file, FileStat stat})>[];
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      if (entity.path.endsWith(_temporarySuffix)) {
        await _delete(entity);
        continue;
      }
      final stat = await entity.stat();
      if (stat.type != FileSystemEntityType.notFound) {
        files.add((file: entity, stat: stat));
      }
    }
    files.sort((a, b) => a.stat.accessed.compareTo(b.stat.accessed));
    var total = files.fold<int>(0, (sum, entry) => sum + entry.stat.size);
    for (final (:file, :stat) in files) {
      if (total <= maxBytes) break;
      await _delete(file);
      total -= stat.size;
    }
  }

  Future<Map<int, File>> _cachedSizes(String avatar) async =>
      (await (_index ??= _readIndex())).putIfAbsent(avatar, () => {});

  Future<Map<String, Map<int, File>>> _readIndex() async {
    final index = <String, Map<int, File>>{};
    if (!await directory.exists()) return index;
    await for (final entity in directory.list()) {
      final name = entity.uri.pathSegments.last;
      if (entity is! File || name.endsWith(_temporarySuffix)) continue;
      if (name.split('_') case [final avatar, final size]) {
        if (int.tryParse(size) case final pixels?) {
          index.putIfAbsent(avatar, () => {})[pixels] = entity;
        }
      }
    }
    return index;
  }

  static Iterable<File> _largerFirst(Map<int, File> cached, int size) => [
    for (final pixels
        in cached.keys.where((pixels) => pixels >= size).toList()..sort())
      cached[pixels]!,
  ];

  static Iterable<File> _smallerFirst(Map<int, File> cached, int size) => [
    for (final pixels
        in cached.keys.where((pixels) => pixels < size).toList()
          ..sort((a, b) => b.compareTo(a)))
      cached[pixels]!,
  ];

  /// Reads [file] and marks it as just used.
  Future<Uint8List> _read(File file) async {
    final bytes = await file.readAsBytes();
    await file.setLastAccessed(_now());
    return bytes;
  }

  Future<Uint8List> _download(Uri url) async {
    final response = await _http.get(url);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('${response.statusCode} for $url', uri: url);
    }
    if (response.bodyBytes.isEmpty) {
      throw HttpException('Empty image for $url', uri: url);
    }
    return response.bodyBytes;
  }

  /// Writes [bytes] to a temporary file and renames it, so a reader never
  /// sees a partly written image. Each write has its own temporary file, in
  /// case the same avatar is downloaded twice at once.
  Future<void> _store(String avatar, int size, Uint8List bytes) async {
    await directory.create(recursive: true);
    final file = File('${directory.path}/${avatar}_$size');
    final temporary = File('${file.path}.${_writes++}$_temporarySuffix');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.setLastModified(_now());
    await temporary.setLastAccessed(_now());
    await temporary.rename(file.path);
    (await _cachedSizes(avatar))[size] = file;
  }

  /// Deletes [file] unless it is already gone, e.g. removed by a [trim]
  /// pass or the OS clearing caches.
  static Future<void> _delete(File file) async {
    try {
      await file.delete();
    } on PathNotFoundException {
      // Already gone.
    }
  }

  static const _temporarySuffix = '.tmp';

  static bool _resizes(Uri url) => url.host == _gitHubAvatarHost;

  /// [url] at [size] pixels on GitHub's avatar host; other URLs as they are.
  static Uri _requestUrl(Uri url, int size) => _resizes(url)
      ? url.replace(queryParameters: {...url.queryParameters, 's': '$size'})
      : url;

  /// One name for every size of an avatar: its `avatar_url`, which has no
  /// size.
  static String _avatarKey(Uri url) => _fnv1a64(url.toString());

  /// A stable 64-bit FNV-1a hash, as a file name for [text].
  static String _fnv1a64(String text) {
    var hash = 0xcbf29ce484222325;
    for (final unit in text.codeUnits) {
      hash ^= unit;
      hash *= 0x100000001b3;
    }
    return hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
  }
}
