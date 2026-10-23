import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class Spotlight {
  final AnimeRef anime;
  final String? banner;
  final String? description;
  Spotlight(this.anime, this.banner, this.description);
}

class HomeData {
  final List<Spotlight> spotlight;
  final Map<String, List<AnimeRef>> sections; // ordered
  final List<AnimeRef> top10Day;
  final List<AnimeRef> top10Week;
  final List<AnimeRef> top10Month;
  HomeData(this.spotlight, this.sections, this.top10Day, this.top10Week, this.top10Month);
}

/// Category pages on the streaming site, in display order.
class Category {
  final String key;
  final String title;
  final String path;
  const Category(this.key, this.title, this.path);
}

const kCategories = [
  Category('top-airing', 'Top Airing', 'top-airing'),
  Category('most-popular', 'Most Popular', 'most-popular'),
  Category('recently-updated', 'Latest Episodes', 'recently-updated'),
  Category('most-favorite', 'Most Favorite', 'most-favorite'),
  Category('top-upcoming', 'Top Upcoming', 'top-upcoming'),
  Category('movie', 'Movies', 'movie'),
  Category('tv', 'TV Series', 'tv'),
  Category('dubbed-anime', 'Dubbed Anime', 'dubbed-anime'),
  Category('subbed-anime', 'Subbed Anime', 'subbed-anime'),
  Category('ova', 'OVA', 'ova'),
  Category('ona', 'ONA', 'ona'),
  Category('special', 'Specials', 'special'),
];

const kGenres = [
  'action', 'adventure', 'comedy', 'drama', 'fantasy', 'romance', 'sci-fi', 'slice-of-life',
  'supernatural', 'mystery', 'horror', 'psychological', 'thriller', 'sports', 'mecha', 'music',
  'school', 'shounen', 'shoujo', 'seinen', 'josei', 'isekai', 'historical', 'military',
  'martial-arts', 'magic', 'super-power', 'demons', 'space', 'samurai', 'harem', 'kids',
  'parody', 'police', 'game', 'detective', 'reincarnation', 'time-travel', 'mythology', 'iyashikei',
];

String genreLabel(String slug) =>
    slug.split('-').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

/// Auto-fetches listings straight from the streaming site's pages, so every
/// listed anime is guaranteed to be playable. Retries, mirror fallback and
/// caching keep it reliable.
class HiAnimeSource {
  HiAnimeSource._();
  static final HiAnimeSource instance = HiAnimeSource._();

  final List<String> _mirrors = ['https://hianime.at/'];
  void setMirrors(List<String> m) {
    final clean = m
        .map((e) => e.trim())
        .where((e) => e.startsWith('http'))
        .map((e) => e.endsWith('/') ? e : '$e/')
        .toList();
    if (clean.isNotEmpty) {
      _mirrors
        ..clear()
        ..addAll(clean);
    }
  }

  List<String> get mirrors => List.unmodifiable(_mirrors);

  final _cache = <String, (DateTime, String)>{};
  static const _ttl = Duration(minutes: 15);

