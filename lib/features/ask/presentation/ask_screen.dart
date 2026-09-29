import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dusk_backdrop.dart';
import '../../../core/widgets/island_toast.dart';
import '../../../core/widgets/velora_mascot.dart';
import '../../accounts/data/account_repository.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/presentation/transaction_entry_screen.dart';
import '../application/ask_controller.dart';
import '../application/money_context_provider.dart';
import '../domain/chat_message.dart';
import 'widgets/chat_bubbles.dart';
import 'widgets/proposal_card.dart';

/// Ask Velora: log money by chatting, and ask about it.
class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const AskScreen());

  @override
  ConsumerState<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends ConsumerState<AskScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final t = (text ?? _input.text).trim();
    if (t.isEmpty) return;
    HapticFeedback.lightImpact();
    _input.clear();
    setState(() {});
    ref.read(askProvider.notifier).send(t);
  }

  Future<void> _confirm(ChatMessage m) async {
    final toast = Toast.of(context);
    try {
      await ref.read(askProvider.notifier).confirm(m.id);
      HapticFeedback.mediumImpact();
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'log that'));
    }
  }

  Future<void> _undo(ChatMessage m) async {
    final toast = Toast.of(context);
    try {
      await ref.read(askProvider.notifier).undo(m.id);
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'undo that'));
    }
  }

  void _edit(ChatMessage m) {
    ref.read(askProvider.notifier).markEdited(m.id);
    Navigator.of(context)
        .push(TransactionEntryScreen.route(prefill: m.proposal!.toDraft()));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final chat = ref.watch(askProvider);
    // Keeps the money summary loaded while the chat is open.
    final money = ref.watch(moneyContextProvider);
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final fresh = chat.messages.length == 1;

    // Newest at the bottom; the list is reversed so it starts there.
    final items = <Widget>[
      for (final (i, m) in chat.messages.indexed) ...[
        if (m.role == ChatRole.user)
          UserBubble(text: m.text)
        else
          VeloraBubble(
            text: m.text,
            fromAi: m.fromAi,
            showAvatar: i == 0 || chat.messages[i - 1].role != ChatRole.velora,
          ),
        if (m.proposal case final p?)
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: 10),
            child: ProposalCard(
              proposal: p,
              status: m.status,
              accounts: {for (final a in accounts) a.id: a},
              categories: {for (final c in categories) c.id: c},
              onConfirm: () => _confirm(m),
              onEdit: () => _edit(m),
              onUndo: () => _undo(m),
            ),
          ),
        if (i == 0 && fresh) ...[
          const PrivacyNote(),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in AskController.suggestions(money))
                ActionChip(
                  label: Text(s),
                  onPressed: () => _send(s),
                  labelStyle: text.labelMedium?.copyWith(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  backgroundColor: AppColors.surface.withValues(alpha: 0.7),
                  side: BorderSide(color: AppColors.hairline(0.1)),
                  shape: const StadiumBorder(),
                ),
            ],
          ),
        ],
      ],
      if (chat.thinking) const TypingBubble(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: DuskBackdrop(showMoon: false)),
          Positioned.fill(
            child: ColoredBox(color: AppColors.night.withValues(alpha: 0.8)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const VeloraMascot(
                        pose: MascotPose.wave,
                        size: 44,
                        halo: false,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ask Velora',
                              style: text.titleMedium?.copyWith(fontSize: 17),
                            ),
                            Text(
                              chat.thinking
                                  ? 'Thinking…'
                                  : 'Log or ask anything',
                              style: text.labelMedium?.copyWith(
                                fontSize: 11,
                                color: chat.thinking
                                    ? AppColors.accentBright
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!fresh)
                        IconButton(
                          tooltip: 'New chat',
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            ref.read(askProvider.notifier).clear();
                          },
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    children: items.reversed.toList(),
                  ),
                ),
                _Composer(
                  controller: _input,
                  focus: _focus,
                  busy: chat.thinking,
                  onChanged: () => setState(() {}),
                  onSend: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.busy,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool busy;
  final VoidCallback onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final canSend = controller.text.trim().isNotEmpty && !busy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              inputFormatters: [LengthLimitingTextInputFormatter(400)],
              onChanged: (_) => onChanged(),
              onSubmitted: (_) => onSend(),
              style: text.bodyLarge?.copyWith(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Spent 250 on lunch… or ask me',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Send',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: canSend ? onSend : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: canSend
                      ? AppColors.accent
                      : AppColors.surface.withValues(alpha: 0.8),
                ),
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: canSend ? AppColors.onBrand : AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
