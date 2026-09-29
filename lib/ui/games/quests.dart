import '../widgets/game_text.dart';
import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../../domain/ru_words.dart';
import '../../domain/services/level_service.dart';
import '../game_controller.dart';
import '../theme/finni_theme.dart';
import '../widgets/coach.dart';
import '../widgets/emoji_art.dart';
import '../widgets/finni_ui.dart';
import 'game_screen.dart';
import 'level_screen.dart';

const List<String> _weekdays = [
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье',
];

const List<String> _weekdaysShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

const List<String> _months = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

String ruDate(DateTime at) =>
    '${_weekdays[at.weekday - 1]}, ${at.day} ${_months[at.month - 1]}';

Future<bool> openDaily(BuildContext context, GameController state) async {
  state.startDaily();
  final toPlan = await Navigator.of(context).push<bool>(MaterialPageRoute(
    settings: const RouteSettings(name: 'daily'),
    builder: (_) => DailyScreen(state: state),
  ));
  return toPlan == true;
}

Future<void> showQuestHelp(BuildContext context, String title, String text) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.help_outline_rounded, size: 36),
        title: GameText(title),
        content: GameText(text, style: const TextStyle(fontSize: 17)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const GameText('Понятно')),
        ],
      ),
    );

class HomeQuests extends StatelessWidget {
  const HomeQuests({
    super.key,
    required this.state,
    required this.onLevel,
    required this.onDaily,
    required this.onPractice,
    required this.onBedtime,
    required this.onPlan,
  });

