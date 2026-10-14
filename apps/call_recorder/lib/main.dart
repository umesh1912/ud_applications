import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ud_core/ud_core.dart';

import 'player.dart';
import 'recorder.dart';
import 'service.dart';
import 'store.dart';
import 'strings.dart';

const appName = 'Baatcheet';

void main() {
  FlutterForegroundTask.initCommunicationPort();
  runUdApp(UdAppSpec(
    name: appName,
    taglineKey: 'tagline',
    accent: const Color(0xFF1F7A55),
    icon: Icons.phone_in_talk_outlined,
    strings: baatStrings,
    home: (_) => const BaatGate(),
  ));
}

class BaatGate extends StatefulWidget {
  const BaatGate({super.key});

  @override
  State<BaatGate> createState() => _BaatGateState();
}

class _BaatGateState extends State<BaatGate> {
  RecStore? _store;

  @override
  void initState() {
    super.initState();
    CallService.init();
    RecStore.open().then((s) async {
      await FlutterForegroundTask.saveData(key: K.dir, value: s.dir);
      if (mounted) setState(() => _store = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (store == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return HomePage(store: store);
  }
}

enum Filter { all, calls, voice, starred }

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});
  final RecStore store;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool _watching = false;
  bool _batteryOk = true;
  Filter _filter = Filter.all;
  String _query = '';

  RecStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _onTaskData(Object data) => store.reload();

  Future<void> _refresh() async {
    final watching = await CallService.running;
    final battery = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    await store.reload();
    if (mounted) {
      setState(() {
        _watching = watching;
        _batteryOk = battery;
      });
    }
  }

  /// Passes the texts the service shows, in the current language.
  Future<void> _saveTexts() async {
    for (final e in {
      K.tReady: 'n_ready',
      K.tRecording: 'n_recording',
      K.tIn: 'incoming_call',
      K.tOut: 'outgoing_call',
    }.entries) {
      await FlutterForegroundTask.saveData(key: e.key, value: context.tr(e.value));
    }
  }

  Future<void> _toggleWatch() async {
    if (_watching) {
      await CallService.stop();
      await _refresh();
      return;
    }
    if (!await _askPermissions() || !mounted) return;
    await _saveTexts();
    if (!mounted) return;
    final ok = await CallService.start(
      title: appName,
      text: context.tr('n_ready'),
      stop: context.tr('stop'),
    );
    if (!ok && mounted) udToast(context, context.tr('error_generic'));
    await _refresh();
  }

  Future<bool> _askPermissions() async {
    final results = await [
      Permission.microphone,
      Permission.phone,
      Permission.notification,
    ].request();
    final mic = results[Permission.microphone]?.isGranted ?? false;
    final phone = results[Permission.phone]?.isGranted ?? false;
    if (mic && phone) return true;
    if (!mounted) return false;
    final open = await udConfirm(context,
        title: context.tr('perm_title'),
        body: context.tr('perm_body'),
        confirmLabel: context.tr('open_settings'),
        danger: false);
    if (open) await openAppSettings();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final q = _query.toLowerCase();
        final items = store.items.where((r) {
          final pass = switch (_filter) {
            Filter.all => true,
            Filter.calls => r.isCall,
            Filter.voice => !r.isCall,
            Filter.starred => r.starred,
          };
          return pass &&
              (q.isEmpty ||
                  '${r.name} ${r.number ?? ''} ${r.note}'.toLowerCase().contains(q));
        }).toList();
        return UdPage(
          eyebrow: appName,
          title: context.tr('home_title'),
          subtitle: context.tr('home_sub',
              {'n': '${store.items.length}', 'size': udFormatBytes(store.totalBytes)}),
          actions: [
            UdIconButton(
              icon: Icons.settings_voice_outlined,
              tooltip: context.tr('rec_settings'),
              onTap: () => showUdSheet<void>(context, (_) => const RecSettings()),
            ),
            const UdSettingsButton(appName: appName),
          ],
          dock: UdDock(
            label: context.tr('record_now'),
            icon: Icons.mic_rounded,
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RecorderPage(store: store),
              ));
              await store.reload();
            },
          ),
          slivers: [
            UdSliverPad(
              bottom: 12,
              sliver: SliverToBoxAdapter(
                child: _WatchCard(watching: _watching, onToggle: _toggleWatch),
              ),
            ),
            if (_watching && !_batteryOk)
              UdSliverPad(
                bottom: 12,
                sliver: SliverToBoxAdapter(
                  child: _HintCard(
                    icon: Icons.battery_alert_outlined,
                    title: context.tr('battery_title'),
                    body: context.tr('battery_body'),
                    onTap: () async {
                      await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
                    },
                  ),
                ),
              ),
            UdSliverPad(
              bottom: 12,
              sliver: SliverToBoxAdapter(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: udInputDecoration(context,
                      hint: context.tr('search_hint'), icon: Icons.search_rounded),
                ),
              ),
            ),
            UdSliverPad(
              bottom: 12,
              sliver: SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in Filter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: context.tr('f_${f.name}'),
                            selected: f == _filter,
                            onTap: () => setState(() => _filter = f),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (items.isEmpty)
              SliverToBoxAdapter(
                child: UdEmpty(
                  icon: store.items.isEmpty ? Icons.graphic_eq_rounded : Icons.search_off_rounded,
                  title: context.tr(store.items.isEmpty ? 'empty' : 'no_results'),
                  body: store.items.isEmpty ? context.tr('empty_body') : null,
                ),
              )
            else
              UdSliverPad(
                sliver: SliverList.list(children: [
                  for (final r in items) RecRow(store: store, rec: r),
                ]),
              ),
          ],
        );
      },
    );
  }
}

