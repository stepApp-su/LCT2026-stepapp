import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../../domain/services/plan_service.dart';
import '../../domain/services/wallet_service.dart';
import '../theme/finni_theme.dart';
import '../widgets/moni_scene.dart';
import '../widgets/coin_icon.dart';
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
  GameController get s => widget.state;
  void go(int value) => setState(() => page = value);
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
  void questionExercise() {
    String? response;
    bool success = s.completed;
    sheet(
      'Задание дня',
      StatefulBuilder(
        builder: (context, update) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.question['text'] as String,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            for (int i = 0; i < (s.question['answers'] as List).length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton(
                  onPressed: success
                      ? null
                      : () {
                          final ok = s.answer(i);
                          update(() {
                            success = ok;
                            response = ok
                                ? 'Верно! ${s.question['explanation']} +${s.question['reward']} монет.'
                                : 'Давай подумаем: сначала важно утолить голод. Попробуй ещё раз.';
                          });
                        },
                  child: Text((s.question['answers'] as List)[i] as String),
                ),
              ),
            if (response != null || success)
              _Notice(
                icon: success
                    ? Icons.check_circle_outline
                    : Icons.lightbulb_outline,
                text: response ??
                    '${s.question['explanation']} Награда уже в кошельке.',
              ),
            const SizedBox(height: 12),
            const Text(
              'Тема: нужное и желаемое.',
              style: TextStyle(color: FinniColors.muted, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  void purchase(ShopItem item) {
    final detail = s.details(item.id);
    bool bought = false;
    sheet(
      item.title,
      StatefulBuilder(
        builder: (context, update) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 150,
              child: Center(
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: ProductArt(
                    sheet: detail['art'] as String,
                    cell: detail['cell'] as int,
                  ),
                ),
              ),
            ),
            Text(detail['note'] as String, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (bought)
              _Notice(
                icon: Icons.check_circle_outline,
                text: 'Готово! Осталось ${s.wallet.wallet.balance} монет.',
              )
            else if (s.ownsAccessory(item))
              const _Notice(
                  icon: Icons.check_circle_outline,
                  text: 'У тебя уже есть этот аксессуар.')
            else if (s.wallet.wallet.balance >= item.price) ...[
              Text(
                'Было ${s.wallet.wallet.balance} → останется ${s.wallet.wallet.balance - item.price} монет.\n${priceComparison(item)}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  final result = s.buy(item);
                  if (result is WalletOk) update(() => bought = true);
                },
                icon: const Icon(Icons.shopping_bag_outlined),
                label: Text('Купить за ${item.price} монет'),
              ),
            ] else ...[
              _Notice(
                icon: Icons.lightbulb_outline,
                text:
                    'Нужно ещё ${item.price - s.wallet.wallet.balance} монет. Давай выберем, что делать.',
              ),
              const SizedBox(height: 12),
              if (!s.completed)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    tasks();
                  },
                  icon: const Icon(Icons.extension_outlined),
                  label: const Text('Выполнить задание'),
                ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  s.postpone(item.id);
                  toast('Сохранили в желаниях.');
                },
                child: const Text('Отложить на завтра'),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    page = 2;
                    filter = 3;
                  });
                },
                child: const Text('Посмотреть доступные товары'),
              ),
            ],
          ],
        ),
      ),
    );
  }

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
            : (constraints.maxHeight - 318).clamp(240.0, 440.0);
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(children: [
              Semantics(
                button: true,
                label:
                    'Мечта: ${s.goal}. ${s.wallet.wallet.savings} из ${s.target} монет',
                excludeSemantics: true,
                child: Material(
                  color: FinniColors.lavender,
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                      onTap: savings,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          _IconTile(
                              icon: switch (s.goalId) {
                                'book' => Icons.menu_book_outlined,
                                'telescope' => Icons.travel_explore_rounded,
                                _ => Icons.electric_scooter_rounded,
                              },
                              color: FinniColors.paper),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('Мечта: ${s.goal}',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 5),
                                _Progress(
                                    value: s.wallet.wallet.savings / s.target,
                                    color: FinniColors.purple),
                                const SizedBox(height: 4),
                                Text(
                                    '${s.wallet.wallet.savings} из ${s.target} монет',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        color: FinniColors.purple)),
                              ])),
                          const Icon(Icons.chevron_right_rounded),
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
                                const Text('Малыш',
                                    style: TextStyle(
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
                    ],
                  )),
              const SizedBox(height: 8),
              Row(children: [
                _Stat(
                    label: 'Сытость',
                    value: s.stats.satiety,
                    icon: Icons.restaurant_outlined,
                    color: FinniColors.gold),
                _Stat(
                    label: 'Уход',
                    value: s.stats.care,
                    icon: Icons.water_drop_outlined,
                    color: FinniColors.blue),
                _Stat(
                    label: 'Радость',
                    value: s.stats.mood,
                    icon: Icons.favorite_border_rounded,
                    color: FinniColors.purple),
                _Stat(
                    label: 'Уют',
                    value: s.stats.cozy,
                    icon: Icons.home_outlined,
                    color: FinniColors.primary),
              ]),
              const SizedBox(height: 12),
              Material(
                color: FinniColors.sky,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                    onTap: tasks,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Icon(
                            s.completed
                                ? Icons.check_circle_outline_rounded
                                : Icons.extension_outlined,
                            size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  s.completed
                                      ? 'Задание выполнено'
                                      : '${s.question['title']}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800)),
                              Text(
                                  s.completed
                                      ? 'Монеты уже в кошельке'
                                      : 'Задание дня · +${s.question['reward']} монет',
                                  style: const TextStyle(
                                      fontSize: 16, color: FinniColors.muted)),
                            ])),
                        const Icon(Icons.chevron_right_rounded),
                      ]),
                    )),
              ),
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
                  text: (s.daysToGoal == null
                      ? 'Добавь монеты в копилку — и мы посчитаем путь до мечты.'
                      : 'Если откладывать по ${s.plan.plan.savings} монет в день, до мечты ещё ${s.daysToGoal} дн.'),
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
                'Пока не хватает монет. Выполни задание или вернись к покупке позже.',
          ),
        LayoutBuilder(
          builder: (context, c) {
            const columns = 1;
            final width = (c.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in items)
                  SizedBox(width: width, child: product(item)),
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

  Widget product(ShopItem item) {
    final d = s.details(item.id),
        needed = item.category == ExpenseCategory.mandatory;
    final enlarged = MediaQuery.textScalerOf(context).scale(16) > 22;
    final details =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(item.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(d['note'] as String,
          style: const TextStyle(color: FinniColors.muted)),
    ]);
    final picture = SizedBox(
        width: 100,
        height: 100,
        child: ProductArt(sheet: d['art'] as String, cell: d['cell'] as int));
    return _Panel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (enlarged) ...[Center(child: picture), details] else
        Row(children: [
          picture,
          const SizedBox(width: 16),
          Expanded(child: details)
        ]),
      const SizedBox(height: 12),
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            _Pill(
                icon: needed
                    ? Icons.check_circle_outline_rounded
                    : Icons.auto_awesome_outlined,
                label: needed ? 'Обязательное' : 'Желаемое',
                color: needed ? FinniColors.mint : FinniColors.lavender),
            Semantics(
                label: 'Открыть покупку: ${item.title}',
                button: true,
                child: OutlinedButton(
                    onPressed: () => purchase(item),
                    child: s.ownsAccessory(item)
                        ? const Text('Куплено')
                        : _Coins(item.price))),
          ]),
    ]));
  }
}
