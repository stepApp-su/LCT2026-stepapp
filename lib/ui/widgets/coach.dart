import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../domain/models/models.dart';
import '../theme/finni_theme.dart';
import 'finni_ui.dart';

abstract final class CoachIds {
  static const Set<String> all = {
    'home.goal',
    'home.coins',
    'home.pet',
    'home.stats',
    'home.event',
    'home.plan',
    'home.level',
    'home.daily',
    'home.bedtime',
    'nav',
    'nav.home',
    'nav.plan',
    'nav.shop',
    'nav.games',
    'nav.more',
    'plan.income',
    'plan.needs',
    'plan.mandatory',
    'plan.optional',
    'plan.savings',
    'plan.save',
    'plan.confirm',
    'shop.wallet',
    'shop.plan',
    'shop.needs',
    'shop.filters',
    'shop.wants',
    'shop.items',
    'hub.level',
    'hub.daily',
    'hub.practice',
    'savings.change',
    'savings.withdraw',
    'section.back',
    'more.list',
    'more.profile',
    'more.wardrobe',
    'more.titles',
    'more.diary',
    'more.summary',
    'more.glossary',
    'room.tabs',
    'room.stage',
    'room.legend',
    'diary.days',
    'diary.filters',
    'diary.summary',
    'diary.list',
    'titles.stages',
    'titles.xp',
    'titles.current',
    'titles.next',
    'glossary.search',
    'glossary.topics',
    'glossary.list',
    'glossary.learn',
    'flash.card',
    'flash.buttons',
    'night.plan',
    'night.todo',
    'night.sleep',
    'more.coach',
    'level.header',
    'level.start',
    'game.intro',
    'game.board',
    'game.check',
    'game.hint',
    'game.help',
    'sort.cards',
    'sort.bins',
    'coins.counter',
    'coins.wallet',
    'distribute.left',
    'distribute.controls',
    'order.list',
    'choice.options',
    'basket.budget',
    'basket.list',
    'basket.products',
    'week.goal',
    'week.first',
    'board.path',
    'board.goal',
    'board.roll',
    'stall.weather',
    'stall.planner',
    'stall.goal',
    'cashier.customer',
    'cashier.tray',
    'cashier.coins',
    'pricetag.need',
    'pricetag.offers',
  };
}

abstract final class Coach {
  static CoachHostState? of(BuildContext context) =>
      context.findAncestorStateOfType<CoachHostState>();

  static bool busy(BuildContext context) => of(context)?.active ?? false;

  static Future<bool> run(
    BuildContext context, {
    required List<TutorialStep> steps,
    CoachTexts texts = CoachTexts.fallback,
    Map<String, String> values = const {},
    Map<String, bool Function()> conditions = const {},
    bool motion = true,
    String? title,
  }) =>
      of(context)?.start(
        steps: steps,
        texts: texts,
        values: values,
        conditions: conditions,
        motion: motion,
        title: title,
      ) ??
      Future.value(true);
}

class CoachTarget extends StatefulWidget {
  const CoachTarget({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  State<CoachTarget> createState() => _CoachTargetState();
}

class _CoachTargetState extends State<CoachTarget> {
  @override
  void initState() {
    super.initState();
    _Targets.add(widget.id, this);
  }

  @override
  void didUpdateWidget(CoachTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _Targets.remove(oldWidget.id, this);
      _Targets.add(widget.id, this);
    }
  }

  @override
  void dispose() {
    _Targets.remove(widget.id, this);
    super.dispose();
  }

  bool get visible {
    if (!mounted) return false;
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  Rect? rectIn(RenderBox host) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero, ancestor: host) & box.size;
  }

  void reveal(bool motion) {
    if (!mounted) return;
    unawaited(Scrollable.ensureVisible(
      context,
      alignment: .4,
      duration: motion ? const Duration(milliseconds: 300) : Duration.zero,
    ));
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerUp: (_) => _Targets.tapped(widget.id),
        child: widget.child,
      );
}

abstract final class _Targets {
  static final Map<String, List<_CoachTargetState>> _byId = {};
  static void Function(String id)? onTap;

