import '../widgets/game_text.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../../domain/ru_words.dart';
import '../../domain/services/hint_service.dart';
import '../../domain/services/level_service.dart';
import '../../domain/services/phrase_service.dart';
import '../../domain/services/task_engine.dart';
import '../game_controller.dart';
import '../theme/finni_theme.dart';
import '../widgets/coach.dart';
import '../widgets/emoji_art.dart';
import '../widgets/finni_ui.dart';
import '../widgets/moni_scene.dart';
import 'game_boards.dart';

enum GameMode { practice, level, daily, improve }

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.state,
    required this.taskId,
    this.mode = GameMode.practice,
    this.slot = 0,
  });

  final GameController state;
  final String taskId;
  final GameMode mode;
  final int slot;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final TaskSession session;
  TaskAnswer? answer;
  TaskFeedback? feedback;
  GameReward? reward;
  PhraseLine? petLine;
  LevelStep? step;
  bool showFeedback = false;
  HintSituation Function()? situation;

  GameController get s => widget.state;

  @override
  void initState() {
    super.initState();
    session = switch (widget.mode) {
      GameMode.practice => s.startGame(widget.taskId),
      GameMode.level => s.startLevelGame(),
      GameMode.daily => s.startDailyGame(),
      GameMode.improve => s.startImprove(widget.slot),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => petLine = s.say('task_start'));
      if (!s.tutorialSeen(session.task.id)) {
        unawaited(_tutorial(first: true)
            .whenComplete(() => s.markTutorialSeen(session.task.id)));
      }
    });
  }

  TaskTexts get texts => s.content.tasks.texts;
  bool get finished => reward != null;

  Map<String, String> get binLabels => {
        for (final entry in s.content.shop.categories.entries)
          entry.key.name: entry.value.label,
        ...texts.sort.bins,
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

  bool get inLevel => widget.mode == GameMode.level;

  GameReward _finish() {
    switch (widget.mode) {
      case GameMode.practice:
        return s.finishGame(session);
      case GameMode.daily:
        return s.finishDaily(session);
      case GameMode.level:
        final result = s.finishLevelGame(session);
        step = result;
        return result.reward;
      case GameMode.improve:
        return s.finishImprove(widget.slot, session);
    }
  }

  void _complete() {
    final earned = _finish();
    setState(() => reward = earned);
    Celebration.show(
      context,
      motion: s.motion,
      emoji: earned.stars == 3 ? '🌟' : '🎉',
      text: earned.coins > 0 ? '+${earned.coins} монет' : 'Получилось!',
    );
  }

  void _giveUp() {
    final earned = _finish();
    setState(() => reward = earned);
  }

  Future<void> _tutorial({bool first = false}) async {
    final intro = first && !s.coachSeen('game');
    await Coach.run(
      context,
      steps: s.gameCoach(session.task, first: first),
      texts: s.coach.texts,
      values: {'name': s.petName},
      motion: s.motion,
    );
    if (intro) s.markCoachSeen(const ['game']);
  }

  void _hint() {
    final line = s.hintFor(session);
    final variant = session.variant;
    final hint =
        s.hints.hint(variant, answer: answer, situation: situation?.call());
    final general = variant.hint.trim();
    final showGeneral = general.isNotEmpty && !hint.text.contains(general);
    setState(() => petLine = line);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: FinniColors.background,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GameText(hint.ready ? '👍' : '💡',
                style: const TextStyle(fontSize: 48),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            GameText(hint.text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            if (showGeneral) ...[
              const SizedBox(height: 16),
              SoftNotice(
                icon: Icons.lightbulb_outline_rounded,
                text: general,
                color: FinniColors.paper,
              ),
            ],
            if (line != null) ...[
              const SizedBox(height: 12),
              GameText(line.textRu,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 16, color: FinniColors.muted)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const GameText('Понятно'),
            ),
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
        title: GameText(task.title, maxLines: 2),
        actions: [
          CoachTarget(
            id: 'game.help',
            child: IconButton(
              tooltip: 'Как играть',
              onPressed: _tutorial,
              icon: const Icon(Icons.school_outlined),
            ),
          ),
          CoachTarget(
            id: 'game.hint',
            child: IconButton(
              tooltip: texts.hintButton,
              onPressed: finished ? null : _hint,
              icon: const Icon(Icons.lightbulb_outline_rounded),
            ),
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
                      CoachTarget(
                        id: 'game.board',
                        child: buildBoard(BoardContext(
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
                          onSituation: (read) => situation = read,
                          sound: s.fx,
                        )),
                      ),
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
            child: MoniScene(
                appearance: s.appearance,
                stage: s.stage,
                motion: s.motion,
                outfit: s.outfit,
                onPet: s.petVoice),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final (i, label) in _levelLabels().indexed)
                        TagPill(
                          icon:
                              i == 0 ? Icons.flag_rounded : Icons.stars_rounded,
                          label: label,
                          color: i == 0 ? FinniColors.honey : FinniColors.mint,
                        ),
                      if (widget.mode == GameMode.daily)
                        const TagPill(
                          icon: Icons.wb_sunny_rounded,
                          label: 'Задание дня',
                          color: FinniColors.honey,
                        ),
                      if (widget.mode != GameMode.practice &&
                          variant.difficulty == TaskDifficulty.hard)
                        const TagPill(
                          icon: Icons.local_fire_department_outlined,
                          label: 'Посложнее',
                          color: FinniColors.lavender,
                        ),
                      if (widget.mode == GameMode.practice && session.count > 1)
                        TagPill(
                          icon: Icons.layers_outlined,
                          label:
                              'Задание ${session.index + 1} из ${session.count}',
                          color: FinniColors.sky,
                        ),
                      if (theme != null)
                        TagPill(
                          icon: Icons.school_outlined,
                          label: theme.title,
                          color: artBackground(theme.id),
                        ),
                    ],
                  ),
                ),
                if (petLine != null && !finished)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 4),
                    child: GameText(
                      petLine!.textRu,
                      style: const TextStyle(
                          color: FinniColors.primary,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                CoachTarget(
                  id: 'game.intro',
                  child: Material(
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
                      child: GameText(
                        variant.intro,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            height: 1.3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  List<String> _levelLabels() {
    if (!inLevel) return const [];
    final run = s.levelRun;
    final record = step?.finished;
    if (record != null) {
      return [
        'Уровень ${record.number}',
        '${record.stars.length} из ${record.stars.length}'
      ];
    }
    if (run == null) return const [];
    final position =
        reward == null ? (run.currentIndex ?? run.played) + 1 : run.done;
    return ['Уровень ${run.number}', '$position из ${run.slots.length}'];
  }

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
                  const GameText('🎉', style: TextStyle(fontSize: 36)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GameText(
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
              GameText(check.explanation, style: const TextStyle(fontSize: 17)),
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
                  const GameText('🤗', style: TextStyle(fontSize: 34)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GameText(
                      petLine?.textRu ?? 'Давай посмотрим вместе',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GameText(check.explanation, style: const TextStyle(fontSize: 17)),
              for (final line in check.details.skip(1).take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GameText('💭 '),
                      Expanded(child: GameText(line)),
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

  String _noCoins(GameReward earned) => switch (widget.mode) {
        GameMode.level =>
          'Эта игра подождёт. Вернись к ней после остальных — будет новое задание.',
        GameMode.daily =>
          'Задание дня можно пройти ещё раз сегодня. Попробуй!',
        GameMode.improve => earned.stars == 0
            ? 'Ничего страшного: звёзды остались прежними. Можно попробовать ещё раз.'
            : 'Звёзд не больше, чем было, поэтому монет нет. Попробуй ещё!',
        GameMode.practice =>
          'Это тренировка: монет нет, зато звёзды и опыт остаются.',
      };

  Widget _rewardLine(GameReward earned) => FinniCard(
        color: FinniColors.paper,
        padding: 12,
        child: Row(
          children: [
            if (earned.coins > 0) ...[
              CoinAmount(earned.coins, prefix: '+', size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: GameText(switch (step?.finished) {
                  final LevelRecord done =>
                    'Уровень пройден! За весь уровень — ${done.coins} ${ruCoins(done.coins)}.',
                  _ when inLevel =>
                    'Звезда = монета: ${earned.stars} из 3. Идём дальше!',
                  _ when widget.mode == GameMode.improve =>
                    'Новые звёзды — новые монеты!',
                  _ => 'Монеты уже в кошельке.',
                }),
              ),
            ] else
              Expanded(child: GameText(_noCoins(earned))),
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
        icon: Icon(inLevel && step?.finished == null
            ? Icons.arrow_forward_rounded
            : Icons.celebration_outlined),
        label: GameText(!inLevel
            ? texts.next
            : step?.finished != null
                ? 'Открыть конверт'
                : 'Дальше по уровню'),
      );
    } else if (wrongShown) {
      content = Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _giveUp,
              child: GameText(inLevel ? 'Отложить игру' : 'Дальше без ответа'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                s.fx('retry');
                setState(() => showFeedback = false);
              },
              icon: const Icon(Icons.replay_rounded),
              label: GameText(texts.tryAgain),
            ),
          ),
        ],
      );
    } else if (task.type == TaskType.board ||
        task.type == TaskType.stall ||
        task.type == TaskType.cashier ||
        task.type == TaskType.pricetag) {
      content = const GameText(
        'Играй до конца — я расскажу, что получилось',
        textAlign: TextAlign.center,
        style: TextStyle(color: FinniColors.muted),
      );
    } else if (task.type == TaskType.choice) {
      content = const GameText(
        'Выбери вариант — я сразу расскажу, что будет',
        textAlign: TextAlign.center,
        style: TextStyle(color: FinniColors.muted),
      );
    } else {
      final current = answer;
      content = FilledButton.icon(
        onPressed: current == null ? null : () => _submit(current),
        icon: const Icon(Icons.check_circle_outline_rounded),
        label: GameText(texts.check),
      );
    }
    return CoachTarget(
      id: 'game.check',
      child: Container(
        decoration: const BoxDecoration(
          color: FinniColors.paper,
          border: Border(top: BorderSide(color: FinniColors.line)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SizedBox(width: double.infinity, child: content),
      ),
    );
  }
}
