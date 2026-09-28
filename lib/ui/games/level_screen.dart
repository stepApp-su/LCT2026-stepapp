import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/ru_words.dart';
import '../../domain/services/level_service.dart';
import '../game_controller.dart';
import '../theme/finni_theme.dart';
import '../widgets/coach.dart';
import '../widgets/emoji_art.dart';
import '../widgets/finni_ui.dart';
import '../widgets/moni_scene.dart';
import 'game_screen.dart';

String ruGames(int n) => ruPlural(n, 'игра', 'игры', 'игр');

Future<bool> openLevel(BuildContext context, GameController state) async {
  state.startLevel();
  final toPlan = await Navigator.of(context).push<bool>(MaterialPageRoute(
    settings: const RouteSettings(name: 'level'),
    builder: (_) => LevelScreen(state: state),
  ));
  return toPlan == true;
}

class LevelButton extends StatelessWidget {
  const LevelButton({
    super.key,
    required this.state,
    required this.onPlay,
    this.onPractice,
    this.compact = false,
  });

  final GameController state;
  final VoidCallback onPlay;
  final VoidCallback? onPractice;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final done = state.todayLevel;
    if (done != null) return _done(done);
    final run = state.upcomingLevel;
    final started = state.levelRun?.isStarted ?? false;
    final games = run.slots.length;
    final extras = [
      if (run.hardCount > 0) '${run.hardCount} посложнее',
      if (run.newCount > 0) 'новая игра!',
    ];
    final parts = started
        ? ['Пройдено ${run.done} из $games']
        : compact
            ? ['$games ${ruGames(games)}', '🪙 +${run.coins}']
            : ['$games ${ruGames(games)}', ...extras];
    final subtitle = parts.join(', ');
    final title = started
        ? 'Продолжить уровень ${run.number}'
        : 'Уровень дня: ${run.number}';
    return Semantics(
      button: true,
      label: '$title. $subtitle. Награда ${run.coins} ${ruCoins(run.coins)}',
      excludeSemantics: true,
      child: Squish(
        onTap: onPlay,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [FinniColors.honey, FinniColors.sky],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(compact ? 22 : 28),
            boxShadow: const [
              BoxShadow(
                  color: FinniColors.shadow,
                  blurRadius: 10,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              _LevelBadge(number: run.number, size: compact ? 40 : 70),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: compact ? 16 : 21,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    TagRow([
                      for (final part in parts)
                        TagChip(part,
                            tone: part.startsWith('🪙')
                                ? TagTone.green
                                : TagTone.white),
                    ]),
                    if (!compact) ...[
                      const SizedBox(height: 6),
                      if (started)
                        _Dots(total: games, done: run.done)
                      else
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            const Text('Зарплата',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            CoinAmount(run.coins, prefix: '+', size: 18),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
              _Pulse(
                motion: state.motion,
                child: Icon(Icons.play_circle_fill_rounded,
                    size: compact ? 34 : 52, color: FinniColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _done(LevelRecord done) => Semantics(
        button: onPractice != null,
        label: 'Уровень ${done.number} пройден. Новый уровень завтра',
        excludeSemantics: true,
        child: Squish(
          onTap: onPractice,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FinniColors.mint,
              borderRadius: BorderRadius.circular(compact ? 22 : 28),
              border:
                  Border.all(color: FinniColors.primary.withValues(alpha: .25)),
            ),
            child: Row(
              children: [
                Container(
                  width: compact ? 40 : 70,
                  height: compact ? 40 : 70,
                  decoration: const BoxDecoration(
                      color: FinniColors.paper, shape: BoxShape.circle),
                  child: Icon(Icons.check_rounded,
                      size: compact ? 26 : 42, color: FinniColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Уровень ${done.number} пройден!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: compact ? 16 : 20,
                              fontWeight: FontWeight.w900)),
                      Text(
                          compact
                              ? 'Новый — завтра. Можно тренироваться'
                              : 'Новый уровень — завтра. А пока можно потренироваться.',
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, color: FinniColors.muted)),
                      if (!compact) ...[
                        const SizedBox(height: 6),
                        _StarCount(record: done),
                      ],
                    ],
                  ),
                ),
                if (compact)
                  _StarCount(record: done)
                else if (onPractice != null)
                  const Icon(Icons.fitness_center_rounded,
                      color: FinniColors.primary),
              ],
            ),
          ),
        ),
      );
}

class LevelScreen extends StatefulWidget {
  const LevelScreen({super.key, required this.state});

  final GameController state;

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> {
  GameController get s => widget.state;
  LevelRecord? result;

  @override
  void initState() {
    super.initState();
    if (s.levelRun == null) result = s.todayLevel;
    WidgetsBinding.instance.addPostFrameCallback((_) => _coach());
  }

  Future<void> _coach() async {
    if (!mounted || s.coachSeen('level') || s.levelRun == null) return;
    final tour = s.coach.tour('level');
    if (tour == null) return;
    await Coach.run(context,
        steps: tour.steps,
        texts: s.coach.texts,
        values: {'name': s.petName},
        motion: s.motion);
    s.markCoachSeen([tour.id, ...tour.covers]);
  }

  Future<void> _play() async {
    final slot = s.levelRun?.current;
    if (slot == null) return;
    await Navigator.of(context).push<GameReward>(MaterialPageRoute(
      settings: RouteSettings(name: 'level:${slot.taskId}'),
      builder: (_) =>
          GameScreen(state: s, taskId: slot.taskId, mode: GameMode.level),
    ));
    if (!mounted) return;
    setState(() {
      if (s.levelRun == null) result = s.todayLevel;
    });
    if (result != null) {
      Celebration.show(context,
          motion: s.motion, emoji: '💰', text: 'Всего +${result!.coins}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = result;
    final run = s.levelRun;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Назад',
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
            s.levels.titleOf(done?.number ?? run?.number ?? s.levelNumber)),
        actions: [
          IconButton(
            tooltip: 'Подсказка',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                icon: const Icon(Icons.help_outline_rounded, size: 36),
                title: const Text('Уровень дня'),
                content: const Text(
                    'Проходи игры по тропинке одну за другой. За каждую пройденную игру сразу дают часть зарплаты — даже если получилось не с первого раза. Новый уровень откроется завтра, после сна.',
                    style: TextStyle(fontSize: 17)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Понятно')),
                ],
              ),
            ),
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: done != null
                ? _Result(state: s, record: done)
                : run == null
                    ? const SizedBox.shrink()
                    : _Path(state: s, run: run, onPlay: _play),
          ),
        ),
      ),
    );
  }
}

