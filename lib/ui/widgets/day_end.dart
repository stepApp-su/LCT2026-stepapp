import './game_text.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../game_controller.dart';
import '../theme/finni_theme.dart';
import 'day_end_cards.dart';
import 'emoji_art.dart';
import 'moni_scene.dart';
import 'party.dart';
import 'pet_celebration.dart';

const Map<String, (String, String)> _factorLooks = {
  'mandatoryPaid': ('🛒', 'Нужное'),
  'followedPlan': ('📋', 'План'),
  'savedAsPlanned': ('🐷', 'Копилка'),
  'taskDone': ('🧩', 'Задание'),
};

const Map<String, (String, String, Color)> _statLooks = {
  'satiety': ('🍗', 'Сытость', FinniColors.nightSatiety),
  'care': ('🫧', 'Уход', FinniColors.nightCare),
  'mood': ('😊', 'Радость', FinniColors.nightMood),
  'cozy': ('🏠', 'Уют', FinniColors.nightCozy),
};

const TextStyle _kicker = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w800, color: FinniColors.nightDim);
const TextStyle _title = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    color: FinniColors.nightInk,
    height: 1.15);
const TextStyle _body = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w700, color: FinniColors.nightInk);
const TextStyle _soft = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w700, color: FinniColors.nightSoft);

Future<String?> showDayEnd(BuildContext context, GameController state,
        Map<String, dynamic> event) =>
    Navigator.of(context).push<String>(PageRouteBuilder<String>(
      settings: const RouteSettings(name: 'day-end'),
      transitionDuration:
          state.motion ? const Duration(milliseconds: 450) : Duration.zero,
      reverseTransitionDuration:
          state.motion ? const Duration(milliseconds: 300) : Duration.zero,
      pageBuilder: (_, __, ___) => DayEndScreen(state: state, event: event),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ));

class DayEndScreen extends StatefulWidget {
  const DayEndScreen({super.key, required this.state, required this.event});

  final GameController state;
  final Map<String, dynamic> event;

  @override
  State<DayEndScreen> createState() => _DayEndScreenState();
}

class _DayEndScreenState extends State<DayEndScreen> {
  bool morning = false;

  GameController get s => widget.state;

  @override
  void initState() {
    super.initState();
    widget.state.musicTheme('calm');
    final titles = widget.event['titles'] as List? ?? const [];
    if (titles.isNotEmpty) {
      s.fx('title_earned');
    } else if (((widget.event['points'] as num?)?.toInt() ?? 0) > 0) {
      s.fx('tally');
    }
  }
  Map<String, dynamic> get e => widget.event;

  Map<String, dynamic> get _pocket =>
      (e['pocket'] as Map?)?.cast<String, dynamic>() ?? const {};

  int _pocketOf(String key) => (_pocket[key] as num?)?.toInt() ?? 0;

  List<List> get _rows => [
        for (final row in (e['rows'] as List? ?? const []))
          if (row is List && row.length >= 3) row
      ];

  int _int(String key) => (e[key] as num?)?.toInt() ?? 0;

  List<Map<String, dynamic>> _maps(String key) => [
        for (final item in (e[key] as List? ?? const []))
          if (item is Map) item.cast<String, dynamic>()
      ];

  bool get _motion => s.motion && !MediaQuery.disableAnimationsOf(context);

