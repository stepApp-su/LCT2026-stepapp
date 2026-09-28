part of 'game_shell.dart';

const List<(String, String, String)> _slots = [
  ('head', 'Голова', '🎩'),
  ('eyes', 'Глаза', '👓'),
  ('neck', 'Шея', '🧣'),
  ('body', 'Тело', '👕'),
  ('back', 'Спина', '🎒'),
  ('paw', 'Лапа', '🎈'),
];

const List<(double, double)> _slotPlaces = [
  (.5, .0),
  (.1, .16),
  (.9, .16),
  (.05, .52),
  (.95, .52),
  (.5, .88),
];

enum _SpotState { full, open, locked }

String _stageName(GameController s, PetStage stage) =>
    (s.content.economy.growth.texts.stageLabels[stage] ?? stage.name)
        .toLowerCase();

Widget _lockTag(GameController s, ShopItem item) =>
    item.minStage.index > s.stage.index
        ? TagChip('🔒 ${_stageName(s, item.minStage)}')
        : TagChip('🪙 ${item.price}', tone: TagTone.blue);

class _RoomPage extends StatefulWidget {
  const _RoomPage({required this.shell, required this.tab});
  final _GameShellState shell;
  final int tab;
  @override
  State<_RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<_RoomPage> {
  late int tab = widget.tab;

  GameController get s => widget.shell.s;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) s.markThingsSeen();
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          CoachTarget(
            id: 'room.tabs',
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: 0,
                    label: Text('👕 Наряды',
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                ButtonSegment(
                    value: 1,
                    label: Text('🛋️ Комната',
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
              selected: {tab},
              onSelectionChanged: (value) => setState(() => tab = value.first),
            ),
          ),
          const SizedBox(height: 12),
          Text(
              tab == 0
                  ? 'Нажми на кружок и выбери, что надеть'
                  : 'Нажми на «+» и поставь вещь на место',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: FinniColors.muted)),
          const SizedBox(height: 8),
          CoachTarget(
            id: 'room.stage',
            child: tab == 0 ? _wardrobe(context) : _room(context),
          ),
          const SizedBox(height: 12),
          CoachTarget(id: 'room.legend', child: _legend(tab == 0)),
          if (tab == 1) ...[
            const SizedBox(height: 12),
            _Panel(
              padding: 12,
              child: Row(children: [
                const GameIcon(GameIconKind.cozy, size: 24),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text('Уют',
                        style: TextStyle(fontWeight: FontWeight.w900))),
                Text('${s.stats.cozy}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
              ]),
            ),
          ],
          if (s.wishlist.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Отложенные желания',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final item
                in s.content.shop.items.where((i) => s.wishlist.contains(i.id)))
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ItemArt(item.id, size: 44),
                  title: Text(item.title),
                  trailing: TagChip('🪙 ${item.price}', tone: TagTone.blue),
                  onTap: () => widget.shell.purchase(item)),
          ],
        ],
      );

  Widget _legend(bool wardrobe) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 6,
        children: [
          for (final (state, label) in [
            (_SpotState.full, wardrobe ? 'надето' : 'стоит'),
            (_SpotState.open, wardrobe ? 'можно надеть' : 'можно поставить'),
            (_SpotState.locked, 'пока нет вещей'),
          ])
            Row(mainAxisSize: MainAxisSize.min, children: [
              _SpotBubble(state: state, size: 18),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: FinniColors.muted)),
            ]),
        ],
      );

  List<ShopItem> _slotItems(String slot) => [
        for (final item in s.content.shop.items)
          if (item.slot == slot && item.showInShop) item
      ];

  Widget _wardrobe(BuildContext context) =>
      LayoutBuilder(builder: (context, c) {
        final width = c.maxWidth;
        final height = math.min(width * 1.02, 380.0);
        const bubble = 66.0;
        return SizedBox(
          height: height,
          child: Stack(children: [
            Positioned(
              left: width * .2,
              right: width * .2,
              top: height * .12,
              bottom: height * .14,
              child: IgnorePointer(
                child: MoniScene(
                    appearance: s.appearance,
                    stage: s.stage,
                    motion: s.motion,
                    outfit: s.outfit),
              ),
            ),
            for (final (i, (slot, label, emoji)) in _slots.indexed)
              Positioned(
                left: (width - bubble) * _slotPlaces[i].$1,
                top: (height - bubble) * _slotPlaces[i].$2,
                child: _slotBubble(slot, label, emoji, bubble),
              ),
          ]),
        );
      });

  Widget _slotBubble(String slot, String label, String emoji, double size) {
    final worn = s.outfit[slot];
    final owned = _slotItems(slot).any((item) => s.owned.contains(item.id));
    final state = worn != null
        ? _SpotState.full
        : owned
            ? _SpotState.open
            : _SpotState.locked;
    return Semantics(
      button: state != _SpotState.locked,
      label:
          '$label: ${worn == null ? (owned ? 'можно надеть' : 'пока нет вещей') : s.content.shop.byId(worn)?.title ?? ''}',
      excludeSemantics: true,
      child: Squish(
        enabled: state != _SpotState.locked,
        onTap: state == _SpotState.locked
            ? null
            : () => _chooseFor(slot, label, emoji),
        child: _SpotBubble(
          state: state,
          size: size,
          label: label,
          child: worn == null ? null : RoomArt(worn, size: size * .5),
        ),
      ),
    );
  }

  void _chooseFor(String slot, String label, String emoji) {
    widget.shell.sheet(
      '$emoji $label',
      AnimatedBuilder(
        animation: s,
        builder: (context, _) {
          final worn = s.outfit[slot];
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TileGrid(children: [
                  for (final item in _slotItems(slot))
                    if (s.owned.contains(item.id))
                      _ThingTile(
                        art: RoomArt(item.id, size: 52),
                        title: item.title,
                        selected: worn == item.id,
                        onTap: () => s.equip(item.id),
                      )
                    else
                      _ThingTile(
                        art: RoomArt(item.id, size: 52),
                        title: item.title,
                        tag: _lockTag(s, item),
                      ),
                  if (worn != null)
                    _ThingTile(
                      art: const Center(
                          child: Text('🚫', style: TextStyle(fontSize: 30))),
                      title: 'Снять',
                      onTap: () => s.equip(worn),
                    ),
                ]),
                const SizedBox(height: 12),
                const _Notice(
                    icon: Icons.checkroom_outlined,
                    text: 'Надевать и снимать вещи можно бесплатно.'),
              ]);
        },
      ),
    );
  }

  Widget _room(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final width = c.maxWidth;
        final roomHeight = width / 1.25;
        final size = Size(width, roomHeight + 26);
        final pieces = widget.shell.roomPieces;
        return SizedBox(
          height: roomHeight + 26,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(child: RoomScene(state: s, pieces: pieces)),
            for (final spot in s.itemSpots)
              _spotBubble(spot, Rect.fromCenter(
                  center: RoomLayer.markerOf(spot, size), width: 36, height: 36)),
            Positioned(
              right: 8,
              top: 34,
              child: Semantics(
                button: true,
                label: 'Обои',
                excludeSemantics: true,
                child: Squish(
                  onTap: _chooseWallpaper,
                  child: const _SpotBubble(
                    state: _SpotState.full,
                    size: 44,
                    child: Text('🖌️', style: TextStyle(fontSize: 20)),
                  ),
                ),
              ),
            ),
          ]),
        );
      });

  Widget _spotBubble(RoomSpot spot, Rect rect) {
    const size = 36.0;
    final item = s.placedAt(spot);
    final state = item != null
        ? _SpotState.full
        : s.canFill(spot)
            ? _SpotState.open
            : _SpotState.locked;
    final names = s.spotItems(spot).map((i) => i.title).join(', ');
    return Positioned(
      left: rect.center.dx - size / 2,
      top: rect.center.dy - size / 2,
      child: Semantics(
        button: state != _SpotState.locked,
        label: item != null
            ? 'Стоит: ${item.title}'
            : state == _SpotState.open
                ? 'Можно поставить: $names'
                : 'Пока нечего поставить: $names',
        excludeSemantics: true,
        child: Squish(
          enabled: state != _SpotState.locked,
          onTap: state == _SpotState.locked ? null : () => _chooseForSpot(spot),
          child: _SpotBubble(
            state: state,
            size: size,
            child: item == null ? null : RoomArt(item.id, size: 22),
          ),
        ),
      ),
    );
  }

  void _chooseForSpot(RoomSpot spot) {
    final texts = s.content.rooms.texts;
    widget.shell.sheet(
      texts['chooseForSpot'] ?? 'Что поставим сюда?',
      AnimatedBuilder(
        animation: s,
        builder: (context, _) {
          final current = s.placedAt(spot);
          return _TileGrid(children: [
            for (final item in s.spotItems(spot))
              if (s.owned.contains(item.id))
                _ThingTile(
                  art: RoomArt(item.id, size: 52),
                  title: item.title,
                  selected: current?.id == item.id,
                  tag: TagChip(
                      current?.id == item.id
                          ? texts['remove'] ?? 'Убрать'
                          : texts['place'] ?? 'Поставить',
                      tone: TagTone.green),
                  onTap: () =>
                      s.place(spot, current?.id == item.id ? null : item.id),
                )
              else
                _ThingTile(
                  art: RoomArt(item.id, size: 52),
                  title: item.title,
                  tag: _lockTag(s, item),
                ),
          ]);
        },
      ),
    );
  }

  void _chooseWallpaper() {
    widget.shell.sheet(
      s.content.rooms.texts['wallpaperTitle'] ?? 'Обои',
      AnimatedBuilder(
        animation: s,
        builder: (context, _) => _TileGrid(children: [
          for (final item in s.wallpapers)
            _ThingTile(
              art: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                    width: 52,
                    height: 52,
                    child: CustomPaint(painter: WallpaperPainter(item.id))),
              ),
              title: item.title,
              selected: s.wallpaperId == item.id,
              tag: s.owned.contains(item.id) ? null : _lockTag(s, item),
              onTap: s.owned.contains(item.id)
                  ? () => s.applyWallpaper(item.id)
                  : null,
            ),
        ]),
      ),
    );
  }
}

