import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/library.dart';
import '../widgets/common.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: SafeArea(
          bottom: false,
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('My List', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              ),
            ),
            const TabBar(
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textDim,
              dividerColor: Colors.transparent,
              labelStyle: TextStyle(fontWeight: FontWeight.w700),
              tabs: [Tab(text: 'Saved'), Tab(text: 'History')],
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: Library.instance,
                builder: (context, _) {
                  final lib = Library.instance;
                  return TabBarView(children: [
                    lib.watchlist.isEmpty
                        ? const EmptyState(
                            icon: Icons.bookmark_add_outlined,
                            title: 'Your list is empty',
                            subtitle: 'Tap the bookmark on any anime to save it here.',
                          )
                        : PosterGrid(items: lib.watchlist),
                    lib.history.isEmpty
                        ? const EmptyState(
                            icon: Icons.history_rounded,
                            title: 'No watch history yet',
                            subtitle: 'Episodes you watch will show up here.',
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(0, 8, 0, 110),
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: lib.clearHistory,
                                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                                  label: const Text('Clear all'),
                                ),
                              ),
                              ...lib.history.map((h) => Dismissible(
                                    key: ValueKey(h.anime.key + h.episodeId),
                                    direction: DismissDirection.endToStart,
                                    onDismissed: (_) => lib.removeHistory(h),
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 24),
                                      color: AppColors.danger.withValues(alpha: 0.2),
                                      child: const Icon(Icons.delete_rounded, color: AppColors.danger),
                                    ),
                                    child: ListTile(
                                      onTap: () => openAnime(context, h.anime),
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SizedBox(width: 52, height: 72, child: NetImage(h.anime.poster)),
                                      ),
                                      title: Text(h.anime.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w700)),
                                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text('Episode ${h.episodeNumber}',
                                            style: const TextStyle(color: AppColors.textDim)),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: h.progress,
                                            minHeight: 4,
                                            color: AppColors.primary,
                                            backgroundColor: AppColors.border,
                                          ),
                                        ),
                                      ]),
                                    ),
                                  )),
                            ],
                          ),
                  ]);
                },
              ),
            ),
          ]),
        ),
      );
}
