import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ud_core/ud_core.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'main.dart' show saveToGallery;
import 'store.dart';

ResolutionPreset _preset(String q) => switch (q) {
      'sd' => ResolutionPreset.medium,
      'hd' => ResolutionPreset.high,
      'uhd' => ResolutionPreset.ultraHigh,
      _ => ResolutionPreset.veryHigh,
    };

/// Full-screen camera: record, pause, flip, torch and quality.
class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key, required this.store});
  final ClipStore store;

  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  int _camIndex = 0;
  CameraController? _ctrl;
  String? _error;
  bool _busy = false;
  bool _torch = false;

  final _clock = Stopwatch();
  Timer? _ticker;

  ClipStore get store => widget.store;
  bool get _recording => _ctrl?.value.isRecordingVideo ?? false;
  bool get _paused => _ctrl?.value.isRecordingPaused ?? false;
  bool get _front => _cameras.isNotEmpty && _cameras[_camIndex].lensDirection == CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    WakelockPlus.disable();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _ctrl;
    // Only when really in the background, so pulling down the shade keeps recording.
    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) {
      if (c == null) return;
      // Android takes the camera away in the background: keep what was recorded.
      if (_recording) {
        _stop();
      } else {
        _ctrl = null;
        c.dispose();
      }
    } else if (state == AppLifecycleState.resumed && _ctrl == null && !_busy) {
      _open();
    }
  }

  Future<void> _start() async {
    try {
      _cameras = await availableCameras();
    } on CameraException catch (e) {
      setState(() => _error = e.description ?? e.code);
      return;
    }
    if (_cameras.isEmpty) {
      if (mounted) setState(() => _error = context.tr('no_camera'));
      return;
    }
    _camIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
    if (_camIndex < 0) _camIndex = 0;
    await _open();
  }

  Future<void> _open() async {
    final old = _ctrl;
    _ctrl = null;
    await old?.dispose();
    final c = CameraController(
      _cameras[_camIndex],
      _preset(store.quality),
      enableAudio: store.withSound,
    );
    setState(() {
      _error = null;
      _torch = false;
    });
    try {
      await c.initialize();
    } on CameraException catch (e) {
      await c.dispose();
      if (!mounted) return;
      setState(() => _error = switch (e.code) {
            'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' => context.tr('camera_denied'),
            'AudioAccessDenied' || 'AudioAccessDeniedWithoutPrompt' => context.tr('mic_denied'),
            _ => e.description ?? e.code,
          });
      return;
    }
    if (!mounted) {
      await c.dispose();
      return;
    }
    setState(() => _ctrl = c);
  }

  Future<void> _record() async {
    final c = _ctrl;
    if (c == null || _busy) return;
    _busy = true;
    try {
      await c.startVideoRecording();
      HapticFeedback.mediumImpact();
      WakelockPlus.enable();
      _clock
        ..reset()
        ..start();
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) setState(() {});
      });
    } on CameraException catch (e) {
      if (mounted) udToast(context, e.description ?? e.code);
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _pauseResume() async {
    final c = _ctrl;
    if (c == null || !_recording) return;
    try {
      if (_paused) {
        await c.resumeVideoRecording();
        _clock.start();
      } else {
        await c.pauseVideoRecording();
        _clock.stop();
      }
    } on CameraException catch (e) {
      if (mounted) udToast(context, e.description ?? e.code);
    }
    if (mounted) setState(() {});
  }

  Future<void> _stop() async {
    final c = _ctrl;
    if (c == null || !_recording || _busy) return;
    _busy = true;
    _ticker?.cancel();
    _clock.stop();
    final duration = _clock.elapsed;
    final front = _front;
    final quality = store.quality;
    final name = udStampName(mounted ? context.tr('video') : 'Video');
    final keepInGallery = store.saveToGallery;
    try {
      final file = await c.stopVideoRecording();
      HapticFeedback.mediumImpact();
      WakelockPlus.disable();
      final clip = await store.add(file.path,
          name: name, duration: duration, front: front, quality: quality);
      var msg = 'saved_clip';
      if (keepInGallery) {
        msg = await saveToGallery(store.pathOf(clip)) ? 'saved_both' : 'saved_clip';
      }
      if (mounted) udToast(context, context.tr(msg));
    } on CameraException catch (e) {
      if (mounted) udToast(context, e.description ?? e.code);
    } finally {
      _busy = false;
      if (mounted) {
        setState(() {});
      }
      // The app may have gone to the background while saving.
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        _ctrl = null;
        await c.dispose();
      }
    }
  }

  Future<void> _flip() async {
    if (_cameras.length < 2 || _recording) return;
    final dir = _cameras[_camIndex].lensDirection;
    final next = _cameras.indexWhere((c) => c.lensDirection != dir);
    _camIndex = next < 0 ? (_camIndex + 1) % _cameras.length : next;
    await _open();
  }

  Future<void> _toggleTorch() async {
    final c = _ctrl;
    if (c == null) return;
    try {
      await c.setFlashMode(_torch ? FlashMode.off : FlashMode.torch);
      setState(() => _torch = !_torch);
    } on CameraException {
      if (mounted) udToast(context, context.tr('no_torch'));
    }
  }

  Future<void> _options() async {
    if (_recording) return;
    await showUdSheet<void>(context, (c) => _Options(store: store));
    await _open();
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctrl;
    final text = Theme.of(context).textTheme;
    const white = Colors.white;
    return Scaffold(
      backgroundColor: Colors.black,
      body: PopScope(
        canPop: !_recording,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) udToast(context, context.tr('stop_first'));
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (c != null && c.value.isInitialized)
              _Preview(controller: c)
            else
              Center(
                child: _error == null
                    ? const CircularProgressIndicator(color: white)
                    : Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam_off_outlined, color: white, size: 48),
                            const SizedBox(height: 16),
                            Text(_error!,
                                textAlign: TextAlign.center,
                                style: text.bodyLarge?.copyWith(color: white)),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _cameras.isEmpty ? _start : _open,
                              child: Text(context.tr('retry')),
                            ),
                          ],
                        ),
                      ),
              ),
            // Top bar: back, timer, torch, options.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _RoundButton(
                      icon: Icons.close_rounded,
                      onTap: _recording ? null : () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    if (_recording)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _paused ? Colors.black54 : const Color(0xFFD32F2F),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_paused ? Icons.pause_rounded : Icons.circle,
                                color: white, size: _paused ? 16 : 10),
                            const SizedBox(width: 8),
                            Text(formatDuration(_clock.elapsed),
                                style: text.titleMedium?.copyWith(
                                    color: white,
                                    fontFeatures: const [FontFeature.tabularFigures()])),
                          ],
                        ),
                      ),
                    const Spacer(),
                    _RoundButton(
                      icon: _torch ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                      onTap: c == null ? null : _toggleTorch,
                    ),
                    const SizedBox(width: 8),
                    _RoundButton(
                      icon: Icons.tune_rounded,
                      onTap: _recording ? null : _options,
                    ),
                  ],
                ),
              ),
            ),
            // Bottom controls in the thumb zone.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _RoundButton(
                        size: 56,
                        icon: _recording
                            ? (_paused ? Icons.play_arrow_rounded : Icons.pause_rounded)
                            : Icons.flip_camera_android_rounded,
                        onTap: _recording
                            ? _pauseResume
                            : (_cameras.length > 1 && c != null ? _flip : null),
                      ),
                      _ShutterButton(
                        recording: _recording,
                        onTap: c == null ? null : (_recording ? _stop : _record),
                      ),
                      const SizedBox(width: 56),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fills the screen with the camera picture, cropping the edges.
