import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ud_core/ud_core.dart';

import 'music.dart';
import 'sound.dart';
import 'strings.dart';

const appName = 'Sur';

void main() => runUdApp(UdAppSpec(
      name: appName,
      taglineKey: 'tagline',
      accent: const Color(0xFF8E3B6E),
      icon: Icons.piano_rounded,
      strings: musicStrings,
      home: (_) => const HomePage(),
    ));

/// Shown while note sounds are generated the first time.
class SoundGate extends StatelessWidget {
  const SoundGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: Sound.instance.init(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done) return child;
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(context.tr('preparing')),
              ],
            ),
          ),
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    Sound.instance.init(); // warm up in the background
  }

  void _go(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => SoundGate(child: page)));

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('piano', Icons.piano_rounded, () => _go(const PianoPage())),
      ('songs', Icons.queue_music_rounded, () => _go(const SongsPage())),
      ('ear', Icons.hearing_rounded, () => _go(const EarPage())),
      ('tanpura', Icons.graphic_eq_rounded, () => _go(const TanpuraPage())),
      ('metronome', Icons.timer_outlined, () => _go(const MetronomePage())),
    ];
    return UdPage(
      eyebrow: appName,
      title: context.tr('home_title'),
      subtitle: context.tr('home_sub'),
      actions: const [UdSettingsButton(appName: appName)],
      dock: UdDock(
        label: context.tr('open_piano'),
        icon: Icons.piano_rounded,
        onPressed: () => _go(const PianoPage()),
      ),
      slivers: [
        UdSliverPad(
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              for (var i = 0; i < tiles.length; i++)
                UdToolTile(
                  icon: tiles[i].$2,
                  title: context.tr(tiles[i].$1),
                  subtitle: context.tr('${tiles[i].$1}_sub'),
                  highlight: i == 1,
                  onTap: tiles[i].$3,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Multi-touch keyboard. Plays on finger-down for low latency.
class Keyboard extends StatefulWidget {
  const Keyboard({
    super.key,
    required this.low,
    required this.high,
    required this.onNote,
    this.glow,
    this.useSargam = true,
    this.height = 240,
  });

  final int low;
  final int high;
  final int? glow;
  final bool useSargam;
  final double height;
  final void Function(int midi) onNote;

  @override
  State<Keyboard> createState() => _KeyboardState();
}

class _KeyboardState extends State<Keyboard> {
  final _pressed = <int, int>{}; // pointer -> midi

  List<int> get _whites => [
        for (var m = widget.low; m <= widget.high; m++)
          if (!isBlack(m)) m,
      ];

  int? _hit(Offset p, double ww) {
    final whites = _whites;
    final bw = ww * 0.62;
    final bh = widget.height * 0.6;
    if (p.dy < bh) {
      for (var i = 0; i < whites.length; i++) {
        final m = whites[i] + 1;
        if (m > widget.high || !isBlack(m)) continue;
        final left = (i + 1) * ww - bw / 2;
        if (p.dx >= left && p.dx <= left + bw) return m;
      }
    }
    final idx = (p.dx ~/ ww).clamp(0, whites.length - 1);
    return whites[idx];
  }

  void _down(PointerEvent e, double ww) {
    final m = _hit(e.localPosition, ww);
    if (m == null) return;
    setState(() => _pressed[e.pointer] = m);
    HapticFeedback.selectionClick();
    Sound.instance.note(m);
    widget.onNote(m);
  }

  void _up(PointerEvent e) => setState(() => _pressed.remove(e.pointer));

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final lang = context.udSettings.lang;
    final whites = _whites;
    return LayoutBuilder(builder: (context, box) {
      final ww = box.maxWidth / whites.length;
      final bw = ww * 0.62;
      final down = _pressed.values.toSet();

      Widget label(int m, Color c) => Text(
            noteName(m, useSargam: widget.useSargam, lang: lang),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: ww > 40 ? 13 : 11, fontWeight: FontWeight.w600, color: c),
          );

      return Listener(
        onPointerDown: (e) => _down(e, ww),
        onPointerUp: _up,
        onPointerCancel: _up,
        child: SizedBox(
          height: widget.height,
          child: Stack(
            children: [
              for (var i = 0; i < whites.length; i++)
                Positioned(
                  left: i * ww,
                  top: 0,
                  width: ww,
                  height: widget.height,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: down.contains(whites[i])
                          ? t.accentSoft
                          : widget.glow == whites[i]
                              ? const Color(0xFFFFE9A8)
                              : Colors.white,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                      border: Border.all(
                          color: widget.glow == whites[i] ? const Color(0xFFD9A11E) : const Color(0xFFDDD5C5),
                          width: widget.glow == whites[i] ? 2.5 : 1),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))],
                    ),
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.only(bottom: 12),
                    child: label(whites[i], const Color(0xFF5C574D)),
                  ),
                ),
              for (var i = 0; i < whites.length; i++)
                if (whites[i] + 1 <= widget.high && isBlack(whites[i] + 1))
                  Positioned(
                    left: (i + 1) * ww - bw / 2,
                    top: 0,
                    width: bw,
                    height: widget.height * 0.6,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 90),
                      decoration: BoxDecoration(
                        color: down.contains(whites[i] + 1)
                            ? t.accent
                            : widget.glow == whites[i] + 1
                                ? const Color(0xFFD9A11E)
                                : const Color(0xFF1D1B16),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
                      ),
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ww > 34 ? label(whites[i] + 1, Colors.white70) : null,
                    ),
                  ),
            ],
          ),
        ),
      );
    });
  }
}

