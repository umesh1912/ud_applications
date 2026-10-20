import 'package:flutter/material.dart';

class Subject {
  const Subject({
    required this.id,
    required this.symbol,
    required this.name,
    required this.color,
    required this.number,
    required this.chapters,
  });

  final String id;
  final String symbol; // two-letter "element" symbol, e.g. Ph
  final String name;
  final Color color;
  final int number; // position in the study "periodic table"
  final List<Chapter> chapters;

  int get topicCount => chapters.fold(0, (n, c) => n + c.topics.length);
  Iterable<Topic> get topics => chapters.expand((c) => c.topics);
}

class Chapter {
  const Chapter({
    required this.id,
    required this.title,
    required this.topics,
    this.weightage = const {},
  });

  final String id;
  final String title;
  final List<Topic> topics;

  /// Approximate share of marks by exam, e.g. {'Boards': 8, 'JEE': 6}.
  final Map<String, int> weightage;
}

class Topic {
  const Topic({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.minutes,
    required this.notes,
    this.keyFormula,
    this.formulaNote,
    this.examples = const [],
  });

  final String id;
  final String subjectId;
  final String title;
  final int minutes;
  final List<String> notes;
  final String? keyFormula;
  final String? formulaNote;
  final List<SolvedExample> examples;
}

class SolvedExample {
  const SolvedExample({
    required this.question,
    required this.steps,
    required this.answer,
    this.level = 'Easy',
  });

  final String question;
  final List<String> steps;
  final String answer;
  final String level;
}

class Question {
  const Question({
    required this.id,
    required this.subjectId,
    required this.topicId,
    required this.text,
    required this.options,
    required this.correct,
    required this.explanation,
  });

  final String id;
  final String subjectId;
  final String topicId;
  final String text;
  final List<String> options;
  final int correct;
  final String explanation;
}

class MockTest {
  const MockTest({
    required this.id,
    required this.title,
    required this.exam,
    required this.minutes,
    required this.questionIds,
    this.marksCorrect = 4,
    this.marksWrong = -1,
    this.kind = 'Mock test',
  });

  final String id;
  final String title;
  final String exam; // Boards, JEE, NEET
  final int minutes;
  final List<String> questionIds;
  final int marksCorrect;
  final int marksWrong; // negative marking (0 for none)
  final String kind; // Mock test, Chapter test, Past paper

  int get maxMarks => questionIds.length * marksCorrect;
}

class TestAttempt {
  TestAttempt({
    required this.testId,
    required this.title,
    required this.date,
    required this.answers,
    required this.questionIds,
    required this.score,
    required this.maxMarks,
    required this.secondsUsed,
  });

  final String testId;
  final String title;
  final DateTime date;
  final Map<String, int> answers; // questionId -> chosen option
  final List<String> questionIds;
  final int score;
  final int maxMarks;
  final int secondsUsed;

  double get percent => maxMarks == 0 ? 0 : (score / maxMarks).clamp(0, 1).toDouble();
}

enum PdfKind { notes, formulas, pastPaper, solutions }

extension PdfKindLabel on PdfKind {
  String get label => switch (this) {
        PdfKind.notes => 'Chapter notes',
        PdfKind.formulas => 'Formula sheet',
        PdfKind.pastPaper => 'Past paper',
        PdfKind.solutions => 'NCERT solutions',
      };
}

class StudyPdf {
  const StudyPdf({
    required this.id,
    required this.title,
    required this.subjectId,
    required this.kind,
    required this.pages,
    required this.sizeMb,
  });

  final String id;
  final String title;
  final String subjectId;
  final PdfKind kind;
  final int pages;
  final double sizeMb;
}

enum DoubtStatus { waiting, answered }

class Doubt {
  Doubt({
    required this.id,
    required this.subjectId,
    required this.question,
    required this.askedAt,
    this.hasPhoto = false,
    this.answer,
    this.answeredBy,
  });

  final String id;
  final String subjectId;
  final String question;
  final DateTime askedAt;
  final bool hasPhoto;
  String? answer;
  String? answeredBy;

  DoubtStatus get status => answer == null ? DoubtStatus.waiting : DoubtStatus.answered;
}

class StudySession {
  StudySession({
    required this.id,
    required this.weekday, // 1 = Monday … 7 = Sunday
    required this.start,
    required this.minutes,
    required this.subjectId,
    required this.label,
    this.remind = true,
    this.done = false,
  });

  final String id;
  final int weekday;
  final TimeOfDay start;
  final int minutes;
  final String subjectId;
  final String label;
  bool remind;
  bool done;
}

class StudentProfile {
  StudentProfile({
    this.name = '',
    this.contact = '',
    this.grade = 'Class 12',
    this.board = 'CBSE',
    this.stream = 'PCM',
    this.goal = 'JEE',
    DateTime? examDate,
  }) : examDate = examDate ?? DateTime(DateTime.now().year + 1, 4, 5);

  String name;
  String contact;
  String grade;
  String board;
  String stream;
  String goal;
  DateTime examDate;
}
