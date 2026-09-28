part of 'game_boards.dart';

class _Hud extends StatelessWidget {
  const _Hud({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: children,
      );
}

class _HudChip extends StatelessWidget {
  const _HudChip({required this.emoji, required this.text, required this.color});

  final String emoji;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Container(
          key: ValueKey(text),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              Text(text,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
}

class _GoalMeter extends StatelessWidget {
  const _GoalMeter({required this.value, required this.target, required this.labels});

  final int value;
  final int target;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final progress = target == 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TagRow([
          for (final (i, label) in labels.indexed)
            TagChip(label, tone: i == 0 ? TagTone.purple : TagTone.blue),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progress),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 16,
              color: value >= target ? FinniColors.primary : FinniColors.purple,
              backgroundColor: FinniColors.paper,
            ),
          ),
        ),
      ],
    );
  }
}

class _Die extends StatelessWidget {
  const _Die({required this.face, required this.spinning});

  final int? face;
  final bool spinning;

  @override
  Widget build(BuildContext context) => AnimatedRotation(
        turns: spinning ? .05 : 0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FinniColors.paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FinniColors.primary, width: 3),
            boxShadow: const [
              BoxShadow(color: FinniColors.shadow, blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          child: Text(
            face == null ? '🎲' : '$face',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: face == null ? 34 : 32,
              fontWeight: FontWeight.w900,
              color: FinniColors.primary,
            ),
          ),
        ),
      );
}

class BoardGame extends StatefulWidget {
  const BoardGame({super.key, required this.board, required this.payload});

  final BoardContext board;
  final BoardPayload payload;

  @override
  State<BoardGame> createState() => _BoardGameState();
}

class _BoardGameState extends State<BoardGame> {
  late BoardRun run = BoardRun.start(widget.payload);

  @override
  void initState() {
    super.initState();
    widget.board.onSituation?.call(() => BoardSituation(run));
  }

  int? face;
  bool spinning = false;
  bool submitted = false;
  String? event;
  int piggyAmount = 0;
  Timer? timer;

