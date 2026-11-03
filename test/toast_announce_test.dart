import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_utils/shared_utils.dart';

/// `showToast` ينطق رسالته للقارئ الصوتي.
void main() {
  testWidgets('رسالة التوست تصل إلى القارئ الصوتي', (tester) async {
    final List<Object?> events = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (message) async {
        events.add(message);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, null),
    );

    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) {
                captured = context;
                return const SizedBox();
              },
            ),
          ],
        ),
      ),
    );

    showToast('اكتب عنوان الحلم', context: captured);
    await tester.pump();

    expect(events.toString(), contains('اكتب عنوان الحلم'));
    expect(events.toString(), contains('announce'));

    await tester.pump(const Duration(seconds: 5));
  });
}
