import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../../domain/ru_words.dart';
import '../../domain/services/goal_service.dart';
import '../../domain/services/plan_service.dart';
import '../../domain/services/shop_service.dart';
import '../../domain/services/title_service.dart';
import '../../domain/services/wallet_service.dart';
import '../games/games_hub.dart';
import '../games/level_screen.dart';
import '../games/quests.dart';
import '../theme/finni_theme.dart';
import '../widgets/emoji_art.dart';
import '../widgets/finni_ui.dart';
import '../widgets/moni_scene.dart';
import '../widgets/name_picker.dart';
import '../widgets/pet_celebration.dart';
import '../widgets/room_view.dart';
import '../widgets/bedtime_screen.dart';
import '../widgets/coach.dart';
import '../widgets/coin_icon.dart';
import '../widgets/day_end.dart';
import '../widgets/game_icon.dart';
import '../game_controller.dart';

part 'game_sections.dart';
part '../widgets/game_components.dart';
part 'more_pages.dart';

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
  bool coachQueued = false;
  GameController get s => widget.state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && s.bubble == null) s.greet();
      if (mounted) showCelebration();
      maybeCoach();
    });
    s.addListener(showCelebration);
    s.addListener(maybeCoach);
    idleTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted && page == 0 && ModalRoute.of(context)?.isCurrent == true) {
        s.idle();
      }
    });
  }

  @override
  void dispose() {
    s.removeListener(showCelebration);
    s.removeListener(maybeCoach);
    idleTimer?.cancel();
    super.dispose();
  }

  void showCelebration() {
    if (!mounted || celebrating || s.celebration == null) return;
    celebrating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final event = Map<String, dynamic>.of(s.celebration!);
      String? next;
      if (event['kind'] == 'night') {
        next = await showDayEnd(context, s, event);
      } else {
        await showDialog<void>(
            context: context,
            useRootNavigator: false,
            barrierDismissible: false,
            builder: (_) => PetCelebration(state: s, event: event));
      }
      if (!mounted) return;
      s.acknowledgeCelebration();
      celebrating = false;
      if (next == 'plan') go(1);
      maybeCoach();
    });
  }

  void maybeCoach() {
    if (coachQueued || !mounted) return;
    coachQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      coachQueued = false;
      unawaited(coachNow());
    });
  }

  String? get pendingTour {
    final ids = switch (page) {
      0 => [
          'home',
          'shopping',
          'piggy',
          'work',
          if (s.eventPending) 'event',
          if (s.bedtimeReady && !s.needsPlan) 'bedtime',
          if (s.dailyTask != null && !s.dailyDoneToday && !s.needsPlan) 'daily',
        ],
      1 => ['plan'],
      2 => ['shop'],
      3 => ['hub'],
      _ => ['more'],
    };
    for (final id in ids) {
      final tour = s.coach.tour(id);
      if (tour == null || s.coachSeen(id)) continue;
      final requires = tour.requires;
      if (requires != null && !(coachConditions[requires]?.call() ?? false)) continue;
      return id;
    }
    return null;
  }

  Map<String, bool Function()> get coachConditions => {
        'planConfirmed': () => s.plan.isConfirmed,
        'needsPaid': () => s.unpaidNeeds.isEmpty,
        'wantBought': () => s.wantBought,
        'wantsPlanned': () => s.fullPlan.optional > 0,
        'noWants': () => s.fullPlan.optional <= 0,
        'savedAll': () => s.savingsToDeposit <= 0,
        'onHome': () => page == 0,
        'nothingSaved': () => s.savedToday <= 0,
        'somethingSaved': () => s.savedToday > 0,
      };

  Future<void> coachNow() async {
    if (!mounted || celebrating || s.celebration != null || !s.onboarded) return;
    if (ModalRoute.of(context)?.isCurrent == false || Coach.busy(context)) return;
    final id = pendingTour;
    final tour = id == null ? null : s.coach.tour(id);
    if (tour == null) return;
    final finished = await Coach.run(
      context,
      steps: tour.steps,
      texts: s.coach.texts,
      title: tour.title,
      values: {
        'name': s.petName,
        'income': '${s.plan.plan.income}',
      },
      conditions: coachConditions,
      motion: s.motion,
    );
    s.markCoachSeen(tour.seenAfter(finished: finished));
    maybeCoach();
  }

  void go(int value) {
    setState(() => page = value);
    maybeCoach();
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
      case 'room':
        room(1);
      case 'wardrobe':
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
              'Каждый день начинается с плана: разложи монеты на обязательное, желаемое и копилку. Потом можно играть, покупать и копить. Нажми на питомца, чтобы погладить. Внизу — план, магазин, игры и другие разделы.',
            1 =>
              'Сначала подумай, что нужно сегодня. Разложи монеты по трём направлениям. План — это твой выбор, а не списание денег. Потом трать по плану, а монеты для копилки отложи кнопкой «Отложить в копилку». Если заработаешь ещё монеты, здесь появится окошко, чтобы разложить и их.',
            2 =>
              'Обязательное — то, без чего никак. Желаемое — то, что радует. Сверху видно, сколько осталось по плану. Старайся в него укладываться: если потратишь на желаемое больше, в копилку попадёт меньше, и мечта отодвинется. Если монет не хватает, их можно взять из копилки — но только если очень нужно.',
            3 =>
              'Пройди уровень дня — за каждую игру в нём дают часть зарплаты. Задание дня появляется раз в сутки, оно посложнее. Остальные игры — тренировка: монет за них нет, зато звёзды копятся.',
            _ =>
              'Здесь можно переодеть питомца, посмотреть дневник и итоги прошлых дней, узнать новые слова и уложить питомца спать. Настройки находятся в разделе для взрослого.',
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
                        if (page != 0)
                          _PageHeader(
                              title: const [
                                '',
                                'План на день',
                                'Магазин',
                                'Игры',
                                'Ещё'
                              ][page],
                              onHelp: help),
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

  static const BorderRadius _archRadius = BorderRadius.vertical(
      top: Radius.circular(150), bottom: Radius.circular(48));

  List<RoomPiece> get roomPieces {
    final pieces = <RoomPiece>[];
    for (final spot in s.room.spots) {
      final id = switch (spot.type) {
        RoomSpotType.item => s.placedAt(spot)?.id,
        RoomSpotType.goal => s.goalAt(spot)?.id,
        RoomSpotType.wallpaper => null,
      };
      if (id != null) pieces.add(RoomPiece(spot, id));
    }
    return pieces;
  }

  bool get roomWindow => roomPieces.any((piece) =>
      piece.spot.layer == 'windowView' || piece.spot.id.startsWith('sill'));

  Widget home() => LayoutBuilder(builder: (context, constraints) {
        final enlarged = MediaQuery.textScalerOf(context).scale(16) > 20;
        final petHeight = enlarged
            ? 300.0
            : (constraints.maxHeight - 400).clamp(240.0, 440.0);
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(children: [
              CoachTarget(
                id: 'home.goal',
                child: Semantics(
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
              ),
              const SizedBox(height: 8),
              CoachTarget(
                id: 'home.coins',
                child: Row(children: [
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
              ),
              const SizedBox(height: 8),
              CoachTarget(
                id: 'home.pet',
                child: SizedBox(
                  height: petHeight,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                          top: 26,
                          bottom: 0,
                          child: Semantics(
                            button: true,
                            label: 'Комната питомца',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => room(1),
                              child: ClipRRect(
                                borderRadius: _archRadius,
                                child: RoomLayer(
                                  pieces: const [],
                                  wallpaperId: s.wallpaperId,
                                  window: roomWindow,
                                ),
                              ),
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
                          top: 26,
                          bottom: 0,
                          child: IgnorePointer(
                            child: ClipRRect(
                              borderRadius: _archRadius,
                              child: RoomLayer(pieces: roomPieces),
                            ),
                          )),
                      Positioned.fill(
                          top: 14,
                          bottom: 4,
                          child: IgnorePointer(
                            child: MoniScene(
                              stage: s.stage,
                              outfit: s.outfit,
                              motion: s.motion,
                              equipped: s.equipped,
                            ),
                          )),
                      Positioned.fill(
                          top: 26,
                          bottom: 0,
                          child: IgnorePointer(
                            child: ClipRRect(
                              borderRadius: _archRadius,
                              child: RoomLayer(
                                  pieces: roomPieces, front: true),
                            ),
                          )),
                      if (s.roomEmpty)
                        Positioned(
                          right: 8,
                          bottom: 12,
                          child: _RoomButton(
                              news: s.hasNewThings, onTap: () => room(1)),
                        )
                      else if (s.hasNewThings)
                        const Positioned(
                          right: 22,
                          top: 44,
                          child: _NewDot(),
                        ),
                      Positioned(
                          left: 8,
                          right: 48,
                          top: 4,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 0,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(s.petName,
                                        style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(width: 8),
                                    TagChip(s.stageLabel,
                                        tone: TagTone.green),
                                    const SizedBox(width: 5),
                                    TagChip(
                                        '🏅 ${s.currentTitle?.title ?? 'Новичок'}',
                                        tone: TagTone.gold),
                                  ],
                                ),
                              ])),
                      Positioned(
                          right: 0,
                          top: 0,
                          child: CoachTarget(
                              id: 'home.help',
                              child: IconButton(
                                  tooltip: 'Подсказка',
                                  onPressed: help,
                                  icon: const Icon(Icons.help_outline_rounded)))),
                      if (s.todayEvent case final event? when s.eventPending)
                        Positioned(
                            left: 8,
                            bottom: 14,
                            child: CoachTarget(
                              id: 'home.event',
                              child: Semantics(
                              button: true,
                              label: '${s.eventHeader}: ${event.title}',
                              excludeSemantics: true,
                              child: Squish(
                                onTap: showEvent,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: FinniColors.honey,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: FinniColors.shadow,
                                          blurRadius: 8,
                                          offset: Offset(0, 3)),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      EmojiBadge(event.iconId,
                                          size: 30, color: FinniColors.paper),
                                      const SizedBox(width: 8),
                                      Text(s.eventHeader,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                ),
                              ),
                            ))),
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
              ),
              const SizedBox(height: 8),
              CoachTarget(
                id: 'home.stats',
                child: LayoutBuilder(builder: (context, constraints) {
                final columns =
                    MediaQuery.textScalerOf(context).scale(13) > 19 ? 1 : 2;
                final width =
                    ((constraints.maxWidth - (columns - 1) * 8) / columns).clamp(0.0, double.infinity);
                return EqualGrid(
                    columns: columns,
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
              ),
              const SizedBox(height: 12),
              HomeQuests(
                state: s,
                onLevel: playLevel,
                onDaily: playDaily,
                onPractice: () => go(3),
                onBedtime: daySummary,
                onPlan: () => go(1),
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
                CoachTarget(
                  id: 'plan.income',
                  child: _Panel(
                      color: FinniColors.mint,
                      padding: 12,
                      child: Row(children: [
                        const Expanded(
                            child: Text('Доход дня',
                                style: TextStyle(fontWeight: FontWeight.w700))),
                        _Coins(s.plan.plan.income)
                      ])),
                ),
                const SizedBox(height: 8),
                CoachTarget(id: 'plan.needs', child: _NeedsToday(state: s)),
                if (s.earnedToday > 0) ...[
                  const SizedBox(height: 8),
                  _Panel(
                      color: FinniColors.honey.withValues(alpha: .5),
                      padding: 12,
                      child: Row(children: [
                        const Expanded(
                            child: Text('Заработано сегодня',
                                style: TextStyle(fontWeight: FontWeight.w700))),
                        _Coins(s.earnedToday)
                      ])),
                ],
                if (s.extraPending > 0) ...[
                  const SizedBox(height: 12),
                  _ExtraPlanner(state: s, onDone: toast),
                ],
                const SizedBox(height: 12),
                const Text('Каждый шаг — 5 монет.',
                    style: TextStyle(color: FinniColors.muted)),
                const SizedBox(height: 12),
                CoachTarget(
                  id: 'plan.mandatory',
                  child: _BudgetRow(
                    title: 'Обязательное',
                    subtitle: 'То, без чего никак',
                    icon: Icons.restaurant_outlined,
                    color: FinniColors.mint,
                    value: s.plan.plan.mandatory,
                    direction: PlanDirection.mandatory,
                    state: s,
                  ),
                ),
                const SizedBox(height: 12),
                CoachTarget(
                  id: 'plan.optional',
                  child: _BudgetRow(
                  title: 'Желаемое',
                  subtitle: 'То, что радует',
                  icon: Icons.celebration_outlined,
                  color: FinniColors.sky,
                  value: s.plan.plan.optional,
                  direction: PlanDirection.optional,
                  state: s,
                ),
                ),
                const SizedBox(height: 12),
                CoachTarget(
                  id: 'plan.savings',
                  child: _BudgetRow(
                  title: 'Копилка',
                  subtitle: 'Навстречу мечте',
                  icon: Icons.savings_outlined,
                  color: FinniColors.lavender,
                  value: s.plan.plan.savings,
                  direction: PlanDirection.savings,
                  state: s,
                ),
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
          CoachTarget(
            id: 'plan.confirm',
            child: _Panel(
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
                if (s.plan.isConfirmed && s.savingsToDeposit > 0) ...[
                  const SizedBox(height: 12),
                  CoachTarget(
                    id: 'plan.save',
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        final amount = s.savingsToDeposit;
                        if (s.saveByPlan()) {
                          Celebration.show(context, motion: s.motion, emoji: '🐷');
                          toast('Отложили $amount ${ruCoins(amount)} в копилку. Мечта ближе!');
                        } else {
                          toast('Сначала выбери мечту — нажми на неё на главном экране.');
                        }
                      },
                      icon: const Icon(Icons.savings_outlined),
                      label: Text('Отложить в копилку ${s.savingsToDeposit} по плану'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: s.plan.isConfirmed
                      ? null
                      : () {
                          s.confirmPlan();
                          toast('План готов! Теперь можно играть, покупать и копить.');
                          go(0);
                          if (s.eventPending) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) showEvent();
                            });
                          }
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
          ),
        ],
      );

  static const List<(String, String, ShopItemKind?)> _wantFilters = [
    ('Всё', '', null),
    ('Вкусное', '🍪', ShopItemKind.consumable),
    ('Игрушки', '🧸', ShopItemKind.toy),
    ('Наряды', '🎀', ShopItemKind.accessory),
    ('Для дома', '🛋️', ShopItemKind.furniture),
    ('Обои', '🖼️', ShopItemKind.wallpaper),
    ('По карману', '👛', null),
  ];

  Widget shop() {
    final wants = [
      for (final item in s.catalog)
        if (item.category == ExpenseCategory.optional) item
    ];
    final filters = [
      for (final (i, entry) in _wantFilters.indexed)
        if (entry.$3 == null || wants.any((item) => item.kind == entry.$3)) i
    ];
    final active = filters.contains(filter) ? filter : 0;
    final kind = _wantFilters[active].$3;
    final items = [
      for (final item in wants)
        if (active == 0 ||
            kind != null && item.kind == kind ||
            active == _wantFilters.length - 1 &&
                item.price <= s.wallet.wallet.balance)
          item
    ];
    final needs = s.todayNeeds;
    final met = needs.length - s.missingNeeds.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CoachTarget(
          id: 'shop.wallet',
          child: _Panel(
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
        ),
        const SizedBox(height: 12),
        _ShopPet(state: s),
        if (s.plan.isConfirmed) ...[
          const SizedBox(height: 12),
          CoachTarget(id: 'shop.plan', child: _PlanLeft(state: s)),
        ],
        const SizedBox(height: 20),
        CoachTarget(
          id: 'shop.needs',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Нужно ${s.petName} сегодня',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '$met из ${needs.length}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: FinniColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Из каждой строки хватит одного — подешевле или побольше.',
                style: TextStyle(color: FinniColors.muted),
              ),
              const SizedBox(height: 10),
              for (final need in needs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _NeedCard(state: s, need: need, onBuy: purchase),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CoachTarget(
          id: 'shop.wants',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Для радости',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text(
                'Приятно, но можно и без этого.',
                style: TextStyle(color: FinniColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CoachTarget(
          id: 'shop.filters',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final i in filters)
                ChoiceChip(
                  label: Text(_wantFilters[i].$2.isEmpty
                      ? _wantFilters[i].$1
                      : '${_wantFilters[i].$2} ${_wantFilters[i].$1}'),
                  selected: active == i,
                  onSelected: (_) => setState(() => filter = i),
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: active == i ? FinniColors.paper : FinniColors.ink,
                  ),
                  selectedColor: FinniColors.primary,
                  backgroundColor: FinniColors.paper,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const _Notice(
            icon: Icons.savings_outlined,
            text:
                'Пока не хватает монет. Сыграй в игру или вернись к покупке позже.',
          ),
        CoachTarget(
          id: 'shop.items',
          child: LayoutBuilder(
            builder: (context, c) {
              final columns =
                  MediaQuery.textScalerOf(context).scale(16) > 22 ? 1 : 2;
              final width = (c.maxWidth - (columns - 1) * 12) / columns;
              return EqualGrid(
                columns: columns,
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (i, item) in items.indexed)
                    SizedBox(
                      width: width,
                      child: PopIn(
                        key: ValueKey('shop-${item.id}-$active'),
                        motion: s.motion,
                        delay: (i % 6) * 40,
                        child: product(item),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }


  Widget _planNotice(ShopItem item) {
    final check = s.planCheck(item);
    final String text;
    final IconData icon;
    if (check.direction == PlanDirection.mandatory) {
      icon = Icons.check_circle_outline_rounded;
      text = check.fits
          ? 'Это нужное. По плану на обязательное осталось ${check.left} ${ruCoins(check.left)}.'
          : 'Это нужное — оно важнее всего. По плану на обязательное осталось ${check.left}, остальные ${check.gap} ${ruCoins(check.gap)} возьмём из других монет.';
    } else if (check.fits) {
      icon = Icons.check_circle_outline_rounded;
      final after = check.left - check.price;
      text =
          'По плану на желаемое осталось ${check.left} ${ruCoins(check.left)}. После покупки останется $after — всё по плану!';
    } else {
      icon = Icons.warning_amber_rounded;
      text = [
        if (check.left == 0)
          'На желаемое по плану монет уже не осталось.'
        else
          'На желаемое по плану осталось ${check.left} ${ruCoins(check.left)}, а это стоит ${check.price}.',
        'Лишние ${check.gap} ${ruCoins(check.gap)} придётся взять из копилки: отложишь меньше${check.delayDays > 0 ? ', и мечта отодвинется примерно на ${check.delayDays} ${ruDays(check.delayDays)}' : ''}.',
        if (check.needsShort > 0)
          'А ещё тогда не хватит ${check.needsShort} ${ruCoins(check.needsShort)} на нужное для ${s.petName}!',
      ].join(' ');
    }
    return _Notice(icon: icon, text: text);
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
                  Center(child: ItemArt(item.id, size: 72)),
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
              const SizedBox(height: 4),
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
    if (requirePlan()) return;
    PurchaseOutcome outcome = s.askToBuy(item.id);
    WithdrawPreview? takeFromPiggy;
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
                          '$diaryText${noteText == null ? '' : ' $noteText'}',
                    ),
                    const SizedBox(height: 12),
                    _Panel(
                      padding: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Что изменилось',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const CoinIcon(size: 24),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text('Монеты',
                                    style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800)),
                              ),
                              Text('$before → ${s.wallet.wallet.balance}',
                                  style: const TextStyle(fontSize: 17)),
                              const SizedBox(width: 8),
                              _Pill(
                                icon: Icons.remove_rounded,
                                label: '${item.price}',
                                color: FinniColors.lavender,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _ShiftList(s.lastShifts),
                          if (s.plan.isConfirmed &&
                              item.category == ExpenseCategory.optional) ...[
                            const SizedBox(height: 8),
                            Text(
                              s.planLeft(PlanDirection.optional) >= 0
                                  ? 'На желаемое по плану осталось ${s.planLeft(PlanDirection.optional)}.'
                                  : 'На желаемое потрачено на ${-s.planLeft(PlanDirection.optional)} больше плана — сегодня отложим меньше.',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ],
                      ),
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
                PurchaseNotEnough(:final gap) when takeFromPiggy != null => [
                    _Notice(
                      icon: Icons.savings_outlined,
                      text:
                          'Копилка — это монеты на мечту. ${takeFromPiggy!.savedChangeText} ${takeFromPiggy!.etaChangeText}',
                    ),
                    const SizedBox(height: 12),
                    Text(takeFromPiggy!.question,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        if (s.confirmWithdraw(takeFromPiggy!) is WithdrawDone) {
                          update(() {
                            takeFromPiggy = null;
                            outcome = s.askToBuy(item.id);
                          });
                        }
                      },
                      icon: const Icon(Icons.arrow_upward_rounded),
                      label: Text('Взять $gap из копилки'),
                    ),
                    TextButton(
                      onPressed: () => update(() => takeFromPiggy = null),
                      child: const Text('Нет, пусть копится'),
                    ),
                  ],
                PurchaseNotEnough(:final gap, :final options) => [
                    _Notice(
                      icon: Icons.lightbulb_outline,
                      text: 'Пока не хватает $gap монет. Что сделаем?',
                    ),
                    const SizedBox(height: 12),
                    if (s.wallet.wallet.savings >= gap)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final preview = s.previewWithdraw(gap);
                            if (preview is WithdrawPreview) {
                              update(() => takeFromPiggy = preview);
                            } else if (preview is GoalRefused) {
                              toast(preview.textRu);
                            }
                          },
                          icon: const Icon(Icons.savings_outlined),
                          label: Text('Взять $gap из копилки'),
                        ),
                      ),
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
                    if (s.needOf(item) case final need?
                        when s.boughtFor(need) != null) ...[
                      _Notice(
                          icon: Icons.info_outline_rounded,
                          text:
                              '${need.title.isEmpty ? 'Это нужное' : need.title} на сегодня уже есть: ${s.boughtFor(need)!.title}. Эта покупка будет лишней.'),
                      const SizedBox(height: 12),
                    ] else if (s.plan.isConfirmed) ...[
                      _planNotice(item),
                      const SizedBox(height: 12),
                    ],
                    if (item.effects.isNotEmpty) ...[
                      _StatPreview(state: s, item: item),
                      const SizedBox(height: 12),
                    ],
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
      if (s.canEarnFromGames) {
        unawaited(playLevel());
      } else {
        go(3);
      }
    } else if (route == 'postpone') {
      s.postpone(item.id);
      toast('Сохранили в желаниях. Вернёмся к покупке завтра!');
    } else if (route.startsWith('shop:')) {
      final cheaper = s.content.shop.byId(route.substring(5));
      if (cheaper != null) purchase(cheaper);
    }
  }
}
