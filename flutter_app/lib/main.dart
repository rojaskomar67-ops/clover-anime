import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/theme.dart';
import 'data/auth_service.dart';
import 'data/library.dart';
import 'data/notifications.dart';
import 'data/hindi_api.dart';
import 'screens/discover_screen.dart';
import 'screens/hindi_screens.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'screens/watchlist_screen.dart';

const firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyDuCylRtbGlj4sLkpLlsQ_zDIAQyAQ2jro',
  appId: '1:675652283050:android:062fc092cee5fe5f733ed3',
  messagingSenderId: '675652283050',
  projectId: 'clovranimme',
  storageBucket: 'clovranimme.firebasestorage.app',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg,
  ));
  await Library.instance.init();
  await ModeController.instance.init();
  await Notifier.instance.init();
  try {
    await Firebase.initializeApp(options: firebaseOptions);
    AuthService.instance.firebaseReady = true;
    AuthService.instance.start();
  } catch (_) {
    // The app still works for browsing and watching without accounts.
  }
  runApp(const CloverApp());
}

class CloverApp extends StatelessWidget {
  const CloverApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Clover Anime',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const SplashGate(),
      );
}

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _done = false;
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: _done ? const RootShell() : const _Splash(),
      );
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ShaderMask(
                shaderCallback: (r) => AppColors.primaryGradient.createShader(r),
                child: const Icon(Icons.eco_rounded, size: 84, color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text('CLOVER ANIME',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4)),
            ]),
          ),
        ),
      );
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  bool _updateShown = false;
  static const _defaultPages = [HomeScreen(), DiscoverScreen(), SearchScreen(), WatchlistScreen(), ProfileScreen()];
  static const _hindiPages = [HindiHomeScreen(), DiscoverScreen(), HindiSearchScreen(), WatchlistScreen(), ProfileScreen()];

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_checkUpdate);
    _checkUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askNotifications());
  }

  Future<void> _askNotifications() async {
    final p = await SharedPreferences.getInstance();
    if (p.getBool('askedNotifs') == true || !mounted) return;
    await p.setBool('askedNotifs', true);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 40),
        title: const Text('Stay in the loop'),
        content: const Text('Allow notifications to hear about new episodes, updates and announcements.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Allow')),
        ],
      ),
    );
    if (yes == true) {
      await Notifier.instance.requestPermission();
    } else {
      await Notifier.instance.setEnabled(false);
    }
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_checkUpdate);
    super.dispose();
  }

  Future<void> _checkUpdate() async {
    final u = AuthService.instance.update;
    if (u == null || _updateShown) return;
    final info = await PackageInfo.fromPlatform();
    final current = int.tryParse(info.buildNumber) ?? 0;
    if (u.latestVersionCode <= current || !mounted) return;
    _updateShown = true;
    showDialog(
      context: context,
      barrierDismissible: !u.forceUpdate,
      builder: (ctx) => PopScope(
        canPop: !u.forceUpdate,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          icon: const Icon(Icons.system_update_rounded, color: AppColors.primary, size: 40),
          title: Text(u.title),
          content: Text('Version ${u.latestVersionName}\n\n${u.changelog}'),
          actions: [
            if (!u.forceUpdate)
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
            FilledButton(
              onPressed: () => launchUrl(Uri.parse(u.downloadUrl), mode: LaunchMode.externalApplication),
              child: const Text('Update now'),
            ),
          ],
        ),
      ),
    );
  }

  static const _dests = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.explore_outlined, Icons.explore_rounded, 'Discover'),
    (Icons.search_rounded, Icons.search_rounded, 'Search'),
    (Icons.bookmark_outline_rounded, Icons.bookmark_rounded, 'My List'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  void _select(int i) {
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AuthService.instance, ModeController.instance]),
      builder: (context, _) {
        final hindi = ModeController.instance.value;
        final auth = AuthService.instance;
        if (auth.features.maintenance && !auth.isAdmin) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.construction_rounded, size: 64, color: AppColors.accent),
                  const SizedBox(height: 16),
                  const Text('Under maintenance', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(auth.features.maintenanceMessage,
                      textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textDim)),
                ]),
              ),
            ),
          );
        }
        final wide = MediaQuery.of(context).size.width >= 720;
        final pages = hindi ? _hindiPages : _defaultPages;
        final body = Stack(children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(a), child: child),
            ),
            child: IndexedStack(key: ValueKey(hindi), index: _index, children: pages),
          ),
          if (_index == 0 || _index == 2)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 0,
              right: 0,
              child: const Center(child: ModeSwitch()),
            ),
        ]);
        if (wide) {
          return Scaffold(
            body: Row(children: [
              NavigationRail(
                backgroundColor: AppColors.surface,
                selectedIndex: _index,
                onDestinationSelected: _select,
                labelType: NavigationRailLabelType.all,
                indicatorColor: AppColors.primary.withValues(alpha: 0.18),
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: ShaderMask(
                    shaderCallback: (r) => AppColors.primaryGradient.createShader(r),
                    child: const Icon(Icons.eco_rounded, size: 34, color: Colors.white),
                  ),
                ),
                destinations: [
                  for (final d in _dests)
                    NavigationRailDestination(
                      icon: Icon(d.$1),
                      selectedIcon: Icon(d.$2, color: AppColors.primary),
                      label: Text(d.$3),
                    ),
                ],
              ),
              const VerticalDivider(width: 1, color: AppColors.border),
              Expanded(child: body),
            ]),
          );
        }
        return Scaffold(
          extendBody: true,
          body: body,
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: NavigationBar(
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.primary.withValues(alpha: 0.18),
              height: 66,
              selectedIndex: _index,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: _select,
              destinations: [
                for (final d in _dests)
                  NavigationDestination(
                    icon: Icon(d.$1),
                    selectedIcon: Icon(d.$2, color: AppColors.primary),
                    label: d.$3,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
