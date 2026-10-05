import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../data/avatars/avatar_cache.dart';

/// An avatar for display [pixels] wide, loaded through [AvatarCache], so it
/// is read from disk when it was seen before, also after a restart and
/// offline.
///
/// Keyed by URL and size in the in-memory `ImageCache`.
@immutable
class CachedAvatarImage extends ImageProvider<CachedAvatarImage> {
  const CachedAvatarImage(
    this.url, {
    required this.pixels,
    required this.cache,
  });

  /// The owner's `avatar_url`.
  final Uri url;
  final int pixels;
  final AvatarCache cache;

  @override
  Future<CachedAvatarImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    CachedAvatarImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: 1,
      debugLabel: url.toString(),
    );
  }

  Future<ui.Codec> _load(
    CachedAvatarImage key,
    ImageDecoderCallback decode,
  ) async {
    // A failure isn't kept in the ImageCache, so showing it again retries.
    final bytes = await cache.load(url, pixels: pixels);
    try {
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } on Object {
      // Bytes that aren't an image would otherwise stay cached for days.
      await cache.remove(url);
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CachedAvatarImage && other.url == url && other.pixels == pixels;

  @override
  int get hashCode => Object.hash(url, pixels);

  @override
  String toString() => 'CachedAvatarImage("$url", pixels: $pixels)';
}
