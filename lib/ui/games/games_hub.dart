import '../widgets/game_text.dart';
import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../../domain/ru_words.dart';
import '../game_controller.dart';
import '../theme/finni_theme.dart';
import '../widgets/coach.dart';
import '../widgets/emoji_art.dart';
import '../widgets/finni_ui.dart';
import 'game_screen.dart';
import 'level_screen.dart';
import 'quests.dart';

Future<void> openGame(BuildContext context, GameController state, String taskId) =>
    Navigator.of(context).push<GameReward>(MaterialPageRoute(
      settings: RouteSettings(name: 'game:$taskId'),
      builder: (_) => GameScreen(state: state, taskId: taskId),
    ));

class GamesHub extends StatelessWidget {
  const GamesHub({
    super.key,
    required this.state,
    required this.onLevel,
    required this.onDaily,
  });

  final GameController state;
  final VoidCallback onLevel;
  final VoidCallback onDaily;

  @override
  Widget build(BuildContext context) {
    final catalog = state.content.tasks;
    final next = state.nextUnlock;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GameText('Учимся на маленьких решениях',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        GameText(
          'Пройдено уровней: ${state.levelsDone}',
          style: const TextStyle(color: FinniColors.muted),
        ),
        const SizedBox(height: 16),
        CoachTarget(id: 'hub.level', child: LevelButton(state: state, onPlay: onLevel)),
        const SizedBox(height: 12),
        CoachTarget(id: 'hub.daily', child: DailyCard(state: state, onPlay: onDaily)),
        const SizedBox(height: 20),
        CoachTarget(
          id: 'hub.practice',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.fitness_center_rounded, color: FinniColors.primary),
                  const SizedBox(width: 8),
                  GameText('Тренировка', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 6),
              const GameText(
                'Здесь монеты не начисляются — это разминка для ума. Звёзды копятся! Игра попадает сюда, когда ты сыграешь её в уровне.',
                style: TextStyle(color: FinniColors.muted),
              ),
            ],
          ),
        ),
        if (next != null) ...[
          const SizedBox(height: 12),
          _NextUnlock(
            task: next,
            left: state.unlockLevelOf(next.id) - state.reachedLevel,
            motion: state.motion,
          ),
        ],
        for (final theme in catalog.themes) ...[
          const SizedBox(height: 16),
          _ThemeHeader(
            theme: theme,
            done: catalog
                .byTheme(theme.id)
                .fold(0, (sum, t) => sum + state.passedOf(t)),
            total: catalog
                .byTheme(theme.id)
                .fold(0, (sum, t) => sum + t.variantCount),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, constraints) {
            final columns = MediaQuery.textScalerOf(context).scale(16) > 24 ? 1 : 2;
            final width = ((constraints.maxWidth - (columns - 1) * 10) / columns).clamp(0.0, double.infinity);
            return EqualGrid(
              columns: columns,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (i, task) in catalog.byTheme(theme.id).indexed)
                  SizedBox(
                    width: width,
                    child: PopIn(
                      motion: state.motion,
                      delay: i * 60,
                      child: state.isGameUnlocked(task.id)
                          ? _GameTile(
                              task: task,
                              stars: state.starsOf(task.id),
                              passed: state.passedOf(task),
                              onTap: () => openGame(context, state, task.id),
                            )
                          : _LockedTile(
                              task: task,
                              level: state.unlockLevelOf(task.id),
                              left: state.unlockLevelOf(task.id) - state.reachedLevel,
                            ),
                    ),
                  ),
              ],
            );
          }),
        ],
        const SizedBox(height: 16),
        const SoftNotice(
          icon: Icons.favorite_border_rounded,
          text: 'Ошибаться можно: монеты за ошибку не отнимаются, а попробовать снова можно сразу.',
          color: FinniColors.lavender,
        ),
      ],
    );
  }
}

String _levelsLeft(int left) => left <= 0
    ? 'Ждёт тебя в уровне дня'
    : left == 1
        ? 'Откроется на следующем уровне'
        : 'Откроется через $left ${ruPlural(left, 'уровень', 'уровня', 'уровней')}';

class _NextUnlock extends StatelessWidget {
  const _NextUnlock({required this.task, required this.left, required this.motion});

  final TaskDef task;
  final int left;
  final bool motion;

