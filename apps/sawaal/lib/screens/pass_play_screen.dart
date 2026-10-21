import 'package:flutter/material.dart';

import '../data/questions.dart';
import '../question_view.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Setup for pass-and-play: 2–4 people take turns on one phone.
class PassPlaySetupScreen extends StatefulWidget {
  const PassPlaySetupScreen({super.key});

  @override
  State<PassPlaySetupScreen> createState() => _PassPlaySetupScreenState();
}

class _PassPlaySetupScreenState extends State<PassPlaySetupScreen> {
  final List<TextEditingController> _names = [];
  int _rounds = 3;

  @override
  void initState() {
    super.initState();
    final store = StoreScope.read(context);
    final fromProfiles = store.profiles.map((p) => p.name).take(4).toList();
    while (fromProfiles.length < 2) {
      fromProfiles.add(store.t('Player ${fromProfiles.length + 1}', 'खिलाड़ी ${fromProfiles.length + 1}'));
    }
    _names.addAll(fromProfiles.map((n) => TextEditingController(text: n)));
  }

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Scaffold(
      appBar: AppBar(title: Text(store.t('Pass & play', 'बारी-बारी से खेलें'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(store.t('Take turns on one phone. Each player gets their own question each round.',
                  'एक ही फ़ोन पर बारी-बारी से खेलें। हर राउंड में हर खिलाड़ी को अपना सवाल मिलेगा।'),
              style: context.tt.bodyLarge),
          Heading(store.t('Players', 'खिलाड़ी')),
          for (var i = 0; i < _names.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _names[i],
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: store.t('Player ${i + 1}', 'खिलाड़ी ${i + 1}')),
                    ),
                  ),
                  if (_names.length > 2)
                    IconButton(
                      tooltip: store.t('Remove player', 'खिलाड़ी हटाएँ'),
                      onPressed: () {
                        final removed = _names.removeAt(i);
                        setState(() {});
                        WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                ],
              ),
            ),
          if (_names.length < 4)
            SoftButton(
              icon: Icons.person_add_alt_1_rounded,
              label: store.t('Add a player', 'खिलाड़ी जोड़ें'),
              onTap: () => setState(() => _names.add(TextEditingController())),
            ),
          Heading(store.t('Rounds', 'राउंड')),
          Row(
            children: [
              for (final r in const [3, 5, 7]) ...[
                Expanded(
                  child: Sticker(
                    color: _rounds == r ? const Color(0xFFFFD23F) : null,
                    depth: 3,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onTap: () => setState(() => _rounds = r),
                    child: Text('$r', textAlign: TextAlign.center, style: context.tt.headlineSmall!.copyWith(
                      color: _rounds == r ? const Color(0xFF1C1B2E) : null,
                    )),
                  ),
                ),
                if (r != 7) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 24),
          BigButton(
            label: store.t('Start game', 'खेल शुरू करें'),
            icon: Icons.play_arrow_rounded,
            onTap: () {
              final names = [
                for (var i = 0; i < _names.length; i++)
                  _names[i].text.trim().isEmpty ? store.t('Player ${i + 1}', 'खिलाड़ी ${i + 1}') : _names[i].text.trim(),
              ];
              final pool = store.poolFor(types: {QType.mcq, QType.trueFalse, QType.picture});
              final qs = store.pick(pool, names.length * _rounds);
              if (qs.length < names.length) {
                toast(context, store.t('Not enough questions for this group yet.', 'इस समूह के लिए अभी पर्याप्त सवाल नहीं हैं।'));
                return;
              }
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => PassPlayScreen(players: names, questions: qs),
              ));
            },
          ),
        ],
      ),
    );
  }
}

class PassPlayScreen extends StatefulWidget {
  const PassPlayScreen({super.key, required this.players, required this.questions});

  final List<String> players;
  final List<Q> questions;

  @override
  State<PassPlayScreen> createState() => _PassPlayScreenState();
}

