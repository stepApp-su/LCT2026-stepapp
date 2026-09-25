import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../../domain/ru_words.dart';
import '../../domain/services/goal_service.dart';
import '../../domain/services/plan_service.dart';
import '../../domain/services/shop_service.dart';
import '../../domain/services/wallet_service.dart';
import '../games/games_hub.dart';
import '../theme/finni_theme.dart';
import '../widgets/emoji_art.dart';
import '../widgets/finni_ui.dart';
import '../widgets/moni_scene.dart';
import '../widgets/pet_celebration.dart';
import '../widgets/coin_icon.dart';
import '../widgets/game_icon.dart';
import '../game_controller.dart';

part 'game_sections.dart';
part '../widgets/game_components.dart';

class GameShell extends StatefulWidget {
  const GameShell({super.key, required this.state});
  final GameController state;
  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  int page = 0;
  int filter = 0;
  Timer? idleTimer;
  bool celebrating = false;
  GameController get s => widget.state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && s.bubble == null) s.greet();
      if (mounted) showCelebration();
    });
    s.addListener(showCelebration);
    idleTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted && page == 0 && ModalRoute.of(context)?.isCurrent == true) {
        s.idle();
      }
    });
  }

  @override
  void dispose() {
    s.removeListener(showCelebration);
    idleTimer?.cancel();
    super.dispose();
  }

  void showCelebration() {
    if (!mounted || celebrating || s.celebration == null) return;
    celebrating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final event = Map<String, dynamic>.of(s.celebration!);
      await showDialog<void>(
          context: context,
          useRootNavigator: false,
          barrierDismissible: false,
          builder: (_) => PetCelebration(state: s, event: event));
      if (!mounted) return;
      s.acknowledgeCelebration();
      celebrating = false;
    });
  }

  void go(int value) {
    setState(() => page = value);
    switch (value) {
      case 1:
        s.openPlanner();
      case 2:
        s.openShop();
      case 3:
        s.openGames();
    }
  }

  void bubbleAction(String route) {
    switch (route) {
      case 'tasks':
        go(3);
      case 'plan':
        go(1);
      case 'shop':
        go(2);
      case 'savings':
        savings();
      case 'goals':
        chooseGoal();
      case 'room' || 'wardrobe':
        room();
      case 'glossary':
        glossary();
      case 'close_day':
        daySummary();
    }
    s.dismissBubble();
  }

  void toast(String text) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  Future<void> sheet(String title, Widget body) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        backgroundColor: FinniColors.background,
        builder: (context) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              body,
            ],
          ),
        ),
      );
  void help() => sheet(
        'Маленькая подсказка',
        Text(
          switch (page) {
            0 =>
              'Нажми на питомца, чтобы погладить. Сверху — твоя мечта и монеты. Внизу — план, магазин, игры и другие разделы.',
            1 =>
              'Сначала подумай, что нужно сегодня. Разложи монеты по трём направлениям. План — это твой выбор, а не списание денег.',
            2 =>
              'Обязательное — то, без чего никак. Желаемое — то, что радует. Перед покупкой посмотри, сколько монет останется.',
            3 =>
              'Выбери задание. Можно подумать и попробовать ещё раз — за ошибку монеты не отнимаются.',
            _ =>
              'Здесь можно переодеть питомца, посмотреть дневник, узнать новые слова и подвести итоги дня. Настройки находятся в разделе для взрослого.',
          },
        ),
      );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: s,
        builder: (context, _) => PopScope(
            canPop: page == 0,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) go(0);
            },
            child: Scaffold(
              body: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        if (s.storageError != null)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(children: [
                              Text(s.storageError!),
                              TextButton.icon(
                                  onPressed: s.retrySave,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Повторить сохранение'))
                            ]),
                          ),
                        Expanded(
                          child: page == 0
                              ? home()
                              : page == 1
                                  ? budget()
                                  : page == 2
                                      ? shop()
                                      : page == 3
                                          ? tasksBody(context)
                                          : moreBody(),
                        ),
                        _Navigation(index: page, onSelect: go),
                      ],
                    ),
                  ),
                ),
              ),
            )),
      );

  Widget home() => LayoutBuilder(builder: (context, constraints) {
        final enlarged = MediaQuery.textScalerOf(context).scale(16) > 20;
        final petHeight = enlarged
            ? 300.0
            : (constraints.maxHeight - 356).clamp(240.0, 440.0);
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(children: [
              Semantics(
                button: true,
                label: s.currentGoal == null
                    ? 'Выбери мечту'
                    : 'Мечта: ${s.goal}. ${s.wallet.wallet.savings} из ${s.target} монет',
                excludeSemantics: true,
                child: Material(
                  color: FinniColors.lavender,
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                      onTap: savings,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _GoalIcon(s.goalId),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(
                                        s.currentGoal == null
                                            ? 'Выбери мечту'
                                            : 'Мечта: ${s.goal}',
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 5),
                                    _GoalProgress(
                                        saved: s.wallet.wallet.savings,
                                        target: s.target),
                                  ])),
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Icon(Icons.chevron_right_rounded),
                              ),
                            ]),
                      )),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _ResourceChip(
                        label: 'День ${s.day}',
                        icon: Icons.wb_sunny_outlined,
                        color: FinniColors.paper)),
                const SizedBox(width: 6),
                Expanded(
                    child: _ResourceChip(
                        label: '${s.wallet.wallet.balance}',
                        semantics: 'Монеты: ${s.wallet.wallet.balance}',
                        coin: true,
                        color: FinniColors.honey)),
                const SizedBox(width: 6),
                Expanded(
                    child: _ResourceChip(
                        label: '${s.wallet.wallet.savings}',
                        semantics: 'Копилка: ${s.wallet.wallet.savings}',
                        icon: Icons.savings_outlined,
                        color: FinniColors.lavender,
                        onTap: savings)),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                  height: petHeight,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                          top: 26,
                          bottom: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: FinniColors.mint.withValues(alpha: .5),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(150),
                                  bottom: Radius.circular(48)),
                            ),
                          )),
                      Positioned(
                          left: 20,
                          right: 20,
                          bottom: 8,
                          height: 32,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: FinniColors.mint,
                                borderRadius: BorderRadius.circular(80)),
                          )),
                      Positioned.fill(
                          top: 14,
                          bottom: 4,
                          child: MoniScene(
                            stage: s.stage,
                            outfit: s.outfit,
                            motion: s.motion,
                            equipped: s.equipped,
                          )),
                      Positioned(
                          left: 8,
                          top: 4,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.petName,
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800)),
                                Text(
                                    '${s.stageLabel} · ${s.currentTitle?.title ?? 'Новичок'}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        color: FinniColors.muted)),
                              ])),
                      Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                              tooltip: 'Подсказка',
                              onPressed: help,
                              icon: const Icon(Icons.help_outline_rounded))),
                      Positioned(
                          left: 16,
                          right: 16,
                          top: 44,
                          child: Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 310),
                                  child: AnimatedBubble(
                                    line: s.bubble,
                                    motion: s.motion,
                                    onClose: s.dismissBubble,
                                    onAction: s.bubble?.action == null
                                        ? null
                                        : () => bubbleAction(
                                            s.bubble!.action!.route),
                                  )))),
                    ],
                  )),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, constraints) {
                final columns =
                    MediaQuery.textScalerOf(context).scale(13) > 19 ? 1 : 2;
                final width =
                    (constraints.maxWidth - (columns - 1) * 8) / columns;
                return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Stat(
                          label: 'Сытость',
                          value: s.stats.satiety,
                          icon: GameIconKind.food,
                          color: FinniColors.gold),
                      _Stat(
                          label: 'Уход',
                          value: s.stats.care,
                          icon: GameIconKind.care,
                          color: FinniColors.blue),
                      _Stat(
                          label: 'Радость',
                          value: s.stats.mood,
                          icon: GameIconKind.joy,
                          color: FinniColors.purple),
                      _Stat(
                          label: 'Уют',
                          value: s.stats.cozy,
                          icon: GameIconKind.cozy,
                          color: FinniColors.primary),
                    ]
                        .map((stat) => SizedBox(width: width, child: stat))
                        .toList());
              }),
              const SizedBox(height: 12),
              Builder(builder: (context) {
                final daily = s.dailyGame;
                final reward = s.rewardFor(daily);
                return Material(
                  color: FinniColors.sky,
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                      onTap: () => openGame(context, s, daily.id),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          EmojiBadge(daily.iconId,
                              size: 36, color: FinniColors.paper),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(daily.title,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800)),
                                Text(
                                    reward > 0
                                        ? 'Игра дня · +$reward монет'
                                        : 'Можно играть просто так',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        color: FinniColors.muted)),
                              ])),
                          const Icon(Icons.play_circle_fill_rounded,
                              size: 32, color: FinniColors.primary),
                        ]),
                      )),
                );
              }),
            ]),
          ),
        );
      });
  Widget budget() => Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Panel(
                    color: FinniColors.mint,
                    padding: 12,
                    child: Row(children: [
                      const Expanded(
                          child: Text('Доход дня',
                              style: TextStyle(fontWeight: FontWeight.w700))),
                      _Coins(s.plan.plan.income)
                    ])),
                const SizedBox(height: 12),
                const Text('Каждый шаг — 5 монет.',
                    style: TextStyle(color: FinniColors.muted)),
                const SizedBox(height: 12),
                _BudgetRow(
                  title: 'Обязательное',
                  subtitle: 'То, без чего никак',
                  icon: Icons.restaurant_outlined,
                  color: FinniColors.mint,
                  value: s.plan.plan.mandatory,
                  direction: PlanDirection.mandatory,
                  state: s,
                ),
                const SizedBox(height: 12),
                _BudgetRow(
                  title: 'Желаемое',
                  subtitle: 'То, что радует',
                  icon: Icons.celebration_outlined,
                  color: FinniColors.sky,
                  value: s.plan.plan.optional,
                  direction: PlanDirection.optional,
                  state: s,
                ),
                const SizedBox(height: 12),
                _BudgetRow(
                  title: 'Копилка',
                  subtitle: 'Навстречу мечте',
                  icon: Icons.savings_outlined,
                  color: FinniColors.lavender,
                  value: s.plan.plan.savings,
                  direction: PlanDirection.savings,
                  state: s,
                ),
                const SizedBox(height: 20),
                if (s.plan.hint() != null) ...[
                  _Notice(
                      icon: Icons.lightbulb_outline_rounded,
                      text: s.plan.hint()!.textRu),
                  const SizedBox(height: 12),
                ],
                _Notice(
                  icon: Icons.savings_outlined,
                  text: (s.daysWithPlan == null
                      ? 'Добавь монеты в копилку — и мы посчитаем путь до мечты.'
                      : 'Если откладывать по ${s.plan.plan.savings} монет в день, до мечты ещё ${s.daysWithPlan} ${ruDays(s.daysWithPlan ?? 0)}.'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'План не тратит монеты. Покупки и пополнение копилки ты делаешь отдельно.',
                  style: TextStyle(color: FinniColors.muted),
                ),
              ],
            ),
          ),
          _Panel(
            radius: 0,
            padding: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Не распределено',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    _Coins(s.plan.remainder),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: s.plan.isConfirmed
                      ? null
                      : () {
                          s.confirmPlan();
                          toast('План готов. Теперь можно выбирать покупки!');
                        },
                  icon: Icon(
                    s.plan.isConfirmed
                        ? Icons.check_rounded
                        : Icons.check_circle_outline_rounded,
                  ),
                  label: Text(
                    s.plan.isConfirmed ? 'План сохранён' : 'Подтвердить план',
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget shop() {
    final items = s.catalog
        .where(
          (item) =>
              filter == 0 ||
              filter == 1 && item.category == ExpenseCategory.mandatory ||
              filter == 2 && item.category == ExpenseCategory.optional ||
              filter == 3 && item.price <= s.wallet.wallet.balance,
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Panel(
          color: FinniColors.honey,
          child: Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 28,
                color: FinniColors.gold,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Можно потратить',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _Coins(s.wallet.wallet.balance),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Что порадует ${s.petName}?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        const Text(
          'Сначала нужное. А дальше — твой выбор.',
          style: TextStyle(color: FinniColors.muted),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, label) in [
              'Всё',
              'Нужное',
              'Желаемое',
              'По карману',
            ].indexed)
              ChoiceChip(
                label: Text(label),
                selected: filter == i,
                onSelected: (_) => setState(() => filter = i),
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: filter == i ? FinniColors.paper : FinniColors.ink,
                ),
                selectedColor: FinniColors.primary,
                backgroundColor: FinniColors.paper,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const _Notice(
            icon: Icons.savings_outlined,
            text:
                'Пока не хватает монет. Сыграй в игру или вернись к покупке позже.',
          ),
        LayoutBuilder(
          builder: (context, c) {
            final columns =
                MediaQuery.textScalerOf(context).scale(16) > 22 ? 1 : 2;
            final width = (c.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (i, item) in items.indexed)
                  SizedBox(
                    width: width,
                    child: PopIn(
                      key: ValueKey('shop-${item.id}-$filter'),
                      motion: s.motion,
                      delay: (i % 6) * 40,
                      child: product(item),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const _Notice(
          icon: Icons.info_outline_rounded,
          text: 'Монеты игровые. Настоящих денег здесь нет.',
        ),
      ],
    );
  }

  Widget _categoryPill(ShopItemView view) => _Pill(
      icon: view.category == ExpenseCategory.mandatory
          ? Icons.check_circle_outline_rounded
          : Icons.auto_awesome_outlined,
      label: view.categoryLabel,
      color: view.category == ExpenseCategory.mandatory
          ? FinniColors.mint
          : FinniColors.lavender);

  Widget product(ShopItem item) {
    final view = s.viewOf(item);
    return Semantics(
      button: true,
      label:
          'Открыть покупку: ${item.title}. ${view.priceText}. ${view.categoryLabel}',
      excludeSemantics: true,
      child: Squish(
        onTap: () => purchase(item),
        child: _Panel(
          padding: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(child: ItemArt(item.id, size: 86)),
                  if (view.isOwned)
                    const Positioned(
                      right: 0,
                      top: 0,
                      child: Icon(Icons.check_circle_rounded,
                          color: FinniColors.primary, size: 28),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(item.title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              _categoryPill(view),
              const SizedBox(height: 6),
              for (final effect in view.effectTexts)
                Text(effect,
                    style: const TextStyle(
                        color: FinniColors.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              view.isOwned
                  ? const Text('Уже есть',
                      style: TextStyle(fontWeight: FontWeight.w800))
                  : _Coins(item.price),
            ],
          ),
        ),
      ),
    );
  }

  void purchase(ShopItem item) {
    PurchaseOutcome outcome = s.askToBuy(item.id);
    final before = s.wallet.wallet.balance;
    sheet(
      item.title,
      StatefulBuilder(
        builder: (context, update) {
          final view = s.viewOf(item);
          final current = outcome;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: PopIn(
                  motion: s.motion,
                  child: ItemArt(item.id, size: 150),
                ),
              ),
              const SizedBox(height: 12),
              if (item.description.isNotEmpty)
                Text(item.description, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _categoryPill(view),
                  for (final effect in view.effectTexts)
                    _Pill(
                        icon: Icons.favorite_border_rounded,
                        label: effect,
                        color: FinniColors.honey),
                  for (final effect in view.dailyEffectTexts)
                    _Pill(
                        icon: Icons.wb_sunny_outlined,
                        label: effect,
                        color: FinniColors.sky),
                ],
              ),
              const SizedBox(height: 8),
              Text(view.categoryHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: FinniColors.muted)),
              const SizedBox(height: 16),
              ...switch (current) {
                PurchaseDone(:final diaryText, :final noteText) => [
                    _Notice(
                      icon: Icons.check_circle_outline,
                      text:
                          '$diaryText${noteText == null ? '' : ' $noteText'} Осталось ${s.wallet.wallet.balance} монет.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.celebration_outlined),
                      label: const Text('Ура!'),
                    ),
                  ],
                PurchaseRefused(:final textRu) => [
                    _Notice(icon: Icons.info_outline_rounded, text: textRu),
                  ],
                PurchaseNotEnough(:final gap, :final options) => [
                    _Notice(
                      icon: Icons.lightbulb_outline,
                      text: 'Пока не хватает $gap монет. Что сделаем?',
                    ),
                    const SizedBox(height: 12),
                    for (final option in options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            notEnoughOption(option, item);
                          },
                          icon: Icon(option.route == 'tasks'
                              ? Icons.extension_outlined
                              : option.route == 'postpone'
                                  ? Icons.bookmark_add_outlined
                                  : Icons.sell_outlined),
                          label: Text(option.textRu),
                        ),
                      ),
                  ],
                PurchaseConfirm confirm => [
                    if (confirm.view.comparisonText != null) ...[
                      _Notice(
                          icon: Icons.lightbulb_outline_rounded,
                          text: confirm.view.comparisonText!),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      before >= item.price
                          ? 'Было $before → останется ${before - item.price} монет'
                          : 'Сейчас у тебя $before монет',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text(confirm.question,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        final result = s.confirmPurchase(confirm);
                        update(() => outcome = result);
                        if (result is PurchaseDone) {
                          Celebration.show(this.context,
                              motion: s.motion, emoji: '🛍️');
                        }
                      },
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: Text('Купить за ${item.price} монет'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Подумаю ещё'),
                    ),
                  ],
              },
            ],
          );
        },
      ),
    );
  }

  void notEnoughOption(NotEnoughOption option, ShopItem item) {
    final route = option.route;
    if (route == 'tasks') {
      go(3);
    } else if (route == 'postpone') {
      s.postpone(item.id);
      toast('Сохранили в желаниях. Вернёмся к покупке завтра!');
    } else if (route.startsWith('shop:')) {
      final cheaper = s.content.shop.byId(route.substring(5));
      if (cheaper != null) purchase(cheaper);
    }
  }
}
