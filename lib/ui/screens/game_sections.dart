part of 'game_shell.dart';

extension _GameSections on _GameShellState {
  void section(String title, Widget Function(BuildContext) content) {
    Navigator.of(context).push<void>(MaterialPageRoute(
      settings: RouteSettings(name: title),
      builder: (context) => Scaffold(
        appBar: AppBar(
            toolbarHeight: MediaQuery.textScalerOf(context).scale(22) * 2.7 + 8,
            title: Text(title, maxLines: 2),
            leading: IconButton(
                tooltip: 'Назад',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded)),
            actions: [
              IconButton(
                  tooltip: 'Подсказка',
                  onPressed: glossary,
                  icon: const Icon(Icons.help_outline_rounded))
            ]),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: AnimatedBuilder(
                        animation: s,
                        builder: (context, _) => content(context))))),
      ),
    ));
  }

  void savings() => section('Мечта и копилка', (context) {
        final view = s.goalView;
        final reached = s.reachedGoals;
        return ListView(padding: const EdgeInsets.all(16), children: [
          if (view == null)
            _Panel(
                color: FinniColors.lavender,
                child: Column(children: [
                  const Text('✨', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 8),
                  Text('Выбери мечту',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(s.goals.starterHint, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: chooseGoal,
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Выбрать мечту')),
                ]))
          else ...[
            _Panel(
                color: FinniColors.lavender,
                child: Column(children: [
                  PopIn(
                      motion: s.motion,
                      child: ItemArt(view.goal.id, size: 120)),
                  const SizedBox(height: 12),
                  Text(view.goal.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium),
                  if (view.goal.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(view.goal.description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: FinniColors.muted)),
                  ],
                  const SizedBox(height: 12),
                  Text(view.progressText,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _MilestoneBar(
                      percent: view.percent,
                      milestones: s.content.goals.milestones,
                      motion: s.motion),
                  const SizedBox(height: 12),
                  Text(view.leftText,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ])),
            const SizedBox(height: 16),
            _Notice(
                icon: Icons.lightbulb_outline_rounded, text: view.eta.textRu),
            const SizedBox(height: 20),
            if (view.isReached) ...[
              FilledButton.icon(
                  onPressed: claimGoal,
                  icon: const Icon(Icons.celebration_outlined),
                  label: Text(view.reachedButton)),
              const SizedBox(height: 8),
            ],
            FilledButton.tonalIcon(
                onPressed:
                    s.wallet.wallet.balance > 0 ? () => transfer(false) : null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Пополнить копилку')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
                onPressed:
                    s.wallet.wallet.savings > 0 ? () => transfer(true) : null,
                icon: const Icon(Icons.arrow_upward_rounded),
                label: const Text('Взять из копилки')),
            const SizedBox(height: 8),
            TextButton.icon(
                onPressed: chooseGoal,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Выбрать другую мечту')),
          ],
          if (reached.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Сбывшиеся мечты',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (final goal in reached)
                Column(mainAxisSize: MainAxisSize.min, children: [
                  ItemArt(goal.id, size: 76),
                  const SizedBox(height: 4),
                  Text(goal.title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
            ]),
          ],
        ]);
      });

  void claimGoal() {
    final outcome = s.claimGoal();
    if (outcome is GoalClaimed) {
      Celebration.show(context,
          motion: s.motion, emoji: '🏆', text: outcome.goal.title);
      sheet(
          'Мечта сбылась!',
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: ItemArt(outcome.goal.id, size: 140)),
            const SizedBox(height: 16),
            Text(outcome.reachedText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            if (outcome.unlockedText != null) ...[
              const SizedBox(height: 12),
              _Notice(
                  icon: Icons.auto_awesome_outlined,
                  text: outcome.unlockedText!),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  chooseGoal();
                },
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Выбрать новую мечту')),
          ]));
    } else if (outcome is GoalRefused) {
      toast(outcome.textRu);
    }
  }

  bool requirePlan() {
    if (!s.needsPlan) return false;
    final income = s.plan.plan.income;
    sheet(
        'Сначала план на день',
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Center(child: Text('📋', style: TextStyle(fontSize: 56))),
          const SizedBox(height: 12),
          Text(
              'Прежде чем тратить и копить, разложим $income ${ruCoins(income)}: на обязательное, на желаемое и в копилку.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17)),
          const SizedBox(height: 8),
          const Text('Так в начале дня делают и взрослые — это и есть план.',
              textAlign: TextAlign.center,
              style: TextStyle(color: FinniColors.muted)),
          const SizedBox(height: 20),
          FilledButton.icon(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                go(1);
              },
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Составить план')),
        ]));
    return true;
  }

  void transfer(bool withdrawal) {
    if (requirePlan()) return;
    final step = s.content.economy.params.plan.step;
    final max = withdrawal ? s.wallet.wallet.savings : s.wallet.wallet.balance;
    int amount = !withdrawal && s.savingsToDeposit > 0
        ? s.savingsToDeposit
        : max < step
            ? max
            : step;
    sheet(withdrawal ? 'Взять из копилки' : 'Пополнить копилку',
        StatefulBuilder(builder: (context, update) {
      final before = s.wallet.wallet.savings;
      final preview =
          withdrawal && amount > 0 ? s.previewWithdraw(amount) : null;
      final after = before + (withdrawal ? -amount : amount);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
            child: Text(withdrawal ? '🐷➡️🪙' : '🪙➡️🐷',
                style: const TextStyle(fontSize: 44))),
        const SizedBox(height: 12),
        _Panel(
            color: withdrawal ? FinniColors.lavender : FinniColors.honey,
            padding: 12,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(
                            withdrawal ? 'Сейчас в копилке' : 'Сейчас в кошельке',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800))),
                    _Coins(max),
                  ]),
                  if (!withdrawal && s.plan.isConfirmed) ...[
                    const SizedBox(height: 6),
                    Text(
                        s.planLeft(PlanDirection.savings) > 0
                            ? 'По плану сегодня отложить ещё ${s.planLeft(PlanDirection.savings)}.'
                            : 'По плану на сегодня уже отложено. Можно добавить ещё, если хочется.',
                        style: const TextStyle(fontSize: 16)),
                  ],
                ])),
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          if (!withdrawal && s.savingsToDeposit > 0 && s.savingsToDeposit != max)
            OutlinedButton(
                onPressed: () => update(() => amount = s.savingsToDeposit),
                child: Text('По плану: ${s.savingsToDeposit}')),
          if (max > 0)
            OutlinedButton(
                onPressed: () => update(() => amount = max),
                child: Text(withdrawal ? 'Всё: $max' : 'Все монеты: $max')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          IconButton.filledTonal(
              tooltip: 'Уменьшить сумму',
              onPressed:
                  amount > step ? () => update(() => amount -= step) : null,
              icon: const Icon(Icons.remove_rounded)),
          Expanded(child: Center(child: _Coins(amount))),
          IconButton.filledTonal(
              tooltip: 'Увеличить сумму',
              onPressed: amount + step <= max
                  ? () => update(() => amount += step)
                  : null,
              icon: const Icon(Icons.add_rounded))
        ]),
        const SizedBox(height: 16),
        if (preview is WithdrawPreview) ...[
          Text(preview.question,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(preview.savedChangeText, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(preview.etaChangeText, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(
              onPressed: () {
                if (s.confirmWithdraw(preview) is WithdrawDone) {
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.arrow_upward_rounded),
              label: Text(preview.confirmLabel)),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(preview.cancelLabel)),
        ] else if (preview is GoalRefused) ...[
          _Notice(icon: Icons.info_outline_rounded, text: preview.textRu),
        ] else if (!withdrawal) ...[
          Text('В копилке: $before → $after монет',
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(
              onPressed: amount > 0
                  ? () {
                      final result = s.deposit(amount);
                      if (result is GoalDepositDone) {
                        Navigator.pop(context);
                        if (result.justReached) {
                          Celebration.show(this.context,
                              motion: s.motion, emoji: '🏆');
                          toast('Хватает! Можно забирать мечту.');
                        } else if (result.milestoneText != null) {
                          Celebration.show(this.context,
                              motion: s.motion,
                              emoji: '⭐',
                              text: result.milestoneText);
                        } else {
                          toast('Отложили $amount монет. Мечта ближе!');
                        }
                      }
                    }
                  : null,
              icon: const Icon(Icons.savings_outlined),
              label: Text('Отложить $amount')),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
        ],
      ]);
    }));
  }

  void chooseGoal() => section('Выбери мечту', (context) {
        final available = s.goals.available();
        final locked = [
          for (final goal in s.content.goals.goals)
            if (!s.goals.isUnlocked(goal) &&
                !s.goals.reachedGoalIds.contains(goal.id))
              goal
        ];
        return ListView(padding: const EdgeInsets.all(16), children: [
          _Notice(
              icon: Icons.savings_outlined,
              text:
                  'Всё накопленное останется в копилке. ${s.goals.starterHint}'),
          const SizedBox(height: 16),
          for (final goal in available)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _Panel(
                    child: Row(children: [
                  ItemArt(goal.id, size: 72),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(goal.title,
                            style: Theme.of(context).textTheme.titleLarge),
                        if (goal.description.isNotEmpty)
                          Text(goal.description,
                              style: const TextStyle(color: FinniColors.muted)),
                        const SizedBox(height: 6),
                        _Coins(goal.price),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                            onPressed: goal.id == s.goalId
                                ? null
                                : () => askGoal(goal.id),
                            icon: Icon(goal.id == s.goalId
                                ? Icons.check_rounded
                                : Icons.flag_outlined),
                            label: Text(goal.id == s.goalId
                                ? 'Текущая мечта'
                                : 'Выбрать')),
                      ])),
                ]))),
          for (final goal in locked)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Opacity(
                    opacity: .6,
                    child: _Panel(
                        child: Row(children: [
                      ItemArt(goal.id, size: 72),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(goal.title,
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 6),
                            Row(children: [
                              const Icon(Icons.lock_outline_rounded, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(
                                      'Откроется после ${goal.minGoalsReached} ${ruPlural(goal.minGoalsReached, 'достигнутой цели', 'достигнутых целей', 'достигнутых целей')}')),
                            ]),
                          ])),
                    ])))),
        ]);
      });

  void askGoal(String id) {
    final ask = s.askGoal(id);
    if (ask is GoalRefused) {
      toast(ask.textRu);
      return;
    }
    if (ask is! GoalSelectConfirm) return;
    sheet(
        ask.question,
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: ItemArt(ask.goal.id, size: 120)),
          const SizedBox(height: 12),
          Text(ask.keepSavingsText, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: () {
                final result = s.confirmGoal(ask);
                Navigator.of(context).pop();
                if (result is GoalSelected) {
                  Navigator.of(context).maybePop();
                  toast(result.selectPhrase);
                }
              },
              icon: const Icon(Icons.check_rounded),
              label: Text(ask.confirmLabel)),
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(ask.cancelLabel)),
        ]));
  }

  Widget tasksBody(BuildContext context) =>
      GamesHub(state: s, onLevel: playLevel, onDaily: playDaily);

  Future<void> playDaily() async {
    if (requirePlan()) return;
    final toPlan = await openDaily(context, s);
    if (!mounted) return;
    if (toPlan) {
      go(1);
    } else {
      maybeCoach();
    }
  }

  Future<void> playLevel() async {
    if (requirePlan()) return;
    final toPlan = await openLevel(context, s);
    if (!mounted) return;
    if (toPlan) {
      go(1);
    } else {
      maybeCoach();
    }
  }

  Widget moreBody() => ListView(padding: const EdgeInsets.all(16), children: [
        CoachTarget(
            id: 'more.list',
            child: Column(children: [
        _routeTile('Комната и гардероб', 'Вещи и наряды',
            Icons.checkroom_outlined, room),
        _routeTile(
            'Дневник', 'Все движения монет', Icons.menu_book_outlined, history),
        _routeTile('Звания и рост', 'Наши достижения',
            Icons.workspace_premium_outlined, titles),
        _routeTile('Спокойной ночи', 'Как прошёл день', Icons.bedtime_outlined,
            daySummary),
        _routeTile('Словарик', 'Что значат слова',
            Icons.lightbulb_outline_rounded, glossary),
        _routeTile('Для взрослого', 'Настройки приложения',
            Icons.family_restroom_outlined, adults),
            ])),
        CoachTarget(
            id: 'more.coach',
            child: _routeTile('Обучение', 'Покажу, как всё устроено, ещё раз',
                Icons.school_outlined, () {
              s.resetCoach();
              toast('Хорошо! Сейчас я всё покажу.');
              go(0);
            })),
      ]);
  Widget _routeTile(String title, String description, IconData icon,
          VoidCallback action) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _Panel(
              padding: 4,
              child: ListTile(
                  minVerticalPadding: 12,
                  leading: Icon(icon, color: FinniColors.primary),
                  title: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(description),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: action)));

  void history() => section(
      'Дневник',
      (context) => ListView(padding: const EdgeInsets.all(16), children: [
            Text('День ${s.day}',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            if (s.dayHistory.isNotEmpty) ...[
              Text('Итоги прошлых дней',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final (i, entry) in s.dayHistory.indexed)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DayRecap(entry: entry, expanded: i == 0)),
              const SizedBox(height: 8),
              Text('Все движения монет',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
            ],
            if (s.wallet.journal.isEmpty)
              const _Notice(
                  icon: Icons.menu_book_outlined,
                  text:
                      'Здесь появятся покупки и пополнения. Старый баланс сохранён.'),
            for (final t in s.wallet.journal.reversed)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Panel(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Icon(switch (t.type) {
                            TransactionType.income => Icons.add_circle_outline,
                            TransactionType.expense =>
                              Icons.shopping_bag_outlined,
                            TransactionType.toSavings => Icons.savings_outlined,
                            TransactionType.fromSavings =>
                              Icons.arrow_upward_rounded
                          }),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(t.reasonText,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)))
                        ]),
                        const SizedBox(height: 8),
                        Text('${t.amount} монет · ${switch (t.type) {
                          TransactionType.income => "получено",
                          TransactionType.expense => "потрачено",
                          TransactionType.toSavings => "в копилку",
                          TransactionType.fromSavings => "из копилки"
                        }}'),
                      ]))),
            if (s.legacyCompletedTasks.isNotEmpty)
              Text(
                  'Сохранены задания прежней версии: ${s.legacyCompletedTasks.length}.'),
          ]));

  void room() => section(
      'Комната и гардероб',
      (context) => ListView(padding: const EdgeInsets.all(16), children: [
            SizedBox(
                height: 250,
                child: MoniScene(
                    stage: s.stage,
                    motion: s.motion,
                    outfit: s.outfit,
                    equipped: s.equipped)),
            const SizedBox(height: 16),
            Text('Гардероб', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('Надевать и снимать вещи можно бесплатно.'),
            const SizedBox(height: 16),
            for (final slot in [
              ('head', 'Голова'),
              ('eyes', 'Глаза'),
              ('neck', 'Шея'),
              ('body', 'Тело'),
              ('paw', 'Лапа'),
              ('back', 'Спина')
            ])
              Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _Panel(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        Text(slot.$2,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        if (!s.ownedItems.any((item) => item.slot == slot.$1))
                          const Text('Пока нет вещей в этом слоте',
                              style: TextStyle(color: FinniColors.muted)),
                        for (final item in s.ownedItems
                            .where((item) => item.slot == slot.$1))
                          Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: OutlinedButton.icon(
                                  onPressed: () => s.equip(item.id),
                                  icon: ItemArt(item.id,
                                      size: 36, background: false),
                                  label: Text(
                                      '${item.title} · ${s.outfit[slot.$1] == item.id ? 'снять' : 'надеть'}'))),
                      ]))),
            Text('В комнате', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (s.ownedItems.every((i) => i.slot.isNotEmpty) &&
                s.reachedGoals.isEmpty)
              const Text('Здесь появятся игрушки, мебель и сбывшиеся мечты.',
                  style: TextStyle(color: FinniColors.muted)),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final goal in s.reachedGoals)
                Column(mainAxisSize: MainAxisSize.min, children: [
                  ItemArt(goal.id, size: 72),
                  Text(goal.title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
              for (final item in s.ownedItems.where((i) => i.slot.isEmpty))
                Column(mainAxisSize: MainAxisSize.min, children: [
                  ItemArt(item.id, size: 64),
                  Text(item.title, style: const TextStyle(fontSize: 14)),
                ]),
            ]),
            const SizedBox(height: 16),
            const _PendingFeature(
                owner: 'Игорь',
                text:
                    'Расстановка мебели по местам комнаты и иллюстрации для всех вещей.'),
            const SizedBox(height: 16),
            Text('Отложенные желания',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (s.wishlist.isEmpty)
              const Text('Если вещь пока не по карману, сохрани её здесь.'),
            for (final item
                in s.content.shop.items.where((i) => s.wishlist.contains(i.id)))
              ListTile(
                  leading: ItemArt(item.id, size: 44),
                  title: Text(item.title),
                  subtitle: Text('${item.price} монет'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => purchase(item)),
          ]));

  void titles() => section(
      'Звания и рост',
      (context) => ListView(padding: const EdgeInsets.all(16), children: [
            SizedBox(
                height: 220,
                child: MoniScene(
                    stage: s.stage, motion: s.motion, outfit: s.outfit)),
            Text('${s.petName} растёт вместе с тобой',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            _Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Text('${s.stageLabel} · ${s.progress.growthPoints} опыта',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                      value: s.growthStatus.next == null
                          ? 1
                          : ((s.progress.growthPoints -
                                      (s.stage == PetStage.baby
                                          ? 0
                                          : s.growth.rules
                                              .thresholds[s.stage]!)) /
                                  (s.growth.rules
                                          .thresholds[s.growthStatus.next]! -
                                      (s.stage == PetStage.baby
                                          ? 0
                                          : s.growth.rules
                                              .thresholds[s.stage]!)))
                              .clamp(0.0, 1.0),
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(8)),
                  const SizedBox(height: 10),
                  Text(s.growthStatus.next == null
                      ? 'Взрослый друг! Впереди ещё новые звания.'
                      : 'До стадии «${s.growthStatus.nextLabel}» — ${s.growthStatus.pointsToNext} опыта'),
                  const SizedBox(height: 8),
                  const Text(
                      'Опыт получаем вечером: за нужные покупки, план, накопления и игры.'),
                ])),
            const SizedBox(height: 24),
            Text('Твои звания', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
                'Выбери полученное звание — оно появится рядом с именем. Новые звания открываются по итогам дня.'),
            const SizedBox(height: 12),
            for (final title in s.content.titles.titles)
              Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _Panel(
                      color: s.progress.currentTitleId == title.id
                          ? FinniColors.honey
                          : FinniColors.paper,
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                                s.progress.earnedTitles.contains(title.id)
                                    ? Icons.workspace_premium_rounded
                                    : Icons.lock_outline_rounded,
                                color:
                                    s.progress.earnedTitles.contains(title.id)
                                        ? FinniColors.gold
                                        : FinniColors.muted,
                                size: 30),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(title.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  Text(s.titles.reasonOf(title)),
                                  const SizedBox(height: 5),
                                  if (s.progress.currentTitleId == title.id)
                                    const Text('Выбрано',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800))
                                  else if (s.progress.earnedTitles
                                      .contains(title.id))
                                    TextButton(
                                        onPressed: () =>
                                            s.chooseTitle(title.id),
                                        child: const Text('Выбрать'))
                                  else
                                    const Text('Ещё впереди',
                                        style: TextStyle(
                                            color: FinniColors.muted)),
                                ])),
                          ]))),
          ]));
  void daySummary() => section('Спокойной ночи', (context) {
        final summaryDay = s.day;
        final todos = s.bedtimeTodos;
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Icon(Icons.bedtime_outlined,
              size: 48, color: FinniColors.purple),
          const SizedBox(height: 16),
          Text('Как прошёл день',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          for (final row in s.planFactRows)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(row.$1,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text('План ${row.$2} · факт ${row.$3}'),
                      Text('Разница: ${row.$3 - row.$2} монет')
                    ]))),
          _Notice(
              icon: todos.isEmpty
                  ? Icons.check_circle_outline_rounded
                  : Icons.lightbulb_outline_rounded,
              text: s.bedtimeHint),
          const SizedBox(height: 12),
          _Notice(
              icon: Icons.auto_awesome,
              text:
                  'Сегодня можно получить ${s.growth.pointsFor(s.growth.factorsOf(s.dayFacts))} опыта. После сна проверим новые звания и начнём следующий день.'),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: () => goToSleep(context, summaryDay),
              icon: const Icon(Icons.nightlight_round),
              label: const Text('Спокойной ночи')),
        ]);
      });

  void goToSleep(BuildContext sheetContext, int summaryDay) {
    final reminder = s.bedtimeReminder;
    void sleep() {
      if (s.closeDay(summaryDay)) Navigator.of(sheetContext).pop();
    }

    if (reminder == null) {
      sleep();
      return;
    }
    final texts = s.content.economy.bedtime;
    showDialog<void>(
        context: sheetContext,
        builder: (dialogContext) => AlertDialog(
              icon: const Text('🛒', style: TextStyle(fontSize: 40)),
              title: Text(reminder, textAlign: TextAlign.center),
              actionsAlignment: MainAxisAlignment.center,
              actionsOverflowDirection: VerticalDirection.down,
              actions: [
                if (s.bedtimeCanShop)
                  FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        Navigator.of(sheetContext).pop();
                        go(2);
                      },
                      icon: const Icon(Icons.storefront_outlined),
                      label: Text(texts.goShopping)),
                OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      sleep();
                    },
                    icon: const Icon(Icons.nightlight_round),
                    label: Text(texts.sleepAnyway)),
              ],
            ));
  }

  void showEvent() {
    final event = s.todayEvent;
    if (event == null || requirePlan()) return;
    s.openEvent();
    EventOutcome? outcome;
    sheet(
        s.eventHeader,
        StatefulBuilder(builder: (context, update) {
          final current = outcome;
          final done = current is EventResolved ? current : null;
          final short = current is EventShort ? current : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                  child: PopIn(
                      motion: s.motion,
                      child: EmojiBadge(event.iconId, size: 96))),
              const SizedBox(height: 12),
              Text(event.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(event.situation,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17)),
              const SizedBox(height: 16),
              if (done != null) ...[
                _Notice(icon: Icons.check_circle_outline, text: done.text),
                const SizedBox(height: 12),
                if (done.shifts.isNotEmpty) _ShiftList(done.shifts),
                const SizedBox(height: 8),
                FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(s.eventText('done'))),
              ] else ...[
                if (event.options.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(s.eventText('chooseHint'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: FinniColors.muted)),
                  ),
                if (short != null) ...[
                  _Notice(icon: Icons.lightbulb_outline, text: short.text),
                  const SizedBox(height: 12),
                ],
                for (final option in event.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FilledButton.tonal(
                      onPressed: () {
                        final result = s.resolveEvent(option.id);
                        if (result != null) update(() => outcome = result);
                      },
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.all(16)),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(option.label,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800))),
                          if (option.cost > 0)
                            _Pill(
                                icon: Icons.remove_rounded,
                                label: '${option.cost}',
                                color: FinniColors.lavender)
                          else if (option.coins > 0)
                            _Pill(
                                icon: Icons.add_rounded,
                                label: '${option.coins}',
                                color: FinniColors.mint)
                          else
                            const _Pill(
                                icon: Icons.favorite_border_rounded,
                                label: 'Бесплатно',
                                color: FinniColors.mint),
                        ],
                      ),
                    ),
                  ),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(s.eventText('postpone'))),
              ],
            ],
          );
        }));
  }

  void glossary() => section(
      'Словарик',
      (context) => ListView(padding: const EdgeInsets.all(16), children: [
            for (final entry in [
              (
                'Бюджет',
                'Все монеты, которыми ты можешь распорядиться. Например, утром у тебя 40 монет.'
              ),
              (
                'Обязательное',
                'То, без чего сейчас не обойтись. Например, еда для питомца.'
              ),
              (
                'Желаемое',
                'То, что радует, но может подождать. Например, новый бантик.'
              ),
              (
                'Накопления',
                'Монеты, которые ты сохранил на потом. Они лежат в копилке.'
              ),
              ('Цель', 'Вещь, на которую ты копишь. Например, самокат.'),
              (
                'План',
                'Твой выбор заранее: сколько потратить и сколько отложить.'
              ),
            ])
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Panel(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Icon(Icons.lightbulb_outline_rounded,
                            color: FinniColors.gold),
                        const SizedBox(height: 8),
                        Text(entry.$1,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(entry.$2)
                      ]))),
          ]));

  void adults() {
    final answer = TextEditingController();
    final random = math.Random();
    final a = 6 + random.nextInt(4);
    final b = 6 + random.nextInt(4);
    final expected = '${a * b}';
    String? message;
    sheet(
        'Для взрослого',
        StatefulBuilder(
            builder: (context, update) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          'Чтобы открыть настройки, решите пример: $a × $b.'),
                      const SizedBox(height: 16),
                      TextField(
                          controller: answer,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: 'Ответ', errorText: message),
                          onSubmitted: (value) {
                            if (value.trim() == expected) {
                              Navigator.pop(context);
                              adultSettings();
                            } else {
                              update(() => message = 'Попробуйте ещё раз');
                            }
                          }),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                          onPressed: () {
                            if (answer.text.trim() == expected) {
                              Navigator.pop(context);
                              adultSettings();
                            } else {
                              update(() => message = 'Попробуйте ещё раз');
                            }
                          },
                          icon: const Icon(Icons.lock_open_rounded),
                          label: const Text('Открыть настройки')),
                    ]))).whenComplete(answer.dispose);
  }

  void adultSettings() => section(
      'Настройки для взрослого',
      (context) => ListView(padding: const EdgeInsets.all(16), children: [
            const _Notice(
                icon: Icons.school_outlined,
                text:
                    'Игра помогает различать нужное и желаемое, планировать расходы и копить на цель. Настоящие деньги не используются.'),
            const SizedBox(height: 16),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Анимации питомца'),
                subtitle: const Text(
                    'Системное отключение движений тоже учитывается'),
                value: s.motion,
                onChanged: s.setMotion),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Попроще'),
                subtitle:
                    const Text('Игры станут проще: меньше карточек и чисел'),
                value: s.simpleMode,
                onChanged: s.setSimple),
            const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.volume_off_outlined),
                title: Text('Звук пока не подключён'),
                subtitle:
                    Text('Игорь / команда. Все подсказки доступны текстом.')),
            const SizedBox(height: 16),
            const _PendingFeature(
                owner: 'Матвей, Юля',
                text:
                    'Демонстрационный режим с отдельным профилем и пропуском ожидания. Основной профиль не должен изменяться.'),
            const SizedBox(height: 20),
            _routeTile(
                'Учебный прогресс',
                'Пройдено игр: ${s.tasks.completedTaskIds.length} из ${s.content.tasks.tasks.length}',
                Icons.school_outlined,
                titles),
            for (final theme in s.content.tasks.themes)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                      '${theme.title}: ${s.content.tasks.byTheme(theme.id).every((t) => s.tasks.isCompleted(t.id)) ? 'тема пройдена' : 'тема в процессе'}')),
            Text('Питомец: ${s.petName}'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: () => renamePet(),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Изменить имя питомца')),
            const SizedBox(height: 24),
            OutlinedButton.icon(
                onPressed: () => confirmProfileAction(false),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Начать заново')),
            const SizedBox(height: 8),
            TextButton.icon(
                onPressed: () => confirmProfileAction(true),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Удалить локальный профиль')),
          ]));
  void renamePet() => sheet(
      'Имя питомца',
      NamePicker(
          initial: s.petName,
          names: [for (final name in s.config['names'] as List) '$name'],
          buttonLabel: 'Сохранить имя',
          onDone: (name) {
            s.renamePet(name);
            Navigator.of(context).pop();
          }));
  void confirmProfileAction(bool delete) {
    bool busy = false;
    String? error;
    sheet(
        delete ? 'Удалить профиль?' : 'Начать заново?',
        StatefulBuilder(
            builder: (context, update) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(delete
                          ? 'Покупки, монеты и учебный прогресс будут удалены с этого устройства. Отменить это действие нельзя.'
                          : 'Текущий прогресс будет заменён новым профилем. Отменить это действие нельзя.'),
                      const SizedBox(height: 16),
                      if (error != null) Text(error!),
                      FilledButton.icon(
                          onPressed: busy
                              ? null
                              : () async {
                                  update(() => busy = true);
                                  try {
                                    if (delete) {
                                      await s.deleteProfile();
                                    } else {
                                      await s.resetProfile();
                                    }
                                    if (context.mounted) {
                                      Navigator.of(context)
                                          .popUntil((route) => route.isFirst);
                                    }
                                  } catch (_) {
                                    if (context.mounted) {
                                      update(() {
                                        busy = false;
                                        error =
                                            'Не получилось сохранить изменение. Попробуйте ещё раз.';
                                      });
                                    }
                                  }
                                },
                          icon: const Icon(Icons.check_rounded),
                          label: Text(busy
                              ? 'Сохраняем…'
                              : delete
                                  ? 'Да, удалить'
                                  : 'Да, начать заново')),
                      TextButton(
                          onPressed: busy ? null : () => Navigator.pop(context),
                          child: const Text('Отмена')),
                    ])));
  }
}

class _PendingFeature extends StatelessWidget {
  const _PendingFeature({required this.owner, required this.text});
  final String owner, text;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: FinniColors.sky, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.construction_outlined, size: 24),
          SizedBox(width: 8),
          Expanded(
              child: Text('В разработке',
                  style: TextStyle(fontWeight: FontWeight.w800)))
        ]),
        const SizedBox(height: 8),
        Text(text),
        const SizedBox(height: 8),
        Text('Ответственные: $owner',
            style: const TextStyle(color: FinniColors.muted)),
      ]));
}
