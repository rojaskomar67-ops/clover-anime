import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class ContinueItem {
  final AnimeRef anime;
  final String episodeId;
  final String episodeNumber;
  final int positionMs;
  final int durationMs;
  final int updatedAt;
  ContinueItem({
    required this.anime,
    required this.episodeId,
    required this.episodeNumber,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
  });
  double get progress => durationMs <= 0 ? 0 : (positionMs / durationMs).clamp(0, 1);

  Map<String, dynamic> toJson() => {
        'anime': anime.toJson(),
        'episodeId': episodeId,
        'episodeNumber': episodeNumber,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'updatedAt': updatedAt,
      };
  factory ContinueItem.fromJson(Map<String, dynamic> j) => ContinueItem(
        anime: AnimeRef.fromJson(j['anime'] as Map<String, dynamic>),
        episodeId: j['episodeId'].toString(),
        episodeNumber: j['episodeNumber'].toString(),
        positionMs: (j['positionMs'] as num).toInt(),
        durationMs: (j['durationMs'] as num).toInt(),
        updatedAt: (j['updatedAt'] as num).toInt(),
      );
}

/// Local watchlist, history, playback progress and player preferences.
class Library extends ChangeNotifier {
  Library._();
  static final Library instance = Library._();

  late SharedPreferences _p;
  final List<AnimeRef> watchlist = [];
  final List<ContinueItem> history = [];
  final Set<String> watched = {};
  final List<String> recentSearches = [];

  double playbackSpeed = 1.0;
  bool autoPlayNext = true;
  bool autoSkipIntro = false;
  bool subtitlesOn = true;
  String preferredType = 'sub';

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    void load(String k, void Function(dynamic) f) {
      final s = _p.getString(k);
      if (s == null) return;
      try {
        f(jsonDecode(s));
      } catch (_) {}
    }

    load('watchlist', (d) => watchlist.addAll(
        (d as List).map((e) => AnimeRef.fromJson(e as Map<String, dynamic>))));
    load('history', (d) => history.addAll(
        (d as List).map((e) => ContinueItem.fromJson(e as Map<String, dynamic>))));
    watched.addAll(_p.getStringList('watched') ?? []);
    recentSearches.addAll(_p.getStringList('recentSearches') ?? []);
    playbackSpeed = _p.getDouble('speed') ?? 1.0;
    autoPlayNext = _p.getBool('autoNext') ?? true;
    autoSkipIntro = _p.getBool('autoSkip') ?? false;
    subtitlesOn = _p.getBool('subs') ?? true;
    preferredType = _p.getString('prefType') ?? 'sub';
  }

  bool inWatchlist(AnimeRef a) =>
      watchlist.any((w) => w.key == a.key || (a.cloverId != null && w.cloverId == a.cloverId));

  void toggleWatchlist(AnimeRef a) {
    if (inWatchlist(a)) {
      watchlist.removeWhere((w) => w.key == a.key || (a.cloverId != null && w.cloverId == a.cloverId));
    } else {
      watchlist.insert(0, a);
    }
    _p.setString('watchlist', jsonEncode(watchlist.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  ContinueItem? progressFor(String cloverId) {
    for (final h in history) {
      if (h.anime.cloverId == cloverId) return h;
    }
    return null;
  }

  int savedPosition(String episodeId) {
    for (final h in history) {
      if (h.episodeId == episodeId) return h.positionMs;
    }
    return 0;
  }

  void saveProgress(AnimeRef a, String episodeId, String number, int pos, int dur) {
    history.removeWhere((h) => h.anime.cloverId == a.cloverId);
    history.insert(
      0,
      ContinueItem(
        anime: a,
        episodeId: episodeId,
        episodeNumber: number,
        positionMs: pos,
        durationMs: dur,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (history.length > 40) history.removeLast();
    if (dur > 0 && pos / dur > 0.85) watched.add(episodeId);
    _p.setString('history', jsonEncode(history.map((e) => e.toJson()).toList()));
    _p.setStringList('watched', watched.toList());
    notifyListeners();
  }

  void removeHistory(ContinueItem item) {
    history.remove(item);
    _p.setString('history', jsonEncode(history.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  void clearHistory() {
    history.clear();
    _p.remove('history');
    notifyListeners();
  }

  void addSearch(String q) {
    recentSearches.remove(q);
    recentSearches.insert(0, q);
    if (recentSearches.length > 10) recentSearches.removeLast();
    _p.setStringList('recentSearches', recentSearches);
  }

  void clearSearches() {
    recentSearches.clear();
    _p.remove('recentSearches');
    notifyListeners();
  }

  void setSpeed(double v) {
    playbackSpeed = v;
    _p.setDouble('speed', v);
  }

  void setAutoNext(bool v) {
    autoPlayNext = v;
    _p.setBool('autoNext', v);
    notifyListeners();
  }

  void setAutoSkip(bool v) {
    autoSkipIntro = v;
    _p.setBool('autoSkip', v);
    notifyListeners();
  }

  void setSubs(bool v) {
    subtitlesOn = v;
    _p.setBool('subs', v);
    notifyListeners();
  }

  void setPrefType(String v) {
    preferredType = v;
    _p.setString('prefType', v);
    notifyListeners();
  }
}
