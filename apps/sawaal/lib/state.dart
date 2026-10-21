import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/questions.dart';

enum AgeGroup { kids, school, college, adult }

extension AgeGroupX on AgeGroup {
  L get label => switch (this) {
        AgeGroup.kids => const L('Kids, 5–10', 'बच्चे, 5–10'),
        AgeGroup.school => const L('School, 11–17', 'स्कूल, 11–17'),
        AgeGroup.college => const L('College & young adults', 'कॉलेज और युवा'),
        AgeGroup.adult => const L('Adults & seniors', 'वयस्क और वरिष्ठ'),
      };
  int get secondsPerQuestion => switch (this) {
        AgeGroup.kids => 30,
        AgeGroup.adult => 30,
        _ => 20,
      };
  Set<Level> get levels => levelsFor(index);
}

class Avatar {
  const Avatar(this.icon, this.color);
  final IconData icon;
  final Color color;
}

const avatars = [
  Avatar(Icons.pets, Color(0xFFFF8A3D)),
  Avatar(Icons.rocket_launch, Color(0xFF7C8CFF)),
  Avatar(Icons.local_florist, Color(0xFFFF8FC0)),
  Avatar(Icons.sports_soccer, Color(0xFF7BD957)),
  Avatar(Icons.music_note, Color(0xFFB58CFF)),
  Avatar(Icons.bolt, Color(0xFFFFD23F)),
  Avatar(Icons.wb_sunny, Color(0xFFFFB13B)),
  Avatar(Icons.water_drop, Color(0xFF3BA7FF)),
];

class Award {
  const Award(this.id, this.name, this.how, this.icon);
  final String id;
  final L name;
  final L how;
  final IconData icon;
}

const badges = [
  Award('first', L('First quiz', 'पहला क्विज़'), L('Finish any quiz', 'कोई भी क्विज़ पूरा करें'), Icons.flag),
  Award('perfect', L('Full marks', 'पूरे अंक'), L('Get every answer right in a quiz', 'किसी क्विज़ में सभी जवाब सही दें'), Icons.workspace_premium),
  Award('streak3', L('3-day streak', '3 दिन लगातार'), L('Play 3 days in a row', 'लगातार 3 दिन खेलें'), Icons.local_fire_department),
  Award('streak7', L('7-day streak', '7 दिन लगातार'), L('Play 7 days in a row', 'लगातार 7 दिन खेलें'), Icons.whatshot),
  Award('rapid10', L('Quick thinker', 'तेज़ दिमाग'), L('Get 10 right in Rapid fire', 'रैपिड फ़ायर में 10 सही जवाब दें'), Icons.speed),
  Award('botwin', L('Beat the bot', 'रोबोट को हराया'), L('Win a battle against the computer', 'कंप्यूटर से मुकाबला जीतें'), Icons.smart_toy),
  Award('hundred', L('Century', 'शतक'), L('Answer 100 questions', '100 सवालों के जवाब दें'), Icons.military_tech),
  Award('allcats', L('All-rounder', 'ऑल-राउंडर'), L('Play every category', 'हर श्रेणी खेलें'), Icons.auto_awesome),
];

class Profile {
  Profile({
    required this.id,
    required this.name,
    required this.group,
    this.avatar = 0,
    this.coins = 50,
    this.xp = 0,
    this.streak = 0,
    this.lastPlayedDay,
    Set<String>? badges,
    List<String>? missed,
    Map<String, int>? catAnswered,
    Map<String, int>? catCorrect,
    this.answered = 0,
    this.correct = 0,
    this.weekScore = 0,
    this.weekKey = '',
    this.bestRapid = 0,
    this.secondsToday = 0,
    this.secondsDay = '',
    this.dailyLimitMin,
    this.dailyDoneDay,
  })  : badges = badges ?? {},
        missed = missed ?? [],
        catAnswered = catAnswered ?? {},
        catCorrect = catCorrect ?? {};

  final String id;
  String name;
  AgeGroup group;
  int avatar;
  int coins;
  int xp;
  int streak;
  String? lastPlayedDay;
  final Set<String> badges;
  final List<String> missed;
  final Map<String, int> catAnswered;
  final Map<String, int> catCorrect;
  int answered;
  int correct;
  int weekScore;
  String weekKey;
  int bestRapid;
  int secondsToday;
  String secondsDay;
  int? dailyLimitMin; // kids only; null = no limit
  String? dailyDoneDay;

  int get level => xp ~/ 250 + 1;
  double get levelProgress => (xp % 250) / 250;
  bool get isKid => group == AgeGroup.kids;
  Avatar get avatarData => avatars[avatar % avatars.length];

  int minutesUsedToday() => secondsDay == dayKey(DateTime.now()) ? secondsToday ~/ 60 : 0;

