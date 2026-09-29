import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/app_clock.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../../profile/data/profile_repository.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction.dart';
import '../data/ask_repository.dart';
import '../domain/chat_message.dart';
import '../domain/local_answers.dart';
import '../domain/money_context.dart';
import '../domain/transaction_parser.dart';
import 'money_context_provider.dart';

class AskState {
  const AskState({required this.messages, this.thinking = false});

  final List<ChatMessage> messages;

  /// Velora is working on a reply.
  final bool thinking;

  AskState copyWith({List<ChatMessage>? messages, bool? thinking}) => AskState(
    messages: messages ?? this.messages,
    thinking: thinking ?? this.thinking,
  );
}

/// The Ask Velora conversation. It lasts while the app is open.
///
/// Each message is tried in order:
/// 1. A clear transaction ("spent 250 on lunch") is understood on the
///    phone and offered as a card to confirm.
/// 2. A short, common question ("how much did I spend this week?") is
///    answered on the phone from the real numbers.
/// 3. Anything else goes to the AI, with the money summary as context.
/// 4. If the AI can't be reached, the phone answers what it can.
///
/// Nothing is ever saved without the user tapping "Log it".
final askProvider = NotifierProvider<AskController, AskState>(
  AskController.new,
);

class AskController extends Notifier<AskState> {
  int _ids = 0;

  String _id() => 'm${_ids++}';

  ChatMessage _greeting() {
    final name = ref.read(profileProvider).value?.name ?? 'friend';
    return ChatMessage(
      id: _id(),
      role: ChatRole.velora,
      text:
          'Hi $name! I’m Velora. Tell me what you spent or earned and I’ll '
          'log it, or ask me anything about your money.',
    );
  }

  @override
  AskState build() => AskState(messages: [_greeting()]);

  void clear() => state = AskState(messages: [_greeting()]);

  void _add(ChatMessage m) =>
      state = state.copyWith(messages: [...state.messages, m], thinking: false);

  void _update(String id, ChatMessage Function(ChatMessage) change) =>
      state = state.copyWith(
        messages: [for (final m in state.messages) m.id == id ? change(m) : m],
      );

  TransactionParser? _parser() {
    final accounts = ref.read(accountsProvider).value;
    final categories = ref.read(categoriesProvider).value;
    if (accounts == null || categories == null || accounts.isEmpty) {
      return null;
    }
    final recent = ref.read(recentTransactionsProvider).value;
    final last = recent?.firstOrNull?.accountId;
    return TransactionParser(
      accounts: accounts,
      categories: categories,
      now: AppClock.now(),
      defaultAccountId: accounts.any((a) => a.id == last)
          ? last
          : accounts.first.id,
    );
  }

  static String _confirmText(ParsedTransaction p) => switch (p.kind) {
    TransactionKind.expense =>
      'Got it. Here’s the expense. Tap Log it to save.',
    TransactionKind.income => 'Nice! Here’s the income. Tap Log it to save.',
    TransactionKind.transfer =>
      'Here’s the transfer. Tap Log it to move the money.',
  };

