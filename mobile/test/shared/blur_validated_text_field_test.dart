import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartngo/shared/widgets/blur_validated_text_field.dart';

Widget _harness(TextEditingController controller) {
  return MaterialApp(
    home: Scaffold(
      body: Form(
        child: Column(
          children: [
            BlurValidatedTextField(
              key: const Key('email'),
              controller: controller,
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'Enter a valid email'
                  : null,
            ),
            const TextField(key: Key('other')),
          ],
        ),
      ),
    ),
  );
}

void main() {
  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  testWidgets('no error is shown while the field still has focus',
      (tester) async {
    await tester.pumpWidget(_harness(controller));

    await tester.enterText(find.byKey(const Key('email')), 'not-an-email');
    await tester.pump();

    expect(find.text('Enter a valid email'), findsNothing);
  });

  testWidgets('error appears when the field loses focus with invalid input',
      (tester) async {
    await tester.pumpWidget(_harness(controller));

    await tester.enterText(find.byKey(const Key('email')), 'not-an-email');
    await tester.tap(find.byKey(const Key('other'))); // blur the email field
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email'), findsOneWidget);
  });

  testWidgets('error clears while typing once the input becomes valid',
      (tester) async {
    await tester.pumpWidget(_harness(controller));

    await tester.enterText(find.byKey(const Key('email')), 'not-an-email');
    await tester.tap(find.byKey(const Key('other')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email'), findsOneWidget);

    // Return to the field and fix the input — error should clear on change,
    // without needing another blur or a form submit.
    await tester.enterText(find.byKey(const Key('email')), 'jane@x.org');
    await tester.pump();

    expect(find.text('Enter a valid email'), findsNothing);
  });
}
