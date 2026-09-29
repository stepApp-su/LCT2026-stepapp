import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/finni_theme.dart';
import 'day_end.dart';
import 'game_text.dart';

const TextStyle _head = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w900, color: FinniColors.nightInk);
const TextStyle _note = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w700, color: FinniColors.nightSoft);

class PlanJars extends StatefulWidget {
  const PlanJars({
    super.key,
    required this.rows,
    required this.followed,
    required this.motion,
  });

  final List<List> rows;
  final bool followed;
  final bool motion;

  @override
  State<PlanJars> createState() => _PlanJarsState();
}

class _PlanJarsState extends State<PlanJars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200));

  static const _looks = [
    ('🍲', 'Нужное', FinniColors.nightMint),
    ('🎁', 'Хочу', FinniColors.nightCare),
    ('🐷', 'Копилка', FinniColors.nightMood),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.motion) {
      _run.forward();
    } else {
      _run.value = 1;
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  int get _total => widget.rows
      .fold(0, (sum, row) => sum + ((row[1] as num?)?.toInt() ?? 0));

  @override
  Widget build(BuildContext context) {
    final fill = CurvedAnimation(
        parent: _run,
        curve: const Interval(.1, .55, curve: Curves.easeOutCubic));
    final stamp = CurvedAnimation(
        parent: _run, curve: const Interval(.6, .85, curve: Curves.elasticOut));
    return Semantics(
      container: true,
      label: widget.followed
          ? 'План дня выполнен точно по плану'
          : 'План дня выполнен почти по плану',
      child: NightGlass(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(child: GameText('📋 План дня', style: _head)),
            GameText('утром, $_total', style: _note),
          ]),
          const SizedBox(height: 12),
          Stack(clipBehavior: Clip.none, children: [
            Row(children: [
              for (final (i, row) in widget.rows.take(3).indexed)
                Expanded(child: _jar(i, row, fill)),
            ]),
            Positioned(
              left: 0,
              right: 0,
              top: 18,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: stamp,
                    builder: (context, child) {
                      final t = stamp.value;
                      return Opacity(
                        opacity: _run.value < .6 ? 0.0 : t.clamp(0.0, 1.0),
                        child: Transform.rotate(
                          angle: -.16,
                          child: Transform.scale(
                              scale: 2.2 - 1.2 * t, child: child),
                        ),
                      );
                    },
                    child: Center(child: _stamp()),
                  ),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _stamp() {
    final color =
        widget.followed ? FinniColors.nightMint : FinniColors.nightPeach;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: FinniColors.sheetNight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 3),
      ),
      child: GameText(
        widget.followed ? 'ТОЧНО ПО ПЛАНУ!' : 'ПОЧТИ ПОЛУЧИЛОСЬ',
        textScaler: TextScaler.noScaling,
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: .6,
            color: color),
      ),
    );
  }

  Widget _jar(int index, List row, Animation<double> fill) {
    final look = _looks[index];
    final plan = (row[1] as num?)?.toInt() ?? 0;
    final fact = (row[2] as num?)?.toInt() ?? 0;
    final share = plan <= 0
        ? (fact > 0 ? 1.0 : 0.0)
        : math.min(1.0, fact / plan * .78);
    return Column(children: [
      Container(
        width: 62,
        height: 86,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: FinniColors.glass,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(14), bottom: Radius.circular(18)),
          border: Border.all(color: FinniColors.glassStrong, width: 2),
        ),
        child: Stack(children: [
          AnimatedBuilder(
            animation: fill,
            builder: (context, _) => Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: 1,
                heightFactor: share * fill.value,
                child: ColoredBox(color: look.$3),
              ),
            ),
          ),
          if (plan > 0)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 86 * .78 - 4,
              child: SizedBox(
                  height: 2, child: ColoredBox(color: FinniColors.nightSoft)),
            ),
          Center(
            child: GameText(look.$1,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(fontSize: 22)),
          ),
        ]),
      ),
      const SizedBox(height: 6),
      GameText(plan <= 0 ? '$fact' : '$fact из $plan',
          maxLines: 1,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: FinniColors.nightInk)),
      GameText(look.$2,
          maxLines: 1,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: FinniColors.nightDim)),
    ]);
  }
}

class PocketFlow extends StatefulWidget {
  const PocketFlow({
    super.key,
    required this.earned,
    required this.saved,
    required this.needs,
    required this.carry,
    required this.petName,
    required this.motion,
  });

