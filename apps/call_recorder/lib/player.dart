import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ud_core/ud_core.dart';

import 'store.dart';

Future<void> showPlayer(BuildContext context, RecStore store, Recording r) =>
    showUdSheet<void>(context, (_) => _Player(path: store.pathOf(r), rec: r));

class _Player extends StatefulWidget {
  const _Player({required this.path, required this.rec});
  final String path;
  final Recording rec;

  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> {
  final _player = AudioPlayer();
  bool _failed = false;
  double _speed = 1;

  @override
  void initState() {
    super.initState();
    _player.setFilePath(widget.path).then((_) => _player.play()).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _cycleSpeed() {
    _speed = switch (_speed) { 1.0 => 1.5, 1.5 => 2.0, _ => 1.0 };
    _player.setSpeed(_speed);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final r = widget.rec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(r.name, style: text.headlineSmall),
        const SizedBox(height: 4),
        Text(
          [
            if (r.number != null && r.number!.isNotEmpty) r.number!,
            udFormatDate(context, r.started),
          ].join(' · '),
          style: text.bodySmall?.copyWith(color: t.inkSoft),
        ),
        if (r.note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(r.note, style: text.bodyMedium),
          ),
        const SizedBox(height: 20),
        if (_failed)
          Text(context.tr('cant_play'), style: text.bodyMedium?.copyWith(color: t.danger))
        else
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, snap) {
              final total = _player.duration ?? r.duration;
              final pos = snap.data ?? Duration.zero;
              final max = total.inMilliseconds.toDouble().clamp(1, double.infinity).toDouble();
              return Column(
                children: [
                  Slider(
                    value: pos.inMilliseconds.toDouble().clamp(0, max),
                    max: max,
                    onChanged: (v) => _player.seek(Duration(milliseconds: v.round())),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      children: [
                        Text(formatDuration(pos), style: text.labelMedium),
                        const Spacer(),
                        Text(formatDuration(total), style: text.labelMedium),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(onPressed: _cycleSpeed, child: Text('${_speed}x')),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.replay_10_rounded),
              onPressed: () => _player.seek(_player.position - const Duration(seconds: 10)),
            ),
            const SizedBox(width: 8),
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (context, snap) {
                final s = snap.data;
                final playing = s?.playing ?? false;
                final done = s?.processingState == ProcessingState.completed;
                return IconButton.filled(
                  iconSize: 34,
                  style: IconButton.styleFrom(minimumSize: const Size(64, 64)),
                  icon: Icon(playing && !done ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  onPressed: () async {
                    if (playing && !done) {
                      await _player.pause();
                    } else {
                      if (done) await _player.seek(Duration.zero);
                      await _player.play();
                    }
                  },
                );
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.forward_10_rounded),
              onPressed: () => _player.seek(_player.position + const Duration(seconds: 10)),
            ),
            const SizedBox(width: 56),
          ],
        ),
      ],
    );
  }
}
