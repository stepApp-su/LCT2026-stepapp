import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finni/domain/models/phrase_catalog.dart';
import 'package:finni/domain/services/phrase_service.dart';
import 'package:finni/ui/widgets/finni_ui.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('action bubble fits narrow screen at text scale $scale',
        (tester) async {
      var opened = false;
      var dismissed = false;
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
            body: Center(
                child: SizedBox(
          width: 296,
          child: SpeechBubble(
            line: PhraseLine(
                id: 'task',
                category: 'task',
                trigger: 'task',
                textRu: 'Давай выполним задание и приблизимся к мечте!',
                emotion: PhraseEmotion.values.first,
                action: const PhraseAction(
                    label: 'Открыть задание', route: '/tasks'),
                tts: false),
            onClose: () => dismissed = true,
            onAction: () => opened = true,
          ),
        ))),
      )));
      expect(tester.takeException(), isNull);
      final text = tester
          .getRect(find.text('Давай выполним задание и приблизимся к мечте!'));
      final button = tester.getRect(find.byType(FilledButton));
      expect(button.left, text.left);
      expect(button.top, greaterThan(text.bottom));
      expect(button.height, greaterThanOrEqualTo(44));
      await tester.tap(find.text('Открыть задание'));
      expect(opened, isTrue);
      expect(dismissed, isFalse);
    });
  }
}
