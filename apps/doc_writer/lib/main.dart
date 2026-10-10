import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:ud_core/ud_core.dart';

import 'formats.dart';
import 'strings.dart';

const appName = 'Likho';

final docs = UdListStore('writer.docs');

void main() => runUdApp(UdAppSpec(
      name: appName,
      taglineKey: 'tagline',
      accent: const Color(0xFF5A4A3A),
      icon: Icons.edit_note_rounded,
      strings: writerStrings,
      home: (_) => const HomePage(),
    ));

List<Block> blocksOf(Map<String, dynamic> d) => [
      for (final b in (d['blocks'] as List<dynamic>? ?? const []))
        Block.fromJson(Map<String, dynamic>.from(b as Map)),
    ];

int wordCount(List<Block> blocks) =>
    blocks.fold(0, (n, b) => n + b.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length);

const templates = <String, List<List<String>>>{
  'tpl_blank': [
    ['p', ''],
  ],
  'tpl_letter': [
    ['p', 'Your name\nYour address\nCity, PIN'],
    ['p', 'Date: '],
    ['p', 'To,\nThe Manager\nCompany / Office name\nAddress'],
    ['h2', 'Subject: '],
    ['p', 'Respected Sir/Madam,'],
    ['p', 'I am writing to …'],
    ['p', 'Thank you for your time and consideration.'],
    ['p', 'Yours faithfully,\nYour name'],
  ],
  'tpl_leave': [
    ['p', 'To,\nThe Principal / Manager\nSchool / Company name'],
    ['p', 'Date: '],
    ['h2', 'Subject: Application for leave'],
    ['p', 'Respected Sir/Madam,'],
    ['p', 'I request leave from __ to __ because __. I will make sure my work is covered during this time.'],
    ['p', 'Kindly grant me leave for these days.'],
    ['p', 'Yours sincerely,\nName\nClass / Employee ID'],
  ],
  'tpl_resume': [
    ['h1', 'Your Name'],
    ['p', 'Phone · Email · City'],
    ['h2', 'Objective'],
    ['p', 'One or two lines about the role you want.'],
    ['h2', 'Experience'],
    ['li', 'Job title, Company (Year – Year): what you achieved'],
    ['h2', 'Education'],
    ['li', 'Degree, College (Year) — marks'],
    ['h2', 'Skills'],
    ['li', 'Skill one'],
    ['li', 'Skill two'],
    ['h2', 'Languages'],
    ['li', 'English, Hindi, Gujarati'],
  ],
  'tpl_notes': [
    ['h1', 'Meeting notes'],
    ['p', 'Date: \nPeople: '],
    ['h2', 'Discussed'],
    ['li', ''],
    ['h2', 'Decisions'],
    ['li', ''],
    ['h2', 'Next steps'],
    ['li', 'Who · What · By when'],
  ],
};

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    docs.load();
  }

  Future<void> _open(Map<String, dynamic> d) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorPage(docId: d['id'] as String)));

  Future<void> _create(String title, List<Block> blocks) async {
    final d = await docs.add({
      'title': title,
      'blocks': [for (final b in blocks) b.toJson()],
      'updated': DateTime.now().toIso8601String(),
    });
    if (mounted) await _open(d);
  }

  Future<void> _new() async {
    final key = await showUdActions<String>(context, title: context.tr('templates'), actions: [
      UdAction('tpl_blank', Icons.note_add_outlined, context.tr('tpl_blank')),
      UdAction('tpl_letter', Icons.mail_outline_rounded, context.tr('tpl_letter')),
      UdAction('tpl_leave', Icons.event_busy_outlined, context.tr('tpl_leave')),
      UdAction('tpl_resume', Icons.badge_outlined, context.tr('tpl_resume')),
      UdAction('tpl_notes', Icons.groups_outlined, context.tr('tpl_notes')),
    ]);
    if (key == null || !mounted) return;
    final title = key == 'tpl_blank' ? context.tr('untitled') : context.tr(key);
    await _create(title, [for (final b in templates[key]!) Block(b[0], b[1])]);
  }

  Future<void> _import() async {
    final paths = await udPickFiles(extensions: const ['docx', 'txt', 'pdf']);
    if (paths.isEmpty || !mounted) return;
    final path = paths.first;
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    final ext = dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
    final title = dot == -1 ? name : name.substring(0, dot);
    try {
      final bytes = await File(path).readAsBytes();
      final blocks = switch (ext) {
        'docx' => readDocx(bytes),
        'pdf' => readPdfText(bytes),
        _ => readText(utf8.decode(bytes, allowMalformed: true)),
      };
      if (!mounted) return;
      if (ext == 'pdf') udToast(context, context.tr('opened_pdf'));
      await _create(title, blocks.isEmpty ? [Block('p', '')] : blocks);
    } catch (_) {
      if (mounted) udToast(context, context.tr('could_not_open'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: docs,
      builder: (context, _) {
        final list = [...docs.items]
          ..sort((a, b) => (b['updated'] as String).compareTo(a['updated'] as String));
        return UdPage(
          eyebrow: appName,
          title: context.tr('home_title'),
          subtitle: context.tr('home_sub'),
          actions: const [UdSettingsButton(appName: appName)],
          dock: UdDock(
            label: context.tr('new_doc'),
            icon: Icons.add_rounded,
            onPressed: _new,
            extras: [
              UdDockAction(icon: Icons.file_open_outlined, label: context.tr('import'), onTap: _import),
            ],
          ),
          slivers: [
            UdSliverPad(
              bottom: 16,
              sliver: SliverToBoxAdapter(
                child: UdRow(
                  leading: const UdBadgeIcon(Icons.file_open_outlined),
                  title: context.tr('import'),
                  subtitle: context.tr('import_sub'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _import,
                ),
              ),
            ),
            if (docs.loaded && list.isEmpty)
              SliverToBoxAdapter(
                child: UdEmpty(
                  icon: Icons.edit_note_rounded,
                  title: context.tr('empty_title'),
                  body: context.tr('empty_body'),
                ),
              )
            else
              UdSliverPad(
                sliver: SliverList.list(children: [
                  for (final d in list)
                    UdRow(
                      leading: const UdBadgeIcon(Icons.description_outlined),
                      title: (d['title'] as String).isEmpty ? context.tr('untitled') : d['title'] as String,
                      subtitle:
                          '${context.tr('words', {'n': '${wordCount(blocksOf(d))}'})} · ${udFormatDate(context, DateTime.parse(d['updated'] as String))}',
                      onTap: () => _open(d),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () async {
                          if (await udConfirm(context)) docs.remove(d['id'] as String);
                        },
                      ),
                    ),
                ]),
              ),
          ],
        );
      },
    );
  }
}

class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.docId});
  final String docId;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late Map<String, dynamic> _doc;
  late final TextEditingController _title;
  final _blocks = <Block>[];
  final _ctrls = <TextEditingController>[];
  final _focus = <FocusNode>[];
  int _current = 0;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _doc = Map<String, dynamic>.from(docs.items.firstWhere((d) => d['id'] == widget.docId));
    _title = TextEditingController(text: _doc['title'] as String? ?? '');
    _title.addListener(_scheduleSave);
    for (final b in blocksOf(_doc)) {
      _insert(_blocks.length, b);
    }
    if (_blocks.isEmpty) _insert(0, Block('p', ''));
  }

  void _insert(int at, Block b) {
    final c = TextEditingController(text: b.text);
    c.addListener(() {
      b.text = c.text;
      _scheduleSave();
    });
    final f = FocusNode();
    f.addListener(() {
      if (f.hasFocus) {
        final i = _focus.indexOf(f);
        if (i != -1 && i != _current) setState(() => _current = i);
      }
    });
    _blocks.insert(at, b);
    _ctrls.insert(at, c);
    _focus.insert(at, f);
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _save);
  }

  Future<void> _save() async {
    _doc['title'] = _title.text.trim();
    _doc['blocks'] = [for (final b in _blocks) b.toJson()];
    _doc['updated'] = DateTime.now().toIso8601String();
    await docs.put(_doc);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _save();
    _title.dispose();
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  void _setType(String type) {
    setState(() => _blocks[_current].type = type);
    _scheduleSave();
  }

  void _addBelow() {
    final type = _blocks[_current].type == 'li' ? 'li' : 'p';
    setState(() => _insert(_current + 1, Block(type, '')));
    final i = _current + 1;
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus[i].requestFocus());
    _scheduleSave();
  }

  void _removeCurrent() {
    if (_blocks.length == 1) {
      _ctrls[0].clear();
      return;
    }
    final i = _current;
    setState(() {
      _blocks.removeAt(i);
      _ctrls.removeAt(i).dispose();
      _focus.removeAt(i).dispose();
      _current = (i - 1).clamp(0, _blocks.length - 1);
    });
    _focus[_current].requestFocus();
    _scheduleSave();
  }

  String get _name => _title.text.trim().isEmpty ? context.tr('untitled') : _title.text.trim();

  Future<void> _export() async {
    final choice = await showUdActions<String>(context, title: context.tr('export'), actions: [
      UdAction('docx', Icons.description_outlined, context.tr('export_word')),
      UdAction('pdf', Icons.picture_as_pdf_outlined, context.tr('export_pdf')),
      UdAction('print', Icons.print_outlined, context.tr('print')),
    ]);
    if (choice == null || !mounted) return;
    await _save();
    final name = udSafeName(_name);
    try {
      if (choice == 'print') {
        await Printing.layoutPdf(name: name, onLayout: (_) => buildPdf(_name, _blocks));
        return;
      }
      final Uint8List bytes = choice == 'docx'
          ? buildDocx(_name, _blocks)
          : await udBusy(context, () => buildPdf(_name, _blocks));
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/$name.$choice');
      await f.writeAsBytes(bytes, flush: true);
      if (choice == 'pdf' && mounted && _blocks.any((b) => RegExp(r'[ऀ-૿]').hasMatch(b.text))) {
        udToast(context, context.tr('pdf_note'));
      }
      await udShareFiles([f.path]);
    } catch (_) {
      if (mounted) udToast(context, context.tr('error_generic'));
    }
  }

  TextStyle? _styleFor(String type, TextTheme text) => switch (type) {
        'h1' => text.headlineMedium,
        'h2' => text.titleLarge,
        _ => text.bodyLarge?.copyWith(height: 1.55),
      };

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;

    Widget typeChip(String type, IconData icon) {
      final sel = _blocks[_current].type == type;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Tooltip(
          message: context.tr(type),
          child: InkResponse(
            onTap: () => _setType(type),
            radius: 24,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: sel ? t.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: sel ? t.onAccent : t.paper, size: 22),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  UdIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${context.tr('words', {'n': '${wordCount(_blocks)}'})} · ${context.tr('saved_auto')}',
                      style: text.bodySmall,
                    ),
                  ),
                  UdIconButton(icon: Icons.ios_share_rounded, filled: true, onTap: _export),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
                children: [
                  TextField(
                    controller: _title,
                    style: text.displaySmall,
                    maxLines: null,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: context.tr('title_hint'),
                      hintStyle: text.displaySmall?.copyWith(color: t.inkFaint),
                    ),
                  ),
                  Container(height: 1, color: t.line, margin: const EdgeInsets.only(bottom: 10)),
                  for (var i = 0; i < _blocks.length; i++)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_blocks[i].type == 'li')
                          Padding(
                            padding: const EdgeInsets.only(top: 12, right: 10),
                            child: Icon(Icons.circle, size: 7, color: t.ink),
                          ),
                        Expanded(
                          child: TextField(
                            controller: _ctrls[i],
                            focusNode: _focus[i],
                            maxLines: null,
                            style: _styleFor(_blocks[i].type, text),
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 6),
                              hintText: _blocks.length == 1 ? context.tr('type_here') : null,
                              hintStyle: _styleFor(_blocks[i].type, text)?.copyWith(color: t.inkFaint),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: t.ink, borderRadius: BorderRadius.circular(22)),
              child: Row(
                children: [
                  typeChip('h1', Icons.title_rounded),
                  typeChip('h2', Icons.text_fields_rounded),
                  typeChip('p', Icons.notes_rounded),
                  typeChip('li', Icons.format_list_bulleted_rounded),
                  const Spacer(),
                  IconButton(
                    tooltip: context.tr('remove_block'),
                    onPressed: _removeCurrent,
                    icon: Icon(Icons.backspace_outlined, color: t.paper),
                  ),
                  IconButton.filled(
                    tooltip: context.tr('add_block'),
                    onPressed: _addBelow,
                    style: IconButton.styleFrom(backgroundColor: t.accent),
                    icon: Icon(Icons.add_rounded, color: t.onAccent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
