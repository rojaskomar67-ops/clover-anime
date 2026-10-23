import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/jikan_api.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'list_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);
  late Future<List<Genre>> _genres = JikanApi.instance.genres();
  static const _days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  int _day = DateTime.now().weekday - 1;

  static const _palette = [
    Color(0xFF3DDC84), Color(0xFFFFB547), Color(0xFFFF5470), Color(0xFF7FB8FF),
    Color(0xFFC792EA), Color(0xFF4DD0E1), Color(0xFFFF8A65), Color(0xFFAED581),
  ];

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Discover', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          ),
        ),
        TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textDim,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [Tab(text: 'Genres'), Tab(text: 'Schedule')],
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [_genreGrid(), _schedule()]),
        ),
      ]),
    );
  }

  Widget _genreGrid() => FutureBuilder<List<Genre>>(
        future: _genres,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final g = snap.data ?? [];
          if (g.isEmpty) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: "Couldn't load genres",
              action: FilledButton(
                onPressed: () => setState(() => _genres = JikanApi.instance.genres()),
                child: const Text('Retry'),
              ),
            );
          }
          return GridView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.4,
            ),
            itemCount: g.length,
            itemBuilder: (_, i) {
              final c = _palette[i % _palette.length];
              return FadeIn(
                delay: Duration(milliseconds: 20 * (i % 12)),
                child: Pressable(
                  onTap: () => Navigator.of(context).push(fadeRoute(ListScreen(
                    title: g[i].name,
                    loader: (p) => JikanApi.instance.byGenre(g[i].id, page: p),
                  ))),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [c.withValues(alpha: 0.35), c.withValues(alpha: 0.08)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: c.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(g[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text('${g[i].count} titles',
                            style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

  Widget _schedule() => Column(children: [
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(_days[i].substring(0, 3).toUpperCase()),
              selected: _day == i,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: _day == i ? Colors.black : AppColors.text,
                fontWeight: FontWeight.w700,
              ),
              showCheckmark: false,
              onSelected: (_) => setState(() => _day = i),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<AnimeRef>>(
            key: ValueKey(_day),
            future: JikanApi.instance.schedule(_days[_day]),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              final l = snap.data ?? [];
              if (l.isEmpty) {
                return const EmptyState(icon: Icons.event_busy_rounded, title: 'No episodes scheduled');
              }
              return PosterGrid(items: l);
            },
          ),
        ),
      ]);
}
