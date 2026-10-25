import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/vault.dart';

/// One skippable part of an episode.
class SkipSegment {
  final String type; // recap, intro, outro, preview
  final double start;
  final double end;
  final bool learned;
  const SkipSegment(this.type, this.start, this.end, {this.learned = false});

  String get label => switch (type) {
        'recap' => 'Skip Recap',
        'outro' => 'Skip Credits',
        'preview' => 'Skip Preview',
        _ => 'Skip Intro',
      };

  bool contains(double s) => s >= start && s < end - 1;
  Map<String, dynamic> toJson() => {'t': type, 's': start, 'e': end};
  static SkipSegment fromJson(Map j) =>
      SkipSegment('${j['t']}', (j['s'] as num).toDouble(), (j['e'] as num).toDouble());
}

/// Detects recap / intro / credits / preview times from a community skip-time
/// database (matched by show, season, episode and the real video length), and
/// learns each show's intro position so episodes without data still work.
class SkipTimes {
  SkipTimes._();
  static final instance = SkipTimes._();
  final _malCache = <String, int?>{};
  final _segCache = <String, List<SkipSegment>>{};

  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  Future<int?> malId(String title, {int season = 1}) async {
    final key = '$title#$season';
    if (_malCache.containsKey(key)) return _malCache[key];
    final p = await SharedPreferences.getInstance();
    final saved = p.getInt('mal:$key');
    if (saved != null) return _malCache[key] = saved;
    int? id;
    try {
      final q = season > 1 ? '$title season $season' : title;
      final r = await http
          .get(Uri.parse('${Vault.jikan}anime').replace(queryParameters: {'q': q, 'limit': '8'}))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final list = (jsonDecode(r.body)['data'] as List? ?? []).cast<Map>();
        final t = _norm(title);
        Map? best;
        for (final a in list) {
          final names = [a['title'], a['title_english'], ...((a['titles'] as List? ?? []).map((x) => x['title']))]
              .whereType<String>()
              .map(_norm);
          final type = '${a['type']}';
          if (season <= 1 && names.contains(t) && type == 'TV') {
            best = a;
            break;
          }
        }
        best ??= list.firstWhere((a) => '${a['type']}' == 'TV', orElse: () => list.isEmpty ? {} : list.first);
        id = (best['mal_id'] as num?)?.toInt();
      }
    } catch (_) {}
    if (id != null) await p.setInt('mal:$key', id);
    return _malCache[key] = id;
  }

  /// [showKey] groups episodes of the same show+season for learning.
  Future<List<SkipSegment>> find({
    required String showKey,
    required String title,
    required int episode,
    required double length,
    int season = 1,
    int? mal,
  }) async {
    final ck = '$showKey#$episode';
    if (_segCache[ck] != null) return _segCache[ck]!;
    final p = await SharedPreferences.getInstance();
    var segs = <SkipSegment>[];
    try {
      final id = mal ?? await malId(title, season: season);
      if (id != null) {
        final uri = Uri.parse('${Vault.skipApi}$id/$episode').replace(queryParameters: {
          'types': ['op', 'ed', 'recap', 'mixed-op', 'mixed-ed'],
          'episodeLength': length.toStringAsFixed(0),
        });
        final r = await http.get(uri).timeout(const Duration(seconds: 15));
        if (r.statusCode == 200) {
          final d = jsonDecode(r.body);
          for (final x in (d['results'] as List? ?? [])) {
            final s = (x['interval']['startTime'] as num).toDouble();
            final e = (x['interval']['endTime'] as num).toDouble();
            final srcLen = (x['episodeLength'] as num?)?.toDouble() ?? 0;
            // Rescale when the uploaded file is a different length (e.g. extra
            // logo at the start); keep offsets from the matching end.
            var off = 0.0;
            if (srcLen > 0 && length > 0 && (length - srcLen).abs() > 3 && (length - srcLen).abs() < 120) {
              off = length - srcLen;
            }
            final type = switch ('${x['skipType']}') {
              'op' || 'mixed-op' => 'intro',
              'ed' || 'mixed-ed' => 'outro',
              _ => 'recap',
            };
            final adj = off;
            if (e > s) segs.add(SkipSegment(type, (s + adj).clamp(0, length), (e + adj).clamp(0, length)));
          }
        }
      }
    } catch (_) {}

    // Preview after credits: if credits end well before the video ends.
    final outro = segs.where((s) => s.type == 'outro').firstOrNull;
    if (outro != null && length - outro.end > 15 && length - outro.end < 90) {
      segs.add(SkipSegment('preview', outro.end, length));
    }

    final learnKey = 'skipLearn:$showKey';
    if (segs.any((s) => s.type == 'intro')) {
      final i = segs.firstWhere((s) => s.type == 'intro');
      await p.setString(learnKey, jsonEncode(i.toJson()));
    } else {
      final raw = p.getString(learnKey);
      if (raw != null) {
        final l = SkipSegment.fromJson(jsonDecode(raw));
        if (l.end < length * 0.3) segs.add(SkipSegment('intro', l.start, l.end, learned: true));
      }
    }
    segs.sort((a, b) => a.start.compareTo(b.start));
    return _segCache[ck] = segs;
  }

  /// When the user skips manually, remember where the intro is for this show.
  Future<void> learn(String showKey, double start, double end) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('skipLearn:$showKey', jsonEncode(SkipSegment('intro', start, end).toJson()));
  }
}
