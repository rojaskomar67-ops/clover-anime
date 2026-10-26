import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/theme.dart';
import '../data/hindi_api.dart';
import '../data/library.dart';
import '../data/skip_times.dart';
import '../widgets/player_extras.dart';
import '../widgets/common.dart';

const hindiAccent = Color(0xFFFF9933); // saffron

/// Smooth pill switch between Default and Hindi mode.
class ModeSwitch extends StatelessWidget {
  const ModeSwitch({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: ModeController.instance,
        builder: (context, hindi, _) {
          Widget seg(String label, bool forHindi) {
            final on = hindi == forHindi;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (on) return;
                  HapticFeedback.lightImpact();
                  ModeController.instance.set(forHindi);
                },
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: on ? Colors.black : AppColors.text,
                    ),
                    child: Text(label),
                  ),
                ),
              ),
            );
          }

          return Container(
            width: 150,
            height: 34,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xCC141821),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                alignment: hindi ? Alignment.centerRight : Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  heightFactor: 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    decoration: BoxDecoration(
                      color: hindi ? hindiAccent : AppColors.primary,
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                ),
              ),
              Row(children: [seg('Default', false), seg('हिंदी', true)]),
            ]),
          );
        },
      );
}

void openHindi(BuildContext context, HindiAnime a) =>
    Navigator.of(context).push(fadeRoute(HindiDetailScreen(anime: a)));

class HindiCard extends StatelessWidget {
  final HindiAnime anime;
  final double width;
  const HindiCard({super.key, required this.anime, this.width = 128});
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: () => openHindi(context, anime),
        child: SizedBox(
          width: width,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
              aspectRatio: 0.7,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(fit: StackFit.expand, children: [
                  Hero(tag: 'h-${anime.link}', child: NetImage(anime.poster)),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xAA000000)],
                        stops: [0.55, 1],
                      ),
                    ),
                  ),
                  if (anime.languages?.contains('Hindi') ?? false)
                    const Positioned(top: 6, left: 6, child: Badge2('HINDI', color: hindiAccent)),
                  if (anime.isMovie)
                    const Positioned(top: 6, right: 6, child: Badge2('MOVIE', color: Color(0xFF7FB8FF))),
                  if (anime.rank != null)
                    Positioned(
                      bottom: 2,
                      left: 6,
                      child: Text('${anime.rank}',
                          style: const TextStyle(
                              fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
                    ),
                  if (anime.badge != null)
                    Positioned(bottom: 6, right: 6, child: Badge2(anime.badge!)),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Text(anime.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.2)),
            if (anime.languages != null)
              Text(anime.languages!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textDim)),
          ]),
        ),
      );
}

class _HindiRow extends StatelessWidget {
  final List<HindiAnime> items;
  const _HindiRow(this.items);
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 262,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => FadeIn(
            delay: Duration(milliseconds: 40 * (i % 8)),
            child: HindiCard(anime: items[i]),
          ),
        ),
      );
}

// ---------------- Home ----------------
class HindiHomeScreen extends StatefulWidget {
  const HindiHomeScreen({super.key});
  @override
  State<HindiHomeScreen> createState() => _HindiHomeScreenState();
}

class _HindiHomeScreenState extends State<HindiHomeScreen> {
  late Future<List<HindiSection>> _f = HindiApi.instance.home();
  late Future<List<HindiAnime>> _hist = HindiApi.instance.history();
  late Future<List<HindiAnime>> _saved = HindiApi.instance.saved();

  @override
  void initState() {
    super.initState();
    HindiApi.instance.changes.addListener(_reloadUser);
  }

  void _reloadUser() {
    if (!mounted) return;
    setState(() {
      _hist = HindiApi.instance.history();
      _saved = HindiApi.instance.saved();
    });
  }