class _SpotBubble extends StatelessWidget {
  const _SpotBubble(
      {required this.state, required this.size, this.label, this.child});
  final _SpotState state;
  final double size;
  final String? label;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final small = size < 30;
    final Widget inner = child ??
        switch (state) {
          _SpotState.open => Text('+',
              style: TextStyle(
                  fontSize: small ? 14 : size * .36,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: FinniColors.primary)),
          _SpotState.locked => small
              ? const SizedBox.shrink()
              : Icon(Icons.lock_rounded,
                  size: size * .3, color: FinniColors.muted),
          _SpotState.full => const SizedBox.shrink(),
        };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: switch (state) {
          _SpotState.full => FinniColors.mint,
          _SpotState.open => FinniColors.paper,
          _SpotState.locked => FinniColors.line,
        },
        border: Border.all(
          color: switch (state) {
            _SpotState.full => FinniColors.primary,
            _SpotState.open => FinniColors.primary.withValues(alpha: .55),
            _SpotState.locked => FinniColors.line,
          },
          width: state == _SpotState.full ? 2.5 : 2,
        ),
        boxShadow: small
            ? null
            : const [
                BoxShadow(
                    color: FinniColors.shadow,
                    blurRadius: 8,
                    offset: Offset(0, 3))
              ],
      ),
      child: label == null || small
          ? Center(child: inner)
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              inner,
              Text(label!,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: state == _SpotState.locked
                          ? FinniColors.muted
                          : FinniColors.primary)),
            ]),
    );
  }
}

