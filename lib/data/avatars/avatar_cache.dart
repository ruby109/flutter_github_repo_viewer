import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Avatar images on disk, so they show after a restart and offline without
/// downloading them again.
///
/// One file per URL in [directory]. A file downloaded more than [maxAge]
/// ago is downloaded again; if that fails (e.g. offline), the old file is
/// still used. [trim] keeps the files within [maxBytes], removing the least
/// recently used first; the app calls it when it goes to the background,
/// like SDWebImage, rather than on every write.
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

  /// The image bytes at [url], from disk when fresh, otherwise downloaded.
  ///
  /// Throws if the download fails and no copy is stored.
  Future<Uint8List> load(Uri url) async {
    final file = _fileFor(url);
    final stored = file.existsSync() ? file.statSync() : null;
    if (stored != null && _now().difference(stored.modified) < maxAge) {
      return _read(file);
    }
    try {
      final bytes = await _download(url);
      await _store(file, bytes);
      return bytes;
    } on Object {
      if (stored != null) return _read(file);
      rethrow;
    }
  }

  /// Removes leftover temporary files, then the least recently used files
  /// until the rest fit in [maxBytes].
  ///
  /// Old files stay while there is room: offline, they are all there is.
  Future<void> trim() async {
    if (!directory.existsSync()) return;
    final files = <({File file, FileStat stat})>[];
    for (final entity in directory.listSync()) {
      if (entity is! File) continue;
      if (entity.path.endsWith(_temporarySuffix)) {
        await entity.delete();
      } else {
        files.add((file: entity, stat: entity.statSync()));
      }
    }
    files.sort((a, b) => a.stat.accessed.compareTo(b.stat.accessed));
    var total = files.fold<int>(0, (sum, entry) => sum + entry.stat.size);
    for (final (:file, :stat) in files) {
      if (total <= maxBytes) break;
      await file.delete();
      total -= stat.size;
    }
  }

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
  /// sees a partly written image.
  Future<void> _store(File file, Uint8List bytes) async {
    await directory.create(recursive: true);
    final temporary = File('${file.path}$_temporarySuffix');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.setLastModified(_now());
    await temporary.setLastAccessed(_now());
    await temporary.rename(file.path);
  }

  static const _temporarySuffix = '.tmp';

  File _fileFor(Uri url) =>
      File('${directory.path}/${_fnv1a64(url.toString())}');

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
