import 'package:deduper/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home screen exposes scan and monetization surfaces', (tester) async {
    await tester.pumpWidget(const PhotoCuratorApp());

    expect(find.text('PhotoCurator AI'), findsOneWidget);
    expect(find.text('Scan library'), findsOneWidget);
    expect(find.text('Upgrade'), findsOneWidget);
  });
}
