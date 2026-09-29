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
            ? const Center(child: GameText('✨', style: TextStyle(fontSize: 26)))
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
                    child: GameText('$saved из $target',
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
            GameText(
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
                        GameText(label,
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
                child: GameText(
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
                child: GameText(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color))),
            const SizedBox(width: 7),
            GameText('$value',
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
            Expanded(child: GameText(text)),
          ],
        ),
      );
}

class _PlanLeft extends StatelessWidget {
  const _PlanLeft({required this.state});
  final GameController state;

  Widget _row(String emoji, String label, int left, int planned, Color color) {
    final shown = left < 0 ? 0 : left;
    final spent =
        planned <= 0 ? 0.0 : ((planned - left) / planned).clamp(0.0, 1.0);
    return Semantics(
      label: planned <= 0
          ? '$label: не планировали'
          : '$label: осталось $shown из $planned',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: GameText('$emoji $label',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              GameText(planned <= 0 ? 'не планировали' : 'ещё $shown из $planned',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: FinniColors.muted)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: spent,
              minHeight: 9,
              color: color,
              backgroundColor: FinniColors.line,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final full = state.plan.plan;
    final mandatory = state.planLeft(PlanDirection.mandatory);
    final optional = state.planLeft(PlanDirection.optional);
    final savings = state.planLeft(PlanDirection.savings);
    return _Panel(
      padding: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row('🍲', 'Нужное', mandatory, full.mandatory, FinniColors.primary),
          const SizedBox(height: 10),
          _row('🎁', 'Желаемое', optional, full.optional, FinniColors.purple),
          const SizedBox(height: 10),
          GameText(
            savings > 0
                ? '🐷 В копилку отложить ещё $savings ${ruCoins(savings)}'
                : '🐷 В копилку отложено по плану',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: FinniColors.muted),
          ),
          if (optional < 0) ...[
            const SizedBox(height: 6),
            GameText(
                'На желаемое потрачено на ${-optional} больше плана — сегодня в копилку попадёт меньше.',
                style: const TextStyle(fontSize: 16, color: FinniColors.muted)),
          ],
        ],
      ),
    );
  }
}

const List<(PetStat, String, GameIconKind, Color)> _statRows = [
  (PetStat.satiety, 'Сытость', GameIconKind.food, FinniColors.gold),
  (PetStat.care, 'Уход', GameIconKind.care, FinniColors.blue),
  (PetStat.mood, 'Радость', GameIconKind.joy, FinniColors.purple),
  (PetStat.cozy, 'Уют', GameIconKind.cozy, FinniColors.primary),
];

