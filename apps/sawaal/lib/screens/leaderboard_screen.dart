import 'dart:math';

import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class _Row {
  _Row(this.name, this.score, {this.me = false, this.bot = false, this.profile});
  final String name;
  final int score;
  final bool me;
  final bool bot;
  final Profile? profile;
}

/// Two boards: everyone who plays on this phone, and a weekly league against
/// computer players (clearly labelled) until online leaderboards are added.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _league = false;

  static const _botNames = ['Chatur', 'Gyani', 'Tez', 'Budhi', 'Pandit', 'Sitara', 'Jugnu', 'Toofan', 'Moti'];

  List<_Row> _phoneRows(Store s) {
    final wk = weekKeyOf(DateTime.now());
    final rows = [
      for (final p in s.profiles) _Row(p.name, p.weekKey == wk ? p.weekScore : 0, me: p.id == s.active?.id, profile: p),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return rows;
  }

  List<_Row> _leagueRows(Store s) {
    final me = s.active!;
    final wk = weekKeyOf(DateTime.now());
    final myScore = me.weekKey == wk ? me.weekScore : 0;
    // Computer players scale with your level so the league stays competitive.
    final r = Random(wk.hashCode ^ me.id.hashCode);
    final dayOfWeek = DateTime.now().weekday;
    final base = 60 + me.level * 25;
    final rows = [
      for (final n in _botNames) _Row('$n (computer)', (base * (0.4 + r.nextDouble()) * dayOfWeek / 3).round(), bot: true),
      _Row(me.name, myScore, me: true, profile: me),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final sc = context.sc;
    final rows = _league ? _leagueRows(store) : _phoneRows(store);
    final myRank = rows.indexWhere((r) => r.me) + 1;

    return Scaffold(
      appBar: AppBar(title: Text(store.t('Leaderboard', 'लीडरबोर्ड'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Row(
            children: [
              for (final (league, label) in [(false, store.t('This phone', 'यह फ़ोन')), (true, store.t('Weekly league', 'साप्ताहिक लीग'))]) ...[
                Expanded(
                  child: Sticker(
                    depth: 3,
                    color: _league == league ? const Color(0xFFFFD23F) : null,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    onTap: () => setState(() => _league = league),
                    semanticLabel: _league == league ? '$label, selected' : label,
                    child: Text(label,
                        textAlign: TextAlign.center,
                        style: context.tt.labelLarge!.copyWith(color: _league == league ? const Color(0xFF1C1B2E) : null)),
                  ),
                ),
                if (!league) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _league
                ? store.t('You against computer players. Scores reset every Monday.', 'आप बनाम कंप्यूटर खिलाड़ी। स्कोर हर सोमवार रीसेट होते हैं।')
                : store.t('Points scored this week by everyone on this phone.', 'इस फ़ोन पर सभी के इस हफ़्ते के अंक।'),
            style: context.tt.bodySmall,
          ),
          if (myRank > 0) ...[
            const SizedBox(height: 10),
            Sticker(
              color: sc.primary,
              child: Text(
                store.t('You are #$myRank this week', 'इस हफ़्ते आप #$myRank पर हैं'),
                style: context.tt.headlineSmall!.copyWith(color: const Color(0xFF1C1B2E)),
              ),
            ),
          ],
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Sticker(
                depth: 2,
                color: rows[i].me ? const Color(0xFFFFD23F) : null,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 34,
                      child: Text('${i + 1}', style: context.tt.headlineSmall!.copyWith(color: rows[i].me ? const Color(0xFF1C1B2E) : null)),
                    ),
                    if (rows[i].profile != null)
                      AvatarDot(profile: rows[i].profile!, size: 34)
                    else
                      const IconBlob(icon: Icons.smart_toy, color: Color(0xFF7C8CFF), size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(rows[i].name,
                          style: context.tt.titleMedium!.copyWith(color: rows[i].me ? const Color(0xFF1C1B2E) : null)),
                    ),
                    Text('${rows[i].score}',
                        style: context.tt.titleLarge!.copyWith(color: rows[i].me ? const Color(0xFF1C1B2E) : null)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
