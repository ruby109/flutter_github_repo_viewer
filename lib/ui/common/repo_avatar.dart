import 'package:flutter/material.dart';

/// A repository owner's avatar, or a placeholder when there is none or it
/// fails to load.
///
/// Decorative: the repository name next to it identifies the repository.
class RepoAvatar extends StatelessWidget {
  const RepoAvatar({super.key, required this.url, this.size = 40});

  /// The owner's `avatar_url`; null when the repository has no owner.
  final String? url;

  /// The diameter in logical pixels.
  final double size;

  static const placeholderIcon = Icons.person;

  static const _gitHubAvatarHost = 'avatars.githubusercontent.com';

  @override
  Widget build(BuildContext context) {
    final placeholder = _Placeholder(size: size);
    final url = this.url;
    if (url == null) return placeholder;

    // GitHub serves avatars at 460 pixels by default; fetch and decode only
    // the pixels shown, which keeps long result lists light on memory.
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return ExcludeSemantics(
      child: ClipOval(
        child: Image.network(
          _sized(url, pixels),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: pixels,
          cacheHeight: pixels,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
              frame == null && !wasSynchronouslyLoaded ? placeholder : child,
          errorBuilder: (context, error, stackTrace) => placeholder,
        ),
      ),
    );
  }

  /// Asks GitHub's avatar host for an image [pixels] wide.
  static String _sized(String url, int pixels) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host != _gitHubAvatarHost) return url;
    return uri
        .replace(queryParameters: {...uri.queryParameters, 's': '$pixels'})
        .toString();
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