  Future<void> _next() async {
    if (e['stageUp'] == true) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PetCelebration(state: s, event: {
          'from': e['from'],
          'to': e['to'],
          'headline': e['headline'],
          'reason': e['reason'],
          'titles': e['titles'] ?? const [],
        }),
      );
      if (!mounted) return;
    } else {
      for (final id in e['titles'] as List? ?? const []) {
        final title = s.content.titles.byId('$id');
        if (title == null) continue;
        final wear = await showParty(context,
            state: s,
            party: Party(
              kind: PartyKind.title,
              kicker: 'Новое звание',
              title: title.title,
              text: s.titles.reasonOf(title),
              icon: titleIconOf(title.iconId),
              button: 'Ура! Надеть звание',
              second: 'Позже',
            ));
        if (!mounted) return;
        if (wear) s.chooseTitle(title.id);
      }
    }
    setState(() => morning = true);
    s.musicTheme('main');
    s.fx('coin');
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: FinniColors.nightTop,
          body: AnimatedSwitcher(
            duration:
                _motion ? const Duration(milliseconds: 500) : Duration.zero,
            child: morning
                ? KeyedSubtree(
                    key: const ValueKey('morning'), child: _morning())
                : KeyedSubtree(key: const ValueKey('night'), child: _night()),
          ),
        ),
      );

  Widget _frame({
    required List<Color> colors,
    required bool moon,
    required double stars,
    required bool sun,
    required List<Widget> children,
    required List<Widget> footer,
  }) =>
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
        ),
        child: Stack(children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                  painter: NightSky(moon: moon, stars: stars, sun: sun)),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      children: children,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: footer,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      );

  Widget _pet({required bool sleeping}) => SizedBox(
        height: 270,
        child: LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          const h = 270.0;
          final scale = math.min(w / 470, h / 550);
          final left = (w - 470 * scale) / 2;
          final top = (h - 550 * scale) / 2;
          return Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: left + 130 * scale,
              width: 220 * scale,
              bottom: top + 4 * scale,
              height: 18,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: FinniColors.groundShadow,
                  borderRadius: BorderRadius.circular(80),
                ),
              ),
            ),
            Positioned.fill(
              child: ExcludeSemantics(
                child: MoniScene(
                  appearance: s.appearance,
                  stage: s.stage,
                  sleeping: sleeping,
                  motion: s.motion,
                  outfit: s.outfit,
                  equipped: s.equipped,
                ),
              ),
            ),
            if (sleeping)
              Positioned(
                left: left + 425 * scale,
                top: top + 150 * scale,
                child: const ExcludeSemantics(
                  child: GameText('z z Z',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: FinniColors.nightSoft)),
                ),
              ),
          ]);
        }),
      );

  Widget _night() {
    final day = _int('day');
    final points = _int('points');
    final factors = _maps('factors');
    final missed = [
      for (final f in factors)
        if (f['met'] != true) f
    ];
    final nextAt = (e['nextAt'] as num?)?.toInt();
    final from = _int('stageFrom');
    final current = _int('growthPoints');
    final titles = e['stageUp'] == true
        ? const <Object?>[]
        : (e['titles'] as List? ?? const []);
    final columns = MediaQuery.textScalerOf(context).scale(16) > 22 ? 2 : 4;
    return _frame(
      colors: const [
        FinniColors.nightTop,
        FinniColors.nightMid,
        FinniColors.nightLow
      ],
      moon: true,
      stars: 1,
      sun: false,
      children: [
        GameText('День $day завершён', style: _kicker),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(right: 64),
          child: GameText('${s.petName} сладко спит', style: _title),
        ),
        const SizedBox(height: 8),
        _pet(sleeping: true),
        const SizedBox(height: 14),
        NightGlass(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  GameText('+$points',
                      style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: FinniColors.honey)),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: GameText('к росту за день',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: FinniColors.nightInk)),
                  ),
                ]),
            const SizedBox(height: 10),
            if (nextAt != null && nextAt > from) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ((current - from) / (nextAt - from)).clamp(0.0, 1.0),
                  minHeight: 12,
                  color: FinniColors.honey,
                  backgroundColor: FinniColors.glassStrong,
                ),
              ),
              const SizedBox(height: 8),
              GameText('$current из $nextAt до стадии «${e['nextLabel']}»',
                  style: _soft),
            ] else
              GameText('${s.petName} уже совсем взрослый!', style: _soft),
          ]),
        ),
        if ('${e['hungry'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: FinniColors.nightPeach.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: FinniColors.nightPeach.withValues(alpha: .5))),
            child: Row(children: [
              const ExcludeSemantics(
                  child: GameText('🍲', style: TextStyle(fontSize: 24))),
              const SizedBox(width: 10),
              Expanded(
                child: GameText(
                    '${e['hungry']}. Купи еду — и завтра он снова будет расти.',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: FinniColors.nightInk)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          final width = ((constraints.maxWidth - (columns - 1) * 8) / columns)
              .clamp(0.0, double.infinity);
          return Wrap(spacing: 8, runSpacing: 8, children: [
            for (final factor in factors)
              SizedBox(width: width, child: _factorTile(factor)),
          ]);
        }),
        if (_rows.any((row) => ((row[1] as num?) ?? 0) > 0)) ...[
          const SizedBox(height: 10),
          PlanJars(
            rows: _rows,
            followed: factors.any(
                (f) => f['id'] == 'followedPlan' && f['met'] == true),
            motion: _motion,
          ),
        ],
        if (_pocketOf('earned') > 0) ...[
          const SizedBox(height: 10),
          PocketFlow(
            earned: _pocketOf('earned'),
            saved: _pocketOf('saved'),
            needs: _pocketOf('needs'),
            carry: _pocketOf('carry'),
            petName: s.petName,
            motion: _motion,
          ),
        ],
        for (final id in titles)
          if (s.content.titles.byId('$id') case final title?)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TitleGlass(
                icon: titleIconOf(title.iconId),
                title: title.title,
                reason: s.titles.reasonOf(title),
                motion: _motion,
              ),
            ),
        if (missed.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: FinniColors.honey,
                borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              const GameText('⭐', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: GameText('Завтра: ${_lower('${missed.first['text']}')}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: FinniColors.honeyInk)),
              ),
            ]),
          ),
        ],
      ],
      footer: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: FinniColors.honey,
            foregroundColor: FinniColors.honeyInk,
            minimumSize: const Size.fromHeight(56),
          ),
          onPressed: _next,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const GameText('Дальше'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: FinniColors.nightSoft),
          onPressed: _summary,
          child: const GameText('Итоги дня',
              style: TextStyle(decoration: TextDecoration.underline)),
        ),
      ],
    );
  }

  Widget _factorTile(Map<String, dynamic> factor) {
    final look = _factorLooks['${factor['id']}'] ?? ('✨', '${factor['id']}');
    final met = factor['met'] == true;
    return Semantics(
      label: '${look.$2}: ${met ? 'сделано' : 'пока нет'}',
      excludeSemantics: true,
      child: Opacity(
        opacity: met ? 1 : .55,
        child: NightGlass(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          radius: 18,
          child: Column(children: [
            GameText(look.$1, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 2),
            GameText(look.$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: FinniColors.nightInk)),
            Icon(met ? Icons.check_rounded : Icons.remove_rounded,
                size: 20,
                color: met ? FinniColors.nightMint : FinniColors.nightDim),
          ]),
        ),
      ),
    );
  }

  void _summary() {
    final rows = _rows;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: FinniColors.sheetNight,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          GameText('Итоги дня ${_int('day')}',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: FinniColors.nightInk)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _money('+${_int('earned')}', 'заработал')),
            const SizedBox(width: 8),
            Expanded(child: _money('−${_int('spent')}', 'потратил')),
          ]),
          const SizedBox(height: 10),
          NightGlass(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(child: SizedBox()),
                  SizedBox(
                      width: 58,
                      child: GameText('План',
                          textAlign: TextAlign.right, style: _soft)),
                  SizedBox(
                      width: 58,
                      child: GameText('Факт',
                          textAlign: TextAlign.right, style: _soft)),
                  SizedBox(width: 34),
                ]),
              ),
              for (final (i, row) in rows.indexed) _planRow(i, row),
            ]),
          ),
          if (_pocketOf('earned') > 0) ...[
            const SizedBox(height: 10),
            NightGlass(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(children: [
                _pocketRow('👛 Новые монеты', _pocketOf('earned'), strong: true),
                _pocketRow('🐷 В копилку', _pocketOf('saved')),
                _pocketRow('🍎 На нужное', _pocketOf('needs')),
                _pocketRow('📅 На завтра', _pocketOf('carry')),
              ]),
            ),
          ],
          if ('${e['explain'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 10),
            NightGlass(
              child: Row(children: [
                SizedBox(
                  width: 52,
                  height: 56,
                  child: ExcludeSemantics(
                    child: MoniScene(
                        appearance: s.appearance,
                        stage: s.stage,
                        motion: false,
                        outfit: s.outfit),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: GameText('${e['explain']}', style: _body)),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: FinniColors.honey,
              foregroundColor: FinniColors.honeyInk,
              minimumSize: const Size.fromHeight(56),
            ),
            onPressed: () => Navigator.pop(context),
            child: const GameText('Понятно'),
          ),
        ]),
      ),
    );
  }

  Widget _pocketRow(String label, int value, {bool strong = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: strong
            ? null
            : const BoxDecoration(
                border:
                    Border(top: BorderSide(color: FinniColors.glassLine))),
        child: Row(children: [
          Expanded(
              child: GameText(label,
                  style: strong
                      ? _body.copyWith(fontWeight: FontWeight.w900)
                      : _body)),
          GameText('$value',
              style: _body.copyWith(
                  fontWeight: FontWeight.w900,
                  color: strong ? FinniColors.honey : FinniColors.nightInk)),
        ]),
      );

  Widget _money(String value, String label) => NightGlass(
        radius: 16,
        child: Column(children: [
          GameText(value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: FinniColors.nightInk)),
          GameText(label, style: _soft),
        ]),
      );

  Widget _planRow(int index, List row) {
    const icons = ['🍲', '🎁', '🐷'];
    final plan = (row[1] as num).toInt();
    final fact = (row[2] as num).toInt();
    final ok = index == 1 ? fact <= plan : fact >= plan;
    return Semantics(
      label: '${row[0]}: план $plan, факт $fact${ok ? ', по плану' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: FinniColors.glassLine))),
        child: Row(children: [
          Expanded(
            child: GameText('${index < icons.length ? icons[index] : ''} ${row[0]}',
                maxLines: 2, style: _body),
          ),
          SizedBox(
              width: 58,
              child: GameText('$plan',
                  textAlign: TextAlign.right,
                  style: _body.copyWith(fontWeight: FontWeight.w900))),
          SizedBox(
              width: 58,
              child: GameText('$fact',
                  textAlign: TextAlign.right,
                  style: _body.copyWith(fontWeight: FontWeight.w900))),
          SizedBox(
            width: 34,
            child: Icon(
                ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                size: 20,
                color: ok ? FinniColors.nightMint : FinniColors.honey),
          ),
        ]),
      ),
    );
  }

  Widget _morning() {
    final night = _maps('night');
    final reasons = [
      for (final r in (e['nightReasons'] as List? ?? const [])) '$r'
    ];
    final dropped = {
      for (final shift in night)
        if (((shift['after'] as num?) ?? 0) < ((shift['before'] as num?) ?? 0))
          '${shift['stat']}'
    };
    final fixes = <ShopItem, String>{};
    for (final stat in dropped) {
      final item = _restorer(stat);
      if (item != null && !fixes.containsKey(item)) {
        fixes[item] = _statLooks[stat]?.$2 ?? stat;
      }
    }
    final toPlan = s.needsPlan;
    return _frame(
      colors: const [
        FinniColors.dawnTop,
        FinniColors.dawnMid,
        FinniColors.dawnWarm,
        FinniColors.dawnLow,
      ],
      moon: false,
      stars: .35,
      sun: true,
      children: [
        GameText('День ${s.day}', style: _kicker),
        const SizedBox(height: 4),
        const GameText('Доброе утро!', style: _title),
        const SizedBox(height: 8),
        _pet(sleeping: false),
        const SizedBox(height: 14),
        NightGlass(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const GameText('Что изменилось за ночь',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: FinniColors.nightInk)),
            const SizedBox(height: 4),
            if (night.isEmpty)
              GameText('Ночь прошла спокойно — ${s.petName} отлично выспался.',
                  style: _soft)
            else ...[
              GameText(reasons.join(' '), style: _soft),
              const SizedBox(height: 6),
              for (final shift in night) _statRow(shift),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        NightGlass(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(
                child: GameText('☀️ Новые монеты на день',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: FinniColors.nightInk)),
              ),
              GameText('+${s.content.economy.params.day.income}',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: FinniColors.honey)),
            ]),
            if (s.carried > 0) _incomeRow('👛 Осталось со вчера', s.carried),
            if (s.paidBack > 0) _incomeRow('🤝 Тебе вернули', s.paidBack),
            if (s.carried > 0 || s.paidBack > 0) ...[
              const SizedBox(height: 8),
              const SizedBox(
                  height: 1, child: ColoredBox(color: FinniColors.glassLine)),
              const SizedBox(height: 8),
              Row(children: [
                const Expanded(
                  child: GameText('Можно распланировать',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: FinniColors.nightInk)),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(
                      begin: _motion
                          ? s.content.economy.params.day.income.toDouble()
                          : s.plan.plan.income.toDouble(),
                      end: s.plan.plan.income.toDouble()),
                  duration: _motion
                      ? const Duration(milliseconds: 1100)
                      : Duration.zero,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => GameText(
                      '${value.round()}',
                      style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: FinniColors.honey)),
                ),
              ]),
            ],
            for (final entry in fixes.entries)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  ItemArt(entry.key.id, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GameText(
                        '${entry.key.title} — вернёт ${entry.value.toLowerCase()}',
                        style: _body),
                  ),
                ]),
              ),
          ]),
        ),
      ],
      footer: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: FinniColors.honey,
            foregroundColor: FinniColors.honeyInk,
            minimumSize: const Size.fromHeight(56),
          ),
          onPressed: () => Navigator.pop(context, toPlan ? 'plan' : null),
          icon: Icon(
              toPlan ? Icons.edit_note_rounded : Icons.arrow_forward_rounded),
          label: GameText(toPlan ? 'Составить план на день' : 'Продолжить'),
        ),
      ],
    );
  }

  Widget _incomeRow(String label, int value) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          Expanded(
            child: GameText(label,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: FinniColors.nightInk)),
          ),
          GameText('+$value',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: FinniColors.honey)),
        ]),
      );

  ShopItem? _restorer(String stat) {
    final wanted = PetStat.values.where((v) => v.name == stat).firstOrNull;
    if (wanted == null) return null;
    final candidates = [
      for (final item in s.catalog)
        if (item.effects.any((e) => e.stat == wanted && e.delta > 0)) item
    ];
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final byCategory = (a.category == ExpenseCategory.mandatory ? 0 : 1)
          .compareTo(b.category == ExpenseCategory.mandatory ? 0 : 1);
      return byCategory != 0 ? byCategory : a.price.compareTo(b.price);
    });
    return candidates.first;
  }

  Widget _statRow(Map<String, dynamic> shift) {
    final stat = '${shift['stat']}';
    final look = _statLooks[stat] ?? ('✨', stat, FinniColors.honey);
    final before = ((shift['before'] as num?) ?? 0).toInt();
    final after = ((shift['after'] as num?) ?? 0).toInt();
    final delta = after - before;
    return Semantics(
      label: '${look.$2}: было $before, стало $after',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: FinniColors.glassStrong,
                borderRadius: BorderRadius.circular(12)),
            child: GameText(look.$1, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GameText(look.$2, style: _body.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              LayoutBuilder(builder: (context, constraints) {
                final w = constraints.maxWidth;
                return SizedBox(
                  height: 10,
                  child: Stack(children: [
                    Container(
                        decoration: BoxDecoration(
                            color: FinniColors.glassStrong,
                            borderRadius: BorderRadius.circular(6))),
                    Container(
                        width: w * (before / 100).clamp(0.0, 1.0),
                        decoration: BoxDecoration(
                            color: FinniColors.glassLine,
                            borderRadius: BorderRadius.circular(6))),
                    Container(
                        width: w * (after / 100).clamp(0.0, 1.0),
                        decoration: BoxDecoration(
                            color: look.$3,
                            borderRadius: BorderRadius.circular(6))),
                  ]),
                );
              }),
            ]),
          ),
          const SizedBox(width: 10),
          GameText(delta < 0 ? '−${-delta}' : '+$delta',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: delta < 0
                      ? FinniColors.nightPeach
                      : FinniColors.nightMint)),
        ]),
      ),
    );
  }

  static String _lower(String text) =>
      text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);
}

