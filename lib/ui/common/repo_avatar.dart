import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/avatars/avatar_providers.dart';
import 'cached_avatar_image.dart';

/// A repository owner's avatar, or a placeholder when there is none or it
/// fails to load.
///
/// Loaded through the disk cache ([avatarCacheProvider]), so avatars seen
/// before show after a restart and offline.
///
/// Decorative: the repository name next to it identifies the repository.
class RepoAvatar extends ConsumerWidget {
  const RepoAvatar({super.key, required this.url, this.size = 40});

  /// The owner's `avatar_url`; null when the repository has no owner.
  final String? url;

  /// The diameter in logical pixels.
  final double size;

  static const placeholderIcon = Icons.person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeholder = _Placeholder(size: size);
    // owner.avatar_url can be any string, so it may not parse.
    final url = Uri.tryParse(this.url ?? '');
    if (url == null || !url.hasAuthority) return placeholder;

    // GitHub serves avatars at 460 pixels by default; fetch and decode only
    // the pixels shown, which keeps long result lists light on memory.
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return ExcludeSemantics(
      child: ClipOval(
        child: Image(
          image: ResizeImage(
            CachedAvatarImage(
              url,
              pixels: pixels,
              cache: ref.watch(avatarCacheProvider),
            ),
            width: pixels,
            height: pixels,
          ),
          width: size,
          height: size,
          fit: BoxFit.cover,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
              frame == null && !wasSynchronouslyLoaded ? placeholder : child,
          errorBuilder: (context, error, stackTrace) => placeholder,
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: colors.surfaceContainerHighest,
        child: Icon(
          RepoAvatar.placeholderIcon,
          size: size * 0.6,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
