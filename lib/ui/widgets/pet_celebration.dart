import './game_text.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/pet.dart';
import '../game_controller.dart';
import '../theme/finni_theme.dart';
import 'moni_scene.dart';
import 'pet_sprite_set.dart';
import 'sprite_sheet.dart';

class PetCelebration extends StatefulWidget {
  const PetCelebration({super.key, required this.state, required this.event});
  final GameController state;
  final Map<String, dynamic> event;
  @override
  State<PetCelebration> createState() => _PetCelebrationState();
}

class _PetCelebrationState extends State<PetCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 4200));
  bool started = false;
  bool petReady = false;
  bool eggReady = false;
  bool loadingEgg = false;
  SpriteSheet? eggSheet;
  void startWhenReady() {
    if (!mounted || started || !petReady || !eggReady) return;
    started = true;
    final hatching = widget.event['from'] == PetStage.egg.name;
    widget.state.fx(hatching ? 'egg_crack' : 'stage_up');
    if (hatching) {
      animation.addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.state.fx('stage_up');
      });
    }
    animation.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced =
        !widget.state.motion || MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      if (!started) widget.state.fx('stage_up');
      started = true;
      animation.value = 1;
    } else if (!loadingEgg) {
      loadingEgg = true;
      final pet = widget.state.appearance;
      final ready = pet.unifiedHead
          ? PetSpriteSet.bodies(pet).then((sheet) {
              eggSheet = sheet;
            })
          : precacheImage(AssetImage(pet.egg), context);
      ready.then((_) {
        if (!mounted) return;
        eggReady = true;
        startWhenReady();
      });
    }
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final from = PetStage.values.byName(event['from'] as String);
    final to = PetStage.values.byName(event['to'] as String);
    final hatching = from == PetStage.egg;
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: FinniColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: SizedBox(
          key: const ValueKey('celebration-frame'),
          width: 440,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final t = animation.value;
                final reveal = ((t - .45) / .35).clamp(0.0, 1.0);
                final glow =
                    math.sin(((t - .32) / .42).clamp(0.0, 1.0) * math.pi);
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  GameText(event['headline'] as String,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  GameText(event['reason'] as String, textAlign: TextAlign.center),
                  SizedBox(
                      width: double.infinity,
                      height: 280,
                      child: Stack(alignment: Alignment.center, children: [
                        Positioned.fill(
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            FinniColors.honey.withValues(alpha: .65),
                            FinniColors.background.withValues(alpha: 0)
                          ]),
                        ))),
                        Positioned.fill(
                            child: Opacity(
                                opacity: hatching ? reveal : 1,
                                child: Transform.scale(
                                    scale: 1,
                                    child: MoniScene(
                                        appearance: widget.state.appearance,
                                        onReady: () {
                                          petReady = true;
                                          startWhenReady();
                                        },
                                        stage: t < .50 && !hatching ? from : to,
                                        celebrationProgress:
                                            hatching ? .30 + .70 * reveal : t,
                                        motion: widget.state.motion,
                                        outfit: widget.state.outfit)))),
                        if (hatching && t < .85)
                          Transform.rotate(
                              angle: t < .45 ? math.sin(t * 65) * .06 : 0,
                              child: SizedBox(
                                  width: 180,
                                  height: 250,
                                  child: Stack(children: [
                                    for (final top in [true, false])
                                      Positioned.fill(
                                          child: Opacity(
                                              opacity: 1 - reveal,
                                              child: Transform.translate(
                                                  offset: Offset(
                                                      (top ? -35 : 35) * reveal,
                                                      (top ? -95 : 50) *
                                                          reveal),
                                                  child: ClipPath(
                                                      clipper: _EggHalf(top),
                                                      child: widget
                                                              .state
                                                              .appearance
                                                              .unifiedHead
                                                          ? CustomPaint(
                                                              painter: _PetEgg(
                                                                  eggSheet))
                                                          : Image.asset(
                                                              widget
                                                                  .state
                                                                  .appearance
                                                                  .egg,
                                                              fit: BoxFit
                                                                  .contain))))),
                                  ]))),
                        if (from != to && !hatching && glow > 0)
                          Positioned.fill(
                              child: IgnorePointer(
                                  child: DecoratedBox(
                                      decoration: BoxDecoration(
                                          gradient: RadialGradient(colors: [
                            FinniColors.paper.withValues(alpha: glow),
                            FinniColors.honey.withValues(alpha: glow * .65),
                            FinniColors.paper.withValues(alpha: 0)
                          ], stops: const [
                            0,
                            .6,
                            1
                          ]))))),
                        if (t > .45 && t < 1)
                          Positioned.fill(
                              child: IgnorePointer(
                                  child:
                                      CustomPaint(painter: _Sparkles(reveal)))),
                      ])),
                  if (event['points'] != null)
                    Chip(
                        avatar: const Icon(Icons.auto_awesome, size: 19),
                        label: GameText('+${event['points']} к росту')),
                  for (final id in (event['titles'] as List? ?? []))
                    if (widget.state.content.titles.byId(id as String)
                        case final title?)
                      Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: FinniColors.honey,
                              borderRadius: BorderRadius.circular(18)),
                          child: Row(children: [
                            const Icon(Icons.workspace_premium_rounded,
                                color: FinniColors.gold),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  GameText('Новое звание: ${title.title}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  GameText(widget.state.titles.reasonOf(title)),
                                ]))
                          ])),
                  if (event['lines'] case final List lines)
                    for (final line in lines)
                      Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: GameText(line as String,
                              textAlign: TextAlign.center)),
                  if (event['changes'] case final List changes)
                    for (final change in changes)
                      Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: GameText(change as String,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 14, color: FinniColors.muted))),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed:
                          t < 1 ? null : () => Navigator.of(context).pop(),
                      child: GameText(hatching ? 'Начать дружить' : 'Здорово!')),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PetEgg extends CustomPainter {
  _PetEgg(this.sheet);
  final SpriteSheet? sheet;
  @override
  void paint(Canvas canvas, Size size) {
    if (sheet == null) return;
    final source = sheet!.cells[4];
    final fit = applyBoxFit(BoxFit.contain, source.size, size);
    canvas.drawImageRect(
        sheet!.image,
        source,
        Alignment.center.inscribe(fit.destination, Offset.zero & size),
        Paint()..filterQuality = FilterQuality.high);
  }

  @override
  bool shouldRepaint(_PetEgg old) => old.sheet != sheet;
}

class _EggHalf extends CustomClipper<Path> {
  const _EggHalf(this.top);
  final bool top;
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, top ? 0 : size.height)
      ..lineTo(0, size.height * .48);
    for (var i = 1; i <= 8; i++) {
      path.lineTo(size.width * i / 8, size.height * (i.isEven ? .48 : .53));
    }
    return path
      ..lineTo(size.width, top ? 0 : size.height)
      ..close();
  }

  @override
  bool shouldReclip(_EggHalf oldClipper) => oldClipper.top != top;
}

class _Sparkles extends CustomPainter {
  const _Sparkles(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final radius = 45 + t * 105;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final r = (1 - t) * (i.isEven ? 6 : 4);
      final path = Path()
        ..moveTo(point.dx, point.dy - r)
        ..lineTo(point.dx + r * .4, point.dy)
        ..lineTo(point.dx, point.dy + r)
        ..lineTo(point.dx - r * .4, point.dy)
        ..close();
      canvas.drawPath(
          path,
          Paint()
            ..color = (i.isEven ? FinniColors.gold : FinniColors.purple)
                .withValues(alpha: 1 - t));
    }
  }

  @override
  bool shouldRepaint(_Sparkles oldDelegate) => oldDelegate.t != t;
}