class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final columns = MediaQuery.textScalerOf(context).scale(16) > 22 ? 2 : 3;
        final width = (c.maxWidth - (columns - 1) * 8) / columns;
        return EqualGrid(
            columns: columns,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final child in children)
                SizedBox(width: width, child: child),
            ]);
      });
}

class _ThingTile extends StatelessWidget {
  const _ThingTile(
      {required this.art,
      required this.title,
      this.tag,
      this.selected = false,
      this.onTap});
  final Widget art;
  final String title;
  final Widget? tag;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: onTap != null,
        selected: selected,
        label: title,
        child: Opacity(
          opacity: onTap == null ? .6 : 1,
          child: Material(
            color: selected ? FinniColors.mint : FinniColors.paper,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: selected ? FinniColors.primary : FinniColors.line,
                      width: selected ? 2.5 : 1.5),
                ),
                child: Column(children: [
                  SizedBox(height: 54, child: Center(child: art)),
                  const SizedBox(height: 4),
                  Text(title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.1)),
                  if (tag != null) ...[const SizedBox(height: 4), tag!],
                ]),
              ),
            ),
          ),
        ),
      );
}

class _RoomButton extends StatelessWidget {
  const _RoomButton({required this.news, required this.onTap, this.compact = false});
  final bool compact;
  final bool news;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Обустроить комнату',
        excludeSemantics: true,
        child: Squish(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: FinniColors.paper,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                    color: FinniColors.shadow,
                    blurRadius: 10,
                    offset: Offset(0, 3))
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (compact)
                const SizedBox(
                    width: 24, height: 32,
                    child: Center(child: Icon(Icons.weekend_outlined, size: 26,
                        color: FinniColors.primary)))
              else const Text('🛋️ Обустроить',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              if (news) ...[const SizedBox(width: 6), const _NewDot()],
            ]),
          ),
        ),
      );
}

class _NewDot extends StatelessWidget {
  const _NewDot();
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Есть новая вещь',
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: FinniColors.alert,
            shape: BoxShape.circle,
            border: Border.all(color: FinniColors.paper, width: 2),
          ),
        ),
      );
}

class _DiaryPage extends StatefulWidget {
  const _DiaryPage({required this.state});
  final GameController state;
  @override
  State<_DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<_DiaryPage> {
  late int day = widget.state.day;
  int filter = 0;

  GameController get s => widget.state;

  static const List<String> _filters = [
    'Все',
    '➕ Пришло',
    '➖ Траты',
    '🐷 Копилка'
  ];

  bool _shown(Transaction t) => switch (filter) {
        1 => t.type == TransactionType.income,
        2 => t.type == TransactionType.expense,
        3 => t.type == TransactionType.toSavings ||
            t.type == TransactionType.fromSavings,
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final all = [
      for (final t in s.wallet.journal)
        if (t.dayNumber == day) t
    ];
    int total(TransactionType type) => all
        .where((t) => t.type == type)
        .fold(0, (sum, t) => sum + t.amount);
    final saved = total(TransactionType.toSavings) -
        total(TransactionType.fromSavings);
    final recap = [
      for (final entry in s.dayHistory)
        if (entry['day'] == day) entry
    ];
    final growthDay = [
      for (final g in s.progress.growthDays)
        if (g.dayNumber == day) g
    ];
    final onPlan = growthDay.isNotEmpty &&
        growthDay.first.factors.contains(GrowthFactor.followedPlan);
    final purchases = [
      for (final t in all)
        if (t.type == TransactionType.expense) t
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      CoachTarget(
        id: 'diary.days',
        child: SizedBox(
        height: 64,
        child: ListView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          children: [
            for (var d = s.day; d >= 1; d--)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _DayChip(
                  day: d,
                  today: d == s.day,
                  selected: d == day,
                  onTap: () => setState(() => day = d),
                ),
              ),
          ],
        ),
      ),
      ),
      const SizedBox(height: 10),
      CoachTarget(
        id: 'diary.filters',
        child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (i, label) in _filters.indexed)
          ChoiceChip(
            label: Text(label),
            selected: filter == i,
            showCheckmark: false,
            onSelected: (_) => setState(() => filter = i),
            labelStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: filter == i ? FinniColors.paper : FinniColors.ink),
            selectedColor: FinniColors.primary,
            backgroundColor: FinniColors.paper,
            side: BorderSide.none,
          ),
      ]),
      ),
      const SizedBox(height: 12),
      CoachTarget(
        id: 'diary.summary',
        child: _Panel(
        padding: 12,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('День $day',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900)),
              if (day == s.day)
                const TagChip('сегодня', tone: TagTone.gold)
              else if (onPlan)
                const TagChip('по плану ✓', tone: TagTone.green),
            ],
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (i, (value, label, color, ink)) in [
              ('+${total(TransactionType.income)}', 'пришло', FinniColors.mint, FinniColors.primary),
              ('−${total(TransactionType.expense)}', 'потратили', FinniColors.peach, FinniColors.alert),
              ('${saved < 0 ? 0 : saved}', 'в копилку', FinniColors.lavender, FinniColors.purple),
            ].indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(14)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(value,
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900, color: ink)),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: FinniColors.muted)),
                  ]),
                ),
              ),
            ],
          ])),
        ]),
      ),
      ),
      const SizedBox(height: 12),
      if (all.where(_shown).isEmpty)
        const _Notice(
            icon: Icons.menu_book_outlined,
            text: 'Здесь появятся покупки, заработок и копилка этого дня.'),
      for (final (i, t) in all.reversed.where(_shown).indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: i == 0
              ? CoachTarget(
                  id: 'diary.list', child: _DiaryRow(state: s, transaction: t))
              : _DiaryRow(state: s, transaction: t),
        ),
      if ((filter == 0 || filter == 2) && purchases.isNotEmpty) ...[
        const SizedBox(height: 4),
        _DayReceipt(state: s, day: day, items: purchases),
        const SizedBox(height: 8),
      ],
      if (recap.isNotEmpty) ...[
        const SizedBox(height: 4),
        _Notice(
            icon: Icons.bedtime_outlined,
            text:
                '${recap.first['explain'] ?? ''} Опыт за день: +${recap.first['points'] ?? 0}.'),
      ],
      if (s.legacyCompletedTasks.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
            'Сохранены задания прежней версии: ${s.legacyCompletedTasks.length}.'),
      ],
    ]);
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip(
      {required this.day,
      required this.today,
      required this.selected,
      required this.onTap});
  final int day;
  final bool today, selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: today ? 'День $day, сегодня' : 'День $day',
        excludeSemantics: true,
        child: Material(
          color: selected ? FinniColors.primary : FinniColors.paper,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              width: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: selected ? FinniColors.primary : FinniColors.line,
                    width: 1.5),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$day',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: selected
                                ? FinniColors.paper
                                : FinniColors.ink)),
                    Text(today ? 'сегодня' : 'день',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? FinniColors.mint
                                : FinniColors.muted)),
                  ]),
            ),
          ),
        ),
      );
}