  bool get limitReached {
    if (!isKid || dailyLimitMin == null) return false;
    return minutesUsedToday() >= dailyLimitMin!;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'group': group.index,
        'avatar': avatar,
        'coins': coins,
        'xp': xp,
        'streak': streak,
        'lastPlayedDay': lastPlayedDay,
        'badges': badges.toList(),
        'missed': missed,
        'catAnswered': catAnswered,
        'catCorrect': catCorrect,
        'answered': answered,
        'correct': correct,
        'weekScore': weekScore,
        'weekKey': weekKey,
        'bestRapid': bestRapid,
        'secondsToday': secondsToday,
        'secondsDay': secondsDay,
        'dailyLimitMin': dailyLimitMin,
        'dailyDoneDay': dailyDoneDay,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        name: j['name'] as String,
        group: AgeGroup.values[(j['group'] as int?) ?? 1],
        avatar: (j['avatar'] as int?) ?? 0,
        coins: (j['coins'] as int?) ?? 0,
        xp: (j['xp'] as int?) ?? 0,
        streak: (j['streak'] as int?) ?? 0,
        lastPlayedDay: j['lastPlayedDay'] as String?,
        badges: ((j['badges'] as List?) ?? []).cast<String>().toSet(),
        missed: ((j['missed'] as List?) ?? []).cast<String>(),
        catAnswered: ((j['catAnswered'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, v as int)),
        catCorrect: ((j['catCorrect'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, v as int)),
        answered: (j['answered'] as int?) ?? 0,
        correct: (j['correct'] as int?) ?? 0,
        weekScore: (j['weekScore'] as int?) ?? 0,
        weekKey: (j['weekKey'] as String?) ?? '',
        bestRapid: (j['bestRapid'] as int?) ?? 0,
        secondsToday: (j['secondsToday'] as int?) ?? 0,
        secondsDay: (j['secondsDay'] as String?) ?? '',
        dailyLimitMin: j['dailyLimitMin'] as int?,
        dailyDoneDay: j['dailyDoneDay'] as String?,
      );
}

class Settings {
  String lang = 'en';
  int textSize = 0; // 0 normal, 1 large, 2 extra large
  bool highContrast = false;
  bool timer = true;
  bool readAloud = false;
  bool explanations = true;
  String? parentPin;

  double get textScale => const [1.0, 1.18, 1.35][textSize.clamp(0, 2)];

  Map<String, dynamic> toJson() => {
        'lang': lang,
        'textSize': textSize,
        'highContrast': highContrast,
        'timer': timer,
        'readAloud': readAloud,
        'explanations': explanations,
        'parentPin': parentPin,
      };

  void load(Map<String, dynamic> j) {
    lang = (j['lang'] as String?) ?? 'en';
    textSize = (j['textSize'] as int?) ?? 0;
    highContrast = (j['highContrast'] as bool?) ?? false;
    timer = (j['timer'] as bool?) ?? true;
    readAloud = (j['readAloud'] as bool?) ?? false;
    explanations = (j['explanations'] as bool?) ?? true;
    parentPin = j['parentPin'] as String?;
  }
}

/// One answered question in a finished game.
class AnswerRecord {
  AnswerRecord(this.q, this.correct, {this.chosen, this.typed, this.seconds = 0});
  final Q q;
  final bool correct;
  final int? chosen;
  final String? typed;
  final int seconds;
}

class GameResult {
  GameResult({
    required this.mode,
    required this.answers,
    required this.score,
    required this.seconds,
    this.wonBattle = false,
  });

  final String mode; // classic, daily, category, rapid, battle, review, challenge
  final List<AnswerRecord> answers;
  final int score;
  final int seconds;
  final bool wonBattle;

  int get right => answers.where((a) => a.correct).length;
  bool get perfect => answers.isNotEmpty && right == answers.length;
}

class RewardSummary {
  RewardSummary({required this.coins, required this.xp, required this.newBadges, required this.levelUp});
  final int coins;
  final int xp;
  final List<Award> newBadges;
  final bool levelUp;
}

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String weekKeyOf(DateTime d) => dayKey(DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1)));

class Store extends ChangeNotifier {
  Store._(this._prefs);

  static const _key = 'sawaal_v1';
  final SharedPreferences? _prefs; // null if storage is unavailable: app still runs, nothing is saved
  final List<Profile> profiles = [];
  String? activeId;
  final Settings settings = Settings();

