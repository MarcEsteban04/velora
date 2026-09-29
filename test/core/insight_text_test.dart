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

  test('one long sentence ends at a natural break, never mid-thought', () {
    // What the Wallet card showed as "…early tracking shows high…".
    const long =
        'Your ₱30,666 net worth is split 39% cash and 61% e-wallet, with ₱837 '
        'spent in just 2 days, so early tracking shows high daily spending '
        'worth watching.';
    expect(
      tightenInsight(long),
      'Your ₱30,666 net worth is split 39% cash and 61% e-wallet, with ₱837 '
      'spent in just 2 days.',
    );
    expect(tightenInsight(long, allowCut: false), isNotNull);
  });

  test('with no clean break, the caller can ask for a shorter one', () {
    final words = List.filled(40, 'spending').join(' ');
    expect(tightenInsight(words, allowCut: false), isNull);
    expect(tightenInsight(words), endsWith('…'));
  });
}