class _Preview extends StatelessWidget {
  const _Preview({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    var scale = size.aspectRatio * controller.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: Center(child: CameraPreview(controller)),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, this.size = 44});
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: Material(
        color: Colors.black45,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: Colors.white, size: size * 0.5),
          ),
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.recording, required this.onTap});
  final bool recording;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 5),
        ),
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: recording ? 32 : 62,
          height: recording ? 32 : 62,
          decoration: BoxDecoration(
            color: const Color(0xFFE53935),
            borderRadius: BorderRadius.circular(recording ? 8 : 31),
          ),
        ),
      ),
    );
  }
}

class _Options extends StatefulWidget {
  const _Options({required this.store});
  final ClipStore store;

  @override
  State<_Options> createState() => _OptionsState();
}

class _OptionsState extends State<_Options> {
  ClipStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('options'), style: text.headlineSmall),
        const SizedBox(height: 16),
        UdLabel(context.tr('quality')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in qualities)
              ChoiceChip(
                label: Text(context.tr('q_$q')),
                labelStyle: text.labelMedium
                    ?.copyWith(color: q == store.quality ? t.onAccent : t.ink),
                selected: q == store.quality,
                showCheckmark: false,
                selectedColor: t.accent,
                backgroundColor: t.paper,
                side: BorderSide(color: q == store.quality ? t.accent : t.line),
                shape: const StadiumBorder(),
                onSelected: (_) async {
                  await store.setQuality(q);
                  setState(() {});
                },
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(context.tr('quality_note'),
              style: text.bodySmall?.copyWith(color: t.inkSoft)),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('with_sound'), style: text.titleMedium),
          value: store.withSound,
          onChanged: (v) async {
            await store.setWithSound(v);
            setState(() {});
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('auto_gallery'), style: text.titleMedium),
          subtitle: Text(context.tr('auto_gallery_sub'), style: text.bodySmall),
          value: store.saveToGallery,
          onChanged: (v) async {
            await store.setSaveToGallery(v);
            setState(() {});
          },
        ),
      ],
    );
  }
}
