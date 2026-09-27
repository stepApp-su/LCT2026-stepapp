part of '../screens/game_shell.dart';

class _GoalIcon extends StatelessWidget {
  const _GoalIcon(this.id);
  final String? id;
  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: FinniColors.paper.withValues(alpha: .45),
          borderRadius: BorderRadius.circular(16),
        ),
        child: id == null
            ? const Center(child: Text('✨', style: TextStyle(fontSize: 26)))
            : ItemArt(id!, size: 40, background: false),
      );
}

class _GoalProgress extends StatelessWidget {
  const _GoalProgress({required this.saved, required this.target});
  final int saved, target;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(alignment: Alignment.center, children: [
          Positioned.fill(
              child: LinearProgressIndicator(
            value: target > 0 ? (saved / target).clamp(0.0, 1.0) : 0,
            color: const Color(0xFFCCB8E8),
            backgroundColor: FinniColors.paper,
            borderRadius: BorderRadius.circular(12),
          )),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(
                    child: Text('$saved из $target',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: FinniColors.ink))),
                const SizedBox(width: 4),
                const CoinIcon(size: 18),
              ])),
        ]),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.color = FinniColors.paper,
    this.padding = 16,
    this.radius = 24,
  });
  final Widget child;
  final Color color;
  final double padding, radius;
  @override
  Widget build(BuildContext context) => Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: FinniColors.line.withValues(alpha: .6)),
        ),
        child: Padding(padding: EdgeInsets.all(padding), child: child),
      );
}

class _Coins extends StatelessWidget {
  const _Coins(this.amount);
  final int amount;
  @override
  Widget build(BuildContext context) => Semantics(
        label: '$amount монет',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinIcon(),
            const SizedBox(width: 6),
            Text(
              '$amount',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: FinniColors.ink,
              ),
            ),
          ],
        ),
      );
}

class _ResourceChip extends StatelessWidget {
  const _ResourceChip(
      {required this.label,
      required this.color,
      this.icon,
      this.coin = false,
      this.semantics,
      this.onTap});
  final String label;
  final String? semantics;
  final Color color;
  final IconData? icon;
  final bool coin;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        label: semantics ?? label,
        button: onTap != null,
        excludeSemantics: true,
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Center(
                        child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      children: [
                        if (coin)
                          const CoinIcon(size: 22)
                        else if (icon == Icons.wb_sunny_outlined)
                          const GameIcon(GameIconKind.sun)
                        else if (icon == Icons.savings_outlined)
                          const GameIcon(GameIconKind.pig)
                        else
                          Icon(icon, size: 22),
                        Text(label,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                      ],
                    ))),
              )),
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: FinniColors.ink),
            const SizedBox(width: 5),
            Flexible(
                child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            )),
          ],
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  final String label;
  final int value;
  final GameIconKind icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(
        label: '$label: $value из 100',
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
              color: Color.alphaBlend(
                  color.withValues(alpha: .10), FinniColors.paper),
              borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            GameIcon(icon, size: 25),
            const SizedBox(width: 7),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color))),
            const SizedBox(width: 7),
            Text('$value',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => _Panel(
        color: FinniColors.honey.withValues(alpha: .4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: FinniColors.gold),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _PlanLeft extends StatelessWidget {
  const _PlanLeft({required this.state});
  final GameController state;

  @override
  Widget build(BuildContext context) {
    final mandatory = state.planLeft(PlanDirection.mandatory);
    final optional = state.planLeft(PlanDirection.optional);
    final savings = state.planLeft(PlanDirection.savings);
    int shown(int value) => value < 0 ? 0 : value;
    return _Panel(
      padding: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Осталось по плану',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                  icon: Icons.restaurant_outlined,
                  label: 'Нужное: ${shown(mandatory)}',
                  color: FinniColors.mint),
              _Pill(
                  icon: Icons.celebration_outlined,
                  label: 'Желаемое: ${shown(optional)}',
                  color: FinniColors.sky),
              _Pill(
                  icon: Icons.savings_outlined,
                  label: savings > 0 ? 'Отложить: $savings' : 'Копилка: готово',
                  color: FinniColors.lavender),
            ],
          ),
          if (optional < 0) ...[
            const SizedBox(height: 8),
            Text(
                'На желаемое потрачено на ${-optional} больше плана — сегодня в копилку попадёт меньше.',
                style: const TextStyle(fontSize: 16, color: FinniColors.muted)),
          ],
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.value,
    required this.direction,
    required this.state,
  });
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final int value;
  final PlanDirection direction;
  final GameController state;
  int get extra => state.planExtra[direction] ?? 0;

  @override
  Widget build(BuildContext context) => _Panel(
        padding: 12,
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: FinniColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 16,
                          color: FinniColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Уменьшить: $title',
                  onPressed: !state.plan.isConfirmed && value >= 5
                      ? () => state.changePlan(direction, -5)
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                Expanded(child: Center(child: _Coins(value + extra))),
                IconButton.filledTonal(
                  tooltip: 'Увеличить: $title',
                  onPressed:
                      !state.plan.isConfirmed && state.plan.remainder >= 5
                          ? () => state.changePlan(direction, 5)
                          : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            if (extra > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _Pill(
                  icon: Icons.add_task_rounded,
                  label: 'Утром $value, из заработанного +$extra',
                  color: FinniColors.honey,
                ),
              ),
          ],
        ),
      );
}

