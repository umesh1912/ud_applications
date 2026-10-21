import 'package:flutter/material.dart';

import '../data/questions.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'challenge_screen.dart';
import 'launcher.dart';
import 'leaderboard_screen.dart';
import 'onboarding_screen.dart';
import 'pass_play_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _switchPlayer(BuildContext context) async {
    final store = StoreScope.read(context);
    final current = store.active;
    if (current != null && current.isKid && store.settings.parentPin != null) {
      if (!await askParentPin(context)) return;
    }
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(store.t('Who\'s playing?', 'कौन खेल रहा है?'), style: ctx.tt.headlineSmall),
            const SizedBox(height: 12),
            for (final p in store.profiles)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Sticker(
                  depth: 3,
                  color: p.id == store.active?.id ? const Color(0xFFFFD23F) : null,
                  onTap: () {
                    store.switchTo(p);
                    Navigator.pop(ctx);
                  },
                  child: Row(
                    children: [
                      AvatarDot(profile: p, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: ctx.tt.titleMedium!.copyWith(
                              color: p.id == store.active?.id ? const Color(0xFF1C1B2E) : null,
                            )),
                            Text(p.group.label.of(store.lang), style: ctx.tt.bodySmall!.copyWith(
                              color: p.id == store.active?.id ? const Color(0xFF1C1B2E) : null,
                            )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            SoftButton(
              icon: Icons.person_add_alt_1_rounded,
              label: store.t('Add a player', 'खिलाड़ी जोड़ें'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingScreen(addingPlayer: true)));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final p = store.active!;
    final sc = context.sc;
    final lang = store.lang;

    void open(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                Semantics(
                  button: true,
                  label: store.t('Switch player', 'खिलाड़ी बदलें'),
                  child: GestureDetector(onTap: () => _switchPlayer(context), child: AvatarDot(profile: p, size: 52)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: context.tt.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(store.t('Level ${p.level}', 'लेवल ${p.level}'), style: context.tt.labelMedium),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: sc.card,
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(color: sc.line, width: 1.6),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: p.levelProgress.clamp(0.02, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(color: const Color(0xFF7BD957), borderRadius: BorderRadius.circular(99)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                CoinPill(coins: p.coins),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(tooltip: store.t('Leaderboard', 'लीडरबोर्ड'), onPressed: () => open(const LeaderboardScreen()), icon: const Icon(Icons.emoji_events_outlined)),
                IconButton(tooltip: store.t('My progress', 'मेरी प्रगति'), onPressed: () => open(const ProfileScreen()), icon: const Icon(Icons.insights_rounded)),
                IconButton(tooltip: store.t('Settings', 'सेटिंग्स'), onPressed: () => open(const SettingsScreen()), icon: const Icon(Icons.settings_outlined)),
              ],
            ),

            // The daily quiz is the hero: one per day, keeps the streak going.
            Sticker(
              color: store.dailyDone ? sc.card : sc.primary,
              onTap: store.dailyDone ? null : () => startQuiz(context, dailyPlay(store)),
              padding: const EdgeInsets.all(18),
              semanticLabel: store.t('Daily quiz', 'आज का क्विज़'),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.dailyDone ? store.t('Daily quiz done', 'आज का क्विज़ पूरा') : store.t('Today\'s quiz', 'आज का क्विज़'),
                          style: context.tt.headlineMedium!.copyWith(color: store.dailyDone ? sc.ink : const Color(0xFF1C1B2E)),
                        ),
                        Text(
                          store.dailyDone
                              ? store.t('New questions tomorrow. Try Rapid fire meanwhile.', 'कल नए सवाल आएँगे। तब तक रैपिड फ़ायर खेलें।')
                              : store.t('5 questions · +15 bonus coins', '5 सवाल · +15 बोनस सिक्के'),
                          style: context.tt.bodyMedium!.copyWith(color: store.dailyDone ? sc.muted : const Color(0xFF1C1B2E)),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Icon(Icons.local_fire_department_rounded,
                          size: 36, color: store.dailyDone ? const Color(0xFFFF7A2F) : const Color(0xFF1C1B2E)),
                      Text(store.t('${p.streak} day${p.streak == 1 ? '' : 's'}', '${p.streak} दिन'),
                          style: context.tt.labelMedium!.copyWith(color: store.dailyDone ? sc.ink : const Color(0xFF1C1B2E))),
                    ],
                  ),
                ],
              ),
            ),
            if (p.isKid && p.dailyLimitMin != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  store.t('${(p.dailyLimitMin! - p.minutesUsedToday()).clamp(0, 999)} minutes of play left today',
                      'आज खेलने के ${(p.dailyLimitMin! - p.minutesUsedToday()).clamp(0, 999)} मिनट बाकी'),
                  style: context.tt.bodySmall,
                ),
              ),

            Heading(store.t('Ways to play', 'खेलने के तरीके')),
            Pairs(
              children: [
                _Mode(icon: Icons.play_arrow_rounded, color: const Color(0xFF7BD957), title: store.t('Quick play', 'झटपट खेल'),
                    sub: store.t('10 mixed questions', '10 मिले-जुले सवाल'), onTap: () => startQuiz(context, quickPlay(store))),
                _Mode(icon: Icons.speed_rounded, color: const Color(0xFFFF5D6C), title: store.t('Rapid fire', 'रैपिड फ़ायर'),
                    sub: store.t('60 seconds, go!', '60 सेकंड, शुरू!'), onTap: () => startQuiz(context, rapidPlay(store))),
                _Mode(icon: Icons.smart_toy_rounded, color: const Color(0xFF7C8CFF), title: store.t('Battle the computer', 'कंप्यूटर से मुकाबला'),
                    sub: store.t('1 vs 1, 7 rounds', '1 बनाम 1, 7 राउंड'), onTap: () => startBattleGuarded(context)),
                _Mode(icon: Icons.groups_rounded, color: const Color(0xFFFFB13B), title: store.t('Pass & play', 'बारी-बारी से'),
                    sub: store.t('2–4 players, one phone', '2–4 खिलाड़ी, एक फ़ोन'), onTap: () => open(const PassPlaySetupScreen())),
                _Mode(icon: Icons.send_rounded, color: const Color(0xFF2EC4B6), title: store.t('Challenge a friend', 'दोस्त को चुनौती'),
                    sub: store.t('Share a code', 'कोड भेजें'), onTap: () => open(const ChallengeScreen())),
                _Mode(icon: Icons.emoji_events_rounded, color: const Color(0xFFFFD23F), title: store.t('Leaderboard', 'लीडरबोर्ड'),
                    sub: store.t('This week\'s scores', 'इस हफ़्ते के स्कोर'), onTap: () => open(const LeaderboardScreen())),
              ],
            ),

            if (p.missed.isNotEmpty) ...[
              const SizedBox(height: 8),
              Sticker(
                onTap: () => startQuiz(context, reviewPlay(store)),
                child: Row(
                  children: [
                    const IconBlob(icon: Icons.school_rounded, color: Color(0xFFFF8FC0)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(store.t('Learn mode', 'सीखो मोड'), style: context.tt.titleMedium),
                          Text(store.t('Practise ${p.missed.length} questions you got wrong', 'गलत हुए ${p.missed.length} सवालों का अभ्यास करें'),
                              style: context.tt.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: sc.ink),
                  ],
                ),
              ),
            ],

            Heading(store.t('Pick a topic', 'विषय चुनें')),
            Pairs(
              children: [
                for (final c in Cat.values)
                  Sticker(
                    color: c.color,
                    depth: 3,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    onTap: () => startQuiz(context, categoryPlay(store, c)),
                    semanticLabel: c.name.of(lang),
                    child: Row(
                      children: [
                        Icon(c.icon, color: const Color(0xFF1C1B2E)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(c.name.of(lang),
                              maxLines: 2,
                              style: context.tt.titleSmall!.copyWith(color: const Color(0xFF1C1B2E))),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Mode extends StatelessWidget {
  const _Mode({required this.icon, required this.color, required this.title, required this.sub, required this.onTap});

  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Sticker(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      semanticLabel: '$title. $sub',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBlob(icon: icon, color: color, size: 40),
          const SizedBox(height: 10),
          Text(title, style: context.tt.titleMedium),
          Text(sub, style: context.tt.bodySmall),
        ],
      ),
    );
  }
}
