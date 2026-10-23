import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';

/// Generic grid of anime with optional infinite scroll.
class ListScreen extends StatefulWidget {
  final String title;
  final Future<List<AnimeRef>> Function(int page) loader;
  final bool paged;
  const ListScreen({super.key, required this.title, required this.loader, this.paged = true});
  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  final _items = <AnimeRef>[];
  final _sc = ScrollController();
  int _page = 1;
  bool _loading = false;
  bool _end = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _more();
    _sc.addListener(() {
      if (widget.paged && _sc.position.pixels > _sc.position.maxScrollExtent - 600) _more();
    });
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  Future<void> _more() async {
    if (_loading || _end) return;
    setState(() => _loading = true);
    try {
      final r = await widget.loader(_page);
      final keys = _items.map((e) => e.key).toSet();
      _items.addAll(r.where((e) => !keys.contains(e.key)));
      _page++;
      if (r.isEmpty || !widget.paged) _end = true;
      _error = null;
    } catch (e) {
      _error = 'Could not load. Pull to retry.';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: _items.isEmpty && _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _items.isEmpty
                ? EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: _error ?? 'Nothing here yet',
                    action: FilledButton(
                        onPressed: () {
                          _end = false;
                          _more();
                        },
                        child: const Text('Retry')),
                  )
                : PosterGrid(
                    items: _items,
                    controller: _sc,
                    footer: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                          )
                        : null,
                  ),
      );
}