class _DiaryRow extends StatelessWidget {
  const _DiaryRow({required this.state, required this.transaction});
  final GameController state;
  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final source = t.sourceId;
    final itemId = source.startsWith('shop:')
        ? source.substring(5)
        : source.startsWith('goal:')
            ? source.substring(5)
            : null;
    final (sign, ink, tint) = switch (t.type) {
      TransactionType.income => ('+', FinniColors.primary, FinniColors.mint),
      TransactionType.expense => ('−', FinniColors.alert, FinniColors.peach),
      TransactionType.toSavings => (
          '🐷 ',
          FinniColors.purple,
          FinniColors.lavender
        ),
      TransactionType.fromSavings => (
          '⬆️ ',
          FinniColors.purple,
          FinniColors.lavender
        ),
    };
    final (String tag, TagTone tone) = switch (t.type) {
      TransactionType.income when source.startsWith('task:') => (
          'награда',
          TagTone.gold
        ),
      TransactionType.income => ('доход', TagTone.green),
      TransactionType.expense when t.category == ExpenseCategory.mandatory => (
          'нужное',
          TagTone.green
        ),
      TransactionType.expense => ('желаемое', TagTone.purple),
      TransactionType.toSavings => ('в копилку', TagTone.purple),
      TransactionType.fromSavings => ('из копилки', TagTone.purple),
    };
    final Widget icon = itemId != null
        ? RoomArt(itemId, size: 28)
        : switch (t.type) {
            TransactionType.income when source.startsWith('task:') =>
              const Text('🧩', style: TextStyle(fontSize: 22)),
            TransactionType.income => const CoinIcon(size: 26),
            _ => const GameIcon(GameIconKind.pig, size: 26),
          };
    return Semantics(
      label: '${t.reasonText}: $sign${t.amount}',
      excludeSemantics: true,
      child: _Panel(
        padding: 10,
        radius: 18,
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: tint, borderRadius: BorderRadius.circular(12)),
            child: icon,
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.reasonText,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              if (t.type == TransactionType.expense)
                TagRow([TagChip(tag, tone: tone), const TagChip('🧾 чек')])
              else
                TagChip(tag, tone: tone),
            ]),
          ),
          const SizedBox(width: 8),
          Text('$sign${t.amount}',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: ink)),
        ]),
      ),
    );
  }
}

class _ReserveCard extends StatelessWidget {
  const _ReserveCard({required this.state});

  final GameController state;