  final GameController state;
  final VoidCallback onLevel;
  final VoidCallback onDaily;
  final VoidCallback onPractice;
  final VoidCallback onBedtime;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    if (state.needsPlan) {
      return CoachTarget(id: 'home.plan', child: _QuestTile(
        title: 'Составь план на день',
        horizontal: true,
        subtitle: 'Разложим ${state.plan.plan.income} ${ruCoins(state.plan.plan.income)}',
        semantics: 'Сначала план на день. Открыть план',
        icon: const Icon(Icons.edit_note_rounded, color: FinniColors.primary),
        trailing: Icons.arrow_forward_rounded,
        gradient: const [FinniColors.mint, FinniColors.honey],
        onTap: onPlan,
      ));
    }
    if (state.bedtimeReady) {
      return CoachTarget(id: 'home.bedtime', child: _QuestTile(
        title: 'Спокойной ночи',
        subtitle: 'Все дела сделаны! Пора спать',
        semantics: 'Все дела на сегодня сделаны. Уложить питомца спать',
        icon: const Icon(Icons.nightlight_round, color: FinniColors.purple),
        trailing: Icons.bedtime_rounded,
        gradient: const [FinniColors.lavender, FinniColors.sky],
        onTap: onBedtime,
      ));
    }
    final level = state.todayLevel;
    final run = state.upcomingLevel;
    final started = state.levelRun?.isStarted ?? false;
    final daily = state.dailyTask;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: CoachTarget(
            id: 'home.level',
            child: level != null
              ? _QuestTile(
                  title: 'Уровень ${level.number}',
                  subtitle: 'До завтра!',
                  semantics: 'Уровень ${level.number} пройден. Новый завтра',
                  icon: const Icon(Icons.check_rounded, color: FinniColors.primary),
                  trailing: Icons.fitness_center_rounded,
                  color: FinniColors.mint,
                  onTap: onPractice,
                )
              : _QuestTile(
                  title: 'Уровень ${run.number}',
                  subtitle: 'Пройдено ${run.done} из ${run.slots.length}',
                  tags: started
                      ? const []
                      : [
                          '🪙 +${run.coins}',
                          '${run.slots.length} ${ruGames(run.slots.length)}'
                        ],
                  semantics: 'Уровень дня ${run.number}. Играть',
                  icon: GameText('${run.number}',
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: FinniColors.gold)),
                  trailing: Icons.play_circle_fill_rounded,
                  gradient: const [FinniColors.honey, FinniColors.sky],
                  onTap: onLevel,
                ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CoachTarget(
            id: 'home.daily',
            child: daily == null
              ? const _QuestTile(
                  title: 'Задание дня',
                  subtitle: 'После уровня',
                  semantics: 'Задание дня откроется после первого уровня',
                  icon: Icon(Icons.lock_rounded, color: FinniColors.muted),
                  color: FinniColors.paper,
                )
              : state.dailyDoneToday
                  ? _QuestTile(
                      title: 'Задание дня',
                      subtitle: 'До завтра!',
                      semantics: 'Задание дня выполнено. Новое завтра',
                      icon: const Icon(Icons.check_rounded, color: FinniColors.primary),
                      trailing: Icons.check_circle_rounded,
                      color: FinniColors.mint,
                      onTap: onDaily,
                    )
                  : _QuestTile(
                      title: 'Задание дня',
                      subtitle: 'Сложное',
                      tags: ['🪙 +${state.dailyRules.coins}', '💪 сложное'],
                      semantics: 'Задание дня: ${daily.title}. Играть',
                      icon: const GameText('☀️',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(fontSize: 18)),
                      trailing: Icons.play_circle_fill_rounded,
                      gradient: const [FinniColors.lavender, FinniColors.honey],
                      onTap: onDaily,
                    ),
          ),
        ),
      ],
    );
  }
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({
    required this.title,
    required this.subtitle,
    required this.semantics,
    required this.icon,
    this.trailing,
    this.color,
    this.gradient,
    this.onTap,
    this.tags = const [],
    this.horizontal = false,
  });

  final String title;
  final String subtitle;
  final List<String> tags;
  final bool horizontal;
  final String semantics;
  final Widget icon;
  final IconData? trailing;
  final Color? color;
  final List<Color>? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = gradient;
    return Semantics(
      button: onTap != null,
      label: semantics,
      excludeSemantics: true,
      child: Squish(
        onTap: onTap,
        enabled: onTap != null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: colors == null ? color : null,
            gradient: colors == null
                ? null
                : LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(20),
            border: colors == null ? Border.all(color: FinniColors.line) : null,
          ),
          child: horizontal ? Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: FinniColors.paper, shape: BoxShape.circle),
                child: icon,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GameText(title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w900)),
                    GameText(subtitle,
                        style: const TextStyle(
                            fontSize: 16, color: FinniColors.ink)),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Icon(trailing, size: 24, color: FinniColors.primary),
              ],
            ],
          ) : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        color: FinniColors.paper, shape: BoxShape.circle),
                    child: icon,
                  ),
                  const Spacer(),
                  if (trailing != null)
                    Icon(trailing, size: 28, color: FinniColors.primary),
                ],
              ),
              const SizedBox(height: 6),
              GameText(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              if (tags.isEmpty)
                GameText(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, color: FinniColors.ink))
              else
                TagRow([
                  for (final tag in tags)
                    TagChip(tag,
                        tone: tag.startsWith('🪙')
                            ? TagTone.green
                            : TagTone.white),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

class DailyCard extends StatelessWidget {
  const DailyCard({super.key, required this.state, required this.onPlay});

  final GameController state;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final task = state.dailyTask;
    final done = state.dailyDoneToday;
    final rules = state.dailyRules;
    final String title;
    final String subtitle;
    var tags = const <String>[];
    if (task == null) {
      title = 'Задание дня';
      subtitle = 'Откроется, когда пройдёшь первый уровень.';
    } else if (done) {
      title = 'Задание дня выполнено!';
      subtitle = 'Новое появится завтра. Приходи!';
    } else {
      title = 'Задание дня: ${task.title}';
      subtitle =
          'Сложный вариант, +${rules.coins}, а с первой попытки ещё +${rules.perfectBonus}';
      tags = [
        '💪 сложный вариант',
        '🪙 +${rules.coins}',
        '🎯 с первой попытки +${rules.perfectBonus}',
      ];
    }
    return Semantics(
      button: task != null,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Squish(
        onTap: task == null ? null : onPlay,
        enabled: task != null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: task == null
                ? FinniColors.background
                : done
                    ? FinniColors.mint
                    : null,
            gradient: task != null && !done
                ? const LinearGradient(
                    colors: [FinniColors.lavender, FinniColors.honey],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: FinniColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: FinniColors.paper, shape: BoxShape.circle),
                child: task == null
                    ? const Icon(Icons.lock_rounded, color: FinniColors.muted)
                    : done
                        ? const Icon(Icons.check_rounded,
                            size: 32, color: FinniColors.primary)
                        : const GameText('☀️',
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GameText(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    if (tags.isEmpty)
                      GameText(subtitle, style: const TextStyle(color: FinniColors.ink))
                    else
                      TagRow([
                        for (final tag in tags)
                          TagChip(tag,
                              tone: tag.startsWith('🪙')
                                  ? TagTone.green
                                  : TagTone.white),
                      ]),
                  ],
                ),
              ),
              if (task != null && !done)
                const Icon(Icons.play_circle_fill_rounded,
                    size: 40, color: FinniColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key, required this.state});

  final GameController state;

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  GameController get s => widget.state;
  GameReward? reward;

  Future<void> _play() async {
    final task = s.dailyTask;
    if (task == null || !s.dailyAvailable) return;
    s.startDaily();
    final earned = await Navigator.of(context).push<GameReward>(MaterialPageRoute(
      settings: RouteSettings(name: 'daily:${task.id}'),
      builder: (_) => GameScreen(state: s, taskId: task.id, mode: GameMode.daily),
    ));
    if (!mounted) return;
    setState(() => reward = earned ?? reward);
    if (earned != null && earned.coins > 0) {
      Celebration.show(context, motion: s.motion, emoji: '☀️', text: '+${earned.coins} монет');
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = s.clock.now();
    final task = s.dailyTask;
    final done = s.dailyDoneToday || reward != null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Назад',
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const GameText('Задание дня'),
        actions: [
          IconButton(
            tooltip: 'Подсказка',
            onPressed: () => showQuestHelp(context, 'Задание дня',
                'Каждый день по календарю появляется одно задание — посложнее, чем в уровне. За решение дают монеты, а если с первой попытки — ещё немного сверху. Завтра будет новое!'),
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                GameText(ruDate(now),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                const GameText(
                  'Одно задание на весь день — сложнее, чем в уровне. Завтра будет новое!',
                  style: TextStyle(color: FinniColors.muted),
                ),
                const SizedBox(height: 14),
                _WeekStrip(now: now, done: s.dailyHistory),
                const SizedBox(height: 6),
                GameText('Всего выполнено: ${s.dailyHistory.length}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: FinniColors.muted)),
                const SizedBox(height: 16),
                if (task == null)
                  const SoftNotice(
                    icon: Icons.lock_outline_rounded,
                    text: 'Задание дня откроется, когда ты пройдёшь первый уровень. Так ты уже будешь знать правила игр.',
                  )
                else if (done)
                  _DoneCard(
                      state: s,
                      reward: reward,
                      onSave: s.pocket > 0
                          ? () => Navigator.pop(context, true)
                          : null)
                else
                  _Challenge(state: s, task: task, onPlay: _play),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Challenge extends StatelessWidget {
  const _Challenge({required this.state, required this.task, required this.onPlay});

  final GameController state;
  final TaskDef task;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final rules = state.dailyRules;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PopIn(
          motion: state.motion,
          child: FinniCard(
            color: FinniColors.lavender,
            child: Column(
              children: [
                EmojiBadge(task.iconId, size: 88, color: FinniColors.paper),
                const SizedBox(height: 10),
                GameText(task.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const TagPill(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Сложный вариант',
                  color: FinniColors.honey,
                ),
                const SizedBox(height: 12),
                const GameText(
                  'Эту игру ты уже знаешь. Сегодня в ней больше чисел и хитростей — подумай не спеша.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FinniCard(
          color: FinniColors.paper,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CoinAmount(rules.coins, prefix: '+', size: 22),
                  const SizedBox(width: 10),
                  const Expanded(child: GameText('за решение — даже если получится не сразу')),
                ],
              ),
              if (rules.perfectBonus > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    CoinAmount(rules.perfectBonus, prefix: '+', size: 22),
                    const SizedBox(width: 10),
                    const Expanded(child: GameText('ещё, если с первой попытки')),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onPlay,
          icon: const Icon(Icons.wb_sunny_rounded),
          label: const GameText('Принять вызов'),
        ),
      ],
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({required this.state, required this.reward, this.onSave});

  final GameController state;
  final GameReward? reward;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final coins = reward?.coins ?? state.dailyCoinsToday;
    return PopIn(
      motion: state.motion,
      child: FinniCard(
        color: FinniColors.mint,
        child: Column(
          children: [
            const GameText('🌞', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 6),
            GameText('Задание дня выполнено!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            if (reward != null) ...[
              const SizedBox(height: 8),
              StarRow(stars: reward!.stars, size: 28),
            ],
            if (coins > 0) ...[
              const SizedBox(height: 10),
              CoinAmount(coins, prefix: '+', size: 28),
            ],
            const SizedBox(height: 10),
            const GameText('Новое задание появится завтра. Приходи!',
                textAlign: TextAlign.center),
            if (onSave != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.savings_outlined),
                label: GameText('В копилку ${state.pocket}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.now, required this.done});

  final DateTime now;
  final Set<String> done;

  @override
  Widget build(BuildContext context) {
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(builder: (context) {
              final day = DateTime(monday.year, monday.month, monday.day + i);
              final isDone = done.contains(LevelService.dateKey(day));
              final isToday = day == today;
              return Semantics(
                label: '${_weekdays[i]}${isDone ? ', выполнено' : ''}',
                excludeSemantics: true,
                child: Column(
                  children: [
                    GameText(_weekdaysShort[i],
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                            color: isToday ? FinniColors.ink : FinniColors.muted)),
                    const SizedBox(height: 4),
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone ? FinniColors.mint : FinniColors.paper,
                        border: Border.all(
                          color: isToday ? FinniColors.gold : FinniColors.line,
                          width: isToday ? 3 : 1.5,
                        ),
                      ),
                      child: isDone
                          ? const Icon(Icons.check_rounded,
                              size: 20, color: FinniColors.primary)
                          : GameText('${day.day}',
                              textScaler: TextScaler.noScaling,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            }),
          ),
      ],
    );
  }
}
