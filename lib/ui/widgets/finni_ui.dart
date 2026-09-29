import './game_text.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tap_sound.dart';
import 'package:flutter/rendering.dart';

import '../../domain/services/phrase_service.dart';
import '../theme/finni_theme.dart';
import 'coin_icon.dart';

bool motionAllowed(BuildContext context, bool motion) =>
    motion && !MediaQuery.disableAnimationsOf(context);

class FinniCard extends StatelessWidget {
  const FinniCard({
    super.key,
    required this.child,
    this.color = FinniColors.paper,
    this.padding = 16,
    this.radius = 24,
    this.onTap,
  });

  final Widget child;
  final Color color;
  final double padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: FinniColors.line.withValues(alpha: .6)),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: EdgeInsets.all(padding), child: child),
        ),
      );
}

class CoinAmount extends StatelessWidget {
  const CoinAmount(this.amount, {super.key, this.size = 22, this.prefix = ''});

  final int amount;
  final double size;
  final String prefix;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$prefix$amount монет',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoinIcon(size: size + 2),
            SizedBox(width: size * .28),
            GameText(
              '$prefix$amount',
              style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w800,
                color: FinniColors.ink,
              ),
            ),
          ],
        ),
      );
}

class SoftNotice extends StatelessWidget {
  const SoftNotice({
    super.key,
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => FinniCard(
        color: color ?? FinniColors.honey.withValues(alpha: .4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: FinniColors.gold),
            const SizedBox(width: 12),
            Expanded(child: GameText(text)),
          ],
        ),
      );
}

class TagPill extends StatelessWidget {
  const TagPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: FinniColors.ink),
            const SizedBox(width: 6),
            Flexible(
              child: GameText(
                label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}

class Squish extends StatefulWidget {
  const Squish(
      {super.key, required this.child, this.onTap, this.enabled = true});

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<Squish> createState() => _SquishState();
}

class _SquishState extends State<Squish> {
  bool pressed = false;

  void _set(bool value) {
    if (pressed != value) setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => _set(true) : null,
        onTapCancel: () => _set(false),
        onTapUp: widget.enabled ? (_) => _set(false) : null,
        onTap: widget.enabled
            ? () {
                if (widget.onTap != null) TapSound.tap();
                widget.onTap?.call();
              }
            : null,
        child: AnimatedScale(
          scale: pressed ? .94 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.line,
    this.onClose,
    this.onAction,
    this.tailLeft = false,
    this.tailAbove = false,
  });

  final PhraseLine line;
  final VoidCallback? onClose;
  final VoidCallback? onAction;
  final bool tailLeft;
  final bool tailAbove;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        label: line.textRu,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              tailLeft ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            if (tailAbove)
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: CustomPaint(
                  size: const Size(24, 14),
                  painter: _TailPainter(above: true),
                ),
              ),
            Material(
              color: FinniColors.paper,
              elevation: 3,
              shadowColor: FinniColors.shadow,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: onClose,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GameText(
                        line.textRu,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.25),
                      ),
                      if (line.action != null && onAction != null) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: onAction,
                              child: GameText(line.action!.label,
                                  textAlign: TextAlign.center),
                            )),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (!tailAbove)
              Padding(
                padding: EdgeInsets.only(left: tailLeft ? 28 : 0),
                child: CustomPaint(
                  size: const Size(22, 12),
                  painter: _TailPainter(),
                ),
              ),
          ],
        ),
      );
}

class _TailPainter extends CustomPainter {
  _TailPainter({this.above = false});
  final bool above;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, above ? size.height : 0)
      ..lineTo(size.width, above ? size.height : 0)
      ..lineTo(
          above ? size.width * .2 : size.width / 2, above ? 0 : size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = FinniColors.paper);
  }

  @override
  bool shouldRepaint(_TailPainter oldDelegate) => oldDelegate.above != above;
}

class AnimatedBubble extends StatelessWidget {
  const AnimatedBubble({
    super.key,
    required this.line,
    required this.motion,
    this.onClose,
    this.onAction,
    this.tailLeft = false,
    this.tailAbove = false,
  });

