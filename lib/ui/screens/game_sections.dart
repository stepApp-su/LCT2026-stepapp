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

  String priceComparison(ShopItem item) {
    final food = s.catalog.firstWhere((e) => e.id == 'food');
    if (item.id == 'food') return 'Это одна порция еды для питомца.';
    if (item.price == food.price) {
      return 'Это столько же, сколько одна порция еды.';
    }
    if (item.price > food.price) {
      return 'Порция еды стоит ${food.price} монет. Эта покупка дороже на ${item.price - food.price}.';
    }
    return 'Порция еды стоит ${food.price} монет. Эта покупка дешевле на ${food.price - item.price}.';
  }

  void savings() => section(
      'Мечта и копилка',
      (context) => ListView(padding: const EdgeInsets.all(16), children: [
            _Panel(
                color: FinniColors.lavender,
                child: Column(children: [
                  const Icon(Icons.savings_outlined,
                      size: 48, color: FinniColors.purple),
                  const SizedBox(height: 12),
                  Text(s.goal,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text('${s.wallet.wallet.savings} из ${s.target} монет',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  _Progress(
                      value: s.wallet.wallet.savings / s.target,
                      color: FinniColors.purple),
                  const SizedBox(height: 12),
                  Text('Осталось ${s.left} монет'),
                ])),
            const SizedBox(height: 16),
            _Notice(
                icon: Icons.lightbulb_outline_rounded,
                text: s.daysToGoal == null
                    ? 'Выбери в плане сумму для копилки, чтобы посчитать срок.'
                    : 'По плану ты откладываешь ${s.plan.plan.savings} монет в день. Осталось ${s.left}. Это ещё ${s.daysToGoal} дн.'),
            const SizedBox(height: 20),
            FilledButton.icon(
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
            const SizedBox(height: 20),
            const _PendingFeature(
                owner: 'Матвей, Юля',
                text:
                    'Выдача достигнутой цели в комнату и промежуточные награды. Накопления уже сохраняются.'),
          ]));

  void transfer(bool withdrawal) {
    int amount = 5;
    final max = withdrawal ? s.wallet.wallet.savings : s.wallet.wallet.balance;
    if (max < amount) amount = max;
    sheet(withdrawal ? 'Взять из копилки' : 'Пополнить копилку',
        StatefulBuilder(builder: (context, update) {
      final before = s.wallet.wallet.savings,
          after = before + (withdrawal ? -amount : amount);
      String days(int value) => s.daysFor(value) == null
          ? 'пока без срока'
          : '${s.daysFor(value)} дн.';
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconButton.filledTonal(
              tooltip: 'Уменьшить сумму',
              onPressed: amount > 5 ? () => update(() => amount -= 5) : null,
              icon: const Icon(Icons.remove_rounded)),
          Expanded(child: Center(child: _Coins(amount))),
          IconButton.filledTonal(
              tooltip: 'Увеличить сумму',
              onPressed:
                  amount + 5 <= max ? () => update(() => amount += 5) : null,
              icon: const Icon(Icons.add_rounded))
        ]),
        const SizedBox(height: 16),
        Text('В копилке: $before → $after монет'),
        const SizedBox(height: 8),
        Text('До мечты: ${days(before)} → ${days(after)}'),
        const SizedBox(height: 20),
        FilledButton.icon(
            onPressed: amount > 0
                ? () {
                    final ok =
                        withdrawal ? s.withdraw(amount) : s.saveCoins(amount);
                    if (ok) Navigator.pop(context);
                  }
                : null,
            icon: Icon(withdrawal
                ? Icons.arrow_upward_rounded
                : Icons.savings_outlined),
            label: Text(withdrawal ? 'Да, взять $amount' : 'Отложить $amount')),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
      ]);
    }));
  }

  void chooseGoal() => section(
      'Выбери мечту',
      (context) => ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Всё накопленное останется в копилке.'),
            const SizedBox(height: 16),
            for (final goal in s.goals)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Panel(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        Text(goal['title'] as String,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        _Coins(goal['price'] as int),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                            onPressed: goal['id'] == s.goalId
                                ? null
                                : () => sheet(
                                    'Сменить мечту?',
                                    Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                              'Будем копить на «${goal['title']}». Все ${s.wallet.wallet.savings} монет сохранятся.'),
                                          const SizedBox(height: 16),
                                          FilledButton.icon(
                                              onPressed: () {
                                                s.changeGoal(
                                                    goal['id'] as String);
                                                Navigator.of(context).pop();
                                              },
                                              icon: const Icon(
                                                  Icons.check_rounded),
                                              label: const Text('Да, сменить'))
                                        ])),
                            icon: Icon(goal['id'] == s.goalId
                                ? Icons.check_rounded
                                : Icons.flag_outlined),
                            label: Text(goal['id'] == s.goalId
                                ? 'Текущая мечта'
                                : 'Выбрать')),
                      ]))),
          ]));
  void tasks() => go(3);
  Widget tasksBody(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        Text('Учимся на маленьких решениях',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _Panel(
            color: FinniColors.sky,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.extension_outlined, size: 36),
                  const SizedBox(height: 12),
                  Text(s.question['title'] as String,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(s.completed
                      ? 'Пройдено · награда уже в кошельке'
                      : 'Нужное и желаемое · ${s.question['reward']} монет'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: questionExercise,
                      icon: Icon(s.completed
                          ? Icons.replay_rounded
                          : Icons.play_arrow_rounded),
                      label: Text(
                          s.completed ? 'Посмотреть объяснение' : 'Начать')),
                ])),
        const SizedBox(height: 20),
        for (final entry in [
          (
            Icons.swap_horiz_rounded,
            'Разложи по корзинам',
            'Перетаскивание в «Нужное» и «Желаемое».'
          ),
          (
            Icons.shopping_basket_outlined,
            'Собери покупки',
            'Выбор товаров в пределах бюджета.'
          ),
          (
            Icons.pie_chart_outline_rounded,
            'Распредели монеты',
            'Счётчики по направлениям с остатком.'
          )
        ])
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _Panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Icon(entry.$1, size: 28),
                    const SizedBox(height: 8),
                    Text(entry.$2,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(entry.$3),
                    const SizedBox(height: 12),
                    const _PendingFeature(
                        owner: 'Макс, Юля',
                        text:
                            'Нужны схема контента, проверка ответа и правила награды.'),
                  ]))),
      ]);

  Widget moreBody() => ListView(padding: const EdgeInsets.all(16), children: [
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
                    motion: s.motion, outfit: s.outfit, equipped: s.equipped)),
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
                        if (!s.catalog.any((item) =>
                            s.details(item.id)['slot'] == slot.$1 &&
                            s.owned.contains(item.id)))
                          const Text('Пока нет вещей в этом слоте',
                              style: TextStyle(color: FinniColors.muted)),
                        for (final item in s.catalog.where((item) =>
                            s.details(item.id)['slot'] == slot.$1 &&
                            s.owned.contains(item.id)))
                          OutlinedButton.icon(
                              onPressed: () => s.equip(item.id),
                              icon: Icon(s.outfit[slot.$1] == item.id
                                  ? Icons.check_rounded
                                  : Icons.add_rounded),
                              label: Text(
                                  '${item.title} · ${s.outfit[slot.$1] == item.id ? 'снять' : 'надеть'}')),
                      ]))),
            const _PendingFeature(
                owner: 'Игорь; Матвей, Юля',
                text:
                    'Иллюстрации мебели и постоянные предметы достигнутых целей. Удаление достижений не предусмотрено.'),
            const SizedBox(height: 16),
            Text('Отложенные желания',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (s.wishlist.isEmpty)
              const Text('Если вещь пока не по карману, сохрани её здесь.'),
            for (final item
                in s.catalog.where((i) => s.wishlist.contains(i.id)))
              ListTile(
                  title: Text(item.title),
                  subtitle: Text('${item.price} монет'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => purchase(item)),
          ]));

  void titles() => section(
      'Звания и рост',
      (context) => ListView(padding: const EdgeInsets.all(16), children: [
            const Icon(Icons.workspace_premium_outlined,
                size: 56, color: FinniColors.purple),
            const SizedBox(height: 20),
            Text('Каждое решение — новый опыт',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            _Notice(
                icon: Icons.check_circle_outline,
                text:
                    'Задание: ${s.completed ? 'пройдено' : 'можно начать'}. В копилке ${s.wallet.wallet.savings} монет.'),
            const SizedBox(height: 20),
            const _PendingFeature(
                owner: 'Макс, Юля',
                text:
                    'Очки развития, стадии и правила званий. Звания появятся после подключения сервиса прогресса; сейчас они не выдаются за покупки.'),
          ]));
  void daySummary() => section('Спокойной ночи', (context) {
        int actual(ExpenseCategory category) => s.wallet.journal
            .where((t) =>
                t.dayNumber == s.day &&
                t.type == TransactionType.expense &&
                t.category == category)
            .fold(0, (sum, t) => sum + t.amount);
        final savings =
            s.wallet.journal.where((t) => t.dayNumber == s.day).fold(
                0,
                (sum, t) =>
                    sum +
                    (t.type == TransactionType.toSavings
                        ? t.amount
                        : t.type == TransactionType.fromSavings
                            ? -t.amount
                            : 0));
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Icon(Icons.bedtime_outlined,
              size: 48, color: FinniColors.purple),
          const SizedBox(height: 16),
          Text('Как прошёл день',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          for (final row in [
            (
              'Обязательное',
              s.plan.plan.mandatory,
              actual(ExpenseCategory.mandatory)
            ),
            (
              'Желаемое',
              s.plan.plan.optional,
              actual(ExpenseCategory.optional)
            ),
            ('Копилка', s.plan.plan.savings, savings)
          ])
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
          const _PendingFeature(
              owner: 'Матвей, Юля; Макс, Юля',
              text:
                  'Закрытие дня, объяснение последствий и рост питомца. Здесь показаны реальные операции, но день пока не закрывается.'),
          const SizedBox(height: 16),
          const FilledButton(
              onPressed: null, child: Text('Переход к новому дню в работе')),
        ]);
      });
  void glossary() => section(
      'Словарик',
      (context) => ListView(padding: const EdgeInsets.all(16), children: [
            for (final entry in [
              (
                'Бюджет',
                'Все монеты, которыми ты можешь распорядиться. Например, сегодня у тебя 60 монет.'
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
    String? message;
    sheet(
        'Для взрослого',
        StatefulBuilder(
            builder: (context, update) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                          'Чтобы открыть настройки, решите пример: 7 × 8.'),
                      const SizedBox(height: 16),
                      TextField(
                          controller: answer,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: 'Ответ', errorText: message),
                          onSubmitted: (value) {
                            if (value.trim() == '56') {
                              Navigator.pop(context);
                              adultSettings();
                            } else {
                              update(() => message = 'Попробуйте ещё раз');
                            }
                          }),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                          onPressed: () {
                            if (answer.text.trim() == '56') {
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
                    const Text('Подбор по сложности подключают Макс и Юля'),
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
                s.completed
                    ? 'Нужное и желаемое: пройдено'
                    : 'Нужное и желаемое: в процессе',
                Icons.school_outlined,
                titles),
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
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final name in s.config['names'] as List)
          ActionChip(
              label: Text(name as String),
              onPressed: () {
                s.createPet(name, s.simpleMode);
                Navigator.of(context).pop();
              },
              padding: const EdgeInsets.all(12))
      ]));
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
