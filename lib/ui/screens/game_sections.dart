part of 'game_shell.dart';

extension _GameSections on _GameShellState {
  void section(String title, Widget Function(BuildContext) content,
      {String? tour}) {
    Navigator.of(context).push<void>(MaterialPageRoute(
      settings: RouteSettings(name: title),
      builder: (context) => Scaffold(
        appBar: AppBar(
            toolbarHeight: MediaQuery.textScalerOf(context).scale(22) * 2.7 + 8,
            title: Text(title, maxLines: 2),
            leading: CoachTarget(
                id: 'section.back',
                child: IconButton(
                    tooltip: 'Назад',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded))),
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
                    child: _TourStarter(
                        state: s,
                        tour: tour,
                        child: AnimatedBuilder(
                            animation: s,
                            builder: (context, _) => content(context)))))),
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
            const SizedBox(height: 12),
            _ReserveCard(state: s),
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
            CoachTarget(
                id: 'savings.withdraw',
                child: OutlinedButton.icon(
                    onPressed: s.wallet.wallet.savings > 0
                        ? () => transfer(true)
                        : null,
                    icon: const Icon(Icons.arrow_upward_rounded),
                    label: const Text('Взять из копилки'))),
            const SizedBox(height: 8),
            CoachTarget(
                id: 'savings.change',
                child: TextButton.icon(
                    onPressed: chooseGoal,
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Выбрать другую мечту'))),
          ],
          if (reached.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Сбывшиеся мечты',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            EqualGrid(columns: 3, spacing: 12, runSpacing: 12, children: [
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
          id: 'more.profile',
          child: Column(children: [
        Center(
          child: SizedBox(
            height: 150,
            width: 180,
            child: IgnorePointer(
              child: MoniScene(
                  stage: s.stage, motion: s.motion, outfit: s.outfit),
            ),
          ),
        ),
        Center(
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(s.petName,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900)),
              TagChip(s.stageLabel, tone: TagTone.green),
              TagChip('🏅 ${s.currentTitle?.title ?? 'Новичок'}',
                  tone: TagTone.gold),
            ],
          ),
        ),
          ]),
        ),
        const SizedBox(height: 16),
        CoachTarget(
          id: 'more.list',
          child: LayoutBuilder(builder: (context, c) {
            final columns =
                MediaQuery.textScalerOf(context).scale(16) > 22 ? 2 : 3;
            final width = (c.maxWidth - (columns - 1) * 10) / columns;
            return EqualGrid(columns: columns, spacing: 10, runSpacing: 10, children: [
              for (final (id, label, art, action, news) in [
                ('more.wardrobe', 'Гардероб', const RoomArt('bow', size: 44), room, s.hasNewThings),
                ('more.titles', 'Звания', const Text('🏅', style: TextStyle(fontSize: 34)), titles, false),
                ('more.diary', 'Дневник', const Text('📒', style: TextStyle(fontSize: 34)), history, false),
                ('more.summary', 'Итоги', const Text('🌙', style: TextStyle(fontSize: 34)), daySummary, false),
                ('more.glossary', 'Словарик', const Text('💡', style: TextStyle(fontSize: 34)), glossary, false),
              ])
                SizedBox(
                    width: width,
                    child: CoachTarget(
                        id: id,
                        child: _MoreTile(
                            label: label, art: art, news: news, onTap: action))),
              SizedBox(
                width: width,
                child: CoachTarget(
                  id: 'more.coach',
                  child: _MoreTile(
                    label: 'Обучение',
                    art: const Text('🎓', style: TextStyle(fontSize: 34)),
                    onTap: () {
                      s.resetCoach();
                      toast('Хорошо! Сейчас я всё покажу.');
                      go(0);
                    },
                  ),
                ),
              ),
            ]);
          }),
        ),
        const SizedBox(height: 14),
        Material(
          color: FinniColors.sky,
          borderRadius: BorderRadius.circular(18),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            leading: const Icon(Icons.lock_outline_rounded, color: FinniColors.blue),
            title: const Text('Для взрослого',
                style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Настройки и успехи ребёнка'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: adults,
          ),
        ),
      ]);

  void history() =>
      section('Дневник', (context) => _DiaryPage(state: s), tour: 'diary');

  void room([int tab = 0]) => section(
      'Гардероб и комната', (context) => _RoomPage(shell: this, tab: tab),
      tour: 'room');

  void titles() => section(
      'Звания и рост',
      (context) => _TitlesView(state: s, onChange: chooseTitle),
      tour: 'titles');

  void chooseTitle() => sheet(
      'Сменить звание',
      AnimatedBuilder(
        animation: s,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Выбери звание, оно появится рядом с именем.',
                style: TextStyle(color: FinniColors.muted)),
            const SizedBox(height: 10),
            for (final title in s.content.titles.titles)
              if (s.progress.earnedTitles.contains(title.id))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _Panel(
                    padding: 4,
                    color: s.progress.currentTitleId == title.id
                        ? FinniColors.honey
                        : FinniColors.paper,
                    child: ListTile(
                      title: Text(title.title,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(s.titles.reasonOf(title)),
                      trailing: s.progress.currentTitleId == title.id
                          ? const TagChip('✓ выбрано', tone: TagTone.green)
                          : const TagChip('выбрать', tone: TagTone.gold),
                      onTap: () => s.chooseTitle(title.id),
                    ),
                  ),
                ),
          ],
        ),
      ));

  void daySummary() {
    final summaryDay = s.day;
    Navigator.of(context).push<void>(MaterialPageRoute(
      settings: const RouteSettings(name: 'Спокойной ночи'),
      builder: (_) => _TourStarter(
        state: s,
        tour: 'summary',
        child: BedtimeScreen(
        state: s,
        onSleep: (screenContext) => goToSleep(screenContext, summaryDay),
        onTodo: (screenContext, todo) {
          Navigator.of(screenContext).pop();
          switch (todo) {
            case BedtimeTodo.plan:
              go(1);
            case BedtimeTodo.needs:
              go(2);
            case BedtimeTodo.task:
              if (s.levelDoneToday) {
                unawaited(playDaily());
              } else {
                unawaited(playLevel());
              }
            case BedtimeTodo.event:
              showEvent();
          }
        },
      ),
      ),
    ));
  }

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

  void glossary() =>
      section('Словарик', (context) => _GlossaryPage(state: s),
          tour: 'glossary');

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
                              s.fx('not_enough');
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
                              s.fx('not_enough');
                              update(() => message = 'Попробуйте ещё раз');
                            }
                          },
                          icon: const Icon(Icons.lock_open_rounded),
                          label: const Text('Открыть настройки')),
                    ]))).whenComplete(answer.dispose);
  }

  void adultSettings() =>
      section('Для взрослого', (context) => _AdultView(shell: this));
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

