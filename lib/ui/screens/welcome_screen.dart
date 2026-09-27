import 'package:flutter/material.dart';
import '../game_controller.dart';
import '../theme/finni_theme.dart';
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
  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(children: [
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          if (step > 0)
                            IconButton(
                                tooltip: 'Назад',
                                onPressed: () => setState(() => step--),
                                icon: const Icon(Icons.arrow_back_rounded))
                          else
                            const SizedBox(width: 48),
                          Expanded(
                              child: Text('Знакомство · ${step + 1} из 3',
                                  textAlign: TextAlign.center)),
                          IconButton(
                              tooltip: 'Подсказка',
                              onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                          title:
                                              const Text('Твой маленький друг'),
                                          content: const Text(
                                              'Заботься о питомце, выбирай покупки и копи на мечту. Монеты здесь игровые.'),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Понятно'))
                                          ])),
                              icon: const Icon(Icons.help_outline_rounded)),
                        ])),
                    Expanded(
                        child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            children: [
                          SizedBox(
                              height: step == 0 ? 230 : 160,
                              child: MoniScene(motion: widget.state.motion)),
                          const SizedBox(height: 16),
                          Text(
                              step == 0
                                  ? 'Привет! Давай дружить'
                                  : step == 1
                                      ? 'Как назовём питомца?'
                                      : 'Как будем играть?',
                              style: Theme.of(context).textTheme.headlineMedium,
                              textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          if (step == 0) ...[
                            for (final entry in [
                              (
                                Icons.restaurant_outlined,
                                'Покупай то, что нужно'
                              ),
                              (
                                Icons.celebration_outlined,
                                'Выбирай то, что радует'
                              ),
                              (Icons.savings_outlined, 'Откладывай на мечту')
                            ])
                              ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(entry.$1,
                                      color: FinniColors.primary),
                                  title: Text(entry.$2)),
                            const SizedBox(height: 16),
                            const Text(
                                'Монеты здесь игровые. Учимся тратить и копить без настоящих денег.',
                                style: TextStyle(color: FinniColors.muted)),
                          ],
                          if (step == 1)
                            NamePicker(
                                initial: name,
                                names: [
                                  for (final option
                                      in widget.state.config['names'] as List)
                                    '$option'
                                ],
                                onChanged: (value, valid) => setState(() {
                                      name = value;
                                      nameOk = valid;
                                    })),
                          if (step == 2) ...[
                            ListTile(
                                title: const Text('Я только учусь'),
                                subtitle: const Text('Попроще'),
                                leading: Icon(simple
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off),
                                onTap: () => setState(() => simple = true)),
                            ListTile(
                                title: const Text('Я уже умею считать'),
                                subtitle: const Text('Посложнее'),
                                leading: Icon(!simple
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off),
                                onTap: () => setState(() => simple = false)),
                            const SizedBox(height: 16),
                            const Text(
                                'Выбор сохраним. Поменять его можно в разделе для взрослого.',
                                style: TextStyle(color: FinniColors.muted)),
                          ],
                        ])),
                    Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton.icon(
                                  onPressed: step == 1 && !nameOk
                                      ? null
                                      : () {
                                    if (step < 2) {
                                      setState(() => step++);
                                    } else {
                                      widget.state.createPet(name, simple);
                                    }
                                  },
                                  icon: Icon(step == 2
                                      ? Icons.pets_outlined
                                      : Icons.arrow_forward_rounded),
                                  label: Text(
                                      step == 2 ? 'Начать дружить' : 'Дальше')),
                              if (step == 0)
                                TextButton(
                                    onPressed: () => setState(() => step = 1),
                                    child: const Text('Пропустить знакомство')),
                            ])),
                  ])))));
}
