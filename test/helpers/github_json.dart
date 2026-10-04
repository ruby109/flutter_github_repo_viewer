/// Minimal GitHub API JSON payloads for tests.
library;

/// A repository as it appears in Search API results.
Map<String, Object?> repoJson({int id = 1, String fullName = 'owner/repo'}) {
  return {
    'id': id,
    'full_name': fullName,
    'owner': <String, Object?>{
      'login': fullName.split('/').first,
      'avatar_url': 'https://avatars.githubusercontent.com/u/$id?v=4',
    },
  };
}

/// A Search API response body containing [items].
Map<String, Object?> searchJson({
  required int totalCount,
  required List<Map<String, Object?>> items,
}) {
  return {
    'total_count': totalCount,
    'incomplete_results': false,
    'items': items,
  };
}
