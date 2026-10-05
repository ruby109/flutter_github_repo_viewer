import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../data/avatars/avatar_cache.dart';

/// An avatar image loaded through [AvatarCache], so it is read from disk
/// when it was seen before, also after a restart and offline.
///
/// Like `NetworkImage`, it is keyed by URL in the in-memory `ImageCache`.
@immutable
class CachedAvatarImage extends ImageProvider<CachedAvatarImage> {
  const CachedAvatarImage(this.url, this.cache);

  final Uri url;
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
    try {
      final bytes = await cache.load(url);
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } on Object {
      // Not cached as failed in memory, so it is tried again next time.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CachedAvatarImage && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'CachedAvatarImage("$url")';
}