class _Navigation extends StatelessWidget {
  const _Navigation({
    required this.index,
    required this.onSelect,
  });
  final int index;
  final ValueChanged<int> onSelect;
  static const _ids = ['nav.home', 'nav.plan', 'nav.shop', 'nav.games', 'nav.more'];

  @override
  Widget build(BuildContext context) => CoachTarget(
        id: 'nav',
        child: Container(
        decoration: const BoxDecoration(
          color: FinniColors.paper,
          border: Border(top: BorderSide(color: FinniColors.line)),
        ),
        padding: const EdgeInsets.fromLTRB(7, 8, 7, 10),
        child: Row(
          children: [
            nav('Дом', GameIconKind.navHome, 0),
            const SizedBox(width: 3),
            nav('План', GameIconKind.navPlan, 1),
            const SizedBox(width: 3),
            nav('Магазин', GameIconKind.navShop, 2),
            const SizedBox(width: 3),
            nav('Игры', GameIconKind.navGames, 3),
            const SizedBox(width: 3),
            nav('Ещё', GameIconKind.navMore, 4),
          ],
        ),
      ),
      );
  Widget nav(String label, GameIconKind icon, int value) => Expanded(
        flex: value == 2 ? 5 : 4,
        child: CoachTarget(
          id: _ids[value],
          child: Semantics(
          selected: index == value,
          child: TextButton(
            onPressed: () => onSelect(value),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 60),
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 1),
              backgroundColor: index == value
                  ? const Color(0xFFE7F0E1)
                  : FinniColors.transparent,
              foregroundColor:
                  index == value ? FinniColors.primary : FinniColors.muted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GameIcon(icon, size: 33),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
        ),
      );
}

class _MilestoneBar extends StatelessWidget {
  const _MilestoneBar(
      {required this.percent, required this.milestones, required this.motion});
  final int percent;
  final List<int> milestones;
  final bool motion;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Накоплено $percent процентов',
        excludeSemantics: true,
        child: SizedBox(
          height: 44,
          child: LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0,
                right: 0,
                top: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: (percent / 100).clamp(0.0, 1.0)),
                    duration: motionAllowed(context, motion)
                        ? const Duration(milliseconds: 600)
                        : Duration.zero,
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 20,
                      color: const Color(0xFFB79BE3),
                      backgroundColor: FinniColors.paper,
                    ),
                  ),
                ),
              ),
              for (final milestone in milestones)
                Positioned(
                  left: width * milestone / 100 - 16,
                  top: 0,
                  child: AnimatedScale(
                    scale: percent >= milestone ? 1.15 : .9,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      percent >= milestone
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 32,
                      color: percent >= milestone
                          ? const Color(0xFFE8A817)
                          : FinniColors.muted,
                    ),
                  ),
                ),
            ]);
          }),
        ),
      );
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.onHelp});

  final String title;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton(
              tooltip: 'Подсказка',
              onPressed: onHelp,
              icon: const Icon(Icons.help_outline_rounded),
            ),
          ],
        ),
      );
}

class _ShiftList extends StatelessWidget {
  const _ShiftList(this.shifts);

  final List<StatShift> shifts;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final shift in shifts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                      shift.delta > 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: FinniColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(shift.label,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  Text('${shift.before} → ${shift.after}',
                      style: const TextStyle(
                          fontSize: 17,
                          fontFeatures: [FontFeature.tabularFigures()])),
                  const SizedBox(width: 8),
                  _Pill(
                    icon: shift.delta > 0
                        ? Icons.add_rounded
                        : Icons.remove_rounded,
                    label: '${shift.delta.abs()}',
                    color: shift.delta > 0
                        ? FinniColors.mint
                        : FinniColors.lavender,
                  ),
                ],
              ),
            ),
        ],
      );
}

class _ExtraPlanner extends StatefulWidget {
  const _ExtraPlanner({required this.state, required this.onDone});

  final GameController state;
  final ValueChanged<String> onDone;

  @override
  State<_ExtraPlanner> createState() => _ExtraPlannerState();
}

class _ExtraPlannerState extends State<_ExtraPlanner> {
  final Map<PlanDirection, int> parts = {
    for (final d in PlanDirection.values) d: 0
  };

