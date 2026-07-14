import 'package:deduper/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home screen exposes focused cleanup workflows', (tester) async {
    await tester.pumpWidget(const PhotoCuratorApp());

    expect(find.text('Curate'), findsOneWidget);
    expect(find.text('Similar photos'), findsOneWidget);
    expect(find.text('Screenshots'), findsOneWidget);
    expect(find.text('Large photos'), findsOneWidget);
  });
}