class _Path extends StatelessWidget {
  const _Path({required this.state, required this.run, required this.onPlay});

  final GameController state;
  final LevelRun run;
  final VoidCallback onPlay;

  static const double _row = 132;
  static const List<double> _sway = [0, .55, 0, -.55];

  @override
  Widget build(BuildContext context) {
    final current = run.current;
    final currentTask =
        current == null ? null : state.content.tasks.byId(current.taskId);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              CoachTarget(
                  id: 'level.header', child: _Header(state: state, run: run)),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                final width = constraints.maxWidth;
                final centers = [
                  for (var i = 0; i < run.slots.length; i++)
                    Offset(
                        width / 2 + _sway[i % _sway.length] * (width / 2 - 70),
                        _row * i + 50),
                ];
                return SizedBox(
                  height: _row * run.slots.length,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter:
                              _TrailPainter(centers: centers, done: run.done),
                        ),
                      ),
                      for (final (i, slot) in run.slots.indexed)
                        Positioned(
                          left: centers[i].dx - 70,
                          top: centers[i].dy - 44,
                          width: 140,
                          child: PopIn(
                            motion: state.motion,
                            delay: i * 90,
                            child: _Node(
                              state: state,
                              slot: slot,
                              index: i,
                              stars: i < run.stars.length ? run.stars[i] : null,
                              isCurrent: i == run.done,
                              onTap: i == run.done ? onPlay : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const SoftNotice(
                icon: Icons.favorite_border_rounded,
                text:
                    'Пробовать можно сколько угодно: зарплата за уровень не уменьшается. Звёзды — за то, как ты думал.',
                color: FinniColors.lavender,
              ),
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: FinniColors.paper,
            border: Border(top: BorderSide(color: FinniColors.line)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: CoachTarget(
            id: 'level.start',
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: currentTask == null ? null : onPlay,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(currentTask == null
                    ? 'Готово'
                    : run.isStarted
                        ? 'Дальше: ${currentTask.title}'
                        : 'Начать: ${currentTask.title}'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.run});

  final GameController state;
  final LevelRun run;

  @override
  Widget build(BuildContext context) {
    final games = run.slots.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [FinniColors.sky, FinniColors.lavender],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 84,
            height: 92,
            child: MoniScene(
                appearance: state.appearance,
                motion: state.motion,
                stage: state.stage,
                outfit: state.outfit),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  run.isStarted
                      ? 'Ещё ${games - run.done} ${ruGames(games - run.done)} — и уровень пройден!'
                      : 'Сегодня $games ${ruGames(games)}. За каждую — часть зарплаты!',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, height: 1.25),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('✉️ ', style: TextStyle(fontSize: 20)),
                    CoinAmount(run.coins, prefix: '+', size: 20),
                    const Spacer(),
                    _Dots(total: games, done: run.done),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({
    required this.state,
    required this.slot,
    required this.index,
    required this.stars,
    required this.isCurrent,
    required this.onTap,
  });

  final GameController state;
  final LevelSlot slot;
  final int index;
  final int? stars;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final task = state.content.tasks.byId(slot.taskId)!;
    final done = stars != null;
    final waiting = !done && !isCurrent;
    Widget circle = Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? FinniColors.mint
            : isCurrent
                ? FinniColors.honey
                : FinniColors.paper,
        border: Border.all(
          color: isCurrent ? FinniColors.gold : FinniColors.line,
          width: isCurrent ? 3 : 2,
        ),
        boxShadow: const [
          BoxShadow(
              color: FinniColors.shadow, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      alignment: Alignment.center,
      child: Opacity(
        opacity: waiting ? .45 : 1,
        child:
            EmojiBadge(task.iconId, size: 50, color: FinniColors.transparent),
      ),
    );
    if (isCurrent) circle = _Pulse(motion: state.motion, child: circle);
    return Semantics(
      button: onTap != null,
      label:
          'Игра ${index + 1}: ${task.title}${done ? '. Звёзд: $stars' : isCurrent ? '. Сейчас' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                circle,
                if (done)
                  const Positioned(
                    right: -2,
                    bottom: -2,
                    child: CircleAvatar(
                      radius: 13,
                      backgroundColor: FinniColors.primary,
                      child: Icon(Icons.check_rounded,
                          size: 18, color: FinniColors.paper),
                    ),
                  ),
                if (slot.isNew && !done)
                  Positioned(
                    top: -8,
                    right: -18,
                    child: Transform.rotate(
                      angle: .2,
                      child: const TagPill(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Новая!',
                          color: FinniColors.honey),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: waiting ? FinniColors.muted : FinniColors.ink)),
            if (done)
              StarRow(stars: stars!, size: 16)
            else if (slot.isHard)
              const Text('🔥 посложнее',
                  style: TextStyle(
                      fontSize: 16,
                      color: FinniColors.purple,
                      fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.state, required this.record});

  final GameController state;
  final LevelRecord record;

  @override
  Widget build(BuildContext context) {
    final next = state.nextUnlock;
    final all = record.stars.length * 3;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        PopIn(
          motion: state.motion,
          child: const Text('🎉',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 64)),
        ),
        Text('Уровень ${record.number} пройден!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final stars in record.stars) StarRow(stars: stars, size: 22),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          record.totalStars == all
              ? 'Все звёзды! Ты думал очень внимательно.'
              : 'Звёзды показывают, как ты думал. Монеты — за каждую пройденную игру.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: FinniColors.muted),
        ),
        const SizedBox(height: 20),
        PopIn(
          motion: state.motion,
          delay: 200,
          child: FinniCard(
            color: FinniColors.honey,
            child: Column(
              children: [
                const Text('✉️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 4),
                const Text('Всего за уровень',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                CoinAmount(record.coins, prefix: '+', size: 32),
                const SizedBox(height: 8),
                const Text('Все монеты уже в кошельке. Куда их направим?',
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (next != null)
          FinniCard(
            color: FinniColors.lavender,
            child: Row(
              children: [
                _Silhouette(iconId: next.iconId),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _teaser(state.unlockLevelOf(next.id) - record.number),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.pie_chart_outline_rounded),
          label: const Text('Распределить монеты'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('На главную'),
        ),
      ],
    );
  }
}

String _teaser(int left) => left <= 1
    ? 'Завтра на новом уровне откроется новая игра!'
    : 'Ещё $left ${ruPlural(left, 'уровень', 'уровня', 'уровней')} — и откроется новая игра!';

class _StarCount extends StatelessWidget {
  const _StarCount({required this.record});

  final LevelRecord record;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: FinniColors.gold, size: 20),
          const SizedBox(width: 4),
          Text('${record.totalStars} из ${record.stars.length * 3}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      );
}

class _Silhouette extends StatelessWidget {
  const _Silhouette({required this.iconId});

  final String iconId;

  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: [
          ColorFiltered(
            colorFilter:
                const ColorFilter.mode(FinniColors.purple, BlendMode.srcIn),
            child: Opacity(
              opacity: .35,
              child:
                  EmojiBadge(iconId, size: 52, color: FinniColors.transparent),
            ),
          ),
          const Icon(Icons.lock_rounded, color: FinniColors.purple, size: 22),
        ],
      );
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.number, required this.size});

  final int number;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: FinniColors.paper,
          shape: BoxShape.circle,
          border: Border.all(color: FinniColors.gold, width: 3),
        ),
        alignment: Alignment.center,
        child: Text('$number',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
                fontSize: size * .42,
                fontWeight: FontWeight.w900,
                color: FinniColors.gold)),
      );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.total, required this.done});

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++)
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < done ? FinniColors.primary : FinniColors.paper,
                border: Border.all(color: FinniColors.primary, width: 1.5),
              ),
            ),
        ],
      );
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child, required this.motion});

  final Widget child;
  final bool motion;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
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
        builder: (context, child) => Transform.scale(
          scale: 1 + Curves.easeInOut.transform(controller.value) * .07,
          child: child,
        ),
        child: widget.child,
      );
}

class _TrailPainter extends CustomPainter {
  const _TrailPainter({required this.centers, required this.done});

  final List<Offset> centers;
  final int done;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i + 1 < centers.length; i++) {
      final a = centers[i];
      final b = centers[i + 1];
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, (a.dy + b.dy) / 2, b.dx, (a.dy + b.dy) / 2, b.dx, b.dy);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = i < done
            ? FinniColors.primary.withValues(alpha: .55)
            : FinniColors.line;
      for (final metric in path.computeMetrics()) {
        var distance = 0.0;
        while (distance < metric.length) {
          final end = math.min(distance + 10, metric.length);
          canvas.drawPath(metric.extractPath(distance, end), paint);
          distance += 20;
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TrailPainter oldDelegate) =>
      oldDelegate.done != done || oldDelegate.centers.length != centers.length;
}