  final PhraseLine? line;
  final bool motion;
  final VoidCallback? onClose;
  final VoidCallback? onAction;
  final bool tailLeft;
  final bool tailAbove;

  @override
  Widget build(BuildContext context) {
    final current = line;
    return AnimatedSwitcher(
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [...previousChildren, if (currentChild != null) currentChild],
      ),
      duration: motionAllowed(context, motion)
          ? const Duration(milliseconds: 260)
          : Duration.zero,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        alignment: Alignment.bottomCenter,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: current == null
          ? const SizedBox.shrink(key: ValueKey('empty'))
          : SpeechBubble(
              key: ValueKey('${current.id}:${current.textRu}'),
              line: current,
              onClose: onClose,
              onAction: onAction,
              tailLeft: tailLeft,
              tailAbove: tailAbove,
            ),
    );
  }
}

class Celebration {
  static void show(BuildContext context,
      {required bool motion, String emoji = '⭐', String? text}) {
    if (!motionAllowed(context, motion)) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CelebrationLayer(
        emoji: emoji,
        text: text,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _CelebrationLayer extends StatefulWidget {
  const _CelebrationLayer(
      {required this.emoji, required this.onDone, this.text});

  final String emoji;
  final String? text;
  final VoidCallback onDone;

  @override
  State<_CelebrationLayer> createState() => _CelebrationLayerState();
}

class _CelebrationLayerState extends State<_CelebrationLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..forward().whenComplete(widget.onDone);

  late final List<_Particle> particles = _Particle.burst(46);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = controller.value;
            final pop = Curves.elasticOut.transform((t * 1.8).clamp(0.0, 1.0));
            final fade = t < .75 ? 1.0 : (1 - (t - .75) / .25);
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _ConfettiPainter(particles, t)),
                ),
                Center(
                  child: Opacity(
                    opacity: fade.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: .4 + pop * .6,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GameText(
                            widget.emoji,
                            style: const TextStyle(fontSize: 96, height: 1),
                            textScaler: TextScaler.noScaling,
                          ),
                          if (widget.text != null)
                            Material(
                              color: FinniColors.paper,
                              borderRadius: BorderRadius.circular(20),
                              elevation: 4,
                              shadowColor: FinniColors.shadow,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                child: GameText(
                                  widget.text!,
                                  style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: FinniColors.ink),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class _Particle {
  const _Particle(
      this.angle, this.speed, this.spin, this.color, this.size, this.round);

  final double angle;
  final double speed;
  final double spin;
  final Color color;
  final double size;
  final bool round;

  static const List<Color> palette = [
    Color(0xFFFFC94D),
    Color(0xFF8FD3A8),
    Color(0xFF9CC7EA),
    Color(0xFFC9B2EC),
    Color(0xFFFF9E8A),
  ];

  static List<_Particle> burst(int count) {
    final random = math.Random(7);
    return [
      for (var i = 0; i < count; i++)
        _Particle(
          -math.pi / 2 + (random.nextDouble() - .5) * math.pi * 1.4,
          .55 + random.nextDouble() * .6,
          (random.nextDouble() - .5) * 12,
          palette[i % palette.length],
          6 + random.nextDouble() * 8,
          random.nextBool(),
        ),
    ];
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.particles, this.t);

  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * .55);
    final reach = size.shortestSide * .9;
    final fade = t < .7 ? 1.0 : (1 - (t - .7) / .3).clamp(0.0, 1.0);
    for (final p in particles) {
      final distance = reach * p.speed * Curves.easeOutCubic.transform(t);
      final gravity = size.height * .45 * t * t;
      final position = origin +
          Offset(math.cos(p.angle) * distance,
              math.sin(p.angle) * distance + gravity);
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(p.spin * t);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset.zero, width: p.size, height: p.size * .55),
                const Radius.circular(2)),
            paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.t != t;
}

class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 20, this.of = 3});

  final int stars;
  final double size;
  final int of;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Звёзд: $stars из $of',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < of; i++)
              Icon(
                i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size,
                color: i < stars ? const Color(0xFFE8A817) : FinniColors.muted,
              ),
          ],
        ),
      );
}