  static void add(String id, _CoachTargetState target) {
    (_byId[id] ??= []).add(target);
  }

  static void remove(String id, _CoachTargetState target) {
    _byId[id]?.remove(target);
  }

  static bool present(String id) => _byId[id]?.any((t) => t.mounted) ?? false;

  static _CoachTargetState? find(String id) {
    final list = _byId[id];
    if (list == null) return null;
    for (final target in list.reversed) {
      if (target.visible) return target;
    }
    return null;
  }

  static void tapped(String id) => onTap?.call(id);
}

final class _Run {
  _Run({
    required this.steps,
    required this.texts,
    required this.values,
    required this.conditions,
    required this.motion,
    this.title,
  });

  final String? title;
  final List<TutorialStep> steps;
  final CoachTexts texts;
  final Map<String, String> values;
  final Map<String, bool Function()> conditions;
  final bool motion;
  final Completer<bool> done = Completer<bool>();
}

class CoachHost extends StatefulWidget {
  const CoachHost({super.key, required this.child});

  final Widget child;

  @override
  State<CoachHost> createState() => CoachHostState();
}

class CoachHostState extends State<CoachHost> with SingleTickerProviderStateMixin {
  static const Duration _lostAfter = Duration(milliseconds: 800);

  final GlobalKey _stackKey = GlobalKey();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  _Run? _run;
  int _index = 0;
  int _token = 0;
  Rect? _hole;
  bool _scrolled = false;
  bool _lost = false;
  bool _listening = false;
  bool _measuring = false;
  Timer? _lostTimer;

  bool get active => _run != null;

