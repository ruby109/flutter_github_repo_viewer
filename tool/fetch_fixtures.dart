// Downloads real GitHub API responses and their owners' avatars into
// test/fixtures, so tests and goldens use real data without the network:
// a Search API response, and the Repository API response for its first
// result.
//
// Usage: dart run tool/fetch_fixtures.dart
//
// The fixtures are a snapshot: rerunning this replaces them, and golden
// files that show them must then be regenerated.
import 'dart:convert';
import 'dart:io';

const _query = 'flutter';
const _itemCount = 20;

/// List avatars are 40 logical pixels wide, so 80 pixels covers a 2x
/// screen.
const _avatarSize = 80;

/// The detail screen's avatar is 96 logical pixels wide; 288 pixels covers
/// a 3x screen.
const _detailAvatarSize = 288;

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

    final detailName = items.first['full_name']! as String;
    final detail = await _getJson(
      client,
      Uri(
        scheme: 'https',
        host: 'api.github.com',
        pathSegments: ['repos', ...detailName.split('/')],
      ),
    );

    // Download everything before replacing anything, so a failed run
    // leaves the previous fixtures intact.
    final avatarBytes = <String, List<int>>{};
    for (final item in items) {
      // The Search API allows results without an owner; they keep their
      // place in the JSON but have no avatar.
      if (item['owner'] case {'avatar_url': final String avatarUrl}) {
        final url = Uri.parse(avatarUrl);
        final userId = url.pathSegments.last;
        if (avatarBytes.containsKey(userId)) continue;
        avatarBytes[userId] = await _getBytes(
          client,
          url.replace(
            queryParameters: {...url.queryParameters, 's': '$_avatarSize'},
          ),
        );
      }
    }

    // The detail screen shows its owner larger; the list scales it down.
    if (detail['owner'] case {'avatar_url': final String avatarUrl}) {
      final url = Uri.parse(avatarUrl);
      avatarBytes[url.pathSegments.last] = await _getBytes(
        client,
        url.replace(
          queryParameters: {...url.queryParameters, 's': '$_detailAvatarSize'},
        ),
      );
    }

    final avatars = Directory('${_fixtures.path}/avatars');
    if (avatars.existsSync()) avatars.deleteSync(recursive: true);
    avatars.createSync(recursive: true);
    avatarBytes.forEach((userId, bytes) {
      File('${avatars.path}/$userId').writeAsBytesSync(bytes);
    });
    File('${_fixtures.path}/search_$_query.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(search)}\n',
    );
    File('${_fixtures.path}/repo_${detailName.replaceAll('/', '_')}.json')
        .writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(detail)}\n',
        );
    stdout.writeln(
      'Saved ${items.length} results, $detailName and their avatars.',
    );
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