  final int earned, saved, needs, carry;
  final String petName;
  final bool motion;

  @override
  State<PocketFlow> createState() => _PocketFlowState();
}

class _PocketFlowState extends State<PocketFlow>
    with SingleTickerProviderStateMixin {
  late final List<int> _values = [widget.saved, widget.needs, widget.carry];
  late final List<int> _coins = _spread();
  late final int _flying = _coins.fold(0, (a, b) => a + b);
  late final AnimationController _run = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 900 + _flying * 120 + 700));

  static const _start = .08;
  static const _flight = 520.0;
  static const _laneTop = 62.0;

  List<int> _spread() {
    final total = _values.fold(0, (a, b) => a + b);
    if (total <= 0) return const [0, 0, 0];
    final visual = math.min(total, 12);
    final shares = [
      for (final v in _values)
        v <= 0 ? 0 : math.max(1, (v * visual / total).round())
    ];
    return shares;
  }

  double get _ms => _run.duration!.inMilliseconds.toDouble();

  double _progressOf(int order) {
    final begin = _start * _ms + order * 120;
    return ((_run.value * _ms - begin) / _flight).clamp(0.0, 1.0);
  }

  int _landed(int lane) {
    var order = 0;
    var landed = 0;
    for (var i = 0; i < 3; i++) {
      for (var k = 0; k < _coins[i]; k++) {
        if (i == lane && _progressOf(order) >= 1) landed++;
        order++;
      }
    }
    return landed;
  }

  @override
  void initState() {
    super.initState();
    if (widget.motion) {
      _run.forward();
    } else {
      _run.value = 1;
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  (String, String) get _sticker {
    final name = widget.petName;
    if (widget.needs > 0) {
      return (
        '🍎',
        'Кармашек выручил, когда $name не хватило на нужное.${widget.carry > 0 ? ' Остальное — на завтра.' : ''}'
      );
    }
    if (widget.saved > 0 && widget.carry > 0) {
      return ('🐷', 'Часть новых монет уже в копилке, остальные ждут завтрашнего плана.');
    }
    if (widget.saved > 0) {
      return ('🏅', 'Все новые монеты — в копилку. Так делают настоящие копильщики!');
    }
    return ('📅', 'Ты не потратил новые монеты сразу, а оставил их на завтрашний план.');
  }

  @override
  Widget build(BuildContext context) {
    const lanes = [
      ('🐷', 'в копилку'),
      ('🍎', 'на нужное'),
      ('📅', 'на завтра'),
    ];
    final sticker = _sticker;
    return Semantics(
      container: true,
      label:
          'Новые монеты за день: ${widget.earned}. В копилку ${widget.saved}, на нужное ${widget.needs}, на завтра ${widget.carry}',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FinniColors.honey.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: FinniColors.honey.withValues(alpha: .35)),
        ),
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _run,
            builder: (context, _) {
              final landed = [for (var i = 0; i < 3; i++) _landed(i)];
              final shown = [
                for (var i = 0; i < 3; i++)
                  _coins[i] == 0
                      ? 0
                      : (_values[i] * landed[i] / _coins[i]).round()
              ];
              final left =
                  math.max(0, widget.earned - shown.fold(0, (a, b) => a + b));
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const GameText('👛 Куда ушли новые монеты', style: _head),
                    const SizedBox(height: 10),
                    LayoutBuilder(builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      return SizedBox(
                        height: _laneTop + 100,
                        child: Stack(clipBehavior: Clip.none, children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            height: 50,
                            child: Row(children: [
                              const GameText('👛',
                                  textScaler: TextScaler.noScaling,
                                  style: TextStyle(fontSize: 34)),
                              const SizedBox(width: 10),
                              GameText('$left',
                                  textScaler: TextScaler.noScaling,
                                  style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      color: FinniColors.honey)),
                              const SizedBox(width: 8),
                              const Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: GameText('заработано днём',
                                      maxLines: 1, style: _note),
                                ),
                              ),
                            ]),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: _laneTop,
                            height: 100,
                            child: Row(children: [
                              for (final (i, lane) in lanes.indexed) ...[
                                if (i > 0) const SizedBox(width: 6),
                                Expanded(
                                    child: _lane(lane.$1, lane.$2, shown[i],
                                        _values[i] > 0, landed[i])),
                              ],
                            ]),
                          ),
                          ..._flyingCoins(w),
                        ]),
                      );
                    }),
                    const SizedBox(height: 10),
                    AnimatedOpacity(
                      opacity: _run.value >= 1 ? 1 : 0,
                      duration: widget.motion
                          ? const Duration(milliseconds: 400)
                          : Duration.zero,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FinniColors.glass,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(children: [
                          GameText(sticker.$1,
                              textScaler: TextScaler.noScaling,
                              style: const TextStyle(fontSize: 30)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GameText(sticker.$2,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: FinniColors.nightInk)),
                          ),
                        ]),
                      ),
                    ),
                  ]);
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _flyingCoins(double width) {
    final coins = <Widget>[];
    var order = 0;
    for (var i = 0; i < 3; i++) {
      for (var k = 0; k < _coins[i]; k++) {
        final t = _progressOf(order);
        order++;
        if (t <= 0 || t >= 1) continue;
        final eased = Curves.easeInOutCubic.transform(t);
        const fromX = 8.0;
        const fromY = 12.0;
        final toX = width * (i + .5) / 3 - 11;
        const toY = _laneTop + 10;
        final x = fromX + (toX - fromX) * eased;
        final y = fromY + (toY - fromY) * eased - math.sin(t * math.pi) * 26;
        coins.add(Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: 1 - t * .5,
            child: const GameText('🪙',
                textScaler: TextScaler.noScaling,
                style: TextStyle(fontSize: 20)),
          ),
        ));
      }
    }
    return coins;
  }

  Widget _lane(String emoji, String label, int value, bool used, int landed) {
    final bump = landed > 0 && _run.value < 1;
    return Opacity(
      opacity: used ? 1 : .45,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: bump
              ? FinniColors.honey.withValues(alpha: .18)
              : FinniColors.glass,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          GameText(emoji,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(fontSize: 24)),
          GameText('$value',
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: FinniColors.nightInk)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: GameText(label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: FinniColors.nightDim)),
          ),
        ]),
      ),
    );
  }
}