class _WatchCard extends StatelessWidget {
  const _WatchCard({required this.watching, required this.onToggle});
  final bool watching;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return UdPressable(
      onTap: onToggle,
      color: watching ? t.accent : t.card,
      border: !watching,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(watching ? Icons.phone_in_talk_rounded : Icons.phone_disabled_outlined,
                  color: watching ? t.onAccent : t.accent, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr(watching ? 'watch_on' : 'watch_off'),
                        style: text.titleMedium?.copyWith(color: watching ? t.onAccent : t.ink)),
                    Text(context.tr(watching ? 'watch_on_sub' : 'watch_off_sub'),
                        style: text.bodySmall?.copyWith(
                            color: watching ? t.onAccent.withValues(alpha: 0.85) : t.inkSoft)),
                  ],
                ),
              ),
              Switch(
                value: watching,
                onChanged: (_) => onToggle(),
                activeThumbColor: t.onAccent,
                activeTrackColor: Colors.white.withValues(alpha: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.volume_up_outlined,
                  size: 18, color: watching ? t.onAccent : t.inkSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(context.tr('speaker_tip'),
                    style: text.bodySmall?.copyWith(
                        color: watching ? t.onAccent.withValues(alpha: 0.85) : t.inkSoft)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.icon, required this.title, required this.body, required this.onTap});
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return UdPressable(
      onTap: onTap,
      color: t.accentSoft,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: t.accent, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                Text(body, style: text.bodySmall?.copyWith(color: t.inkSoft)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: t.accent),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return ChoiceChip(
      label: Text(label),
      labelStyle: text.labelMedium?.copyWith(color: selected ? t.onAccent : t.ink),
      selected: selected,
      showCheckmark: false,
      selectedColor: t.accent,
      backgroundColor: t.paper,
      side: BorderSide(color: selected ? t.accent : t.line),
      shape: const StadiumBorder(),
      onSelected: (_) => onTap(),
    );
  }
}