  @override
  Widget build(BuildContext context) {
    final perDay = state.titles.dailyNeedsCost;
    if (perDay <= 0) return const SizedBox.shrink();
    final saved = state.wallet.wallet.savings;
    final days = saved ~/ perDay;
    final keeper = [
      for (final title in state.content.titles.titles)
        if (title.condition is ReserveCondition) title
    ].firstOrNull;
    final target = switch (keeper?.condition) {
      ReserveCondition(days: final need) => need,
      _ => 3,
    };
    final earned =
        keeper != null && state.progress.earnedTitles.contains(keeper.id);
    final text = days == 0
        ? 'Запаса пока нет. Один день нужного — это $perDay ${ruCoins(perDay)}.'
        : 'В копилке запас на $days ${ruDays(days)} нужного.';
    return Semantics(
      container: true,
      label: 'Подушка безопасности. $text',
      child: ExcludeSemantics(
        child: _Panel(
          padding: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('🛡️', style: TextStyle(fontSize: 30)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Подушка безопасности',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  ),
                  TagChip('${math.min(days, target)} из $target', tone: TagTone.green),
                ],
              ),
              const SizedBox(height: 8),
              Text(text,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (days / target).clamp(0.0, 1.0),
                  minHeight: 10,
                  color: FinniColors.primary,
                  backgroundColor: FinniColors.line,
                ),
              ),
              const SizedBox(height: 8),
              if (keeper != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TagChip(
                      earned
                          ? '🏅 «${keeper.title}» получено'
                          : '🏅 «${keeper.title}» — запас на $target ${ruDays(target)}',
                      tone: TagTone.gold),
                ),
              const SizedBox(height: 8),
              Text(
                  'Это монеты на неожиданный случай: сломался зонтик, подорожала еда. '
                  'Один день нужного = $perDay ${ruCoins(perDay)}.',
                  style: const TextStyle(fontSize: 15, color: FinniColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashLine extends StatelessWidget {
  const _DashLine();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: CustomPaint(
            painter: _DashPainter(), size: Size(double.infinity, 2)),
      );
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = FinniColors.storyPageNo
      ..strokeWidth = 2;
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, 1), Offset(math.min(x + 5, size.width), 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => false;
}

class _DayReceipt extends StatelessWidget {
  const _DayReceipt({required this.state, required this.day, required this.items});

  final GameController state;
  final int day;
  final List<Transaction> items;

  String _name(Transaction t) {
    final source = t.sourceId;
    if (source.startsWith('shop:')) {
      if (state.content.shop.byId(source.substring(5)) case final item?) {
        return item.title;
      }
    }
    return t.reasonText;
  }

  @override
  Widget build(BuildContext context) {
    final total = items.fold(0, (sum, t) => sum + t.amount);
    const figures = [FontFeature.tabularFigures()];
    return Semantics(
      container: true,
      label: 'Чек дня $day. Покупок: ${items.length}. Итого $total ${ruCoins(total)}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: FinniColors.storyPaper,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FinniColors.storyEdge, width: 1.5),
          boxShadow: const [
            BoxShadow(color: FinniColors.shadow, blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('🧾', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Чек дня',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  ),
                  Text('День $day',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800, color: FinniColors.muted)),
                ],
              ),
              const _DashLine(),
              for (final t in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(_name(t),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Text('${t.amount}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              fontFeatures: figures)),
                    ],
                  ),
                ),
              const _DashLine(),
              Row(
                children: [
                  const Expanded(
                    child: Text('Итого',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                  Text('$total ${ruCoins(total)}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900, fontFeatures: figures)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                  'Чек помогает проверить покупки. С ним можно вернуть сломанную вещь.',
                  style: TextStyle(fontSize: 15, color: FinniColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitlesView extends StatelessWidget {
  const _TitlesView({required this.state, required this.onChange});
  final GameController state;
  final VoidCallback onChange;

  GameController get s => state;

  static const Map<GrowthFactor, (String, Color)> _factors = {
    GrowthFactor.mandatoryPaid: ('🛒 Всё нужное', FinniColors.mint),
    GrowthFactor.followedPlan: ('📋 По плану', FinniColors.sky),
    GrowthFactor.savedAsPlanned: ('🐷 Копилка', FinniColors.lavender),
    GrowthFactor.taskDone: ('🧩 Игра', FinniColors.honey),
  };

  String _iconOf(TitleDef title) => switch (title.condition) {
        StartCondition() => '🌱',
        DaysCondition(:final marks) when marks.contains(DayMark.saved) => '🐷',
        DaysCondition(:final marks) when marks.contains(DayMark.planMade) =>
          '📋',
        DaysCondition(:final marks) when marks.contains(DayMark.onPlan) => '🎯',
        DaysCondition() => '📅',
        ThemeCondition() => '🛍️',
        GoalsCondition() => '🌟',
        ReserveCondition() => '🛡️',
        CarefulCondition() => '🔒',
      };

  @override
  Widget build(BuildContext context) {
    final status = s.growthStatus;
    final thresholds = s.growth.rules.thresholds;
    final from = s.stage == PetStage.baby ? 0 : thresholds[s.stage] ?? 0;
    final to = status.next == null ? null : thresholds[status.next];
    final share = to == null
        ? 1.0
        : ((s.progress.growthPoints - from) / (to - from)).clamp(0.0, 1.0);
    final facts = TitleFacts.create(
        dayNumber: s.day,
        completedTaskIds: s.tasks.completedTaskIds,
        reachedGoalIds: s.goals.reachedGoalIds,
        savings: s.wallet.wallet.savings,
        careful: s.carefulCount);
    final current = s.currentTitle;
    final next = [
      for (final title in s.content.titles.titles)
        if (!s.progress.earnedTitles.contains(title.id)) title
    ];
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          CoachTarget(
            id: 'titles.stages',
            child: _Panel(
              padding: 12,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final stage in PetStage.values)
                          Expanded(child: _StageStep(state: s, stage: stage)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text('${s.progress.growthPoints} опыта',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w900)),
                          if (status.next != null)
                            TagChip(
                                'до «${status.nextLabel}» ещё ${status.pointsToNext}')
                          else
                            const TagChip('взрослый друг', tone: TagTone.green),
                        ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child:
                          LinearProgressIndicator(value: share, minHeight: 12),
                    ),
                  ]),
            ),
          ),
          const SizedBox(height: 16),
          Text('Как получить опыт',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Опыт считаем вечером, по итогам дня.',
              style: TextStyle(color: FinniColors.muted)),
          const SizedBox(height: 8),
          CoachTarget(
            id: 'titles.xp',
            child: LayoutBuilder(builder: (context, c) {
              final columns =
                  MediaQuery.textScalerOf(context).scale(16) > 22 ? 1 : 2;
              final width = (c.maxWidth - (columns - 1) * 8) / columns;
              return EqualGrid(
                  columns: columns,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final MapEntry(key: factor, value: (label, color))
                        in _factors.entries)
                      SizedBox(
                        width: width,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(16)),
                          child: Row(children: [
                            Expanded(
                                child: Text(label,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800))),
                            Text('+${s.growth.rules.points[factor] ?? 0}',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w900)),
                          ]),
                        ),
                      ),
                  ]);
            }),
          ),
          const SizedBox(height: 16),
          if (current != null)
            CoachTarget(
              id: 'titles.current',
              child: _Panel(
                color: FinniColors.honey.withValues(alpha: .6),
                padding: 12,
                child: Row(children: [
                  Text(_iconOf(current), style: const TextStyle(fontSize: 34)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Твоё звание',
                              style: TextStyle(
                                  color: FinniColors.muted,
                                  fontWeight: FontWeight.w700)),
                          Text(current.title,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w900)),
                        ]),
                  ),
                  if (s.progress.earnedTitles.length > 1)
                    TextButton(
                        onPressed: onChange, child: const Text('Сменить')),
                ]),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text('Следующие звания',
                    style: Theme.of(context).textTheme.titleLarge),
                TagChip(
                    '${s.progress.earnedTitles.length} из ${s.content.titles.titles.length}',
                    tone: TagTone.gold),
              ]),
          const SizedBox(height: 8),
          if (next.isEmpty)
            const _Notice(
                icon: Icons.workspace_premium_outlined,
                text: 'Все звания получены! Ты настоящий мастер.'),
          for (final (i, title) in next.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _maybeTarget(
                  i == 0 ? 'titles.next' : null,
                  _NextTitle(
                    icon: _iconOf(title),
                    title: title.title,
                    reason: s.titles.reasonOf(title),
                    progress: s.titles.progressOf(title, s.progress, facts),
                  )),
            ),
        ]);
  }
}

