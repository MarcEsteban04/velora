import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_client.dart';
import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/island_toast.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/scene_scaffold.dart';
import '../../../core/widgets/velora_mascot.dart';
import '../../accounts/data/account_repository.dart';
import '../../ask/domain/chat_message.dart';
import '../../ask/domain/transaction_parser.dart';
import '../../ask/presentation/widgets/proposal_card.dart';
import '../../profile/application/main_currency.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transaction_entry_screen.dart';
import '../application/receipt_to_transaction.dart';
import '../data/receipt_reader.dart';
import '../domain/receipt.dart';
import 'widgets/scanning_preview.dart';

enum _Stage { start, reading, result, failed }

/// Snap or pick a receipt, or proof of money in (cashback, interest, a
/// refund, a "you have received" screenshot). Velora reads the amount,
/// store or source, date and items, and offers an expense or income to
/// confirm. Nothing is saved without a tap.
class ScanReceiptScreen extends ConsumerStatefulWidget {
  const ScanReceiptScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const ScanReceiptScreen());

  @override
  ConsumerState<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends ConsumerState<ScanReceiptScreen> {
  _Stage _stage = _Stage.start;
  ReceiptPhoto? _photo;
  ReceiptScan? _scan;

  /// What was read, before any Money in / Money out correction.
  ReceiptScan? _original;
  ParsedTransaction? _proposal;
  ProposalStatus _status = ProposalStatus.pending;
  Transaction? _saved;

  Future<void> _take({required bool camera}) async {
    final toast = Toast.of(context);
    try {
      final photo = await ref
          .read(receiptPhotoSourceProvider)
          .take(camera: camera);
      if (photo == null || !mounted) return;
      setState(() {
        _photo = photo;
        _stage = _Stage.reading;
        _status = ProposalStatus.pending;
        _saved = null;
      });
      await _read(photo);
    } on PlatformException catch (error) {
      toast.error(
        error.code.contains('denied')
            ? 'Velora needs camera access. Allow it in your phone’s settings.'
            : friendlyError(error, action: 'open the camera'),
      );
    }
  }

  Future<void> _read(ReceiptPhoto photo) async {
    final categories = await ref.read(categoriesProvider.future);
    final accounts = await ref.read(accountsProvider.future);
    List<String> names(TransactionKind kind) => [
      for (final c in categories)
        if (c.kind == kind && !c.hidden) c.name,
    ];
    final scan = await ref.read(receiptReaderProvider).read(photo, (
      expense: names(TransactionKind.expense),
      income: names(TransactionKind.income),
    ));
    if (!mounted) return;
    if (scan == null || accounts.isEmpty) {
      HapticFeedback.mediumImpact();
      setState(() => _stage = _Stage.failed);
      return;
    }
    final recent = ref.read(recentTransactionsProvider).value;
    final last = recent?.firstOrNull?.accountId;
    HapticFeedback.mediumImpact();
    setState(() {
      _scan = scan;
      _original = scan;
      _proposal = receiptToTransaction(
        scan,
        accounts: accounts,
        categories: categories,
        now: AppClock.now(),
        accountId: accounts.any((a) => a.id == last)
            ? last!
            : accounts.first.id,
      );
      _stage = _Stage.result;
    });
  }

  /// The user says it's the other way round: money in, not out, or back.
  void _flip(TransactionKind kind) {
    final scan = _scan, original = _original, p = _proposal;
    if (scan == null || original == null || p == null || scan.kind == kind) {
      return;
    }
    HapticFeedback.selectionClick();
    // From the original, so flipping back restores the AI's category.
    final flipped = original.withKind(kind);
    setState(() {
      _scan = flipped;
      _proposal = receiptToTransaction(
        flipped,
        accounts: ref.read(accountsProvider).value ?? const [],
        categories: ref.read(categoriesProvider).value ?? const [],
        now: AppClock.now(),
        accountId: p.accountId,
      );
    });
  }

  Future<void> _confirm() async {
    final p = _proposal;
    if (p == null) return;
    final toast = Toast.of(context);
    setState(() => _status = ProposalStatus.saving);
    try {
      final actions = TransactionActions.of(context);
      var saved = await actions.create(p.toDraft());
      // The photo you scanned comes along as the receipt.
      if (_photo case final photo?) {
        try {
          saved = await actions.attachReceipt(saved.id, photo.bytes);
        } on Object catch (error) {
          friendlyError(error, action: 'upload the receipt');
          toast.error(
            'Logged, but the receipt photo didn’t upload. Add it from '
            'History.',
          );
        }
      }
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _status = ProposalStatus.saved;
          _saved = saved;
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _status = ProposalStatus.pending);
      toast.error(friendlyError(error, action: 'log the receipt'));
    }
  }

  Future<void> _undo() async {
    final saved = _saved;
    if (saved == null) return;
    final toast = Toast.of(context);
    final actions = TransactionActions.of(context);
    try {
      // Undo takes the uploaded photo with it.
      if (saved.hasReceipt) await actions.removeReceipt(saved);
      await actions.delete(saved.id);
      if (mounted) {
        setState(() {
          _status = ProposalStatus.undone;
          _saved = null;
        });
      }
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'undo that'));
    }
  }

  void _edit() {
    final p = _proposal;
    if (p == null) return;
    setState(() => _status = ProposalStatus.edited);
    Navigator.of(context).push(
      TransactionEntryScreen.route(
        prefill: p.toDraft(),
        receipt: _photo?.bytes,
      ),
    );
  }

  void _restart() => setState(() {
    _stage = _Stage.start;
    _photo = null;
    _scan = null;
    _original = null;
    _proposal = null;
    _status = ProposalStatus.pending;
    _saved = null;
  });

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final currency = ref.watch(mainCurrencyProvider);

    final body = switch (_stage) {
      _Stage.start => [
        _Start(
          onCamera: () => _take(camera: true),
          onGallery: () => _take(camera: false),
        ),
      ],
      _Stage.reading => [
        ScanningPreview(
          bytes: _photo!.bytes,
          steps: const [
            'Finding the total…',
            'Reading the store and date…',
            'Picking a category…',
          ],
        ),
      ],
      _Stage.failed => [
        _Failed(
          photo: _photo,
          onRetake: () => _take(camera: true),
          onGallery: () => _take(camera: false),
          onManual: () =>
              Navigator.of(context)
                  .pushReplacement(TransactionEntryScreen.route()),
        ),
      ],
      _Stage.result => [
        FadeSlideIn(
          child: _SourceRow(photo: _photo!, source: _scan!.source),
        ),
        const SizedBox(height: 12),
        if (_status == ProposalStatus.pending) ...[
          FadeSlideIn(
            delay: const Duration(milliseconds: 40),
            child: _Direction(kind: _scan!.kind, onChanged: _flip),
          ),
          const SizedBox(height: 10),
        ],
        FadeSlideIn(
          delay: const Duration(milliseconds: 80),
          child: ProposalCard(
            proposal: _proposal!,
            status: _status,
            accounts: {for (final a in accounts) a.id: a},
            categories: {for (final c in categories) c.id: c},
            onConfirm: _confirm,
            onEdit: _edit,
            onUndo: _undo,
          ),
        ),
        if (_scan!.items.isNotEmpty) ...[
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: const Duration(milliseconds: 140),
            child: _Items(items: _scan!.items, currency: currency),
          ),
        ],
        const SizedBox(height: 18),
        if (_status == ProposalStatus.saved ||
            _status == ProposalStatus.undone ||
            _status == ProposalStatus.edited)
          Row(
            children: [
              Expanded(
                child: PressableButton(
                  label: 'Scan another',
                  icon: Icons.document_scanner_rounded,
                  height: 52,
                  variant: PressableButtonVariant.light,
                  onPressed: _restart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PressableButton(
                  label: 'Done',
                  height: 52,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ],
          )
        else
          Center(
            child: TextButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Scan a different receipt'),
            ),
          ),
      ],
    };

    return SceneScaffold(
      eyebrow: 'Quick add',
      title: 'Scan receipt',
      children: body,
    );
  }
}

