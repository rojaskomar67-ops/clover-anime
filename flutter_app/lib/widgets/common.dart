import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../screens/detail_screen.dart';

Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: c,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(c),
            child: child,
          ),
        );
      },
    );

void openAnime(BuildContext context, AnimeRef a) =>
    Navigator.of(context).push(fadeRoute(DetailScreen(anime: a)));

class NetImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: AppColors.surfaceHi,
        child: const Icon(Icons.movie_outlined, color: AppColors.textDim),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      width: width,
      height: height,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, __) => const ShimmerBox(),
      errorWidget: (_, __, ___) => Container(
        color: AppColors.surfaceHi,
        child: const Icon(Icons.broken_image_outlined, color: AppColors.textDim),
      ),
    );
  }
}

class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  const ShimmerBox({super.key, this.width, this.height, this.radius = 0});
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: AppColors.surface,
        highlightColor: AppColors.surfaceHi,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      );
}

/// Scales slightly when pressed, for a tactile feel.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down ? 0.95 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

class Badge2 extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Badge2(this.text, {super.key, this.color = AppColors.primary, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: Colors.black),
            const SizedBox(width: 2),
          ],
          Text(text,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black)),
        ]),
      );
}

class PosterCard extends StatelessWidget {
  final AnimeRef anime;
  final double width;
  final int? rank;
  const PosterCard({super.key, required this.anime, this.width = 128, this.rank});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => openAnime(context, anime),
      child: SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 0.7,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(fit: StackFit.expand, children: [
                Hero(tag: 'poster-${anime.key}', child: NetImage(anime.poster)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xAA000000)],
                      stops: [0.6, 1],
                    ),
                  ),
                ),
                if (anime.score != null && anime.score != '0' && anime.score != 'null')
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Badge2(anime.score!, color: AppColors.accent, icon: Icons.star_rounded),
                  ),
                if (rank != null)
                  Positioned(
                    bottom: 2,
                    left: 6,
                    child: Text('$rank',
                        style: const TextStyle(
                            fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
                  ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Row(children: [
                    if (anime.sub > 0) Badge2('CC ${anime.sub}'),
                    if (anime.dub > 0) ...[
                      const SizedBox(width: 3),
                      Badge2('DUB ${anime.dub}', color: const Color(0xFF7FB8FF)),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Text(anime.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.2)),
          if (anime.type != null)
            Text(
              [anime.type, if (anime.episodes != null) '${anime.episodes} eps'].join(' • '),
              style: const TextStyle(fontSize: 11, color: AppColors.textDim),
            ),
        ]),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final VoidCallback? onMore;
  const SectionHeader(this.title, {super.key, this.icon, this.onMore});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 8, 10),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
          ),
          if (onMore != null)
            TextButton(
              onPressed: onMore,
              child: const Text('See all', style: TextStyle(color: AppColors.primary)),
            ),
        ]),
      );
}

class PosterRow extends StatelessWidget {
  final Future<List<AnimeRef>> future;
  final bool ranked;
  const PosterRow({super.key, required this.future, this.ranked = false});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 250,
        child: FutureBuilder<List<AnimeRef>>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) => const ShimmerBox(width: 128, height: 183, radius: 14),
              );
            }
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return const Center(
                  child: Text("Couldn't load this list", style: TextStyle(color: AppColors.textDim)));
            }
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => FadeIn(
                delay: Duration(milliseconds: 40 * (i % 8)),
                child: PosterCard(anime: list[i], rank: ranked ? i + 1 : null),
              ),
            );
          },
        ),
      );
}

class FadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const FadeIn({super.key, required this.child, this.delay = Duration.zero});
  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(a),
        child: widget.child,
      ),
    );
  }
}

class PosterGrid extends StatelessWidget {
  final List<AnimeRef> items;
  final ScrollController? controller;
  final Widget? footer;
  const PosterGrid({super.key, required this.items, this.controller, this.footer});
  @override
  Widget build(BuildContext context) => CustomScrollView(
        controller: controller,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: 0.52,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => FadeIn(
                  delay: Duration(milliseconds: 30 * (i % 9)),
                  child: PosterCard(anime: items[i], width: double.infinity),
                ),
                childCount: items.length,
              ),
            ),
          ),
          if (footer != null) SliverToBoxAdapter(child: footer),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
              child: Icon(icon, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textDim)),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ]),
        ),
      );
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
}
