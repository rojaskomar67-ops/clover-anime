import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../data/clover_api.dart';
import '../data/jikan_api.dart';
import '../data/library.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'player_screen.dart';

class DetailScreen extends StatefulWidget {
  final AnimeRef anime;
  const DetailScreen({super.key, required this.anime});
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  AnimeDetails? _d;
  List<Episode> _eps = [];
  Map<String, dynamic>? _mal;
  Future<List<AnimeRef>>? _recs;
  String? _error;
  bool _loading = true;
  bool _expanded = true;
  int _range = 0;
  bool _desc = false;

  AnimeRef get _ref => _d?.toRef() ?? widget.anime;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final a = widget.anime;
    if (a.malId != null) {
      JikanApi.instance.full(a.malId!).then((m) {
        if (mounted) setState(() => _mal = m);
      });
      _recs = JikanApi.instance.recommendations(a.malId!);
    }
    try {
      var id = a.cloverId;
      if (id == null) {
        final match = await CloverApi.instance.resolve(a.title, altTitle: a.altTitle);
        id = match?.cloverId;
      }
      if (id == null) {
        setState(() {
          _error = 'This anime is not available to stream yet.';
          _loading = false;
        });
        return;
      }
      final results = await Future.wait([
        CloverApi.instance.details(id),
        CloverApi.instance.episodes(id),
      ]);
      if (!mounted) return;
      setState(() {
        _d = results[0] as AnimeDetails;
        _eps = results[1] as List<Episode>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load episodes. Check your internet.';
          _loading = false;
        });
      }
    }
  }

  void _play(int index) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(fadeRoute(PlayerScreen(anime: _ref, episodes: _eps, index: index)));
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.anime;
    final banner = _d?.banner ?? _d?.poster ?? a.poster;
    final desc = _d?.description ?? _mal?['synopsis']?.toString();
    final genres = (_d?.genres.isNotEmpty == true)
        ? _d!.genres
        : ((_mal?['genres'] as List?)?.map((g) => g['name'].toString()).toList() ?? <String>[]);
    final ranges = (_eps.length / 100).ceil();
    final start = _range * 100;
    final shown = _eps.isEmpty ? <Episode>[] : _eps.sublist(start, (start + 100).clamp(0, _eps.length));
    final cont = _d == null ? null : Library.instance.progressFor(_d!.id);
    final contIndex = cont == null ? -1 : _eps.indexWhere((e) => e.id == cont.episodeId);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 420,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.bg,
            leading: Padding(
              padding: const EdgeInsets.all(6),
              child: CircleAvatar(
                backgroundColor: Colors.black45,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              ListenableBuilder(
                listenable: Library.instance,
                builder: (_, __) {
                  final inList = Library.instance.inWatchlist(_ref) || Library.instance.inWatchlist(a);
                  return Padding(
                    padding: const EdgeInsets.all(6),
                    child: CircleAvatar(
                      backgroundColor: Colors.black45,
                      child: IconButton(
                        icon: Icon(inList ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                            color: inList ? AppColors.primary : Colors.white),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          if (inList && !Library.instance.inWatchlist(_ref)) {
                            Library.instance.toggleWatchlist(a);
                          } else {
                            Library.instance.toggleWatchlist(_ref);
                          }
                          toast(context, inList ? 'Removed from My List' : 'Added to My List');
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(fit: StackFit.expand, children: [
                NetImage(banner),
                const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 110,
                        height: 158,
                        child: Hero(tag: 'poster-${a.key}', child: NetImage(a.poster ?? _d?.poster)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_d?.title ?? a.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.1)),
                        if ((_d?.japaneseTitle ?? a.altTitle) != null)
                          Text(_d?.japaneseTitle ?? a.altTitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          if ((_d?.score ?? a.score) != null)
                            Badge2(_d?.score ?? a.score!, color: AppColors.accent, icon: Icons.star_rounded),
                          if ((_d?.type ?? a.type) != null) Badge2(_d?.type ?? a.type!, color: Colors.white),
                          if (_d?.quality != null) Badge2(_d!.quality!, color: Colors.white),
                          if ((_d?.sub ?? 0) > 0) Badge2('CC ${_d!.sub}'),
                          if ((_d?.dub ?? 0) > 0) Badge2('DUB ${_d!.dub}', color: const Color(0xFF7FB8FF)),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_eps.isNotEmpty)
                  FadeIn(
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _play(contIndex >= 0 ? contIndex : 0),
                        icon: const Icon(Icons.play_arrow_rounded, size: 26),
                        label: Text(contIndex >= 0
                            ? 'Continue EP ${_eps[contIndex].number}'
                            : 'Play EP ${_eps.first.number}'),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                _infoRow(),
                if (genres.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: genres
                        .map((g) => Chip(
                              label: Text(g, style: const TextStyle(fontSize: 12)),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ],
                if (desc != null && desc.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setState(() => _desc = !_desc),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: Text(
                        desc,
                        maxLines: _desc ? null : 4,
                        overflow: _desc ? null : TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textDim, height: 1.45),
                      ),
                    ),
                  ),
                  Text(_desc ? 'Show less' : 'Read more',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ],
                if ((_d?.seasons.length ?? 0) > 1) ...[
                  const SizedBox(height: 18),
                  const Text('Seasons', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _d!.seasons.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final s = _d!.seasons[i];
                        return ChoiceChip(
                          label: Text(s.title),
                          selected: s.isCurrent || s.id == _d!.id,
                          selectedColor: AppColors.primary,
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            color: (s.isCurrent || s.id == _d!.id) ? Colors.black : AppColors.text,
                          ),
                          onSelected: (_) {
                            if (s.id == _d!.id) return;
                            Navigator.of(context).pushReplacement(fadeRoute(DetailScreen(
                              anime: AnimeRef(cloverId: s.id, title: s.title, poster: s.poster),
                            )));
                          },
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(children: [
                  Text('Episodes${_eps.isNotEmpty ? ' (${_eps.length})' : ''}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (_eps.isNotEmpty)
                    IconButton(
                      icon: Icon(_expanded ? Icons.grid_view_rounded : Icons.view_list_rounded),
                      onPressed: () => setState(() => _expanded = !_expanded),
                    ),
                ]),
                if (ranges > 1)
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: ranges,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ChoiceChip(
                        label: Text('${i * 100 + 1}-${((i + 1) * 100).clamp(0, _eps.length)}'),
                        selected: _range == i,
                        selectedColor: AppColors.primary,
                        showCheckmark: false,
                        labelStyle: TextStyle(color: _range == i ? Colors.black : AppColors.text),
                        onSelected: (_) => setState(() => _range = i),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
              ]),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            )
          else if (_error != null)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.error_outline_rounded,
                title: _error!,
                action: FilledButton(onPressed: _load, child: const Text('Retry')),
              ),
            )
          else if (_expanded)
            SliverList.builder(
              itemCount: shown.length,
              itemBuilder: (_, i) => _episodeTile(shown[i], start + i),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 70,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _episodeBox(shown[i], start + i),
                  childCount: shown.length,
                ),
              ),
            ),
          if (_recs != null) ...[
            const SliverToBoxAdapter(child: SectionHeader('You may also like', icon: Icons.auto_awesome_rounded)),
            SliverToBoxAdapter(child: PosterRow(future: _recs!)),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }

  Widget _infoRow() {
    final items = <(IconData, String)>[
      if (_d?.status != null) (Icons.circle, _d!.status!),
      if (_d?.aired != null) (Icons.event_rounded, _d!.aired!),
      if (_d?.duration != null) (Icons.schedule_rounded, _d!.duration!),
      if (_d?.studios.isNotEmpty == true) (Icons.business_rounded, _d!.studios.first),
      if (_mal?['rank'] != null) (Icons.emoji_events_rounded, 'Rank #${_mal!['rank']}'),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: items
          .map((e) => Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(e.$1, size: e.$1 == Icons.circle ? 8 : 15, color: AppColors.primary),
                const SizedBox(width: 5),
                Text(e.$2, style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
              ]))
          .toList(),
    );
  }

  Widget _episodeBox(Episode e, int index) {
    final watched = Library.instance.watched.contains(e.id);
    return Pressable(
      onTap: () => _play(index),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: watched ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: e.filler
                ? AppColors.accent.withValues(alpha: 0.6)
                : (watched ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border),
          ),
        ),
        child: Text(e.number,
            style: TextStyle(
                fontWeight: FontWeight.w800, color: watched ? AppColors.primary : AppColors.text)),
      ),
    );
  }

  Widget _episodeTile(Episode e, int index) {
    final watched = Library.instance.watched.contains(e.id);
    return ListTile(
      onTap: () => _play(index),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 120,
          height: 68,
          child: Stack(fit: StackFit.expand, children: [
            NetImage(_d?.banner ?? _d?.poster ?? widget.anime.poster),
            Container(color: Colors.black45),
            Icon(watched ? Icons.check_circle_rounded : Icons.play_arrow_rounded,
                color: watched ? AppColors.primary : Colors.white),
          ]),
        ),
      ),
      title: Text('E${e.number}${e.title.isNotEmpty && !e.title.startsWith('Episode') ? ' · ${e.title}' : ''}',
          maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Builder(builder: (_) {
        final h = Library.instance.history.where((x) => x.episodeId == e.id).firstOrNull;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 3),
          Text(
            e.filler ? 'Filler' : (watched ? 'Watched' : (h != null ? 'Continue · ${(h.positionMs ~/ 60000)} min in' : 'Episode ${e.number}')),
            style: TextStyle(color: e.filler ? AppColors.accent : (h != null ? AppColors.primary : AppColors.textDim), fontSize: 12),
          ),
          if (h != null && !watched) ...[
            const SizedBox(height: 5),
            LinearProgressIndicator(value: h.progress, minHeight: 3, color: AppColors.primary,
                backgroundColor: Colors.white12, borderRadius: BorderRadius.circular(3)),
          ],
        ]);
      }),
    );
  }
}
