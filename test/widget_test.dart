// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:controllore_app/utils/ics_parser.dart';

void main() {
  test('IcsParser parses basic VEVENT correctly', () {
    const icsContent = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//ControllOre//IT
BEGIN:VEVENT
UID:test-123@example.com
DTSTART:20261025T090000Z
DTEND:20261025T110000Z
SUMMARY:Lezione di Matematica
STATUS:CONFIRMED
END:VEVENT
END:VCALENDAR''';

    final lessons = IcsParser.parse(icsContent);
    expect(lessons.length, 1);
    expect(lessons.first.summary, 'Lezione di Matematica');
    expect(lessons.first.duration, '02:00');
  });
}
