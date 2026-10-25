import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../core/theme.dart';

/// Badge shown while the user holds the screen to watch at 2x.
class HoldSpeedBadge extends StatelessWidget {
  final bool visible;
  const HoldSpeedBadge({super.key, required this.visible});
  @override
  Widget build(BuildContext context) => Align(
        alignment: const Alignment(0, -0.78),
        child: IgnorePointer(
          child: AnimatedScale(
            scale: visible ? 1 : 0.8,
            duration: const Duration(milliseconds: 200),
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(30)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('2x', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  SizedBox(width: 4),
                  Icon(Icons.fast_forward_rounded, color: Colors.white, size: 18),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Hold-for-2x behaviour shared by both players.
class HoldSpeed {
  bool active = false;
  double _before = 1;

  void start(VideoPlayerController? c) {
    if (c == null || !c.value.isInitialized || active) return;
    HapticFeedback.mediumImpact();
    _before = c.value.playbackSpeed;
    active = true;
    c.setPlaybackSpeed(2);
    if (!c.value.isPlaying) c.play();
  }

  void end(VideoPlayerController? c) {
    if (!active) return;
    active = false;
    c?.setPlaybackSpeed(_before);
  }
}

/// Sleep timer: minutes, or -1 for "end of episode".
class SleepTimer {
  Timer? _t;
  int? minutes;
  DateTime? endsAt;
  bool get endOfEpisode => minutes == -1;
  bool get on => minutes != null;

  void set(int? m, VoidCallback fire) {
    _t?.cancel();
    minutes = m;
    endsAt = null;
    if (m != null && m > 0) {
      endsAt = DateTime.now().add(Duration(minutes: m));
      _t = Timer(Duration(minutes: m), () {
        minutes = null;
        fire();
      });
    }
  }

  void cancel() {
    _t?.cancel();
    minutes = null;
  }

  String get label {
    if (minutes == null) return 'Off';
    if (endOfEpisode) return 'End of episode';
    final left = endsAt!.difference(DateTime.now());
    return '${left.inMinutes + 1} min left';
  }
}

Future<int?> pickSleep(BuildContext context, SleepTimer t, Color accent) => showModalBottomSheet<int?>(
      context: context,
      backgroundColor: AppColors.surface,
      constraints: const BoxConstraints(maxWidth: 520),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sleep timer', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            for (final o in const [(0, 'Off'), (15, '15 minutes'), (30, '30 minutes'), (45, '45 minutes'), (60, '1 hour'), (-1, 'End of this episode')])
              ListTile(
                leading: Icon(
                  (o.$1 == 0 ? !t.on : t.minutes == o.$1) ? Icons.check_rounded : Icons.bedtime_outlined,
                  color: accent,
                ),
                title: Text(o.$2),
                onTap: () => Navigator.pop(ctx, o.$1),
              ),
          ]),
        ),
      ),
    );

/// "Next episode" pill shown near the end of an episode.
class NextEpisodePill extends StatelessWidget {
  final VoidCallback onTap;
  final Color accent;
  const NextEpisodePill({super.key, required this.onTap, required this.accent});
  @override
  Widget build(BuildContext context) => FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
        onPressed: onTap,
        icon: const Icon(Icons.skip_next_rounded),
        label: const Text('Next Episode', style: TextStyle(fontWeight: FontWeight.w800)),
      );
}

/// Countdown card before auto-playing the next episode.
class UpNextCard extends StatelessWidget {
  final int seconds;
  final String title;
  final VoidCallback onPlay;
  final VoidCallback onCancel;
  final Color accent;
  const UpNextCard({
    super.key,
    required this.seconds,
    required this.title,
    required this.onPlay,
    required this.onCancel,
    required this.accent,
  });
  @override
  Widget build(BuildContext context) => Container(
        width: 300,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Up next in $seconds', style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            key: ValueKey(title),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(seconds: 6),
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              color: accent,
              backgroundColor: Colors.white12,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
                onPressed: onPlay,
                child: const Text('Play now'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
          ]),
        ]),
      );
}
