import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
import '../../accounts/domain/account.dart';
import '../../profile/data/profile_repository.dart';
import '../../receipts/data/receipt_reader.dart';
import '../../receipts/domain/receipt.dart';
import '../../receipts/presentation/widgets/scanning_preview.dart';
import '../../transactions/application/transaction_providers.dart';
import '../application/invoice_import.dart';
import '../application/payoneer_providers.dart';
import '../data/invoice_reader.dart';
import '../domain/invoice.dart';
import '../domain/invoice_scan.dart';
import 'invoice_sheet.dart';

enum _Stage { start, reading, done, failed }

/// Snap, pick or import an invoice or payment notice; Velora reads it and
/// logs it straight away: a new invoice, marked paid (with the salary)
/// when the document shows the money arrived. Undo takes it all back.
class ScanInvoiceScreen extends ConsumerStatefulWidget {
  const ScanInvoiceScreen({super.key, required this.account});

  final Account account;

  static Route<void> route(Account account) =>
      MaterialPageRoute(builder: (_) => ScanInvoiceScreen(account: account));

  @override
  ConsumerState<ScanInvoiceScreen> createState() => _ScanInvoiceScreenState();
}

class _ScanInvoiceScreenState extends ConsumerState<ScanInvoiceScreen> {
  _Stage _stage = _Stage.start;
  ReceiptPhoto? _page;
  InvoiceScan? _scan;
  InvoiceImport? _result;
  bool _undone = false;
  bool _busy = false;

  late final Currency _currency = Currencies.byCode(
    widget.account.currencyCode,
  );

  Future<void> _get(
    Future<ReceiptPhoto?> Function(InvoiceDocumentSource s) pick,
  ) async {
    final toast = Toast.of(context);
    try {
      final page = await pick(ref.read(invoiceDocumentSourceProvider));
      if (page == null || !mounted) return;
      setState(() {
        _page = page;
        _stage = _Stage.reading;
        _result = null;
        _undone = false;
      });
      await _read(page);
    } on PlatformException catch (error) {
      toast.error(
        error.code.contains('denied')
            ? 'Velora needs camera access. Allow it in your phone’s settings.'
            : friendlyError(error, action: 'open that'),
      );
    } on Object catch (error) {
      // A PDF that won't render, for example.
      toast.error(friendlyError(error, action: 'open that file'));
      if (mounted && _stage == _Stage.reading) {
        setState(() => _stage = _Stage.failed);
      }
    }
  }

  Future<void> _read(ReceiptPhoto page) async {
    final toast = Toast.of(context);
    final name = ref.read(profileProvider).value?.name ?? 'the user';
    final scan = await ref
        .read(invoiceReaderProvider)
        .read(page, userName: name, currencyCode: _currency.code);
    if (!mounted) return;
    if (scan == null) {
      HapticFeedback.mediumImpact();
      setState(() => _stage = _Stage.failed);
      return;
    }
    // Logged right away; the result card offers Undo and Edit.
    try {
      final existing = await ref.read(invoicesProvider.future);
      final categories = await ref.read(categoriesProvider.future);
      if (!mounted) return;
      final result = await logScannedInvoice(
        InvoiceActions.of(context),
        scan: scan,
        account: widget.account,
        existing: existing,
        today: AppClock.now(),
        categoryId: salaryCategory(categories)?.id,
      );
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _scan = scan;
          _result = result;
          _stage = _Stage.done;
        });
      }
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'log the invoice'));
      if (mounted) setState(() => _stage = _Stage.failed);
    }
  }

  Future<void> _undo() async {
    final result = _result;
    if (result == null || _busy) return;
    final toast = Toast.of(context);
    setState(() => _busy = true);
    try {
      await undoScannedInvoice(InvoiceActions.of(context), result);
      if (mounted) setState(() => _undone = true);
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'undo that'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _restart() => setState(() {
    _stage = _Stage.start;
    _page = null;
    _scan = null;
    _result = null;
    _undone = false;
  });

  @override
  Widget build(BuildContext context) {
    final body = switch (_stage) {
      _Stage.start => [
        _Start(
          onCamera: () => _get((s) => s.take(camera: true)),
          onGallery: () => _get((s) => s.take(camera: false)),
          onImport: () => _get((s) => s.import()),
        ),
      ],
      _Stage.reading => [
        ScanningPreview(
          bytes: _page!.bytes,
          steps: const [
            'Finding the amount…',
            'Reading the invoice number…',
            'Checking if it’s paid…',
          ],
        ),
      ],
      _Stage.failed => [_Failed(onRetry: _restart)],
      _Stage.done => [
        FadeSlideIn(
          child: _ResultCard(
            result: _result!,
            scan: _scan!,
            currency: _currency,
            undone: _undone,
            busy: _busy,
            onUndo: _undo,
            onEdit: switch (_result!) {
              InvoiceLogged(:final invoice) ||
              InvoiceMarkedPaid(:final invoice) ||
              InvoiceAlreadyLogged(:final invoice) => () => InvoiceSheet.show(
                context,
                account: widget.account,
                invoice: invoice,
              ),
              InvoiceOtherCurrency() => () => InvoiceSheet.show(
                context,
                account: widget.account,
                draft: InvoiceDraft(
                  accountId: widget.account.id,
                  client: _scan!.client ?? '',
                  reference: _scan!.reference,
                  amountMinor: 0,
                  issuedOn: _scan!.issuedOn ?? AppClock.now(),
                ),
              ),
            },
          ),
        ),
        const SizedBox(height: 16),
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
        ),
      ],
    };

    return SceneScaffold(
      eyebrow: widget.account.name,
      title: 'Scan invoice',
      children: body,
    );
  }
}

