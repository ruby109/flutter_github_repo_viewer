import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;

import 'avatar_cache.dart';

/// The app's avatar cache, in the system's temporary (cache) directory,
/// which the OS may clear when storage runs low, as a cache allows.
///
/// Its own HTTP client: avatars come from GitHub's image host, not the API.
final avatarCacheProvider = Provider<AvatarCache>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return AvatarCache(
    client,
    directory: Directory('${Directory.systemTemp.path}/avatars'),
  );
});
