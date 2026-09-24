part of '../screens/game_shell.dart';

class _GoalIcon extends StatelessWidget {
  const _GoalIcon(this.id);
  final String id;
  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: FinniColors.paper.withValues(alpha: .45),
          borderRadius: BorderRadius.circular(16),
        ),
        child: GameIcon(
            switch (id) {
              'book' => GameIconKind.book,
              'telescope' => GameIconKind.telescope,
              _ => GameIconKind.scooter,
            },
            size: 40),
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

class _Progress extends StatelessWidget {
  const _Progress({required this.value, required this.color});
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: 7,
          color: color,
          backgroundColor: FinniColors.paper,
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
                Expanded(child: Center(child: _Coins(value))),
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
  @override
  Widget build(BuildContext context) => Container(
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
      );
  Widget nav(String label, GameIconKind icon, int value) => Expanded(
        flex: value == 2 ? 5 : 4,
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
      );
}