class _MoreTile extends StatelessWidget {
  const _MoreTile(
      {required this.label,
      required this.art,
      required this.onTap,
      this.news = false});
  final String label;
  final Widget art;
  final VoidCallback onTap;
  final bool news;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Squish(
          onTap: onTap,
          child: _Panel(
            padding: 10,
            radius: 20,
            child: Stack(clipBehavior: Clip.none, children: [
              Column(children: [
                SizedBox(height: 46, child: Center(child: art)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ]),
              if (news) const Positioned(right: 0, top: 0, child: _NewDot()),
            ]),
          ),
        ),
      );
}

class _TourStarter extends StatefulWidget {
  const _TourStarter({required this.state, required this.tour, required this.child});
  final GameController state;
  final String? tour;
  final Widget child;
  @override
  State<_TourStarter> createState() => _TourStarterState();
}

class _TourStarterState extends State<_TourStarter> {
  GameController get s => widget.state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => Future.delayed(
            const Duration(milliseconds: 350), _start));
  }

  Future<void> _start() async {
    final id = widget.tour;
    if (!mounted || id == null || s.coachSeen(id) || !s.onboarded) return;
    if (Coach.busy(context)) return;
    final tour = s.coach.tour(id);
    if (tour == null) return;
    final finished = await Coach.run(context,
        steps: tour.steps,
        texts: s.coach.texts,
        title: tour.title,
        values: {'name': s.petName},
        motion: s.motion);
    s.markCoachSeen(tour.seenAfter(finished: finished));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
