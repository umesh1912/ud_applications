import 'dart:math';

import 'package:flutter/foundation.dart';

enum LudoMode { classic, quick, rush }

/// The 52 shared squares, clockwise, as (row, col) on a 15×15 grid.
/// Index 0 is Red's starting square.
const List<(int, int)> kTrack = [
  (6, 1), (6, 2), (6, 3), (6, 4), (6, 5),
  (5, 6), (4, 6), (3, 6), (2, 6), (1, 6), (0, 6),
  (0, 7),
  (0, 8), (1, 8), (2, 8), (3, 8), (4, 8), (5, 8),
  (6, 9), (6, 10), (6, 11), (6, 12), (6, 13), (6, 14),
  (7, 14),
  (8, 14), (8, 13), (8, 12), (8, 11), (8, 10), (8, 9),
  (9, 8), (10, 8), (11, 8), (12, 8), (13, 8), (14, 8),
  (14, 7),
  (14, 6), (13, 6), (12, 6), (11, 6), (10, 6), (9, 6),
  (8, 5), (8, 4), (8, 3), (8, 2), (8, 1), (8, 0),
  (7, 0),
  (6, 0),
];

/// Five home-column squares per colour (Red, Green, Yellow, Blue).
const List<List<(int, int)>> kHomeColumn = [
  [(7, 1), (7, 2), (7, 3), (7, 4), (7, 5)],
  [(1, 7), (2, 7), (3, 7), (4, 7), (5, 7)],
  [(7, 13), (7, 12), (7, 11), (7, 10), (7, 9)],
  [(13, 7), (12, 7), (11, 7), (10, 7), (9, 7)],
];

const List<int> kStartIndex = [0, 13, 26, 39];

/// Starting squares and star squares: no captures here.
const Set<int> kSafe = {0, 8, 13, 21, 26, 34, 39, 47};

/// Top-left corner of each colour's yard.
const List<(int, int)> kYardOrigin = [(0, 0), (0, 9), (9, 9), (9, 0)];

/// Progress values: -1 = yard, 0..50 = shared track, 51..55 = home column, 56 = finished.
const int kLastTrack = 50;
const int kFinished = 56;

class LudoPlayer {
  LudoPlayer({required this.color, required this.bot, required this.tokens});
  final int color;
  final bool bot;
  final List<int> tokens;

  int get finishedCount => tokens.where((t) => t == kFinished).length;
}

/// Pure game rules plus turn state. The UI listens and drives timing.
class LudoGame extends ChangeNotifier {
  LudoGame({
    required this.mode,
    required List<bool> bots,
    required List<int> colors,
    Random? random,
  }) : _rng = random ?? Random() {
    final count = mode == LudoMode.quick ? 2 : 4;
    final startAt = mode == LudoMode.quick ? 0 : -1;
    players = [
      for (var i = 0; i < colors.length; i++)
        LudoPlayer(color: colors[i], bot: bots[i], tokens: List.filled(count, startAt)),
    ];
  }

  final LudoMode mode;
  final Random _rng;
  late final List<LudoPlayer> players;

  int current = 0;
  int? dice;
  bool rolled = false;
  int _sixes = 0;
  final List<int> ranking = []; // player indexes in finishing order
  String? lastEvent; // 'capture', 'home', 'six', 'skip'

  LudoPlayer get player => players[current];
  bool get over => ranking.isNotEmpty && (mode == LudoMode.rush || ranking.length >= players.length - 1);

  /// Absolute track index of a token, or null when not on the shared track.
  int? trackIndex(int color, int progress) {
    if (progress < 0 || progress > kLastTrack) return null;
    return (kStartIndex[color] + progress) % kTrack.length;
  }

  /// Board position of a token as (row, col); fractional for yard and centre.
  (double, double) cellOf(int color, int tokenIndex, int progress) {
    if (progress < 0) {
      final (r, c) = kYardOrigin[color];
      const slots = [(1.6, 1.6), (1.6, 3.4), (3.4, 1.6), (3.4, 3.4)];
      final (dr, dc) = slots[tokenIndex % 4];
      return (r + dr - 0.5, c + dc - 0.5);
    }
    if (progress <= kLastTrack) {
      final (r, c) = kTrack[trackIndex(color, progress)!];
      return (r.toDouble(), c.toDouble());
    }
    if (progress < kFinished) {
      final (r, c) = kHomeColumn[color][progress - kLastTrack - 1];
      return (r.toDouble(), c.toDouble());
    }
    const centre = [(7.0, 6.35), (6.35, 7.0), (7.0, 7.65), (7.65, 7.0)];
    return centre[color];
  }