class _PassPlayScreenState extends State<PassPlayScreen> {
  late final List<int> _scores = List.filled(widget.players.length, 0);
  int _turn = 0; // index into questions
  bool _handoff = true; // show "pass the phone" card first
  bool _revealed = false;
  int? _chosen;

  int get _player => _turn % widget.players.length;
  bool get _over => _turn >= widget.questions.length;

  void _choose(int i) {
    if (_revealed) return;
    final q = widget.questions[_turn];
    setState(() {
      _chosen = i;
      _revealed = true;
      if (i == q.answer) _scores[_player] += 10;
    });
  }

  void _next() {
    setState(() {
      _turn++;
      _handoff = true;
      _revealed = false;
      _chosen = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final sc = context.sc;
    final rounds = widget.questions.length ~/ widget.players.length;

    if (_over) {
      final order = List.generate(widget.players.length, (i) => i)..sort((a, b) => _scores[b].compareTo(_scores[a]));
      final top = _scores[order.first];
      final winners = order.where((i) => _scores[i] == top).map((i) => widget.players[i]).toList();
      return Scaffold(
        appBar: AppBar(title: Text(store.t('Final scores', 'अंतिम स्कोर'))),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Sticker(
              color: sc.primary,
              child: Text(
                winners.length > 1
                    ? store.t('It\'s a tie: ${winners.join(' & ')}', 'बराबरी: ${winners.join(' और ')}')
                    : store.t('${winners.first} wins!', '${winners.first} जीते!'),
                textAlign: TextAlign.center,
                style: context.tt.headlineMedium!.copyWith(color: const Color(0xFF1C1B2E)),
              ),
            ),
            const SizedBox(height: 8),
            for (var r = 0; r < order.length; r++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Sticker(
                  depth: 2,
                  child: Row(
                    children: [
                      Text('${r + 1}', style: context.tt.headlineSmall),
                      const SizedBox(width: 14),
                      Expanded(child: Text(widget.players[order[r]], style: context.tt.titleMedium)),
                      Text('${_scores[order[r]]}', style: context.tt.headlineSmall),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            BigButton(label: store.t('Done', 'हो गया'), onTap: () => Navigator.of(context).pop()),
          ],
        ),
      );
    }

    final name = widget.players[_player];
    final round = _turn ~/ widget.players.length + 1;

    return Scaffold(
      appBar: AppBar(title: Text(store.t('Round $round of $rounds', 'राउंड $round / $rounds'))),
      body: SafeArea(
        child: _handoff
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.phone_android_rounded, size: 72, color: sc.ink),
                    const SizedBox(height: 12),
                    Text(store.t('Pass the phone to', 'फ़ोन दीजिए'), textAlign: TextAlign.center, style: context.tt.titleLarge),
                    Text(name, textAlign: TextAlign.center, style: context.tt.displaySmall),
                    const SizedBox(height: 24),
                    BigButton(
                      label: store.t('I\'m $name — show my question', 'मैं $name हूँ — सवाल दिखाएँ'),
                      onTap: () => setState(() => _handoff = false),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < widget.players.length; i++)
                          Text('${widget.players[i]}: ${_scores[i]}', style: context.tt.labelLarge),
                      ],
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      children: [
                        Text(store.t('$name\'s turn', '$name की बारी'), style: context.tt.labelLarge!.copyWith(color: sc.primary)),
                        const SizedBox(height: 8),
                        QuestionView(
                          q: widget.questions[_turn],
                          revealed: _revealed,
                          chosen: _chosen,
                          onChoose: _choose,
                          onType: (_) {},
                        ),
                        if (_revealed) ...[
                          const SizedBox(height: 6),
                          Text(widget.questions[_turn].explain.of(store.lang), style: context.tt.bodyLarge),
                        ],
                      ],
                    ),
                  ),
                  if (_revealed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: BigButton(
                        label: _turn == widget.questions.length - 1
                            ? store.t('See final scores', 'अंतिम स्कोर देखें')
                            : store.t('Next player', 'अगला खिलाड़ी'),
                        icon: Icons.arrow_forward_rounded,
                        onTap: _next,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