  @override
  Widget build(BuildContext context) => FinniCard(
        color: FinniColors.lavender,
        child: Row(
          children: [
            _Wobble(
              motion: motion,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: .3,
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                          FinniColors.purple, BlendMode.srcIn),
                      child: EmojiBadge(task.iconId,
                          size: 56, color: FinniColors.transparent),
                    ),
                  ),
                  const GameText('?',
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: FinniColors.purple)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GameText('Скоро новая игра!',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  GameText(_levelsLeft(left)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _LockedTile extends StatelessWidget {
  const _LockedTile({required this.task, required this.level, required this.left});

  final TaskDef task;
  final int level;
  final int left;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Игра закрыта. Откроется на уровне $level',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FinniColors.background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: FinniColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: .25,
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                              FinniColors.muted, BlendMode.srcIn),
                          child: EmojiBadge(task.iconId,
                              size: 54, color: FinniColors.transparent),
                        ),
                      ),
                      const Icon(Icons.lock_rounded, color: FinniColors.muted),
                    ],
                  ),
                  const Spacer(),
                  TagPill(
                    icon: Icons.flag_outlined,
                    label: '$level',
                    color: FinniColors.paper,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _Reserve(
                style: _titleStyle,
                child: GameText('???',
                    style: _titleStyle.copyWith(color: FinniColors.muted)),
              ),
              const SizedBox(height: 6),
              _Reserve(
                style: _noteStyle,
                child: GameText(_levelsLeft(left),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _noteStyle.copyWith(color: FinniColors.muted)),
              ),
            ],
          ),
        ),
      );
}

class _Wobble extends StatefulWidget {
  const _Wobble({required this.child, required this.motion});

  final Widget child;
  final bool motion;

  @override
  State<_Wobble> createState() => _WobbleState();
}

class _WobbleState extends State<_Wobble> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionAllowed(context, widget.motion)) {
      if (!controller.isAnimating) controller.repeat(reverse: true);
    } else {
      controller.stop();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, child) => Transform.rotate(
          angle: (Curves.easeInOut.transform(controller.value) - .5) * .12,
          child: child,
        ),
        child: widget.child,
      );
}

class _ThemeHeader extends StatelessWidget {
  const _ThemeHeader({required this.theme, required this.done, required this.total});

  final TaskTheme theme;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          EmojiBadge(theme.iconId, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: GameText(theme.title,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          ),
          TagPill(
            icon: Icons.flag_outlined,
            label: '$done из $total',
            color: done == total ? FinniColors.mint : FinniColors.paper,
          ),
        ],
      );
}

const TextStyle _titleStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w800);
const TextStyle _noteStyle = TextStyle(fontSize: 16);

class _Reserve extends StatelessWidget {
  const _Reserve({required this.style, required this.child});

  final TextStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: Stack(
          children: [
            ExcludeSemantics(
              child: Opacity(
                  opacity: 0, child: GameText('A\nA', maxLines: 2, style: style)),
            ),
            Positioned.fill(child: child),
          ],
        ),
      );
}

class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.task,
    required this.stars,
    required this.passed,
    required this.onTap,
  });

  final TaskDef task;
  final int stars;
  final int passed;
  final VoidCallback onTap;

  int get total => task.variantCount;
  bool get all => passed >= total;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '${task.title}. Пройдено $passed из $total. Звёзд: $stars из 3',
        excludeSemantics: true,
        child: Squish(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FinniColors.paper,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: FinniColors.line),
              boxShadow: const [
                BoxShadow(color: FinniColors.shadow, blurRadius: 8, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EmojiBadge(task.iconId, size: 54),
                    const Spacer(),
                    if (all)
                      const Icon(Icons.check_circle_rounded, color: FinniColors.primary)
                    else
                      StarRow(stars: stars, size: 16),
                  ],
                ),
                const SizedBox(height: 8),
                _Reserve(
                  style: _titleStyle,
                  child: GameText(task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle),
                ),
                const SizedBox(height: 6),
                _Reserve(
                  style: _noteStyle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GameText(all ? 'Всё пройдено!' : 'Пройдено $passed из $total',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _noteStyle.copyWith(
                              fontWeight: FontWeight.w800,
                              color: all ? FinniColors.primary : FinniColors.ink)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : passed / total,
                          minHeight: 8,
                          backgroundColor: FinniColors.line,
                          color: FinniColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
