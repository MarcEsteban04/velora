import 'transaction_parser.dart';

enum ChatRole { user, velora }

/// Where a suggested transaction stands.
enum ProposalStatus {
  /// Waiting for "Log it".
  pending,
  saving,
  saved,

  /// Saved, then undone.
  undone,

  /// Opened in the full editor instead.
  edited,
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.proposal,
    this.status = ProposalStatus.pending,
    this.savedId,
    this.fromAi = false,
  });

  final String id;
  final ChatRole role;
  final String text;

  /// A transaction Velora understood and is offering to log.
  final ParsedTransaction? proposal;
  final ProposalStatus status;

  /// The transaction's id once logged, for Undo.
  final String? savedId;

  /// Written by the AI rather than worked out on the phone.
  final bool fromAi;

  ChatMessage copyWith({ProposalStatus? status, String? Function()? savedId}) =>
      ChatMessage(
        id: id,
        role: role,
        text: text,
        proposal: proposal,
        status: status ?? this.status,
        savedId: savedId == null ? this.savedId : savedId(),
        fromAi: fromAi,
      );
}

/// What the AI suggests logging, by name. It's matched to real accounts
/// and categories on the phone before anything is shown.
class AiAction {
  const AiAction({
    required this.kind,
    required this.amount,
    this.account,
    this.toAccount,
    this.category,
    this.note,
    this.date,
  });

  final String kind;
  final double amount;
  final String? account;
  final String? toAccount;
  final String? category;
  final String? note;
  final DateTime? date;

  static AiAction? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = json['kind'];
    final amount = json['amount'];
    if (kind is! String ||
        !const ['expense', 'income', 'transfer'].contains(kind)) {
      return null;
    }
    final value = switch (amount) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s.replaceAll(',', '')),
      _ => null,
    };
    if (value == null || value <= 0 || value > 1e10) return null;
    String? str(Object? v) =>
        v is String && v.trim().isNotEmpty ? v.trim() : null;
    return AiAction(
      kind: kind,
      amount: value,
      account: str(json['account']),
      toAccount: str(json['to_account']),
      category: str(json['category']),
      note: str(json['note']),
      date: switch (json['date']) {
        final String d => DateTime.tryParse(d),
        _ => null,
      },
    );
  }
}

class AiReply {
  const AiReply({required this.text, this.action});

  final String text;
  final AiAction? action;
}