  Future<void> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || state.thinking) return;
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(id: _id(), role: ChatRole.user, text: text),
      ],
      thinking: true,
    );

    final parser = _parser();
    final ctx = ref.read(moneyContextProvider);

    // 1. A clear "spent 250 on lunch", understood on the phone. A question
    // ("I earn 30k, is that enough?") is conversation, never a log.
    final parsed = text.contains('?') ? null : parser?.parse(text);
    if (parsed != null) {
      await _pause();
      _add(
        ChatMessage(
          id: _id(),
          role: ChatRole.velora,
          text: _confirmText(parsed),
          proposal: parsed,
        ),
      );
      return;
    }

    // 2. The AI, for everything else: a real conversation that remembers
    // the chat. The phone's own answers are the offline fallback.
    final local = ctx == null ? null : LocalAnswers.answer(text, ctx);
    final ai = ctx == null
        ? null
        : await ref
              .read(askRepositoryProvider)
              .ask(
                history: [
                  for (final m
                      in state.messages
                          .skip(1)
                          .toList()
                          .reversed
                          .take(16)
                          .toList()
                          .reversed)
                    (m.role == ChatRole.user ? 'user' : 'assistant', m.text),
                ],
                context: ctx.toJson(),
              );
    if (ai != null) {
      final action = ai.action == null || parser == null
          ? null
          : _resolve(ai.action!, parser);
      _add(
        ChatMessage(
          id: _id(),
          role: ChatRole.velora,
          // A reply that claims it's already saved isn't true yet: the
          // user still taps Log it. Say so plainly instead.
          text: action != null && claimsSaved(ai.text)
              ? _confirmText(action)
              : ai.text,
          proposal: action,
          fromAi: true,
        ),
      );
      return;
    }

    // 3. Offline, or the AI isn't set up: the phone does its best.
    _add(
      ChatMessage(
        id: _id(),
        role: ChatRole.velora,
        text:
            local ??
            'I can’t reach my AI brain right now, but I can still log '
                'things like “Spent 250 on lunch” and answer questions like '
                '“How much did I spend this week?”',
      ),
    );
  }

  /// Whether [text] says something is already logged or saved, in English
  /// or Filipino.
  static bool claimsSaved(String text) => RegExp(
    r"\b(logged|saved|recorded|added it|i've added|na-?log|nai-?log|naitala|na-?save|nai-?save|nilagay ko)\b",
    caseSensitive: false,
  ).hasMatch(text);

  /// A beat, so replies don't snap in faster than a person could read the
  /// question back.
  Future<void> _pause() =>
      Future<void>.delayed(const Duration(milliseconds: 450));

  /// Matches the AI's names to real accounts and categories.
  ParsedTransaction? _resolve(AiAction a, TransactionParser p) {
    final kind = TransactionKind.values.asNameMap()[a.kind];
    if (kind == null) return null;
    Account? account(String? name) {
      if (name == null) return null;
      final n = name.toLowerCase();
      return p.accounts.where((x) => x.name.toLowerCase() == n).firstOrNull ??
          p.accounts
              .where(
                (x) =>
                    x.name.toLowerCase().contains(n) ||
                    n.contains(x.name.toLowerCase()),
              )
              .firstOrNull;
    }

    Category? category(String? name) {
      final options = p.categories.where((c) => c.kind == kind && !c.hidden);
      if (name != null) {
        final n = name.toLowerCase();
        final hit = options.where((c) => c.name.toLowerCase() == n).firstOrNull;
        if (hit != null) return hit;
        // The phone's own keywords as a second opinion.
        final guess = p.parse('spent 1 on $name')?.categoryId;
        if (guess != null) {
          return options.where((c) => c.id == guess).firstOrNull;
        }
      }
      return options.where((c) => c.icon == 'other').firstOrNull;
    }

    final from = account(a.account);
    final to = account(a.toAccount);
    final accountId = from?.id ?? p.defaultAccountId;
    if (accountId == null) return null;
    if (kind == TransactionKind.transfer &&
        (to == null || to.id == accountId)) {
      return null;
    }
    final now = p.now;
    final d = a.date;
    return ParsedTransaction(
      kind: kind,
      amountMinor: (a.amount * 100).round(),
      accountId: accountId,
      accountGuessed: from == null,
      toAccountId: to?.id,
      categoryId: kind == TransactionKind.transfer
          ? null
          : category(a.category)?.id,
      note: a.note,
      occurredAt: d == null || d.isAfter(now)
          ? now
          : DateTime(d.year, d.month, d.day, now.hour, now.minute),
    );
  }

  /// Logs a proposal after the user taps "Log it".
  Future<void> confirm(String messageId) async {
    final m = state.messages.where((x) => x.id == messageId).firstOrNull;
    final p = m?.proposal;
    if (m == null || p == null || m.status == ProposalStatus.saving) return;
    _update(messageId, (x) => x.copyWith(status: ProposalStatus.saving));
    try {
      final saved = await TransactionActions.fromRef(ref).create(p.toDraft());
      _update(
        messageId,
        (x) =>
            x.copyWith(status: ProposalStatus.saved, savedId: () => saved.id),
      );
    } on Object {
      _update(messageId, (x) => x.copyWith(status: ProposalStatus.pending));
      rethrow;
    }
  }

  Future<void> undo(String messageId) async {
    final m = state.messages.where((x) => x.id == messageId).firstOrNull;
    final id = m?.savedId;
    if (id == null) return;
    await TransactionActions.fromRef(ref).delete(id);
    _update(
      messageId,
      (x) => x.copyWith(status: ProposalStatus.undone, savedId: () => null),
    );
  }

  void markEdited(String messageId) =>
      _update(messageId, (x) => x.copyWith(status: ProposalStatus.edited));

  /// Starter ideas for an empty chat.
  static List<String> suggestions(MoneyContext? c) => [
    'Spent 250 on lunch from ${c?.accounts.firstOrNull?.name ?? 'Cash'}',
    'How much did I spend this week?',
    'What’s my net worth?',
    if (c?.budgets.isNotEmpty ?? false)
      'How’s my ${c!.budgets.first.category} budget?'
    else
      'Where did my money go this month?',
  ];
}