  @override
  void dispose() {
    HindiApi.instance.changes.removeListener(_reloadUser);
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _f = HindiApi.instance.home(force: true);
      _hist = HindiApi.instance.history();
      _saved = HindiApi.instance.saved();
    });
    await _f;
  }

  static const _icons = {
    'Recent Regional Dub Episodes': Icons.record_voice_over_rounded,
    'On-Air Series': Icons.live_tv_rounded,
    'Top 10 Series of All Time': Icons.emoji_events_rounded,
    'Top 10 Movies of All Time': Icons.workspace_premium_rounded,
    'Most-Watched Series': Icons.local_fire_department_rounded,
    'Most-Watched Movies': Icons.movie_filter_rounded,
    'Latest Anime Movies': Icons.movie_rounded,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
        body: RefreshIndicator(
          color: hindiAccent,
          onRefresh: _refresh,
          child: FutureBuilder<List<HindiSection>>(
            future: _f,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return ListView(padding: const EdgeInsets.fromLTRB(16, 120, 16, 16), children: [
                  const ShimmerBox(height: 220, radius: 22),
                  const SizedBox(height: 20),
                  for (var i = 0; i < 3; i++) ...[
                    const ShimmerBox(width: 180, height: 18, radius: 6),
                    const SizedBox(height: 10),
                    const ShimmerBox(height: 180, radius: 14),
                    const SizedBox(height: 20),
                  ],
                ]);
              }
              if (snap.hasError || (snap.data ?? []).isEmpty) {
                return ListView(children: [
                  const SizedBox(height: 160),
                  EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Hindi library unavailable',
                    subtitle: 'Pull down or tap retry.',
                    action: FilledButton(onPressed: _refresh, child: const Text('Retry')),
                  ),
                ]);
              }
              final sections = snap.data!;
              final heroList = sections.first.items.take(8).toList();
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(child: HindiHeroSlider(items: heroList)),
                  SliverToBoxAdapter(child: _userRow('Continue watching', Icons.history_rounded, _hist)),
                  SliverToBoxAdapter(child: _userRow('My Hindi list', Icons.bookmark_rounded, _saved)),
                  for (final (n, s) in sections.indexed) ...[
                    SliverToBoxAdapter(
                      child: FadeIn(
                        delay: Duration(milliseconds: 80 * (n % 6)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SectionHeader(s.title, icon: _icons[s.title] ?? Icons.translate_rounded),
                          _HindiRow(s.items),
                        ]),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              );
            },
          ),
        ),
      );

  Widget _userRow(String title, IconData icon, Future<List<HindiAnime>> f) => FutureBuilder<List<HindiAnime>>(
        future: f,
        builder: (_, s) {
          final l = s.data ?? [];
          if (l.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title, icon: icon),
            _HindiRow(l),
          ]);
        },
      );

}


/// Auto-sliding, swipeable hero carousel with parallax, Ken Burns zoom and dots.
class HindiHeroSlider extends StatefulWidget {
  final List<HindiAnime> items;
  const HindiHeroSlider({super.key, required this.items});
  @override
  State<HindiHeroSlider> createState() => _HindiHeroSliderState();
}

class _HindiHeroSliderState extends State<HindiHeroSlider> {
  final _pc = PageController();
  Timer? _t;
  double _page = 0;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _pc.addListener(() => setState(() => _page = _pc.page ?? 0));
    _start();
  }

  void _start() {
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pc.hasClients || widget.items.length < 2) return;
      final n = (_i + 1) % widget.items.length;
      if (n == 0) {
        _pc.jumpToPage(0);
      } else {
        _pc.animateToPage(n, duration: const Duration(milliseconds: 800), curve: Curves.easeInOutCubic);
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
    final items = widget.items;
    final h = MediaQuery.sizeOf(context).width >= 720 ? 480.0 : 460.0;
    return SizedBox(
      height: h,
      child: Stack(children: [
        Listener(
          onPointerDown: (_) => _t?.cancel(),
          onPointerUp: (_) => _start(),
          child: PageView.builder(
            controller: _pc,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (_, i) => _slide(items[i], i - _page, i == _i),
          ),
        ),
        Positioned(
          right: 18,
          bottom: 26,
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                margin: const EdgeInsets.only(left: 5),
                width: i == _i ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _i ? hindiAccent : Colors.white30,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _slide(HindiAnime a, double off, bool active) => Pressable(
        onTap: () => openHindi(context, a),
        child: ClipRect(
          child: Stack(fit: StackFit.expand, children: [
            Transform.translate(
              offset: Offset(off * -120, 0),
              child: TweenAnimationBuilder<double>(
                key: ValueKey('${a.link}$active'),
                tween: Tween(begin: 1.0, end: active ? 1.12 : 1.0),
                duration: const Duration(seconds: 6),
                builder: (_, z, child) => Transform.scale(scale: z, child: child),
                child: NetImage(a.poster),
              ),
            ),
            const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [hindiAccent.withValues(alpha: 0.18), Colors.transparent],
                  stops: const [0, 0.6],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 50,
              child: AnimatedSlide(
                offset: active ? Offset.zero : const Offset(0, 0.25),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: active ? 1 : 0,
                  duration: const Duration(milliseconds: 500),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      const Badge2('HINDI DUB', color: hindiAccent, icon: Icons.translate_rounded),
                      if (a.isMovie) const Badge2('MOVIE', color: Color(0xFF7FB8FF)),
                      if (a.badge != null) Badge2(a.badge!),
                    ]),
                    const SizedBox(height: 10),
                    Text(a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            shadows: [Shadow(blurRadius: 16, color: Colors.black)])),
                    if (a.languages != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(a.languages!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textDim)),
                      ),
                    const SizedBox(height: 14),
                    Row(children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: hindiAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                        onPressed: () => openHindi(context, a),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Watch in Hindi', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        onPressed: () async {
                          final on = await HindiApi.instance.toggleSaved(a);
                          HindiApi.instance.changes.value++;
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(on ? 'Added to My Hindi list' : 'Removed from list')));
                          }
                        },
                        icon: const Icon(Icons.bookmark_add_outlined),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      );
}

// ---------------- Search ----------------
class HindiSearchScreen extends StatefulWidget {
  const HindiSearchScreen({super.key});
  @override
  State<HindiSearchScreen> createState() => _HindiSearchScreenState();
}

class _HindiSearchScreenState extends State<HindiSearchScreen> {
  final _c = TextEditingController();
  Timer? _deb;
  Future<List<HindiAnime>>? _f;

  void _go(String q) {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 500), () {
      if (q.trim().length < 2) return;
      setState(() => _f = HindiApi.instance.search(q.trim()));
    });
  }

  @override
  void dispose() {
    _deb?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 56, 16, 8),
              child: TextField(
                controller: _c,
                onChanged: _go,
                onSubmitted: _go,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search Hindi anime…',
                  prefixIcon: const Icon(Icons.search_rounded, color: hindiAccent),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: _f == null
                  ? const EmptyState(
                      icon: Icons.translate_rounded,
                      title: 'Find Hindi dubbed anime',
                      subtitle: 'Search series and movies from myanimes.in',
                    )
                  : FutureBuilder<List<HindiAnime>>(
                      future: _f,
                      builder: (_, s) {
                        if (s.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator(color: hindiAccent));
                        }
                        if (s.hasError) {
                          return const EmptyState(icon: Icons.error_outline_rounded, title: 'Search failed');
                        }
                        final l = s.data ?? [];
                        if (l.isEmpty) return const EmptyState(icon: Icons.search_off_rounded, title: 'No results');
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 160,
                            childAspectRatio: 0.5,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: l.length,
                          itemBuilder: (_, i) => FadeIn(
                            delay: Duration(milliseconds: 30 * (i % 12)),
                            child: HindiCard(anime: l[i], width: double.infinity),
                          ),
                        );
                      },
                    ),
            ),
          ]),
        ),
      );
}

