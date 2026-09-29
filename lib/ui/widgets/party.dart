import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game_controller.dart';
import '../theme/finni_theme.dart';
import 'emoji_art.dart';
import 'finni_ui.dart';
import 'game_glyph.dart';
import 'game_text.dart';
import 'moni_scene.dart';

enum PartyKind { title, dream, level, milestone }

final class Party {
  const Party({
    required this.kind,
    required this.kicker,
    required this.title,
    required this.text,
    required this.button,
    this.second,
    this.icon = '🏅',
    this.itemId,
    this.coins,
    this.stars = 3,
    this.from = 0,
    this.to = 0,
    this.caption,
  });

  final PartyKind kind;
  final String kicker;
  final String title;
  final String text;
  final String button;
  final String? second;
  final String icon;
  final String? itemId;
  final int? coins;
  final int stars;
  final double from;
  final double to;
  final String? caption;
}

Future<bool> showParty(BuildContext context,
    {required GameController state, required Party party}) async {
  state.fx(switch (party.kind) {
    PartyKind.title => 'title_earned',
    PartyKind.dream => 'goal_reached',
    PartyKind.level => 'round_win',
    PartyKind.milestone => 'coin',
  });
  final chosen = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: party.title,
    barrierColor: FinniColors.scrim,
    transitionDuration: motionAllowed(context, state.motion)
        ? const Duration(milliseconds: 250)
        : Duration.zero,
    pageBuilder: (_, __, ___) => PartyScreen(state: state, party: party),
    transitionBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
  return chosen == true;
}

class PartyScreen extends StatefulWidget {
  const PartyScreen({super.key, required this.state, required this.party});

  final GameController state;
  final Party party;

  @override
  State<PartyScreen> createState() => _PartyScreenState();
}

