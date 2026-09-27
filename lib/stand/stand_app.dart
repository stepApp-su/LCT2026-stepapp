import 'package:flutter/material.dart';
import '../content/content_repository.dart';
import '../domain/models/models.dart';
import '../domain/services/phrase_service.dart';
import '../domain/services/plan_service.dart';
import '../ui/app.dart';
import '../ui/game_controller.dart';
import 'download.dart';
import 'stand_style.dart';
import 'stand_repository.dart';

class StandApp extends StatefulWidget {
  const StandApp({super.key, required this.content, required this.config});
  final ContentBundle content;
  final Map<String, dynamic> config;
  @override
  State<StandApp> createState() => _StandAppState();
}

class _StandAppState extends State<StandApp> {
  late GameController game;
  int revision = 0;
  bool playing = false, busy = false;
  double phoneWidth = 390;
  String selectedGroup = 'Рост';
  StandStyle get look => StandStyle.contrast;
  bool get dark => look.dark;
  static const groupIcons = [
    Icons.trending_up,
    Icons.tune,
    Icons.chat_bubble_outline,
    Icons.workspace_premium_outlined,
    Icons.wb_sunny_outlined,
    Icons.checkroom
  ];
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  final playRepository = StandRepository(persistent: true);
  static const buildId =
      String.fromEnvironment('BUILD_ID', defaultValue: 'local');
  static const groups = [
    'Рост',
    'Состояние',
    'Реплики',
    'Награды',
    'День',
    'Одежда'
  ];
  static const ink = Color(0xff202b3a), line = Color(0xffdbe1e8);

