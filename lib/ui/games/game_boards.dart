import '../widgets/game_text.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../../domain/ru_words.dart';
import '../../domain/services/hint_service.dart';
import '../../domain/services/task_engine.dart';
import '../../domain/text_template.dart';
import '../theme/finni_theme.dart';
import '../widgets/coach.dart';
import '../widgets/coin_icon.dart';
import '../widgets/emoji_art.dart';
import '../widgets/finni_ui.dart';

part 'game_sims.dart';

String fillText(String template, Map<String, String> values) =>
    fillPlurals(fillTemplate(template, values));

final math.Random _mixer = math.Random();

List<T> mixed<T>(List<T> items,
    {Object? Function(T item)? groupOf, bool Function(List<T> order)? avoid}) {
  if (items.length < 2) return [...items];
  bool same(List<T> order) {
    for (var i = 0; i < order.length; i++) {
      if (!identical(order[i], items[i])) return false;
    }
    return true;
  }

  bool clumped(List<T> order) {
    if (groupOf == null) return false;
    final groups = {for (final item in order) groupOf(item)}.length;
    if (groups < 2) return false;
    var changes = 0;
    for (var i = 1; i < order.length; i++) {
      if (groupOf(order[i]) != groupOf(order[i - 1])) changes++;
    }
    final half = order.take(order.length ~/ 2 + 1).map(groupOf).toSet();
    return changes <= groups || half.length < 2;
  }

  var order = [...items]..shuffle(_mixer);
  for (var tries = 0;
      tries < 20 &&
          (same(order) || clumped(order) || (avoid?.call(order) ?? false));
      tries++) {
    order.shuffle(_mixer);
  }
  return order;
}

final class BoardContext {
  const BoardContext({
    required this.task,
    required this.variant,
    required this.texts,
    required this.plan,
    required this.binLabels,
    required this.check,
    required this.locked,
    required this.motion,
    required this.onChanged,
    required this.onSubmit,
    this.onSituation,
    this.sound,
  });

  final TaskDef task;
  final TaskVariant variant;
  final TaskTexts texts;
  final PlanRules plan;
  final Map<String, String> binLabels;
  final TaskCheck? check;
  final bool locked;
  final bool motion;
  final ValueChanged<TaskAnswer?> onChanged;
  final ValueChanged<TaskAnswer> onSubmit;
  final void Function(HintSituation Function() read)? onSituation;

  /// Короткий эффект по id из звуковой схемы; в тестах null — тишина.
  final void Function(String event)? sound;

  bool get showMarks => check != null && check!.verdict != TaskVerdict.incomplete;
}

Widget buildBoard(BoardContext board) => switch (board.variant.payload) {
      SortPayload payload => SortBoard(board: board, payload: payload),
      CoinsPayload payload => CoinsBoard(board: board, payload: payload),
      DistributePayload payload => DistributeBoard(board: board, payload: payload),
      OrderPayload payload => OrderBoard(board: board, payload: payload),
      ChoicePayload payload => ChoiceBoard(board: board, payload: payload),
      BasketPayload payload => BasketBoard(board: board, payload: payload),
      WeekPayload payload => WeekBoard(board: board, payload: payload),
      BoardPayload payload => BoardGame(board: board, payload: payload),
      StallPayload payload => StallGame(board: board, payload: payload),
      CashierPayload payload => CashierGame(board: board, payload: payload),
      PriceTagPayload payload => PriceTagGame(board: board, payload: payload),
    };

class _Mark extends StatelessWidget {
  const _Mark({required this.right});

  final bool right;

  @override
  Widget build(BuildContext context) => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: right ? FinniColors.mint : FinniColors.lavender,
          shape: BoxShape.circle,
          border: Border.all(color: FinniColors.paper, width: 2),
        ),
        child: Icon(
          right ? Icons.check_rounded : Icons.question_mark_rounded,
          size: 16,
          color: right ? FinniColors.primary : FinniColors.purple,
        ),
      );
}

class _CardChip extends StatelessWidget {
  const _CardChip({
    required this.iconId,
    required this.label,
    this.selected = false,
    this.mark,
    this.compact = false,
  });

