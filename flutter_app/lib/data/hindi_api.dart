import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/vault.dart';

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

  static String get base => Vault.hindiBase;
  static String get site => Vault.hindiSite;
  static String get _key => Vault.hindiKey;
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

  final changes = ValueNotifier<int>(0);
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
      if (html.isEmpty) throw Exception('Could not reach the Hindi library');
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
        final a = RegExp('href="(${RegExp.escape(site)}[^"]+)"').firstMatch(art);
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

  Future<void> saveLast(HindiAnime a, int index, String label, int pos, int dur) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('hlast:${a.link}', jsonEncode({'i': index, 'label': label, 'pos': pos, 'dur': dur}));
    if (dur > 0 && pos / dur > 0.9) await p.setBool('hdone:${a.link}#$index', true);
    final h = (await history())..removeWhere((x) => x.link == a.link);
    final item = HindiAnime(
        id: a.id, title: a.title, link: a.link, poster: a.poster, languages: '▶ $label', badge: null);
    await _writeList('hindiHistory', [item, ...h]);
    changes.value++;
  }

  Future<Map<String, dynamic>?> last(HindiAnime a) async {
    final r = (await SharedPreferences.getInstance()).getString('hlast:${a.link}');
    return r == null ? null : Map<String, dynamic>.from(jsonDecode(r));
  }

  Future<Set<int>> watched(HindiAnime a, int count) async {
    final p = await SharedPreferences.getInstance();
    return {for (var i = 0; i < count; i++) if (p.getBool('hdone:${a.link}#$i') == true) i};
  }

  Future<int> position(String link) async =>
      (await SharedPreferences.getInstance()).getInt('hpos:$link') ?? 0;
  Future<void> savePosition(String link, int s, [int dur = 0]) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('hpos:$link', s);
    if (dur > 0) await p.setInt('hdur:$link', dur);
  }

  /// Progress 0..1 per episode link.
  Future<Map<String, double>> progress(List<HindiEpisode> eps) async {
    final p = await SharedPreferences.getInstance();
    final m = <String, double>{};
    for (final e in eps) {
      final pos = p.getInt('hpos:${e.link}') ?? 0, dur = p.getInt('hdur:${e.link}') ?? 0;
      if (pos > 0 && dur > 0) m[e.link] = (pos / dur).clamp(0, 1).toDouble();
    }
    return m;
  }
}

// ---------------- HLS audio-language & quality control ----------------
class HlsAudio {
  final String name;
  final String lang;
  final String line;
  const HlsAudio(this.name, this.lang, this.line);
}

class HlsVariant {
  final String info;
  final String uri;
  final int height;
  final int bandwidth;
  const HlsVariant(this.info, this.uri, this.height, this.bandwidth);
  String get label => height > 0 ? '${height}p' : '${(bandwidth / 1000).round()} kbps';
}

class HlsMaster {
  final Uri url;
  final List<String> header;
  final List<HlsAudio> audios;
  final List<HlsVariant> variants;
  const HlsMaster(this.url, this.header, this.audios, this.variants);

  static String _attr(String line, String key) =>
      RegExp('$key="?([^",]*)"?').firstMatch(line)?.group(1) ?? '';

  static String _absUri(String line, Uri base) => line.replaceAllMapped(
      RegExp(r'URI="([^"]+)"'), (m) => 'URI="${base.resolve(m.group(1)!)}"');

  static HlsMaster parse(String text, Uri url) {
    final header = <String>[];
    final audios = <HlsAudio>[];
    final variants = <HlsVariant>[];
    final lines = text.split(RegExp(r'\r?\n'));
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i].trim();
      if (l.isEmpty) continue;
      if (l.startsWith('#EXT-X-MEDIA') && l.contains('TYPE=AUDIO')) {
        audios.add(HlsAudio(_attr(l, 'NAME'), _attr(l, 'LANGUAGE'), _absUri(l, url)));
      } else if (l.startsWith('#EXT-X-STREAM-INF')) {
        var j = i + 1;
        while (j < lines.length && (lines[j].trim().isEmpty || lines[j].startsWith('#'))) {
          j++;
        }
        if (j >= lines.length) break;
        final res = _attr(l, 'RESOLUTION');
        final h = res.contains('x') ? int.tryParse(res.split('x').last) ?? 0 : 0;
        variants.add(HlsVariant(l, url.resolve(lines[j].trim()).toString(), h,
            int.tryParse(_attr(l, 'BANDWIDTH')) ?? 0));
        i = j;
      } else if (l.startsWith('#') && !l.startsWith('#EXTM3U')) {
        header.add(_absUri(l, url));
      }
    }
    variants.sort((a, b) => b.bandwidth.compareTo(a.bandwidth));
    return HlsMaster(url, header, audios, variants);
  }

  /// Builds a playlist with only the chosen audio language (forced default)
  /// and either every quality (auto) or a single chosen quality.
  String build({String? lang, int? variant}) {
    final b = StringBuffer('#EXTM3U\n');
    for (final h in header) {
      b.writeln(h);
    }
    if (audios.isNotEmpty) {
      final pick = audios.firstWhere((a) => a.lang == lang, orElse: () => audios.first);
      b.writeln(pick.line
          .replaceAll(RegExp(r'DEFAULT=(YES|NO)'), 'DEFAULT=YES')
          .replaceAll(RegExp(r'AUTOSELECT=(YES|NO)'), 'AUTOSELECT=YES'));
    }
    final vs = variant == null || variant >= variants.length ? variants : [variants[variant]];
    for (final v in vs) {
      b.writeln(v.info);
      b.writeln(v.uri);
    }
    return b.toString();
  }
}

/// Tiny local server that hands the rewritten playlist to the video player.
class LocalHls {
  LocalHls._();
  static final instance = LocalHls._();
  HttpServer? _server;
  final _docs = <String, String>{};
  int _n = 0;

  Future<String> serve(String playlist) async {
    _server ??= await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
      ..listen((req) {
        final body = _docs[req.uri.pathSegments.isEmpty ? '' : req.uri.pathSegments.last];
        req.response.statusCode = body == null ? 404 : 200;
        req.response.headers.set('Content-Type', 'application/vnd.apple.mpegurl');
        req.response.write(body ?? '');
        req.response.close();
      });
    final id = 'p${_n++}.m3u8';
    _docs[id] = playlist;
    if (_docs.length > 20) _docs.remove(_docs.keys.first);
    return 'http://127.0.0.1:${_server!.port}/$id';
  }
}

extension HindiMaster on HindiApi {
  Future<HlsMaster?> master(HindiStream s) async {
    try {
      final u = Uri.parse(s.url);
      final r = await http.get(u, headers: {if (s.referer != null) 'Referer': s.referer!})
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200 || !r.body.contains('#EXTM3U')) return null;
      final m = HlsMaster.parse(r.body, u);
      return m.variants.isEmpty ? null : m;
    } catch (_) {
      return null;
    }
  }

  Future<String> audioLang() async => (await SharedPreferences.getInstance()).getString('hindiAudio') ?? 'hi';
  Future<void> setAudioLang(String l) async => (await SharedPreferences.getInstance()).setString('hindiAudio', l);
}
