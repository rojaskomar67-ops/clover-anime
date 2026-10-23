import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/clover_api.dart';
import '../data/library.dart';
import '../data/models.dart';
import '../widgets/common.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<AnimeRef>? _results;
  bool _loading = false;
  String? _error;
  String _filter = 'All';
  static const _filters = ['All', 'TV', 'Movie', 'OVA', 'ONA', 'Special', 'Dub'];
  static const _quick = ['One Piece', 'Jujutsu Kaisen', 'Solo Leveling', 'Demon Slayer', 'Naruto', 'Frieren'];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(q));
    setState(() {});
  }

  Future<void> _search(String q) async {
    q = q.trim();
    if (q.length < 2) {
      setState(() => _results = null);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await CloverApi.instance.search(q);
      if (_ctrl.text.trim() != q) return;
      Library.instance.addSearch(q);
      setState(() => _results = r);
    } catch (_) {
      setState(() => _error = 'Search failed. Check your internet.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AnimeRef> get _filtered {
    final r = _results ?? [];
    if (_filter == 'All') return r;
    if (_filter == 'Dub') return r.where((a) => a.dub > 0).toList();
    return r.where((a) => (a.type ?? '').toUpperCase() == _filter.toUpperCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _ctrl,
            onChanged: _onChanged,
            onSubmitted: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search anime...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textDim),
              suffixIcon: _ctrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _ctrl.clear();
                        setState(() => _results = null);
                      },
                    ),
            ),
          ),
        ),
        if (_results != null)
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ChoiceChip(
                label: Text(_filters[i]),
                selected: _filter == _filters[i],
                showCheckmark: false,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: _filter == _filters[i] ? Colors.black : AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() => _filter = _filters[i]),
              ),
            ),
          ),
        if (_loading) const LinearProgressIndicator(color: AppColors.primary, minHeight: 2),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _body(),
          ),
        ),
      ]),
    );
  }

  Widget _body() {
    if (_error != null) {
      return EmptyState(key: const ValueKey('err'), icon: Icons.wifi_off_rounded, title: _error!);
    }
    if (_results == null) {
      return ListenableBuilder(
        key: const ValueKey('idle'),
        listenable: Library.instance,
        builder: (_, __) {
          final recent = Library.instance.recentSearches;
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (recent.isNotEmpty) ...[
              Row(children: [
                const Expanded(
                    child: Text('Recent searches', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                TextButton(onPressed: Library.instance.clearSearches, child: const Text('Clear')),
              ]),
              ...recent.map((q) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_rounded, color: AppColors.textDim),
                    title: Text(q),
                    trailing: const Icon(Icons.north_west_rounded, size: 18, color: AppColors.textDim),
                    onTap: () {
                      _ctrl.text = q;
                      _search(q);
                    },
                  )),
              const SizedBox(height: 16),
            ],
            const Text('Popular searches', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quick
                  .map((q) => ActionChip(
                        avatar: const Icon(Icons.local_fire_department_rounded, size: 16, color: AppColors.accent),
                        label: Text(q),
                        onPressed: () {
                          _ctrl.text = q;
                          _search(q);
                        },
                      ))
                  .toList(),
            ),
          ]);
        },
      );
    }
    final f = _filtered;
    if (f.isEmpty) {
      return const EmptyState(
          key: ValueKey('empty'), icon: Icons.search_off_rounded, title: 'No results', subtitle: 'Try another name');
    }
    return PosterGrid(key: ValueKey('r${_ctrl.text}$_filter'), items: f);
  }
}
