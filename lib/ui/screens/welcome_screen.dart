import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../../domain/ru_words.dart';
import '../game_controller.dart';
import '../theme/finni_theme.dart';
import '../widgets/emoji_art.dart';
import '../widgets/finni_ui.dart';
import '../widgets/moni_scene.dart';
import '../widgets/name_picker.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.state});
  final GameController state;
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int step = 0;
  String name = 'Мони';
  bool nameOk = true;
  bool simple = true;
  String? dream;

  static const int _last = 3;
  static const int _perDay = 10;

  GameController get s => widget.state;

  @override
  void initState() {
    super.initState();
    final starter = s.content.goals.settings.starterRecommendationId;
    final available = s.goals.available();
    dream = s.goalId ??
        (starter.isNotEmpty
            ? starter
            : available.isEmpty
                ? null
                : available.first.id);
  }

  Goal? get _dreamGoal {
    for (final goal in s.goals.available()) {
      if (goal.id == dream) return goal;
    }
    return null;
  }

  void _next() {
    if (step < _last) {
      setState(() => step++);
    } else {
      s.createPet(name, simple, goalId: dream);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, .55],
              colors: [FinniColors.morning, FinniColors.background],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(children: [
                  _header(context),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: motionAllowedHere(context)
                          ? const Duration(milliseconds: 260)
                          : Duration.zero,
                      child: ListView(
                        key: ValueKey(step),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                        children: switch (step) {
                          0 => _hello(context),
                          1 => _name(context),
                          2 => _dreams(context),
                          _ => _mode(context),
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                        onPressed: step == 1 && !nameOk || step == 2 && dream == null
                            ? null
                            : _next,
                        icon: Icon(step == _last
                            ? Icons.pets_outlined
                            : Icons.arrow_forward_rounded),
                        label: Text(_buttonLabel),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );

  bool motionAllowedHere(BuildContext context) =>
      s.motion && !MediaQuery.disableAnimationsOf(context);

  String get _buttonLabel {
    if (step == _last) return 'Начать дружить';
    if (step == 2) {
      final goal = _dreamGoal;
      return goal == null ? 'Дальше' : 'Выбрать: ${goal.title}';
    }
    return 'Дальше';
  }

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Row(children: [
          SizedBox(
            width: 48,
            child: step > 0
                ? IconButton(
                    tooltip: 'Назад',
                    onPressed: () => setState(() => step--),
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                : null,
          ),
          Expanded(
            child: Semantics(
              label: 'Шаг ${step + 1} из ${_last + 1}',
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i <= _last; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == step ? 24 : 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: i == step ? FinniColors.primary : FinniColors.line,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Подсказка',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Твой маленький друг'),
                content: const Text(
                    'Заботься о питомце, выбирай покупки и копи на мечту.',
                    style: TextStyle(fontSize: 17)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Понятно')),
                ],
              ),
            ),
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ]),
      );

  Widget _pet(double height) => Center(
        child: SizedBox(
          height: height,
          width: height * 1.1,
          child: MoniScene(
              motion: s.motion,
              stage: PetStage.baby,
              onPet: () => s.fx('pet_tap')),
        ),
      );

  Widget _title(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w900, color: FinniColors.ink, height: 1.15)),
      );

  Widget _lead(String text) => Text(text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: FinniColors.muted));

  List<Widget> _hello(BuildContext context) => [
        _pet(190),
        _title(context, 'Привет! Давай дружить'),
        _lead('Я буду жить у тебя, а ты научишься обращаться с монетками.'),
        const SizedBox(height: 16),
        for (final (emoji, text, color) in const [
          ('🍲', 'Покупай то, что нужно', FinniColors.mint),
          ('🎁', 'Выбирай то, что радует', FinniColors.sky),
          ('🐷', 'Копи на мечту', FinniColors.lavender),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _Card(
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(text,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800, color: FinniColors.ink)),
                ),
              ]),
            ),
          ),
      ];

  List<Widget> _name(BuildContext context) => [
        _pet(140),
        _title(context, 'Как меня назовём?'),
        const SizedBox(height: 8),
        NamePicker(
          initial: name,
          names: [for (final option in s.config['names'] as List) '$option'],
          onChanged: (value, valid) => setState(() {
            name = value;
            nameOk = valid;
          }),
        ),
      ];

  List<Widget> _dreams(BuildContext context) {
    final goals = s.goals.available();
    final columns = MediaQuery.textScalerOf(context).scale(16) > 22 ? 1 : 2;
    return [
      _title(context, 'О чём мечтаем?'),
      _lead('Мечта — большая покупка. На неё копят по чуть-чуть. Поменять её можно потом.'),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, constraints) {
        final width =
            ((constraints.maxWidth - (columns - 1) * 10) / columns).clamp(0.0, double.infinity);
        final scale = MediaQuery.textScalerOf(context);
        final height = 24 + 56 + 6 + scale.scale(16) * 1.15 * 2 + 8 + scale.scale(16) * 1.25 + 10;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final goal in goals)
            SizedBox(width: width, height: height, child: _dreamTile(goal)),
        ]);
      }),
    ];
  }

  Widget _dreamTile(Goal goal) {
    final selected = dream == goal.id;
    final days = (goal.price + _perDay - 1) ~/ _perDay;
    return Semantics(
      selected: selected,
      button: true,
      label: '${goal.title}, ${goal.price} ${ruCoins(goal.price)}, $days ${ruDays(days)}',
      excludeSemantics: true,
      child: _Card(
        selected: selected,
        onTap: () => setState(() => dream = goal.id),
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        child: Column(children: [
          ItemArt(goal.id, size: 56),
          const SizedBox(height: 6),
          Expanded(
            child: Center(
              child: Text(goal.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900, color: FinniColors.ink, height: 1.15)),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              TagChip('🪙 ${goal.price}', tone: TagTone.blue),
              const SizedBox(width: 4),
              TagChip('$days ${ruDays(days)}'),
            ]),
          ),
        ]),
      ),
    );
  }

  List<Widget> _mode(BuildContext context) => [
        _pet(140),
        _title(context, 'Как будем играть?'),
        const SizedBox(height: 10),
        for (final (value, emoji, title, subtitle) in const [
          (true, '🌱', 'Я только учусь', 'Задания попроще'),
          (false, '🚀', 'Я уже умею считать', 'Задания посложнее'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Semantics(
              selected: simple == value,
              button: true,
              label: '$title. $subtitle',
              excludeSemantics: true,
              child: _Card(
                selected: simple == value,
                onTap: () => setState(() => simple = value),
                child: Row(children: [
                  Text(emoji, style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900, color: FinniColors.ink)),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700, color: FinniColors.muted)),
                    ]),
                  ),
                  Icon(simple == value ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: FinniColors.primary),
                ]),
              ),
            ),
          ),
        const SizedBox(height: 4),
        _lead('Поменять можно в разделе для взрослого.'),
      ];
}

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.selected = false,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? FinniColors.mint : FinniColors.paper,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? FinniColors.primary : FinniColors.line,
                width: selected ? 2.5 : 1.5,
              ),
            ),
            child: child,
          ),
        ),
      );
}
