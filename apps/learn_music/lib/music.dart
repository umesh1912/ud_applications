/// Note names and practice songs (all traditional or public-domain melodies).

const westernNames = ['C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B'];

/// Sargam per semitone above Sa. Lower-case = komal; Ma' = tivra.
const sargam = {
  'en': ['Sa', 're', 'Re', 'ga', 'Ga', 'Ma', 'Ma′', 'Pa', 'dha', 'Dha', 'ni', 'Ni'],
  'hi': ['सा', 'रे॒', 'रे', 'ग॒', 'ग', 'म', 'म॑', 'प', 'ध॒', 'ध', 'नि॒', 'नि'],
  'gu': ['સા', 'રે॒', 'રે', 'ગ॒', 'ગ', 'મ', 'મ॑', 'પ', 'ધ॒', 'ધ', 'નિ॒', 'નિ'],
};

bool isBlack(int midi) => const [1, 3, 6, 8, 10].contains(midi % 12);

String noteName(int midi, {required bool useSargam, required String lang, int saMidi = 60}) {
  if (!useSargam) return '${westernNames[midi % 12]}${midi ~/ 12 - 1}';
  final names = sargam[lang] ?? sargam['en']!;
  final rel = (midi - saMidi) % 12;
  final octave = (midi - saMidi) ~/ 12;
  final dot = midi < saMidi ? '̣' : (octave >= 1 ? '̇' : '');
  return '${names[rel]}$dot';
}

class Song {
  const Song(this.id, this.notes, {this.beats});
  final String id;
  final List<int> notes;

  /// Length of each note in beats (defaults to 1).
  final List<double>? beats;

  double beat(int i) => beats == null ? 1 : beats![i];
}

// MIDI: C4=60 D=62 E=64 F=65 G=67 A=69 B=71 C5=72 D5=74 E5=76 F5=77 G5=79
const songs = <Song>[
  Song('sargam_up', [60, 62, 64, 65, 67, 69, 71, 72]),
  Song('sargam_down', [72, 71, 69, 67, 65, 64, 62, 60]),
  Song('alankar', [
    60, 62, 64, 62, 64, 65, 64, 65, 67, 65, 67, 69, 67, 69, 71, 69, 71, 72, //
  ]),
  Song('twinkle', [
    60, 60, 67, 67, 69, 69, 67, 65, 65, 64, 64, 62, 62, 60, //
    67, 67, 65, 65, 64, 64, 62, 67, 67, 65, 65, 64, 64, 62, //
    60, 60, 67, 67, 69, 69, 67, 65, 65, 64, 64, 62, 62, 60,
  ], beats: [
    1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 2, //
    1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 2, //
    1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 2,
  ]),
  Song('birthday', [
    67, 67, 69, 67, 72, 71, //
    67, 67, 69, 67, 74, 72, //
    67, 67, 79, 76, 72, 71, 69, //
    77, 77, 76, 72, 74, 72,
  ], beats: [
    0.75, 0.25, 1, 1, 1, 2, //
    0.75, 0.25, 1, 1, 1, 2, //
    0.75, 0.25, 1, 1, 1, 1, 2, //
    0.75, 0.25, 1, 1, 1, 2,
  ]),
  Song('ode', [
    64, 64, 65, 67, 67, 65, 64, 62, 60, 60, 62, 64, 64, 62, 62, //
    64, 64, 65, 67, 67, 65, 64, 62, 60, 60, 62, 64, 62, 60, 60,
  ], beats: [
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.5, 0.5, 2, //
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.5, 0.5, 2,
  ]),
  Song('jingle', [
    64, 64, 64, 64, 64, 64, 64, 67, 60, 62, 64, //
    65, 65, 65, 65, 65, 64, 64, 64, 64, 62, 62, 64, 62, 67,
  ], beats: [
    1, 1, 2, 1, 1, 2, 1, 1, 1.5, 0.5, 4, //
    1, 1, 1.5, 0.5, 1, 1, 1, 0.5, 0.5, 1, 1, 1, 2, 2,
  ]),
];