  Future<String> _page(String path) async {
    final hit = _cache[path];
    if (hit != null && DateTime.now().difference(hit.$1) < _ttl) return hit.$2;
    Object? lastErr;
    for (final base in _mirrors) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final res = await http.get(Uri.parse('$base$path'), headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 Chrome/124 Mobile Safari/537.36',
            'Accept': 'text/html',
          }).timeout(const Duration(seconds: 20));
          if (res.statusCode == 200 && res.body.contains('film-poster')) {
            final body = utf8.decode(res.bodyBytes, allowMalformed: true);
            _cache[path] = (DateTime.now(), body);
            return body;
          }
          lastErr = 'HTTP ${res.statusCode}';
        } catch (e) {
          lastErr = e;
        }
        await Future.delayed(Duration(milliseconds: 600 * (attempt + 1)));
      }
    }
    if (hit != null) return hit.$2; // stale is better than nothing
    throw Exception('Could not reach anime source ($lastErr)');
  }

  void clearCache() => _cache.clear();

  static String _clean(String s) => s
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&#039;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String? _m(String src, String pattern) {
    final m = RegExp(pattern, dotAll: true).firstMatch(src);
    return m == null ? null : m.group(1);
  }

  static String? _idFromHref(String? href) {
    if (href == null) return null;
    final path = href.split('?').first;
    final m = RegExp(r'-(\d+)$').firstMatch(path);
    return m?.group(1);
  }

  static AnimeRef? _parseItem(String block) {
    final href = _m(block, r'class="film-name">\s*<a[^>]*href="([^"]+)"') ??
        _m(block, r'href="([^"]+)"');
    final id = _m(block, r'data-id="(\d+)"') ?? _idFromHref(href);
    final title = _m(block, r'class="dynamic-name"[^>]*>([^<]+)<') ??
        _m(block, r'title="([^"]+)"') ??
        _m(block, r'alt="([^"]+)"');
    if (id == null || title == null) return null;
    final poster = _m(block, r'<img[^>]*?(?:data-src|src)="([^"]+)"');
    final sub = int.tryParse(_clean(_m(block, r'tick-sub">(.*?)</div>') ?? '')) ?? 0;
    final dub = int.tryParse(_clean(_m(block, r'tick-dub">(.*?)</div>') ?? '')) ?? 0;
    final eps = int.tryParse(_clean(_m(block, r'tick-eps">(.*?)</div>') ?? ''));
    final type = _m(block, r'<span class="fdi-item">([^<]+)</span>');
    return AnimeRef(
      cloverId: id,
      title: _clean(title),
      altTitle: _m(block, r'data-jname="([^"]+)"'),
      poster: poster,
      type: type?.trim(),
      sub: sub,
      dub: dub,
      episodes: eps ?? (sub > 0 ? sub : null),
    );
  }

  static List<AnimeRef> _parseList(String html, String marker) {
    final parts = html.split(marker);
    final seen = <String>{};
    final out = <AnimeRef>[];
    for (final p in parts.skip(1)) {
      final block = p.length > 3500 ? p.substring(0, 3500) : p;
      final a = _parseItem(block);
      if (a != null && seen.add(a.cloverId!)) out.add(a);
    }
    return out;
  }

  /// Splits the home page by section heading and parses each block.
  Future<HomeData> home() async {
    final html = await _page('home');

    final spot = <Spotlight>[];
    for (final p in html.split('class="deslide-item"').skip(1).take(12)) {
      final block = p.length > 6000 ? p.substring(0, 6000) : p;
      final title = _m(block, r'desi-head-title[^>]*>(.*?)</div>');
      final href = _m(block, r'href="([^"]*/watch/[^"]+)"') ?? _m(block, r'href="(https?://[^"]+-\d+)"');
      final id = _idFromHref(href);
      if (title == null || id == null) continue;
      final type = _m(block, r'fa-play-circle mr-1"></i>\s*([A-Za-z]+)');
      final sub = int.tryParse(_clean(_m(block, r'tick-sub">(.*?)</div>') ?? '')) ?? 0;
      final dub = int.tryParse(_clean(_m(block, r'tick-dub">(.*?)</div>') ?? '')) ?? 0;
      final banner = _m(block, r'<img[^>]*?(?:data-src|src)="([^"]+)"');
      spot.add(Spotlight(
        AnimeRef(
          cloverId: id,
          title: _clean(title),
          altTitle: _m(block, r'data-jname="([^"]+)"'),
          poster: banner,
          type: type,
          sub: sub,
          dub: dub,
        ),
        banner,
        _m(block, r'desi-description">(.*?)</div>') == null
            ? null
            : _clean(_m(block, r'desi-description">(.*?)</div>')!),
      ));
    }

    final sections = <String, List<AnimeRef>>{};
    final heads = RegExp(r'<h2 class="cat-heading">\s*([^<]+?)\s*</h2>').allMatches(html).toList();
    for (var i = 0; i < heads.length; i++) {
      final name = _clean(heads[i].group(1)!);
      if (name == 'Genres' || name == 'Top 10') continue;
      final end = i + 1 < heads.length ? heads[i + 1].start : html.length;
      final chunk = html.substring(heads[i].end, end);
      var items = _parseList(chunk, 'class="flw-item');
      if (items.isEmpty) items = _parseList(chunk, 'class="item"');
      if (items.isEmpty) items = _parseList(chunk, 'class="swiper-slide"');
      if (items.isNotEmpty) sections[name] = items;
    }

    List<AnimeRef> top(String id) {
      final s = html.indexOf('id="$id"');
      if (s < 0) return [];
      final rest = html.substring(s);
      final e = rest.indexOf('</ul>');
      return _parseList(e > 0 ? rest.substring(0, e) : rest, 'class="film-number');
    }

    var day = top('top-viewed-day');
    if (day.isEmpty) day = _parseList(html, 'class="film-number');

    return HomeData(spot, sections, day, top('top-viewed-week'), top('top-viewed-month'));
  }

  Future<List<AnimeRef>> category(String path, {int page = 1}) async {
    final html = await _page(page > 1 ? '$path?page=$page' : path);
    return _parseList(html, 'class="flw-item');
  }

  Future<List<AnimeRef>> genre(String slug, {int page = 1}) => category('genres/$slug', page: page);

  Future<List<AnimeRef>> azList(String letter, {int page = 1}) => category('az-list/$letter', page: page);
}