class _PartyScreenState extends State<PartyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
      vsync: this,
      duration: Duration(
          milliseconds: widget.party.kind == PartyKind.dream ? 3400 : 2800));
  late final List<_Bit> _bits = _Bit.of(widget.party.kind);
  bool _started = false;

  Party get p => widget.party;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (motionAllowed(context, widget.state.motion)) {
      _run.forward();
    } else {
      _run.value = 1;
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  double _span(double from, double to, [Curve curve = Curves.easeOutCubic]) {
    final t = ((_run.value - from) / (to - from)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AnimatedBuilder(
                animation: _run,
                builder: (context, _) => LayoutBuilder(
                  builder: (context, box) {
                    final heroTop = math.min(box.maxHeight * .30, 230.0);
                    return Stack(clipBehavior: Clip.none, children: [
                      if (p.kind != PartyKind.milestone)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: heroTop - 260,
                          height: 520,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: _span(.05, .25),
                              child: Transform.scale(
                                scale: .4 + .6 * _span(.05, .3),
                                child: CustomPaint(
                                    painter: _Rays(_run.value * .9)),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: heroTop - 120,
                        height: 240,
                        child: ExcludeSemantics(child: _hero()),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                              painter: _Confetti(_bits, _run.value,
                                  Offset(box.maxWidth / 2, heroTop))),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Transform.translate(
                          offset: Offset(
                              0,
                              (1 - _span(.28, .5, Curves.easeOutBack)) *
                                  box.maxHeight),
                          child: _card(),
                        ),
                      ),
                    ]);
                  },
                ),
              ),
            ),
          ),
        ),
      );

  Widget _hero() => switch (p.kind) {
        PartyKind.title => _medal(),
        PartyKind.dream => _gift(),
        PartyKind.level => _stars(),
        PartyKind.milestone => _piggy(),
      };

  Widget _medal() {
    final drop = _span(0, .3, Curves.easeOutBack);
    final wobble = math.sin(_span(.3, .55) * math.pi * 3) * .12 *
        (1 - _span(.3, .55));
    final hop = math.sin(_span(.35, .75) * math.pi * 3).abs() * 22;
    return Stack(alignment: Alignment.center, children: [
      Positioned(
        bottom: -14,
        child: Opacity(
          opacity: _span(.3, .4),
          child: Transform.translate(
            offset: Offset(0, -hop),
            child: SizedBox(
              width: 150,
              height: 150,
              child: MoniScene(
                appearance: widget.state.appearance,
                stage: widget.state.stage,
                motion: false,
                outfit: widget.state.outfit,
              ),
            ),
          ),
        ),
      ),
      Positioned(
        top: 0,
        child: Opacity(
          opacity: _span(0, .12),
          child: Transform.translate(
            offset: Offset(0, -(1 - drop) * 320),
            child: Transform.rotate(
              angle: (1 - drop) * -.5 + wobble,
              child: _Medal(icon: p.icon, shine: _span(.45, .8)),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _gift() {
    final pop = _span(0, .15, Curves.easeOutBack);
    final shake = math.sin(_span(.15, .45) * math.pi * 8) * .12;
    final open = _span(.45, .6, Curves.easeOutBack);
    final rise = _span(.5, .72, Curves.easeOutBack);
    return Stack(alignment: Alignment.center, children: [
      Opacity(
        opacity: rise.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 40 - rise * 100),
          child: Transform.scale(
            scale: .3 + .7 * rise,
            child: p.itemId == null
                ? const GameGlyph('trophy', size: 130)
                : ItemArt(p.itemId!, size: 130, background: false),
          ),
        ),
      ),
      Transform.translate(
        offset: Offset(0, 60 * open),
        child: Opacity(
          opacity: (1 - open).clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: shake,
            child: Transform.scale(
              scale: pop * (1 + open * .4),
              child: const GameGlyph('gift', size: 130),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _stars() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.fromLTRB(6, i == 1 ? 0 : 26, 6, 0),
              child: Builder(builder: (context) {
                final t = _span(.08 + i * .12, .22 + i * .12, Curves.easeOutBack);
                return Opacity(
                  opacity: t.clamp(0.0, 1.0) * (i < p.stars ? 1 : .3),
                  child: Transform.rotate(
                    angle: (1 - t) * -.8,
                    child: Transform.scale(
                        scale: 3 - 2 * t,
                        child: GameGlyph('star', size: i == 1 ? 84 : 70)),
                  ),
                );
              }),
            ),
        ],
      );

  Widget _piggy() {
    final pop = _span(0, .15, Curves.easeOutBack);
    final wiggle = math.sin(_span(.15, .6) * math.pi * 8) * .16 *
        (1 - _span(.15, .6));
    return Center(
      child: Transform.rotate(
        angle: wiggle,
        child: Transform.scale(
          scale: pop,
          child: const GameText('🐷',
              textScaler: TextScaler.noScaling,
              style: TextStyle(fontSize: 120, height: 1)),
        ),
      ),
    );
  }

  Widget _card() {
    final coins = p.coins;
    final fill = p.from + (p.to - p.from) * _span(.5, .8);
    return Material(
      color: FinniColors.paper,
      elevation: 8,
      shadowColor: FinniColors.shadow,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GameText(p.kicker.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                    color: FinniColors.gold)),
            const SizedBox(height: 4),
            GameText(p.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    color: FinniColors.ink)),
            if (coins != null) ...[
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  GameText('+${(coins * _span(.55, .85)).round()}',
                      style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: FinniColors.gold)),
                  const SizedBox(width: 6),
                  const GameText('🪙', style: TextStyle(fontSize: 36)),
                ]),
              ),
            ],
            if (p.kind == PartyKind.milestone) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: fill.clamp(0.0, 1.0),
                  minHeight: 16,
                  color: FinniColors.purple,
                  backgroundColor: FinniColors.line,
                ),
              ),
              if (p.caption != null) ...[
                const SizedBox(height: 6),
                GameText(p.caption!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: FinniColors.purple)),
              ],
            ],
            const SizedBox(height: 8),
            GameText(p.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: FinniColors.muted)),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: FinniColors.honey,
                foregroundColor: FinniColors.honeyInk,
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: GameText(p.button,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            if (p.second != null)
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: GameText(p.second!,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: FinniColors.muted)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Medal extends StatelessWidget {
  const _Medal({required this.icon, required this.shine});

  final String icon;
  final double shine;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        height: 170,
        child: Stack(alignment: Alignment.bottomCenter, children: [
          const Positioned(
            top: 0,
            child: SizedBox(
                width: 60, height: 64, child: CustomPaint(painter: _Ribbon())),
          ),
          Container(
            width: 132,
            height: 132,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-.3, -.4),
                colors: [
                  FinniColors.partyGoldLight,
                  FinniColors.partyGold,
                  FinniColors.partyGoldDeep,
                ],
                stops: [0, .5, 1],
              ),
              border: Border.all(color: FinniColors.paper, width: 6),
              boxShadow: const [
                BoxShadow(
                    color: FinniColors.partyGoldDeep,
                    spreadRadius: 4,
                    blurRadius: 0),
                BoxShadow(
                    color: FinniColors.shadow,
                    offset: Offset(0, 10),
                    blurRadius: 20),
              ],
            ),
            child: Stack(alignment: Alignment.center, children: [
              GameText(icon,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(fontSize: 60, height: 1)),
              if (shine > 0 && shine < 1)
                Positioned.fill(
                  child: FractionalTranslation(
                    translation: Offset(-1.2 + shine * 2.4, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          FinniColors.paper.withValues(alpha: 0),
                          FinniColors.paper.withValues(alpha: .75),
                          FinniColors.paper.withValues(alpha: 0),
                        ], stops: const [.35, .5, .65]),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      );
}

class _Ribbon extends CustomPainter {
  const _Ribbon();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final left = Path()
      ..moveTo(0, 0)
      ..lineTo(w / 2, 0)
      ..lineTo(w / 2, h * .8)
      ..lineTo(0, h)
      ..close();
    final right = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(w / 2, h * .8)
      ..close();
    canvas.drawPath(left, Paint()..color = FinniColors.partyRibbonRed);
    canvas.drawPath(right, Paint()..color = FinniColors.partyRibbonBlue);
  }

  @override
  bool shouldRepaint(_Ribbon oldDelegate) => false;
}

class _Rays extends CustomPainter {
  const _Rays(this.turn);

  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final paint = Paint()
      ..shader = RadialGradient(colors: [
        FinniColors.partyRay,
        FinniColors.partyRay.withValues(alpha: 0),
      ], stops: const [.25, 1])
          .createShader(Rect.fromCircle(center: center, radius: radius));
    for (var i = 0; i < 12; i++) {
      final a = turn + i * math.pi / 6;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(Rect.fromCircle(center: center, radius: radius), a,
            math.pi / 16, false)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_Rays oldDelegate) => oldDelegate.turn != turn;
}

final class _Bit {
  const _Bit(this.from, this.vx, this.vy, this.spin, this.color, this.size,
      this.round, this.delay);

  final Offset? from;
  final double vx, vy, spin, size, delay;
  final Color color;
  final bool round;

  static const List<Color> _colors = [
    FinniColors.partyGold,
    FinniColors.honey,
    FinniColors.nightMint,
    FinniColors.nightCare,
    FinniColors.nightMood,
    FinniColors.nightPeach,
    FinniColors.partyConfettiCoral,
    FinniColors.partyConfettiGreen,
  ];

  static List<_Bit> of(PartyKind kind) {
    final random = math.Random(kind.index + 3);
    final bits = <_Bit>[];
    void burst(int count, double delay, {Offset? from, double spread = 2.6,
        double power = 1}) {
      for (var i = 0; i < count; i++) {
        final angle = -math.pi / 2 + (random.nextDouble() - .5) * spread;
        final speed = (520 + random.nextDouble() * 520) * power;
        bits.add(_Bit(
          from,
          math.cos(angle) * speed,
          math.sin(angle) * speed,
          (random.nextDouble() - .5) * 14,
          _colors[i % _colors.length],
          6 + random.nextDouble() * 7,
          random.nextDouble() < .3,
          delay + random.nextDouble() * .04,
        ));
      }
    }

    switch (kind) {
      case PartyKind.title:
        burst(60, .18);
        burst(30, .3, from: const Offset(-1, .75), spread: .9, power: 1.2);
        burst(30, .3, from: const Offset(1, .75), spread: .9, power: 1.2);
      case PartyKind.dream:
        burst(80, .5, power: 1.2);
        burst(30, .55, from: const Offset(-1, .75), spread: .9, power: 1.3);
        burst(30, .55, from: const Offset(1, .75), spread: .9, power: 1.3);
      case PartyKind.level:
        for (var i = 0; i < 3; i++) {
          burst(22, .12 + i * .12, spread: 6.2, power: .55);
        }
      case PartyKind.milestone:
        burst(34, .45, spread: 2.2, power: .7);
    }
    return bits;
  }
}

class _Confetti extends CustomPainter {
  const _Confetti(this.bits, this.t, this.origin);

  final List<_Bit> bits;
  final double t;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    for (final bit in bits) {
      final age = (t - bit.delay) * 2.4;
      if (age <= 0) continue;
      final start = bit.from == null
          ? origin
          : Offset(
              bit.from!.dx < 0 ? 0 : size.width, size.height * bit.from!.dy);
      final x = start.dx + (bit.from == null ? bit.vx : bit.vx.abs() * -bit.from!.dx.sign) * age * .9;
      final y = start.dy + bit.vy * age + 900 * age * age;
      if (y > size.height + 40) continue;
      final fade = (1.4 - age).clamp(0.0, 1.0);
      if (fade <= 0) continue;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(bit.spin * age);
      final paint = Paint()..color = bit.color.withValues(alpha: fade);
      if (bit.round) {
        canvas.drawCircle(Offset.zero, bit.size / 2, paint);
      } else {
        final squash = (math.cos(bit.spin * age * 2)).abs() * .8 + .2;
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset.zero,
                width: bit.size,
                height: bit.size * 1.5 * squash),
            paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Confetti oldDelegate) => oldDelegate.t != t;
}

String titleIconOf(String iconId) => kEmoji[iconId] ?? '🏅';