class _Start extends StatelessWidget {
  const _Start({
    required this.onCamera,
    required this.onGallery,
    required this.onImport,
  });

  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return FadeSlideIn(
      child: GlassCard(
        child: Column(
          children: [
            const VeloraMascot(pose: MascotPose.coin, size: 120, halo: false),
            const SizedBox(height: 6),
            Text('Scan and it’s logged', style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'An invoice or payment email from Payoneer: the PDF, a '
              'screenshot or a photo. Velora reads the number, client and '
              'amount, logs it, and marks it paid if the money arrived. '
              'You can undo.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
            const SizedBox(height: 18),
            PressableButton(
              label: 'Import a PDF or image',
              icon: Icons.upload_file_rounded,
              onPressed: onImport,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: PressableButton(
                    label: 'Take a photo',
                    icon: Icons.photo_camera_rounded,
                    height: 50,
                    variant: PressableButtonVariant.light,
                    onPressed: onCamera,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PressableButton(
                    label: 'Screenshot',
                    icon: Icons.photo_library_rounded,
                    height: 50,
                    variant: PressableButtonVariant.light,
                    onPressed: onGallery,
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

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.scan,
    required this.currency,
    required this.undone,
    required this.busy,
    required this.onUndo,
    required this.onEdit,
  });

  final InvoiceImport result;
  final InvoiceScan scan;
  final Currency currency;
  final bool undone;
  final bool busy;
  final VoidCallback onUndo;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    String money(int m) => Money.format(m, currency);
    final landed = scan.paidMinor ?? scan.amountMinor;

    final (
      IconData icon,
      Color color,
      String title,
      String detail,
    ) = switch (result) {
      _ when undone => (
        Icons.undo_rounded,
        AppColors.textMuted,
        'Undone',
        'Nothing from this scan is logged.',
      ),
      InvoiceLogged(:final invoice, paidTransactionId: _?) => (
        Icons.payments_rounded,
        AppColors.accentBright,
        'Logged as paid',
        '${invoice.title} · ${money(landed)} salary added',
      ),
      InvoiceLogged(:final invoice) => (
        Icons.receipt_long_rounded,
        AppColors.ember,
        'Invoice logged',
        '${invoice.title} is waiting for payment',
      ),
      InvoiceMarkedPaid(:final invoice) => (
        Icons.payments_rounded,
        AppColors.accentBright,
        'Marked paid',
        '${invoice.title} · ${money(landed)} salary added',
      ),
      InvoiceAlreadyLogged(:final invoice) => (
        Icons.check_circle_rounded,
        AppColors.sky,
        'Already logged',
        '${invoice.title} is ${invoice.isWaiting ? 'waiting for payment' : invoice.status.name}',
      ),
      InvoiceOtherCurrency(:final currencyCode) => (
        Icons.currency_exchange_rounded,
        AppColors.rust,
        'This one is in $currencyCode',
        'Your ${currency.code} account can’t take it as is. Check the '
            'amount and log it yourself.',
      ),
    };

    final rows = <(String, String)>[
      if (scan.client != null) ('Client', scan.client!),
      if (scan.reference != null) ('Invoice no.', scan.reference!),
      (
        'Amount',
        scan.currencyCode == null || scan.currencyCode == currency.code
            ? money(scan.amountMinor)
            : Money.format(
                scan.amountMinor,
                Currencies.byCode(scan.currencyCode!),
              ),
      ),
      if (scan.issuedOn != null)
        ('Sent', DateFormat('MMM d, y').format(scan.issuedOn!)),
      ('Paid', scan.paid ? 'Yes' : 'Not yet'),
      if (scan.paid && scan.paidMinor != null)
        ('Arrived', money(scan.paidMinor!)),
    ];
    final canUndo =
        !undone && (result is InvoiceLogged || result is InvoiceMarkedPaid);

    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    Text(detail, style: text.labelMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(label, style: text.labelMedium),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: text.titleMedium?.copyWith(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          if (scan.source == ReceiptSource.device)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Read on your phone. Check the details.',
                style: text.labelMedium,
              ),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (canUndo)
                TextButton.icon(
                  onPressed: busy ? null : onUndo,
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: const Text('Undo'),
                ),
              if (!undone)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: Icon(
                    result is InvoiceOtherCurrency
                        ? Icons.edit_note_rounded
                        : Icons.edit_rounded,
                    size: 18,
                  ),
                  label: Text(
                    result is InvoiceOtherCurrency ? 'Log it myself' : 'Edit',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      child: Column(
        children: [
          const VeloraMascot(pose: MascotPose.wallet, size: 110, halo: false),
          const SizedBox(height: 8),
          Text('I couldn’t read an invoice', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Try the PDF itself, or a sharper screenshot with the amount in '
            'view.',
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          const SizedBox(height: 16),
          PressableButton(
            label: 'Try again',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
