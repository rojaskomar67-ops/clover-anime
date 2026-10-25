import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide switch between the default catalog and Hindi mode.
class ModeController extends ValueNotifier<bool> {
  ModeController._() : super(false);
  static final instance = ModeController._();

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    value = p.getBool('hindiMode') ?? false;
  }

  Future<void> set(bool hindi) async {
    value = hindi;
    final p = await SharedPreferences.getInstance();
    await p.setBool('hindiMode', hindi);
  }
}

class HindiAnime {
  final String id;
  final String title;
  final String link;
  final String? poster;
  final String? languages;
  final String? badge;
  final int? rank;
  const HindiAnime({
    required this.id,
    required this.title,
    required this.link,
    this.poster,
    this.languages,
    this.badge,
    this.rank,
  });

  bool get isMovie => link.contains('/movies/');

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'link': link, 'poster': poster, 'languages': languages};
  factory HindiAnime.fromJson(Map<String, dynamic> j) => HindiAnime(
        id: '${j['id'] ?? slugOf('${j['link']}')}',
        title: '${j['title'] ?? ''}',
        link: '${j['link'] ?? ''}',
        poster: j['poster'] as String?,
        languages: j['languages'] as String?,
      );
}

String slugOf(String link) {
  final parts = Uri.tryParse(link)?.pathSegments.where((s) => s.isNotEmpty).toList() ?? [];
  return parts.isEmpty ? link : parts.last;
}

class HindiSection {
  final String title;
  final List<HindiAnime> items;
  const HindiSection(this.title, this.items);
}

class HindiEpisode {
  final int season;
  final int number;
  final String link;
  final String title;
  final String label;
  const HindiEpisode(this.season, this.number, this.link, this.title, this.label);
}

class HindiDetail {
  final String? description;
  final String? poster;
  final int total;
  final List<HindiEpisode> episodes;
  const HindiDetail({this.description, this.poster, this.total = 0, this.episodes = const []});
}

class HindiStream {
  final String server;
  final String url;
  final String m3u8;
  final String? referer;
  const HindiStream(this.server, this.url, this.m3u8, this.referer);
}

class HindiApi {
  HindiApi._();
  static final instance = HindiApi._();

  static const base = 'https://hindianime-apu-forapp.vercel.app';
  static const site = 'https://myanimes.in/';
  static const _key = '@BaignX';
  static const _ua =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36';

  static const homeSections = [
    'Recent Regional Dub Episodes',
    'On-Air Series',
    'Top 10 Series of All Time',
    'Most-Watched Series',
    'Recent English Dub Episodes',
    'Recent English Sub Episodes',
    'Top 10 Movies of All Time',
    'Most-Watched Movies',
    'Latest Anime Movies',
  ];

  List<HindiSection>? _home;
  DateTime? _homeAt;
  final _details = <String, HindiDetail>{};

  Future<dynamic> _get(String path, [Map<String, String>? q]) async {
    final uri = Uri.parse('$base$path').replace(queryParameters: q);
    Object? last;
    for (var i = 0; i < 3; i++) {
      try {
        final r = await http
            .get(uri, headers: {'X-API-Key': _key, 'Accept': 'application/json'})
            .timeout(const Duration(seconds: 45));
        if (r.statusCode == 200) return jsonDecode(utf8.decode(r.bodyBytes));
        if (r.statusCode == 404) throw Exception('Not found');
        last = Exception('Server error ${r.statusCode}');
      } catch (e) {
        last = e;
        if ('$e'.contains('Not found')) rethrow;
      }
      await Future.delayed(Duration(milliseconds: 700 * (i + 1)));
    }
    throw last ?? Exception('Request failed');
  }

  /// Reads the myanimes.in home page and returns its rows.
  Future<List<HindiSection>> home({bool force = false}) async {
    if (!force && _home != null && DateTime.now().difference(_homeAt!) < const Duration(minutes: 15)) {
      return _home!;
    }
    final p = await SharedPreferences.getInstance();
    try {
      String html = '';
      for (var i = 0; i < 3 && html.isEmpty; i++) {
        try {
          final r = await http.get(Uri.parse(site), headers: {'User-Agent': _ua}).timeout(const Duration(seconds: 30));
          if (r.statusCode == 200) html = utf8.decode(r.bodyBytes, allowMalformed: true);
        } catch (_) {}
      }
      if (html.isEmpty) throw Exception('Could not reach myanimes.in');
      final sections = parseHome(html);
      if (sections.isEmpty) throw Exception('Nothing found');
      _home = sections;
      _homeAt = DateTime.now();
      await p.setString('hindiHome', html);
      return sections;
    } catch (e) {
      final cached = p.getString('hindiHome');
      if (cached != null) return _home = parseHome(cached);
      rethrow;
    }
  }

