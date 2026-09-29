import 'package:flutter/material.dart';

import 'game_glyph.dart';

/// Text with game artwork instead of platform-dependent emoji glyphs.
class GameText extends Text {
  const GameText(
    super.data, {
    super.key,
    super.style,
    super.strutStyle,
    super.textAlign,
    super.textDirection,
    super.locale,
    super.softWrap,
    super.overflow,
    super.textScaler,
    super.maxLines,
    super.semanticsLabel,
    super.semanticsIdentifier,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.selectionColor,
  });

  const GameText.rich(
    super.textSpan, {
    super.key,
    super.style,
    super.strutStyle,
    super.textAlign,
    super.textDirection,
    super.locale,
    super.softWrap,
    super.overflow,
    super.textScaler,
    super.maxLines,
    super.semanticsLabel,
    super.semanticsIdentifier,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.selectionColor,
  }) : super.rich();

  @override
  Widget build(BuildContext context) {
    final original = data ?? textSpan!.toPlainText();
    if (!gameGlyphPattern.hasMatch(original)) return super.build(context);
    final inherited = DefaultTextStyle.of(context).style.merge(style);
    return Text.rich(
      _replace(textSpan ?? TextSpan(text: data), inherited),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel ?? original,
      semanticsIdentifier: semanticsIdentifier,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }

  InlineSpan _replace(InlineSpan source, TextStyle inherited) {
    if (source is! TextSpan) return source;
    final resolved = inherited.merge(source.style);
    final value = source.text ?? '';
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final match in gameGlyphPattern.allMatches(value)) {
      if (match.start > cursor) {
        children.add(TextSpan(text: value.substring(cursor, match.start)));
      }
      children.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GameGlyph(match.group(0)!,
            size: (resolved.fontSize ?? 14) * 1.15, color: resolved.color),
      ));
      cursor = match.end;
    }
    if (cursor < value.length) {
      children.add(TextSpan(text: value.substring(cursor)));
    }
    children.addAll((source.children ?? []).map((s) => _replace(s, resolved)));
    return TextSpan(
      style: source.style,
      children: children,
      recognizer: source.recognizer,
      mouseCursor: source.mouseCursor,
      onEnter: source.onEnter,
      onExit: source.onExit,
      semanticsLabel: source.semanticsLabel,
      locale: source.locale,
      spellOut: source.spellOut,
    );
  }
}