  static Future<Store> load() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 4));
    } catch (_) {
      prefs = null; // never block start-up on storage
    }
    final s = Store._(prefs);
    final raw = prefs?.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        s.profiles.addAll(((j['profiles'] as List?) ?? []).map((e) => Profile.fromJson(e as Map<String, dynamic>)));
        s.activeId = j['activeId'] as String?;
        s.settings.load((j['settings'] as Map?)?.cast<String, dynamic>() ?? {});
      } catch (_) {
        // Corrupt data: start fresh rather than crash.
      }
    }
    return s;
  }

  void _save() {
    _prefs?.setString(
      _key,
      jsonEncode({
        'profiles': profiles.map((p) => p.toJson()).toList(),
        'activeId': activeId,
        'settings': settings.toJson(),
      }),
    );
  }

  void changed() {
    _save();
    notifyListeners();
  }

  String get lang => settings.lang;
  String t(String en, String hi) => lang == 'hi' ? hi : en;

  Profile? get active {
    for (final p in profiles) {
      if (p.id == activeId) return p;
    }
    return profiles.isEmpty ? null : profiles.first;
  }

  Profile addProfile(String name, AgeGroup group, int avatar) {
    final p = Profile(
      id: 'p${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      group: group,
      avatar: avatar,
      dailyLimitMin: group == AgeGroup.kids ? 30 : null,
    );
    profiles.add(p);
    activeId = p.id;
    changed();
    return p;
  }

  void switchTo(Profile p) {
    activeId = p.id;
    changed();
  }

  void removeProfile(Profile p) {
    profiles.remove(p);
    if (activeId == p.id) activeId = profiles.isEmpty ? null : profiles.first.id;
    changed();
  }

  /// Questions suitable for the active player.
  List<Q> poolFor({Cat? cat, Set<QType>? types}) {
    final p = active;
    final levels = p?.group.levels ?? Level.values.toSet();
    return questionBank
        .where((q) => levels.contains(q.level))
        .where((q) => cat == null || q.cat == cat)
        .where((q) => types == null || types.contains(q.type))
        .toList();
  }

  List<Q> pick(List<Q> pool, int n, {int? seed}) {
    final r = seed == null ? Random() : Random(seed);
    final copy = [...pool]..shuffle(r);
    return copy.take(n).toList();
  }

  /// Same five questions for everyone in a group on a given day.
  List<Q> dailyQuestions() {
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    return pick(poolFor(), 5, seed: seed);
  }

  bool get dailyDone => active?.dailyDoneDay == dayKey(DateTime.now());

  void addPlayTime(int seconds) {
    final p = active;
    if (p == null) return;
    final today = dayKey(DateTime.now());
    if (p.secondsDay != today) {
      p.secondsDay = today;
      p.secondsToday = 0;
    }
    p.secondsToday += seconds;
    changed();
  }

  RewardSummary record(GameResult r) {
    final p = active!;
    final before = p.badges.toSet();
    final levelBefore = p.level;
    final now = DateTime.now();
    final today = dayKey(now);
    final yesterday = dayKey(now.subtract(const Duration(days: 1)));

    for (final a in r.answers) {
      final c = a.q.cat.name.en;
      p.catAnswered[c] = (p.catAnswered[c] ?? 0) + 1;
      if (a.correct) {
        p.catCorrect[c] = (p.catCorrect[c] ?? 0) + 1;
        p.missed.remove(a.q.id);
      } else if (!p.missed.contains(a.q.id)) {
        p.missed.insert(0, a.q.id);
      }
    }
    if (p.missed.length > 60) p.missed.removeRange(60, p.missed.length);
    p.answered += r.answers.length;
    p.correct += r.right;

    if (p.lastPlayedDay != today) {
      p.streak = p.lastPlayedDay == yesterday ? p.streak + 1 : 1;
      p.lastPlayedDay = today;
    }
    final wk = weekKeyOf(now);
    if (p.weekKey != wk) {
      p.weekKey = wk;
      p.weekScore = 0;
    }
    p.weekScore += r.score;
    if (r.mode == 'daily') p.dailyDoneDay = today;
    if (r.mode == 'rapid' && r.right > p.bestRapid) p.bestRapid = r.right;

    final coins = r.right * 2 + (r.perfect ? 10 : 0) + (r.mode == 'daily' ? 15 : 0) + (r.wonBattle ? 20 : 0);
    final xp = r.score;
    p.coins += coins;
    p.xp += xp;

    void earn(String id, bool cond) {
      if (cond) p.badges.add(id);
    }

    earn('first', true);
    earn('perfect', r.perfect && r.answers.length >= 5);
    earn('streak3', p.streak >= 3);
    earn('streak7', p.streak >= 7);
    earn('rapid10', r.mode == 'rapid' && r.right >= 10);
    earn('botwin', r.wonBattle);
    earn('hundred', p.answered >= 100);
    earn('allcats', Cat.values.every((c) => (p.catAnswered[c.name.en] ?? 0) > 0));

    addPlayTime(r.seconds); // also saves
    return RewardSummary(
      coins: coins,
      xp: xp,
      newBadges: badges.where((b) => p.badges.contains(b.id) && !before.contains(b.id)).toList(),
      levelUp: p.level > levelBefore,
    );
  }

  bool spendCoins(int n) {
    final p = active;
    if (p == null || p.coins < n) return false;
    p.coins -= n;
    changed();
    return true;
  }
}

class StoreScope extends InheritedNotifier<Store> {
  const StoreScope({super.key, required Store store, required super.child}) : super(notifier: store);

  static Store of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
  static Store read(BuildContext context) => context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

extension StoreContext on BuildContext {
  Store get store => StoreScope.of(this);
  String tr(String en, String hi) => StoreScope.of(this).t(en, hi);
}
