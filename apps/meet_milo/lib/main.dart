import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ud_core/ud_core.dart';

import 'strings.dart';

const appName = 'Milo';
const kServer = 'https://meet.jit.si/';

final meetings = UdListStore('milo.meetings');

void main() => runUdApp(UdAppSpec(
      name: appName,
      taglineKey: 'tagline',
      accent: const Color(0xFF5B4FCF),
      icon: Icons.videocam_rounded,
      strings: meetStrings,
      home: (_) => const HomePage(),
    ));

/// Memorable, hard-to-guess room names like "Milo-MangoRiver-4821".
String newRoom() {
  const a = ['Mango', 'Lotus', 'Peacock', 'Monsoon', 'Saffron', 'Banyan', 'Tiger', 'Jasmine', 'Coral', 'Comet'];
  const b = ['River', 'Garden', 'Hill', 'Lake', 'Market', 'Bridge', 'Valley', 'Harbour', 'Forest', 'Desert'];
  final r = Random.secure();
  return 'Milo-${a[r.nextInt(a.length)]}${b[r.nextInt(b.length)]}-${1000 + r.nextInt(9000)}';
}

String linkOf(String room) => '$kServer$room';

String fmtWhen(DateTime d) => '${udTwo(d.day)}/${udTwo(d.month)}/${d.year}, ${udTwo(d.hour)}:${udTwo(d.minute)}';

Future<void> join(String room) => udOpenUrl(linkOf(room), external: true);

Future<void> invite(BuildContext context, Map<String, dynamic> m) {
  final when = m['when'] == null ? '' : context.tr('invite_when', {'d': fmtWhen(DateTime.parse(m['when'] as String))});
  return udShareText(context.tr('invite_text', {'t': m['title'] as String, 'w': when, 'l': linkOf(m['room'] as String)}));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _join = TextEditingController();

  @override
  void initState() {
    super.initState();
    meetings.load();
  }

  Future<void> _startNow() async {
    final m = await meetings.add({
      'title': context.tr('quick_title'),
      'room': newRoom(),
      'created': DateTime.now().toIso8601String(),
    });
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MeetingPage(id: m['id'] as String)));
  }

  void _joinTyped() {
    final s = _join.text.trim();
    if (s.isEmpty) return;
    final room = s.contains('/') ? s.split('/').last.split('?').first : s.replaceAll(' ', '');
    join(room);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: meetings,
      builder: (context, _) {
        final t = UdTokens.of(context);
        final text = Theme.of(context).textTheme;
        final now = DateTime.now();
        DateTime when(Map<String, dynamic> m) => DateTime.parse((m['when'] ?? m['created']) as String);
        final upcoming = meetings.items.where((m) => m['when'] != null && when(m).isAfter(now.subtract(const Duration(hours: 1)))).toList()
          ..sort((a, b) => when(a).compareTo(when(b)));
        final past = meetings.items.where((m) => !upcoming.contains(m)).take(10).toList();

        return UdPage(
          eyebrow: appName,
          title: context.tr('home_title'),
          subtitle: context.tr('home_sub'),
          actions: const [UdSettingsButton(appName: appName)],
          dock: UdDock(
            label: context.tr('start_now'),
            icon: Icons.videocam_rounded,
            onPressed: _startNow,
            extras: [
              UdDockAction(
                icon: Icons.event_rounded,
                label: context.tr('schedule'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScheduleForm())),
              ),
            ],
          ),
          slivers: [
            UdSliverPad(
              bottom: 16,
              sliver: SliverToBoxAdapter(
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _join,
                      onSubmitted: (_) => _joinTyped(),
                      decoration: udInputDecoration(context, hint: context.tr('join_hint'), icon: Icons.link_rounded),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(height: 56, child: FilledButton(onPressed: _joinTyped, child: Text(context.tr('join_btn')))),
                ]),
              ),
            ),
            if (meetings.loaded && meetings.items.isEmpty)
              SliverToBoxAdapter(
                child: UdEmpty(icon: Icons.video_call_outlined, title: context.tr('empty_title'), body: context.tr('empty_body')),
              )
            else
              UdSliverPad(
                sliver: SliverList.list(children: [
                  if (upcoming.isNotEmpty) UdLabel(context.tr('upcoming')),
                  for (final m in upcoming) _row(context, m, true),
                  if (past.isNotEmpty) UdLabel(context.tr('past')),
                  for (final m in past) _row(context, m, false),
                ]),
              ),
            UdSliverPad(
              top: 12,
              sliver: SliverToBoxAdapter(
                child: Text(context.tr('powered'), style: text.bodySmall?.copyWith(color: t.inkSoft)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> m, bool upcoming) {
    final w = m['when'] == null ? null : DateTime.parse(m['when'] as String);
    String sub = m['room'] as String;
    if (w != null) {
      final diff = w.difference(DateTime.now());
      final rel = diff.isNegative
          ? context.tr('now')
          : context.tr('starts_in', {'t': diff.inHours >= 24 ? '${diff.inDays}d' : diff.inHours >= 1 ? '${diff.inHours}h' : '${diff.inMinutes}m'});
      sub = '${fmtWhen(w)} · $rel';
    }
    return UdRow(
      leading: UdBadgeIcon(upcoming ? Icons.event_available_rounded : Icons.videocam_outlined),
      title: m['title'] as String,
      subtitle: sub,
      trailing: IconButton(icon: const Icon(Icons.login_rounded), onPressed: () => join(m['room'] as String)),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MeetingPage(id: m['id'] as String))),
    );
  }
}

