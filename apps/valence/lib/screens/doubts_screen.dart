import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Ask a doubt (text + optional photo) and see teachers' answers.
class DoubtsScreen extends StatefulWidget {
  const DoubtsScreen({super.key, this.startAsking = false, this.subjectId, this.prefill});

  final bool startAsking;
  final String? subjectId;
  final String? prefill;

  @override
  State<DoubtsScreen> createState() => _DoubtsScreenState();
}

class _DoubtsScreenState extends State<DoubtsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.startAsking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ask();
      });
    }
  }

  Future<void> _ask() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AskSheet(subjectId: widget.subjectId, prefill: widget.prefill),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doubt sent. You\'ll get a notification when a teacher answers.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Doubts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ask,
        backgroundColor: context.vc.highlight,
        foregroundColor: context.vc.highlightInk,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Ask a doubt'),
      ),
      body: state.doubts.isEmpty
          ? EmptyNote(
              icon: Icons.forum_outlined,
              title: 'No doubts yet',
              body: 'Stuck on a step? Type the question or snap a photo of it, and a teacher will reply.',
              action: 'Ask a doubt',
              onAction: _ask,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 100),
              itemCount: state.doubts.length,
              separatorBuilder: (_, __) => const SizedBox(height: Space.m),
              itemBuilder: (context, i) => _DoubtCard(doubt: state.doubts[i]),
            ),
    );
  }
}

class _DoubtCard extends StatelessWidget {
  const _DoubtCard({required this.doubt});

  final Doubt doubt;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final d = doubt;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SubjectMark(d.subjectId, size: 24),
              const SizedBox(width: Space.s),
              Text(relativeDay(d.askedAt), style: context.text.labelSmall),
              const Spacer(),
              if (d.status == DoubtStatus.waiting)
                Row(
                  children: [
                    const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6)),
                    const SizedBox(width: 6),
                    Text('Waiting for a teacher', style: context.text.labelSmall),
                  ],
                )
              else
                Text('Answered', style: context.text.labelSmall!.copyWith(color: Palette.correct)),
            ],
          ),
          const SizedBox(height: Space.s),
          Text(d.question, style: context.text.titleSmall),
          if (d.hasPhoto) ...[
            const SizedBox(height: Space.s),
            Row(
              children: [
                Icon(Icons.image_outlined, size: 16, color: vc.muted),
                const SizedBox(width: 4),
                Text('Photo attached', style: context.text.bodySmall),
              ],
            ),
          ],
          if (d.answer != null) ...[
            const SizedBox(height: Space.m),
            Container(
              padding: const EdgeInsets.all(Space.m),
              decoration: BoxDecoration(
                color: vc.paper,
                borderRadius: BorderRadius.circular(Radii.card - 4),
                border: Border(left: BorderSide(color: vc.highlight, width: 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.answer!, style: context.text.bodyMedium),
                  const SizedBox(height: Space.s),
                  Text(d.answeredBy ?? '', style: context.text.labelSmall),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AskSheet extends StatefulWidget {
  const _AskSheet({this.subjectId, this.prefill});

  final String? subjectId;
  final String? prefill;

  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  late String _subjectId = widget.subjectId ?? 'phy';
  late final _text = TextEditingController(text: widget.prefill ?? '');
  bool _photo = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    if (_text.text.trim().length < 10) {
      setState(() => _error = 'Add a little more detail — at least 10 characters.');
      return;
    }
    AppScope.read(context).askDoubt(subjectId: _subjectId, question: _text.text.trim(), hasPhoto: _photo);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.gutter, 0, Space.gutter, MediaQuery.of(context).viewInsets.bottom + Space.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ask a doubt', style: context.text.headlineSmall),
          const SizedBox(height: Space.l),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in SampleData.subjects) ...[
                  ChoiceChip(
                    avatar: SubjectMark(s.id, size: 20),
                    label: Text(s.name),
                    selected: _subjectId == s.id,
                    onSelected: (_) => setState(() => _subjectId = s.id),
                  ),
                  const SizedBox(width: Space.s),
                ],
              ],
            ),
          ),
          const SizedBox(height: Space.m),
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Describe where you\'re stuck. Include the question and your working if you can.',
              errorText: _error,
            ),
          ),
          const SizedBox(height: Space.s),
          // Wire up image_picker here for camera/gallery.
          OutlinedButton.icon(
            onPressed: () => setState(() => _photo = !_photo),
            icon: Icon(_photo ? Icons.check : Icons.photo_camera_outlined),
            label: Text(_photo ? 'Photo attached — tap to remove' : 'Add a photo of the question'),
          ),
          const SizedBox(height: Space.l),
          FilledButton(
            onPressed: _send,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Send doubt'),
          ),
        ],
      ),
    );
  }
}
