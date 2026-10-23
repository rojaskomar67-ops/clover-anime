import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/theme.dart';
import '../data/auth_service.dart';
import '../data/library.dart';
import '../data/notifications.dart';
import '../widgets/common.dart';
import 'admin_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final lib = Library.instance;
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([auth, lib]),
        builder: (context, _) {
          final u = auth.user;
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            children: [
              const Text('Profile', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(colors: [
                    AppColors.primary.withValues(alpha: 0.25),
                    AppColors.surface,
                  ]),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      (u?.email ?? 'G').substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(u == null ? 'Guest' : (u.email ?? '').split('@').first,
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                      Text(u?.email ?? 'Sign in to unlock your profile',
                          style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
                      if (auth.isAdmin) ...[
                        const SizedBox(height: 6),
                        const Badge2('ADMIN', color: AppColors.accent, icon: Icons.shield_rounded),
                      ],
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Row(children: [
                _stat('${lib.watchlist.length}', 'Saved'),
                const SizedBox(width: 10),
                _stat('${lib.history.length}', 'Watching'),
                const SizedBox(width: 10),
                _stat('${lib.watched.length}', 'Episodes'),
              ]),
              const SizedBox(height: 14),
              if (u == null)
                FilledButton.icon(
                  onPressed: () => showSignIn(context),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign in / Create account'),
                ),
              if (auth.isAdmin) ...[
                const SizedBox(height: 4),
                _tile(Icons.admin_panel_settings_rounded, 'Admin panel', 'Manage app, users and announcements',
                    () => Navigator.of(context).push(fadeRoute(const AdminScreen())),
                    color: AppColors.accent),
              ],
              const SizedBox(height: 10),
              const Text('Player', style: TextStyle(color: AppColors.textDim, fontWeight: FontWeight.w700)),
              _switch('Auto-play next episode', lib.autoPlayNext, lib.setAutoNext),
              _switch('Auto-skip intro', lib.autoSkipIntro, lib.setAutoSkip),
              _switch('Subtitles on by default', lib.subtitlesOn, lib.setSubs),
              _switch('Prefer dubbed audio', lib.preferredType == 'dub', (v) => lib.setPrefType(v ? 'dub' : 'sub')),
              _NotifSwitch(),
              const SizedBox(height: 10),
              const Text('Data', style: TextStyle(color: AppColors.textDim, fontWeight: FontWeight.w700)),
              _tile(Icons.history_toggle_off_rounded, 'Clear watch history', null, () {
                lib.clearHistory();
                toast(context, 'History cleared');
              }),
              _tile(Icons.manage_search_rounded, 'Clear recent searches', null, () {
                lib.clearSearches();
                toast(context, 'Searches cleared');
              }),
              if (u != null)
                _tile(Icons.logout_rounded, 'Sign out', null, () => auth.signOut(), color: AppColors.danger),
              const SizedBox(height: 18),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (_, s) => Center(
                  child: Text(
                    s.hasData ? 'Clover Anime v${s.data!.version} (${s.data!.buildNumber})' : '',
                    style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String v, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: [
            Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary)),
            Text(l, style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
          ]),
        ),
      );

  Widget _switch(String t, bool v, ValueChanged<bool> f) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeTrackColor: AppColors.primary,
        title: Text(t),
        value: v,
        onChanged: f,
      );

  Widget _tile(IconData i, String t, String? s, VoidCallback onTap, {Color color = AppColors.text}) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(i, color: color),
        title: Text(t, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        subtitle: s == null ? null : Text(s, style: const TextStyle(color: AppColors.textDim)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
        onTap: onTap,
      );
}

Future<void> showSignIn(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _SignInSheet(),
    );

class _SignInSheet extends StatefulWidget {
  const _SignInSheet();
  @override
  State<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<_SignInSheet> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await AuthService.instance.signIn(_email.text, _pass.text);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
      toast(context, 'Welcome to Clover!');
    } else {
      setState(() {
        _error = err;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Sign in', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const Text('New here? We create your account automatically.',
              style: TextStyle(color: AppColors.textDim)),
          const SizedBox(height: 18),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: _hide,
            onSubmitted: (_) => _go(),
            decoration: InputDecoration(
              hintText: 'Password (6+ characters)',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _error == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _go,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Continue'),
          ),
        ]),
      );
}

class _NotifSwitch extends StatefulWidget {
  @override
  State<_NotifSwitch> createState() => _NotifSwitchState();
}

class _NotifSwitchState extends State<_NotifSwitch> {
  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeTrackColor: AppColors.primary,
        title: const Text('Notifications'),
        subtitle: const Text('New episodes, updates and announcements', style: TextStyle(color: AppColors.textDim)),
        value: Notifier.instance.enabled,
        onChanged: (v) async {
          await Notifier.instance.setEnabled(v);
          setState(() {});
        },
      );
}
