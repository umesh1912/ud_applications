import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/sample_data.dart';

/// Single app-wide store. Kept dependency-free (ChangeNotifier +
/// InheritedNotifier). Swap the in-memory fields for API/database calls later.
class AppState extends ChangeNotifier {
  AppState() {
    _seed();
  }

  // ── Auth & profile ──────────────────────────────────────────────
  bool signedIn = false;
  bool onboarded = false;
  final StudentProfile profile = StudentProfile();
  ThemeMode themeMode = ThemeMode.system;

  void signIn({required String contact}) {
    profile.contact = contact;
    signedIn = true;
    notifyListeners();
  }

  void completeOnboarding() {
    onboarded = true;
    notifyListeners();
  }

  void signOut() {
    signedIn = false;
    onboarded = false;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
  }

  void updateProfile(void Function(StudentProfile p) change) {
    change(profile);
    notifyListeners();
  }

  // ── Learning progress ───────────────────────────────────────────
  final Set<String> completedTopics = {};
  String? lastTopicId;
  int streakDays = 6;

  void openTopic(String topicId) {
    lastTopicId = topicId;
    notifyListeners();
  }

  void toggleTopicDone(String topicId) {
    if (!completedTopics.remove(topicId)) completedTopics.add(topicId);
    notifyListeners();
  }

  double subjectProgress(Subject s) {
    if (s.topicCount == 0) return 0;
    final done = s.topics.where((t) => completedTopics.contains(t.id)).length;
    return done / s.topicCount;
  }

  // ── Bookmarks ("Revise later") ──────────────────────────────────
  final Set<String> bookmarkedTopics = {};
  final Set<String> bookmarkedQuestions = {};

  bool isTopicBookmarked(String id) => bookmarkedTopics.contains(id);
  bool isQuestionBookmarked(String id) => bookmarkedQuestions.contains(id);

  void toggleTopicBookmark(String id) {
    if (!bookmarkedTopics.remove(id)) bookmarkedTopics.add(id);
    notifyListeners();
  }

  void toggleQuestionBookmark(String id) {
    if (!bookmarkedQuestions.remove(id)) bookmarkedQuestions.add(id);
    notifyListeners();
  }

  // ── Tests & analytics ───────────────────────────────────────────
  final List<TestAttempt> attempts = [];

  void recordAttempt(TestAttempt a) {
    attempts.add(a);
    notifyListeners();
  }

  /// Accuracy per subject across all attempts (0–1), null if never attempted.
  Map<String, double?> subjectAccuracy() {
    final right = <String, int>{};
    final total = <String, int>{};
    for (final a in attempts) {
      for (final qid in a.questionIds) {
        final chosen = a.answers[qid];
        if (chosen == null) continue;
        final q = SampleData.question(qid);
        total[q.subjectId] = (total[q.subjectId] ?? 0) + 1;
        if (chosen == q.correct) right[q.subjectId] = (right[q.subjectId] ?? 0) + 1;
      }
    }
    return {
      for (final s in SampleData.subjects)
        s.id: (total[s.id] ?? 0) == 0 ? null : (right[s.id] ?? 0) / total[s.id]!,
    };
  }

  /// Topics answered wrong most recently — feeds "Weak spots".
  List<Topic> weakTopics({int limit = 3}) {
    final misses = <String, int>{};
    for (final a in attempts) {
      for (final qid in a.questionIds) {
        final chosen = a.answers[qid];
        final q = SampleData.question(qid);
        if (chosen != null && chosen != q.correct) {
          misses[q.topicId] = (misses[q.topicId] ?? 0) + 1;
        }
      }
    }
    final ids = misses.keys.toList()..sort((a, b) => misses[b]!.compareTo(misses[a]!));
    return ids.map(SampleData.topic).whereType<Topic>().take(limit).toList();
  }

  // ── PDF library ─────────────────────────────────────────────────
  /// pdfId -> download progress 0..1 (1 = available offline)
  final Map<String, double> downloads = {};
  final Map<String, Timer> _downloadTimers = {};

  bool isDownloaded(String id) => (downloads[id] ?? 0) >= 1;
  bool isDownloading(String id) => downloads.containsKey(id) && !isDownloaded(id);

  /// Simulated download. Replace with a real HTTP download (e.g. dio) that
  /// writes to app documents and reports progress the same way.
  void download(StudyPdf pdf) {
    if (downloads.containsKey(pdf.id)) return;
    downloads[pdf.id] = 0;
    notifyListeners();
    final step = 0.08 / pdf.sizeMb.clamp(0.5, 10);
    _downloadTimers[pdf.id] = Timer.periodic(const Duration(milliseconds: 120), (t) {
      final next = ((downloads[pdf.id] ?? 0.0) + step).clamp(0.0, 1.0);
      downloads[pdf.id] = next;
      if (next >= 1) {
        t.cancel();
        _downloadTimers.remove(pdf.id);
      }
      notifyListeners();
    });
  }

  void removeDownload(String id) {
    _downloadTimers.remove(id)?.cancel();
    downloads.remove(id);
    notifyListeners();
  }

  // ── Doubts ──────────────────────────────────────────────────────
  final List<Doubt> doubts = [];

