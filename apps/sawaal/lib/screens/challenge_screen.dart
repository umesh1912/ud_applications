import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/questions.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'quiz_screen.dart';

/// Challenge a friend without any server: a short code (e.g. SCI-4821)
/// picks the same 7 questions on every phone.
const _prefix = {
  'IND': Cat.india,
  'SCI': Cat.science,
  'HIS': Cat.history,
  'GEO': Cat.geography,
  'SPO': Cat.sports,
  'FLG': Cat.flags,
  'NAT': Cat.nature,
  'SPA': Cat.space,
  'BKS': Cat.books,
  'MTH': Cat.maths,
};

String _codeFor(Cat? cat, int seed) {
  final p = cat == null ? 'MIX' : _prefix.entries.firstWhere((e) => e.value == cat).key;
  return '$p-$seed';
}

/// Returns the questions for a code, or null if the code is not valid.
List<Q>? questionsForCode(String raw) {
  final code = raw.trim().toUpperCase().replaceAll(' ', '');
  final m = RegExp(r'^([A-Z]{3})-?(\d{4})$').firstMatch(code);
  if (m == null) return null;
  final p = m.group(1)!;
  if (p != 'MIX' && !_prefix.containsKey(p)) return null;
  final cat = _prefix[p];
  final seed = int.parse(m.group(2)!);
  final pool = questionBank.where((q) => cat == null || q.cat == cat).toList()
    ..sort((a, b) => a.id.compareTo(b.id)); // stable order on every phone
  pool.shuffle(Random(seed));
  return pool.take(7).toList();
}

String normaliseCode(String raw) {
  final c = raw.trim().toUpperCase().replaceAll(' ', '');
  return c.contains('-') ? c : '${c.substring(0, 3)}-${c.substring(3)}';
}

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  Cat? _cat;
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _play(String code, List<Q> qs) {
    final store = StoreScope.read(context);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizScreen(
        config: QuizConfig(
          title: store.t('Challenge $code', 'चुनौती $code'),
          mode: 'challenge',
          questions: qs,
          perQuestionSeconds: 20,
          lifelines: false,
          challengeCode: code,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final lang = store.lang;
    return Scaffold(
      appBar: AppBar(title: Text(store.t('Challenge a friend', 'दोस्त को चुनौती'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Text(
            store.t('Both of you play the same 7 questions with the same code. Compare scores after.',
                'एक ही कोड से आप दोनों को वही 7 सवाल मिलेंगे। बाद में स्कोर मिलाएँ।'),
            style: context.tt.bodyLarge,
          ),
          Heading(store.t('Got a code?', 'कोड मिला है?')),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            style: context.tt.headlineSmall,
            decoration: InputDecoration(hintText: 'SCI-4821', errorText: _error),
          ),
          const SizedBox(height: 10),
          BigButton(
            label: store.t('Play this challenge', 'यह चुनौती खेलें'),
            icon: Icons.play_arrow_rounded,
            onTap: () {
              final qs = questionsForCode(_code.text);
              if (qs == null || qs.isEmpty) {
                setState(() => _error = store.t('Codes look like SCI-4821. Check the letters and 4 digits.',
                    'कोड SCI-4821 जैसा होता है। अक्षर और 4 अंक जाँचें।'));
                return;
              }
              setState(() => _error = null);
              _play(normaliseCode(_code.text), qs);
            },
          ),
          Heading(store.t('Or make a new one', 'या नया बनाएँ')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CatChoice(label: store.t('Mixed', 'मिला-जुला'), color: const Color(0xFFFFFFFF), selected: _cat == null, onTap: () => setState(() => _cat = null)),
              for (final c in Cat.values)
                _CatChoice(label: c.name.of(lang), color: c.color, selected: _cat == c, onTap: () => setState(() => _cat = c)),
            ],
          ),
          const SizedBox(height: 16),
          BigButton(
            label: store.t('Create code and play', 'कोड बनाएँ और खेलें'),
            icon: Icons.bolt_rounded,
            onTap: () {
              final code = _codeFor(_cat, 1000 + Random().nextInt(9000));
              Clipboard.setData(ClipboardData(text: code));
              toast(context, store.t('Code $code copied. Send it to your friend.', 'कोड $code कॉपी हो गया। दोस्त को भेजें।'));
              _play(code, questionsForCode(code)!);
            },
          ),
        ],
      ),
    );
  }
}

class _CatChoice extends StatelessWidget {
  const _CatChoice({required this.label, required this.color, required this.selected, required this.onTap});

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Sticker(
      color: selected ? color : context.sc.card,
      depth: selected ? 1 : 3,
      radius: 99,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      onTap: onTap,
      semanticLabel: selected ? '$label, selected' : label,
      child: Text(label,
          style: context.tt.labelMedium!.copyWith(color: selected ? const Color(0xFF1C1B2E) : context.sc.ink)),
    );
  }
}