class ScheduleForm extends StatefulWidget {
  const ScheduleForm({super.key});

  @override
  State<ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<ScheduleForm> {
  final _title = TextEditingController();
  DateTime _when = DateTime.now().add(const Duration(hours: 1));

  Future<void> _pick() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final tm = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (tm == null) return;
    setState(() => _when = DateTime(d.year, d.month, d.day, tm.hour, tm.minute));
  }

  Future<void> _save() async {
    final title = _title.text.trim().isEmpty ? context.tr('quick_title') : _title.text.trim();
    final m = await meetings.add({
      'title': title,
      'room': newRoom(),
      'when': _when.toIso8601String(),
      'created': DateTime.now().toIso8601String(),
    });
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MeetingPage(id: m['id'] as String)));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return UdPage(
      title: context.tr('schedule'),
      dock: UdDock(label: context.tr('save_meeting'), icon: Icons.check_rounded, onPressed: _save),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            UdLabel(context.tr('meeting_title')),
            TextField(
              controller: _title,
              autofocus: true,
              style: text.bodyLarge,
              decoration: udInputDecoration(context, hint: context.tr('title_hint')),
            ),
            const SizedBox(height: 18),
            UdLabel(context.tr('when')),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.event_rounded),
              label: Text(fmtWhen(_when)),
            ),
          ]),
        ),
      ],
    );
  }
}

class MeetingPage extends StatelessWidget {
  const MeetingPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? m;
    for (final e in meetings.items) {
      if (e['id'] == id) m = e;
    }
    final meeting = m;
    if (meeting == null) return const Scaffold();
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final link = linkOf(meeting['room'] as String);
    final when = meeting['when'] == null ? null : DateTime.parse(meeting['when'] as String);
    return UdPage(
      title: meeting['title'] as String,
      subtitle: when == null ? null : fmtWhen(when),
      actions: [
        UdIconButton(
          icon: Icons.delete_outline_rounded,
          onTap: () async {
            if (!await udConfirm(context)) return;
            await meetings.remove(id);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
      dock: UdDock(
        label: context.tr('join_meeting'),
        icon: Icons.videocam_rounded,
        onPressed: () => join(meeting['room'] as String),
        extras: [
          UdDockAction(icon: Icons.share_rounded, label: context.tr('invite'), onTap: () => invite(context, meeting)),
        ],
      ),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: t.accentSoft, borderRadius: BorderRadius.circular(24)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.videocam_rounded, size: 40, color: t.accent),
                const SizedBox(height: 12),
                SelectableText(link, style: text.titleMedium),
                const SizedBox(height: 12),
                Row(children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      udToast(context, context.tr('copied'));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text(context.tr('copy_link')),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => invite(context, meeting),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: Text(context.tr('invite')),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            Text(context.tr('powered'), style: text.bodySmall?.copyWith(color: t.inkSoft)),
          ]),
        ),
      ],
    );
  }
}