class PianoPage extends StatefulWidget {
  const PianoPage({super.key});

  @override
  State<PianoPage> createState() => _PianoPageState();
}

class _PianoPageState extends State<PianoPage> {
  int _low = 60;
  bool _sargam = true;
  int? _last;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final lang = context.udSettings.lang;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  UdIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  Expanded(child: Text(context.tr('piano'), style: text.headlineSmall)),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: true, label: Text(context.tr('sargam'))),
                      ButtonSegment(value: false, label: Text(context.tr('western'))),
                    ],
                    selected: {_sargam},
                    onSelectionChanged: (s) => setState(() => _sargam = s.first),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 120),
                  child: Text(
                    _last == null ? '♪' : noteName(_last!, useSargam: _sargam, lang: lang),
                    key: ValueKey(_last),
                    style: text.displayLarge?.copyWith(fontSize: 96, color: t.accent),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: _low > 48 ? () => setState(() => _low -= 12) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('${westernNames[0]}${_low ~/ 12 - 1} – E${_low ~/ 12}', style: text.labelLarge),
                ),
                IconButton.filledTonal(
                  onPressed: _low < 72 ? () => setState(() => _low += 12) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
              child: Keyboard(
                low: _low,
                high: _low + 16,
                useSargam: _sargam,
                height: 260,
                onNote: (m) => setState(() => _last = m),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SongsPage extends StatelessWidget {
  const SongsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return UdPage(
      title: context.tr('songs'),
      subtitle: context.tr('songs_sub'),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            for (final s in songs)
              UdRow(
                leading: const UdBadgeIcon(Icons.music_note_rounded),
                title: context.tr('s_${s.id}'),
                subtitle: context.tr('notes_n', {'n': '${s.notes.length}'}),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => PlayAlongPage(song: s))),
              ),
          ]),
        ),
      ],
    );
  }
}

class PlayAlongPage extends StatefulWidget {
  const PlayAlongPage({super.key, required this.song});
  final Song song;

  @override
  State<PlayAlongPage> createState() => _PlayAlongPageState();
}

class _PlayAlongPageState extends State<PlayAlongPage> {
  int _pos = 0;
  bool _demo = false;
  bool _alive = true;
  int _wrongKey = -1;

  Song get song => widget.song;

  @override
  void dispose() {
    _alive = false;
    super.dispose();
  }

  Future<void> _playDemo() async {
    if (_demo) return;
    setState(() {
      _demo = true;
      _pos = 0;
    });
    const beatMs = 520;
    for (var i = 0; i < song.notes.length; i++) {
      if (!_alive || !_demo) return;
      setState(() => _pos = i);
      Sound.instance.note(song.notes[i]);
      await Future<void>.delayed(Duration(milliseconds: (beatMs * song.beat(i)).round()));
    }
    if (!_alive) return;
    setState(() {
      _demo = false;
      _pos = 0;
    });
  }

