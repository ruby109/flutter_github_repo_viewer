import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;

import 'avatar_cache.dart';

/// Where avatars are cached: the system's temporary (cache) directory,
/// which the OS may clear when storage runs low, as a cache allows.
final avatarCacheDirectoryProvider = Provider<Directory>(
  (ref) => Directory('${Directory.systemTemp.path}/avatars'),
);

/// The app's avatar cache, with its own HTTP client: avatars come from
/// GitHub's image host, not the API.
///
/// Trimmed when the app goes to the background, like SDWebImage, rather
/// than on every write.
final avatarCacheProvider = Provider<AvatarCache>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  final cache = AvatarCache(
    client,
    directory: ref.watch(avatarCacheDirectoryProvider),
  );
  final lifecycle = AppLifecycleListener(onHide: () => unawaited(cache.trim()));
  ref.onDispose(lifecycle.dispose);
  return cache;
});
