import 'package:chat_support_lite/models/chat_message.dart';
import 'package:chat_support_lite/theme/app_theme.dart';
import 'package:chat_support_lite/widgets/empty_state.dart';
import 'package:chat_support_lite/widgets/message_bubble.dart';
import 'package:chat_support_lite/widgets/message_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

ChatMessage _msg({
  String body = 'Hello there',
  bool hidden = false,
  DeliveryState delivery = DeliveryState.sent,
}) => ChatMessage(
  id: delivery == DeliveryState.sent ? 'm1' : 'local-1',
  threadId: 't1',
  senderId: 'u1',
  body: body,
  createdAt: DateTime(2026, 9, 24, 14, 5),
  hidden: hidden,
  delivery: delivery,
);

void main() {
  group('MessageComposer', () {
    Future<(TextEditingController, List<int>)> pump(
      WidgetTester tester, {
      bool enabled = true,
      bool ready = true,
    }) async {
      final controller = TextEditingController();
      final sends = <int>[];
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              const Spacer(),
              MessageComposer(
                controller: controller,
                enabled: enabled,
                ready: ready,
                disabledHint: 'You are muted',
                onChanged: (_) {},
                onSend: () => sends.add(1),
              ),
            ],
          ),
        ),
      );
      return (controller, sends);
    }

    testWidgets('send is inert until there is text', (tester) async {
      final (controller, sends) = await pump(tester);
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      expect(sends, isEmpty);

      await tester.enterText(find.byType(TextField), 'Hi');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      expect(sends, hasLength(1));
      expect(controller.text, 'Hi');
    });

    testWidgets('counter appears near the cap and blocks overflow', (
      tester,
    ) async {
      final (_, sends) = await pump(tester);
      await tester.enterText(find.byType(TextField), 'a' * 420);
      await tester.pump();
      expect(find.text('420 / 500'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'a' * 510);
      await tester.pump();
      expect(find.textContaining('trim 10 to send'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      expect(sends, isEmpty);
    });

    testWidgets('Enter sends, Shift+Enter does not', (tester) async {
      final (_, sends) = await pump(tester);
      await tester.enterText(find.byType(TextField), 'Line one');
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(sends, isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(sends, hasLength(1));
    });

    testWidgets('typing works while history loads, sending waits', (
      tester,
    ) async {
      final (controller, sends) = await pump(tester, ready: false);
      await tester.enterText(find.byType(TextField), 'Early draft');
      await tester.pump();
      expect(controller.text, 'Early draft');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      expect(sends, isEmpty);
    });

    testWidgets('disabled composer shows the reason', (tester) async {
      await pump(tester, enabled: false);
      expect(find.text('You are muted'), findsOneWidget);
    });
  });

  group('MessageBubble', () {
    testWidgets('shows body, time, and receipt', (tester) async {
      await tester.pumpWidget(
        _host(MessageBubble(message: _msg(), mine: true, receipt: 'Seen')),
      );
      expect(find.text('Hello there'), findsOneWidget);
      expect(find.textContaining('Seen'), findsOneWidget);
    });

    testWidgets('hidden message never shows the original body', (tester) async {
      await tester.pumpWidget(
        _host(
          MessageBubble(
            message: _msg(body: 'secret insult', hidden: true),
            mine: false,
          ),
        ),
      );
      expect(find.text('secret insult'), findsNothing);
      expect(find.text('Removed by a moderator'), findsOneWidget);
    });

    testWidgets('failed message offers retry on tap', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        _host(
          MessageBubble(
            message: _msg(delivery: DeliveryState.failed),
            mine: true,
            onRetry: () => retried++,
          ),
        ),
      );
      expect(find.textContaining('Not sent'), findsOneWidget);
      await tester.tap(find.text('Hello there'));
      expect(retried, 1);
    });
  });

  testWidgets('EmptyState renders title, subtitle, and action', (tester) async {
    await tester.pumpWidget(
      _host(
        EmptyState(
          title: 'No conversations yet',
          subtitle: 'Pick a mentor',
          action: FilledButton(onPressed: () {}, child: const Text('Start')),
        ),
      ),
    );
    expect(find.text('No conversations yet'), findsOneWidget);
    expect(find.text('Pick a mentor'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });
}