  void _onNote(int m) {
    if (_demo || _pos >= song.notes.length) return;
    if (m == song.notes[_pos]) {
      setState(() {
        _pos++;
        _wrongKey = -1;
      });
      if (_pos == song.notes.length) HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _wrongKey = m);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final lang = context.udSettings.lang;
    final lowest = song.notes.reduce(min);
    final highest = song.notes.reduce(max);
    final low = lowest - lowest % 12;
    final high = max(low + 16, highest + (isBlack(highest + 1) ? 2 : 1));
    final finished = _pos >= song.notes.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  UdIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(context.tr('s_${song.id}'),
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleLarge),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: song.notes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final done = i < _pos;
                  final now = i == _pos;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: now ? t.accent : done ? t.accentSoft : t.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: now ? t.accent : t.line),
                    ),
                    child: Text(
                      noteName(song.notes[i], useSargam: true, lang: lang),
                      style: text.titleMedium?.copyWith(color: now ? t.onAccent : t.ink),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  finished
                      ? context.tr('well_played')
                      : _wrongKey >= 0
                          ? '✕  ${noteName(_wrongKey, useSargam: true, lang: lang)}'
                          : context.tr('your_turn'),
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(color: _wrongKey >= 0 && !finished ? t.danger : t.ink),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _demo ? () => setState(() => _demo = false) : _playDemo,
                      icon: Icon(_demo ? Icons.stop_rounded : Icons.headphones_rounded),
                      label: Text(_demo ? context.tr('stop') : context.tr('listen_first')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => setState(() {
                        _pos = 0;
                        _demo = false;
                        _wrongKey = -1;
                      }),
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(context.tr('restart')),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 16),
              child: Keyboard(
                low: low,
                high: high,
                glow: finished ? null : song.notes[_pos.clamp(0, song.notes.length - 1)],
                onNote: _onNote,
                height: 230,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EarPage extends StatefulWidget {
  const EarPage({super.key});

  @override
  State<EarPage> createState() => _EarPageState();
}

class _EarPageState extends State<EarPage> {
  static const pool = [60, 62, 64, 65, 67, 69, 71];
  final _rng = Random();
  late int _target;
  late List<int> _options;
  int? _picked;
  int _score = 0;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  void _newRound() {
    _target = pool[_rng.nextInt(pool.length)];
    _options = ([...pool]..remove(_target)..shuffle(_rng)).take(3).toList()
      ..add(_target)
      ..shuffle(_rng);
    _picked = null;
    Future<void>.delayed(const Duration(milliseconds: 300), () => Sound.instance.note(_target));
  }

  void _pick(int m) {
    if (_picked != null) return;
    setState(() {
      _picked = m;
      if (m == _target) {
        _score++;
        _streak++;
      } else {
        _streak = 0;
      }
    });
    Sound.instance.note(m == _target ? m : _target);
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final lang = context.udSettings.lang;
    return UdPage(
      title: context.tr('which_note'),
      subtitle: context.tr('score_streak', {'a': '$_score', 'b': '$_streak'}),
      dock: UdDock(
        label: _picked == null ? context.tr('replay') : context.tr('next_note'),
        icon: _picked == null ? Icons.volume_up_rounded : Icons.arrow_forward_rounded,
        onPressed: () {
          if (_picked == null) {
            Sound.instance.note(_target);
          } else {
            setState(_newRound);
          }
        },
        extras: [
          UdDockAction(icon: Icons.music_note_rounded, label: 'Sa', onTap: () => Sound.instance.note(60)),
        ],
      ),
      slivers: [
        UdSliverPad(
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              for (final o in _options)
                UdPressable(
                  onTap: () => _pick(o),
                  color: _picked == null
                      ? t.card
                      : o == _target
                          ? const Color(0xFF2F7D4F).withValues(alpha: 0.18)
                          : o == _picked
                              ? t.danger.withValues(alpha: 0.14)
                              : t.card,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(noteName(o, useSargam: true, lang: lang), style: text.displaySmall),
                        Text(noteName(o, useSargam: false, lang: lang),
                            style: text.labelMedium?.copyWith(color: t.inkSoft)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class TanpuraPage extends StatefulWidget {
  const TanpuraPage({super.key});

  @override
  State<TanpuraPage> createState() => _TanpuraPageState();
}

class _TanpuraPageState extends State<TanpuraPage> with SingleTickerProviderStateMixin {
  int _sa = 48; // C3
  bool _ma = false;
  bool _on = false;
  bool _loading = false;
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void dispose() {
    _pulse.dispose();
    Sound.instance.stopDrone();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_on) {
      await Sound.instance.stopDrone();
      _pulse.stop();
      setState(() => _on = false);
      return;
    }
    setState(() => _loading = true);
    await Sound.instance.startDrone(_sa, useMa: _ma);
    if (!mounted) return;
    _pulse.repeat(reverse: true);
    setState(() {
      _loading = false;
      _on = true;
    });
  }

  Future<void> _restartIfOn() async {
    if (!_on) return;
    setState(() => _loading = true);
    await Sound.instance.startDrone(_sa, useMa: _ma);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return UdPage(
      title: context.tr('tanpura'),
      subtitle: context.tr('tanpura_sub'),
      dock: UdDock(
        label: _on ? context.tr('stop') : context.tr('start'),
        icon: _on ? Icons.stop_rounded : Icons.play_arrow_rounded,
        onPressed: _loading ? () {} : _toggle,
      ),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            Center(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final s = 1 + _pulse.value * 0.12;
                  return Transform.scale(
                    scale: _on ? s : 1,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _on ? t.accent : t.accentSoft,
                        border: Border.all(color: t.line),
                      ),
                      alignment: Alignment.center,
                      child: _loading
                          ? const CircularProgressIndicator()
                          : Text('${westernNames[_sa % 12]}',
                              style: text.displayMedium?.copyWith(color: _on ? t.onAccent : t.accent)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            UdLabel(context.tr('sa_key')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var m = 48; m < 60; m++)
                  ChoiceChip(
                    label: Text(westernNames[m % 12]),
                    selected: m == _sa,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() => _sa = m);
                      _restartIfOn();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('with_ma'), style: text.titleMedium),
              value: _ma,
              onChanged: (v) {
                setState(() => _ma = v);
                _restartIfOn();
              },
            ),
          ]),
        ),
      ],
    );
  }
}

class MetronomePage extends StatefulWidget {
  const MetronomePage({super.key});

  @override
  State<MetronomePage> createState() => _MetronomePageState();
}

class _MetronomePageState extends State<MetronomePage> {
  double _bpm = 90;
  int _beats = 4;
  int _beat = -1;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _beat = -1;
    _tick();
    _timer = Timer.periodic(Duration(milliseconds: (60000 / _bpm).round()), (_) => _tick());
    setState(() {});
  }

  void _tick() {
    setState(() => _beat = (_beat + 1) % _beats);
    Sound.instance.click(accent: _beat == 0);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    setState(() => _beat = -1);
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final running = _timer != null;
    return UdPage(
      title: context.tr('metronome'),
      subtitle: context.tr('bpm', {'n': '${_bpm.round()}'}),
      dock: UdDock(
        label: running ? context.tr('stop') : context.tr('start'),
        icon: running ? Icons.stop_rounded : Icons.play_arrow_rounded,
        onPressed: running ? _stop : _start,
      ),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            Center(child: Text('${_bpm.round()}', style: text.displayLarge?.copyWith(fontSize: 88))),
            Slider(
              value: _bpm,
              min: 40,
              max: 220,
              divisions: 180,
              onChanged: (v) => setState(() => _bpm = v),
              onChangeEnd: (_) {
                if (running) _start();
              },
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < _beats; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    width: _beats > 8 ? 26 : 38,
                    height: _beats > 8 ? 26 : 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _beat ? (i == 0 ? t.accent : t.ink) : t.accentSoft,
                      border: Border.all(color: t.line),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            UdLabel(context.tr('taal')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in const [3, 4, 6, 7, 8, 10, 12, 16])
                  ChoiceChip(
                    label: Text('$b'),
                    selected: b == _beats,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() => _beats = b);
                      if (running) _start();
                    },
                  ),
              ],
            ),
          ]),
        ),
      ],
    );
  }
}