  int get pending => widget.state.extraPending;
  int get used => parts.values.fold(0, (a, b) => a + b);
  int get left => pending - used;

  static const Map<PlanDirection, (String, IconData)> _labels = {
    PlanDirection.mandatory: ('Обязательное', Icons.restaurant_outlined),
    PlanDirection.optional: ('Желаемое', Icons.celebration_outlined),
    PlanDirection.savings: ('Копилка', Icons.savings_outlined),
  };

  void _change(PlanDirection d, int delta) {
    final next = parts[d]! + delta;
    if (next < 0 || (delta > 0 && left < delta)) return;
    setState(() => parts[d] = next);
  }

  void _all(PlanDirection d) => setState(() {
        for (final key in parts.keys) {
          parts[key] = key == d ? pending : 0;
        }
      });

  @override
  Widget build(BuildContext context) {
    if (pending <= 0) return const SizedBox.shrink();
    return _Panel(
      color: FinniColors.honey,
      padding: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('💰', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Заработано сегодня ещё $pending ${ruCoins(pending)}. Куда направим?',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final d in PlanDirection.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(_labels[d]!.$2, color: FinniColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_labels[d]!.$1,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    tooltip: 'Меньше: ${_labels[d]!.$1}',
                    onPressed: parts[d]! > 0 ? () => _change(d, -1) : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text('${parts[d]}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                  IconButton(
                    tooltip: 'Больше: ${_labels[d]!.$1}',
                    onPressed: left > 0 ? () => _change(d, 1) : null,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in PlanDirection.values)
                ActionChip(
                  label: Text('Всё: ${_labels[d]!.$1.toLowerCase()}'),
                  onPressed: () => _all(d),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            left > 0
                ? 'Осталось разложить: $left ${ruCoins(left)}'
                : 'Всё разложено!',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: used > 0
                ? () {
                    final added = used;
                    if (widget.state.planEarned(parts)) {
                      setState(() {
                        for (final key in parts.keys) {
                          parts[key] = 0;
                        }
                      });
                      widget.onDone(
                          'Добавили в план ещё $added ${ruCoins(added)}.');
                    }
                  }
                : null,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Добавить в план'),
          ),
        ],
      ),
    );
  }
}

class _DayRecap extends StatelessWidget {
  const _DayRecap({required this.entry, required this.expanded});

  final Map<String, dynamic> entry;
  final bool expanded;

  List<String> _strings(String key) =>
      [for (final item in entry[key] as List? ?? const []) '$item'];

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final row in entry['rows'] as List? ?? const [])
        (row as List).map((cell) => '$cell').toList()
    ];
    final titles = _strings('titles');
    final changes = _strings('changes');
    final stageUp = entry['stageUp'] as String?;
    final event = entry['event'] as String?;
    return _Panel(
      padding: 4,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: FinniColors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          leading: const Icon(Icons.bedtime_outlined, color: FinniColors.purple),
          title: Text('День ${entry['day']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          subtitle: Text('Опыт: +${entry['points'] ?? 0}'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final row in rows)
              if (row.length == 3)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(row[0],
                              style: const TextStyle(fontWeight: FontWeight.w800))),
                      Text('план ${row[1]} · факт ${row[2]}'),
                    ],
                  ),
                ),
            const SizedBox(height: 6),
            Text('${entry['explain'] ?? ''}', style: const TextStyle(fontSize: 16)),
            if (event != null) ...[
              const SizedBox(height: 8),
              Text('Событие дня: $event'),
            ],
            if (stageUp != null) ...[
              const SizedBox(height: 8),
              Text('Питомец подрос: $stageUp',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
            if (titles.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Новые звания: ${titles.join(', ')}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
            for (final change in changes)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('• $change'),
              ),
          ],
        ),
      ),
    );
  }
}

class _NeedsToday extends StatelessWidget {
  const _NeedsToday({required this.state});

  final GameController state;

  @override
  Widget build(BuildContext context) {
    final unpaid = {for (final item in state.unpaidNeeds) item.id};
    final items = [
      for (final need in state.content.economy.pet.needs)
        if (state.content.shop.byId(need.itemId) case final item?) item
    ];
    final total = items.fold(0, (sum, item) => sum + item.price);
    return _Panel(
      color: FinniColors.mint,
      padding: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant_outlined, color: FinniColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Сегодня нужно — всего $total ${ruCoins(total)}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  ItemArt(item.id, size: 36),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item.title)),
                  Text('${item.price}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  Icon(
                    unpaid.contains(item.id)
                        ? Icons.radio_button_unchecked_rounded
                        : Icons.check_circle_rounded,
                    color: FinniColors.primary,
                    semanticLabel:
                        unpaid.contains(item.id) ? 'ещё не куплено' : 'куплено',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