  @override
  void initState() {
    super.initState();
    game = create({'onboarded': true});
    game.addListener(refresh);
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  GameController create(Map<String, dynamic>? saved,
          {StandRepository? repository}) =>
      GameController(widget.config,
          content: widget.content,
          repository: repository ?? StandRepository(),
          saved: saved);

  void record(String message) {
    if (!message.startsWith('Не выполнено:')) return;
    messengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> replace(Map<String, dynamic>? saved, {bool? play}) async {
    final nextPlaying = play ?? playing;
    final old = game;
    await old.flush();
    if (!mounted) return;
    old.removeListener(refresh);
    setState(() {
      playing = nextPlaying;
      game = create(saved,
          repository: playing ? playRepository : StandRepository());
      game.addListener(refresh);
      revision++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  Future<void> run(String label, Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (mounted) setState(() => record(label));
    } catch (error) {
      if (mounted) setState(() => record('Не выполнено: $error'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> scenario(Map<String, dynamic> patch) => replace({
        ...game.snapshot(),
        'onboarded': true,
        'celebration': null,
        ...patch,
      }, play: false);

  Future<void> stage(PetStage to, {PetStage? from}) async {
    await scenario({
      'petProgress': game.progress
          .copyWith(
              stage: to,
              growthPoints: to == PetStage.baby
                  ? 0
                  : widget.content.economy.growth.thresholds[to]!)
          .toJson(),
      if (from != null)
        'celebration': {
          'from': from.name,
          'to': to.name,
          'headline': from == PetStage.egg ? 'Привет, Мони!' : 'Мони подрос!',
          'reason': from == PetStage.egg
              ? 'Теперь будем учиться и расти вместе.'
              : 'Ты заботился о друге, учился планировать и копить.',
          'titles': <String>[],
        },
    });
  }

  Future<void> phrase(String text, {PhraseAction? action}) async {
    await scenario({});
    if (!mounted) return;
    game.bubble = PhraseLine(
        id: 'stand-${game.clock.now().microsecondsSinceEpoch}',
        category: 'stand',
        trigger: 'stand',
        textRu: text,
        emotion: PhraseEmotion.happy,
        action: action,
        tts: false);
    game.changed();
  }

  Future<void> award(String id) async {
    final title = widget.content.titles.byId(id)!;
    await scenario({
      'petProgress': game.progress
          .copyWith(
              earnedTitles: {...game.progress.earnedTitles, id}.toList(),
              currentTitleId: id)
          .toJson(),
      'celebration': {
        'from': game.stage.name,
        'to': game.stage.name,
        'headline': 'Новое звание!',
        'reason': game.titles.reasonOf(title),
        'titles': [id]
      },
    });
  }

  Future<void> day(bool good) async {
    await scenario({
      'balance': 180,
      'confirmed': false,
      'plan': {'mandatory': 0, 'optional': 0, 'savings': 0},
      'journal': <Object>[],
    });
    if (good) {
      game.plan.setAmount(PlanDirection.mandatory, game.mandatoryCost);
      game.plan.setAmount(PlanDirection.savings, 15);
      game.confirmPlan();
      for (final need in widget.content.economy.pet.needs) {
        game.buyNow(need.itemId);
      }
      game.saveCoins(15);
    }
    game.closeDay(game.day);
  }

  Future<void> reset(BuildContext context) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Сбросить стенд?'),
              content: const Text(
                  'Игровой профиль этого стенда и тестовые изменения будут удалены. Приложение на телефоне не затрагивается.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Отмена')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Сбросить'))
              ],
            ));
    if (yes != true || !mounted) return;
    await run('Стенд сброшен', () async {
      await game.flush();
      await playRepository.delete();
      await replace({'onboarded': true}, play: false);
    });
  }

  @override
  void dispose() {
    game.removeListener(refresh);
    game.dispose();
    super.dispose();
  }

  IconData actionIcon(String label) {
    if (label.contains('яйца')) return Icons.egg_outlined;
    if (label.contains('→')) return Icons.auto_awesome_outlined;
    if (label.contains('монет')) {
      return Icons.paid_outlined;
    }
    if (label.contains('Копилка')) return Icons.savings_outlined;
    if (label.contains('Ошибка')) return Icons.warning_amber_rounded;
    if (label.contains('Скрыть') || label.contains('Снять')) {
      return Icons.visibility_off_outlined;
    }
    return switch (selectedGroup) {
      'Рост' => Icons.pets_outlined,
      'Реплики' => Icons.chat_bubble_outline,
      'Награды' => Icons.workspace_premium_outlined,
      'День' => Icons.wb_sunny_outlined,
      'Одежда' => Icons.checkroom_outlined,
      _ => Icons.tune,
    };
  }

  Widget action(String label, Future<void> Function() callback) {
    final tint = look.accent.withValues(alpha: dark ? .15 : .08);
    return Padding(
        padding: EdgeInsets.only(bottom: look.actionMode == 3 ? 2 : 10),
        child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: look.actionMode == 2
                  ? tint
                  : look.actionMode == 1
                      ? (dark ? const Color(0xff2c3643) : Colors.white)
                      : Colors.transparent,
              side: BorderSide(
                  color: look.actionMode == 2 || look.actionMode == 3
                      ? Colors.transparent
                      : (dark
                          ? const Color(0xff43505d)
                          : const Color(0xffdce2e9))),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(look.radius)),
            ),
            onPressed: busy || playing ? null : () => run(label, callback),
            child: Row(children: [
              Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: look.filledIcons ? tint : Colors.transparent,
                      borderRadius: BorderRadius.circular(look.radius * .65)),
                  child: Icon(actionIcon(label), size: 21, color: look.accent)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500))),
              const SizedBox(width: 8),
              Tooltip(
                  message: 'Выполнить действие',
                  child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: tint, borderRadius: BorderRadius.circular(6)),
                      child: Icon(Icons.play_arrow_rounded,
                          size: 17, color: look.accent))),
            ])));
  }

  Widget note(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(text,
          style: TextStyle(
              color: dark ? const Color(0xffa9b6c5) : const Color(0xff687589),
              height: 1.5,
              fontSize: 13)));

  List<Widget> controls(String group) => switch (group) {
        'Рост' => [
            note(
                'Прямой просмотр стадии или полный переход с анимацией. Яйцо — только появление питомца.'),
            action('Появление из яйца',
                () => stage(PetStage.baby, from: PetStage.egg)),
            action('Малыш → подросток',
                () => stage(PetStage.teen, from: PetStage.baby)),
            action('Подросток → взрослый',
                () => stage(PetStage.adult, from: PetStage.teen)),
            const Divider(height: 28),
            for (final age in [PetStage.baby, PetStage.teen, PetStage.adult])
              action(widget.content.economy.growth.texts.stageLabels[age]!,
                  () => stage(age)),
          ],
        'Состояние' => [
            note(
                'Подготовленные состояния для проверки шкал, магазина и копилки.'),
            action(
                'Все потребности закрыты',
                () => scenario({
                      'stats': PetState.create(
                              satiety: 100, care: 100, mood: 100, cozy: 50)
                          .toJson()
                    })),
            action(
                'Нужны еда и уход',
                () => scenario({
                      'stats': PetState.create(
                              satiety: 20, care: 20, mood: 30, cozy: 0)
                          .toJson()
                    })),
            action('Нет монет', () => scenario({'balance': 0})),
            action('180 монет', () => scenario({'balance': 180})),
            action(
                'Копилка почти полная',
                () => scenario(
                    {'savings': (game.currentGoal?.price ?? 120) - 5})),
            action('Без выбранной мечты', () => scenario({'goalId': null})),
            action('Без анимаций', () => scenario({'motion': false})),
            action('Включить анимации', () => scenario({'motion': true})),
          ],
        'Реплики' => [
            note(
                'Короткий текст, длинная реплика и карточки с действием. Кнопки открывают реальные разделы игры.'),
            action(
                'Приветствие', () => phrase('Привет! Хорошо, что ты здесь.')),
            action(
                'Длинная реплика',
                () => phrase(
                    'Давай сначала позаботимся о нужном, а потом решим, сколько монет отложить на нашу мечту!')),
            action(
                'С кнопкой задания',
                () => phrase('Давай выполним задание и приблизимся к мечте!',
                    action: const PhraseAction(
                        label: 'Открыть задания', route: 'tasks'))),
            action(
                'С кнопкой плана',
                () => phrase('Заглянем в план на сегодня?',
                    action: const PhraseAction(
                        label: 'Составить план', route: 'plan'))),
            action(
                'С кнопкой магазина',
                () => phrase('Пора подкрепиться. Выберем еду?',
                    action:
                        const PhraseAction(label: 'В магазин', route: 'shop'))),
            action('Скрыть реплику', () async {
              game.dismissBubble();
            }),
            action('Ошибка сохранения', () async {
              await scenario({});
              (game.repository as StandRepository).failWrites = true;
              game.changed();
              await game.flush();
            }),
          ],
        'Награды' => [
            note('Награды выдаются принудительно только в режиме сценариев.'),
            for (final title in widget.content.titles.titles)
              action(title.title, () => award(title.id)),
          ],
        'День' => [
            note(
                'Сценарии используют реальные расчёты роста и изменения состояния. Можно продолжить играть после закрытия окна.'),
            action('Забота, план и накопления', () => day(true)),
            action('День без действий', () => day(false)),
            action('Завершить текущий день', () async {
              if (!game.closeDay(game.day)) {
                throw StateError('Сначала закрой окно предыдущего итога');
              }
            }),
          ],
        _ => [
            note(
                'Посадка аксессуаров на текущей стадии. Сначала выберите возраст в разделе «Рост».'),
            for (final entry in {
              'cap': 'Шапка',
              'bow': 'Бант',
              'glasses': 'Очки',
              'scarf': 'Шарф',
              'balloon': 'Шарик'
            }.entries)
              action(
                  entry.value,
                  () => scenario({
                        'owned': {...game.shop.owned, entry.key}.toList(),
                        'outfit': {'stand': entry.key}
                      })),
            action('Снять всё', () => scenario({'outfit': <String, String>{}})),
          ],
      };

  Widget section(String name) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        ...controls(name),
      ]);

  Widget events() {
    if (playing) {
      return Center(
          child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.sports_esports_outlined, size: 104, color: look.accent),
        const SizedBox(height: 24),
        const Text('Можно просто играть',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        const Text(
            'Прогресс сохраняется в этом браузере.\n\nДля проверки событий переключитесь на сценарии.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 14, height: 1.6, color: Color(0xff687589))),
      ])));
    }
    final railInk = dark || look.darkRail
        ? const Color(0xffe4eaf3)
        : const Color(0xff556171);
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
          width: 154,
          child: Material(
              color: look.rail,
              borderRadius: BorderRadius.circular(look.radius),
              child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  children: [
                    Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 0, 16),
                        child: Text('РАЗДЕЛЫ',
                            style: TextStyle(
                                color: railInk.withValues(alpha: .65),
                                fontSize: 10,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w600))),
                    for (var i = 0; i < groups.length; i++)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                              color: selectedGroup == groups[i]
                                  ? (look.darkRail
                                      ? Colors.white.withValues(alpha: .17)
                                      : look.accent
                                          .withValues(alpha: dark ? .2 : .12))
                                  : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(look.radius * .7),
                              child: InkWell(
                                  borderRadius:
                                      BorderRadius.circular(look.radius * .7),
                                  onTap: () =>
                                      setState(() => selectedGroup = groups[i]),
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 16),
                                      child: Row(children: [
                                        Icon(groupIcons[i],
                                            size: 19,
                                            color: selectedGroup == groups[i] &&
                                                    !look.darkRail
                                                ? look.accent
                                                : railInk),
                                        const SizedBox(width: 10),
                                        Expanded(
                                            child: Text(groups[i],
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: railInk,
                                                    fontWeight: selectedGroup ==
                                                            groups[i]
                                                        ? FontWeight.w700
                                                        : FontWeight.w400))),
                                        if (selectedGroup == groups[i])
                                          Container(
                                              width: 4,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                  color: look.darkRail
                                                      ? Colors.white
                                                      : look.accent,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          2))),
                                      ]))))),
                  ]))),
      const SizedBox(width: 20),
      Expanded(
          child: ListView(children: [
        Row(children: [
          Icon(groupIcons[groups.indexOf(selectedGroup)],
              size: 17, color: look.accent),
          const SizedBox(width: 8),
          Text('СЦЕНАРИИ / ${selectedGroup.toUpperCase()}',
              style: TextStyle(
                  fontSize: 10, letterSpacing: 1, color: look.accent)),
        ]),
        const SizedBox(height: 12),
        section(selectedGroup),
      ])),
    ]);
  }

  Widget modeSwitch() => SegmentedButton<bool>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 36)),
      segments: const [
        ButtonSegment(
            value: false,
            icon: Icon(Icons.tune, size: 16),
            label: Text('Сценарии')),
        ButtonSegment(
            value: true,
            icon: Icon(Icons.play_arrow, size: 16),
            label: Text('Играть')),
      ],
      selected: {playing},
      onSelectionChanged: busy
          ? null
          : (v) => run(v.first ? 'Обычная игра' : 'Режим сценариев', () async {
                await game.flush();
                await replace(
                    v.first ? await playRepository.load() : {'onboarded': true},
                    play: v.first);
              }));

  Widget panel(BuildContext context) => Material(
      key: const ValueKey('stand-controls'),
      color: look.surface,
      child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            LayoutBuilder(builder: (context, space) {
              final title = Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Тестовый стенд Финни',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Tooltip(
                    message: buildId == 'local'
                        ? 'Будет доступно после первого релиза'
                        : 'Последний релиз',
                    child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            textStyle: const TextStyle(fontSize: 11),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        onPressed: buildId == 'local' ? null : downloadApk,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Скачать APK'))),
              ]);
              return space.maxWidth >= 580
                  ? Row(children: [
                      Expanded(
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: title)),
                      const SizedBox(width: 12),
                      modeSwitch()
                    ])
                  : Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [title, modeSwitch()]);
            }),
            const Divider(height: 28),
            Expanded(child: events()),
          ])));

  Widget previewToolbar(BuildContext context) => SizedBox(
      width: 88,
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
          child: SingleChildScrollView(
              child: Column(children: [
            const Icon(Icons.smartphone, size: 20),
            const SizedBox(height: 8),
            const Text('Ширина', style: TextStyle(fontSize: 11)),
            const SizedBox(height: 10),
            for (final width in [360.0, 390.0, 430.0])
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ChoiceChip(
                      showCheckmark: false,
                      label: Text(width.toInt().toString()),
                      selected: phoneWidth == width,
                      onSelected: (_) => setState(() => phoneWidth = width))),
            const Divider(height: 24),
            Tooltip(
                message: 'Сбросить стенд',
                child: IconButton(
                    onPressed: busy ? null : () => reset(context),
                    icon: const Icon(Icons.restart_alt))),
            const Text('Сброс', style: TextStyle(fontSize: 11)),
          ]))));

  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'Финни — тестовый стенд',
      scaffoldMessengerKey: messengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: dark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor:
            dark ? const Color(0xff171d25) : const Color(0xffeef0f2),
        colorScheme: ColorScheme.fromSeed(
            brightness: dark ? Brightness.dark : Brightness.light,
            seedColor: look.accent,
            surface: look.surface),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
                foregroundColor: dark ? const Color(0xffe1e8f2) : ink,
                alignment: Alignment.centerLeft,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                minimumSize: Size(0, dark ? 40 : 48),
                side: BorderSide(color: dark ? const Color(0xff3b4654) : line),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(look.radius)))),
      ),
      home: Builder(
          builder: (context) => Scaffold(
                  body: SafeArea(child: LayoutBuilder(builder: (context, box) {
                final phone = Center(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: FittedBox(
                            fit: BoxFit.contain,
                            child: Container(
                              width: phoneWidth,
                              height: 844,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                      color: dark
                                          ? const Color(0xff495462)
                                          : line),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Color(0x14202b3a),
                                        blurRadius: 24,
                                        offset: Offset(0, 8))
                                  ]),
                              child: FinniApp(
                                  key: ValueKey(revision), controller: game),
                            ))));
                return box.maxWidth >= 800
                    ? Row(children: [
                        Expanded(child: panel(context)),
                        Expanded(
                            child: Row(
                                key: const ValueKey('stand-preview'),
                                children: [
                              previewToolbar(context),
                              Expanded(child: phone)
                            ]))
                      ])
                    : Column(children: [
                        SizedBox(
                            height: box.maxHeight * .55,
                            child: SingleChildScrollView(
                                child: SizedBox(
                                    height: 780, child: panel(context)))),
                        Expanded(
                            child: Row(children: [
                          previewToolbar(context),
                          Expanded(child: phone)
                        ])),
                      ]);
              })))));
}