class _StageStep extends StatelessWidget {
  const _StageStep({required this.state, required this.stage});
  final GameController state;
  final PetStage stage;
  @override
  Widget build(BuildContext context) {
    final now = state.stage == stage;
    final done = stage.index < state.stage.index;
    final size = now ? 58.0 : 46.0;
    final label =
        state.content.economy.growth.texts.stageLabels[stage] ?? stage.name;
    final Widget art = stage == PetStage.egg
        ? const Center(child: Text('🥚', style: TextStyle(fontSize: 26)))
        : IgnorePointer(
            child: MoniScene(
                appearance: state.appearance, stage: stage, motion: false));
    return Semantics(
      label: '$label${now ? ', сейчас' : done ? ', пройдено' : ''}',
      excludeSemantics: true,
      child: Column(children: [
        Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || now ? FinniColors.mint : FinniColors.paper,
            border: Border.all(
                color: done || now ? FinniColors.primary : FinniColors.line,
                width: now ? 3 : 2),
          ),
          child: done || now
              ? art
              : Opacity(
                  opacity: .35,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      .33,
                      .33,
                      .33,
                      0,
                      0,
                      .33,
                      .33,
                      .33,
                      0,
                      0,
                      .33,
                      .33,
                      .33,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1,
                      0,
                    ]),
                    child: art,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: now ? FinniColors.primary : FinniColors.muted)),
        ),
      ]),
    );
  }
}

