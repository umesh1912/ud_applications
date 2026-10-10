import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:signature/signature.dart';
import 'package:ud_core/ud_core.dart';

import 'strings.dart';

const appName = 'Signa';

void main() => runUdApp(UdAppSpec(
      name: appName,
      taglineKey: 'tagline',
      accent: const Color(0xFF2B3A8C),
      icon: Icons.draw_rounded,
      strings: signStrings,
      home: (_) => const HomePage(),
    ));

/// Handwriting faces offered for typed signatures.
const signatureFonts = [
  'Great Vibes',
  'Dancing Script',
  'Allura',
  'Sacramento',
  'Caveat',
  'Satisfy',
];

const inkColors = <String, Color>{
  'ink_black': Color(0xFF111111),
  'ink_blue': Color(0xFF1C3A9E),
  'ink_red': Color(0xFFB0172B),
};

Future<List<File>> loadSignatures() async {
  final dir = await udDir('signatures');
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.png'))
      .toList()
    ..sort((a, b) => b.path.compareTo(a.path));
  return files;
}

Future<File> saveSignature(Uint8List png) async {
  final dir = await udDir('signatures');
  final f = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}.png');
  await f.writeAsBytes(png, flush: true);
  return f;
}

/// Renders typed text in a handwriting font to a transparent PNG.
Future<Uint8List> renderTyped(String text, String font, Color color) async {
  final style = GoogleFonts.getFont(font, fontSize: 140, color: color);
  await GoogleFonts.pendingFonts();
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  const pad = 32.0;
  final w = (tp.width + pad * 2).ceil();
  final h = (tp.height + pad * 2).ceil();
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  tp.paint(canvas, const Offset(pad, pad));
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<File>? _sigs;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final s = await loadSignatures();
    if (mounted) setState(() => _sigs = s);
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final sigs = _sigs;
    return UdPage(
      eyebrow: appName,
      title: context.tr('home_title'),
      subtitle: context.tr('home_sub'),
      actions: const [UdSettingsButton(appName: appName)],
      dock: UdDock(
        label: context.tr('new_sig'),
        icon: Icons.draw_rounded,
        onPressed: () => _open(const CreatePage()),
      ),
      slivers: [
        if (sigs == null)
          const SliverToBoxAdapter(
              child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator())))
        else if (sigs.isEmpty)
          SliverToBoxAdapter(
            child: UdEmpty(
              icon: Icons.gesture_rounded,
              title: context.tr('empty_title'),
              body: context.tr('empty_body'),
            ),
          )
        else
          UdSliverPad(
            sliver: SliverList.list(children: [
              for (final f in sigs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SignatureCard(
                    file: f,
                    onTap: () => _open(SignaturePage(file: f)),
                  ),
                ),
            ]),
          ),
      ],
    );
  }
}

/// Signature shown on a paper strip with a signing line, like on a form.
class _SignatureCard extends StatelessWidget {
  const _SignatureCard({required this.file, this.onTap, this.dark = false});
  final File file;
  final VoidCallback? onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final bg = dark ? const Color(0xFF1B1A17) : Colors.white;
    return UdPressable(
      onTap: onTap,
      color: bg,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        children: [
          SizedBox(
            height: 110,
            child: Center(
              child: Image.file(file, fit: BoxFit.contain, gaplessPlayback: true),
            ),
          ),
          Container(
            height: 1.2,
            margin: const EdgeInsets.only(top: 6),
            color: dark ? Colors.white24 : t.line,
          ),
        ],
      ),
    );
  }
}

class SignaturePage extends StatefulWidget {
  const SignaturePage({super.key, required this.file});
  final File file;

  @override
  State<SignaturePage> createState() => _SignaturePageState();
}

class _SignaturePageState extends State<SignaturePage> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    return UdPage(
      title: context.tr('home_title'),
      actions: [
        UdIconButton(
          icon: Icons.delete_outline_rounded,
          tooltip: context.tr('delete'),
          onTap: () async {
            if (!await udConfirm(context)) return;
            await widget.file.delete();
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
      dock: UdDock(
        label: context.tr('share_png'),
        icon: Icons.ios_share_rounded,
        onPressed: () => udShareFiles([widget.file.path]),
      ),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            _SignatureCard(file: widget.file, dark: _dark),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.light_mode_outlined),
                    label: Text(context.tr('on_light'))),
                ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.dark_mode_outlined),
                    label: Text(context.tr('on_dark'))),
              ],
              selected: {_dark},
              onSelectionChanged: (s) => setState(() => _dark = s.first),
            ),
            const SizedBox(height: 20),
            Text(context.tr('tip'),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: UdTokens.of(context).inkSoft)),
          ]),
        ),
      ],
    );
  }
}

