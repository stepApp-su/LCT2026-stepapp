import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../theme/finni_theme.dart';
import '../widgets/finni_ui.dart';

Future<void> showTutorial(
  BuildContext context, {
  required String title,
  required List<TutorialStep> steps,
  required bool motion,
}) {
  if (steps.isEmpty) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: FinniColors.background,
    builder: (context) => TutorialSheet(title: title, steps: steps, motion: motion),
  );
}

class TutorialSheet extends StatefulWidget {
  const TutorialSheet({
    super.key,
    required this.title,
    required this.steps,
    required this.motion,
  });

  final String title;
  final List<TutorialStep> steps;
  final bool motion;

  @override
  State<TutorialSheet> createState() => _TutorialSheetState();
}

class _TutorialSheetState extends State<TutorialSheet> {
  int step = 0;

  bool get last => step == widget.steps.length - 1;

  @override
  Widget build(BuildContext context) {
    final current = widget.steps[step];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Как играть: ${widget.title}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: motionAllowed(context, widget.motion)
                ? const Duration(milliseconds: 280)
                : Duration.zero,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: const Offset(.15, 0), end: Offset.zero)
                    .animate(animation),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey(step),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  decoration: BoxDecoration(
                    color: [
                      FinniColors.mint,
                      FinniColors.sky,
                      FinniColors.lavender,
                      FinniColors.honey,
                    ][step % 4],
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: PopIn(
                    motion: widget.motion,
                    child: Text(
                      current.emoji,
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(fontSize: 56, height: 1.1),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  current.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            label: 'Шаг ${step + 1} из ${widget.steps.length}',
            excludeSemantics: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.steps.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == step ? 22 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: i == step ? FinniColors.primary : FinniColors.line,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (step > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => step--),
                    child: const Text('Назад'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: last
                      ? () => Navigator.pop(context)
                      : () => setState(() => step++),
                  icon: Icon(last
                      ? Icons.play_arrow_rounded
                      : Icons.arrow_forward_rounded),
                  label: Text(last ? 'Понятно, играем!' : 'Дальше'),
                ),
              ),
            ],
          ),
          if (!last)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Пропустить'),
            ),
        ],
      ),
    );
  }
}
