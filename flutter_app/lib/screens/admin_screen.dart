import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/auth_service.dart';
import '../data/clover_api.dart';
import '../data/models.dart';
import '../widgets/common.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});
  @override
  Widget build(BuildContext context) {
    if (!AuthService.instance.isAdmin) {
      return const Scaffold(body: EmptyState(icon: Icons.block_rounded, title: 'Admins only'));
    }
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin panel'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.accent,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textDim,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(icon: Icon(Icons.campaign_rounded), text: 'Announce'),
              Tab(icon: Icon(Icons.send_rounded), text: 'Broadcasts'),
              Tab(icon: Icon(Icons.people_alt_rounded), text: 'Users'),
              Tab(icon: Icon(Icons.system_update_rounded), text: 'Update'),
              Tab(icon: Icon(Icons.settings_ethernet_rounded), text: 'Server'),
            ],
          ),
        ),
        body: const TabBarView(children: [
          _AnnouncementTab(),
          _BroadcastTab(),
          _UsersTab(),
          _UpdateTab(),
          _ServerTab(),
        ]),
      ),
    );
  }
}

const _types = ['info', 'warning', 'urgent', 'maintenance'];

Widget _field(TextEditingController c, String label, {int lines = 1, TextInputType? kb}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: lines,
        keyboardType: kb,
        decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
      ),
    );

Widget _typePicker(String value, ValueChanged<String> onChanged) => Wrap(
      spacing: 8,
      children: _types
          .map((t) => ChoiceChip(
                label: Text(t),
                selected: value == t,
                showCheckmark: false,
                selectedColor: AppColors.accent,
                labelStyle: TextStyle(color: value == t ? Colors.black : AppColors.text),
                onSelected: (_) => onChanged(t),
              ))
          .toList(),
    );

class _AnnouncementTab extends StatefulWidget {
  const _AnnouncementTab();
  @override
  State<_AnnouncementTab> createState() => _AnnouncementTabState();
}

class _AnnouncementTabState extends State<_AnnouncementTab> {
  final a = AuthService.instance.announcement;
  late final _title = TextEditingController(text: a?.title);
  late final _msg = TextEditingController(text: a?.message);
  late final _url = TextEditingController(text: a?.actionUrl);
  late final _btn = TextEditingController(text: a?.actionText);
  late bool _on = a?.active ?? false;
  late String _type = a?.type ?? 'info';
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await AuthService.instance.saveAnnouncement({
        'title': _title.text.trim(),
        'message': _msg.text.trim(),
        'actionUrl': _url.text.trim(),
        'actionText': _btn.text.trim(),
        'type': _type,
        'enabled': _on,
        'isEnabled': _on,
        'displayMode': 'banner',
      });
      toast(context, 'Announcement saved');
    } catch (e) {
      toast(context, 'Save failed: $e');
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeTrackColor: AppColors.accent,
          title: const Text('Show banner on home'),
          value: _on,
          onChanged: (v) => setState(() => _on = v),
        ),
        _field(_title, 'Title'),
        _field(_msg, 'Message', lines: 4),
        _field(_btn, 'Button text (optional)'),
        _field(_url, 'Button link (optional)', kb: TextInputType.url),
        _typePicker(_type, (t) => setState(() => _type = t)),
        const SizedBox(height: 18),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Save announcement')),
      ]);
}

class _BroadcastTab extends StatefulWidget {
  const _BroadcastTab();
  @override
  State<_BroadcastTab> createState() => _BroadcastTabState();
}

