import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../../domain/services/phrase_service.dart';
import '../../domain/services/task_engine.dart';
import '../game_controller.dart';
import '../theme/finni_theme.dart';
import '../widgets/emoji_art.dart';
import '../widgets/finni_ui.dart';
import '../widgets/moni_scene.dart';
import 'game_boards.dart';
import 'tutorial_sheet.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.state, required this.taskId});

  final GameController state;
  final String taskId;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final TaskSession session;
  TaskAnswer? answer;
  TaskFeedback? feedback;
  GameReward? reward;
  PhraseLine? petLine;
  bool showFeedback = false;

  GameController get s => widget.state;

  @override
  void initState() {
    super.initState();
    session = s.startGame(widget.taskId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => petLine = s.say('task_start'));
      if (!s.tutorialSeen(session.task.id)) {
        _tutorial().whenComplete(() => s.markTutorialSeen(session.task.id));
      }
    });
  }
  TaskTexts get texts => s.content.tasks.texts;
  bool get finished => reward != null;

  Map<String, String> get binLabels => {
        for (final entry in s.content.shop.categories.entries)
          entry.key.name: entry.value.label,
      };

  void _submit(TaskAnswer value) {
    if (finished) return;
    final result = session.submit(value);
    final line = s.reactToAnswer(session, result);
    setState(() {
      feedback = result;
      petLine = line;
      showFeedback = true;
    });
    if (result.isCorrect) _complete();
  }

  void _complete() {
    final earned = s.finishGame(session);
    setState(() => reward = earned);
    Celebration.show(
      context,
      motion: s.motion,
      emoji: earned.stars == 3 ? '🌟' : '🎉',
      text: earned.coins > 0 ? '+${earned.coins} монет' : 'Получилось!',
    );
  }

  void _giveUp() {
    final earned = s.finishGame(session);
    setState(() => reward = earned);
  }

  Future<void> _tutorial() => showTutorial(
        context,
        title: session.task.title,
        steps: s.tutorialFor(session.task),
        motion: s.motion,
      );

  void _hint() {
    final line = s.hintFor(session);
    setState(() => petLine = line);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: FinniColors.background,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('💡', style: TextStyle(fontSize: 48), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(session.variant.hint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            if (line != null) ...[
              const SizedBox(height: 12),
              Text(line.textRu,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: FinniColors.muted)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = session.task;
    final variant = session.variant;
    final theme = s.content.tasks.theme(task.themeId);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(22) * 2.7 + 8,
        leading: IconButton(
          tooltip: 'Назад',
          onPressed: () => Navigator.pop(context, reward),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(task.title, maxLines: 2),
        actions: [
          IconButton(
            tooltip: 'Как играть',
            onPressed: _tutorial,
            icon: const Icon(Icons.school_outlined),
          ),
          IconButton(
            tooltip: texts.hintButton,
            onPressed: finished ? null : _hint,
            icon: const Icon(Icons.lightbulb_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      _intro(task, variant, theme),
                      const SizedBox(height: 16),
                      buildBoard(BoardContext(
                        task: task,
                        variant: variant,
                        texts: texts,
                        plan: s.content.economy.params.plan,
                        binLabels: binLabels,
                        check: showFeedback ? feedback?.check : null,
                        locked: finished,
                        motion: s.motion,
                        onChanged: (value) {
                          if (!mounted) return;
                          setState(() {
                            answer = value;
                            if (!finished) showFeedback = false;
                          });
                        },
                        onSubmit: _submit,
                      )),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: motionAllowed(context, s.motion)
                            ? const Duration(milliseconds: 280)
                            : Duration.zero,
                        child: showFeedback && feedback != null
                            ? _feedbackCard(feedback!)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                _bottomBar(task),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _intro(TaskDef task, TaskVariant variant, TaskTheme? theme) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 92,
            height: 104,
            child: MoniScene(motion: s.motion, outfit: s.outfit),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (theme != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: TagPill(
                      icon: Icons.school_outlined,
                      label: theme.title,
                      color: artBackground(theme.id),
                    ),
                  ),
                if (petLine != null && !finished)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 4),
                    child: Text(
                      petLine!.textRu,
                      style: const TextStyle(
                          color: FinniColors.primary,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                Material(
                  color: FinniColors.paper,
                  elevation: 2,
                  shadowColor: FinniColors.shadow,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                    bottomRight: Radius.circular(22),
                    bottomLeft: Radius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      variant.intro,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700, height: 1.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _feedbackCard(TaskFeedback result) {
    final check = result.check;
    final earned = reward;
    return switch (check.verdict) {
      TaskVerdict.correct => FinniCard(
          key: const ValueKey('correct'),
          color: FinniColors.mint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 36)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      earned != null && earned.withMistakes
                          ? 'Разобрались!'
                          : 'С первого раза!',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (earned != null) StarRow(stars: earned.stars, size: 28),
                ],
              ),
              const SizedBox(height: 10),
              Text(check.explanation, style: const TextStyle(fontSize: 17)),
              if (earned != null) ...[
                const SizedBox(height: 12),
                _rewardLine(earned),
              ],
            ],
          ),
        ),
      TaskVerdict.wrong => FinniCard(
          key: ValueKey('wrong-${result.attempt}'),
          color: FinniColors.lavender,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('🤗', style: TextStyle(fontSize: 34)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      petLine?.textRu ?? 'Давай посмотрим вместе',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(check.explanation, style: const TextStyle(fontSize: 17)),
              for (final line in check.details.skip(1).take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💭 '),
                      Expanded(child: Text(line)),
                    ],
                  ),
                ),
              if (earned != null) ...[
                const SizedBox(height: 12),
                _rewardLine(earned),
              ],
            ],
          ),
        ),
      TaskVerdict.incomplete => SoftNotice(
          key: const ValueKey('incomplete'),
          icon: Icons.touch_app_outlined,
          text: check.explanation,
        ),
    };
  }

  Widget _rewardLine(GameReward earned) => FinniCard(
        color: FinniColors.paper,
        padding: 12,
        child: Row(
          children: [
            if (earned.coins > 0) ...[
              CoinAmount(earned.coins, prefix: '+', size: 24),
              const SizedBox(width: 10),
              const Expanded(child: Text('Монеты уже в кошельке')),
            ] else
              const Expanded(
                child: Text(
                    'Монеты за игры сегодня уже получены. Играть можно сколько хочешь!'),
              ),
          ],
        ),
      );

  Widget _bottomBar(TaskDef task) {
    final result = feedback;
    final wrongShown =
        showFeedback && result != null && result.verdict == TaskVerdict.wrong;
    final Widget content;
    if (finished) {
      content = FilledButton.icon(
        onPressed: () => Navigator.pop(context, reward),
        icon: const Icon(Icons.celebration_outlined),
        label: Text(texts.next),
      );
    } else if (wrongShown) {
      content = Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _giveUp,
              child: const Text('Дальше без ответа'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => setState(() => showFeedback = false),
              icon: const Icon(Icons.replay_rounded),
              label: Text(texts.tryAgain),
            ),
          ),
        ],
      );
    } else if (task.type == TaskType.board ||
        task.type == TaskType.stall ||
        task.type == TaskType.cashier ||
        task.type == TaskType.pricetag) {
      content = const Text(
        'Играй до конца — я расскажу, что получилось',
        textAlign: TextAlign.center,
        style: TextStyle(color: FinniColors.muted),
      );
    } else if (task.type == TaskType.choice) {
      content = const Text(
        'Выбери вариант — я сразу расскажу, что будет',
        textAlign: TextAlign.center,
        style: TextStyle(color: FinniColors.muted),
      );
    } else {
      final current = answer;
      content = FilledButton.icon(
        onPressed: current == null ? null : () => _submit(current),
        icon: const Icon(Icons.check_circle_outline_rounded),
        label: Text(texts.check),
      );
    }
    return Container(
      decoration: const BoxDecoration(
        color: FinniColors.paper,
        border: Border(top: BorderSide(color: FinniColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(width: double.infinity, child: content),
    );
  }
}
