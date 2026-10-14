import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:ud_core/ud_core.dart';

import 'player.dart';
import 'recorder.dart';
import 'store.dart';
import 'strings.dart';

const appName = 'ClipCam';

void main() => runUdApp(UdAppSpec(
      name: appName,
      taglineKey: 'tagline',
      accent: const Color(0xFFC2412F),
      icon: Icons.videocam_outlined,
      strings: clipStrings,
      home: (_) => const ClipGate(),
    ));

class ClipGate extends StatefulWidget {
  const ClipGate({super.key});

  @override
  State<ClipGate> createState() => _ClipGateState();
}

class _ClipGateState extends State<ClipGate> {
  ClipStore? _store;

  @override
  void initState() {
    super.initState();
    ClipStore.open().then((s) {
      if (mounted) setState(() => _store = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (store == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return LibraryPage(store: store);
  }
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.store});
  final ClipStore store;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String _query = '';

  ClipStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final all = store.clips;
        final q = _query.toLowerCase();
        final clips = q.isEmpty ? all : all.where((c) => c.name.toLowerCase().contains(q)).toList();
        return UdPage(
          eyebrow: appName,
          title: context.tr('home_title'),
          subtitle: context.tr('home_sub', {
            'n': '${all.length}',
            'time': formatDuration(store.totalDuration),
            'size': udFormatBytes(store.totalBytes),
          }),
          actions: const [UdSettingsButton(appName: appName)],
          dock: UdDock(
            label: context.tr('record'),
            icon: Icons.fiber_manual_record_rounded,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => RecorderPage(store: store),
            )),
          ),
          slivers: [
            if (all.isNotEmpty)
              UdSliverPad(
                bottom: 18,
                sliver: SliverToBoxAdapter(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: udInputDecoration(context,
                        hint: context.tr('search_hint'), icon: Icons.search_rounded),
                  ),
                ),
              ),
            if (all.isEmpty)
              SliverToBoxAdapter(
                child: UdEmpty(
                  icon: Icons.videocam_outlined,
                  title: context.tr('empty'),
                  body: context.tr('empty_body'),
                ),
              )
            else if (clips.isEmpty)
              SliverToBoxAdapter(
                child: UdEmpty(icon: Icons.search_off_rounded, title: context.tr('no_results')),
              )
            else
              UdSliverPad(
                sliver: SliverList.list(children: [
                  for (final c in clips) ClipRow(store: store, clip: c),
                ]),
              ),
          ],
        );
      },
    );
  }
}

class ClipRow extends StatelessWidget {
  const ClipRow({super.key, required this.store, required this.clip});
  final ClipStore store;
  final Clip clip;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    return UdRow(
      leading: UdBadgeIcon(clip.front ? Icons.portrait_rounded : Icons.movie_outlined),
      title: clip.name,
      subtitle: [
        formatDuration(clip.duration),
        context.tr('q_${clip.quality}'),
        udFormatDate(context, clip.created),
      ].join(' · '),
      trailing: IconButton(
        icon: Icon(Icons.more_horiz_rounded, color: t.inkSoft),
        onPressed: () => clipActions(context, store, clip),
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PlayerPage(store: store, clip: clip),
      )),
      onLongPress: () => clipActions(context, store, clip),
    );
  }
}

/// Returns true when the clip was deleted.
Future<bool> clipActions(BuildContext context, ClipStore store, Clip clip) async {
  final a = await showUdActions<String>(context, title: clip.name, actions: [
    UdAction('share', Icons.ios_share_rounded, context.tr('share')),
    UdAction('gallery', Icons.add_photo_alternate_outlined, context.tr('save_gallery')),
    UdAction('rename', Icons.edit_outlined, context.tr('rename')),
    UdAction('delete', Icons.delete_outline_rounded, context.tr('delete'), danger: true),
  ]);
  if (!context.mounted || a == null) return false;
  switch (a) {
    case 'share':
      await udShareFiles([await store.exportCopy(clip)]);
    case 'gallery':
      final ok = await saveToGallery(store.pathOf(clip));
      if (context.mounted) udToast(context, context.tr(ok ? 'saved_gallery' : 'gallery_failed'));
    case 'rename':
      final n = await udPrompt(context, title: context.tr('rename'), initial: clip.name);
      if (n != null) await store.rename(clip, n);
    case 'delete':
      if (await udConfirm(context)) {
        await store.remove(clip);
        return true;
      }
  }
  return false;
}

/// Copies a video into the phone's gallery (album "ClipCam").
Future<bool> saveToGallery(String path) async {
  try {
    if (!await Gal.hasAccess(toAlbum: true)) {
      if (!await Gal.requestAccess(toAlbum: true)) return false;
    }
    await Gal.putVideo(path, album: appName);
    return true;
  } catch (_) {
    return false;
  }
}
