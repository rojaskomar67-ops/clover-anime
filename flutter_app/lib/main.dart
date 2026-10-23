import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/theme.dart';
import 'data/auth_service.dart';
import 'data/library.dart';
import 'screens/discover_screen.dart';
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
  final _pages = const [HomeScreen(), DiscoverScreen(), SearchScreen(), WatchlistScreen(), ProfileScreen()];

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_checkUpdate);
    _checkUpdate();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _pages),
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
          onDestinationSelected: (i) {
            HapticFeedback.selectionClick();
            setState(() => _index = i);
          },
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
                label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded, color: AppColors.primary),
                label: 'Discover'),
            NavigationDestination(
                icon: Icon(Icons.search_rounded),
                selectedIcon: Icon(Icons.search_rounded, color: AppColors.primary),
                label: 'Search'),
            NavigationDestination(
                icon: Icon(Icons.bookmark_outline_rounded),
                selectedIcon: Icon(Icons.bookmark_rounded, color: AppColors.primary),
                label: 'My List'),
            NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
                label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