class PopIn extends StatelessWidget {
  const PopIn(
      {super.key, required this.child, required this.motion, this.delay = 0});

  final Widget child;
  final bool motion;
  final int delay;

  @override
  Widget build(BuildContext context) {
    if (!motionAllowed(context, motion)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + delay),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final local = delay == 0
            ? value
            : ((value * (420 + delay) - delay) / 420).clamp(0.0, 1.0);
        return Opacity(
          opacity: local.clamp(0.0, 1.0),
          child: Transform.scale(scale: .7 + .3 * local, child: child),
        );
      },
      child: child,
    );
  }
}

enum TagTone { neutral, green, gold, blue, purple, peach, white }

class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key, this.tone = TagTone.neutral});

  final String label;
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, ink) = switch (tone) {
      TagTone.neutral => (FinniColors.line, FinniColors.ink),
      TagTone.green => (FinniColors.mint, FinniColors.primary),
      TagTone.gold => (FinniColors.honey, FinniColors.honeyInk),
      TagTone.blue => (FinniColors.sky, FinniColors.blue),
      TagTone.purple => (FinniColors.lavender, FinniColors.purple),
      TagTone.peach => (FinniColors.peach, FinniColors.alert),
      TagTone.white => (FinniColors.paper, FinniColors.ink),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(999)),
      child: GameText(label,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: ink, height: 1.25)),
    );
  }
}

class TagRow extends StatelessWidget {
  const TagRow(this.tags, {super.key});

  final List<Widget> tags;

  @override
  Widget build(BuildContext context) => Wrap(
      spacing: 5,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: tags);
}

class EqualGrid extends MultiChildRenderObjectWidget {
  const EqualGrid({
    super.key,
    required this.columns,
    this.spacing = 10,
    this.runSpacing = 10,
    required super.children,
  });

  final int columns;
  final double spacing;
  final double runSpacing;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderEqualGrid(columns: columns, spacing: spacing, runSpacing: runSpacing);

  @override
  void updateRenderObject(BuildContext context, RenderEqualGrid renderObject) {
    renderObject
      ..columns = columns
      ..spacing = spacing
      ..runSpacing = runSpacing;
  }
}

class EqualGridParentData extends ContainerBoxParentData<RenderBox> {}

class RenderEqualGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, EqualGridParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, EqualGridParentData> {
  RenderEqualGrid(
      {required int columns, required double spacing, required double runSpacing})
      : _columns = columns,
        _spacing = spacing,
        _runSpacing = runSpacing;

  int _columns;
  double _spacing;
  double _runSpacing;

  set columns(int value) {
    if (value == _columns) return;
    _columns = value;
    markNeedsLayout();
  }

  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  set runSpacing(double value) {
    if (value == _runSpacing) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! EqualGridParentData) child.parentData = EqualGridParentData();
  }

  @override
  void performLayout() {
    final columns = math.max(1, _columns);
    final maxWidth = constraints.maxWidth;
    final cell = math.max(0.0, (maxWidth - (columns - 1) * _spacing) / columns);
    var tallest = 0.0;
    var child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints(minWidth: cell, maxWidth: cell), parentUsesSize: true);
      tallest = math.max(tallest, child.size.height);
      child = childAfter(child);
    }
    var index = 0;
    child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints.tight(Size(cell, tallest)));
      final data = child.parentData! as EqualGridParentData;
      data.offset = Offset((index % columns) * (cell + _spacing),
          (index ~/ columns) * (tallest + _runSpacing));
      index++;
      child = childAfter(child);
    }
    final rows = (childCount + columns - 1) ~/ columns;
    size = constraints.constrain(Size(maxWidth,
        rows == 0 ? 0 : rows * tallest + (rows - 1) * _runSpacing));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
