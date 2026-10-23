int _i(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

String? _s(dynamic v) => v == null ? null : v.toString();

List<String> _strList(dynamic v) {
  if (v is List) {
    return v
        .map((e) => e is Map ? (e['name'] ?? '').toString() : e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

/// A lightweight reference to an anime, from either the Clover API or Jikan.
class AnimeRef {
  final String? cloverId;
  final int? malId;
  final String title;
  final String? altTitle;
  final String? poster;
  final String? score;
  final String? type;
  final int sub;
  final int dub;
  final int? episodes;

  const AnimeRef({
    this.cloverId,
    this.malId,
    required this.title,
    this.altTitle,
    this.poster,
    this.score,
    this.type,
    this.sub = 0,
    this.dub = 0,
    this.episodes,
  });

  String get key => cloverId != null ? 'c:$cloverId' : 'm:$malId:$title';

  factory AnimeRef.fromClover(Map<String, dynamic> j) {
    final subEp = _i(j['sub_episodes']);
    final dubEp = _i(j['dub_episodes']);
    return AnimeRef(
      cloverId: _s(j['id']),
      title: _s(j['title']) ?? 'Unknown',
      altTitle: _s(j['japanese_title']),
      poster: _s(j['poster']),
      score: _s(j['score']),
      type: _s(j['type']),
      sub: subEp > 0 ? subEp : _i(j['sub']),
      dub: dubEp > 0 ? dubEp : _i(j['dub']),
      episodes: j['total_episodes'] == null ? null : _i(j['total_episodes']),
    );
  }

  factory AnimeRef.fromJikan(Map<String, dynamic> j) {
    final images = j['images'] as Map<String, dynamic>?;
    final jpg = images?['webp'] ?? images?['jpg'];
    final en = _s(j['title_english']);
    return AnimeRef(
      malId: _i(j['mal_id']),
      title: (en != null && en.isNotEmpty) ? en : (_s(j['title']) ?? 'Unknown'),
      altTitle: _s(j['title']),
      poster: jpg is Map ? _s(jpg['large_image_url'] ?? jpg['image_url']) : null,
      score: j['score'] == null ? null : j['score'].toString(),
      type: _s(j['type']),
      episodes: j['episodes'] == null ? null : _i(j['episodes']),
    );
  }

  Map<String, dynamic> toJson() => {
        'cloverId': cloverId,
        'malId': malId,
        'title': title,
        'altTitle': altTitle,
        'poster': poster,
        'score': score,
        'type': type,
        'sub': sub,
        'dub': dub,
        'episodes': episodes,
      };

  factory AnimeRef.fromJson(Map<String, dynamic> j) => AnimeRef(
        cloverId: _s(j['cloverId']),
        malId: j['malId'] == null ? null : _i(j['malId']),
        title: _s(j['title']) ?? '',
        altTitle: _s(j['altTitle']),
        poster: _s(j['poster']),
        score: _s(j['score']),
        type: _s(j['type']),
        sub: _i(j['sub']),
        dub: _i(j['dub']),
        episodes: j['episodes'] == null ? null : _i(j['episodes']),
      );
}

class AnimeDetails {
  final String id;
  final String title;
  final String? japaneseTitle;
  final String? poster;
  final String? banner;
  final String? description;
  final List<String> genres;
  final List<String> studios;
  final String? aired;
  final String? duration;
  final String? status;
  final String? score;
  final String? type;
  final String? quality;
  final int sub;
  final int dub;
  final String? watchUrl;
  final List<SeasonItem> seasons;

  AnimeDetails({
    required this.id,
    required this.title,
    this.japaneseTitle,
    this.poster,
    this.banner,
    this.description,
    this.genres = const [],
    this.studios = const [],
    this.aired,
    this.duration,
    this.status,
    this.score,
    this.type,
    this.quality,
    this.sub = 0,
    this.dub = 0,
    this.watchUrl,
    this.seasons = const [],
  });

  factory AnimeDetails.fromJson(Map<String, dynamic> j) {
    final subEp = _i(j['sub_episodes']);
    final dubEp = _i(j['dub_episodes']);
    return AnimeDetails(
      id: _s(j['id']) ?? '',
      title: _s(j['title']) ?? 'Unknown',
      japaneseTitle: _s(j['japanese_title']),
      poster: _s(j['poster']),
      banner: _s(j['banner']),
      description: _s(j['description']),
      genres: _strList(j['genres']),
      studios: _strList(j['studios']),
      aired: _s(j['aired']),
      duration: _s(j['duration']),
      status: _s(j['status']),
      score: _s(j['mal_score'] ?? j['site_rating']),
      type: _s(j['type']),
      quality: _s(j['quality']),
      sub: subEp > 0 ? subEp : _i(j['sub']),
      dub: dubEp > 0 ? dubEp : _i(j['dub']),
      watchUrl: _s(j['watch_url']),
      seasons: (j['seasons'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(SeasonItem.fromJson)
          .toList(),
    );
  }

  AnimeRef toRef() => AnimeRef(
        cloverId: id,
        title: title,
        altTitle: japaneseTitle,
        poster: poster,
        score: score,
        type: type,
        sub: sub,
        dub: dub,
      );
}

class SeasonItem {
  final String id;
  final String title;
  final String? poster;
  final bool isCurrent;
  SeasonItem({required this.id, required this.title, this.poster, this.isCurrent = false});
  factory SeasonItem.fromJson(Map<String, dynamic> j) => SeasonItem(
        id: _s(j['id']) ?? '',
        title: _s(j['title']) ?? '',
        poster: _s(j['poster']),
        isCurrent: j['is_current'] == true,
      );
}

class Episode {
  final String id;
  final String number;
  final String title;
  final bool filler;
  Episode({required this.id, required this.number, required this.title, this.filler = false});
  factory Episode.fromJson(Map<String, dynamic> j) {
    final epId = _s(j['episode_id']);
    return Episode(
      id: (epId != null && epId.isNotEmpty) ? epId : (_s(j['id']) ?? ''),
      number: _s(j['number']) ?? '',
      title: _s(j['title']) ?? '',
      filler: j['filler'] == true || j['is_filler'] == true,
    );
  }
}

class ServerItem {
  final String name;
  final String type;
  ServerItem({required this.name, required this.type});
  factory ServerItem.fromJson(Map<String, dynamic> j) => ServerItem(
        name: _s(j['name'] ?? j['server_name'] ?? j['host']) ?? 'Server',
        type: _s(j['type']) ?? 'sub',
      );
}

class Subtitle {
  final String label;
  final String url;
  final bool isDefault;
  Subtitle({required this.label, required this.url, this.isDefault = false});
  factory Subtitle.fromJson(Map<String, dynamic> j) => Subtitle(
        label: _s(j['label'] ?? j['language']) ?? 'Subtitle',
        url: _s(j['proxy_url'] ?? j['url'] ?? j['file']) ?? '',
        isDefault: j['default'] == true || j['is_default'] == true,
      );
}

class TimeRange {
  final int start;
  final int end;
  TimeRange(this.start, this.end);
  bool get valid => end > start;
  static TimeRange? fromJson(dynamic j) {
    if (j is! Map) return null;
    final r = TimeRange(_i(j['start']), _i(j['end']));
    return r.valid ? r : null;
  }
}

class StreamInfo {
  final String url;
  final String referer;
  final List<Subtitle> subtitles;
  final TimeRange? intro;
  final TimeRange? outro;
  final String? server;
  StreamInfo({
    required this.url,
    required this.referer,
    this.subtitles = const [],
    this.intro,
    this.outro,
    this.server,
  });

  factory StreamInfo.fromJson(Map<String, dynamic> j) {
    final stream = j['stream'] as Map<String, dynamic>?;
    String? pick(List<dynamic> c) {
      for (final v in c) {
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    }

    final url = pick([
          j['proxy_url'],
          stream?['proxy_url'],
          j['m3u8'],
          j['stream_url'],
          stream?['stream_url'],
        ]) ??
        '';
    final host = _s(j['host']);
    final subsRaw = (j['subtitles'] as List?) ?? (stream?['tracks'] as List?) ?? [];
    return StreamInfo(
      url: url,
      referer: _s(j['referer']) ?? (host != null ? 'https://$host/' : 'https://megacloud.tv/'),
      subtitles: subsRaw
          .whereType<Map<String, dynamic>>()
          .map(Subtitle.fromJson)
          .where((s) => s.url.isNotEmpty && !s.label.toLowerCase().contains('thumbnail'))
          .toList(),
      intro: TimeRange.fromJson(j['intro']),
      outro: TimeRange.fromJson(j['outro']),
      server: _s(j['server']),
    );
  }
}

class Genre {
  final int id;
  final String name;
  final int count;
  Genre(this.id, this.name, this.count);
}

class Announcement {
  final String title;
  final String message;
  final bool active;
  final String type;
  final String? actionUrl;
  final String? actionText;
  final int updatedAt;
  Announcement({
    required this.title,
    required this.message,
    required this.active,
    this.type = 'info',
    this.actionUrl,
    this.actionText,
    this.updatedAt = 0,
  });
  factory Announcement.fromMap(Map<String, dynamic> m) => Announcement(
        title: _s(m['title']) ?? '',
        message: _s(m['message']) ?? '',
        active: m['enabled'] == true || m['isEnabled'] == true,
        type: _s(m['type']) ?? 'info',
        actionUrl: _s(m['actionUrl']),
        actionText: _s(m['actionText']),
        updatedAt: _i(m['updatedAt']),
      );
}

class UpdateConfig {
  final int latestVersionCode;
  final String latestVersionName;
  final String title;
  final String changelog;
  final String downloadUrl;
  final bool forceUpdate;
  UpdateConfig({
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.title,
    required this.changelog,
    required this.downloadUrl,
    required this.forceUpdate,
  });
  factory UpdateConfig.fromMap(Map<String, dynamic> m) => UpdateConfig(
        latestVersionCode: _i(m['latestVersionCode']),
        latestVersionName: _s(m['latestVersionName']) ?? '',
        title: _s(m['title']) ?? 'New update available',
        changelog: _s(m['changelog']) ?? '',
        downloadUrl: _s(m['downloadUrl']) ?? '',
        forceUpdate: m['forceUpdate'] == true,
      );
}

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String role;
  final int lastLoginAt;
  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.role = 'user',
    this.lastLoginAt = 0,
  });
  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        uid: _s(m['uid']) ?? '',
        email: _s(m['email']) ?? '',
        displayName: _s(m['displayName']) ?? '',
        role: _s(m['role']) ?? 'user',
        lastLoginAt: _i(m['lastLoginAt']),
      );
}

class Broadcast {
  final String id;
  final String title;
  final String message;
  final String type;
  final int createdAt;
  final String createdBy;
  Broadcast({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.createdBy,
  });
  factory Broadcast.fromMap(String id, Map<String, dynamic> m) => Broadcast(
        id: id,
        title: _s(m['title']) ?? '',
        message: _s(m['message']) ?? '',
        type: _s(m['type']) ?? 'info',
        createdAt: _i(m['createdAt']),
        createdBy: _s(m['createdBy']) ?? '',
      );
}
