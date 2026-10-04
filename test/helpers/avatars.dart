/// Real avatar images for widget and golden tests, without the network.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs [body] with `Image.network` loading GitHub avatar URLs from
/// `test/fixtures/avatars`, and passes it the URLs requested so far.
///
/// `https://avatars.githubusercontent.com/u/<id>?...` is served from
/// `test/fixtures/avatars/<id>`; any other URL fails with 404. Without this,
/// flutter_test answers every image request with 400.
///
/// Clears the image cache first, so every image is requested again.
///
/// Wraps the test body instead of resetting in a tear-down because
/// flutter_test checks that debug variables are unset before tear-downs run.
Future<void> withAvatarFixtures(
  Future<void> Function(List<Uri> requested) body,
) async {
  imageCache
    ..clear()
    ..clearLiveImages();
  final requested = <Uri>[];
  debugNetworkImageHttpClientProvider = () => _FixtureHttpClient(requested);
  try {
    await body(requested);
  } finally {
    debugNetworkImageHttpClientProvider = null;
  }
}

/// Waits until every [Image] on screen has loaded and decoded, or failed.
///
/// A failed image isn't cached, so this requests it once more.
///
/// Decoding runs outside the test's fake async zone, so pumping alone never
/// finishes it.
Future<void> loadImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = (element.widget as Image).image;
      await precacheImage(image, element, onError: (_, _) {});
    }
  });
  await tester.pump();
}

final class _FixtureHttpClient extends Fake implements HttpClient {
  _FixtureHttpClient(this._requested);

  final List<Uri> _requested;

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    _requested.add(url);
    return _FixtureRequest(_fixtureFor(url));
  }

  static File? _fixtureFor(Uri url) {
    if (url.host != 'avatars.githubusercontent.com') return null;
    if (url.pathSegments case ['u', final userId]) {
      final file = File('test/fixtures/avatars/$userId');
      if (file.existsSync()) return file;
    }
    return null;
  }
}

final class _FixtureRequest extends Fake implements HttpClientRequest {
  _FixtureRequest(this._fixture);

  final File? _fixture;

  @override
  Future<HttpClientResponse> close() async {
    return _FixtureResponse(_fixture?.readAsBytesSync());
  }
}

final class _FixtureResponse extends Fake implements HttpClientResponse {
  _FixtureResponse(this._bytes);

  final List<int>? _bytes;

  @override
  int get statusCode => _bytes == null ? HttpStatus.notFound : HttpStatus.ok;

  @override
  int get contentLength => _bytes?.length ?? 0;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.fromIterable([?_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