  bool canMove(int tokenIndex, int roll) {
    final p = player.tokens[tokenIndex];
    if (p == kFinished) return false;
    if (p < 0) return roll == 6;
    return p + roll <= kFinished;
  }

  List<int> movableTokens() {
    final d = dice;
    if (!rolled || d == null) return const [];
    return [for (var i = 0; i < player.tokens.length; i++) if (canMove(i, d)) i];
  }

  /// Rolls the dice. Returns the movable tokens (empty means the turn passes).
  List<int> roll() {
    dice = _rng.nextInt(6) + 1;
    rolled = true;
    lastEvent = null;
    if (dice == 6) {
      _sixes++;
      if (_sixes == 3) {
        lastEvent = 'skip';
        notifyListeners();
        return const [];
      }
    }
    notifyListeners();
    return movableTokens();
  }

  /// Moves a token by the rolled amount. Returns true when the same player
  /// gets another turn.
  bool move(int tokenIndex) {
    final d = dice!;
    final tokens = player.tokens;
    final from = tokens[tokenIndex];
    final to = from < 0 ? 0 : from + d;
    tokens[tokenIndex] = to;

    var bonus = d == 6;
    lastEvent = d == 6 ? 'six' : null;

    // Capture opponents on the landing square.
    final landing = trackIndex(player.color, to);
    if (landing != null && !kSafe.contains(landing)) {
      for (final other in players) {
        if (other == player) continue;
        for (var i = 0; i < other.tokens.length; i++) {
          if (trackIndex(other.color, other.tokens[i]) == landing) {
            other.tokens[i] = mode == LudoMode.quick ? 0 : -1;
            bonus = true;
            lastEvent = 'capture';
          }
        }
      }
    }

    if (to == kFinished) {
      bonus = true;
      lastEvent = 'home';
      final done = mode == LudoMode.rush || tokens.every((t) => t == kFinished);
      if (done && !ranking.contains(current)) {
        ranking.add(current);
        bonus = false;
      }
    }

    rolled = false;
    notifyListeners();
    return bonus && !over;
  }

  void nextTurn({bool samePlayer = false}) {
    rolled = false;
    if (!samePlayer) {
      _sixes = 0;
      lastEvent = null;
      var next = current;
      for (var i = 0; i < players.length; i++) {
        next = (next + 1) % players.length;
        if (!ranking.contains(next)) break;
      }
      current = next;
    }
    dice = null;
    notifyListeners();
  }

  /// Simple but sensible computer player.
  int chooseForBot(List<int> options) {
    final d = dice!;
    int best = options.first;
    var bestScore = -1e9;
    for (final i in options) {
      final from = player.tokens[i];
      final to = from < 0 ? 0 : from + d;
      var score = 0.0;
      final landing = trackIndex(player.color, to);
      if (landing != null && !kSafe.contains(landing)) {
        for (final other in players) {
          if (other == player) continue;
          for (final t in other.tokens) {
            if (trackIndex(other.color, t) == landing) score += 100 + t;
          }
        }
      }
      if (to == kFinished) score += 80;
      if (from <= kLastTrack && to > kLastTrack) score += 50;
      if (from < 0) score += 60;
      if (landing != null && kSafe.contains(landing)) score += 25;
      if (landing != null && _inDanger(landing)) score -= 40;
      final fromTrack = trackIndex(player.color, from);
      if (fromTrack != null && _inDanger(fromTrack) && !kSafe.contains(fromTrack)) score += 30;
      score += to * 0.5;
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }
    return best;
  }

  /// True if an opponent token sits 1–6 squares behind this track square.
  bool _inDanger(int square) {
    for (final other in players) {
      if (other == player) continue;
      for (final t in other.tokens) {
        final idx = trackIndex(other.color, t);
        if (idx == null) continue;
        final gap = (square - idx + kTrack.length) % kTrack.length;
        if (gap >= 1 && gap <= 6) return true;
      }
    }
    return false;
  }
}