class NightGlass extends StatelessWidget {
  const NightGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: FinniColors.glass,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: FinniColors.glassLine),
        ),
        child: child,
      );
}

class NightSky extends CustomPainter {
  const NightSky({this.moon = false, this.stars = 1, this.sun = false});

  final bool moon;
  final double stars;
  final bool sun;

  static const List<(double, double, double)> _stars = [
    (.08, .05, 1.6),
    (.34, .10, 1.2),
    (.72, .04, 1.6),
    (.88, .20, 1.2),
    (.16, .24, 1.2),
    (.55, .17, 1.6),
    (.80, .33, 1.2),
    (.06, .40, 1.0),
    (.93, .47, 1.0),
    (.42, .30, 1.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final starPaint = Paint()
      ..color = FinniColors.star.withValues(alpha: .8 * stars);
    for (final (x, y, r) in _stars) {
      canvas.drawCircle(Offset(size.width * x, size.height * y), r, starPaint);
    }
    if (moon) {
      const radius = 30.0;
      final center = Offset(math.max(70.0, size.width - 50), 58);
      final crescent = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
        Path()
          ..addOval(Rect.fromCircle(
              center: center + const Offset(15, -11), radius: radius * .86)),
      );
      canvas.drawPath(
          crescent,
          Paint()
            ..color = FinniColors.moonGlow
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
      canvas.drawPath(crescent, Paint()..color = FinniColors.moon);
    }
    if (sun) {
      final center = Offset(size.width / 2, size.height + 40);
      canvas.drawCircle(
        center,
        size.width * .7,
        Paint()
          ..shader = RadialGradient(colors: [
            FinniColors.sunGlow.withValues(alpha: .55),
            FinniColors.sunGlow.withValues(alpha: 0),
          ]).createShader(
              Rect.fromCircle(center: center, radius: size.width * .7)),
      );
    }
  }

  @override
  bool shouldRepaint(NightSky oldDelegate) =>
      oldDelegate.moon != moon ||
      oldDelegate.stars != stars ||
      oldDelegate.sun != sun;
}