  BoardPayload get payload => widget.payload;
  BoardContext get board => widget.board;
  TextGroup get texts => board.texts.board;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _roll() {
    if (!run.canRoll || spinning) return;
    board.sound?.call('dice');
    final value = run.nextRoll!;
    if (!motionAllowed(context, board.motion)) {
      _land(value);
      return;
    }
    var ticks = 0;
    setState(() => spinning = true);
    timer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      ticks++;
      if (!mounted) {
        t.cancel();
        return;
      }
      if (ticks >= 8) {
        t.cancel();
        _land(value);
      } else {
        setState(() => face = (ticks * 7 + value) % 6 + 1);
      }
    });
  }

  void _land(int value) {
    final next = run.roll();
    final cell = next.cell;
    String? text;
    switch (cell.kind) {
      case BoardCellKind.income:
        board.sound?.call('coin');
        text = fillText(texts['income'], {'amount': '${cell.amount}', 'label': cell.label});
      case BoardCellKind.expense:
        final short = next.shortages.length > run.shortages.length
            ? next.shortages.last
            : null;
        board.sound?.call(short == null ? 'purchase' : 'not_enough');
        text = short == null
            ? fillText(texts['expense'], {'amount': '${cell.amount}', 'label': cell.label})
            : fillText(texts['short'], {'label': cell.label, 'gap': '${short.gap}'});
      case BoardCellKind.finish:
        text = texts['finish'];
      case BoardCellKind.start ||
            BoardCellKind.temptation ||
            BoardCellKind.piggy ||
            BoardCellKind.rest:
        text = null;
    }
    setState(() {
      run = next;
      face = value;
      spinning = false;
      event = text;
      piggyAmount = next.pending && cell.kind == BoardCellKind.piggy
          ? next.options().lastWhere((amount) => amount * 2 <= next.wallet,
              orElse: () => 0)
          : 0;
    });
    _checkFinish();
  }

  void _decide(int value) {
    if (value > 0) {
      board.sound
          ?.call(run.cell.kind == BoardCellKind.piggy ? 'coin' : 'purchase');
    }
    setState(() {
      run = run.decide(value);
      event = null;
    });
    _checkFinish();
  }

  void _checkFinish() {
    if (run.isFinished && !submitted) {
      submitted = true;
      board.onSubmit(BoardAnswer(run.decisions));
    }
  }

  void _restart() {
    board.sound?.call('retry');
    setState(() {
      run = BoardRun.start(payload);
      face = null;
      event = null;
      submitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const columns = 4;
    final rows = <List<int>>[];
    for (var i = 0; i < payload.cells.length; i += columns) {
      final row = [
        for (var j = i; j < i + columns && j < payload.cells.length; j++) j
      ];
      rows.add(rows.length.isOdd ? row.reversed.toList() : row);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hud(children: [
          _HudChip(
              emoji: '👛',
              text: fillText(texts['wallet'], {'wallet': '${run.wallet}'}),
              color: FinniColors.honey),
          _HudChip(
              emoji: '💛',
              text: fillText(texts['joy'], {'joy': '${run.joy}'}),
              color: FinniColors.lavender),
        ]),
        const SizedBox(height: 10),
        CoachTarget(
          id: 'board.goal',
          child: FinniCard(
          color: FinniColors.lavender,
          padding: 12,
          child: _GoalMeter(
            value: run.savings,
            target: payload.target,
            labels: [
              '🐷 ${fillText(texts['savings'], {'savings': '${run.savings}'})}',
              fillText(texts['goal'], {'target': '${payload.target}'}),
            ],
          ),
        ),
        ),
        const SizedBox(height: 12),
        CoachTarget(
          id: 'board.path',
          child: FinniCard(
          color: const Color(0xFFEFF6E8),
          padding: 8,
          child: Column(
            children: [
              for (final row in rows)
                Row(
                  children: [
                    for (final index in row) Expanded(child: _tile(index)),
                    for (var k = row.length; k < columns; k++)
                      const Expanded(child: SizedBox()),
                  ],
                ),
            ],
          ),
        ),
        ),
        const SizedBox(height: 12),
        _eventPanel(),
        const SizedBox(height: 12),
        CoachTarget(
          id: 'board.roll',
          child: Row(
          children: [
            _Die(face: face, spinning: spinning),
            const SizedBox(width: 12),
            Expanded(
              child: run.isFinished
                  ? (board.locked || !submitted
                      ? Text(texts['finish'],
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))
                      : OutlinedButton.icon(
                          onPressed: _restart,
                          icon: const Icon(Icons.replay_rounded),
                          label: Text(texts['again'])))
                  : FilledButton.icon(
                      onPressed: run.canRoll && !spinning && !board.locked ? _roll : null,
                      icon: const Icon(Icons.casino_outlined),
                      label: Text(texts['roll'])),
            ),
          ],
        ),
        ),
      ],
    );
  }

  Widget _tile(int index) {
    final cell = payload.cells[index];
    final here = run.position == index;
    final passed = index < run.position;
    final amount = switch (cell.kind) {
      BoardCellKind.income => '+${cell.amount}',
      BoardCellKind.expense => '−${cell.amount}',
      BoardCellKind.temptation => '${cell.amount}',
      _ => '',
    };
    final color = switch (cell.kind) {
      BoardCellKind.income => FinniColors.mint,
      BoardCellKind.expense => FinniColors.sky,
      BoardCellKind.temptation => FinniColors.honey,
      BoardCellKind.piggy => FinniColors.lavender,
      _ => FinniColors.paper,
    };
    return Semantics(
      label: '${index + 1}. ${cell.label} $amount',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 64,
          decoration: BoxDecoration(
            color: passed ? color.withValues(alpha: .45) : color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: here ? FinniColors.primary : FinniColors.paper,
              width: here ? 3 : 1.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(kEmoji[cell.iconId] ?? '⬜',
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(fontSize: 24)),
                  if (amount.isNotEmpty)
                    Text(amount,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900)),
                ],
              ),
              if (here)
                Positioned(
                  top: 0,
                  right: 0,
                  child: PopIn(
                    key: ValueKey('token-${run.turn}'),
                    motion: board.motion,
                    child: const Text('🦊',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(fontSize: 26)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eventPanel() {
    final cell = run.cell;
    if (run.pending && cell.kind == BoardCellKind.temptation) {
      final options = run.options();
      return PopIn(
        key: ValueKey('tempt-${run.turn}'),
        motion: board.motion,
        child: FinniCard(
          color: FinniColors.honey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                EmojiBadge(cell.iconId, size: 52, color: FinniColors.paper),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${cell.label} — ${cell.amount} ${ruCoins(cell.amount)}. Купим?',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    onPressed: options.contains(1) && !board.locked ? () => _decide(1) : null,
                    child: Text(fillText(texts['buy'], {'cost': '${cell.amount}'})),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: board.locked ? null : () => _decide(0),
                    child: Text(texts['skip']),
                  ),
                ),
              ]),
            ],
          ),
        ),
      );
    }
    if (run.pending && cell.kind == BoardCellKind.piggy) {
      final options = run.options();
      final index = options.indexOf(piggyAmount);
      return PopIn(
        key: ValueKey('piggy-${run.turn}'),
        motion: board.motion,
        child: FinniCard(
          color: FinniColors.lavender,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(children: [
                Text('🐷', style: TextStyle(fontSize: 40)),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Копилка! Сколько отложим?',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                IconButton.filledTonal(
                  tooltip: 'Меньше',
                  onPressed: index > 0
                      ? () => setState(() => piggyAmount = options[index - 1])
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                Expanded(child: Center(child: CoinAmount(piggyAmount))),
                IconButton.filledTonal(
                  tooltip: 'Больше',
                  onPressed: index >= 0 && index < options.length - 1
                      ? () => setState(() => piggyAmount = options[index + 1])
                      : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ]),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: board.locked ? null : () => _decide(piggyAmount),
                child: Text(piggyAmount == 0
                    ? texts['keep']
                    : fillText(texts['save'], {'amount': '$piggyAmount'})),
              ),
            ],
          ),
        ),
      );
    }
    final text = event;
    if (text == null) {
      return SoftNotice(
        icon: Icons.casino_outlined,
        text: run.turn == 0 ? board.variant.hint : 'Бросай кубик — что там дальше?',
        color: FinniColors.paper,
      );
    }
    return PopIn(
      key: ValueKey('event-${run.turn}'),
      motion: board.motion,
      child: FinniCard(
        color: cell.kind == BoardCellKind.income ? FinniColors.mint : FinniColors.sky,
        child: Row(children: [
          EmojiBadge(cell.iconId, size: 48, color: FinniColors.paper),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}

class StallGame extends StatefulWidget {
  const StallGame({super.key, required this.board, required this.payload});

  final BoardContext board;
  final StallPayload payload;

  @override
  State<StallGame> createState() => _StallGameState();
}

class _StallGameState extends State<StallGame> {
  int day = 0;
  late int coins = widget.payload.startCoins;

  @override
  void initState() {
    super.initState();
    widget.board.onSituation?.call(() => StallSituation(
          day: day,
          coins: coins,
          portions: portions,
          price: price,
          dayShown: shown != null,
        ));
  }

  final List<StallChoice> choices = [];
  final List<StallDayResult> results = [];
  int portions = 0;
  late int price = widget.payload.prices.first;
  StallDayResult? shown;
  bool submitted = false;

  StallPayload get payload => widget.payload;
  BoardContext get board => widget.board;
  TextGroup get texts => board.texts.stall;

  void _open() {
    final choice = StallChoice(portions: portions, price: price);
    final result = payload.playDay(day, coins, choice);
    setState(() {
      choices.add(choice);
      results.add(result);
      shown = result;
      coins = result.coinsAfter;
    });
    if (result.profit > 0) {
      board.sound?.call('round_win');
      Celebration.show(context, motion: board.motion, emoji: '🍦');
    }
  }

  void _next() {
    if (day + 1 >= payload.days.length) {
      if (!submitted) {
        setState(() => submitted = true);
        board.onSubmit(StallAnswer([...choices]));
      }
      return;
    }
    setState(() {
      day++;
      shown = null;
      portions = 0;
    });
  }

  void _restart() {
    board.sound?.call('retry');
    setState(() {
      day = 0;
      coins = payload.startCoins;
      choices.clear();
      results.clear();
      shown = null;
      portions = 0;
      price = payload.prices.first;
      submitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = payload.days[day];
    final result = shown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hud(children: [
          _HudChip(
              emoji: '💰',
              text: fillText(texts['coins'], {'coins': '$coins'}),
              color: FinniColors.honey),
          _HudChip(
              emoji: '📅',
              text: fillText(texts['day'], {'n': '${day + 1}', 'total': '${payload.days.length}'}),
              color: FinniColors.sky),
        ]),
        const SizedBox(height: 10),
        CoachTarget(
          id: 'stall.goal',
          child: FinniCard(
            color: FinniColors.paper,
            padding: 12,
            child: _GoalMeter(
              value: coins,
              target: payload.target,
              labels: [fillText(texts['goal'], {'target': '${payload.target}'})],
            ),
          ),
        ),
        const SizedBox(height: 12),
        CoachTarget(
          id: 'stall.weather',
          child: PopIn(
          key: ValueKey('weather-$day'),
          motion: board.motion,
          child: FinniCard(
            color: FinniColors.sky,
            child: Row(children: [
              Text(kEmoji[current.iconId] ?? '🌤️',
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(fontSize: 52)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(current.label,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    Text(current.forecast),
                  ],
                ),
              ),
            ]),
          ),
        ),
        ),
        const SizedBox(height: 12),
        CoachTarget(
          id: 'stall.planner',
          child: result == null ? _planner() : _resultCard(result),
        ),
      ],
    );
  }

  Widget _planner() {
    final options = payload.portionOptions(coins);
    final index = options.indexOf(portions);
    return FinniCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            IconButton.filledTonal(
              tooltip: 'Меньше порций',
              onPressed: index > 0 && !board.locked
                  ? () => setState(() => portions = options[index - 1])
                  : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            Expanded(
              child: Column(children: [
                Text(fillText(texts['portions'], {'portions': '$portions'}),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                Text(fillText(texts['spent'], {'spent': '${portions * payload.costPerPortion}'}),
                    style: const TextStyle(color: FinniColors.muted)),
              ]),
            ),
            IconButton.filledTonal(
              tooltip: 'Больше порций',
              onPressed: index >= 0 && index < options.length - 1 && !board.locked
                  ? () => setState(() => portions = options[index + 1])
                  : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 2,
            runSpacing: 2,
            children: [
              for (var i = 0; i < portions; i++)
                PopIn(
                  key: ValueKey('portion-$i'),
                  motion: board.motion,
                  child: const Text('🍦',
                      textScaler: TextScaler.noScaling, style: TextStyle(fontSize: 22)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(texts['price'], style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final option in payload.prices)
                ChoiceChip(
                  label: CoinAmount(option, size: 18),
                  selected: price == option,
                  onSelected: board.locked ? null : (_) => setState(() => price = option),
                  showCheckmark: false,
                  selectedColor: FinniColors.honey,
                  backgroundColor: FinniColors.paper,
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: board.locked ? null : _open,
            icon: const Icon(Icons.storefront_outlined),
            label: Text(texts['open']),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(StallDayResult result) {
    const faces = ['🐻', '🐰', '🐱', '🦔', '🐸', '🐼', '🦉', '🐶'];
    final last = day + 1 >= payload.days.length;
    return FinniCard(
      color: FinniColors.mint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 0; i < result.sold; i++)
                PopIn(
                  key: ValueKey('buyer-$day-$i'),
                  motion: board.motion,
                  delay: i * 60,
                  child: Text('${faces[i % faces.length]}🍦',
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(fontSize: 22)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            fillText(texts['dayResult'], {
              'n': '${result.day}',
              'sold': '${result.sold}',
              'portions': '${result.choice.portions}',
              'revenue': '${result.revenue}',
            }),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          if (result.leftover > 0)
            Text(fillText(texts['leftover'], {'leftover': '${result.leftover}'})),
          if (result.missed > 0)
            Text(fillText(texts['missed'], {'missed': '${result.missed}'})),
          const SizedBox(height: 6),
          Row(children: [
            CoinAmount(result.revenue, prefix: '+', size: 18),
            const SizedBox(width: 12),
            Text('−${result.spent}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          if (!submitted)
            FilledButton.icon(
              onPressed: board.locked ? null : _next,
              icon: Icon(last ? Icons.flag_outlined : Icons.arrow_forward_rounded),
              label: Text(last ? 'Подвести итог' : texts['next']),
            )
          else if (!board.locked)
            OutlinedButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.replay_rounded),
              label: Text(texts['again']),
            ),
        ],
      ),
    );
  }
}

class CashierGame extends StatefulWidget {
  const CashierGame({super.key, required this.board, required this.payload});

  final BoardContext board;
  final CashierPayload payload;

  @override
  State<CashierGame> createState() => _CashierGameState();
}

class _CashierGameState extends State<CashierGame> {
  int index = 0;
  final List<Map<int, int>> changes = [];
  final List<int> tray = [];
  bool? lastRight;
  bool submitted = false;

  CashierPayload get payload => widget.payload;
  BoardContext get board => widget.board;
  TextGroup get texts => board.texts.cashier;

  int get given => tray.fold(0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    widget.board.onSituation?.call(() => CashierSituation(
          customer: index,
          given: given,
          answered: lastRight != null,
        ));
  }

  void _give() {
    final counts = <int, int>{};
    for (final coin in tray) {
      counts.update(coin, (n) => n + 1, ifAbsent: () => 1);
    }
    final customer = payload.customers[index];
    final right = given == customer.change;
    setState(() {
      changes.add(counts);
      lastRight = right;
    });
    board.sound?.call(right ? 'round_win' : 'miss');
    if (right) Celebration.show(context, motion: board.motion, emoji: '😊');
  }

  void _next() {
    if (index + 1 >= payload.customers.length) {
      if (!submitted) {
        setState(() => submitted = true);
        board.onSubmit(CashierAnswer([...changes]));
      }
      return;
    }
    setState(() {
      index++;
      tray.clear();
      lastRight = null;
    });
  }

  void _restart() {
    board.sound?.call('retry');
    setState(() {
      index = 0;
      changes.clear();
      tray.clear();
      lastRight = null;
      submitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final customer = payload.customers[index];
    final answered = lastRight != null;
    final denominations = [...payload.denominations]..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hud(children: [
          _HudChip(
              emoji: '🧾',
              text: fillText(texts['customer'],
                  {'n': '${index + 1}', 'total': '${payload.customers.length}'}),
              color: FinniColors.sky),
        ]),
        const SizedBox(height: 12),
        CoachTarget(
          id: 'cashier.customer',
          child: PopIn(
          key: ValueKey('customer-$index-${changes.length}'),
          motion: board.motion,
          child: FinniCard(
            color: answered
                ? (lastRight! ? FinniColors.mint : FinniColors.lavender)
                : FinniColors.paper,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Text(kEmoji[customer.iconId] ?? '🐾',
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(fontSize: 56)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customer.name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        Text(
                          answered
                              ? (lastRight!
                                  ? texts['right']
                                  : fillText(texts['wrong'], {'change': '${customer.change}'}))
                              : fillText(texts['paid'], {'paid': '${customer.paid}'}),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                for (final item in customer.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      EmojiBadge(item.iconId, size: 36),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(item.label,
                              style: const TextStyle(fontWeight: FontWeight.w700))),
                      CoinAmount(item.price, size: 16),
                    ]),
                  ),
                const Divider(),
                Text(
                  payload.showTotal || answered
                      ? fillText(texts['total'], {'total': '${customer.total}'})
                      : texts['askTotal'],
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                TagPill(
                  icon: Icons.payments_outlined,
                  label: fillText(texts['paid'], {'paid': '${customer.paid}'}),
                  color: FinniColors.honey,
                ),
              ],
            ),
          ),
        ),
        ),
        const SizedBox(height: 12),
        CoachTarget(
          id: 'cashier.tray',
          child: FinniCard(
          color: const Color(0xFFF3E3C4),
          child: Column(
            children: [
              Text(fillText(texts['change'], {'given': '$given'}),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              if (tray.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('Нажимай на монеты внизу',
                      style: TextStyle(color: FinniColors.muted)),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final (i, coin) in tray.indexed)
                      PopIn(
                        key: ValueKey('tray-$index-$i-$coin'),
                        motion: board.motion,
                        child: Squish(
                          enabled: !answered && !board.locked,
                          onTap: () => setState(() => tray.removeAt(i)),
                          child: _CoinDisc(value: coin, size: 44),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        ),
        const SizedBox(height: 12),
        if (!answered)
          CoachTarget(
            id: 'cashier.coins',
            child: FinniCard(
            color: FinniColors.lavender,
            child: Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final value in denominations)
                  Semantics(
                    button: true,
                    label: 'Монета $value',
                    excludeSemantics: true,
                    child: Squish(
                      enabled: !board.locked,
                      onTap: () => setState(() => tray.add(value)),
                      child: _CoinDisc(value: value, size: 56),
                    ),
                  ),
              ],
            ),
          ),
          ),
        const SizedBox(height: 12),
        if (!answered)
          FilledButton.icon(
            onPressed: tray.isEmpty || board.locked ? null : _give,
            icon: const Icon(Icons.front_hand_outlined),
            label: Text(texts['give']),
          )
        else if (!submitted)
          FilledButton.icon(
            onPressed: board.locked ? null : _next,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(index + 1 >= payload.customers.length
                ? 'Закрыть смену'
                : 'Следующий покупатель'),
          )
        else if (!board.locked)
          OutlinedButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.replay_rounded),
            label: Text(texts['again']),
          ),
      ],
    );
  }
}

class _Sticker extends StatefulWidget {
  const _Sticker({required this.text, required this.motion});

  final String text;
  final bool motion;

  @override
  State<_Sticker> createState() => _StickerState();
}

class _StickerState extends State<_Sticker> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  void _sync() {
    if (motionAllowed(context, widget.motion)) {
      if (!controller.isAnimating) controller.repeat(reverse: true);
    } else {
      controller.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _Sticker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
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
          angle: -.08 + controller.value * .06,
          child: Transform.scale(scale: 1 + controller.value * .05, child: child),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD34D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FinniColors.paper, width: 2),
            boxShadow: const [
              BoxShadow(color: FinniColors.shadow, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: Text(
            widget.text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
        ),
      );
}

class PriceTagGame extends StatefulWidget {
  const PriceTagGame({super.key, required this.board, required this.payload});

  final BoardContext board;
  final PriceTagPayload payload;

  @override
  State<PriceTagGame> createState() => _PriceTagGameState();
}

class _PriceTagGameState extends State<PriceTagGame> {
  int index = 0;
  final List<String> chosen = [];
  String? pick;
  bool submitted = false;

  PriceTagPayload get payload => widget.payload;
  BoardContext get board => widget.board;
  TextGroup get texts => board.texts.pricetag;

  @override
  void initState() {
    super.initState();
    widget.board.onSituation
        ?.call(() => PriceTagSituation(round: index, picked: pick != null));
  }

  void _choose(PriceOffer offer) {
    if (pick != null || board.locked) return;
    final round = payload.rounds[index];
    setState(() {
      pick = offer.id;
      chosen.add(offer.id);
    });
    board.sound?.call(offer.id == round.best.id ? 'round_win' : 'miss');
    if (offer.id == round.best.id) {
      Celebration.show(context, motion: board.motion, emoji: '🔍');
    }
  }

  void _next() {
    if (index + 1 >= payload.rounds.length) {
      if (!submitted) {
        setState(() => submitted = true);
        board.onSubmit(PriceTagAnswer([...chosen]));
      }
      return;
    }
    setState(() {
      index++;
      pick = null;
    });
  }

  void _restart() {
    board.sound?.call('retry');
    setState(() {
      index = 0;
      chosen.clear();
      pick = null;
      submitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final round = payload.rounds[index];
    final picked = pick == null ? null : round.offer(pick!);
    final best = round.best;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hud(children: [
          _HudChip(
            emoji: '🔍',
            text: fillText(texts['round'],
                {'n': '${index + 1}', 'total': '${payload.rounds.length}'}),
            color: FinniColors.sky,
          ),
        ]),
        const SizedBox(height: 12),
        CoachTarget(
          id: 'pricetag.need',
          child: PopIn(
          key: ValueKey('need-$index'),
          motion: board.motion,
          child: FinniCard(
            color: FinniColors.honey,
            child: Row(children: [
              const Text('🎯', style: TextStyle(fontSize: 34)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(round.need,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              ),
            ]),
          ),
        ),
        ),
        const SizedBox(height: 8),
        Text(texts['pick'], style: const TextStyle(color: FinniColors.muted)),
        const SizedBox(height: 10),
        CoachTarget(
          id: 'pricetag.offers',
          child: LayoutBuilder(builder: (context, constraints) {
          final columns = MediaQuery.textScalerOf(context).scale(16) > 22 ? 1 : 2;
          final width = ((constraints.maxWidth - (columns - 1) * 10) / columns).clamp(0.0, double.infinity);
          return EqualGrid(
            columns: columns,
            spacing: 10,
            runSpacing: 14,
            children: [
              for (final (i, offer) in round.offers.indexed)
                SizedBox(
                  width: width,
                  child: PopIn(
                    key: ValueKey('offer-$index-${offer.id}'),
                    motion: board.motion,
                    delay: i * 90,
                    child: _tag(offer, picked, best),
                  ),
                ),
            ],
          );
        }),
        ),
        const SizedBox(height: 12),
        if (picked != null) ...[
          PopIn(
            key: ValueKey('verdict-$index'),
            motion: board.motion,
            child: FinniCard(
              color: picked.id == best.id ? FinniColors.mint : FinniColors.lavender,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    picked.id == best.id ? '🎉 ${texts['best']}' : '🤔 ${texts['tricky']}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(picked.why, style: const TextStyle(fontSize: 16)),
                  if (picked.id != best.id) ...[
                    const SizedBox(height: 6),
                    Text('✓ ${best.label}: ${best.why}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!submitted)
            FilledButton.icon(
              onPressed: board.locked ? null : _next,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(index + 1 >= payload.rounds.length
                  ? texts['finish']
                  : texts['next']),
            )
          else if (!board.locked)
            OutlinedButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.replay_rounded),
              label: Text(texts['again']),
            ),
        ],
      ],
    );
  }

  Widget _tag(PriceOffer offer, PriceOffer? picked, PriceOffer best) {
    final revealed = picked != null;
    final isPicked = picked?.id == offer.id;
    final isBest = offer.id == best.id;
    final color = !revealed
        ? FinniColors.paper
        : isBest
            ? FinniColors.mint
            : isPicked
                ? FinniColors.lavender
                : FinniColors.paper;
    final tag = offer.tag;
    return Semantics(
      button: !revealed,
      label: '${offer.label}. ${offer.detail}',
      excludeSemantics: true,
      child: Squish(
        enabled: !revealed && !board.locked,
        onTap: () => _choose(offer),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(22),
                ),
                border: Border.all(
                  color: isPicked ? FinniColors.primary : FinniColors.line,
                  width: isPicked ? 3 : 1.5,
                ),
                boxShadow: const [
                  BoxShadow(color: FinniColors.shadow, blurRadius: 8, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: FinniColors.background,
                        shape: BoxShape.circle,
                        border: Border.all(color: FinniColors.line),
                      ),
                    ),
                    const Spacer(),
                    EmojiBadge(offer.iconId, size: 48),
                  ]),
                  const SizedBox(height: 8),
                  Text(offer.label,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.search_rounded, size: 16, color: FinniColors.muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(offer.detail,
                            style: const TextStyle(fontSize: 14, color: FinniColors.muted)),
                      ),
                    ],
                  ),
                  if (revealed) ...[
                    const SizedBox(height: 6),
                    Text(fillText(texts['total'], {'pay': '${offer.pay}'}),
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                  ],
                ],
              ),
            ),
            if (tag != null)
              Positioned(
                top: -12,
                left: 8,
                child: _Sticker(text: tag, motion: board.motion && !revealed),
              ),
            if (revealed && isBest)
              const Positioned(right: -6, top: -8, child: _Mark(right: true)),
          ],
        ),
      ),
    );
  }
}