class _BroadcastTabState extends State<_BroadcastTab> {
  final _title = TextEditingController();
  final _msg = TextEditingController();
  String _type = 'info';
  bool _banner = true;
  bool _busy = false;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        _field(_title, 'Title'),
        _field(_msg, 'Message', lines: 3),
        _typePicker(_type, (t) => setState(() => _type = t)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeTrackColor: AppColors.accent,
          title: const Text('Also show as home banner'),
          value: _banner,
          onChanged: (v) => setState(() => _banner = v),
        ),
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  if (_title.text.trim().isEmpty) return toast(context, 'Add a title');
                  setState(() => _busy = true);
                  try {
                    await AuthService.instance
                        .publishBroadcast(_title.text.trim(), _msg.text.trim(), _type, _banner);
                    _title.clear();
                    _msg.clear();
                    toast(context, 'Broadcast published');
                  } catch (e) {
                    toast(context, 'Failed: $e');
                  }
                  setState(() => _busy = false);
                },
          icon: const Icon(Icons.send_rounded),
          label: const Text('Publish'),
        ),
        const SizedBox(height: 20),
        const Text('History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        StreamBuilder<List<Broadcast>>(
          stream: AuthService.instance.broadcasts(),
          builder: (_, s) {
            final list = s.data ?? [];
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No broadcasts yet', style: TextStyle(color: AppColors.textDim)),
              );
            }
            return Column(
              children: list
                  .map((b) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(b.title),
                        subtitle: Text(
                          '${b.message}\n${DateTime.fromMillisecondsSinceEpoch(b.createdAt).toString().substring(0, 16)} • ${b.createdBy}',
                          style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                          onPressed: () => AuthService.instance.deleteBroadcast(b.id),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ]);
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _q = '';
  final _newAdmin = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    return ListenableBuilder(
      listenable: auth,
      builder: (_, __) => StreamBuilder<List<UserProfile>>(
        stream: auth.users(),
        builder: (_, s) {
          final all = s.data ?? [];
          final users = all.where((u) => u.email.toLowerCase().contains(_q.toLowerCase())).toList();
          final weekAgo = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
          final active = all.where((u) => u.lastLoginAt > weekAgo).length;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              _stat('${all.length}', 'Users'),
              const SizedBox(width: 10),
              _stat('$active', 'Active 7d'),
              const SizedBox(width: 10),
              _stat('${auth.adminEmails.length}', 'Admins'),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _newAdmin,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'Add admin by email'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.accent),
                icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.black),
                onPressed: () async {
                  final e = _newAdmin.text.trim().toLowerCase();
                  if (!e.contains('@')) return;
                  await auth.saveAdmins({...auth.adminEmails, e});
                  _newAdmin.clear();
                  toast(context, '$e is now an admin');
                },
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(hintText: 'Search users', prefixIcon: Icon(Icons.search_rounded)),
            ),
            const SizedBox(height: 8),
            ...users.map((u) {
              final isAdmin = auth.adminEmails.contains(u.email.toLowerCase());
              final builtIn = AuthService.defaultAdmins.contains(u.email.toLowerCase());
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: isAdmin ? AppColors.accent : AppColors.surfaceHi,
                  child: Text(u.email.isEmpty ? '?' : u.email[0].toUpperCase(),
                      style: TextStyle(color: isAdmin ? Colors.black : AppColors.text)),
                ),
                title: Text(u.email, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  u.lastLoginAt == 0
                      ? 'Never signed in'
                      : 'Last seen ${DateTime.fromMillisecondsSinceEpoch(u.lastLoginAt).toString().substring(0, 16)}',
                  style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                ),
                trailing: builtIn
                    ? const Badge2('OWNER', color: AppColors.accent)
                    : TextButton(
                        onPressed: () async {
                          final next = {...auth.adminEmails};
                          isAdmin ? next.remove(u.email.toLowerCase()) : next.add(u.email.toLowerCase());
                          await auth.saveAdmins(next);
                          await auth.setRole(u.uid, isAdmin ? 'user' : 'admin');
                        },
                        child: Text(isAdmin ? 'Remove admin' : 'Make admin',
                            style: TextStyle(color: isAdmin ? AppColors.danger : AppColors.accent)),
                      ),
              );
            }),
          ]);
        },
      ),
    );
  }

  Widget _stat(String v, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.accent)),
            Text(l, style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
          ]),
        ),
      );
}

class _UpdateTab extends StatefulWidget {
  const _UpdateTab();
  @override
  State<_UpdateTab> createState() => _UpdateTabState();
}

class _UpdateTabState extends State<_UpdateTab> {
  final u = AuthService.instance.update;
  late final _code = TextEditingController(text: '${u?.latestVersionCode ?? 9}');
  late final _name = TextEditingController(text: u?.latestVersionName ?? '3.0.0');
  late final _title = TextEditingController(text: u?.title ?? 'New Clover Anime Update');
  late final _log = TextEditingController(text: u?.changelog);
  late final _url = TextEditingController(text: u?.downloadUrl);
  late bool _force = u?.forceUpdate ?? false;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Users on an older version will see an update popup.',
            style: TextStyle(color: AppColors.textDim)),
        const SizedBox(height: 12),
        _field(_code, 'Latest version number (e.g. 9)', kb: TextInputType.number),
        _field(_name, 'Version name (e.g. 3.0.0)'),
        _field(_title, 'Popup title'),
        _field(_log, "What's new", lines: 4),
        _field(_url, 'Download link', kb: TextInputType.url),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeTrackColor: AppColors.accent,
          title: const Text('Force update'),
          subtitle: const Text('Users cannot close the popup'),
          value: _force,
          onChanged: (v) => setState(() => _force = v),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            try {
              await AuthService.instance.saveUpdate({
                'latestVersionCode': int.tryParse(_code.text.trim()) ?? 1,
                'latestVersionName': _name.text.trim(),
                'title': _title.text.trim(),
                'changelog': _log.text.trim(),
                'downloadUrl': _url.text.trim(),
                'forceUpdate': _force,
              });
              toast(context, 'Update settings saved');
            } catch (e) {
              toast(context, 'Failed: $e');
            }
          },
          child: const Text('Save update settings'),
        ),
      ]);
}

class _ServerTab extends StatefulWidget {
  const _ServerTab();
  @override
  State<_ServerTab> createState() => _ServerTabState();
}

class _ServerTabState extends State<_ServerTab> {
  late final _url = TextEditingController(text: CloverApi.instance.baseUrl);
  bool _active = true;
  String? _test;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Change where every app gets anime episodes from.', style: TextStyle(color: AppColors.textDim)),
        const SizedBox(height: 12),
        _field(_url, 'Streaming server address', kb: TextInputType.url),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeTrackColor: AppColors.accent,
          title: const Text('Use this address'),
          value: _active,
          onChanged: (v) => setState(() => _active = v),
        ),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                setState(() => _test = 'Testing...');
                final old = CloverApi.instance.baseUrl;
                CloverApi.instance.setBaseUrl(_url.text);
                try {
                  final r = await CloverApi.instance.search('naruto ${DateTime.now().millisecond}');
                  setState(() => _test = 'Working • ${r.length} results');
                } catch (e) {
                  setState(() => _test = 'Not working: $e');
                }
                CloverApi.instance.setBaseUrl(old);
              },
              child: const Text('Test'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () async {
                try {
                  await AuthService.instance.saveApi(_url.text.trim(), _active);
                  toast(context, 'Server saved for all users');
                } catch (e) {
                  toast(context, 'Failed: $e');
                }
              },
              child: const Text('Save'),
            ),
          ),
        ]),
        if (_test != null)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text(_test!)),
      ]);
}