class RecRow extends StatelessWidget {
  const RecRow({super.key, required this.store, required this.rec});
  final RecStore store;
  final Recording rec;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    return UdRow(
      leading: UdBadgeIcon(switch (rec.kind) {
        RecKind.incoming => Icons.call_received_rounded,
        RecKind.outgoing => Icons.call_made_rounded,
        RecKind.voice => Icons.mic_none_rounded,
      }),
      title: rec.name,
      subtitle: [
        if (rec.number != null && rec.number!.isNotEmpty) rec.number!,
        formatDuration(rec.duration),
        udFormatDate(context, rec.started),
        if (rec.note.isNotEmpty) rec.note,
      ].join(' · '),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rec.starred) Icon(Icons.star_rounded, size: 20, color: t.accent),
          IconButton(
            icon: Icon(Icons.more_horiz_rounded, color: t.inkSoft),
            onPressed: () => recActions(context, store, rec),
          ),
        ],
      ),
      onTap: () => showPlayer(context, store, rec),
      onLongPress: () => recActions(context, store, rec),
    );
  }
}

Future<void> recActions(BuildContext context, RecStore store, Recording r) async {
  final a = await showUdActions<String>(context, title: r.name, actions: [
    UdAction('play', Icons.play_arrow_rounded, context.tr('play')),
    UdAction('share', Icons.ios_share_rounded, context.tr('share')),
    UdAction('star', r.starred ? Icons.star_rounded : Icons.star_outline_rounded,
        context.tr(r.starred ? 'unstar' : 'star')),
    UdAction('rename', Icons.edit_outlined, context.tr('rename')),
    UdAction('note', Icons.sticky_note_2_outlined, context.tr('add_note')),
    UdAction('delete', Icons.delete_outline_rounded, context.tr('delete'), danger: true),
  ]);
  if (!context.mounted || a == null) return;
  switch (a) {
    case 'play':
      await showPlayer(context, store, r);
    case 'share':
      await udShareFiles([await store.exportCopy(r)]);
    case 'star':
      r.starred = !r.starred;
      await store.save(r);
    case 'rename':
      final n = await udPrompt(context, title: context.tr('rename'), initial: r.name);
      if (n != null) {
        r.name = n;
        await store.save(r);
      }
    case 'note':
      final n = await udPrompt(context,
          title: context.tr('add_note'), initial: r.note, hint: context.tr('note_hint'));
      if (n != null) {
        r.note = n;
        await store.save(r);
      }
    case 'delete':
      if (await udConfirm(context)) await store.remove(r);
  }
}

/// Recording options shared by the call service and the manual recorder.
class RecSettings extends StatefulWidget {
  const RecSettings({super.key});

  @override
  State<RecSettings> createState() => _RecSettingsState();
}

class _RecSettingsState extends State<RecSettings> {
  bool _speaker = false;
  String _source = 'mic';

  @override
  void initState() {
    super.initState();
    () async {
      final speaker = await FlutterForegroundTask.getData<bool>(key: K.speaker) ?? false;
      final source = await FlutterForegroundTask.getData<String>(key: K.source) ?? 'mic';
      if (mounted) {
        setState(() {
          _speaker = speaker;
          _source = source;
        });
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('rec_settings'), style: text.headlineSmall),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('auto_speaker'), style: text.titleMedium),
          subtitle: Text(context.tr('auto_speaker_sub'), style: text.bodySmall),
          value: _speaker,
          onChanged: (v) async {
            await FlutterForegroundTask.saveData(key: K.speaker, value: v);
            setState(() => _speaker = v);
          },
        ),
        const SizedBox(height: 8),
        UdLabel(context.tr('source')),
        for (final s in sources.keys)
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('src_$s'), style: text.titleMedium),
            value: s,
            // ignore: deprecated_member_use
            groupValue: _source,
            // ignore: deprecated_member_use
            onChanged: (v) async {
              if (v == null) return;
              await FlutterForegroundTask.saveData(key: K.source, value: v);
              setState(() => _source = v);
            },
          ),
        Text(context.tr('source_sub'), style: text.bodySmall?.copyWith(color: t.inkSoft)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.gavel_rounded, size: 18, color: t.accent),
              const SizedBox(width: 10),
              Expanded(child: Text(context.tr('consent'), style: text.bodySmall)),
            ],
          ),
        ),
      ],
    );
  }
}