// ---------------- Detail ----------------
class HindiDetailScreen extends StatefulWidget {
  final HindiAnime anime;
  const HindiDetailScreen({super.key, required this.anime});
  @override
  State<HindiDetailScreen> createState() => _HindiDetailScreenState();
}

class _HindiDetailScreenState extends State<HindiDetailScreen> {
  late Future<HindiDetail> _f = HindiApi.instance.detail(widget.anime);
  int _season = 0;
  bool _saved = false;
  Map<String, dynamic>? _last;
  Set<int> _done = {};
  Map<String, double> _prog = {};
  bool _seasonSet = false;

  Future<void> _refreshProgress() async {
    final d = await _f;
    final l = await HindiApi.instance.last(widget.anime);
    final w = await HindiApi.instance.watched(widget.anime, d.episodes.length);
    final pr = await HindiApi.instance.progress(d.episodes);
    if (!mounted) return;
    setState(() {
      _last = l;
      _done = w;
      _prog = pr;
      if (!_seasonSet && l != null) {
        final i = (l['i'] as num).toInt();
        if (i < d.episodes.length) {
          final seasons = d.episodes.map((e) => e.season).toSet().toList()..sort();
          _season = seasons.indexOf(d.episodes[i].season).clamp(0, seasons.length);
        }
        _seasonSet = true;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _refreshProgress();
    HindiApi.instance.isSaved(widget.anime).then((v) {
      if (mounted) setState(() => _saved = v);
    });
  }

  void _play(List<HindiEpisode> eps, int i) {
    HindiApi.instance.addHistory(widget.anime);
    Navigator.of(context)
        .push(fadeRoute(HindiPlayerScreen(anime: widget.anime, episodes: eps, index: i)))
        .then((_) => _refreshProgress());
  }

  int? _resumeIndex(List<HindiEpisode> eps) {
    final l = _last;
    if (l == null) return null;
    final i = (l['i'] as num).toInt();
    if (i >= eps.length) return null;
    final pos = (l['pos'] as num).toInt(), dur = (l['dur'] as num).toInt();
    // Finished → next episode (crosses into the next season too).
    if (dur > 0 && dur - pos < 30) return i + 1 < eps.length ? i + 1 : i;
    return i;
  }

  String _playLabel(List<HindiEpisode> eps, HindiAnime a, int? sel) {
    final r = _resumeIndex(eps);
    if (r == null) return a.isMovie ? 'Play movie' : 'Play ${sel != null ? 'S$sel ' : ''}EP 1';
    final l = _last!;
    final same = r == (l['i'] as num).toInt();
    final pos = (l['pos'] as num).toInt();
    if (!same) return 'Play next · ${eps[r].label}';
    final m = (pos ~/ 60).toString().padLeft(2, '0'), s = (pos % 60).toString().padLeft(2, '0');
    return a.isMovie ? 'Resume · $m:$s' : 'Continue ${eps[r].label} · $m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.anime;
    return Scaffold(
      body: FutureBuilder<HindiDetail>(
        future: _f,
        builder: (context, snap) {
          final d = snap.data;
          final eps = d?.episodes ?? [];
          final seasons = eps.map((e) => e.season).toSet().toList()..sort();
          final sel = seasons.isEmpty ? 1 : seasons[_season.clamp(0, seasons.length - 1)];
          final shown = [for (var i = 0; i < eps.length; i++) if (eps[i].season == sel) i];
          return CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: 380,
              pinned: true,
              backgroundColor: AppColors.bg,
              actions: [
                IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                        key: ValueKey(_saved), color: _saved ? hindiAccent : null),
                  ),
                  onPressed: () async {
                    final v = await HindiApi.instance.toggleSaved(a);
                    if (!mounted) return;
                    setState(() => _saved = v);
                    toast(this.context, v ? 'Added to My Hindi list' : 'Removed from list');
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  Hero(tag: 'h-${a.link}', child: NetImage(d?.poster ?? a.poster)),
                  const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.1)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    const Badge2('HINDI', color: hindiAccent, icon: Icons.translate_rounded),
                    Badge2(a.isMovie ? 'MOVIE' : 'SERIES', color: const Color(0xFF7FB8FF)),
                    if (eps.isNotEmpty && !a.isMovie) Badge2('${eps.length} EPISODES'),
                    if (seasons.length > 1) Badge2('${seasons.length} SEASONS', color: AppColors.accent),
                  ]),
                  if (a.languages != null) ...[
                    const SizedBox(height: 8),
                    Text(a.languages!, style: const TextStyle(color: AppColors.textDim)),
                  ],
                  if (d?.description != null) ...[
                    const SizedBox(height: 12),
                    Text(d!.description!, style: const TextStyle(color: AppColors.textDim, height: 1.45)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: hindiAccent, foregroundColor: Colors.black),
                      onPressed: eps.isEmpty
                          ? null
                          : () => _play(eps, _resumeIndex(eps) ?? (shown.isEmpty ? 0 : shown.first)),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(_playLabel(eps, a, seasons.length > 1 ? sel : null),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]),
              ),
            ),
            if (snap.connectionState != ConnectionState.done)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(color: hindiAccent)),
                ),
              )
            else if (snap.hasError)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: "Couldn't load episodes",
                  action: TextButton(
                    onPressed: () => setState(() => _f = HindiApi.instance.detail(a)),
                    child: const Text('Retry'),
                  ),
                ),
              )
            else ...[
              if (seasons.length > 1)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 46,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: seasons.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ChoiceChip(
                        label: Text('Season ${seasons[i]}'),
                        selected: i == _season,
                        selectedColor: hindiAccent,
                        labelStyle: TextStyle(
                            color: i == _season ? Colors.black : AppColors.text, fontWeight: FontWeight.w700),
                        onSelected: (_) => setState(() => _season = i),
                      ),
                    ),
                  ),
                ),
              if (!a.isMovie)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
                  sliver: SliverList.builder(
                    itemCount: shown.length,
                    itemBuilder: (_, j) {
                      final i = shown[j];
                      final e = eps[i];
                      final cur = _last != null && (_last!['i'] as num).toInt() == i;
                      final done = _done.contains(i);
                      final pr = _prog[e.link];
                      return FadeIn(
                        delay: Duration(milliseconds: 25 * (j % 12)),
                        child: Pressable(
                          onTap: () => _play(eps, i),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cur ? hindiAccent.withValues(alpha: 0.10) : AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cur ? hindiAccent.withValues(alpha: 0.6) : AppColors.border),
                            ),
                            child: Row(children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 128,
                                  height: 72,
                                  child: Stack(fit: StackFit.expand, children: [
                                    NetImage(d?.poster ?? a.poster),
                                    Container(color: Colors.black38),
                                    Center(
                                      child: Icon(done ? Icons.check_circle_rounded : Icons.play_circle_fill_rounded,
                                          color: done ? hindiAccent : Colors.white, size: 30),
                                    ),
                                    Positioned(
                                      left: 6,
                                      top: 6,
                                      child: Badge2('S${e.season} E${e.number}', color: hindiAccent),
                                    ),
                                    if (pr != null && !done)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: LinearProgressIndicator(
                                            value: pr, minHeight: 3, color: hindiAccent, backgroundColor: Colors.white24),
                                      ),
                                  ]),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Episode ${e.number}',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                  const SizedBox(height: 3),
                                  Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    done ? 'Watched' : (cur ? 'Continue watching' : (pr != null ? 'In progress' : 'Hindi')),
                                    style: TextStyle(
                                        color: done || cur ? hindiAccent : AppColors.textDim,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ]),
                              ),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ]);
        },
      ),
    );
  }
}

