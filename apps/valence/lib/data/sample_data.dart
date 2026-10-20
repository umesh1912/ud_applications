import '../theme/tokens.dart';
import 'models.dart';

/// Sample content so every screen works offline out of the box.
/// Replace with your API/CMS later (see README → "Connecting a backend").
class SampleData {
  SampleData._();

  static final List<Subject> subjects = [
    Subject(
      id: 'phy',
      symbol: 'Ph',
      name: 'Physics',
      color: Palette.physics,
      number: 1,
      chapters: [
        Chapter(
          id: 'phy-kin',
          title: 'Motion in a straight line',
          weightage: {'Boards': 6, 'JEE': 4, 'NEET': 3},
          topics: [
            Topic(
              id: 'phy-kin-1',
              subjectId: 'phy',
              title: 'Equations of motion',
              minutes: 18,
              notes: [
                'When acceleration stays constant, three equations link initial velocity (u), final velocity (v), acceleration (a), time (t) and displacement (s).',
                'Pick the equation that contains the three quantities you know and the one you want. You never need all five.',
                'Signs matter: choose one direction as positive and stick to it. A ball thrown up has a = −9.8 m/s² if "up" is positive.',
              ],
              keyFormula: 'v = u + at    s = ut + ½at²    v² = u² + 2as',
              formulaNote: 'Valid only for constant acceleration.',
              examples: [
                SolvedExample(
                  level: 'Easy',
                  question: 'A car starts from rest and accelerates at 2 m/s² for 5 s. How far does it travel?',
                  steps: [
                    'Known: u = 0, a = 2 m/s², t = 5 s. Want: s.',
                    'Use s = ut + ½at² because it has u, a, t and s.',
                    's = 0 × 5 + ½ × 2 × 5² = 25 m.',
                  ],
                  answer: '25 m',
                ),
                SolvedExample(
                  level: 'Medium',
                  question: 'A ball is thrown straight up at 20 m/s. How high does it rise? (g = 10 m/s²)',
                  steps: [
                    'Take up as positive. u = 20 m/s, a = −10 m/s², and at the top v = 0.',
                    'No time is given or needed, so use v² = u² + 2as.',
                    '0 = 20² + 2(−10)s  →  20s = 400.',
                    's = 20 m.',
                  ],
                  answer: '20 m',
                ),
              ],
            ),
            Topic(
              id: 'phy-kin-2',
              subjectId: 'phy',
              title: 'Velocity–time graphs',
              minutes: 14,
              notes: [
                'The slope of a velocity–time graph is acceleration.',
                'The area under a velocity–time graph is displacement. Area below the time axis counts as negative displacement.',
                'A horizontal line means constant velocity; a straight sloped line means constant acceleration.',
              ],
              keyFormula: 'slope = a    area = s',
              examples: [
                SolvedExample(
                  question: 'A v–t graph rises in a straight line from 0 to 12 m/s in 4 s. Find a and s.',
                  steps: [
                    'Slope = (12 − 0) / 4 = 3 m/s², so a = 3 m/s².',
                    'Area of the triangle = ½ × 4 × 12 = 24 m.',
                  ],
                  answer: 'a = 3 m/s², s = 24 m',
                ),
              ],
            ),
          ],
        ),
        Chapter(
          id: 'phy-nlm',
          title: 'Laws of motion',
          weightage: {'Boards': 8, 'JEE': 7, 'NEET': 6},
          topics: [
            Topic(
              id: 'phy-nlm-1',
              subjectId: 'phy',
              title: 'Newton\'s second law',
              minutes: 20,
              notes: [
                'Net force equals the rate of change of momentum. For constant mass this becomes F = ma.',
                'Always draw a free-body diagram first: one dot for the object, one arrow for every force on it.',
                'Only forces acting on the object go in its diagram. Forces it exerts on others do not.',
              ],
              keyFormula: 'F(net) = ma',
              formulaNote: 'F in newtons, m in kg, a in m/s².',
              examples: [
                SolvedExample(
                  question: 'A 5 kg box is pushed with 30 N against 10 N of friction. Find its acceleration.',
                  steps: [
                    'Net force = 30 − 10 = 20 N in the direction of the push.',
                    'a = F / m = 20 / 5 = 4 m/s².',
                  ],
                  answer: '4 m/s²',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    Subject(
      id: 'che',
      symbol: 'Ch',
      name: 'Chemistry',
      color: Palette.chemistry,
      number: 2,
      chapters: [
        Chapter(
          id: 'che-mole',
          title: 'Some basic concepts',
          weightage: {'Boards': 5, 'JEE': 4, 'NEET': 5},
          topics: [
            Topic(
              id: 'che-mole-1',
              subjectId: 'che',
              title: 'The mole concept',
              minutes: 16,
              notes: [
                'One mole is 6.022 × 10²³ particles — Avogadro\'s number.',
                'Molar mass in g/mol equals the atomic or molecular mass. One mole of water weighs 18 g.',
                'Most stoichiometry questions are: grams → moles → use the ratio from the balanced equation → back to grams.',
              ],
              keyFormula: 'n = m / M',
              formulaNote: 'n = moles, m = mass in g, M = molar mass in g/mol.',
              examples: [
                SolvedExample(
                  question: 'How many moles are in 88 g of CO₂?',
                  steps: [
                    'Molar mass of CO₂ = 12 + 2 × 16 = 44 g/mol.',
                    'n = 88 / 44 = 2 mol.',
                  ],
                  answer: '2 mol',
                ),
              ],
            ),
          ],
        ),
        Chapter(
          id: 'che-bond',
          title: 'Chemical bonding',
          weightage: {'Boards': 7, 'JEE': 6, 'NEET': 7},
          topics: [
            Topic(
              id: 'che-bond-1',
              subjectId: 'che',
              title: 'VSEPR and molecular shape',
              minutes: 22,
              notes: [
                'Electron pairs around a central atom push each other as far apart as possible.',
                'Lone pairs repel more strongly than bonding pairs, so they squeeze bond angles.',
                'Count bonding pairs and lone pairs, then read the shape: 4 bp + 0 lp is tetrahedral, 3 bp + 1 lp is pyramidal, 2 bp + 2 lp is bent.',
              ],
              keyFormula: 'lp–lp > lp–bp > bp–bp',
              formulaNote: 'Order of repulsion strength.',
              examples: [
                SolvedExample(
                  question: 'Why is the bond angle in water about 104.5° and not 109.5°?',
                  steps: [
                    'Oxygen has 2 bonding pairs and 2 lone pairs: 4 pairs, so the arrangement is tetrahedral.',
                    'The two lone pairs repel the bonding pairs more strongly.',
                    'This pushes the O–H bonds closer together, reducing the angle.',
                  ],
                  answer: 'Lone-pair repulsion compresses the tetrahedral angle to about 104.5°.',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    Subject(
      id: 'bio',
      symbol: 'Bi',
      name: 'Biology',
      color: Palette.biology,
      number: 3,
      chapters: [
        Chapter(
          id: 'bio-cell',
          title: 'Cell: the unit of life',
          weightage: {'Boards': 6, 'NEET': 8},
          topics: [
            Topic(
              id: 'bio-cell-1',
              subjectId: 'bio',
              title: 'Cell organelles',
              minutes: 20,
              notes: [
                'Mitochondria make ATP through aerobic respiration and have their own DNA.',
                'Ribosomes build proteins. They are free in the cytoplasm or attached to rough ER.',
                'Plant cells add a cell wall, chloroplasts and a large central vacuole.',
              ],
              keyFormula: 'Prokaryotes: 70S ribosomes    Eukaryotes: 80S',
              examples: [
                SolvedExample(
                  question: 'Which organelle would be most abundant in a muscle cell, and why?',
                  steps: [
                    'Muscle cells contract constantly, which needs a lot of energy.',
                    'Energy in the form of ATP comes mainly from mitochondria.',
                  ],
                  answer: 'Mitochondria — to meet high ATP demand.',
                ),
              ],
            ),
          ],
        ),
        Chapter(
          id: 'bio-photo',
          title: 'Photosynthesis in plants',
          weightage: {'Boards': 5, 'NEET': 6},
          topics: [
            Topic(
              id: 'bio-photo-1',
              subjectId: 'bio',
              title: 'Light and dark reactions',
              minutes: 18,
              notes: [
                'Light reactions happen in the thylakoids. They split water, release O₂ and make ATP and NADPH.',
                'The Calvin cycle runs in the stroma. It uses ATP and NADPH to fix CO₂ into sugar.',
                'Fixing one CO₂ uses 3 ATP and 2 NADPH.',
              ],
              keyFormula: '6CO₂ + 12H₂O → C₆H₁₂O₆ + 6O₂ + 6H₂O',
              examples: [
                SolvedExample(
                  question: 'How many ATP are needed to make one glucose molecule in the Calvin cycle?',
                  steps: [
                    'One glucose needs 6 CO₂ fixed.',
                    'Each CO₂ uses 3 ATP, so 6 × 3 = 18 ATP.',
                  ],
                  answer: '18 ATP',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    Subject(
      id: 'mat',
      symbol: 'Ma',
      name: 'Maths',
      color: Palette.maths,
      number: 4,
      chapters: [
        Chapter(
          id: 'mat-diff',
          title: 'Differentiation',
          weightage: {'Boards': 10, 'JEE': 8},
          topics: [
            Topic(
              id: 'mat-diff-1',
              subjectId: 'mat',
              title: 'Chain rule',
              minutes: 15,
              notes: [
                'Use the chain rule when one function sits inside another.',
                'Differentiate the outer function, keep the inside unchanged, then multiply by the derivative of the inside.',
              ],
              keyFormula: 'd/dx f(g(x)) = f′(g(x)) · g′(x)',
              examples: [
                SolvedExample(
                  question: 'Differentiate y = sin(3x²).',
                  steps: [
                    'Outer function: sin(u); inner: u = 3x².',
                    'd/du sin(u) = cos(u); du/dx = 6x.',
                    'dy/dx = cos(3x²) · 6x.',
                  ],
                  answer: '6x cos(3x²)',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    Subject(
      id: 'cs',
      symbol: 'Cs',
      name: 'Computer Science',
      color: Palette.computer,
      number: 5,
      chapters: [
        Chapter(
          id: 'cs-algo',
          title: 'Searching and sorting',
          weightage: {'Boards': 8},
          topics: [
            Topic(
              id: 'cs-algo-1',
              subjectId: 'cs',
              title: 'Binary search',
              minutes: 12,
              notes: [
                'Binary search works only on a sorted list.',
                'Compare the target with the middle item, then throw away the half that cannot contain it.',
                'Each step halves the list, so it takes about log₂(n) steps.',
              ],
              keyFormula: 'Time: O(log n)',
              examples: [
                SolvedExample(
                  question: 'At most how many comparisons does binary search need for 1,024 items?',
                  steps: [
                    '1,024 = 2¹⁰.',
                    'Each comparison halves the list, so at most 10 halvings, plus one final check.',
                  ],
                  answer: '11 comparisons (about log₂ 1024 + 1)',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];

  static final List<Question> questions = [
    Question(
      id: 'q1', subjectId: 'phy', topicId: 'phy-kin-1',
      text: 'A body starts from rest with acceleration 4 m/s². Its velocity after 3 s is:',
      options: ['7 m/s', '12 m/s', '16 m/s', '36 m/s'],
      correct: 1,
      explanation: 'v = u + at = 0 + 4 × 3 = 12 m/s.',
    ),
    Question(
      id: 'q2', subjectId: 'phy', topicId: 'phy-kin-2',
      text: 'The area under a velocity–time graph gives:',
      options: ['Acceleration', 'Speed', 'Displacement', 'Force'],
      correct: 2,
      explanation: 'Area under v–t = displacement; slope = acceleration.',
    ),
    Question(
      id: 'q3', subjectId: 'phy', topicId: 'phy-nlm-1',
      text: 'A net force of 12 N acts on a 3 kg mass. Its acceleration is:',
      options: ['36 m/s²', '4 m/s²', '0.25 m/s²', '9 m/s²'],
      correct: 1,
      explanation: 'a = F/m = 12/3 = 4 m/s².',
    ),
    Question(
      id: 'q4', subjectId: 'phy', topicId: 'phy-kin-1',
      text: 'A stone dropped from rest falls for 2 s (g = 10 m/s²). Distance fallen:',
      options: ['10 m', '20 m', '40 m', '5 m'],
      correct: 1,
      explanation: 's = ½gt² = ½ × 10 × 4 = 20 m.',
    ),
    Question(
      id: 'q5', subjectId: 'che', topicId: 'che-mole-1',
      text: 'Number of moles in 36 g of water:',
      options: ['1', '2', '3', '0.5'],
      correct: 1,
      explanation: 'M(H₂O) = 18 g/mol, so n = 36/18 = 2.',
    ),
    Question(
      id: 'q6', subjectId: 'che', topicId: 'che-bond-1',
      text: 'The shape of NH₃ according to VSEPR is:',
      options: ['Tetrahedral', 'Trigonal planar', 'Trigonal pyramidal', 'Bent'],
      correct: 2,
      explanation: '3 bonding pairs + 1 lone pair → trigonal pyramidal.',
    ),
    Question(
      id: 'q7', subjectId: 'che', topicId: 'che-mole-1',
      text: 'Avogadro\'s number is approximately:',
      options: ['6.022 × 10²³', '3.0 × 10⁸', '1.6 × 10⁻¹⁹', '9.8 × 10²'],
      correct: 0,
      explanation: 'One mole contains 6.022 × 10²³ particles.',
    ),
    Question(
      id: 'q8', subjectId: 'bio', topicId: 'bio-cell-1',
      text: 'Ribosomes found in prokaryotic cells are:',
      options: ['80S', '70S', '60S', '90S'],
      correct: 1,
      explanation: 'Prokaryotes have 70S ribosomes; eukaryotic cytoplasm has 80S.',
    ),
    Question(
      id: 'q9', subjectId: 'bio', topicId: 'bio-photo-1',
      text: 'The Calvin cycle takes place in the:',
      options: ['Thylakoid lumen', 'Stroma', 'Cytoplasm', 'Mitochondrial matrix'],
      correct: 1,
      explanation: 'Dark reactions (Calvin cycle) occur in the chloroplast stroma.',
    ),
    Question(
      id: 'q10', subjectId: 'bio', topicId: 'bio-photo-1',
      text: 'Oxygen released in photosynthesis comes from:',
      options: ['CO₂', 'Glucose', 'Water', 'Chlorophyll'],
      correct: 2,
      explanation: 'Photolysis of water in the light reactions releases O₂.',
    ),
    Question(
      id: 'q11', subjectId: 'mat', topicId: 'mat-diff-1',
      text: 'd/dx (x² + 1)³ equals:',
      options: ['3(x² + 1)²', '6x(x² + 1)²', '2x(x² + 1)³', '6x(x² + 1)'],
      correct: 1,
      explanation: 'Chain rule: 3(x² + 1)² · 2x = 6x(x² + 1)².',
    ),
    Question(
      id: 'q12', subjectId: 'cs', topicId: 'cs-algo-1',
      text: 'Binary search needs the list to be:',
      options: ['Linked', 'Sorted', 'Of even length', 'Unique'],
      correct: 1,
      explanation: 'Halving only works if items are in order.',
    ),
  ];

  static final List<MockTest> tests = [
    MockTest(
      id: 't-jee-1',
      title: 'JEE Main — Mock 1',
      exam: 'JEE',
      minutes: 15,
      questionIds: ['q1', 'q2', 'q3', 'q4', 'q5', 'q6', 'q7', 'q11'],
    ),
    MockTest(
      id: 't-neet-1',
      title: 'NEET — Mock 1',
      exam: 'NEET',
      minutes: 15,
      questionIds: ['q3', 'q5', 'q6', 'q8', 'q9', 'q10', 'q2', 'q7'],
    ),
    MockTest(
      id: 't-board-phy',
      title: 'Physics — Motion and forces',
      exam: 'Boards',
      kind: 'Chapter test',
      minutes: 8,
      marksCorrect: 1,
      marksWrong: 0,
      questionIds: ['q1', 'q2', 'q3', 'q4'],
    ),
    MockTest(
      id: 't-board-bio',
      title: 'Biology — Cells and photosynthesis',
      exam: 'Boards',
      kind: 'Chapter test',
      minutes: 8,
      marksCorrect: 1,
      marksWrong: 0,
      questionIds: ['q8', 'q9', 'q10'],
    ),
    MockTest(
      id: 't-pyq-jee',
      title: 'JEE Main 2025 — Shift 1 (sample)',
      exam: 'JEE',
      kind: 'Past paper',
      minutes: 12,
      questionIds: ['q1', 'q3', 'q6', 'q11', 'q12'],
    ),
  ];

  static final List<StudyPdf> pdfs = [
    StudyPdf(id: 'p1', title: 'Motion in a straight line — notes', subjectId: 'phy', kind: PdfKind.notes, pages: 14, sizeMb: 2.1),
    StudyPdf(id: 'p2', title: 'Physics formula sheet, Class 11', subjectId: 'phy', kind: PdfKind.formulas, pages: 6, sizeMb: 0.8),
    StudyPdf(id: 'p3', title: 'Chemical bonding — notes', subjectId: 'che', kind: PdfKind.notes, pages: 18, sizeMb: 3.4),
    StudyPdf(id: 'p4', title: 'Chemistry NCERT solutions, Ch 1–4', subjectId: 'che', kind: PdfKind.solutions, pages: 42, sizeMb: 5.6),
    StudyPdf(id: 'p5', title: 'Cell biology — notes', subjectId: 'bio', kind: PdfKind.notes, pages: 16, sizeMb: 4.2),
    StudyPdf(id: 'p6', title: 'NEET 2025 question paper', subjectId: 'bio', kind: PdfKind.pastPaper, pages: 32, sizeMb: 6.8),
    StudyPdf(id: 'p7', title: 'Calculus formula sheet', subjectId: 'mat', kind: PdfKind.formulas, pages: 4, sizeMb: 0.6),
    StudyPdf(id: 'p8', title: 'JEE Main 2025 question paper', subjectId: 'mat', kind: PdfKind.pastPaper, pages: 28, sizeMb: 5.9),
    StudyPdf(id: 'p9', title: 'CBSE Class 12 CS sample paper', subjectId: 'cs', kind: PdfKind.pastPaper, pages: 12, sizeMb: 1.4),
  ];

  static Subject subject(String id) => subjects.firstWhere((s) => s.id == id);

  static Topic? topic(String id) {
    for (final s in subjects) {
      for (final t in s.topics) {
        if (t.id == id) return t;
      }
    }
    return null;
  }

  static Question question(String id) => questions.firstWhere((q) => q.id == id);

  static MockTest test(String id) => tests.firstWhere((t) => t.id == id);
}
