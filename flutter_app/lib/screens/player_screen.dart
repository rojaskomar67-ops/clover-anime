import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/theme.dart';
import '../data/clover_api.dart';
import '../data/library.dart';
import '../data/models.dart';
import '../widgets/common.dart' show toast;
import '../widgets/player_extras.dart';

class PlayerScreen extends StatefulWidget {
  final AnimeRef anime;
  final List<Episode> episodes;
  final int index;
  const PlayerScreen({super.key, required this.anime, required this.episodes, required this.index});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final lib = Library.instance;
  VideoPlayerController? _vc;
  late int _index = widget.index;
  List<ServerItem> _servers = [];
  ServerItem? _server;
  late String _type = lib.preferredType;
  StreamInfo? _stream;
  Subtitle? _sub;
  String? _error;
  String _status = 'Loading episode...';
  bool _showControls = true;
  bool _locked = false;
  bool _fill = false;
  bool _seeking = false;
  double _seekValue = 0;
  Timer? _hideTimer;
  Timer? _saveTimer;
  int _seekFlash = 0; // -1 back, 1 forward
  Timer? _flashTimer;
  int? _nextCountdown;
  Timer? _nextTimer;
  bool _introSkipped = false;
  bool _ended = false;
  final _hold = HoldSpeed();
  final _sleep = SleepTimer();
  bool _manualIntro = false;