  Future<bool> start({
    required List<TutorialStep> steps,
    CoachTexts texts = CoachTexts.fallback,
    Map<String, String> values = const {},
    Map<String, bool Function()> conditions = const {},
    bool motion = true,
    String? title,
  }) {
    final previous = _run;
    if (previous != null) _complete(previous, true);
    if (steps.isEmpty) return Future.value(true);
    final run = _Run(
      steps: List.unmodifiable(steps),
      texts: texts,
      values: values,
      conditions: conditions,
      motion: motion,
      title: title,
    );
    _run = run;
    _Targets.onTap = _tapped;
    if (!_listening) {
      _listening = true;
      SchedulerBinding.instance.addPersistentFrameCallback(_frame);
    }
    if (motion) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.value = .5;
    }
    _enter(0);
    return run.done.future;
  }

  void skip() {
    final run = _run;
    if (run != null) _complete(run, false);
  }

  bool _check(String? key) {
    if (key == null) return false;
    final condition = _run?.conditions[key];
    return condition != null && condition();
  }

  void _enter(int index) {
    final run = _run;
    if (run == null) return;
    var i = index;
    while (i < run.steps.length && _check(run.steps[i].skipIf)) {
      i++;
    }
    if (i >= run.steps.length) {
      _complete(run, true);
      return;
    }
    _watchLost(run, run.steps[i]);
    setState(() {
      _index = i;
      _hole = null;
      _scrolled = false;
      _lost = false;
      _token++;
    });
  }

  void _next() => _enter(_index + 1);

  void _watchLost(_Run run, TutorialStep step) {
    _lostTimer?.cancel();
    _lostTimer = Timer(_lostAfter, () {
      if (!mounted || !identical(_run, run) || _hole != null) return;
      final id = step.target;
      if (id != null && _Targets.present(id)) {
        _watchLost(run, step);
      } else {
        setState(() => _lost = true);
      }
    });
  }

  void _complete(_Run run, bool finished) {
    if (!run.done.isCompleted) run.done.complete(finished);
    if (!identical(_run, run)) return;
    _run = null;
    _hole = null;
    _Targets.onTap = null;
    _lostTimer?.cancel();
    _pulse.stop();
    if (mounted) setState(() {});
  }

  void _tapped(String id) {
    final run = _run;
    if (run == null) return;
    final step = run.steps[_index];
    if (step.action != CoachAction.tap || step.target != id) return;
    final token = _token;
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted && identical(_run, run) && token == _token) _next();
    });
  }

  void _frame(Duration _) {
    if (!mounted || _run == null || _measuring) return;
    _measuring = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _measuring = false;
      if (mounted) _measure();
    });
  }

  void _measure() {
    final run = _run;
    if (run == null) return;
    final step = run.steps[_index];
    if (step.action == CoachAction.wait && _check(step.until)) {
      _next();
      return;
    }
    Rect? rect;
    final host = _stackKey.currentContext?.findRenderObject();
    final id = step.target;
    if (host is RenderBox && host.hasSize && id != null) {
      final target = _Targets.find(id);
      if (target != null) {
        rect = target.rectIn(host);
        if (rect != null && !_scrolled) {
          _scrolled = true;
          target.reveal(run.motion);
        }
      }
    }
    final lost = rect == null && _lost;
    if (!_same(rect, _hole) || lost != _lost) {
      setState(() {
        _hole = rect;
        _lost = lost;
      });
    }
  }

  static bool _same(Rect? a, Rect? b) {
    if (a == null || b == null) return a == b;
    return (a.left - b.left).abs() < .5 &&
        (a.top - b.top).abs() < .5 &&
        (a.width - b.width).abs() < .5 &&
        (a.height - b.height).abs() < .5;
  }

  String _fill(String text, Map<String, String> values) => text.replaceAllMapped(
        RegExp(r'\{(\w+)\}'),
        (match) => values[match[1]] ?? match[0]!,
      );

  @override
  void dispose() {
    final run = _run;
    if (run != null && !run.done.isCompleted) run.done.complete(false);
    _Targets.onTap = null;
    _lostTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        key: _stackKey,
        children: [
          widget.child,
          if (_run != null) Positioned.fill(child: _layer(context, _run!)),
        ],
      );

  Widget _layer(BuildContext context, _Run run) {
    final step = run.steps[_index];
    final hole = _hole;
    if (hole == null && !_lost) return const SizedBox.shrink();
    final dim = hole != null && step.action != CoachAction.wait;
    final canTap = step.action == CoachAction.tap && hole != null;
    final advanceOnTap = step.action == CoachAction.next;
    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(builder: (context, constraints) {
        final size = constraints.biggest;
        return AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => Stack(
            children: [
              if (dim)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: advanceOnTap ? _next : null,
                    child: _Barrier(
                      hole: hole.inflate(8),
                      open: canTap,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _Shade(hole: hole, pulse: _pulse.value, dim: true),
                      ),
                    ),
                  ),
                )
              else if (hole != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _Shade(hole: hole, pulse: _pulse.value, dim: false),
                    ),
                  ),
                ),
              if (canTap) _hand(hole, size, run.motion),
              _placed(context, run, step, hole, size, canTap),
            ],
          ),
        );
      }),
    );
  }

  Widget _hand(Rect hole, Size size, bool motion) {
    final below = hole.bottom + 64 < size.height;
    final bob = motion ? math.sin(_pulse.value * math.pi) * 8 : 0.0;
    final double left = (hole.center.dx - 22).clamp(4.0, math.max(4.0, size.width - 52)).toDouble();
    return Positioned(
      left: left,
      top: below ? hole.bottom + 6 + bob : hole.top - 54 - bob,
      child: IgnorePointer(
        child: Text(
          below ? '👆' : '👇',
          textScaler: TextScaler.noScaling,
          style: const TextStyle(fontSize: 40),
        ),
      ),
    );
  }

  Widget _placed(BuildContext context, _Run run, TutorialStep step, Rect? hole,
      Size size, bool canTap) {
    final padding = MediaQuery.paddingOf(context);
    final double width = math.max(0.0, math.min(size.width - 32, 400.0));
    final left = (size.width - width) / 2;
    final bubble = _bubble(context, run, step);
    if (hole == null) {
      return Positioned(
        left: left,
        width: width,
        top: padding.top + 12,
        bottom: padding.bottom + 12,
        child: Center(child: bubble),
      );
    }
    const gap = 18.0;
    const room = 210.0;
    final extra = canTap ? 58.0 : 0.0;
    final top = padding.top + 12;
    final bottom = size.height - padding.bottom - 12;
    final above = hole.top - top;
    final below = bottom - hole.bottom;
    if (below >= above) {
      final y = hole.bottom + gap + extra;
      return y + room <= bottom
          ? Positioned(left: left, width: width, top: y, child: bubble)
          : Positioned(
              left: left, width: width, bottom: size.height - bottom, child: bubble);
    }
    final y = hole.top - gap - extra;
    return y - room >= top
        ? Positioned(left: left, width: width, bottom: size.height - y, child: bubble)
        : Positioned(left: left, width: width, top: top, child: bubble);
  }

  Widget _bubble(BuildContext context, _Run run, TutorialStep step) {
    final texts = run.texts;
    final shown = [
      for (final (i, s) in run.steps.indexed)
        if (i == _index || !_check(s.skipIf)) i,
    ];
    final position = shown.indexOf(_index) + 1;
    final last = position == shown.length;
    final needsButton = step.action == CoachAction.next || (_lost && step.action == CoachAction.tap);
    return PopIn(
      key: ValueKey('coach-$_token'),
      motion: run.motion,
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
          decoration: BoxDecoration(
            color: FinniColors.paper,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: FinniColors.honey, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 6)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (run.title case final title?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TagRow([
                    for (final (i, part) in _fill(title, run.values)
                        .split('·')
                        .map((p) => p.trim())
                        .where((p) => p.isNotEmpty)
                        .indexed)
                      if (i == 0 && title.contains('·'))
                        TagChip(part, tone: TagTone.green)
                      else
                        Text(part,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: FinniColors.primary,
                            )),
                  ]),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.emoji,
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(fontSize: 34, height: 1.1)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _fill(step.text, run.values),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: FinniColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              if (step.action == CoachAction.tap && !_lost)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(texts.tap,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700, color: FinniColors.primary)),
                ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (shown.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        _fill(texts.step, {'n': '$position', 'total': '${shown.length}'}),
                        style: const TextStyle(fontSize: 16, color: FinniColors.muted),
                      ),
                    ),
                  TextButton(onPressed: skip, child: Text(texts.skip)),
                  if (step.action == CoachAction.wait)
                    OutlinedButton(onPressed: _next, child: Text(texts.later)),
                  if (needsButton)
                    FilledButton(
                      onPressed: _next,
                      child: Text(last ? texts.done : texts.next),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Barrier extends SingleChildRenderObjectWidget {
  const _Barrier({required this.hole, required this.open, super.child});

  final Rect? hole;
  final bool open;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBarrier(hole, open);

  @override
  void updateRenderObject(BuildContext context, _RenderBarrier renderObject) {
    renderObject
      ..hole = hole
      ..open = open;
  }
}

class _RenderBarrier extends RenderProxyBox {
  _RenderBarrier(this.hole, this.open);

  Rect? hole;
  bool open;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final gap = hole;
    if (open && gap != null && gap.contains(position)) return false;
    if (!size.contains(position)) return false;
    hitTestChildren(result, position: position);
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}

class _Shade extends CustomPainter {
  _Shade({required this.hole, required this.pulse, required this.dim});

  final Rect? hole;
  final double pulse;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = hole;
    final shape = gap == null
        ? null
        : RRect.fromRectAndRadius(gap.inflate(8), const Radius.circular(20));
    if (dim) {
      final path = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size);
      if (shape != null) path.addRRect(shape);
      canvas.drawPath(path, Paint()..color = const Color(0xA6182620));
    }
    if (shape == null) return;
    canvas.drawRRect(
      shape.inflate(2 + pulse * 6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = FinniColors.honey.withValues(alpha: 1 - pulse * .7),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = FinniColors.honey,
    );
  }

  @override
  bool shouldRepaint(_Shade oldDelegate) =>
      oldDelegate.hole != hole || oldDelegate.pulse != pulse || oldDelegate.dim != dim;
}
