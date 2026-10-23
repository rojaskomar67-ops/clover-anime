import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../data/auth_service.dart';
import '../data/hianime_source.dart';
import '../data/library.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final src = HiAnimeSource.instance;
  late Future<HomeData> _home;
  String? _dismissedAnn;
  int _topTab = 0;

  // Extra category rows auto-fetched below the home sections.
  static const _extraRows = ['top-airing', 'most-popular', 'most-favorite', 'movie', 'dubbed-anime'];
  late Map<String, Future<List<AnimeRef>>> _rows;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _home = src.home();
    _rows = {
      for (final k in _extraRows) k: src.category(kCategories.firstWhere((c) => c.key == k).path),
    };
  }

  Future<void> _refresh() async {
    src.clearCache();
    setState(_load);
    try {
      await _home;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: FutureBuilder<HomeData>(
        future: _home,
        builder: (context, snap) {
          if (snap.hasError) {
            return ListView(children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
              EmptyState(
                icon: Icons.wifi_off_rounded,
                title: "Couldn't load home",
                subtitle: 'Check your internet and try again.',
                action: FilledButton(onPressed: _refresh, child: const Text('Retry')),
              ),
            ]);
          }
          final data = snap.data;
          return ListenableBuilder(
            listenable: AuthService.instance,
            builder: (context, _) {
              final hidden = AuthService.instance.features.hiddenSections;
              return CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                    child: data == null
                        ? ShimmerBox(height: _heroHeight(context))
                        : _Hero(items: data.spotlight, autoplay: AuthService.instance.features.spotlightAutoplay),
                  ),
                  SliverToBoxAdapter(child: _announcement()),
                  SliverToBoxAdapter(child: _continueWatching()),
                  if (data == null)
                    SliverToBoxAdapter(
                      child: Column(children: [
                        const SectionHeader('Loading...', icon: Icons.hourglass_top_rounded),
                        PosterRow(future: Completer<List<AnimeRef>>().future),
                      ]),
                    )
                  else ...[
                    for (final e in data.sections.entries)
                      if (!hidden.contains(e.key)) ...[
                        SliverToBoxAdapter(
                          child: SectionHeader(e.key,
                              icon: _iconFor(e.key),
                              onMore: _pathFor(e.key) == null
                                  ? null
                                  : () => _openCategory(e.key, _pathFor(e.key)!)),
                        ),
                        SliverToBoxAdapter(child: PosterRow(future: Future.value(e.value))),
                      ],
                    if (!hidden.contains('Top 10') && data.top10Day.isNotEmpty)
                      SliverToBoxAdapter(child: _top10(data)),
                  ],
                  for (final k in _extraRows)
                    if (!hidden.contains(_cat(k).title)) ...[
                      SliverToBoxAdapter(
                        child: SectionHeader(_cat(k).title,
                            icon: _iconFor(_cat(k).title), onMore: () => _openCategory(_cat(k).title, _cat(k).path)),
                      ),
                      SliverToBoxAdapter(child: PosterRow(future: _rows[k]!)),
                    ],
                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Category _cat(String k) => kCategories.firstWhere((c) => c.key == k);

  String? _pathFor(String title) => switch (title) {
        'Latest Episode' => 'recently-updated',
        'Top Upcoming' => 'top-upcoming',
        'Trending' => 'most-popular',
        _ => null,
      };

  IconData _iconFor(String t) {
    final l = t.toLowerCase();
    if (l.contains('trend')) return Icons.local_fire_department_rounded;
    if (l.contains('latest')) return Icons.new_releases_rounded;
    if (l.contains('new')) return Icons.fiber_new_rounded;
    if (l.contains('upcoming')) return Icons.upcoming_rounded;
    if (l.contains('airing')) return Icons.live_tv_rounded;
    if (l.contains('popular')) return Icons.trending_up_rounded;
    if (l.contains('favorite')) return Icons.favorite_rounded;
    if (l.contains('movie')) return Icons.movie_filter_rounded;
    if (l.contains('dub')) return Icons.mic_rounded;
    return Icons.auto_awesome_rounded;
  }

  void _openCategory(String title, String path) => Navigator.of(context)
      .push(fadeRoute(ListScreen(title: title, loader: (p) => src.category(path, page: p))));

  double _heroHeight(BuildContext c) {
    final s = MediaQuery.of(c).size;
    return (s.height * (s.width > 720 ? 0.5 : 0.58)).clamp(320, 560).toDouble();
  }

  Widget _announcement() => ListenableBuilder(
        listenable: AuthService.instance,
        builder: (_, __) {
          final a = AuthService.instance.announcement;
          if (a == null || !a.active || _dismissedAnn == '${a.updatedAt}') return const SizedBox.shrink();
          return _AnnouncementCard(a: a, onClose: () => setState(() => _dismissedAnn = '${a.updatedAt}'));
        },
      );

  Widget _continueWatching() => ListenableBuilder(
        listenable: Library.instance,
        builder: (_, __) {
          final h = Library.instance.history;
          if (h.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader('Continue Watching', icon: Icons.play_circle_outline_rounded),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: h.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _ContinueCard(item: h[i]),
              ),
            ),
          ]);
        },
      );

  Widget _top10(HomeData d) {
    final lists = [d.top10Day, d.top10Week, d.top10Month];
    final list = lists[_topTab].isEmpty ? d.top10Day : lists[_topTab];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
        child: Row(children: [
          const Icon(Icons.emoji_events_rounded, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          const Expanded(child: Text('Top 10', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          SegmentedButton<int>(
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              selectedBackgroundColor: AppColors.primary,
              selectedForegroundColor: Colors.black,
            ),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('Day')),
              ButtonSegment(value: 1, label: Text('Week')),
              ButtonSegment(value: 2, label: Text('Month')),
            ],
            selected: {_topTab},
            onSelectionChanged: (s) => setState(() => _topTab = s.first),
          ),
        ]),
      ),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: SizedBox(
          key: ValueKey(_topTab),
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => FadeIn(
              delay: Duration(milliseconds: 40 * i),
              child: PosterCard(anime: list[i], rank: i + 1),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Hero extends StatefulWidget {
  final List<Spotlight> items;
  final bool autoplay;
  const _Hero({required this.items, required this.autoplay});
  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  final _pc = PageController();
  Timer? _t;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 6), (_) {
      if (widget.autoplay && _pc.hasClients) {
        _pc.nextPage(duration: const Duration(milliseconds: 700), curve: Curves.easeInOutCubic);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final wide = size.width > 720;
    final h = (size.height * (wide ? 0.5 : 0.58)).clamp(320, 560).toDouble();
    final list = widget.items;
    if (list.isEmpty) return SizedBox(height: MediaQuery.of(context).padding.top + 20);
    return SizedBox(
      height: h,
      child: Stack(children: [
        PageView.builder(
          controller: _pc,
          onPageChanged: (i) => setState(() => _page = i % list.length),
          itemBuilder: (_, i) {
            final s = list[i % list.length];
            final a = s.anime;
            return AnimatedBuilder(
              animation: _pc,
              builder: (_, child) {
                double offset = 0;
                if (_pc.position.haveDimensions) offset = (_pc.page ?? 0) - i;
                return Stack(fit: StackFit.expand, children: [
                  Transform.translate(
                    offset: Offset(offset * -120, 0),
                    child: Transform.scale(scale: 1.12, child: NetImage(s.banner ?? a.poster)),
                  ),
                  child!,
                ]);
              },
              child: Stack(fit: StackFit.expand, children: [
                const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
                Positioned(
                  left: 20,
                  right: wide ? size.width * 0.4 : 20,
                  bottom: 46,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('#${(i % list.length) + 1} Spotlight',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                    const SizedBox(height: 10),
                    Text(a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: wide ? 36 : 28, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, children: [
                      if (a.type != null) Badge2(a.type!, color: Colors.white),
                      if (a.sub > 0) Badge2('CC ${a.sub}'),
                      if (a.dub > 0) Badge2('DUB ${a.dub}', color: const Color(0xFF7FB8FF)),
                    ]),
                    if (s.description != null) ...[
                      const SizedBox(height: 8),
                      Text(s.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
                    ],
                    const SizedBox(height: 14),
                    Row(children: [
                      FilledButton.icon(
                        onPressed: () => openAnime(context, a),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Watch now'),
                      ),
                      const SizedBox(width: 10),
                      ListenableBuilder(
                        listenable: Library.instance,
                        builder: (_, __) {
                          final inList = Library.instance.inWatchlist(a);
                          return IconButton.filledTonal(
                            style: IconButton.styleFrom(backgroundColor: Colors.white12),
                            onPressed: () => Library.instance.toggleWatchlist(a),
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (c, an) => ScaleTransition(scale: an, child: c),
                              child: Icon(inList ? Icons.check_rounded : Icons.add_rounded,
                                  key: ValueKey(inList), color: Colors.white),
                            ),
                          );
                        },
                      ),
                    ]),
                  ]),
                ),
              ]),
            );
          },
        ),
        Positioned(
          bottom: 18,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              list.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 22 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.primary : Colors.white30,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          child: Row(children: [
            ShaderMask(
              shaderCallback: (r) => AppColors.primaryGradient.createShader(r),
              child: const Icon(Icons.eco_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 6),
            const Text('CLOVER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 16)),
          ]),
        ),
      ]),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement a;
  final VoidCallback onClose;
  const _AnnouncementCard({required this.a, required this.onClose});
  @override
  Widget build(BuildContext context) {
    final color = switch (a.type) {
      'warning' => AppColors.accent,
      'urgent' => AppColors.danger,
      'maintenance' => const Color(0xFF7FB8FF),
      _ => AppColors.primary,
    };
    return FadeIn(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.campaign_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(a.message, style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
              if (a.actionUrl != null && a.actionUrl!.isNotEmpty)
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: color),
                  onPressed: () => launchUrl(Uri.parse(a.actionUrl!), mode: LaunchMode.externalApplication),
                  child: Text(a.actionText?.isNotEmpty == true ? a.actionText! : 'Open'),
                ),
            ]),
          ),
          InkWell(onTap: onClose, child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textDim)),
        ]),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final ContinueItem item;
  const _ContinueCard({required this.item});
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: () => openAnime(context, item.anime),
        onLongPress: () => Library.instance.removeHistory(item),
        child: SizedBox(
          width: 220,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 112,
                width: 220,
                child: Stack(fit: StackFit.expand, children: [
                  NetImage(item.anime.poster),
                  Container(color: Colors.black38),
                  const Center(child: Icon(Icons.play_circle_fill_rounded, size: 42, color: Colors.white)),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: item.progress,
                      minHeight: 4,
                      backgroundColor: Colors.white24,
                      color: AppColors.primary,
                    ),
                  ),
                  Positioned(top: 8, left: 8, child: Badge2('EP ${item.episodeNumber}')),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Text(item.anime.title,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
