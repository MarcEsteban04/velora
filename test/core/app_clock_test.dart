import 'package:flutter_test/flutter_test.dart';
import 'package:velora/core/time/app_clock.dart';
import 'package:velora/features/transactions/domain/transaction.dart';

void main() {
  setUpAll(() => AppClock.init(AppClock.defaultZone));
  tearDown(() => AppClock.use(AppClock.defaultZone));

  test('the Philippines is the default, at GMT+8', () {
    expect(AppClock.zone, 'Asia/Manila');
    expect(AppClock.gmtLabel(AppClock.offsetOf('Asia/Manila')), 'GMT+8');
  });

  test('instants become wall time in the zone, and back', () {
    // 4:30 PM UTC is 12:30 AM the next day in Manila.
    final wall = AppClock.wall(DateTime.utc(2026, 9, 28, 16, 30));
    expect(wall, DateTime(2026, 9, 29, 0, 30));
    expect(AppClock.toUtc(wall), DateTime.utc(2026, 9, 28, 16, 30));
  });

  test('zones with daylight saving use the right offset for the date', () {
    AppClock.use('America/New_York');
    expect(
      AppClock.toUtc(DateTime(2026, 7, 1, 12)),
      DateTime.utc(2026, 7, 1, 16),
    ); // EDT, UTC−4
    expect(
      AppClock.toUtc(DateTime(2026, 1, 15, 12)),
      DateTime.utc(2026, 1, 15, 17),
    ); // EST, UTC−5
  });

  test('a transaction lands on its day in the chosen zone', () {
    AppClock.use('America/New_York');
    final t = Transaction.fromRow({
      'id': 't',
      'kind': 'expense',
      'amount_minor': 100,
      'account_id': 'a',
      'occurred_at': '2026-09-29T02:00:00+00:00',
    });
    // 2 AM UTC on the 29th is still the evening of the 28th in New York.
    expect(t.occurredAt, DateTime(2026, 9, 28, 22));
    expect(t.toDraft().toRow()['occurred_at'], '2026-09-29T02:00:00.000Z');
  });

  test('labels read well; unknown zones fall back to the Philippines', () {
    expect(
      AppClock.cityOf('America/Argentina/Buenos_Aires'),
      'Argentina / Buenos Aires',
    );
    expect(AppClock.cityOf('Asia/Manila'), 'Manila');
    expect(
      AppClock.gmtLabel(const Duration(hours: 5, minutes: 30)),
      'GMT+5:30',
    );
    expect(AppClock.gmtLabel(const Duration(hours: -3)), 'GMT−3');
    AppClock.use('Nowhere/Atlantis');
    expect(AppClock.zone, 'Asia/Manila');
  });
}
