import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../data/auth_service.dart';
import '../data/jikan_api.dart';
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
  final j = JikanApi.instance;
  late Future<List<AnimeRef>> _season, _airing, _popular, _movies, _upcoming, _favs;
  String? _dismissedAnn;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _season = j.seasonNow();
    _airing = j.topAiring();
    _popular = j.mostPopular();
    _movies = j.topMovies();
    _upcoming = j.upcoming();
    _favs = j.favorites();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        setState(_load);
        await _season;
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: _Hero(future: _season)),
          SliverToBoxAdapter(
            child: ListenableBuilder(
              listenable: AuthService.instance,
              builder: (_, __) {
                final a = AuthService.instance.announcement;
                if (a == null || !a.active || _dismissedAnn == '${a.updatedAt}') {
                  return const SizedBox.shrink();
                }
                return _AnnouncementCard(a: a, onClose: () => setState(() => _dismissedAnn = '${a.updatedAt}'));
              },
            ),
          ),
          SliverToBoxAdapter(
            child: ListenableBuilder(
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
            ),
          ),
          ..._section('Top Airing', Icons.local_fire_department_rounded, _airing, 'Top Airing', j.topAiring,
              ranked: true),
          ..._section('This Season', Icons.calendar_month_rounded, _season, 'This Season', j.seasonNow),
          ..._section('Most Popular', Icons.trending_up_rounded, _popular, 'Most Popular', j.mostPopular),
          ..._section('Top Movies', Icons.movie_filter_rounded, _movies, 'Top Movies', j.topMovies),
          ..._section('Coming Soon', Icons.upcoming_rounded, _upcoming, 'Coming Soon', j.upcoming),
          ..._section('All-Time Favorites', Icons.favorite_rounded, _favs, 'All-Time Favorites', j.favorites),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  List<Widget> _section(String title, IconData icon, Future<List<AnimeRef>> f, String listTitle,
          Future<List<AnimeRef>> Function() loader,
          {bool ranked = false}) =>
      [
        SliverToBoxAdapter(
          child: SectionHeader(title,
              icon: icon,
              onMore: () => Navigator.of(context)
                  .push(fadeRoute(ListScreen(title: listTitle, loader: (_) => loader(), paged: false)))),
        ),
        SliverToBoxAdapter(child: PosterRow(future: f, ranked: ranked)),
      ];
}

class _Hero extends StatefulWidget {
  final Future<List<AnimeRef>> future;
  const _Hero({required this.future});
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
      if (_pc.hasClients) {
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
    final h = MediaQuery.of(context).size.height * 0.58;
    return SizedBox(
      height: h,
      child: FutureBuilder<List<AnimeRef>>(
        future: widget.future,
        builder: (context, snap) {
          final list = (snap.data ?? []).take(8).toList();
          if (list.isEmpty) return ShimmerBox(height: h);
          return Stack(children: [
            PageView.builder(
              controller: _pc,
              onPageChanged: (i) => setState(() => _page = i % list.length),
              itemBuilder: (_, i) {
                final a = list[i % list.length];
                return AnimatedBuilder(
                  animation: _pc,
                  builder: (_, child) {
                    double offset = 0;
                    if (_pc.position.haveDimensions) offset = (_pc.page ?? 0) - i;
                    return Stack(fit: StackFit.expand, children: [
                      Transform.translate(
                        offset: Offset(offset * -120, 0),
                        child: Transform.scale(scale: 1.15, child: NetImage(a.poster)),
                      ),
                      child!,
                    ]);
                  },
                  child: Stack(fit: StackFit.expand, children: [
                    const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 46,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('#${(i % list.length) + 1} Spotlight',
                              style: const TextStyle(
                                  color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                        const SizedBox(height: 10),
                        Text(a.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -0.5)),
                        const SizedBox(height: 8),
                        Row(children: [
                          if (a.score != null) ...[
                            const Icon(Icons.star_rounded, color: AppColors.accent, size: 18),
                            Text(' ${a.score}  ', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                          Text([a.type, if (a.episodes != null) '${a.episodes} eps'].whereType<String>().join(' • '),
                              style: const TextStyle(color: AppColors.textDim)),
                        ]),
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
                const Text('CLOVER',
                    style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 16)),
              ]),
            ),
          ]);
        },
      ),
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