// ---------------- Player ----------------
class HindiPlayerScreen extends StatefulWidget {
  final HindiAnime anime;
  final List<HindiEpisode> episodes;
  final int index;
  const HindiPlayerScreen({super.key, required this.anime, required this.episodes, required this.index});
  @override
  State<HindiPlayerScreen> createState() => _HindiPlayerScreenState();
}

class _HindiPlayerScreenState extends State<HindiPlayerScreen> {
  late int _i = widget.index;
  VideoPlayerController? _vc;
  List<HindiStream> _streams = [];
  int _server = 0;
  String? _error;
  bool _loading = true;
  bool _ui = true;
  bool _locked = false;
  double _speed = 1;
  BoxFit _fit = BoxFit.contain;
  HlsMaster? _master;
  String _lang = 'hi';
  int? _quality; // null = auto
  final _hold = HoldSpeed();
  final _sleep = SleepTimer();
  int? _countdown;
  Timer? _cd;
  bool _introSkipped = false;
  bool _skipNextDismissed = false;
  List<SkipSegment> _segs = [];
  int _segFor = -1;
  final _skipped = <String>{};
  Timer? _hide;
  Timer? _save;

  HindiEpisode get _ep => widget.episodes[_i];

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _load();
    _save = Timer.periodic(const Duration(seconds: 5), (_) {
      final v = _vc?.value;
      if (v != null && v.isInitialized && v.isPlaying) _persist();
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    _save?.cancel();
    _cd?.cancel();
    _bannerT?.cancel();
    _sleep.cancel();
    _persist();
    _vc?.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _lang = await HindiApi.instance.audioLang();
      _streams = await HindiApi.instance.streams(_ep.link);
      if (_streams.isEmpty) throw Exception('No streams');
      for (var k = 0; k < _streams.length; k++) {
        if (await _open(k)) return;
      }
      throw Exception('All servers failed');
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not play this episode. Try another server.';
        });
      }
    }
  }

  Future<bool> _open(int k, {bool keep = false}) async {
    final s = _streams[k];
    final resume =
        _vc?.value.isInitialized == true && (keep || k != _server) ? _vc!.value.position : null;
    setState(() {
      _loading = true;
      if (k != _server || _master == null) _quality = null;
      _server = k;
    });
    var url = s.url;
    final m = keep && _master != null ? _master : await HindiApi.instance.master(s);
    _master = m;
    if (m != null) {
      if (m.audios.isNotEmpty && !m.audios.any((a) => a.lang == _lang)) {
        _lang = m.audios.any((a) => a.lang == 'hi') ? 'hi' : m.audios.first.lang;
      }
      url = await LocalHls.instance.serve(m.build(lang: _lang, variant: _quality));
    }
    final c = VideoPlayerController.networkUrl(
      Uri.parse(url),
      formatHint: VideoFormat.hls,
      httpHeaders: {if (s.referer != null) 'Referer': s.referer!},
    );
    try {
      await c.initialize().timeout(const Duration(seconds: 25));
      final old = _vc;
      _vc = c;
      await old?.dispose();
      final saved = await HindiApi.instance.position(_ep.link);
      final at = resume ?? (saved > 10 ? Duration(seconds: saved) : Duration.zero);
      if (at > Duration.zero && at < c.value.duration) await c.seekTo(at);
      await c.setPlaybackSpeed(_speed);
      c.addListener(_tick);
      await c.play();
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
      _autoHide();
      return true;
    } catch (_) {
      await c.dispose();
      return false;
    }
  }

  bool _ended = false;
  void _tick() {
    final v = _vc!.value;
    if (!mounted) return;
    if (v.isInitialized && v.duration > Duration.zero && v.position >= v.duration - const Duration(milliseconds: 500)) {
      if (!_ended) {
        _ended = true;
        if (_sleep.endOfEpisode) {
          _sleep.cancel();
          _vc?.pause();
        } else if (_i >= widget.episodes.length - 1) {
          _persist();
          _showBanner(widget.anime.isMovie ? 'Movie finished' : 'You finished ${widget.anime.title}! 🎉');
        } else if (Library.instance.autoPlayNext) {
          _persist();
          if (widget.episodes[_i + 1].season != _ep.season) {
            _showBanner('Season ${_ep.season} finished. Season ${widget.episodes[_i + 1].season} is up next');
          }
          _startCountdown();
        }
      }
    }
    setState(() {});
  }

  void _persist() {
    final v = _vc?.value;
    if (v == null || !v.isInitialized || v.duration == Duration.zero) return;
    final pos = v.position.inSeconds, dur = v.duration.inSeconds;
    // Finished episodes restart from the beginning next time.
    HindiApi.instance.savePosition(_ep.link, dur - pos < 30 ? 0 : pos, dur);
    HindiApi.instance.saveLast(widget.anime, _i, _ep.label, pos, dur);
  }

  String? _banner;
  Timer? _bannerT;
  void _showBanner(String t) {
    _bannerT?.cancel();
    setState(() => _banner = t);
    _bannerT = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  void _startCountdown() {
    _cd?.cancel();
    setState(() => _countdown = 6);
    _cd = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _countdown = _countdown! - 1);
      if (_countdown! <= 0) {
        t.cancel();
        _goto(_i + 1);
      }
    });
  }

  void _goto(int i) {
    _persist();
    if (i < 0 || i >= widget.episodes.length) return;
    final from = widget.episodes[_i].season, to = widget.episodes[i].season;
    if (to != from && i == _i + 1) {
      _showBanner('Season $from complete!  Starting Season $to · EP ${widget.episodes[i].number}');
    }
    _cd?.cancel();
    _countdown = null;
    _introSkipped = false;
    _skipNextDismissed = false;
    _segs = [];
    _segFor = -1;
    _skipped.clear();
    _vc?.removeListener(_tick);
    _vc?.pause();
    _ended = false;
    setState(() => _i = i);
    _load();
  }

  void _autoHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted && (_vc?.value.isPlaying ?? false)) setState(() => _ui = false);
    });
  }

  void _seek(int s) {
    final c = _vc;
    if (c == null) return;
    HapticFeedback.selectionClick();
    c.seekTo(c.value.position + Duration(seconds: s));
    _autoHide();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _sheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Server', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var k = 0; k < _streams.length; k++)
                ChoiceChip(
                  label: Text(_streams[k].server),
                  selected: k == _server,
                  selectedColor: hindiAccent,
                  onSelected: (_) async {
                    Navigator.pop(ctx);
                    if (!await _open(k) && mounted) toast(context, 'That server failed');
                  },
                ),
            ]),
            if ((_master?.audios.length ?? 0) > 0) ...[
              const SizedBox(height: 16),
              const Text('Audio language', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in _master!.audios)
                  ChoiceChip(
                    avatar: a.lang == 'hi' ? const Icon(Icons.star_rounded, size: 16) : null,
                    label: Text(_langName(a)),
                    selected: a.lang == _lang,
                    selectedColor: hindiAccent,
                    onSelected: (_) async {
                      Navigator.pop(ctx);
                      setState(() => _lang = a.lang);
                      await HindiApi.instance.setAudioLang(a.lang);
                      await _open(_server, keep: true);
                    },
                  ),
              ]),
            ],
            if ((_master?.variants.length ?? 0) > 0) ...[
              const SizedBox(height: 16),
              const Text('Quality', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ChoiceChip(
                  label: const Text('Auto'),
                  selected: _quality == null,
                  selectedColor: hindiAccent,
                  onSelected: (_) async {
                    Navigator.pop(ctx);
                    setState(() => _quality = null);
                    await _open(_server, keep: true);
                  },
                ),
                for (var q = 0; q < _master!.variants.length; q++)
                  ChoiceChip(
                    label: Text(_master!.variants[q].label),
                    selected: _quality == q,
                    selectedColor: hindiAccent,
                    onSelected: (_) async {
                      Navigator.pop(ctx);
                      setState(() => _quality = q);
                      await _open(_server, keep: true);
                    },
                  ),
              ]),
            ],
            const SizedBox(height: 16),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (_, set) => Column(children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: hindiAccent,
                  title: const Text('Auto-play next episode'),
                  value: Library.instance.autoPlayNext,
                  onChanged: (v) {
                    Library.instance.setAutoNext(v);
                    set(() {});
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bedtime_rounded, color: hindiAccent),
                  title: const Text('Sleep timer'),
                  trailing: Text(_sleep.label, style: const TextStyle(color: AppColors.textDim)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _sleepPick();
                  },
                ),
              ]),
            ),
            const Text('Speed', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final s in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                ChoiceChip(
                  label: Text('${s}x'),
                  selected: s == _speed,
                  selectedColor: hindiAccent,
                  onSelected: (_) {
                    setState(() => _speed = s);
                    _vc?.setPlaybackSpeed(s);
                    Navigator.pop(ctx);
                  },
                ),
            ]),
            const SizedBox(height: 16),
            const Text('Screen', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final f in [(BoxFit.contain, 'Fit'), (BoxFit.cover, 'Zoom'), (BoxFit.fill, 'Stretch')])
                ChoiceChip(
                  label: Text(f.$2),
                  selected: f.$1 == _fit,
                  selectedColor: hindiAccent,
                  onSelected: (_) {
                    setState(() => _fit = f.$1);
                    Navigator.pop(ctx);
                  },
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  static const _langNames = {
    'hi': 'Hindi', 'ta': 'Tamil', 'te': 'Telugu', 'ml': 'Malayalam', 'kn': 'Kannada',
    'bn': 'Bengali', 'en': 'English', 'ja': 'Japanese', 'mr': 'Marathi',
  };
  String _langName(HlsAudio a) {
    final en = _langNames[a.lang] ?? a.lang.toUpperCase();
    return a.name.isEmpty || a.name == en ? en : '$en · ${a.name}';
  }

  @override
  Widget build(BuildContext context) {
    final c = _vc;
    final ready = c != null && c.value.isInitialized && _error == null;
    final pos = c?.value.position ?? Duration.zero;
    final dur = c?.value.duration ?? Duration.zero;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _ui = !_ui);
          if (_ui) _autoHide();
        },
        onLongPressStart: _locked ? null : (_) => setState(() => _hold.start(_vc)),
        onLongPressEnd: (_) => setState(() => _hold.end(_vc)),
        onDoubleTapDown: _locked
            ? null
            : (d) => _seek(d.globalPosition.dx < MediaQuery.of(context).size.width / 2 ? -10 : 10),
        child: Stack(fit: StackFit.expand, children: [
          if (ready)
            Center(
              child: FittedBox(
                fit: _fit,
                child: SizedBox(
                  width: c.value.size.width == 0 ? 16 : c.value.size.width,
                  height: c.value.size.height == 0 ? 9 : c.value.size.height,
                  child: VideoPlayer(c),
                ),
              ),
            ),
          if (_loading || (ready && c.value.isBuffering))
            const Center(child: CircularProgressIndicator(color: hindiAccent)),
          if (_error != null)
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 44),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                  if (_streams.length > 1) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: _sheet, child: const Text('Servers')),
                  ],
                ]),
              ]),
            ),
          HoldSpeedBadge(visible: _hold.active),
          Align(
            alignment: const Alignment(0, -0.55),
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (c, a) => FadeTransition(
                    opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(a), child: c)),
                child: _banner == null
                    ? const SizedBox.shrink()
                    : Container(
                        key: ValueKey(_banner),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: hindiAccent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(_banner!,
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
                      ),
              ),
            ),
          ),
          if (ready && !_locked) ..._overlayButtons(c),
          if (_countdown != null && _countdown! > 0)
            Positioned(
              right: 24,
              bottom: 90,
              child: UpNextCard(
                seconds: _countdown!,
                title: widget.episodes[_i + 1].season != _ep.season
                    ? 'New season · ${widget.episodes[_i + 1].label}'
                    : widget.episodes[_i + 1].label,
                accent: hindiAccent,
                onPlay: () => _goto(_i + 1),
                onCancel: () {
                  _cd?.cancel();
                  setState(() => _countdown = null);
                },
              ),
            ),
          AnimatedOpacity(
            opacity: _ui ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_ui,
              child: _locked ? _lockedUi() : _controls(ready, pos, dur),
            ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _overlayButtons(VideoPlayerController c) {
    final pos = c.value.position.inSeconds;
    final dur = c.value.duration.inSeconds;
    final out = <Widget>[];
    if (dur > 0 && _segFor != _i) {
      final idx = _i;
      _segFor = idx;
      SkipTimes.instance
          .find(
            showKey: '${widget.anime.link}#${_ep.season}',
            title: widget.anime.title,
            episode: _ep.number,
            season: _ep.season,
            length: c.value.duration.inMilliseconds / 1000,
          )
          .then((v) {
        if (mounted && _i == idx) setState(() => _segs = v);
      });
    }
    final p = c.value.position.inMilliseconds / 1000;
    final seg = _segs.where((x) => x.contains(p)).firstOrNull;
    if (seg != null) {
      final id = '${seg.type}${seg.start}';
      final hasNextEp = _i < widget.episodes.length - 1;
      void doSkip() {
        _skipped.add(id);
        if ((seg.type == 'outro' || seg.type == 'preview') && seg.end >= dur - 2 && hasNextEp && Library.instance.autoPlayNext) {
          _goto(_i + 1);
        } else {
          c.seekTo(Duration(milliseconds: (seg.end * 1000).round()));
        }
      }
      if (Library.instance.autoSkipIntro && !_skipped.contains(id) && seg.type != 'preview') {
        _skipped.add(id);
        Future.microtask(doSkip);
      } else {
        out.add(Positioned(
          right: 24,
          bottom: _ui ? 96 : 40,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
            onPressed: () => setState(doSkip),
            icon: const Icon(Icons.fast_forward_rounded),
            label: Text(seg.label),
          ),
        ));
        return out;
      }
    }
    final hasNext = _i < widget.episodes.length - 1;
    if (hasNext && !_skipNextDismissed && _countdown == null && dur > 300 && dur - pos <= 100 && dur - pos > 1) {
      out.add(Positioned(
        right: 24,
        bottom: _ui ? 96 : 40,
        child: NextEpisodePill(accent: hindiAccent, onTap: () => _goto(_i + 1)),
      ));
    }
    return out;
  }

  void _episodes() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      constraints: const BoxConstraints(maxWidth: 560),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.85,
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('Episodes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: ListView.builder(
              controller: ScrollController(initialScrollOffset: (_i * 56.0 - 100).clamp(0, double.infinity)),
              itemCount: widget.episodes.length,
              itemExtent: 56,
              itemBuilder: (_, i) => ListTile(
                selected: i == _i,
                selectedColor: hindiAccent,
                leading: Icon(i == _i ? Icons.equalizer_rounded : Icons.play_circle_outline_rounded),
                title: Text(widget.episodes[i].label),
                onTap: () {
                  Navigator.pop(ctx);
                  if (i != _i) _goto(i);
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _sleepPick() async {
    final m = await pickSleep(context, _sleep, hindiAccent);
    if (m == null || !mounted) return;
    setState(() => _sleep.set(m == 0 ? null : m, () {
          _vc?.pause();
          if (mounted) setState(() {});
        }));
    toast(context, m == 0 ? 'Sleep timer off' : 'Sleep timer: ${_sleep.label}');
  }

  Widget _lockedUi() => SafeArea(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: IconButton.filledTonal(
              icon: const Icon(Icons.lock_rounded),
              onPressed: () => setState(() => _locked = false),
            ),
          ),
        ),
      );

  Widget _controls(bool ready, Duration pos, Duration dur) {
    final c = _vc;
    final max = dur.inMilliseconds.toDouble().clamp(1, double.infinity).toDouble();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xAA000000), Colors.transparent, Colors.transparent, Color(0xCC000000)],
          stops: [0, 0.3, 0.65, 1],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.anime.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(
                      '${_ep.label}  •  ${_master == null ? 'Hindi' : _langName(_master!.audios.firstWhere((a) => a.lang == _lang, orElse: () => const HlsAudio('Hindi', 'hi', ''))).split(' ·').first}${_quality != null && _master != null ? '  •  ${_master!.variants[_quality!].label}' : ''}${_streams.isNotEmpty ? '  •  ${_streams[_server].server}' : ''}',
                      style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                ]),
              ),
              IconButton(
                tooltip: 'Auto-play',
                icon: Icon(Library.instance.autoPlayNext ? Icons.repeat_on_rounded : Icons.repeat_rounded,
                    color: Library.instance.autoPlayNext ? hindiAccent : Colors.white),
                onPressed: () {
                  final v = !Library.instance.autoPlayNext;
                  Library.instance.setAutoNext(v);
                  if (!v) {
                    _cd?.cancel();
                    _countdown = null;
                  }
                  setState(() {});
                  _showBanner(v ? 'Auto-play ON' : 'Auto-play OFF');
                },
              ),
              IconButton(icon: const Icon(Icons.playlist_play_rounded), onPressed: _episodes),
              IconButton(icon: const Icon(Icons.translate_rounded), onPressed: _sheet),
              IconButton(icon: const Icon(Icons.lock_open_rounded), onPressed: () => setState(() => _locked = true)),
              IconButton(icon: const Icon(Icons.tune_rounded), onPressed: _sheet),
            ]),
            const Spacer(),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                iconSize: 34,
                icon: const Icon(Icons.skip_previous_rounded),
                onPressed: _i > 0 ? () => _goto(_i - 1) : null,
              ),
              const SizedBox(width: 18),
              IconButton(iconSize: 38, icon: const Icon(Icons.replay_10_rounded), onPressed: () => _seek(-10)),
              const SizedBox(width: 18),
              IconButton.filled(
                iconSize: 46,
                style: IconButton.styleFrom(backgroundColor: hindiAccent, foregroundColor: Colors.black),
                icon: Icon(c?.value.isPlaying ?? false ? Icons.pause_rounded : Icons.play_arrow_rounded),
                onPressed: !ready
                    ? null
                    : () {
                        c!.value.isPlaying ? c.pause() : c.play();
                        _autoHide();
                      },
              ),
              const SizedBox(width: 18),
              IconButton(iconSize: 38, icon: const Icon(Icons.forward_10_rounded), onPressed: () => _seek(10)),
              const SizedBox(width: 18),
              IconButton(
                iconSize: 34,
                icon: const Icon(Icons.skip_next_rounded),
                onPressed: _i < widget.episodes.length - 1 ? () => _goto(_i + 1) : null,
              ),
            ]),
            const Spacer(),
            Row(children: [
              Text(_fmt(pos), style: const TextStyle(fontSize: 12)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    activeTrackColor: hindiAccent,
                    thumbColor: hindiAccent,
                    inactiveTrackColor: Colors.white24,
                  ),
                  child: Slider(
                    value: pos.inMilliseconds.toDouble().clamp(0, max).toDouble(),
                    max: max,
                    onChanged: ready ? (v) => c!.seekTo(Duration(milliseconds: v.toInt())) : null,
                  ),
                ),
              ),
              Text(_fmt(dur), style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              TextButton(onPressed: _sheet, child: Text('${_speed}x', style: const TextStyle(color: hindiAccent))),
            ]),
          ]),
        ),
      ),
    );
  }
}
