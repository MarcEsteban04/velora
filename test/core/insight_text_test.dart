import 'package:flutter_test/flutter_test.dart';
import 'package:velora/core/ai/insight_text.dart';

void main() {
  test('short insights pass through, cleaned', () {
    expect(
      tightenInsight('  **Nice** work on "Food" this week!  '),
      'Nice work on Food this week!',
    );
    expect(tightenInsight('   '), isNull);
  });

  test('long ones keep their first sentence', () {
    final t = tightenInsight(
      'It’s early days, but your net worth is ₱30,884. Your spending of ₱617 over '
      'the last two days is mostly food, so consider how to balance that as you '
      'keep logging.',
    );
    expect(t, 'It’s early days, but your net worth is ₱30,884.');
  });

  test('one long sentence is cut at a word, with an ellipsis', () {
    final t = tightenInsight(List.filled(40, 'spending').join(' '))!;
    expect(t.length, lessThanOrEqualTo(insightMaxChars + 1));
    expect(t, endsWith('spending…'));
  });
}