class CreatePage extends StatefulWidget {
  const CreatePage({super.key});

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  bool _typeMode = false;
  String _ink = 'ink_blue';
  double _width = 3.2;
  late SignatureController _pad = _newPad();
  final _name = TextEditingController();
  String _font = signatureFonts.first;

  SignatureController _newPad([List<Point>? points]) {
    final c = SignatureController(
      points: points,
      penStrokeWidth: _width,
      penColor: inkColors[_ink]!,
      exportBackgroundColor: Colors.transparent,
    );
    c.addListener(() {
      if (mounted) setState(() {});
    });
    return c;
  }

  void _restyle({String? ink, double? width}) {
    setState(() {
      _ink = ink ?? _ink;
      _width = width ?? _width;
      final old = _pad;
      _pad = _newPad(List.of(old.points));
      old.dispose();
    });
  }

  @override
  void dispose() {
    _pad.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    Uint8List? png;
    if (_typeMode) {
      final n = _name.text.trim();
      if (n.isEmpty) {
        udToast(context, context.tr('type_first'));
        return;
      }
      png = await renderTyped(n, _font, inkColors[_ink]!);
    } else {
      if (_pad.isEmpty) {
        udToast(context, context.tr('draw_first'));
        return;
      }
      png = await _pad.toPngBytes();
    }
    if (png == null) return;
    await saveSignature(png);
    if (mounted) {
      udToast(context, context.tr('saved'));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final ink = inkColors[_ink]!;

    Widget inkDot(String key) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Tooltip(
            message: context.tr(key),
            child: GestureDetector(
              onTap: () => _restyle(ink: key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: inkColors[key],
                  border: Border.all(
                      color: key == _ink ? t.accent : t.line,
                      width: key == _ink ? 3 : 1),
                ),
              ),
            ),
          ),
        );

    return UdPage(
      title: context.tr('new_sig'),
      scrollable: _typeMode,
      dock: UdDock(
        label: context.tr('save_sig'),
        icon: Icons.check_rounded,
        onPressed: _save,
        extras: _typeMode
            ? const []
            : [
                UdDockAction(
                    icon: Icons.undo_rounded,
                    label: context.tr('undo'),
                    onTap: _pad.undo),
                UdDockAction(
                    icon: Icons.delete_sweep_outlined,
                    label: context.tr('clear'),
                    onTap: _pad.clear),
              ],
      ),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.gesture_rounded),
                    label: Text(context.tr('draw'))),
                ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.keyboard_outlined),
                    label: Text(context.tr('type'))),
              ],
              selected: {_typeMode},
              onSelectionChanged: (s) => setState(() => _typeMode = s.first),
            ),
            const SizedBox(height: 18),
            if (!_typeMode) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: t.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 54,
                      child: Container(height: 1.4, color: const Color(0xFFD9D2C3)),
                    ),
                    Positioned(
                      left: 24,
                      bottom: 26,
                      child: Text(
                        '✕  ${context.tr('sign_here')}',
                        style: text.bodySmall?.copyWith(color: const Color(0xFF9A9284)),
                      ),
                    ),
                    Signature(
                      key: ObjectKey(_pad),
                      controller: _pad,
                      height: 280,
                      backgroundColor: Colors.transparent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              TextField(
                controller: _name,
                style: text.bodyLarge,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: udInputDecoration(context,
                    hint: context.tr('your_name'), icon: Icons.person_outline),
              ),
              const SizedBox(height: 18),
              UdLabel(context.tr('pick_style')),
              for (final f in signatureFonts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: UdPressable(
                    onTap: () => setState(() => _font = f),
                    color: Colors.white,
                    borderRadius: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _name.text.trim().isEmpty ? 'Your Name' : _name.text.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.getFont(f, fontSize: 34, color: ink),
                          ),
                        ),
                        Icon(
                          f == _font
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: f == _font ? t.accent : const Color(0xFFC9C1B2),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
            ],
            UdLabel(context.tr('ink')),
            Row(children: [for (final k in inkColors.keys) inkDot(k)]),
            if (!_typeMode) ...[
              const SizedBox(height: 18),
              UdLabel(context.tr('thickness')),
              SegmentedButton<double>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 2.0, label: Text(context.tr('thin'))),
                  ButtonSegment(value: 3.2, label: Text(context.tr('medium'))),
                  ButtonSegment(value: 5.0, label: Text(context.tr('bold'))),
                ],
                selected: {_width},
                onSelectionChanged: (s) => _restyle(width: s.first),
              ),
            ],
          ]),
        ),
      ],
    );
  }
}
