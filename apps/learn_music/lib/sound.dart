import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

const int kRate = 22050;

double midiToHz(int midi) => 440.0 * pow(2, (midi - 69) / 12);

/// 16-bit mono PCM WAV from samples in [-1, 1].
Uint8List toWav(Float32List samples, {int rate = kRate}) {
  final dataLen = samples.length * 2;
  final b = ByteData(44 + dataLen);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  b.setUint32(4, 36 + dataLen, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  str(36, 'data');
  b.setUint32(40, dataLen, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    b.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32000).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}

/// A soft piano-like tone: a few harmonics with a quick attack and decay.
Float32List pianoTone(double hz, {double seconds = 1.3}) {
  final n = (seconds * kRate).round();
  final out = Float32List(n);
  const harmonics = [1.0, 0.45, 0.22, 0.12, 0.06];
  for (var i = 0; i < n; i++) {
    final t = i / kRate;
    final attack = min(1.0, t / 0.006);
    final env = attack * exp(-3.2 * t);
    var s = 0.0;
    for (var h = 0; h < harmonics.length; h++) {
      s += harmonics[h] * sin(2 * pi * hz * (h + 1) * t) * exp(-h * 1.2 * t);
    }
    out[i] = s * env * 0.42;
  }
  return out;
}

/// One tanpura cycle (Pa/Ma – Sa – Sa – low Sa), loopable.
Float32List tanpuraCycle(double sa, {bool useMa = false}) {
  const pluck = 1.4;
  final strings = [
    sa * (useMa ? 4 / 3 : 3 / 2) / 2,
    sa,
    sa,
    sa / 2,
  ];
  final n = (pluck * strings.length * kRate).round();
  final out = Float32List(n);
  final ring = (pluck * 3 * kRate).round();
  for (var k = 0; k < strings.length; k++) {
    final start = (k * pluck * kRate).round();
    final hz = strings[k];
    for (var j = 0; j < ring; j++) {
      final i = (start + j) % n; // wrap so the loop has no gap
      final t = j / kRate;
      final env = min(1.0, t / 0.02) * exp(-0.9 * t);
      var s = 0.0;
      for (var h = 1; h <= 9; h++) {
        // Rich, buzzing harmonics with slow shimmer, like the jawari bridge.
        final shimmer = 1 + 0.3 * sin(2 * pi * 0.7 * t * h);
        s += sin(2 * pi * hz * h * t) * shimmer / (h * 0.9);
      }
      out[i] += s * env * 0.09;
    }
  }
  return out;
}

Float32List clickSound({bool accent = false}) {
  final n = (0.05 * kRate).round();
  final out = Float32List(n);
  final hz = accent ? 1760.0 : 1100.0;
  for (var i = 0; i < n; i++) {
    final t = i / kRate;
    out[i] = sin(2 * pi * hz * t) * exp(-70 * t) * (accent ? 0.9 : 0.6);
  }
  return out;
}

/// Runs in a background isolate: writes every piano note and the clicks.
void _generateBaseSounds(String dir) {
  Directory(dir).createSync(recursive: true);
  for (var m = 48; m <= 84; m++) {
    final f = File('$dir/n$m.wav');
    if (!f.existsSync()) f.writeAsBytesSync(toWav(pianoTone(midiToHz(m))));
  }
  File('$dir/tick.wav').writeAsBytesSync(toWav(clickSound()));
  File('$dir/tock.wav').writeAsBytesSync(toWav(clickSound(accent: true)));
}

/// Generates sound files once, then plays them with a small pool of players
/// so fast or overlapping taps don't cut each other off.
class Sound {
  Sound._();
  static final Sound instance = Sound._();

  late String _dir;
  bool _ready = false;
  final _pool = <AudioPlayer>[];
  int _next = 0;
  AudioPlayer? _drone;

  Future<void> init() async {
    if (_ready) return;
    _dir = '${(await getTemporaryDirectory()).path}/sur';
    final dir = _dir;
    await Isolate.run(() => _generateBaseSounds(dir));
    for (var i = 0; i < 8; i++) {
      final p = AudioPlayer();
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      _pool.add(p);
    }
    _ready = true;
  }

  Future<void> _play(String file) async {
    if (!_ready) await init();
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    try {
      await p.stop();
      await p.play(DeviceFileSource('$_dir/$file'));
    } catch (_) {}
  }

  Future<void> note(int midi) => _play('n${midi.clamp(48, 84)}.wav');

  Future<void> click({bool accent = false}) => _play(accent ? 'tock.wav' : 'tick.wav');

  Future<void> startDrone(int saMidi, {bool useMa = false}) async {
    if (!_ready) await init();
    await stopDrone();
    final f = File('$_dir/drone_${saMidi}_${useMa ? 'ma' : 'pa'}.wav');
    if (!f.existsSync()) {
      final path = f.path;
      await Isolate.run(() =>
          File(path).writeAsBytesSync(toWav(tanpuraCycle(midiToHz(saMidi), useMa: useMa))));
    }
    final p = AudioPlayer();
    await p.setReleaseMode(ReleaseMode.loop);
    await p.play(DeviceFileSource(f.path));
    _drone = p;
  }

  Future<void> stopDrone() async {
    final d = _drone;
    _drone = null;
    if (d != null) {
      await d.stop();
      await d.dispose();
    }
  }
}