  final String iconId;
  final String label;
  final bool selected;
  final bool? mark;
  final bool compact;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.all(compact ? 6 : 8),
            decoration: BoxDecoration(
              color: FinniColors.paper,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? FinniColors.primary : FinniColors.line,
                width: selected ? 3 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: FinniColors.shadow,
                  blurRadius: selected ? 14 : 6,
                  offset: Offset(0, selected ? 6 : 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                EmojiBadge(iconId, size: compact ? 34 : 44),
                const SizedBox(width: 8),
                Flexible(
                  child: GameText(
                    label,
                    style: TextStyle(
                      fontSize: compact ? 15 : 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          if (mark != null)
            Positioned(right: -6, top: -8, child: _Mark(right: mark!)),
        ],
      );
}

class SortBoard extends StatefulWidget {
  const SortBoard({super.key, required this.board, required this.payload});

  final BoardContext board;
  final SortPayload payload;

  @override
  State<SortBoard> createState() => _SortBoardState();
}

class _SortBoardState extends State<SortBoard> {
  final Map<String, String> placed = {};
  String? selected;
  String? hovered;
  late List<SortCard> cards = _mix();

  List<SortCard> _mix() => mixed(widget.payload.cards, groupOf: (c) => c.bin);

  @override
  void didUpdateWidget(SortBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.payload, widget.payload)) cards = _mix();
  }

  SortPayload get payload => widget.payload;
  BoardContext get board => widget.board;

  void _place(String cardId, String bin) {
    if (board.locked) return;
    setState(() {
      placed[cardId] = bin;
      selected = null;
    });
    board.sound?.call('snap');
    _report();
  }

  void _unplace(String cardId) {
    if (board.locked) return;
    setState(() => placed.remove(cardId));
    board.sound?.call('snap');
    _report();
  }

  void _report() => board.onChanged(
      placed.length == payload.cards.length ? SortAnswer({...placed}) : null);

  bool? _markOf(String cardId) {
    final check = board.check;
    if (!board.showMarks || check == null || !placed.containsKey(cardId)) {
      return null;
    }
    return check.placedRight.contains(cardId);
  }

  Color _binColor(String bin) =>
      bin == payload.bins.first ? FinniColors.mint : FinniColors.lavender;

  IconData _binIcon(String bin) => bin == payload.bins.first
      ? Icons.check_circle_outline_rounded
      : Icons.auto_awesome_outlined;

  Widget _card(SortCard card, {bool compact = false}) => _CardChip(
        iconId: card.iconId,
        label: card.label,
        selected: selected == card.id,
        mark: _markOf(card.id),
        compact: compact,
      );

  @override
  Widget build(BuildContext context) {
    final waiting = [
      for (final card in cards)
        if (!placed.containsKey(card.id)) card
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameText(board.texts.sort.instruction,
            style: const TextStyle(color: FinniColors.muted)),
        const SizedBox(height: 12),
        CoachTarget(
          id: 'sort.cards',
          child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: waiting.isEmpty
              ? const SizedBox(width: double.infinity)
              : EqualGrid(
                  columns:
                      MediaQuery.textScalerOf(context).scale(16) > 22 ? 1 : 2,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final (i, card) in waiting.indexed)
                      PopIn(
                        key: ValueKey('wait-${card.id}'),
                        motion: board.motion,
                        delay: i * 40,
                        child: Draggable<String>(
                          data: card.id,
                          maxSimultaneousDrags: board.locked ? 0 : 1,
                          feedback: Material(
                            color: FinniColors.transparent,
                            child: Transform.rotate(
                              angle: -.06,
                              child: Transform.scale(scale: 1.12, child: _card(card)),
                            ),
                          ),
                          childWhenDragging: Opacity(opacity: .3, child: _card(card)),
                          child: Squish(
                            enabled: !board.locked,
                            onTap: () => setState(() =>
                                selected = selected == card.id ? null : card.id),
                            child: _card(card),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        ),
        if (waiting.isNotEmpty) ...[
          const SizedBox(height: 10),
          GameText(
            fillText(board.texts.sort.notAllPlaced, {'count': '${waiting.length}'}),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
        const SizedBox(height: 16),
        CoachTarget(
          id: 'sort.bins',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, bin) in payload.bins.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: _bin(bin)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _bin(String bin) => DragTarget<String>(
        onWillAcceptWithDetails: (details) {
          if (board.locked) return false;
          setState(() => hovered = bin);
          return true;
        },
        onLeave: (_) => setState(() => hovered = null),
        onAcceptWithDetails: (details) {
          setState(() => hovered = null);
          _place(details.data, bin);
        },
        builder: (context, candidates, rejected) {
          final active = hovered == bin || (selected != null && !board.locked);
          final inside = [
            for (final card in cards)
              if (placed[card.id] == bin) card
          ];
          return Semantics(
            button: selected != null,
            label: 'Корзина «${board.binLabels[bin] ?? bin}»',
            child: GestureDetector(
              onTap: selected == null ? null : () => _place(selected!, bin),
              child: AnimatedScale(
                scale: hovered == bin ? 1.04 : 1,
                duration: const Duration(milliseconds: 150),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  constraints: const BoxConstraints(minHeight: 170),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _binColor(bin),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: active ? FinniColors.primary : FinniColors.transparent,
                      width: 3,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(_binIcon(bin), color: FinniColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GameText(
                              board.binLabels[bin] ?? bin,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                          ),
                          GameText('${inside.length}',
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (inside.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: GameText(
                              board.texts.sort.binEmoji[bin] ??
                                  (bin == payload.bins.first ? '🧺' : '🎁'),
                              style: const TextStyle(fontSize: 40),
                            ),
                          ),
                        ),
                      for (final card in inside)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: PopIn(
                            key: ValueKey('in-${card.id}-$bin'),
                            motion: board.motion,
                            child: Squish(
                              enabled: !board.locked,
                              onTap: () => _unplace(card.id),
                              child: _card(card, compact: true),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class _CoinDisc extends StatelessWidget {
  const _CoinDisc({required this.value, this.size = 56});

  final int value;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CoinIcon(size: size),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: FinniColors.paper.withValues(alpha: .92),
                borderRadius: BorderRadius.circular(10),
              ),
              child: GameText(
                '$value',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: size * .34,
                  fontWeight: FontWeight.w900,
                  color: FinniColors.gold,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      );
}

class CoinsBoard extends StatefulWidget {
  const CoinsBoard({super.key, required this.board, required this.payload});

  final BoardContext board;
  final CoinsPayload payload;

  @override
  State<CoinsBoard> createState() => _CoinsBoardState();
}

class _CoinsBoardState extends State<CoinsBoard> {
  final List<int> counter = [];
  bool glowing = false;

  CoinsPayload get payload => widget.payload;
  BoardContext get board => widget.board;

  int _used(int value) => counter.where((c) => c == value).length;

  int get total => counter.fold(0, (a, b) => a + b);

  void _add(int value) {
    if (board.locked || _used(value) >= (payload.wallet[value] ?? 0)) return;
    setState(() => counter.add(value));
    board.sound?.call('coin');
    _report();
  }

  void _removeAt(int index) {
    if (board.locked) return;
    setState(() => counter.removeAt(index));
    board.sound?.call('ui_tick');
    _report();
  }

  void _report() {
    final counts = <int, int>{};
    for (final coin in counter) {
      counts.update(coin, (n) => n + 1, ifAbsent: () => 1);
    }
    board.onChanged(counter.isEmpty ? null : CoinsAnswer(counts));
  }

  double _sizeOf(int value) => switch (value) {
        1 => 46.0,
        2 => 52.0,
        5 => 58.0,
        _ => 64.0,
      };

  @override
  Widget build(BuildContext context) {
    final texts = board.texts.coins;
    final denominations = payload.wallet.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TagPill(
              icon: Icons.sell_outlined,
              label: fillText(texts.price, {'price': '${payload.price}'}),
              color: FinniColors.honey,
            ),
            if (payload.paid != null)
              TagPill(
                icon: Icons.front_hand_outlined,
                label: fillText(texts.paid, {'paid': '${payload.paid}'}),
                color: FinniColors.sky,
              ),
          ],
        ),
        const SizedBox(height: 14),
        CoachTarget(
          id: 'coins.counter',
          child: DragTarget<int>(
          onWillAcceptWithDetails: (details) {
            if (board.locked) return false;
            setState(() => glowing = true);
            return true;
          },
          onLeave: (_) => setState(() => glowing = false),
          onAcceptWithDetails: (details) {
            setState(() => glowing = false);
            _add(details.data);
          },
          builder: (context, candidates, rejected) => AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 150),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E3C4),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: glowing ? FinniColors.gold : const Color(0xFFE2C993),
                width: glowing ? 3 : 2,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const GameText('🏪', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GameText(
                        fillText(texts.onCounter, {'onCounter': '$total'}),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (counter.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: GameText(texts.dragHint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: FinniColors.muted)),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final (i, coin) in counter.indexed)
                        PopIn(
                          key: ValueKey('coin-$i-$coin'),
                          motion: board.motion,
                          child: Squish(
                            enabled: !board.locked,
                            onTap: () => _removeAt(i),
                            child: _CoinDisc(value: coin, size: _sizeOf(coin) * .82),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        ),
        const SizedBox(height: 16),
        const GameText('Кошелёк', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        CoachTarget(
          id: 'coins.wallet',
          child: FinniCard(
          color: FinniColors.lavender,
          child: Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final value in denominations)
                _WalletCoin(
                  value: value,
                  left: (payload.wallet[value] ?? 0) - _used(value),
                  size: _sizeOf(value),
                  enabled: !board.locked,
                  onTap: () => _add(value),
                ),
            ],
          ),
        ),
        ),
      ],
    );
  }
}

class _WalletCoin extends StatelessWidget {
  const _WalletCoin({
    required this.value,
    required this.left,
    required this.size,
    required this.enabled,
    required this.onTap,
  });

  final int value;
  final int left;
  final double size;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disc = _CoinDisc(value: value, size: size);
    final active = enabled && left > 0;
    return Semantics(
      button: true,
      label: 'Монета $value, осталось $left',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: left > 0 ? 1 : .35,
            child: active
                ? Draggable<int>(
                    data: value,
                    feedback: Transform.scale(scale: 1.15, child: disc),
                    childWhenDragging: Opacity(opacity: .4, child: disc),
                    child: Squish(onTap: onTap, child: disc),
                  )
                : disc,
          ),
          const SizedBox(height: 4),
          GameText('×$left', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class DistributeBoard extends StatefulWidget {
  const DistributeBoard({super.key, required this.board, required this.payload});

  final BoardContext board;
  final DistributePayload payload;

  @override
  State<DistributeBoard> createState() => _DistributeBoardState();
}

class _DistributeBoardState extends State<DistributeBoard> {
  late final Map<String, int> amounts = {
    for (final counter in widget.payload.counters) counter.id: counter.min
  };

  DistributePayload get payload => widget.payload;
  BoardContext get board => widget.board;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  int get total => [
        for (final counter in payload.counters)
          (amounts[counter.id] ?? 0) * counter.unitValue
      ].fold(0, (a, b) => a + b);

  void _report() {
    if (mounted) board.onChanged(DistributeAnswer({...amounts}));
  }

  void _change(CounterSpec counter, int delta) {
    final next = (amounts[counter.id] ?? 0) + delta * counter.step;
    final max = counter.max;
    if (next < counter.min || (max != null && next > max)) return;
    final pool = payload.pool;
    if (pool != null && delta > 0 && total + counter.step * counter.unitValue > pool) {
      return;
    }
    setState(() => amounts[counter.id] = next);
    board.sound?.call('ui_tick');
    _report();
  }

  String _label(CounterSpec counter) {
    if (payload.counterSource == 'plan.directions') {
      return board.plan.directions[counter.id]?.label ?? counter.id;
    }
    return counter.label.isEmpty ? counter.id : counter.label;
  }

  String? _hint(CounterSpec counter) => payload.counterSource == 'plan.directions'
      ? board.plan.directions[counter.id]?.hint
      : null;

  String _iconId(CounterSpec counter) {
    if (payload.counterSource == 'plan.directions') {
      return board.plan.directions[counter.id]?.iconId ?? counter.iconId;
    }
    return counter.iconId;
  }

  @override
  Widget build(BuildContext context) =>
      payload.pool == null ? _days(context) : _jars(context);

  Widget _stepper(CounterSpec counter, Widget value) => Row(
        children: [
          IconButton.filledTonal(
            tooltip: 'Меньше: ${_label(counter)}',
            onPressed: board.locked ? null : () => _change(counter, -1),
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(child: Center(child: value)),
          IconButton.filledTonal(
            tooltip: 'Больше: ${_label(counter)}',
            onPressed: board.locked ? null : () => _change(counter, 1),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      );

  Widget _jars(BuildContext context) {
    final pool = payload.pool!;
    final remainder = pool - total;
    const colors = [FinniColors.mint, FinniColors.sky, FinniColors.lavender];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoachTarget(
          id: 'distribute.left',
          child: FinniCard(
          color: FinniColors.honey,
          padding: 12,
          child: Row(
            children: [
              const GameText('🪙', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              Expanded(
                child: GameText(
                  fillText(board.texts.distribute.remainder, {'remainder': '$remainder'}),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              CoinAmount(remainder),
            ],
          ),
        ),
        ),
        const SizedBox(height: 12),
        for (final (i, counter) in payload.counters.indexed) ...[
          FinniCard(
            color: colors[i % colors.length].withValues(alpha: .7),
            padding: 12,
            child: Row(
              children: [
                _Jar(
                  fill: pool == 0 ? 0 : (amounts[counter.id] ?? 0) * counter.unitValue / pool,
                  iconId: _iconId(counter),
                  motion: board.motion,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GameText(_label(counter),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      if (_hint(counter) != null)
                        GameText(_hint(counter)!,
                            style: const TextStyle(color: FinniColors.muted)),
                      const SizedBox(height: 6),
                      i == 0
                          ? CoachTarget(
                              id: 'distribute.controls',
                              child: _stepper(counter, CoinAmount(amounts[counter.id] ?? 0)),
                            )
                          : _stepper(counter, CoinAmount(amounts[counter.id] ?? 0)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _days(BuildContext context) {
    final counter = payload.counters.first;
    final count = amounts[counter.id] ?? 0;
    final target = payload.target ?? 0;
    final sum = count * counter.unitValue;
    final progress = target == 0 ? 0.0 : (sum / target).clamp(0.0, 1.0);
    final preview = payload.preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoachTarget(
          id: 'distribute.left',
          child: FinniCard(
          color: FinniColors.lavender,
          child: Column(
            children: [
              Row(
                children: [
                  const GameText('🐷', style: TextStyle(fontSize: 34)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: progress),
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 22,
                          color: sum >= target ? FinniColors.primary : FinniColors.purple,
                          backgroundColor: FinniColors.paper,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CoinAmount(target),
                ],
              ),
              const SizedBox(height: 12),
              if (preview != null)
                GameText(
                  fillText(preview, {'days': '$count', 'daysTotal': '$sum'}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
            ],
          ),
        ),
        ),
        const SizedBox(height: 12),
        FinniCard(
          child: Column(
            children: [
              CoachTarget(
                id: 'distribute.controls',
                child: _stepper(
                  counter,
                  GameText('$count',
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                ),
              ),
              GameText(counter.label.isEmpty ? '' : counter.label,
                  style: const TextStyle(color: FinniColors.muted)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (var d = 0; d < count; d++)
                    PopIn(
                      key: ValueKey('day-$d'),
                      motion: board.motion,
                      child: Container(
                        width: 44,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: FinniColors.honey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            GameText('${d + 1}',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w800)),
                            const CoinIcon(size: 20),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Jar extends StatelessWidget {
  const _Jar({required this.fill, required this.iconId, required this.motion});

  final double fill;
  final String iconId;
  final bool motion;

  @override
  Widget build(BuildContext context) => Container(
        width: 64,
        height: 86,
        decoration: BoxDecoration(
          color: FinniColors.paper.withValues(alpha: .8),
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(14), bottom: Radius.circular(22)),
          border: Border.all(color: FinniColors.paper, width: 3),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: fill.clamp(0.0, 1.0)),
              duration: motionAllowed(context, motion)
                  ? const Duration(milliseconds: 380)
                  : Duration.zero,
              curve: Curves.easeOutBack,
              builder: (context, value, _) => FractionallySizedBox(
                heightFactor: value.clamp(0.0, 1.0),
                widthFactor: 1,
                child: const DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFFFFD66B)),
                ),
              ),
            ),
            Center(child: EmojiBadge(iconId, size: 38, color: FinniColors.transparent)),
          ],
        ),
      );
}

class OrderBoard extends StatefulWidget {
  const OrderBoard({super.key, required this.board, required this.payload});

  final BoardContext board;
  final OrderPayload payload;

  @override
  State<OrderBoard> createState() => _OrderBoardState();
}

class _OrderBoardState extends State<OrderBoard> {
  late List<OrderItem> order = _shuffled();
  int? picked;

  OrderPayload get payload => widget.payload;
  BoardContext get board => widget.board;

  List<OrderItem> _shuffled() {
    bool sorted(List<OrderItem> items) {
      for (var i = 1; i < items.length; i++) {
        if (items[i].rank < items[i - 1].rank) return false;
      }
      return true;
    }

    final items = mixed(payload.items, avoid: sorted);
    return sorted(items) ? items.reversed.toList() : items;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  void _report() {
    if (mounted) board.onChanged(OrderAnswer([for (final i in order) i.id]));
  }

  void _tap(int index) {
    if (board.locked) return;
    final first = picked;
    if (first == null) {
      setState(() => picked = index);
      return;
    }
    if (first == index) {
      setState(() => picked = null);
      return;
    }
    setState(() {
      final a = order[first];
      order[first] = order[index];
      order[index] = a;
      picked = null;
    });
    board.sound?.call('snap');
    _report();
  }

  @override
  Widget build(BuildContext context) {
    final check = board.check;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TagPill(
          icon: Icons.touch_app_outlined,
          label: board.texts.order.swapHint,
          color: FinniColors.sky,
        ),
        const SizedBox(height: 12),
        CoachTarget(
          id: 'order.list',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
        for (final (i, item) in order.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AnimatedSwitcher(
              duration: motionAllowed(context, board.motion)
                  ? const Duration(milliseconds: 260)
                  : Duration.zero,
              transitionBuilder: (child, animation) => SizeTransition(
                sizeFactor: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Squish(
                key: ValueKey('slot-$i-${item.id}'),
                enabled: !board.locked,
                onTap: () => _tap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  transform: Matrix4.translationValues(picked == i ? 10 : 0, 0, 0),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: picked == i ? FinniColors.honey : FinniColors.paper,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: picked == i ? FinniColors.gold : FinniColors.line,
                      width: picked == i ? 3 : 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: FinniColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: GameText('${i + 1}',
                            style: const TextStyle(
                                color: FinniColors.paper,
                                fontWeight: FontWeight.w900,
                                fontSize: 17)),
                      ),
                      const SizedBox(width: 10),
                      EmojiBadge(item.iconId, size: 46),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GameText(item.label,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800)),
                      ),
                      if (board.showMarks && check != null)
                        _Mark(right: check.placedRight.contains(item.id))
                      else
                        const Icon(Icons.swap_vert_rounded, color: FinniColors.muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
            ],
          ),
        ),
        if (board.showMarks && check != null && check.placedRight.isNotEmpty)
          GameText('✓ ${board.texts.order.placedRight}',
              style: const TextStyle(color: FinniColors.muted)),
      ],
    );
  }
}

class ChoiceBoard extends StatefulWidget {
  const ChoiceBoard({super.key, required this.board, required this.payload});

  final BoardContext board;
  final ChoicePayload payload;

  @override
  State<ChoiceBoard> createState() => _ChoiceBoardState();
}

class _ChoiceBoardState extends State<ChoiceBoard> {
  String? chosen;
  late List<ChoiceOption> options = mixed(widget.payload.options);

  @override
  void didUpdateWidget(ChoiceBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.payload, widget.payload)) {
      options = mixed(widget.payload.options);
    }
  }

  static const List<String> _faces = ['🅰️', '🅱️', '🔹'];
  static const List<Color> _colors = [
    FinniColors.mint,
    FinniColors.sky,
    FinniColors.lavender,
  ];

  @override
  Widget build(BuildContext context) {
    final board = widget.board;
    final check = board.check;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameText(widget.payload.question,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        CoachTarget(
          id: 'choice.options',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
        for (final (i, option) in options.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PopIn(
              motion: board.motion,
              delay: i * 80,
              child: Squish(
                enabled: !board.locked,
                onTap: () {
                  board.sound?.call('snap');
                  setState(() => chosen = option.id);
                  board.onSubmit(ChoiceAnswer(option.id));
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _colors[i % _colors.length],
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: chosen == option.id ? FinniColors.primary : FinniColors.transparent,
                      width: 3,
                    ),
                  ),
                  child: Row(
                    children: [
                      GameText(_faces[i % _faces.length],
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GameText(option.label,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                      if (chosen == option.id && check != null && board.showMarks)
                        _Mark(right: check.isCorrect),
                    ],
                  ),
                ),
              ),
            ),
          ),
            ],
          ),
        ),
      ],
    );
  }
}

class BasketBoard extends StatefulWidget {
  const BasketBoard({super.key, required this.board, required this.payload});

  final BoardContext board;
  final BasketPayload payload;

  @override
  State<BasketBoard> createState() => _BasketBoardState();
}

class _BasketBoardState extends State<BasketBoard> {
  final Set<String> basket = {};
  late List<BasketProduct> products = _mix();

  List<BasketProduct> _mix() =>
      mixed(widget.payload.products, groupOf: (p) => p.onList);

  @override
  void didUpdateWidget(BasketBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.payload, widget.payload)) products = _mix();
  }

  BasketPayload get payload => widget.payload;
  BoardContext get board => widget.board;

  int get total => [
        for (final p in payload.products)
          if (basket.contains(p.id)) p.price
      ].fold(0, (a, b) => a + b);

  void _toggle(BasketProduct product) {
    if (board.locked) return;
    setState(() {
      if (!basket.remove(product.id)) basket.add(product.id);
    });
    board.sound?.call('snap');
    board.onChanged(basket.isEmpty ? null : BasketAnswer({...basket}));
  }

  @override
  Widget build(BuildContext context) {
    final texts = board.texts.basket;
    final budget = payload.budget;
    final left = budget - total;
    final over = left < 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoachTarget(
          id: 'basket.budget',
          child: FinniCard(
          color: over ? FinniColors.honey : FinniColors.mint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const GameText('🛒', style: TextStyle(fontSize: 30)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GameText(fillText(texts.budget, {'budget': '$budget'}),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                  GameText(
                    over
                        ? fillText(texts.over, {'gap': '${-left}'})
                        : fillText(texts.left, {'left': '$left'}),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: budget == 0 ? 0 : (total / budget).clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 16,
                    color: over ? FinniColors.gold : FinniColors.primary,
                    backgroundColor: FinniColors.paper,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GameText(fillText(texts.inBasket, {'total': '$total'})),
            ],
          ),
        ),
        ),
        const SizedBox(height: 12),
        CoachTarget(
          id: 'basket.list',
          child: FinniCard(
          color: FinniColors.paper,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GameText('📝 Список',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final product in payload.fromList)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          basket.contains(product.id)
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          key: ValueKey(basket.contains(product.id)),
                          color: FinniColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GameText(product.label,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                decoration: basket.contains(product.id)
                                    ? TextDecoration.lineThrough
                                    : null)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        ),
        const SizedBox(height: 12),
        CoachTarget(
          id: 'basket.products',
          child: LayoutBuilder(builder: (context, constraints) {
          final wide = MediaQuery.textScalerOf(context).scale(16) <= 22;
          final columns = wide ? 3 : 2;
          final width = ((constraints.maxWidth - (columns - 1) * 8) / columns).clamp(0.0, double.infinity);
          return EqualGrid(
            columns: columns,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, product) in products.indexed)
                SizedBox(
                  width: width,
                  child: PopIn(
                    motion: board.motion,
                    delay: i * 30,
                    child: _ProductTile(
                      product: product,
                      inBasket: basket.contains(product.id),
                      onListLabel: texts.onList,
                      enabled: !board.locked,
                      onTap: () => _toggle(product),
                    ),
                  ),
                ),
            ],
          );
        }),
        ),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.inBasket,
    required this.onListLabel,
    required this.enabled,
    required this.onTap,
  });

  final BasketProduct product;
  final bool inBasket;
  final String onListLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: inBasket,
        label: '${product.label}, ${product.price} ${ruCoins(product.price)}',
        excludeSemantics: true,
        child: Squish(
          enabled: enabled,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: inBasket ? FinniColors.mint : FinniColors.paper,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: inBasket ? FinniColors.primary : FinniColors.line,
                width: inBasket ? 3 : 1.5,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  children: [
                    EmojiBadge(product.iconId, size: 52),
                    const SizedBox(height: 4),
                    GameText(product.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    CoinAmount(product.price, size: 16),
                    if (product.onList)
                      GameText(onListLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: FinniColors.muted)),
                  ],
                ),
                if (inBasket)
                  const Positioned(right: -4, top: -4, child: _Mark(right: true)),
              ],
            ),
          ),
        ),
      );
}

class WeekBoard extends StatefulWidget {
  const WeekBoard({super.key, required this.board, required this.payload});

  final BoardContext board;
  final WeekPayload payload;

  @override
  State<WeekBoard> createState() => _WeekBoardState();
}

class _WeekBoardState extends State<WeekBoard> {
  late final List<int> saved = List.filled(widget.payload.days, 0);

  WeekPayload get payload => widget.payload;
  BoardContext get board => widget.board;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  void _report() {
    if (mounted) board.onChanged(WeekAnswer([...saved]));
  }

  void _change(int day, int delta) {
    final next = saved[day] + delta * payload.step;
    if (board.locked || next < 0 || next > payload.maxSavePerDay) return;
    setState(() => saved[day] = next);
    board.sound?.call('ui_tick');
    _report();
  }

  @override
  Widget build(BuildContext context) {
    final texts = board.texts.week;
    var wallet = 0;
    var savings = 0;
    final rows = <Widget>[];
    for (var day = 1; day <= payload.days; day++) {
      final put = saved[day - 1];
      wallet += payload.dailyIncome - put;
      savings += put;
      final event = payload.eventOn(day);
      int? gap;
      if (event != null) {
        if (wallet < event.cost) gap = event.cost - wallet;
        wallet -= event.cost;
      }
      if (wallet < 0) wallet = 0;
      final card = _dayCard(day, put, wallet, savings, event, gap, texts);
      rows.add(day == 1 ? CoachTarget(id: 'week.first', child: card) : card);
    }
    final goalProgress =
        payload.target == 0 ? 0.0 : (savings / payload.target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoachTarget(
          id: 'week.goal',
          child: FinniCard(
          color: FinniColors.lavender,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const GameText('🎯', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GameText(fillText(texts.goal, {'target': '${payload.target}'}),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                  GameText(fillText(texts.savings, {'savings': '$savings'}),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: goalProgress),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 16,
                    color: FinniColors.purple,
                    backgroundColor: FinniColors.paper,
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
        const SizedBox(height: 12),
        ...rows,
      ],
    );
  }

  Widget _dayCard(int day, int put, int wallet, int savings, WeekEvent? event,
          int? gap, WeekTexts texts) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FinniCard(
          color: event != null ? FinniColors.sky : FinniColors.paper,
          padding: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GameText(fillText(texts.day, {'n': '$day'}),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  CoinAmount(payload.dailyIncome, size: 16, prefix: '+'),
                  const Spacer(),
                  if (event != null)
                    Flexible(
                      flex: 3,
                      child: TagPill(
                        icon: Icons.event_outlined,
                        label: '${kEmoji[event.iconId] ?? '🎉'} ${event.label} −${event.cost}',
                        color: FinniColors.honey,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const GameText('🐷', style: TextStyle(fontSize: 22)),
                  IconButton.filledTonal(
                    tooltip: 'Отложить меньше в день $day',
                    onPressed: board.locked ? null : () => _change(day - 1, -1),
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Expanded(child: Center(child: CoinAmount(put))),
                  IconButton.filledTonal(
                    tooltip: 'Отложить больше в день $day',
                    onPressed: board.locked ? null : () => _change(day - 1, 1),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                children: [
                  GameText(fillText(texts.wallet, {'wallet': '$wallet'}),
                      style: const TextStyle(color: FinniColors.muted)),
                  GameText(fillText(texts.savings, {'savings': '$savings'}),
                      style: const TextStyle(color: FinniColors.muted)),
                ],
              ),
              if (event != null && gap != null) ...[
                const SizedBox(height: 6),
                SoftNotice(
                  icon: Icons.lightbulb_outline_rounded,
                  text: fillText(texts.eventGap, {'label': event.label, 'gap': '$gap'}),
                ),
              ],
            ],
          ),
        ),
      );
}
