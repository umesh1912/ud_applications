import 'package:flutter/material.dart';

import 'data/questions.dart';
import 'speaker.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// Shows one question and its answer controls. The parent screen owns the
/// game state (timer, score, lifelines) and tells this view what to show.
class QuestionView extends StatefulWidget {
  const QuestionView({
    super.key,
    required this.q,
    required this.revealed,
    required this.onChoose,
    required this.onType,
    this.chosen,
    this.typed,
    this.hidden = const {},
  });

  final Q q;
  final bool revealed;
  final int? chosen;
  final String? typed;
  final Set<int> hidden;
  final ValueChanged<int> onChoose;
  final ValueChanged<String> onType;

  @override
  State<QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<QuestionView> {
  final _ctrl = TextEditingController();

  @override
  void didUpdateWidget(QuestionView old) {
    super.didUpdateWidget(old);
    if (old.q.id != widget.q.id) _ctrl.clear();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _spoken(String lang) {
    final q = widget.q;
    final opts = q.options.isEmpty ? '' : '. ${q.options.map((o) => o.of(lang)).join(', ')}';
    return '${q.text.of(lang)}$opts';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final lang = store.lang;
    final q = widget.q;
    final sc = context.sc;
    final showText = q.type != QType.listen || widget.revealed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: q.cat.color,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: sc.line, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(q.cat.icon, size: 16, color: const Color(0xFF1C1B2E)),
                  const SizedBox(width: 4),
                  Text(q.cat.name.of(lang), style: context.tt.labelMedium!.copyWith(color: const Color(0xFF1C1B2E))),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: store.t('Read aloud', 'पढ़कर सुनाएँ'),
              onPressed: () => Speaker.say(_spoken(lang), lang),
              icon: const Icon(Icons.volume_up_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (q.type == QType.picture && q.picture != null) ...[
          Center(
            child: Sticker(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              child: Text(q.picture!, style: const TextStyle(fontSize: 84, height: 1.1)),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (q.type == QType.listen) ...[
          Sticker(
            color: const Color(0xFF3BA7FF),
            onTap: () => Speaker.say(_spoken(lang), lang),
            semanticLabel: store.t('Play the question', 'सवाल सुनें'),
            child: Row(
              children: [
                const Icon(Icons.hearing_rounded, size: 36, color: Color(0xFF1C1B2E)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    store.t('Listen to the question. Tap to hear it again.', 'सवाल सुनिए। दोबारा सुनने के लिए टैप करें।'),
                    style: context.tt.titleMedium!.copyWith(color: const Color(0xFF1C1B2E)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (showText)
          Text(q.text.of(lang), style: context.tt.headlineSmall!.copyWith(height: 1.25)),
        const SizedBox(height: 18),
        if (q.type == QType.fill)
          _fill(context, store)
        else
          for (var i = 0; i < q.options.length; i++)
            if (!widget.hidden.contains(i))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _Option(
                  letter: q.type == QType.trueFalse ? null : String.fromCharCode(65 + i),
                  text: q.options[i].of(lang),
                  state: _stateFor(i),
                  onTap: widget.revealed ? null : () => widget.onChoose(i),
                ),
              ),
      ],
    );
  }

  _OptState _stateFor(int i) {
    if (!widget.revealed) return _OptState.idle;
    if (i == widget.q.answer) return _OptState.right;
    if (i == widget.chosen) return _OptState.wrong;
    return _OptState.dim;
  }

  Widget _fill(BuildContext context, Store store) {
    final sc = context.sc;
    if (widget.revealed) {
      final ok = widget.typed != null && widget.q.checkTyped(widget.typed!);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Sticker(
            color: ok ? sc.right : sc.wrong,
            child: Text(
              widget.typed == null || widget.typed!.isEmpty ? store.t('No answer', 'कोई जवाब नहीं') : widget.typed!,
              style: context.tt.titleLarge!.copyWith(color: const Color(0xFF1C1B2E)),
            ),
          ),
          if (!ok) ...[
            const SizedBox(height: 6),
            Text('${store.t('Answer', 'उत्तर')}: ${widget.q.accept.first}', style: context.tt.titleMedium),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          autofocus: true,
          textInputAction: TextInputAction.done,
          style: context.tt.titleLarge,
          decoration: InputDecoration(hintText: store.t('Type your answer', 'अपना जवाब लिखें')),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) widget.onType(v);
          },
        ),
        const SizedBox(height: 12),
        BigButton(
          label: store.t('Check answer', 'जवाब जाँचें'),
          onTap: () {
            if (_ctrl.text.trim().isNotEmpty) widget.onType(_ctrl.text);
          },
        ),
      ],
    );
  }
}

enum _OptState { idle, right, wrong, dim }

class _Option extends StatelessWidget {
  const _Option({required this.letter, required this.text, required this.state, required this.onTap});

  final String? letter;
  final String text;
  final _OptState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sc = context.sc;
    final Color bg = switch (state) {
      _OptState.right => sc.right,
      _OptState.wrong => sc.wrong,
      _ => sc.card,
    };
    final fg = state == _OptState.right || state == _OptState.wrong ? const Color(0xFF1C1B2E) : sc.ink;
    return Opacity(
      opacity: state == _OptState.dim ? 0.55 : 1,
      child: Sticker(
        color: bg,
        onTap: onTap,
        depth: 3,
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        semanticLabel: state == _OptState.right
            ? '$text, correct answer'
            : state == _OptState.wrong
                ? '$text, your answer, wrong'
                : text,
        child: Row(
          children: [
            if (letter != null) ...[
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: state == _OptState.idle ? const Color(0xFFFFD23F) : Colors.white.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: sc.line, width: 2),
                ),
                child: Text(letter!, style: context.tt.labelMedium!.copyWith(color: const Color(0xFF1C1B2E))),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(text, style: context.tt.titleMedium!.copyWith(color: fg))),
            if (state == _OptState.right) const Icon(Icons.check_circle, color: Color(0xFF1C1B2E)),
            if (state == _OptState.wrong) const Icon(Icons.cancel, color: Color(0xFF1C1B2E)),
          ],
        ),
      ),
    );
  }
}
