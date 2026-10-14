import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:record/record.dart';
import 'package:ud_core/ud_core.dart';

import 'service.dart';
import 'store.dart';

/// Tap-to-record: voice notes, meetings, or a call on speaker.
class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key, required this.store});
  final RecStore store;

  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  final _rec = AudioRecorder();
  final _clock = Stopwatch();
  final _levels = <double>[];
  StreamSubscription<Amplitude>? _amp;
  Timer? _ticker;
  String? _id;
  DateTime? _started;
  bool _paused = false;

  bool get _recording => _id != null;

  @override
  void dispose() {
    _ticker?.cancel();
    _amp?.cancel();
    if (_recording) {
      _save().whenComplete(_rec.dispose);
    } else {
      _rec.dispose();
      FlutterForegroundTask.saveData(key: K.manual, value: false);
    }
    super.dispose();
  }

  Future<void> _start() async {
    if (!await _rec.hasPermission()) {
      if (mounted) udToast(context, context.tr('mic_needed'));
      return;
    }
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final source = await FlutterForegroundTask.getData<String>(key: K.source) ?? 'mic';
    try {
      await FlutterForegroundTask.saveData(key: K.manual, value: true);
      await _rec.start(recordConfig(source: source), path: audioPath(widget.store.dir, id));
    } catch (_) {
      await FlutterForegroundTask.saveData(key: K.manual, value: false);
      if (mounted) udToast(context, context.tr('error_generic'));
      return;
    }
    HapticFeedback.mediumImpact();
    _clock
      ..reset()
      ..start();
    _levels.clear();
    _amp = _rec.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((a) {
      // dBFS: about -60 is silence, 0 is loudest.
      final v = ((a.current + 60) / 60).clamp(0.04, 1.0);
      _levels.add(v);
      if (_levels.length > 60) _levels.removeAt(0);
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
    setState(() {
      _id = id;
      _started = DateTime.now();
      _paused = false;
    });
  }

  Future<void> _pauseResume() async {
    if (!_recording) return;
    if (_paused) {
      await _rec.resume();
      _clock.start();
    } else {
      await _rec.pause();
      _clock.stop();
    }
    setState(() => _paused = !_paused);
  }

  Future<Recording?> _save() async {
    final id = _id;
    if (id == null) return null;
    _id = null;
    _ticker?.cancel();
    await _amp?.cancel();
    _clock.stop();
    final dir = widget.store.dir;
    final name = udStampName(mounted ? context.tr('voice_note') : 'Voice note');
    String? path;
    try {
      path = await _rec.stop();
    } catch (_) {}
    await FlutterForegroundTask.saveData(key: K.manual, value: false);
    final file = File(path ?? audioPath(dir, id));
    if (!await file.exists()) return null;
    final r = Recording(
      id: id,
      name: name,
      kind: RecKind.voice,
      started: _started ?? DateTime.now(),
      duration: _clock.elapsed,
    );
    await writeMeta(dir, r);
    return r;
  }

  Future<void> _stop() async {
    final r = await _save();
    HapticFeedback.mediumImpact();
    await widget.store.reload();
    if (!mounted) return;
    if (r != null) udToast(context, context.tr('saved'));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_recording,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stop();
      },
      child: UdPage(
        title: context.tr('record_now'),
        subtitle: context.tr('record_sub'),
        scrollable: false,
        slivers: [
          UdSliverPad(
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Text(
                    formatDuration(_clock.elapsed),
                    style: text.displayLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: _paused ? t.inkFaint : t.ink,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 90,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 60; i++)
                          Container(
                            width: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            height: 90 * _levelAt(i),
                            decoration: BoxDecoration(
                              color: _recording ? t.accent : t.line,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 64,
                        child: _recording
                            ? IconButton.outlined(
                                iconSize: 28,
                                style: IconButton.styleFrom(minimumSize: const Size(60, 60)),
                                icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                                onPressed: _pauseResume,
                              )
                            : null,
                      ),
                      const SizedBox(width: 28),
                      GestureDetector(
                        onTap: _recording ? _stop : _start,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _recording ? t.danger : t.accent,
                            boxShadow: [
                              BoxShadow(
                                color: (_recording ? t.danger : t.accent).withValues(alpha: 0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded,
                              color: Colors.white, size: 44),
                        ),
                      ),
                      const SizedBox(width: 92),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.tr(_recording ? (_paused ? 'paused' : 'tap_stop') : 'tap_start'),
                    style: text.bodyMedium?.copyWith(color: t.inkSoft),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _levelAt(int i) {
    final offset = 60 - _levels.length;
    return i < offset ? 0.04 : _levels[i - offset];
  }
}
