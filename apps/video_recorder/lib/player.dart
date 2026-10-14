import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ud_core/ud_core.dart';
import 'package:video_player/video_player.dart';

import 'main.dart' show clipActions;
import 'store.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.store, required this.clip});
  final ClipStore store;
  final Clip clip;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final VideoPlayerController _ctrl =
      VideoPlayerController.file(File(widget.store.pathOf(widget.clip)));
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _ctrl.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _ctrl.play();
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    const white = Colors.white;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: widget.store,
                      builder: (context, _) => Text(widget.clip.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(color: white)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded, color: white),
                    onPressed: () async {
                      _ctrl.pause();
                      final deleted = await clipActions(context, widget.store, widget.clip);
                      if (deleted && context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: _failed
                    ? Text(context.tr('cant_play'), style: text.bodyLarge?.copyWith(color: white))
                    : _ctrl.value.isInitialized
                        ? GestureDetector(
                            onTap: _toggle,
                            child: AspectRatio(
                              aspectRatio: _ctrl.value.aspectRatio,
                              child: VideoPlayer(_ctrl),
                            ),
                          )
                        : const CircularProgressIndicator(color: white),
              ),
            ),
            if (_ctrl.value.isInitialized)
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _ctrl,
                builder: (context, v, _) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    children: [
                      VideoProgressIndicator(
                        _ctrl,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        colors: VideoProgressColors(
                          playedColor: t.accent,
                          bufferedColor: Colors.white24,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                      Row(
                        children: [
                          Text(formatDuration(v.position),
                              style: text.labelMedium?.copyWith(color: white)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.replay_10_rounded, color: white),
                            onPressed: () => _ctrl.seekTo(v.position - const Duration(seconds: 10)),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                                backgroundColor: t.accent, minimumSize: const Size(60, 60)),
                            icon: Icon(v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: white, size: 32),
                            onPressed: _toggle,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.forward_10_rounded, color: white),
                            onPressed: () => _ctrl.seekTo(v.position + const Duration(seconds: 10)),
                          ),
                          const Spacer(),
                          Text(formatDuration(v.duration),
                              style: text.labelMedium?.copyWith(color: white)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _toggle() {
    final v = _ctrl.value;
    if (v.isPlaying) {
      _ctrl.pause();
    } else {
      if (v.position >= v.duration) _ctrl.seekTo(Duration.zero);
      _ctrl.play();
    }
  }
}