  Episode get _ep => widget.episodes[_index];
  bool get _hasNext => _index < widget.episodes.length - 1;
  bool get _hasPrev => _index > 0;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _loadEpisode();
  }

  @override
  void dispose() {
    _saveProgress();
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _flashTimer?.cancel();
    _nextTimer?.cancel();
    _sleep.cancel();
    _vc?.removeListener(_onTick);
    _vc?.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _saveProgress() {
    final v = _vc?.value;
    if (v == null || !v.isInitialized || v.duration.inMilliseconds == 0) return;
    lib.saveProgress(widget.anime, _ep.id, _ep.number, v.position.inMilliseconds, v.duration.inMilliseconds);
  }

  Future<void> _loadEpisode() async {
    _nextTimer?.cancel();
    setState(() {
      _error = null;
      _status = 'Finding servers...';
      _nextCountdown = null;
      _introSkipped = false;
      _ended = false;
      _stream = null;
    });
    try {
      _servers = await CloverApi.instance.servers(_ep.id);
    } catch (_) {
      _servers = [];
    }
    final ofType = _servers.where((s) => s.type == _type).toList();
    if (ofType.isEmpty && _servers.isNotEmpty) _type = _servers.first.type;
    final candidates = _servers.where((s) => s.type == _type).toList();
    // Try each server in order until one plays.
    for (final s in candidates.isEmpty ? [null] : candidates) {
      if (!mounted) return;
      final ok = await _tryServer(s);
      if (ok) return;
    }
    if (mounted) setState(() => _error = 'No working server found for this episode.');
  }

  String? _vcEp;
  Future<bool> _tryServer(ServerItem? s) async {
    final live = (_vc?.value.isInitialized ?? false) && _vcEp == _ep.id
        ? _vc!.value.position.inMilliseconds
        : null;
    if (live != null) {
      _saveProgress();
      _vc?.pause();
    }
    setState(() {
      _server = s;
      _status = 'Connecting to ${s?.name ?? 'server'}...';
    });
    try {
      final info = await CloverApi.instance.stream(_ep.id, server: s?.name, type: _type);
      final old = _vc;
      final c = VideoPlayerController.networkUrl(
        Uri.parse(info.url),
        formatHint: VideoFormat.hls,
        httpHeaders: {'Referer': info.referer, 'User-Agent': 'Mozilla/5.0 CloverAnime/3.0'},
      );
      await c.initialize().timeout(const Duration(seconds: 25));
      old?.removeListener(_onTick);
      await old?.dispose();
      _vc = c;
      _vcEp = _ep.id;
      _stream = info;
      c.addListener(_onTick);
      await c.setPlaybackSpeed(lib.playbackSpeed);
      final saved = live ?? lib.savedPosition(_ep.id);
      if (saved > 5000 && saved < c.value.duration.inMilliseconds - 15000) {
        await c.seekTo(Duration(milliseconds: saved));
      }
      await c.play();
      _sub = null;
      if (lib.subtitlesOn && info.subtitles.isNotEmpty) {
        final def = info.subtitles.firstWhere(
          (t) => t.isDefault || t.label.toLowerCase().contains('english'),
          orElse: () => info.subtitles.first,
        );
        _setSubtitle(def);
      }
      _saveTimer?.cancel();
      _saveTimer = Timer.periodic(const Duration(seconds: 8), (_) => _saveProgress());
      if (mounted) setState(() {});
      _scheduleHide();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _setSubtitle(Subtitle? s) async {
    setState(() => _sub = s);
    final c = _vc;
    if (c == null) return;
    if (s == null) {
      await c.setClosedCaptionFile(null);
      return;
    }
    await c.setClosedCaptionFile(() async {
      final r = await http.get(Uri.parse(s.url));
      return WebVTTCaptionFile(r.body);
    }());
  }

  void _onTick() {
    final c = _vc;
    if (c == null || !mounted) return;
    final v = c.value;
    final pos = v.position.inSeconds;
    final intro = _stream?.intro;
    if (lib.autoSkipIntro && intro != null && !_introSkipped && pos >= intro.start && pos < intro.end - 1) {
      _introSkipped = true;
      c.seekTo(Duration(seconds: intro.end));
    }
    if (v.isInitialized && !_ended && v.duration > Duration.zero && v.position >= v.duration - const Duration(milliseconds: 500)) {
      _ended = true;
      _saveProgress();
      if (_sleep.endOfEpisode) {
        _sleep.cancel();
        c.pause();
      } else if (lib.autoPlayNext && _hasNext) {
        _startNextCountdown();
      }
    }
    setState(() {});
  }

  void _startNextCountdown() {
    _nextCountdown = 5;
    _nextTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _nextCountdown = _nextCountdown! - 1);
      if (_nextCountdown! <= 0) {
        t.cancel();
        _goTo(_index + 1);
      }
    });
  }

  void _goTo(int i) {
    if (i < 0 || i >= widget.episodes.length) return;
    _saveProgress();
    _nextTimer?.cancel();
    _nextCountdown = null;
    _manualIntro = false;
    setState(() => _index = i);
    _loadEpisode();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_vc?.value.isPlaying ?? false)) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  void _seekBy(int seconds) {
    final c = _vc;
    if (c == null) return;
    HapticFeedback.selectionClick();
    final t = c.value.position + Duration(seconds: seconds);
    c.seekTo(t < Duration.zero ? Duration.zero : (t > c.value.duration ? c.value.duration : t));
    _flashTimer?.cancel();
    setState(() => _seekFlash = seconds > 0 ? 1 : -1);
    _flashTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _seekFlash = 0);
    });
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = _vc;
    final ready = c != null && c.value.isInitialized && _error == null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        if (ready)
          Center(
            child: _fill
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: c.value.size.width,
                        height: c.value.size.height,
                        child: VideoPlayer(c),
                      ),
                    ),
                  )
                : AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
          ),
        if (ready && _sub != null && c.value.caption.text.isNotEmpty)
          Positioned(
            left: 40,
            right: 40,
            bottom: _showControls ? 90 : 28,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  c.value.caption.text.replaceAll(RegExp(r'<[^>]*>'), ''),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        // Gesture layer
        Row(children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              onLongPressStart: _locked ? null : (_) => setState(() => _hold.start(_vc)),
              onLongPressEnd: (_) => setState(() => _hold.end(_vc)),
              onDoubleTap: _locked ? null : () => _seekBy(-10),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              onLongPressStart: _locked ? null : (_) => setState(() => _hold.start(_vc)),
              onLongPressEnd: (_) => setState(() => _hold.end(_vc)),
              onDoubleTap: _locked || c == null
                  ? null
                  : () => c.value.isPlaying ? c.pause() : c.play(),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              onLongPressStart: _locked ? null : (_) => setState(() => _hold.start(_vc)),
              onLongPressEnd: (_) => setState(() => _hold.end(_vc)),
              onDoubleTap: _locked ? null : () => _seekBy(10),
            ),
          ),
        ]),
        // Seek flash
        if (_seekFlash != 0)
          Align(
            alignment: _seekFlash < 0 ? const Alignment(-0.7, 0) : const Alignment(0.7, 0),
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_seekFlash < 0 ? Icons.fast_rewind_rounded : Icons.fast_forward_rounded,
                      color: Colors.white, size: 30),
                  const Text('10s', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        if (!ready) _loadingOrError(),
        if (ready && c.value.isBuffering)
          const Center(child: IgnorePointer(child: CircularProgressIndicator(color: AppColors.primary))),
        // Controls
        IgnorePointer(
          ignoring: !_showControls,
          child: AnimatedOpacity(
            opacity: _showControls ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: _locked ? _lockedOverlay() : _controls(ready ? c : null),
          ),
        ),
        HoldSpeedBadge(visible: _hold.active),
        if (ready) ..._skipButtons(c),
        if (_nextCountdown != null && _nextCountdown! > 0) _nextCard(),
      ]),
    );
  }

  Widget _loadingOrError() => Center(
        child: _error == null
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 14),
                Text(_status, style: const TextStyle(color: Colors.white70)),
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 40),
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 14),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  FilledButton(onPressed: _loadEpisode, child: const Text('Retry')),
                  const SizedBox(width: 10),
                  if (_servers.isNotEmpty)
                    OutlinedButton(onPressed: _serverSheet, child: const Text('Pick server')),
                  if (_servers.any((s) => s.type != _type)) ...[
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () {
                        _type = _type == 'sub' ? 'dub' : 'sub';
                        _loadEpisode();
                      },
                      child: Text('Try ${_type == 'sub' ? 'DUB' : 'SUB'}'),
                    ),
                  ],
                ]),
              ]),
      );

  Widget _lockedOverlay() => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: Colors.white24),
            icon: const Icon(Icons.lock_rounded, color: Colors.white),
            onPressed: () => setState(() => _locked = false),
          ),
        ),
      );

  Widget _controls(VideoPlayerController? c) {
    final pos = c?.value.position ?? Duration.zero;
    final dur = c?.value.duration ?? Duration.zero;
    final max = dur.inMilliseconds.toDouble().clamp(1, double.infinity).toDouble();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent, Colors.transparent, Colors.black87],
          stops: [0, 0.3, 0.65, 1],
        ),
      ),
      child: SafeArea(
        child: Column(children: [
          // Top bar
          Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.anime.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                Text(
                  'Episode ${_ep.number}${_server != null ? ' • ${_server!.name}' : ''} • ${_type.toUpperCase()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ]),
            ),
            _topBtn(Icons.dns_rounded, 'Server', _serverSheet),
            _topBtn(Icons.closed_caption_rounded, 'Subtitles', _subtitleSheet),
            IconButton(
              tooltip: 'Auto-play',
              icon: Icon(lib.autoPlayNext ? Icons.repeat_on_rounded : Icons.repeat_rounded,
                  color: lib.autoPlayNext ? AppColors.primary : Colors.white),
              onPressed: () {
                final v = !lib.autoPlayNext;
                lib.setAutoNext(v);
                if (!v) {
                  _nextTimer?.cancel();
                  _nextCountdown = null;
                }
                setState(() {});
                toast(context, v ? 'Auto-play ON' : 'Auto-play OFF');
              },
            ),
            _topBtn(Icons.playlist_play_rounded, 'Episodes', _episodeSheet),
            _topBtn(Icons.tune_rounded, 'Settings', _settingsSheet),
          ]),
          const Spacer(),
          // Center controls
          if (c != null)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _circleBtn(Icons.skip_previous_rounded, _hasPrev ? () => _goTo(_index - 1) : null, 26),
              const SizedBox(width: 28),
              _circleBtn(Icons.replay_10_rounded, () => _seekBy(-10), 30),
              const SizedBox(width: 28),
              _circleBtn(c.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, () {
                HapticFeedback.lightImpact();
                c.value.isPlaying ? c.pause() : c.play();
                _scheduleHide();
              }, 46, primary: true),
              const SizedBox(width: 28),
              _circleBtn(Icons.forward_10_rounded, () => _seekBy(10), 30),
              const SizedBox(width: 28),
              _circleBtn(Icons.skip_next_rounded, _hasNext ? () => _goTo(_index + 1) : null, 26),
            ]),
          const Spacer(),
          // Bottom bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text(_fmt(_seeking ? Duration(milliseconds: _seekValue.toInt()) : pos),
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppColors.primary,
                  ),
                  child: Slider(
                    min: 0,
                    max: max,
                    value: (_seeking ? _seekValue : pos.inMilliseconds.toDouble()).clamp(0, max),
                    onChangeStart: (v) {
                      _hideTimer?.cancel();
                      setState(() {
                        _seeking = true;
                        _seekValue = v;
                      });
                    },
                    onChanged: (v) => setState(() => _seekValue = v),
                    onChangeEnd: (v) {
                      c?.seekTo(Duration(milliseconds: v.toInt()));
                      setState(() => _seeking = false);
                      _scheduleHide();
                    },
                  ),
                ),
              ),
              Text(_fmt(dur), style: const TextStyle(color: Colors.white, fontSize: 12)),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Lock',
                icon: const Icon(Icons.lock_open_rounded, color: Colors.white),
                onPressed: () => setState(() => _locked = true),
              ),
              IconButton(
                tooltip: 'Fit',
                icon: Icon(_fill ? Icons.fit_screen_rounded : Icons.aspect_ratio_rounded, color: Colors.white),
                onPressed: () => setState(() => _fill = !_fill),
              ),
              TextButton(
                onPressed: _speedSheet,
                child: Text('${lib.playbackSpeed}x',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  List<Widget> _skipButtons(VideoPlayerController c) {
    final pos = c.value.position.inSeconds;
    final intro = _stream?.intro;
    final outro = _stream?.outro;
    final inIntro = intro != null && pos >= intro.start && pos < intro.end - 1;
    final inOutro = outro != null && pos >= outro.start && pos < outro.end - 1;
    if (!inIntro && !inOutro) {
      final dur = c.value.duration.inSeconds;
      if (intro == null && !_manualIntro && pos >= 3 && pos < 180 && dur > 600) {
        return [
          Positioned(
            right: 24,
            bottom: 90,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              onPressed: () {
                setState(() => _manualIntro = true);
                c.seekTo(c.value.position + const Duration(seconds: 85));
              },
              icon: const Icon(Icons.fast_forward_rounded),
              label: const Text('Skip Intro'),
            ),
          ),
        ];
      }
      if (_hasNext && _nextCountdown == null && dur > 300 && dur - pos <= 100 && dur - pos > 1) {
        return [
          Positioned(
            right: 24,
            bottom: 90,
            child: NextEpisodePill(accent: AppColors.primary, onTap: () => _goTo(_index + 1)),
          ),
        ];
      }
      return [];
    }
    return [
      Positioned(
        right: 24,
        bottom: 90,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
          onPressed: () {
            if (inOutro && _hasNext && lib.autoPlayNext) {
              _goTo(_index + 1);
            } else {
              c.seekTo(Duration(seconds: inIntro ? intro.end : outro!.end));
            }
          },
          icon: const Icon(Icons.fast_forward_rounded),
          label: Text(inIntro ? 'Skip Intro' : 'Skip Outro'),
        ),
      ),
    ];
  }

  Widget _nextCard() => Positioned(
        right: 24,
        bottom: 90,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Next episode in $_nextCountdown', style: const TextStyle(color: Colors.white)),
            const SizedBox(width: 10),
            FilledButton(onPressed: () => _goTo(_index + 1), child: const Text('Play now')),
            TextButton(
              onPressed: () {
                _nextTimer?.cancel();
                setState(() => _nextCountdown = null);
              },
              child: const Text('Cancel'),
            ),
          ]),
        ),
      );

  Widget _topBtn(IconData i, String tip, VoidCallback onTap) =>
      IconButton(tooltip: tip, icon: Icon(i, color: Colors.white), onPressed: onTap);

  Widget _circleBtn(IconData i, VoidCallback? onTap, double size, {bool primary = false}) => AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.35 : 1,
        child: Material(
          color: primary ? AppColors.primary : Colors.white12,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(primary ? 14 : 10),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Icon(i, key: ValueKey(i), size: size, color: primary ? Colors.black : Colors.white),
              ),
            ),
          ),
        ),
      );

  Future<T?> _sheet<T>(String title, List<Widget> children) {
    _hideTimer?.cancel();
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 520),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ]),
            ),
            Flexible(child: ListView(shrinkWrap: true, children: children)),
          ]),
        ),
      ),
    );
  }

  void _serverSheet() {
    final types = _servers.map((s) => s.type).toSet().toList();
    _sheet('Servers', [
      for (final t in types) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(t.toUpperCase(),
              style: const TextStyle(color: AppColors.textDim, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
        ..._servers.where((s) => s.type == t).map((s) {
          final sel = _server?.name == s.name && _type == s.type;
          return ListTile(
            leading: Icon(sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: sel ? AppColors.primary : AppColors.textDim),
            title: Text(s.name),
            onTap: () async {
              Navigator.pop(context);
              _type = s.type;
              lib.setPrefType(s.type);
              setState(() {
                _error = null;
                _vc?.pause();
              });
              final ok = await _tryServer(s);
              if (!ok && mounted) setState(() => _error = '${s.name} is not working. Try another server.');
            },
          );
        }),
      ],
      if (_servers.isEmpty) const ListTile(title: Text('No servers listed')),
    ]);
  }

  void _subtitleSheet() {
    final subs = _stream?.subtitles ?? [];
    _sheet('Subtitles', [
      ListTile(
        leading: Icon(_sub == null ? Icons.check_rounded : null, color: AppColors.primary),
        title: const Text('Off'),
        onTap: () {
          Navigator.pop(context);
          lib.setSubs(false);
          _setSubtitle(null);
        },
      ),
      ...subs.map((s) => ListTile(
            leading: Icon(_sub?.url == s.url ? Icons.check_rounded : null, color: AppColors.primary),
            title: Text(s.label),
            onTap: () {
              Navigator.pop(context);
              lib.setSubs(true);
              _setSubtitle(s);
            },
          )),
      if (subs.isEmpty)
        const ListTile(
          title: Text('No subtitle files on this server', style: TextStyle(color: AppColors.textDim)),
          subtitle: Text('Subtitles may already be shown inside the video.'),
        ),
    ]);
  }

  void _speedSheet() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    _sheet('Playback speed', speeds
        .map((s) => ListTile(
              leading: Icon(lib.playbackSpeed == s ? Icons.check_rounded : null, color: AppColors.primary),
              title: Text(s == 1.0 ? 'Normal' : '${s}x'),
              onTap: () {
                Navigator.pop(context);
                lib.setSpeed(s);
                _vc?.setPlaybackSpeed(s);
                setState(() {});
              },
            ))
        .toList());
  }

  void _settingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      constraints: const BoxConstraints(maxWidth: 520),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => ListenableBuilder(
        listenable: lib,
        builder: (_, __) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Player settings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            SwitchListTile(
              activeTrackColor: AppColors.primary,
              title: const Text('Auto-play next episode'),
              value: lib.autoPlayNext,
              onChanged: lib.setAutoNext,
            ),
            SwitchListTile(
              activeTrackColor: AppColors.primary,
              title: const Text('Auto-skip intro'),
              value: lib.autoSkipIntro,
              onChanged: lib.setAutoSkip,
            ),
            SwitchListTile(
              activeTrackColor: AppColors.primary,
              title: const Text('Prefer dubbed audio'),
              value: lib.preferredType == 'dub',
              onChanged: (v) => lib.setPrefType(v ? 'dub' : 'sub'),
            ),
            ListTile(
              leading: const Icon(Icons.bedtime_rounded, color: AppColors.primary),
              title: const Text('Sleep timer'),
              trailing: Text(_sleep.label, style: const TextStyle(color: AppColors.textDim)),
              onTap: () async {
                Navigator.pop(ctx);
                final m = await pickSleep(context, _sleep, AppColors.primary);
                if (m == null || !mounted) return;
                setState(() => _sleep.set(m == 0 ? null : m, () {
                      _vc?.pause();
                      if (mounted) setState(() {});
                    }));
                toast(context, m == 0 ? 'Sleep timer off' : 'Sleep timer: ${_sleep.label}');
              },
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Tip: hold anywhere on the video for 2x speed, double-tap sides to skip 10s.',
                  style: TextStyle(color: AppColors.textDim, fontSize: 12)),
            ),
          ]),
        ),
      ),
    );
  }

  void _episodeSheet() {
    _sheet('Episodes', [
      for (var i = 0; i < widget.episodes.length; i++)
        ListTile(
          selected: i == _index,
          selectedColor: AppColors.primary,
          leading: Icon(
            i == _index
                ? Icons.equalizer_rounded
                : (lib.watched.contains(widget.episodes[i].id)
                    ? Icons.check_circle_rounded
                    : Icons.play_circle_outline_rounded),
            color: i == _index || lib.watched.contains(widget.episodes[i].id) ? AppColors.primary : AppColors.textDim,
          ),
          title: Text('Episode ${widget.episodes[i].number}'),
          subtitle: Text(widget.episodes[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: widget.episodes[i].filler
              ? const Text('Filler', style: TextStyle(color: AppColors.accent, fontSize: 12))
              : null,
          onTap: () {
            Navigator.pop(context);
            _goTo(i);
          },
        ),
    ]);
  }
}