class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.low = false,
    this.after,
  });
  final String label;
  final int value;
  final GameIconKind icon;
  final Color color;
  final bool low;
  final int? after;

  double _share(int v) => (v / PetState.cap).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final tint = low ? FinniColors.alert : FinniColors.ink;
    final next = after;
    return Semantics(
      label: next == null
          ? '$label: $value из ${PetState.cap}${low ? ', хочется' : ''}'
          : '$label: было $value, станет $next',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GameIcon(icon, size: 20),
              const SizedBox(width: 5),
              Expanded(
                child: GameText(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: tint)),
              ),
              GameText(next == null ? '$value' : '$value → $next',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900, color: tint)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: color.withValues(alpha: .15)),
                  if (next != null)
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _share(next),
                      child: ColoredBox(color: color.withValues(alpha: .4)),
                    ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _share(value),
                    child: ColoredBox(color: color),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopPet extends StatelessWidget {
  const _ShopPet({required this.state});
  final GameController state;

  @override
  Widget build(BuildContext context) {
    final stats = state.stats;
    final rules = state.content.economy.pet;
    return _Panel(
      padding: 12,
      child: Row(
        children: [
          ExcludeSemantics(
            child: SizedBox(
              width: 64,
              height: 72,
              child: MoniScene(
                appearance: state.appearance,
                stage: state.stage,
                outfit: state.outfit,
                motion: false,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              final columns = c.maxWidth >= 250 &&
                      MediaQuery.textScalerOf(context).scale(16) <= 20
                  ? 2
                  : 1;
              final width = (c.maxWidth - (columns - 1) * 14) / columns;
              return Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  for (final (stat, label, icon, color) in _statRows)
                    SizedBox(
                      width: width,
                      child: _StatBar(
                        label: label,
                        value: stats.of(stat),
                        icon: icon,
                        color: color,
                        low: rules.isLow(stat, stats.of(stat)),
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StatPreview extends StatelessWidget {
  const _StatPreview({required this.state, required this.item});
  final GameController state;
  final ShopItem item;

  @override
  Widget build(BuildContext context) {
    final stats = state.stats;
    return _Panel(
      padding: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, effect) in item.effects.indexed)
            for (final (stat, label, icon, color) in _statRows)
              if (stat == effect.stat)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                  child: _StatBar(
                    label: label,
                    value: stats.of(stat),
                    after: (stats.of(stat) + effect.delta)
                        .clamp(petStatFloor(stat), petStatCap(stat) ?? 1 << 20),
                    icon: icon,
                    color: color,
                  ),
                ),
        ],
      ),
    );
  }
}

class _NeedCard extends StatelessWidget {
  const _NeedCard(
      {required this.state, required this.need, required this.onBuy});
  final GameController state;
  final PetNeed need;
  final void Function(ShopItem item) onBuy;

  @override
  Widget build(BuildContext context) {
    final bought = state.boughtFor(need);
    final options = state.needOptions(need);
    final occasion = need.occasion;
    final color = bought != null
        ? FinniColors.mint
        : occasion == null
            ? FinniColors.paper
            : FinniColors.sky;
    final String note;
    if (bought != null) {
      note = '✓ ${bought.title}';
    } else if (occasion != null) {
      note = occasion.hint;
    } else {
      note = options.length > 1 ? 'выбери одно' : '';
    }
    return _Panel(
      color: color,
      padding: 12,
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: GameText(
                  '${need.emoji.isEmpty ? '' : '${need.emoji} '}${state.needTitle(need)}',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              if (note.isNotEmpty)
                Flexible(
                  child: GameText(note,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: bought != null
                              ? FinniColors.primary
                              : FinniColors.muted)),
                ),
            ],
          ),
          if (bought == null && options.isNotEmpty) ...[
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, c) {
              const gap = 8.0;
              final scale = MediaQuery.textScalerOf(context);
              var columns = 3;
              while (columns > 1 &&
                  (c.maxWidth - (columns - 1) * gap) / columns <
                      scale.scale(96)) {
                columns--;
              }
              final width = (c.maxWidth - (columns - 1) * gap) / columns;
              final height = 16 +
                  scale.scale(16) * 1.3 +
                  6 +
                  48 +
                  4 +
                  scale.scale(16) * 1.1 * 2 +
                  scale.scale(16) * 1.25 +
                  2 +
                  scale.scale(17) * 1.25 +
                  6;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final (i, item) in options.indexed)
                    SizedBox(
                      width: width,
                      height: height,
                      child: _NeedOption(
                        state: state,
                        item: item,
                        best: i == 0 && options.length > 1,
                        onTap: () => onBuy(item),
                      ),
                    ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _NeedOption extends StatelessWidget {
  const _NeedOption(
      {required this.state,
      required this.item,
      required this.best,
      required this.onTap});
  final GameController state;
  final ShopItem item;
  final bool best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final effect = item.effects.isEmpty ? null : item.effects.first;
    final gain = effect == null ? '' : '+${effect.delta}';
    return Semantics(
      button: true,
      label:
          '${item.title}, ${item.price} ${ruCoins(item.price)}${gain.isEmpty ? '' : ', $gain'}${best ? ', дешевле всего' : ''}',
      excludeSemantics: true,
      child: Squish(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          decoration: BoxDecoration(
            color: FinniColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: best ? FinniColors.gold : FinniColors.line,
                width: best ? 2 : 1.5),
          ),
          child: Column(
            children: [
              Opacity(
                opacity: best ? 1 : 0,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(
                      color: FinniColors.honey,
                      borderRadius: BorderRadius.circular(10)),
                  child: const GameText('выгодно',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: FinniColors.honeyInk)),
                ),
              ),
              ItemArt(item.id, size: 48, background: false),
              const SizedBox(height: 4),
              Expanded(
                child: Center(
                  child: GameText(item.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.1)),
                ),
              ),
              if (effect != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final (stat, _, icon, _) in _statRows)
                      if (stat == effect.stat) GameIcon(icon, size: 16),
                    const SizedBox(width: 3),
                    GameText(gain,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: FinniColors.muted)),
                  ],
                ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CoinIcon(size: 18),
                  const SizedBox(width: 4),
                  GameText('${item.price}',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w900)),
                ],
              ),
            ],
          ),
        ),
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
                      GameText(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      GameText(
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
                  onPressed: !state.plan.isConfirmed && value > 0
                      ? () => state.changePlan(direction, -5)
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                Expanded(child: Center(child: _Coins(value))),
                IconButton.filledTonal(
                  tooltip: 'Увеличить: $title',
                  onPressed:
                      !state.plan.isConfirmed && state.plan.remainder > 0
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
  static const _ids = [
    'nav.home',
    'nav.plan',
    'nav.shop',
    'nav.games',
    'nav.more'
  ];

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
                  GameText(
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
              child: GameText(title,
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
                    child: GameText(shift.label,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  GameText('${shift.before} → ${shift.after}',
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

class _HungryCard extends StatelessWidget {
  const _HungryCard({required this.state, required this.onShop});

  final GameController state;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: '${state.petName}: ${state.hungerText}',
        child: _Panel(
          color: FinniColors.peach,
          padding: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: Row(
                  children: [
                    const GameText('🍲', style: TextStyle(fontSize: 34)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GameText(state.hungerText,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: FinniColors.alert)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: FinniColors.alert,
                  foregroundColor: FinniColors.paper,
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: onShop,
                icon: const Icon(Icons.restaurant_outlined),
                label: const GameText('Выбрать еду'),
              ),
            ],
          ),
        ),
      );
}

class _PocketCard extends StatelessWidget {
  const _PocketCard({required this.state, required this.onDone});

  final GameController state;
  final ValueChanged<String> onDone;

  @override
  Widget build(BuildContext context) {
    final coins = state.pocket;
    if (coins <= 0) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: 'Новые монеты: $coins. Заработаны после плана',
      child: _Panel(
        color: FinniColors.honey,
        padding: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const ExcludeSemantics(
                    child: GameText('👛', style: TextStyle(fontSize: 34))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GameText('Новые монеты',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: FinniColors.gold)),
                      GameText('$coins',
                          style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: FinniColors.honeyInk,
                              height: 1.1)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const GameText(
              'Ты заработал их после плана. Отложи в копилку — или они сами добавятся к плану завтра утром.',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: FinniColors.honeyInk),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: FinniColors.purple,
                foregroundColor: FinniColors.paper,
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () {
                if (state.savePocket()) {
                  Celebration.show(context, motion: state.motion, emoji: '🐷');
                  onDone(
                      'Отложили $coins ${ruCoins(coins)} в копилку. Мечта ближе!');
                } else {
                  onDone(
                      'Сначала выбери мечту — нажми на неё на главном экране.');
                }
              },
              icon: const Icon(Icons.savings_outlined),
              label: GameText('В копилку $coins'),
            ),
            const SizedBox(height: 8),
            GameText(
              '📅 Если не трогать — завтра утром +$coins к плану',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: FinniColors.gold),
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
    final needs = state.todayNeeds;
    final total = state.mandatoryCost;
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
                child: GameText('Сегодня нужно — обычно $total ${ruCoins(total)}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const GameText('Можно выбрать подешевле и сэкономить.',
              style: TextStyle(fontSize: 16, color: FinniColors.muted)),
          const SizedBox(height: 4),
          for (final need in needs)
            if (state.content.shop.byId(need.itemId) case final primary?)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    ItemArt((state.boughtFor(need) ?? primary).id, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GameText(need.occasion == null
                          ? (need.title.isEmpty ? primary.title : need.title)
                          : '${need.title} — ${state.needTitle(need)}'),
                    ),
                    GameText(
                        state.needOptions(need).length > 1
                            ? 'от ${state.needOptions(need).first.price}'
                            : '${primary.price}',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Icon(
                      state.boughtFor(need) == null
                          ? Icons.radio_button_unchecked_rounded
                          : Icons.check_circle_rounded,
                      color: FinniColors.primary,
                      semanticLabel: state.boughtFor(need) == null
                          ? 'ещё не куплено'
                          : 'куплено',
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
