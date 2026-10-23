import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// Client for the Clover streaming API (same backend as the original app).
class CloverApi {
  CloverApi._();
  static final CloverApi instance = CloverApi._();

  static const _xorMask = [59, 95, 18, 122, 77, 34, 110, 25];
  static const _encBase = 'UytmCj4YQTZaMXsXKA8PaVJydBU/Qx5pFSl3CC5HAjdaL2JV';
  static const _encKey = 'ex1zEypMNg==';

  static String _xor(String b64) {
    final bytes = base64Decode(b64);
    return utf8.decode([
      for (var i = 0; i < bytes.length; i++) bytes[i] ^ _xorMask[i % _xorMask.length]
    ]);
  }

  final String _apiKey = _xor(_encKey);
  String _baseUrl = _xor(_encBase);

  String get baseUrl => _baseUrl;

  /// Admin can override the API URL from Firestore (app_config/api).
  void setBaseUrl(String? url) {
    if (url == null || url.trim().isEmpty) return;
    _baseUrl = url.trim().endsWith('/') ? url.trim() : '${url.trim()}/';
  }

  final _cache = <String, dynamic>{};

  Future<dynamic> _get(String path, Map<String, String?> query, {bool cache = true}) async {
    final q = <String, String>{};
    query.forEach((k, v) {
      if (v != null && v.isNotEmpty) q[k] = v;
    });
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: q.isEmpty ? null : q);
    final cacheKey = uri.toString();
    if (cache && _cache.containsKey(cacheKey)) return _cache[cacheKey];

    final ts = DateTime.now().millisecondsSinceEpoch;
    final sig = base64Encode(
      sha256.convert(utf8.encode('$_apiKey:$ts:${uri.path}:clover_shield')).bytes,
    );
    final res = await http.get(uri, headers: {
      'X-API-Key': _apiKey,
      'X-Client-Timestamp': '$ts',
      'X-Client-Signature': sig,
      'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) CloverAnime/3.0',
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 40));
    if (res.statusCode != 200) {
      throw Exception('Server error ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (cache) _cache[cacheKey] = data;
    return data;
  }

  Future<List<AnimeRef>> search(String query, {int page = 1}) async {
    final d = await _get('api/search', {'q': query, 'page': '$page'});
    return ((d['results'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AnimeRef.fromClover)
        .toList();
  }

  /// Finds the best Clover match for a title coming from the external catalog.
  Future<AnimeRef?> resolve(String title, {String? altTitle}) async {
    String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    for (final q in [title, if (altTitle != null && altTitle != title) altTitle]) {
      try {
        final results = await search(q);
        if (results.isEmpty) continue;
        final target = norm(q);
        final exact = results.where((r) =>
            norm(r.title) == target || norm(r.altTitle ?? '') == target);
        return exact.isNotEmpty ? exact.first : results.first;
      } catch (_) {}
    }
    return null;
  }

  Future<AnimeDetails> details(String id) async {
    final d = await _get('api/anime/$id', {});
    return AnimeDetails.fromJson(d as Map<String, dynamic>);
  }

  Future<List<Episode>> episodes(String id) async {
    final d = await _get('api/anime/$id/episodes', {});
    return ((d['episodes'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Episode.fromJson)
        .toList();
  }

  Future<List<ServerItem>> servers(String episodeId) async {
    final d = await _get('api/episodes/$episodeId/servers', {});
    return ((d['servers'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ServerItem.fromJson)
        .toList();
  }

  Future<StreamInfo> stream(String episodeId, {String? server, String type = 'sub'}) async {
    final d = await _get(
      'api/stream',
      {'episode_id': episodeId, 'server': server, 'type': type},
      cache: false,
    );
    final info = StreamInfo.fromJson(d as Map<String, dynamic>);
    if (info.url.isEmpty) throw Exception('No stream found on this server');
    return info;
  }
}
