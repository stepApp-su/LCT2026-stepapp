import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../game_controller.dart';
import '../theme/finni_theme.dart';
import '../widgets/emoji_art.dart';
import '../widgets/finni_ui.dart';
import 'game_screen.dart';

Future<void> openGame(BuildContext context, GameController state, String taskId) =>
    Navigator.of(context).push<GameReward>(MaterialPageRoute(
      settings: RouteSettings(name: 'game:$taskId'),
      builder: (_) => GameScreen(state: state, taskId: taskId),
    ));

class GamesHub extends StatelessWidget {
  const GamesHub({super.key, required this.state});

  final GameController state;

  @override
  Widget build(BuildContext context) {
    final catalog = state.content.tasks;
    final daily = state.dailyGame;
    final dailyReward = state.rewardFor(daily);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Учимся на маленьких решениях',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          state.simpleMode ? 'Уровень: попроще' : 'Уровень: посложнее',
          style: const TextStyle(color: FinniColors.muted),
        ),
        const SizedBox(height: 16),
        _DailyCard(
          task: daily,
          reward: dailyReward,
          motion: state.motion,
          onPlay: () => openGame(context, state, daily.id),
        ),
        const SizedBox(height: 12),
        if (!state.canEarnFromGames)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SoftNotice(
              icon: Icons.bedtime_outlined,
              text:
                  'Монеты за игры сегодня уже получены. Играть можно сколько хочешь — объяснения и звёзды остаются!',
            ),
          ),
        for (final theme in catalog.themes) ...[
          const SizedBox(height: 8),
          _ThemeHeader(
            theme: theme,
            done: catalog
                .byTheme(theme.id)
                .where((t) => state.tasks.isCompleted(t.id))
                .length,
            total: catalog.byTheme(theme.id).length,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, constraints) {
            final columns = MediaQuery.textScalerOf(context).scale(16) > 24 ? 1 : 2;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (i, task) in catalog.byTheme(theme.id).indexed)
                  SizedBox(
                    width: width,
                    child: PopIn(
                      motion: state.motion,
                      delay: i * 60,
                      child: _GameTile(
                        task: task,
                        stars: state.starsOf(task.id),
                        reward: state.rewardFor(task),
                        done: state.tasks.isCompleted(task.id),
                        onTap: () => openGame(context, state, task.id),
                      ),
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        const SoftNotice(
          icon: Icons.favorite_border_rounded,
          text: 'Ошибаться можно: монеты за ошибку не отнимаются, а попробовать снова можно сразу.',
          color: FinniColors.lavender,
        ),
      ],
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.task,
    required this.reward,
    required this.motion,
    required this.onPlay,
  });

  final TaskDef task;
  final int reward;
  final bool motion;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Игра дня: ${task.title}',
        child: Squish(
          onTap: onPlay,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [FinniColors.sky, FinniColors.lavender],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                _Wobble(
                  motion: motion,
                  child: EmojiBadge(task.iconId, size: 76, color: FinniColors.paper),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TagPill(
                        icon: Icons.wb_sunny_outlined,
                        label: 'Игра дня',
                        color: FinniColors.honey,
                      ),
                      const SizedBox(height: 6),
                      Text(task.title,
                          style: const TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (reward > 0) CoinAmount(reward, prefix: '+', size: 20),
                          const Spacer(),
                          const Icon(Icons.play_circle_fill_rounded,
                              size: 44, color: FinniColors.primary),
                        ],
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
            child: Text(theme.title,
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

class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.task,
    required this.stars,
    required this.reward,
    required this.done,
    required this.onTap,
  });

  final TaskDef task;
  final int stars;
  final int reward;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '${task.title}. Звёзд: $stars из 3',
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
                    if (reward > 0)
                      CoinAmount(reward, prefix: '+', size: 16)
                    else if (done)
                      const Icon(Icons.check_circle_rounded, color: FinniColors.primary),
                  ],
                ),
                const SizedBox(height: 8),
                Text(task.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                StarRow(stars: stars, size: 20),
              ],
            ),
          ),
        ),
      );
}