  void askDoubt({required String subjectId, required String question, bool hasPhoto = false}) {
    final d = Doubt(
      id: 'd${DateTime.now().microsecondsSinceEpoch}',
      subjectId: subjectId,
      question: question,
      askedAt: DateTime.now(),
      hasPhoto: hasPhoto,
    );
    doubts.insert(0, d);
    notifyListeners();
    // Demo: a teacher replies shortly. Replace with a backend + push.
    Timer(const Duration(seconds: 6), () {
      d.answer = 'Good question. Start by writing down what is given and what is asked, '
          'then pick the formula that links them. Open the matching topic in Subjects '
          'for a worked example, and reply here if a step still feels unclear.';
      d.answeredBy = 'Ms. Kavya · Physics & Maths mentor';
      notifyListeners();
    });
  }

  // ── Planner ─────────────────────────────────────────────────────
  final List<StudySession> sessions = [];

  List<StudySession> sessionsFor(int weekday) =>
      sessions.where((s) => s.weekday == weekday).toList()
        ..sort((a, b) => (a.start.hour * 60 + a.start.minute)
            .compareTo(b.start.hour * 60 + b.start.minute));

  void addSession(StudySession s) {
    sessions.add(s);
    notifyListeners();
  }

  void removeSession(String id) {
    sessions.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  void toggleSessionDone(StudySession s) {
    s.done = !s.done;
    notifyListeners();
  }

  void toggleReminder(StudySession s) {
    s.remind = !s.remind;
    notifyListeners();
  }

  int get daysToExam {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return profile.examDate.difference(today).inDays;
  }

  // ── Seed ────────────────────────────────────────────────────────
  void _seed() {
    completedTopics.addAll(['phy-kin-1', 'che-mole-1', 'bio-cell-1']);
    lastTopicId = 'phy-nlm-1';
    bookmarkedTopics.add('che-bond-1');
    bookmarkedQuestions.add('q11');
    downloads['p2'] = 1;

    final now = DateTime.now();
    final seedScores = [
      ('t-jee-1', {'q1': 1, 'q2': 0, 'q3': 1, 'q4': 1, 'q5': 1, 'q6': 0, 'q7': 0, 'q11': 0}),
      ('t-neet-1', {'q3': 1, 'q5': 1, 'q6': 2, 'q8': 0, 'q9': 1, 'q10': 2, 'q2': 2, 'q7': 0}),
      ('t-jee-1', {'q1': 1, 'q2': 2, 'q3': 1, 'q4': 1, 'q5': 1, 'q6': 2, 'q7': 0, 'q11': 1}),
    ];
    for (var i = 0; i < seedScores.length; i++) {
      final (testId, answers) = seedScores[i];
      final t = SampleData.test(testId);
      var score = 0;
      for (final qid in t.questionIds) {
        final c = answers[qid];
        if (c == null) continue;
        score += c == SampleData.question(qid).correct ? t.marksCorrect : t.marksWrong;
      }
      attempts.add(TestAttempt(
        testId: t.id,
        title: t.title,
        date: now.subtract(Duration(days: (seedScores.length - i) * 4)),
        answers: answers,
        questionIds: t.questionIds,
        score: score,
        maxMarks: t.maxMarks,
        secondsUsed: 600 + i * 40,
      ));
    }

    final wd = now.weekday;
    sessions.addAll([
      StudySession(id: 's1', weekday: wd, start: const TimeOfDay(hour: 6, minute: 30), minutes: 45, subjectId: 'phy', label: 'Laws of motion — notes + examples', done: true),
      StudySession(id: 's2', weekday: wd, start: const TimeOfDay(hour: 17, minute: 0), minutes: 40, subjectId: 'che', label: 'VSEPR shapes — practice 15 questions'),
      StudySession(id: 's3', weekday: wd, start: const TimeOfDay(hour: 20, minute: 30), minutes: 30, subjectId: 'mat', label: 'Chain rule — revise formula sheet'),
      StudySession(id: 's4', weekday: wd % 7 + 1, start: const TimeOfDay(hour: 7, minute: 0), minutes: 60, subjectId: 'bio', label: 'Photosynthesis — full chapter'),
      StudySession(id: 's5', weekday: wd % 7 + 1, start: const TimeOfDay(hour: 18, minute: 0), minutes: 90, subjectId: 'phy', label: 'JEE Main Mock 1'),
    ]);

    doubts.add(Doubt(
      id: 'd0',
      subjectId: 'phy',
      question: 'Why is acceleration negative when a ball is going up, even though it is still moving up?',
      askedAt: now.subtract(const Duration(days: 1, hours: 3)),
      answer: 'Acceleration shows how velocity is changing, not which way the ball moves. '
          'On the way up the ball slows down, so its velocity is decreasing — that change points down. '
          'With "up" as positive, a = −9.8 m/s² the whole time, both going up and coming down.',
      answeredBy: 'Mr. Arjun · Physics mentor',
    ));
  }

  @override
  void dispose() {
    for (final t in _downloadTimers.values) {
      t.cancel();
    }
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without subscribing to rebuilds (for callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