class TitleGlass extends StatefulWidget {
  const TitleGlass({
    super.key,
    required this.icon,
    required this.title,
    required this.reason,
    required this.motion,
  });

  final String icon;
  final String title;
  final String reason;
  final bool motion;

  @override
  State<TitleGlass> createState() => _TitleGlassState();
}

class _TitleGlassState extends State<TitleGlass>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void initState() {
    super.initState();
    if (widget.motion) {
      _run.forward();
    } else {
      _run.value = 1;
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  double _span(double from, double to, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((_run.value - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: 'Новое звание: ${widget.title}. ${widget.reason}',
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _run,
            builder: (context, _) {
              final bump = _span(0, .35, Curves.easeOutBack);
              final wobble = math.sin(_span(.3, .6) * math.pi * 3) *
                  .18 *
                  (1 - _span(.3, .6));
              final shine = _span(.5, .95);
              return Opacity(
                opacity: _span(0, .15),
                child: Transform.scale(
                  scale: .6 + .4 * bump,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        FinniColors.honey.withValues(alpha: .28),
                        FinniColors.nightMood.withValues(alpha: .2),
                      ]),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: FinniColors.honey.withValues(alpha: .55)),
                    ),
                    child: Stack(children: [
                      Row(children: [
                        Transform.rotate(
                          angle: wobble,
                          child: Container(
                            width: 58,
                            height: 58,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                center: Alignment(-.3, -.4),
                                colors: [
                                  FinniColors.partyGoldLight,
                                  FinniColors.partyGold,
                                  FinniColors.partyGoldDeep,
                                ],
                              ),
                              border: Border.all(
                                  color: FinniColors.paper, width: 3),
                            ),
                            child: GameText(widget.icon,
                                textScaler: TextScaler.noScaling,
                                style: const TextStyle(fontSize: 30)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GameText('Новое звание: ${widget.title}',
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: FinniColors.nightInk)),
                                GameText(widget.reason, style: _note),
                              ]),
                        ),
                      ]),
                      if (shine > 0 && shine < 1)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: FractionalTranslation(
                              translation: Offset(-1.2 + shine * 2.4, 0),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    FinniColors.paper.withValues(alpha: 0),
                                    FinniColors.paper.withValues(alpha: .35),
                                    FinniColors.paper.withValues(alpha: 0),
                                  ], stops: const [.35, .5, .65]),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      );
}
