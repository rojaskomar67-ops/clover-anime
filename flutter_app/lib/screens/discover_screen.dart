import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/hianime_source.dart';
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
  late final _tabs = TabController(length: 4, vsync: this);
  static const _days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  int _day = DateTime.now().weekday - 1;
  final src = HiAnimeSource.instance;

  static const _palette = [
    Color(0xFF3DDC84), Color(0xFFFFB547), Color(0xFFFF5470), Color(0xFF7FB8FF),
    Color(0xFFC792EA), Color(0xFF4DD0E1), Color(0xFFFF8A65), Color(0xFFAED581),
  ];

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _open(String title, Future<List<AnimeRef>> Function(int) loader) =>
      Navigator.of(context).push(fadeRoute(ListScreen(title: title, loader: loader)));

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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textDim,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [Tab(text: 'Categories'), Tab(text: 'Genres'), Tab(text: 'A-Z'), Tab(text: 'Schedule')],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [_categories(), _genres(), _az(), _schedule()],
          ),
        ),
      ]),
    );
  }

  Widget _tileGrid(int count, String Function(int) label, VoidCallback Function(int) onTap,
          {double aspect = 2.4, IconData? icon}) =>
      GridView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: aspect,
        ),
        itemCount: count,
        itemBuilder: (_, i) {
          final c = _palette[i % _palette.length];
          return FadeIn(
            delay: Duration(milliseconds: 20 * (i % 12)),
            child: Pressable(
              onTap: onTap(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [c.withValues(alpha: 0.35), c.withValues(alpha: 0.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: c.withValues(alpha: 0.35)),
                ),
                child: Row(children: [
                  if (icon != null) ...[Icon(icon, color: c, size: 20), const SizedBox(width: 8)],
                  Expanded(
                    child: Text(label(i),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ]),
              ),
            ),
          );
        },
      );

  Widget _categories() => _tileGrid(
        kCategories.length,
        (i) => kCategories[i].title,
        (i) => () => _open(kCategories[i].title, (p) => src.category(kCategories[i].path, page: p)),
        icon: Icons.local_movies_rounded,
      );

  Widget _genres() => _tileGrid(
        kGenres.length,
        (i) => genreLabel(kGenres[i]),
        (i) => () => _open(genreLabel(kGenres[i]), (p) => src.genre(kGenres[i], page: p)),
      );

  Widget _az() {
    final letters = ['all', '0-9', ...List.generate(26, (i) => String.fromCharCode(97 + i))];
    return _tileGrid(
      letters.length,
      (i) => letters[i].toUpperCase(),
      (i) => () => _open('A-Z: ${letters[i].toUpperCase()}', (p) => src.azList(letters[i], page: p)),
      aspect: 1.6,
    );
  }

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
              labelStyle: TextStyle(color: _day == i ? Colors.black : AppColors.text, fontWeight: FontWeight.w700),
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
                return EmptyState(
                  icon: Icons.event_busy_rounded,
                  title: snap.hasError ? "Couldn't load schedule" : 'No episodes scheduled',
                  action: snap.hasError
                      ? FilledButton(onPressed: () => setState(() {}), child: const Text('Retry'))
                      : null,
                );
              }
              return PosterGrid(items: l);
            },
          ),
        ),
      ]);
}