class _NextTitle extends StatelessWidget {
  const _NextTitle(
      {required this.icon,
      required this.title,
      required this.reason,
      required this.progress});
  final String icon, title, reason;
  final (int, int) progress;
  @override
  Widget build(BuildContext context) {
    final (done, total) = progress;
    final left = total - done;
    return Semantics(
      label: '$title. $reason. Сделано $done из $total',
      excludeSemantics: true,
      child: _Panel(
        padding: 12,
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: FinniColors.sky,
                borderRadius: BorderRadius.circular(14)),
            child: Text(icon, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900)),
              Text(reason, style: const TextStyle(color: FinniColors.muted)),
              const SizedBox(height: 6),
              TagRow([
                TagChip('$done из $total'),
                if (left > 0 && total > 1)
                  TagChip('осталось $left', tone: TagTone.gold),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    value: total == 0 ? 0 : done / total,
                    minHeight: 8,
                    color: FinniColors.gold,
                    backgroundColor: FinniColors.line),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _GlossaryPage extends StatefulWidget {
  const _GlossaryPage({required this.state});
  final GameController state;
  @override
  State<_GlossaryPage> createState() => _GlossaryPageState();
}

class _GlossaryPageState extends State<_GlossaryPage> {
  String query = '';
  String topic = '';

  GameController get s => widget.state;

  static const List<String> _topics = ['money', 'shop', 'save', 'safe'];

  void _learn([String? startId]) {
    Navigator.of(context).push<void>(MaterialPageRoute(
      settings: const RouteSettings(name: 'Учим слова'),
      builder: (context) => _FlashcardsPage(state: s, startId: startId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final glossary = s.content.glossary;
    final texts = glossary.texts;
    final terms = [
      for (final term
          in query.trim().isEmpty ? glossary.terms : glossary.search(query))
        if (topic.isEmpty || term.topic == topic) term
    ];
    return Column(children: [
      Expanded(
        child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              CoachTarget(
                id: 'glossary.search',
                child: TextField(
                  onChanged: (value) => setState(() => query = value),
                  decoration: InputDecoration(
                    hintText: texts['search'],
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: FinniColors.paper,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              CoachTarget(
                id: 'glossary.topics',
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final id in ['', ..._topics])
                    ChoiceChip(
                      label: Text(id.isEmpty
                          ? texts['topicAll'] ?? 'Все'
                          : texts['topic_$id'] ?? id),
                      selected: topic == id,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => topic = id),
                      labelStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: topic == id
                              ? FinniColors.paper
                              : FinniColors.ink),
                      selectedColor: FinniColors.primary,
                      backgroundColor: FinniColors.paper,
                      side: BorderSide.none,
                    ),
                ]),
              ),
              const SizedBox(height: 10),
              TagRow([
                TagChip('${glossary.terms.length} слов'),
                TagChip('знаю ⭐ ${s.knownWords.length}', tone: TagTone.gold),
              ]),
              const SizedBox(height: 10),
              if (terms.isEmpty)
                const _Notice(
                    icon: Icons.search_off_rounded,
                    text: 'Такого слова пока нет. Попробуй другое.'),
              for (final (i, term) in terms.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _maybeTarget(
                      i == 0 ? 'glossary.list' : null,
                      _Panel(
                        padding: 4,
                        child: ListTile(
                          onTap: () => _learn(term.id),
                          leading: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: s.knownWords.contains(term.id)
                                    ? FinniColors.honey
                                    : FinniColors.mint,
                                borderRadius: BorderRadius.circular(14)),
                            child: Text(kEmoji[term.iconId] ?? '💡',
                                style: const TextStyle(fontSize: 22)),
                          ),
                          title: Text(term.term,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text(term.definition,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: s.knownWords.contains(term.id)
                              ? const Text('⭐', style: TextStyle(fontSize: 20))
                              : const Icon(Icons.chevron_right_rounded),
                        ),
                      )),
                ),
            ]),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: CoachTarget(
            id: 'glossary.learn',
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54)),
                onPressed: () => _learn(),
                icon: const Icon(Icons.style_outlined),
                label: Text(texts['learn'] ?? 'Учить слова'),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _FlashcardsPage extends StatefulWidget {
  const _FlashcardsPage({required this.state, this.startId});
  final GameController state;
  final String? startId;
  @override
  State<_FlashcardsPage> createState() => _FlashcardsPageState();
}

class _FlashcardsPageState extends State<_FlashcardsPage> {
  late final List<GlossaryTerm> deck;
  int index = 0;
  final Set<String> repeat = {};

  GameController get s => widget.state;

  @override
  void initState() {
    super.initState();
    final terms = s.content.glossary.terms;
    final start = [
      for (final term in terms)
        if (term.id == widget.startId) term
    ];
    deck = [
      ...start,
      for (final term in terms)
        if (term.id != widget.startId && !s.knownWords.contains(term.id)) term,
      for (final term in terms)
        if (term.id != widget.startId && s.knownWords.contains(term.id)) term,
    ];
  }

  void _answer(bool known) {
    final term = deck[index];
    s.fx('ui_tick');
    s.knowWord(term.id, known);
    setState(() {
      if (!known) repeat.add(term.id);
      index++;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
              tooltip: 'Закрыть',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded)),
          title: Text(s.content.glossary.texts['learn'] ?? 'Учим слова'),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: index >= deck.length ? _done(context) : _card(context),
            ),
          ),
        ),
      );

  Widget _card(BuildContext context) {
    final term = deck[index];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(
            child: Text('Слово ${index + 1} из ${deck.length}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: FinniColors.muted))),
        TagChip('знаю ⭐ ${s.knownWords.length}', tone: TagTone.gold),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
            value: (index + 1) / deck.length, minHeight: 8),
      ),
      const SizedBox(height: 16),
      CoachTarget(
        id: 'flash.card',
        child: PopIn(
          key: ValueKey(term.id),
          motion: s.motion,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [FinniColors.honey, FinniColors.morning],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                    color: FinniColors.shadow,
                    blurRadius: 18,
                    offset: Offset(0, 8))
              ],
            ),
            child: Column(children: [
              Text(kEmoji[term.iconId] ?? '💡',
                  style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 8),
              Text(term.term,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(term.definition,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: FinniColors.mint,
                    borderRadius: BorderRadius.circular(16)),
                child: Text('🎮 ${term.inGame}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: FinniColors.primary)),
              ),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 16),
      CoachTarget(
        id: 'flash.buttons',
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54)),
              onPressed: () => _answer(false),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Повторить'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54)),
              onPressed: () => _answer(true),
              icon: const Icon(Icons.star_rounded),
              label: const Text('Знаю'),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _done(BuildContext context) {
    final again = [
      for (final term in s.content.glossary.terms)
        if (repeat.contains(term.id)) term
    ];
    return ListView(padding: const EdgeInsets.all(16), children: [
      const SizedBox(height: 24),
      const Center(child: Text('🎉', style: TextStyle(fontSize: 64))),
      const SizedBox(height: 8),
      const Text('Все слова пройдены!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text(
          again.isEmpty
              ? 'Ты знаешь все слова. Здорово!'
              : 'Знаешь ${s.knownWords.length} из ${s.content.glossary.terms.length}. Эти слова повторим в следующий раз:',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: FinniColors.muted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      for (final term in again)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _Panel(
            padding: 12,
            child: Row(children: [
              Text(kEmoji[term.iconId] ?? '💡',
                  style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(term.term,
                      style: const TextStyle(fontWeight: FontWeight.w900))),
              const TagChip('повторить', tone: TagTone.gold),
            ]),
          ),
        ),
      const SizedBox(height: 12),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        onPressed: () => Navigator.pop(context),
        child: const Text('К списку слов'),
      ),
    ]);
  }
}

class _AdultView extends StatelessWidget {
  const _AdultView({required this.shell});
  final _GameShellState shell;

  GameController get s => shell.s;

  static const Map<GrowthFactor, String> _habits = {
    GrowthFactor.mandatoryPaid: '🍲 Сначала покупает нужное',
    GrowthFactor.followedPlan: '📋 Держится плана',
    GrowthFactor.savedAsPlanned: '🐷 Откладывает по плану',
    GrowthFactor.taskDone: '🧩 Играет в учебные игры',
  };

  static const Map<String, (Color, Color)> _themeColors = {
    'planning': (FinniColors.sky, FinniColors.primary),
    'savings': (FinniColors.lavender, FinniColors.purple),
    'payments': (FinniColors.peach, FinniColors.alert),
  };

  String _times(int n) {
    final mod10 = n % 10, mod100 = n % 100;
    final few = mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14);
    return few ? 'раза' : 'раз';
  }

  @override
  Widget build(BuildContext context) {
    final report = s.report;
    final spent = report.mandatory + report.optional;
    final whole = report.mandatory + report.optional + report.saved;
    final closed = s.progress.growthDays.length;
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [FinniColors.mint, FinniColors.paper]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('За ${report.days} ${ruDays(report.days)}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  IntrinsicHeight(
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        for (final (i, (value, label, ink)) in [
                          (
                            '${report.earned}',
                            'заработано',
                            FinniColors.primary
                          ),
                          ('$spent', 'потрачено', FinniColors.alert),
                          ('${report.saved}', 'отложено', FinniColors.purple),
                        ].indexed) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 4),
                              decoration: BoxDecoration(
                                  color: FinniColors.paper,
                                  borderRadius: BorderRadius.circular(14)),
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(value,
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            color: ink)),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(label,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: FinniColors.muted)),
                                    ),
                                  ]),
                            ),
                          ),
                        ],
                      ])),
                  if (whole > 0) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 14,
                        child: Row(children: [
                          for (final (value, color) in [
                            (report.mandatory, FinniColors.primary),
                            (report.optional, FinniColors.purple),
                            (report.saved, FinniColors.gold),
                          ])
                            if (value > 0)
                              Expanded(
                                  flex: value, child: ColoredBox(color: color)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TagRow([
                      TagChip('нужное ${report.mandatory}',
                          tone: TagTone.green),
                      TagChip('желаемое ${report.optional}',
                          tone: TagTone.purple),
                      TagChip('копилка ${report.saved}', tone: TagTone.gold),
                    ]),
                  ],
                ]),
          ),
          const SizedBox(height: 16),
          Text('Что уже получается',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (closed == 0)
            const _Notice(
                icon: Icons.bedtime_outlined,
                text:
                    'Привычки появятся после первого вечера, когда питомец уснёт.')
          else
            _Panel(
              padding: 12,
              child: Column(children: [
                for (final MapEntry(key: factor, value: label)
                    in _habits.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(label,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          TagChip(
                              '${s.habitDays(factor)} из $closed ${ruDays(closed)}',
                              tone: s.habitDays(factor) * 2 >= closed
                                  ? TagTone.green
                                  : TagTone.gold),
                        ]),
                  ),
              ]),
            ),
          const SizedBox(height: 16),
          Text('Настройки', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _Panel(
            padding: 4,
            child: Column(children: [
              ListTile(
                title: const Text('Имя питомца',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(s.petName),
                trailing: TextButton.icon(
                    onPressed: shell.renamePet,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Изменить')),
              ),
              SwitchListTile(
                  title: const Text('Звук',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Озвучка и звуковые эффекты'),
                  value: s.sound,
                  onChanged: s.setSound),
              SwitchListTile(
                  title: const Text('Анимации питомца',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text(
                      'Системное отключение движений тоже учитывается'),
                  value: s.motion,
                  onChanged: s.setMotion),
              SwitchListTile(
                  title: const Text('Попроще',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Меньше карточек и чисел в играх'),
                  value: s.simpleMode,
                  onChanged: s.setSimple),
            ]),
          ),
          const SizedBox(height: 16),
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text('Темы подробно',
                    style: Theme.of(context).textTheme.titleLarge),
                TagChip(
                    '${s.tasks.completedTaskIds.length} из ${s.content.tasks.tasks.length} игр',
                    tone: TagTone.green),
              ]),
          const SizedBox(height: 4),
          const Text(
              'Число справа — сколько раз игра пройдена. Полоски — сколько её вариантов уже решено.',
              style: TextStyle(color: FinniColors.muted)),
          const SizedBox(height: 8),
          for (final theme in s.content.tasks.themes) _theme(context, theme),
          const SizedBox(height: 12),
          _Panel(
            padding: 4,
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.restart_alt_rounded,
                    color: FinniColors.alert),
                title: const Text('Начать заново',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: FinniColors.alert)),
                subtitle:
                    const Text('Прогресс на этом устройстве будет заменён'),
                onTap: () => shell.confirmProfileAction(false),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: FinniColors.alert),
                title: const Text('Удалить профиль',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: FinniColors.alert)),
                subtitle: const Text('Всё будет удалено с этого устройства'),
                onTap: () => shell.confirmProfileAction(true),
              ),
            ]),
          ),
        ]);
  }

  Widget _theme(BuildContext context, TaskTheme theme) {
    final tasks = s.content.tasks.byTheme(theme.id);
    final done = tasks.where((t) => s.tasks.isCompleted(t.id)).length;
    final (tint, ink) =
        _themeColors[theme.id] ?? (FinniColors.mint, FinniColors.primary);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Panel(
        padding: 12,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            EmojiBadge(theme.iconId, size: 42, color: tint),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(theme.title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    TagRow([
                      TagChip('🎮 $done из ${tasks.length} игр',
                          tone: TagTone.green),
                      if (theme.skill.isNotEmpty) TagChip(theme.skill),
                    ]),
                  ]),
            ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
                value: tasks.isEmpty ? 0 : done / tasks.length,
                minHeight: 8,
                color: ink,
                backgroundColor: FinniColors.line),
          ),
          const SizedBox(height: 6),
          for (final task in tasks) _game(task, ink),
        ]),
      ),
    );
  }

  Widget _game(TaskDef task, Color ink) {
    final times = s.timesPlayed(task);
    final variants = task.variantKeys.length;
    final solved = s.passedOf(task);
    return Semantics(
      label:
          '${task.title}: ${times == 0 ? 'не играли' : 'пройдено $times ${_times(times)}'}, вариантов $solved из $variants',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: FinniColors.line))),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(task.title,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Row(children: [
                for (var i = 0; i < variants; i++)
                  Container(
                    width: 16,
                    height: 6,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                        color: i < solved ? ink : FinniColors.line,
                        borderRadius: BorderRadius.circular(3)),
                  ),
              ]),
            ]),
          ),
          if (times == 0)
            const TagChip('не играли')
          else
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$times',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900)),
              Text(_times(times),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: FinniColors.muted)),
            ]),
        ]),
      ),
    );
  }
}

Widget _maybeTarget(String? id, Widget child) =>
    id == null ? child : CoachTarget(id: id, child: child);
