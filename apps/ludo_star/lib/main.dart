import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ud_core/ud_core.dart';

import 'board.dart';
import 'game.dart';
import 'strings.dart';

const appName = 'Ludo Royale';

void main() => runUdApp(UdAppSpec(
      name: appName,
      taglineKey: 'tagline',
      accent: const Color(0xFF6B3FA0),
      icon: Icons.casino_rounded,
      strings: ludoStrings,
      home: (_) => const SetupPage(),
    ));

List<int> seatColors(int count) => switch (count) {
      2 => const [0, 2],
      3 => const [0, 1, 2],
      _ => const [0, 1, 2, 3],
    };

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  LudoMode _mode = LudoMode.classic;
  int _count = 2;
  final _bots = [false, true, true, true];

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final colors = seatColors(_count);

    Widget modeCard(LudoMode m, IconData icon) {
      final sel = m == _mode;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: UdPressable(
          onTap: () => setState(() => _mode = m),
          color: sel ? t.accentSoft : t.card,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              UdBadgeIcon(icon, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('m_${m.name}'), style: text.titleLarge),
                    Text(context.tr('m_${m.name}_sub'),
                        style: text.bodySmall?.copyWith(color: t.inkSoft)),
                  ],
                ),
              ),
              Icon(sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: sel ? t.accent : t.inkFaint),
            ],
          ),
        ),
      );
    }

    return UdPage(
      eyebrow: appName,
      title: context.tr('home_title'),
      subtitle: context.tr('home_sub'),
      actions: const [UdSettingsButton(appName: appName)],
      dock: UdDock(
        label: context.tr('start'),
        icon: Icons.play_arrow_rounded,
        onPressed: () {
          final bots = [for (var i = 0; i < _count; i++) _bots[i]];
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => GamePage(mode: _mode, colors: colors, bots: bots),
          ));
        },
      ),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            UdLabel(context.tr('mode')),
            modeCard(LudoMode.classic, Icons.grid_view_rounded),
            modeCard(LudoMode.quick, Icons.bolt_rounded),
            modeCard(LudoMode.rush, Icons.flag_rounded),
            const SizedBox(height: 10),
            UdLabel(context.tr('players')),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
                ButtonSegment(value: 4, label: Text('4')),
              ],
              selected: {_count},
              onSelectionChanged: (s) => setState(() => _count = s.first),
            ),
            const SizedBox(height: 14),
            for (var seat = 0; seat < _count; seat++)
              UdRow(
                leading: LudoToken(color: kLudoColors[colors[seat]], size: 36),
                title: context.tr('c${colors[seat]}'),
                subtitle: context.tr(_bots[seat] ? 'computer' : 'human'),
                trailing: Switch(
                  value: !_bots[seat],
                  onChanged: (v) => setState(() => _bots[seat] = !v),
                ),
                onTap: () => setState(() => _bots[seat] = !_bots[seat]),
              ),
            const SizedBox(height: 8),
            Text(context.tr('rules'), style: text.bodySmall),
          ]),
        ),
      ],
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.mode, required this.colors, required this.bots});
  final LudoMode mode;
  final List<int> colors;
  final List<bool> bots;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late LudoGame _game;
  bool _busy = false;
  int _face = 1;
  final _rng = Random();
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
    _game = LudoGame(mode: widget.mode, bots: widget.bots, colors: widget.colors);
    _busy = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBot());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  void _maybeBot() {
    if (_disposed || _game.over || !_game.player.bot) return;
    _wait(650).then((_) => _roll());
  }

  Future<void> _roll() async {
    if (_busy || _game.rolled || _game.over || _disposed) return;
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    for (var i = 0; i < 7; i++) {
      await _wait(55);
      if (_disposed) return;
      setState(() => _face = _rng.nextInt(6) + 1);
    }
    final options = _game.roll();
    setState(() => _face = _game.dice!);
    if (options.isEmpty) {
      await _wait(900);
      if (_disposed) return;
      _game.nextTurn();
      setState(() => _busy = false);
      _maybeBot();
      return;
    }
    if (_game.player.bot) {
      await _wait(450);
      if (_disposed) return;
      await _move(_game.chooseForBot(options));
      return;
    }
    if (options.length == 1 || _allSame(options)) {
      await _wait(300);
      if (_disposed) return;
      await _move(options.first);
      return;
    }
    setState(() => _busy = false); // wait for the player's tap
  }

  /// All options move from the same square (e.g. all in the yard).
  bool _allSame(List<int> options) {
    final tokens = _game.player.tokens;
    return options.every((i) => tokens[i] == tokens[options.first]);
  }

  Future<void> _move(int token) async {
    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    final again = _game.move(token);
    if (_game.lastEvent == 'capture') HapticFeedback.heavyImpact();
    await _wait(420);
    if (_disposed) return;
    if (_game.over) {
      setState(() => _busy = false);
      _showResults();
      return;
    }
    _game.nextTurn(samePlayer: again);
    setState(() => _busy = false);
    _maybeBot();
  }

  String _name(int playerIndex) {
    final p = _game.players[playerIndex];
    final c = context.tr('c${p.color}');
    return p.bot ? '$c · ${context.tr('computer')}' : c;
  }

  void _showResults() {
    final order = [
      ..._game.ranking,
      for (var i = 0; i < _game.players.length; i++)
        if (!_game.ranking.contains(i)) i,
    ];
    showUdSheet<void>(context, (c) {
      final text = Theme.of(c).textTheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.tr('winner', {'p': _name(order.first)}), style: text.headlineMedium),
          const SizedBox(height: 16),
          for (var i = 0; i < order.length; i++)
            UdRow(
              leading: LudoToken(color: kLudoColors[_game.players[order[i]].color], size: 34),
              title: '${i + 1}. ${_name(order[i])}',
              trailing: i == 0 ? const Icon(Icons.emoji_events_rounded, color: Color(0xFFD9A11E)) : null,
            ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(c);
                  Navigator.pop(context);
                },
                child: Text(c.tr('new_game')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(c);
                  setState(_newGame);
                },
                child: Text(c.tr('play_again')),
              ),
            ),
          ]),
        ],
      );
    });
  }

  Future<bool> _confirmQuit() async {
    if (_game.over) return true;
    return udConfirm(context,
        title: context.tr('quit'), body: context.tr('quit_sub'), confirmLabel: context.tr('leave'));
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final game = _game;
    final movable = (!_busy && !game.player.bot) ? game.movableTokens() : const <int>[];
    final turnColor = kLudoColors[game.player.color];

    String status;
    if (game.lastEvent != null && game.rolled == false && !_busy) {
      status = context.tr('ev_${game.lastEvent}');
    } else if (game.lastEvent == 'skip') {
      status = context.tr('ev_skip');
    } else if (game.player.bot) {
      status = context.tr('thinking');
    } else if (movable.isNotEmpty) {
      status = context.tr('tap_token');
    } else if (game.rolled && !_busy) {
      status = context.tr('no_move');
    } else {
      status = context.tr('tap_roll');
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmQuit()) nav.pop();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    UdIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () async {
                        final nav = Navigator.of(context);
                        if (await _confirmQuit()) nav.pop();
                      },
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(context.tr('m_${widget.mode.name}'), style: text.headlineSmall),
                    ),
                    for (var i = 0; i < game.players.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _PlayerPip(
                          color: kLudoColors[game.players[i].color],
                          done: game.players[i].finishedCount,
                          total: game.players[i].tokens.length,
                          active: i == game.current,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: LayoutBuilder(builder: (context, box) {
                        final size = box.maxWidth;
                        final cell = size / 15;
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(cell * 0.6),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.10),
                                  blurRadius: 30,
                                  offset: const Offset(0, 12)),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: LudoBoardPainter(
                                      paper: const Color(0xFFFFFCF5), line: const Color(0xFFE2D9C6), ink: t.ink),
                                ),
                              ),
                              ..._tokens(cell, movable),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: t.ink,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    children: [
                      LudoToken(color: turnColor, size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('turn', {'p': _name(game.current)}),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleMedium?.copyWith(color: t.paper)),
                            Text(status,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall?.copyWith(color: t.paper.withValues(alpha: 0.7))),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: game.player.bot ? null : _roll,
                        child: AnimatedScale(
                          scale: (!game.rolled && !_busy && !game.player.bot) ? 1.08 : 1,
                          duration: const Duration(milliseconds: 300),
                          child: Transform.rotate(
                            angle: _busy && !game.rolled ? (_face - 3) * 0.12 : 0,
                            child: DiceFace(value: _face, size: 58, color: turnColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _tokens(double cell, List<int> movable) {
    final game = _game;
    // Group tokens by square so stacked tokens can sit side by side.
    final groups = <String, List<(int, int)>>{};
    for (var pIdx = 0; pIdx < game.players.length; pIdx++) {
      final p = game.players[pIdx];
      for (var ti = 0; ti < p.tokens.length; ti++) {
        final (r, c) = game.cellOf(p.color, ti, p.tokens[ti]);
        groups.putIfAbsent('${r.toStringAsFixed(2)},${c.toStringAsFixed(2)}', () => []).add((pIdx, ti));
      }
    }
    final out = <Widget>[];
    for (var pIdx = 0; pIdx < game.players.length; pIdx++) {
      final p = game.players[pIdx];
      for (var ti = 0; ti < p.tokens.length; ti++) {
        final (r, c) = game.cellOf(p.color, ti, p.tokens[ti]);
        final group = groups['${r.toStringAsFixed(2)},${c.toStringAsFixed(2)}']!;
        final n = group.length;
        final idx = group.indexOf((pIdx, ti));
        final finished = p.tokens[ti] == kFinished;
        var size = cell * (finished ? 0.55 : 0.82);
        var dx = 0.0, dy = 0.0;
        if (n > 1 && !finished) {
          size = cell * 0.6;
          final a = idx * 2 * pi / n;
          dx = cos(a) * cell * 0.2;
          dy = sin(a) * cell * 0.2;
        }
        final active = pIdx == game.current && movable.contains(ti);
        out.add(AnimatedPositioned(
          key: ValueKey('tok-$pIdx-$ti'),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          left: (c + 0.5) * cell - size / 2 + dx,
          top: (r + 0.5) * cell - size / 2 + dy,
          width: size,
          height: size,
          child: GestureDetector(
            onTap: active ? () => _move(ti) : null,
            child: LudoToken(color: kLudoColors[p.color], size: size, active: active),
          ),
        ));
      }
    }
    // Active tokens on top so they are easy to tap.
    out.sort((a, b) {
      bool act(Widget w) => ((w as AnimatedPositioned).child as GestureDetector).onTap != null;
      return (act(a) ? 1 : 0) - (act(b) ? 1 : 0);
    });
    return out;
  }
}

class _PlayerPip extends StatelessWidget {
  const _PlayerPip({required this.color, required this.done, required this.total, required this.active});
  final Color color;
  final int done;
  final int total;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: active ? color : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text('$done/$total',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: active ? Colors.white : color)),
    );
  }
}
