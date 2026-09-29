import './game_text.dart';
import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../game_controller.dart';
import '../theme/finni_theme.dart';
import 'coach.dart';
import 'day_end.dart';
import 'moni_scene.dart';

enum _Tone { ok, bonus, warn, calm }

class BedtimeScreen extends StatelessWidget {
  const BedtimeScreen({
    super.key,
    required this.state,
    required this.onSleep,
    required this.onTodo,
  });

  final GameController state;
  final void Function(BuildContext context) onSleep;
  final void Function(BuildContext context, BedtimeTodo todo) onTodo;

  static const List<(String, Color)> _rows = [
    ('🍲', FinniColors.nightMint),
    ('🎁', FinniColors.nightCare),
    ('🐷', FinniColors.nightMood),
  ];

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: state,
        builder: (context, _) => Scaffold(
          backgroundColor: FinniColors.nightTop,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  FinniColors.dawnTop,
                  FinniColors.nightMid,
                  FinniColors.nightLow
                ],
              ),
            ),
            child: Stack(children: [
              const Positioned.fill(
                child: IgnorePointer(
                    child: CustomPaint(painter: NightSky(stars: .7))),
              ),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(children: [
                      _topBar(context),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          children: [
                            _hero(context),
                            const SizedBox(height: 8),
                            CoachTarget(id: 'night.plan', child: _planCard()),
                            if (state.bedtimeTodos.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              CoachTarget(
                                  id: 'night.todo', child: _todoCard(context)),
                            ],
                          ],
                        ),
                      ),
                      CoachTarget(id: 'night.sleep', child: _footer(context)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );

  Widget _topBar(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Row(children: [
          IconButton(
            tooltip: 'Назад',
            color: FinniColors.nightInk,
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const Expanded(
            child: GameText('Спокойной ночи',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: FinniColors.nightInk)),
          ),
          IconButton(
            tooltip: 'Подсказка',
            color: FinniColors.nightInk,
            onPressed: () => _help(context),
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ]),
      );

  void _help(BuildContext context) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.nightlight_round, size: 36),
          title: const GameText('Перед сном'),
          content: const GameText(
              'Полоска — сколько монет вышло на самом деле. Белая чёрточка — сколько ты планировал утром. Если дела остались, их можно доделать или уложить питомца спать и так.',
              style: TextStyle(fontSize: 17)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const GameText('Понятно')),
          ],
        ),
      );

  bool get _allOnPlan {
    final rows = state.planFactRows;
    for (final (i, row) in rows.indexed) {
      if (_tone(i, row.$2, row.$3) == _Tone.warn) return false;
    }
    return true;
  }

  String get _petLine {
    if (state.bedtimeTodos.isNotEmpty) {
      return 'Я почти засыпаю… Но у нас остались дела.';
    }
    return _allOnPlan
        ? 'Я устал! Пойдём спать? Сегодня всё по плану.'
        : 'Я устал! Пойдём спать? Завтра попробуем ещё точнее по плану.';
  }

  Widget _hero(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 130,
            height: 150,
            child: ExcludeSemantics(
              child: MoniScene(
                appearance: state.appearance,
                stage: state.stage,
                sleeping: true,
                motion: state.motion,
                outfit: state.outfit,
                equipped: state.equipped,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 34),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: FinniColors.nightInk,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                    bottomLeft: Radius.circular(6),
                  ),
                ),
                child: GameText(_petLine,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: FinniColors.ink,
                        height: 1.3)),
              ),
            ),
          ),
        ],
      );

  static _Tone _tone(int index, int plan, int fact) {
    if (plan == 0 && fact == 0) return _Tone.calm;
    if (fact == plan) return _Tone.ok;
    return switch (index) {
      1 => fact < plan ? _Tone.ok : _Tone.warn,
      2 => fact > plan ? _Tone.bonus : _Tone.warn,
      _ => _Tone.warn,
    };
  }

  static String _tagText(int index, int plan, int fact) {
    final gap = (fact - plan).abs();
    if (plan == 0 && fact == 0) return 'Сегодня без этого';
    if (fact == plan) return 'Ровно по плану';
    return switch (index) {
      0 => fact < plan ? 'По плану ещё $gap' : 'Вышло на $gap больше плана',
      1 => fact < plan ? 'Сэкономил $gap' : 'Потратил на $gap больше плана',
      _ => fact > plan
          ? 'Отложил на $gap больше!'
          : 'Отложил на $gap меньше плана',
    };
  }

  Widget _planCard() {
    final rows = state.planFactRows;
    return NightGlass(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const GameText('Как прошёл день',
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: FinniColors.nightInk)),
        const SizedBox(height: 4),
        for (final (i, row) in rows.indexed)
          _planRow(i, row.$1, row.$2, row.$3, first: i == 0),
        const SizedBox(height: 8),
        const Row(children: [
          _Legend(bar: true, text: 'сколько вышло'),
          SizedBox(width: 16),
          _Legend(bar: false, text: 'сколько планировал'),
        ]),
      ]),
    );
  }

  Widget _planRow(int index, String label, int plan, int fact,
      {required bool first}) {
    final look = index < _rows.length ? _rows[index] : ('•', FinniColors.honey);
    final tone = _tone(index, plan, fact);
    final top = plan > fact ? plan : fact;
    final factShare = top == 0 ? 0.0 : fact / top;
    final planShare = top == 0 ? 0.0 : plan / top;
    final (icon, fg, bg) = switch (tone) {
      _Tone.ok => (
          Icons.check_rounded,
          FinniColors.nightMint,
          FinniColors.glass
        ),
      _Tone.bonus => (
          Icons.star_rounded,
          FinniColors.nightMood,
          FinniColors.glass
        ),
      _Tone.warn => (
          Icons.info_outline_rounded,
          FinniColors.nightPeach,
          FinniColors.glass
        ),
      _Tone.calm => (
          Icons.nightlight_round,
          FinniColors.nightSoft,
          FinniColors.glass
        ),
    };
    final tag = _tagText(index, plan, fact);
    return Semantics(
      label: '$label: план $plan, вышло $fact. $tag',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: first
              ? null
              : const Border(top: BorderSide(color: FinniColors.glassLine)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: GameText('${look.$1} $label',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: FinniColors.nightInk)),
            ),
            GameText('$fact из $plan',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: FinniColors.nightInk)),
          ]),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: 22,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 4,
                  height: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: FinniColors.glassStrong,
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 4,
                  height: 14,
                  width: width * factShare.clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: look.$2, borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                if (plan > 0)
                  Positioned(
                    left: (width * planShare - 3).clamp(0.0, width - 3),
                    top: 0,
                    bottom: 0,
                    width: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: FinniColors.nightInk,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
              ]),
            );
          }),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 5),
              Flexible(
                child: GameText(tag,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: fg)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  (String, String) _todoLook(BedtimeTodo todo) => switch (todo) {
        BedtimeTodo.plan => ('📝', 'Составить план на день'),
        BedtimeTodo.needs => (
            '🍲',
            'Ещё не купили: ${state.unpaidNeeds.map((i) => i.titleAccusative).join(', ')}${state.veryHungry ? '. Голодным ${state.petName} ночью не подрастёт' : ''}'
          ),
        BedtimeTodo.task => (
            '🧩',
            state.levelDoneToday ? 'Задание дня ждёт' : 'Уровень дня не пройден'
          ),
        BedtimeTodo.event => ('📣', 'Событие дня ждёт решения'),
      };

  static String _actionLabel(BedtimeTodo todo) => switch (todo) {
        BedtimeTodo.plan => 'План',
        BedtimeTodo.needs => 'В магазин',
        BedtimeTodo.task => 'Играть',
        BedtimeTodo.event => 'Открыть',
      };

  static String _primaryLabel(BedtimeTodo todo) => switch (todo) {
        BedtimeTodo.plan => 'Открыть план',
        BedtimeTodo.needs => 'Сходить в магазин',
        BedtimeTodo.task => 'Пойти играть',
        BedtimeTodo.event => 'Открыть событие',
      };

  static IconData _primaryIcon(BedtimeTodo todo) => switch (todo) {
        BedtimeTodo.plan => Icons.edit_note_rounded,
        BedtimeTodo.needs => Icons.storefront_outlined,
        BedtimeTodo.task => Icons.play_arrow_rounded,
        BedtimeTodo.event => Icons.campaign_outlined,
      };

  Widget _todoCard(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          color: FinniColors.honey.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: FinniColors.honey.withValues(alpha: .45)),
        ),
        child: Column(children: [
          for (final todo in state.bedtimeTodos)
            Row(children: [
              GameText(_todoLook(todo).$1, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: GameText(_todoLook(todo).$2,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: FinniColors.nightInk)),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: FinniColors.honey),
                onPressed: () => onTodo(context, todo),
                child: GameText(_actionLabel(todo),
                    style:
                        const TextStyle(decoration: TextDecoration.underline)),
              ),
            ]),
        ]),
      );

  Widget _footer(BuildContext context) {
    final todos = state.bedtimeTodos;
    final points =
        state.growth.pointsFor(state.growth.factorsOf(state.dayFacts));
    final style = FilledButton.styleFrom(
      backgroundColor: FinniColors.honey,
      foregroundColor: FinniColors.honeyInk,
      minimumSize: const Size.fromHeight(56),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (todos.isEmpty) ...[
          GameText.rich(
            TextSpan(children: [
              const TextSpan(text: '✨ За сегодня можно получить '),
              TextSpan(
                  text: '+$points',
                  style: const TextStyle(
                      color: FinniColors.honey, fontWeight: FontWeight.w900)),
              const TextSpan(text: ' к росту'),
            ]),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: FinniColors.nightSoft),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: style,
            onPressed: () => onSleep(context),
            icon: const Icon(Icons.nightlight_round),
            label: const GameText('Уложить спать'),
          ),
        ] else ...[
          FilledButton.icon(
            style: style,
            onPressed: () => onTodo(context, todos.first),
            icon: Icon(_primaryIcon(todos.first)),
            label: GameText(_primaryLabel(todos.first)),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: FinniColors.nightSoft,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => onSleep(context),
            child: const GameText('Всё равно уложить спать'),
          ),
        ],
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.bar, required this.text});

  final bool bar;
  final String text;

  @override
  Widget build(BuildContext context) => Flexible(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: bar ? 16 : 3,
            height: bar ? 8 : 14,
            decoration: BoxDecoration(
              color: bar ? FinniColors.glassStrong : FinniColors.nightInk,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: GameText(text,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: FinniColors.nightDim)),
          ),
        ]),
      );
}
