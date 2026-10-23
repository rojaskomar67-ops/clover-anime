import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Jikan (MyAnimeList) public API for accurate listings, categories and genres.
class JikanApi {
  JikanApi._();
  static final JikanApi instance = JikanApi._();

  static const _base = 'https://api.jikan.moe/v4/';
  final _cache = <String, dynamic>{};
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _queue = Future.value();

  /// Runs requests one at a time so the catalog never rate-limits us.
  Future<dynamic> _get(String path) {
    if (_cache.containsKey(path)) return Future.value(_cache[path]);
    final next = _queue.then((_) => _fetch(path));
    _queue = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<dynamic> _fetch(String path) async {
    if (_cache.containsKey(path)) return _cache[path];
    // Jikan allows ~3 requests/second; space calls out.
    for (var attempt = 0; attempt < 3; attempt++) {
      final wait = 400 - DateTime.now().difference(_last).inMilliseconds;
      if (wait > 0) await Future.delayed(Duration(milliseconds: wait));
      _last = DateTime.now();
      final res = await http
          .get(Uri.parse('$_base$path'))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 429) {
        await Future.delayed(Duration(milliseconds: 900 * (attempt + 1)));
        continue;
      }
      if (res.statusCode != 200) throw Exception('Catalog error ${res.statusCode}');
      final d = jsonDecode(utf8.decode(res.bodyBytes));
      _cache[path] = d;
      return d;
    }
    throw Exception('Catalog busy, try again');
  }

  List<AnimeRef> _list(dynamic d) {
    final seen = <int>{};
    return ((d['data'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AnimeRef.fromJikan)
        .where((a) => seen.add(a.malId ?? 0))
        .toList();
  }

  Future<List<AnimeRef>> topAiring() async =>
      _list(await _get('top/anime?filter=airing&limit=20&sfw=true'));
  Future<List<AnimeRef>> mostPopular() async =>
      _list(await _get('top/anime?filter=bypopularity&limit=20&sfw=true'));
  Future<List<AnimeRef>> seasonNow() async =>
      _list(await _get('seasons/now?limit=20&sfw=true'));
  Future<List<AnimeRef>> upcoming() async =>
      _list(await _get('seasons/upcoming?limit=20&sfw=true'));
  Future<List<AnimeRef>> topMovies() async =>
      _list(await _get('top/anime?type=movie&limit=20&sfw=true'));
  Future<List<AnimeRef>> favorites() async =>
      _list(await _get('top/anime?filter=favorite&limit=20&sfw=true'));

  Future<List<AnimeRef>> byGenre(int genreId, {int page = 1, String order = 'popularity'}) async =>
      _list(await _get(
          'anime?genres=$genreId&order_by=$order&sort=${order == 'score' ? 'desc' : 'asc'}&page=$page&limit=24&sfw=true'));

  Future<List<AnimeRef>> schedule(String day) async =>
      _list(await _get('schedules?filter=$day&limit=24&sfw=true'));

  Future<List<Genre>> genres() async {
    final d = await _get('genres/anime?filter=genres');
    return ((d['data'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map((g) => Genre(g['mal_id'] as int, g['name'].toString(), (g['count'] as num?)?.toInt() ?? 0))
        .toList();
  }

  Future<Map<String, dynamic>?> full(int malId) async {
    try {
      final d = await _get('anime/$malId/full');
      return d['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<List<AnimeRef>> recommendations(int malId) async {
    try {
      final d = await _get('anime/$malId/recommendations');
      return ((d['data'] as List?) ?? [])
          .take(15)
          .map((e) => AnimeRef.fromJikan((e as Map<String, dynamic>)['entry'] as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