  static String _unescape(String s) => s
      .replaceAll('&#039;', "'")
      .replaceAll('&#8217;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();

  static List<HindiSection> parseHome(String html) {
    final out = <HindiSection>[];
    final chunks = html.split('<h2');
    for (final chunk in chunks.skip(1)) {
      final t = RegExp(r'^[^>]*>([^<]*)').firstMatch(chunk);
      final title = _unescape(t?.group(1) ?? '');
      if (!homeSections.contains(title)) continue;
      final items = <HindiAnime>[];
      final seen = <String>{};
      for (final art in chunk.split('<article').skip(1)) {
        final a = RegExp(r'href="(https://myanimes\.in/[^"]+)"').firstMatch(art);
        if (a == null) continue;
        final link = a.group(1)!;
        if (!seen.add(link)) continue;
        final label = RegExp(r'aria-label="([^"]*)"').firstMatch(art)?.group(1);
        final h3 = RegExp(r'<h3>([^<]*)').firstMatch(art)?.group(1);
        final img = RegExp(r'<img[^>]*\ssrc="([^"]+)"').firstMatch(art)?.group(1);
        final badge = RegExp(r'as-episode-badge">([^<]*)').firstMatch(art)?.group(1);
        final rank = RegExp(r'as-rank">(\d+)').firstMatch(art)?.group(1);
        final langs = RegExp(r'as-card-languages[^>]*>([^<]*)').firstMatch(art)?.group(1);
        items.add(HindiAnime(
          id: slugOf(link),
          title: _unescape(h3 ?? label ?? slugOf(link)),
          link: link,
          poster: img,
          badge: badge == null ? null : _unescape(badge),
          languages: langs == null ? null : _unescape(langs),
          rank: rank == null ? null : int.tryParse(rank),
        ));
      }
      if (items.isNotEmpty) out.add(HindiSection(title, items));
    }
    return out;
  }

  Future<List<HindiAnime>> search(String q) async {
    final d = await _get('/api/search', {'q': q});
    return [for (final r in (d['results'] as List? ?? [])) HindiAnime.fromJson(Map<String, dynamic>.from(r))];
  }

  Future<HindiDetail> detail(HindiAnime a) async {
    if (_details[a.link] != null) return _details[a.link]!;
    String? desc;
    String? poster;
    try {
      final info = await _get('/api/anime/${a.id}');
      desc = info['description'] as String?;
      poster = info['poster'] as String?;
    } catch (_) {}
    var eps = <HindiEpisode>[];
    if (a.isMovie || a.link.contains('/episode/')) {
      eps = [HindiEpisode(1, 1, a.link, a.title, a.isMovie ? 'Movie' : 'Episode')];
    } else {
      final d = await _get('/api/episodes', {'link': a.link});
      eps = [
        for (final e in (d['episodes'] as List? ?? []))
          HindiEpisode(
            (e['season'] as num?)?.toInt() ?? 1,
            (e['number'] as num?)?.toInt() ?? 0,
            '${e['link']}',
            '${e['title'] ?? ''}',
            '${e['label'] ?? 'EP ${e['number']}'}',
          )
      ];
    }
    return _details[a.link] = HindiDetail(description: desc, poster: poster, total: eps.length, episodes: eps);
  }

  Future<List<HindiStream>> streams(String episodeLink) async {
    final d = await _get('/api/extract', {'link': episodeLink});
    return [
      for (final s in (d['streams'] as List? ?? []))
        if ((s['proxy_url'] ?? s['m3u8']) != null)
          HindiStream('${s['server'] ?? 'Server'}', '${s['proxy_url'] ?? s['m3u8']}', '${s['m3u8'] ?? ''}',
              s['referer'] as String?)
    ];
  }

  // ---- local Hindi history & list ----
  Future<List<HindiAnime>> _readList(String k) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(k) ?? [];
    return [for (final r in raw) HindiAnime.fromJson(jsonDecode(r))];
  }

  Future<void> _writeList(String k, List<HindiAnime> l) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(k, [for (final a in l.take(60)) jsonEncode(a.toJson())]);
  }

  Future<List<HindiAnime>> history() => _readList('hindiHistory');
  Future<void> addHistory(HindiAnime a) async {
    final l = (await history())..removeWhere((x) => x.link == a.link);
    await _writeList('hindiHistory', [a, ...l]);
  }

  Future<List<HindiAnime>> saved() => _readList('hindiSaved');
  Future<bool> isSaved(HindiAnime a) async => (await saved()).any((x) => x.link == a.link);
  Future<bool> toggleSaved(HindiAnime a) async {
    final l = await saved();
    final had = l.any((x) => x.link == a.link);
    l.removeWhere((x) => x.link == a.link);
    await _writeList('hindiSaved', had ? l : [a, ...l]);
    return !had;
  }

  Future<int> position(String link) async =>
      (await SharedPreferences.getInstance()).getInt('hpos:$link') ?? 0;
  Future<void> savePosition(String link, int s) async =>
      (await SharedPreferences.getInstance()).setInt('hpos:$link', s);
}
