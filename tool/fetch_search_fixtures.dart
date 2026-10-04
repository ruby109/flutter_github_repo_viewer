// Downloads a real Search API response and its owners' avatars into
// test/fixtures, so tests and goldens use real data without the network.
//
// Usage: dart run tool/fetch_search_fixtures.dart
//
// The fixtures are a snapshot: rerunning this replaces them, and golden
// files that show them must then be regenerated.
import 'dart:convert';
import 'dart:io';

const _query = 'flutter';
const _itemCount = 20;

/// Avatars are shown at most 40 logical pixels wide, so 80 pixels covers a
/// 2x screen.
const _avatarSize = 80;

final _fixtures = Directory('test/fixtures');

Future<void> main() async {
  final client = HttpClient()..userAgent = 'github_repo_viewer fixtures';
  try {
    final search = await _getJson(
      client,
      Uri.https('api.github.com', '/search/repositories', {
        'q': _query,
        'per_page': '$_itemCount',
      }),
    );
    final items = (search['items']! as List<Object?>)
        .cast<Map<String, Object?>>();

    final avatars = Directory('${_fixtures.path}/avatars');
    if (avatars.existsSync()) avatars.deleteSync(recursive: true);
    avatars.createSync(recursive: true);
    for (final item in items) {
      final owner = item['owner']! as Map<String, Object?>;
      final url = Uri.parse(owner['avatar_url']! as String);
      final userId = url.pathSegments.last;
      final bytes = await _getBytes(
        client,
        url.replace(
          queryParameters: {...url.queryParameters, 's': '$_avatarSize'},
        ),
      );
      File('${avatars.path}/$userId').writeAsBytesSync(bytes);
    }

    File('${_fixtures.path}/search_$_query.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(search)}\n',
    );
    stdout.writeln('Saved ${items.length} results and their avatars.');
  } finally {
    client.close();
  }
}

Future<Map<String, Object?>> _getJson(HttpClient client, Uri url) async {
  final bytes = await _getBytes(client, url);
  return jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
}

Future<List<int>> _getBytes(HttpClient client, Uri url) async {
  final request = await client.getUrl(url);
  final response = await request.close();
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('${response.statusCode} for $url', uri: url);
  }
  return [for (final chunk in await response.toList()) ...chunk];
}