class _Start extends StatelessWidget {
  const _Start({required this.onCamera, required this.onGallery});

  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget tip(IconData icon, String label) => Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.accentBright, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: text.labelMedium?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );

    return FadeSlideIn(
      child: GlassCard(
        child: Column(
          children: [
            const VeloraMascot(pose: MascotPose.coin, size: 130, halo: false),
            const SizedBox(height: 6),
            Text('Snap it, done', style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'A receipt, or proof of money in like cashback, interest or a '
              '“you received” screenshot. Velora reads the amount, where '
              'it’s from and the date. You check it before anything is '
              'logged.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                tip(Icons.wb_sunny_rounded, 'Bright and flat'),
                tip(Icons.crop_free_rounded, 'Whole receipt in frame'),
                tip(Icons.receipt_long_rounded, 'One at a time'),
              ],
            ),
            const SizedBox(height: 20),
            PressableButton(
              label: 'Take a photo',
              icon: Icons.photo_camera_rounded,
              onPressed: onCamera,
            ),
            const SizedBox(height: 10),
            PressableButton(
              label: 'Choose from gallery',
              icon: Icons.photo_library_rounded,
              variant: PressableButtonVariant.light,
              height: 52,
              onPressed: onGallery,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.lock_rounded, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    AiClient.isConfigured
                        ? 'The photo is sent to the AI to read and isn’t kept. '
                              'Offline, it’s read on your phone.'
                        : 'Read on your phone. The photo never leaves it.',
                    style: text.labelMedium?.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The photo with a scan line sweeping over it while it's read.
class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.photo, required this.source});

  final ReceiptPhoto photo;
  final ReceiptSource source;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ai = source == ReceiptSource.ai;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            photo.bytes,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            cacheWidth: 156,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Here’s what I read', style: text.titleMedium),
              Row(
                children: [
                  Icon(
                    ai
                        ? Icons.auto_awesome_rounded
                        : Icons.phone_android_rounded,
                    size: 13,
                    color: ai ? AppColors.ember : AppColors.sky,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ai ? 'Read by AI' : 'Read on your phone',
                    style: text.labelMedium?.copyWith(fontSize: 11),
                  ),
                  Flexible(
                    child: Text(
                      ' · check it before logging',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelMedium?.copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Items extends StatelessWidget {
  const _Items({required this.items, required this.currency});

  final List<ReceiptItem> items;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ON THE RECEIPT',
            style: text.labelMedium?.copyWith(fontSize: 11, letterSpacing: 1.4),
          ),
          const SizedBox(height: 6),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      i.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                  ),
                  Text(
                    Money.format(i.amountMinor, currency),
                    style: text.labelMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({
    required this.photo,
    required this.onRetake,
    required this.onGallery,
    required this.onManual,
  });

  final ReceiptPhoto? photo;
  final VoidCallback onRetake;
  final VoidCallback onGallery;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      child: Column(
        children: [
          const VeloraMascot(pose: MascotPose.wave, size: 110, halo: false),
          const SizedBox(height: 6),
          Text('I couldn’t find a total', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Try a brighter, flatter photo with the whole receipt in frame.',
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          const SizedBox(height: 16),
          PressableButton(
            label: 'Retake',
            icon: Icons.photo_camera_rounded,
            onPressed: onRetake,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onGallery,
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('From gallery'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: onManual,
                  icon: const Icon(Icons.keyboard_rounded),
                  label: const Text('Type it in'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Money out or money in, for when the scan guessed wrong.
class _Direction extends StatelessWidget {
  const _Direction({required this.kind, required this.onChanged});

  final TransactionKind kind;
  final ValueChanged<TransactionKind> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<TransactionKind>(
    segments: const [
      ButtonSegment(
        value: TransactionKind.expense,
        icon: Icon(Icons.north_east_rounded, size: 18),
        label: Text('Money out'),
      ),
      ButtonSegment(
        value: TransactionKind.income,
        icon: Icon(Icons.south_west_rounded, size: 18),
        label: Text('Money in'),
      ),
    ],
    selected: {kind},
    showSelectedIcon: false,
    onSelectionChanged: (s) => onChanged(s.first),
  );
}
