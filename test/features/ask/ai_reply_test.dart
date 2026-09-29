import 'package:flutter_test/flutter_test.dart';
import 'package:velora/features/ask/application/ask_controller.dart';
import 'package:velora/features/ask/data/direct_ask_repository.dart';

void main() {
  test('replies that claim something is saved are caught', () {
    expect(
      AskController.claimsSaved('Sige, Marc! Na-log ko na ang kape.'),
      isTrue,
    );
    expect(AskController.claimsSaved("Done, I've logged it."), isTrue);
    expect(
      AskController.claimsSaved('Here’s what I’ll log for your coffee.'),
      isFalse,
    );
  });

  test('AI replies are parsed and cleaned', () {
    final r = DirectAskRepository.parseReply(
      '```json\n{"reply": "**Here** is your coffee", "action": '
      '{"kind": "expense", "amount": 180, "account": "GCash", '
      '"category": "Food", "note": "Starbucks", "date": null}}\n```',
    )!;
    expect(r.text, 'Here is your coffee');
    expect(r.action?.amount, 180);
    expect(r.action?.account, 'GCash');
    expect(DirectAskRepository.parseReply('{"reply": ""}'), isNull);
    // Broken JSON is nothing to show.
    expect(DirectAskRepository.parseReply('{"reply": "Hi'), isNull);
  });

  test('a plain-text reply is still a reply, just without an action', () {
    final r = DirectAskRepository.parseReply(
      'Hey Marc! How’s your **day** going?',
    )!;
    expect(r.text, 'Hey Marc! How’s your day going?');
    expect(r.action, isNull);
  });
}
