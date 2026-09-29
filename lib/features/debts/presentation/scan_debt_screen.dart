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
import '../../../core/widgets/money_fields.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/scene_scaffold.dart';
import '../../../core/widgets/velora_mascot.dart';
import '../../payoneer/data/invoice_reader.dart';
import '../../receipts/data/receipt_reader.dart';
import '../../receipts/presentation/widgets/scanning_preview.dart';
import '../application/debt_providers.dart';
import '../data/debt_scan_reader.dart';
import '../domain/debt.dart';
import 'debt_bill_sheet.dart';

enum _Stage { start, reading, done, failed }

/// What the scan did, for the result card and Undo.
sealed class _Result {
  const _Result();
}

final class _Bought extends _Result {
  const _Bought(this.scan, this.entry);
  final DebtPurchase scan;
  final DebtEntry entry;
}

final class _Billed extends _Result {
  const _Billed(this.scan, this.before, this.limit, this.bills);
  final DebtBill scan;
  final Debt before;
  final int? limit;

  /// The bills it added, each with the one it replaced (for Undo).
  final List<(CreditBill, CreditBill?)> bills;
}

/// Snap or pick a screenshot from SPayLater, BillEase or a card app. A
/// purchase is added to the debt (over its installments); a bill, or the
/// list of them, adds the bills and updates the limit. Logged straight
/// away, with Undo.
class ScanDebtScreen extends ConsumerStatefulWidget {
  const ScanDebtScreen({super.key, required this.debtId});

  final String debtId;

  static Route<void> route(String debtId) =>
      MaterialPageRoute(builder: (_) => ScanDebtScreen(debtId: debtId));

  @override
  ConsumerState<ScanDebtScreen> createState() => _ScanDebtScreenState();
}

class _ScanDebtScreenState extends ConsumerState<ScanDebtScreen> {
  _Stage _stage = _Stage.start;
  ReceiptPhoto? _page;
  _Result? _result;
  bool _undone = false;
  bool _matched = false;
  bool _busy = false;

  DebtProgress? get _progress => ref
      .read(debtProgressProvider)
      ?.where((p) => p.debt.id == widget.debtId)
      .firstOrNull;

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
        _matched = false;
      });
      await _read(page);
    } on PlatformException catch (error) {
      toast.error(
        error.code.contains('denied')
            ? 'Velora needs camera access. Allow it in your phone’s settings.'
            : friendlyError(error, action: 'open that'),
      );
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'open that file'));
      if (mounted && _stage == _Stage.reading) {
        setState(() => _stage = _Stage.failed);
      }
    }
  }

  Future<void> _read(ReceiptPhoto page) async {
    final p = _progress;
    if (p == null) return;
    final toast = Toast.of(context);
    final actions = DebtActions.of(context);
    final scan = await ref
        .read(debtScanReaderProvider)
        .read(page, debtName: p.debt.name, currencyCode: p.debt.currencyCode);
    if (!mounted) return;
    if (scan == null) {
      HapticFeedback.mediumImpact();
      setState(() => _stage = _Stage.failed);
      return;
    }
    try {
      final _Result result;
      switch (scan) {
        case DebtPurchase():
          final entry = await actions.borrow(
            p.debt,
            amountMinor: scan.totalMinor,
            at: atNow(scan.date ?? AppClock.now()),
            note: scan.note,
            installments: scan.installments,
          );
          result = _Bought(scan, entry);
        case DebtBill():
          // No limit on the screen: available plus owed makes it.
          final limit =
              scan.creditLimitMinor ??
              switch (scan.availableMinor) {
                final a? => a + (scan.outstandingMinor ?? p.remainingMinor),
                null => null,
              };
          final unpaid = scan.unpaidBills;
          final bills = <(CreditBill, CreditBill?)>[
            for (final b in unpaid)
              await actions.putBill(
                p.debt,
                amountMinor: b.amountMinor,
                dueOn: b.dueOn,
              ),
          ];
          // With bills, they say what's due; the single latest bill goes.
          final before = await actions.setBill(
            p.debt,
            dueMinor: bills.isNotEmpty
                ? null
                : scan.dueMinor ?? p.debt.billDueMinor,
            dueOn: bills.isNotEmpty ? null : scan.dueOn ?? p.debt.billDueOn,
            creditLimitMinor: limit,
          );
          result = _Billed(scan, before, limit, bills);
      }
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _result = result;
          _stage = _Stage.done;
        });
      }
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'log that'));
      if (mounted) setState(() => _stage = _Stage.failed);
    }
  }

  Future<void> _undo() async {
    final r = _result;
    if (r == null || _busy) return;
    final toast = Toast.of(context);
    final actions = DebtActions.of(context);
    setState(() => _busy = true);
    try {
      switch (r) {
        case _Bought(:final entry):
          await actions.undo(entry);
        case _Billed(:final before, :final bills):
          for (final (bill, was) in bills.reversed) {
            await actions.unputBill(bill, was);
          }
          await actions.restoreBill(before);
      }
      if (mounted) setState(() => _undone = true);
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'undo that'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Makes Velora's balance match what the app says is owed.
  Future<void> _match(int outstanding) async {
    final p = _progress;
    if (p == null || _busy) return;
    final toast = Toast.of(context);
    final actions = DebtActions.of(context);
    final diff = outstanding - p.remainingMinor;
    if (diff == 0) return;
    setState(() => _busy = true);
    try {
      final entry = diff > 0
          ? await actions.borrow(
              p.debt,
              amountMinor: diff,
              at: AppClock.now(),
              note: 'Matched to the app',
            )
          : await actions.pay(
              p.debt,
              amountMinor: -diff,
              paidAt: AppClock.now(),
            );
      HapticFeedback.selectionClick();
      toast.show(
        'Balance matched',
        action: ToastAction('Undo', () => actions.undo(entry)),
      );
      if (mounted) setState(() => _matched = true);
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'match the balance'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(debtProgressProvider);
    final p = list?.where((d) => d.debt.id == widget.debtId).firstOrNull;
    if (p == null) {
      return const SceneScaffold(title: 'Scan', children: []);
    }
    final c = Currencies.byCode(p.debt.currencyCode);

    final body = switch (_stage) {
      _Stage.start => [
        _Start(
          name: p.debt.name,
          onImport: () => _get((s) => s.import()),
          onGallery: () => _get((s) => s.take(camera: false)),
          onCamera: () => _get((s) => s.take(camera: true)),
        ),
      ],
      _Stage.reading => [
        ScanningPreview(
          bytes: _page!.bytes,
          steps: const [
            'Reading the amounts…',
            'Checking for installments…',
            'Finding the due date…',
          ],
        ),
      ],
      _Stage.failed => [
        _Failed(onRetry: () => setState(() => _stage = _Stage.start)),
      ],
      _Stage.done => [
        FadeSlideIn(
          child: _ResultCard(
            result: _result!,
            progress: p,
            currency: c,
            undone: _undone,
            matched: _matched,
            busy: _busy,
            onUndo: _undo,
            onMatch: _match,
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
                onPressed: () => setState(() => _stage = _Stage.start),
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

    return SceneScaffold(eyebrow: p.debt.name, title: 'Scan', children: body);
  }
}

class _Start extends StatelessWidget {
  const _Start({
    required this.name,
    required this.onImport,
    required this.onGallery,
    required this.onCamera,
  });

  final String name;
  final VoidCallback onImport;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return FadeSlideIn(
      child: GlassCard(
        child: Column(
          children: [
            const VeloraMascot(pose: MascotPose.coin, size: 110, halo: false),
            const SizedBox(height: 6),
            Text('Scan and it’s counted', style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'A screenshot from $name: something you bought (Velora adds it, '
              'over its installments), or your bill or “My Bill” list (Velora '
              'adds each month’s bill and updates your limit). You can undo.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
            const SizedBox(height: 18),
            PressableButton(
              label: 'Choose a screenshot',
              icon: Icons.photo_library_rounded,
              onPressed: onGallery,
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
                    label: 'PDF or file',
                    icon: Icons.upload_file_rounded,
                    height: 50,
                    variant: PressableButtonVariant.light,
                    onPressed: onImport,
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
    required this.progress,
    required this.currency,
    required this.undone,
    required this.matched,
    required this.busy,
    required this.onUndo,
    required this.onMatch,
  });

  final _Result result;
  final DebtProgress progress;
  final Currency currency;
  final bool undone;
  final bool matched;
  final bool busy;
  final VoidCallback onUndo;
  final ValueChanged<int> onMatch;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    String money(int m) => Money.format(m, currency);
    String date(DateTime d) => DateFormat('MMM d, y').format(d);

    final (
      IconData icon,
      Color color,
      String title,
      List<(String, String)> rows,
    ) = switch (result) {
      _ when undone => (
        Icons.undo_rounded,
        AppColors.textMuted,
        'Undone',
        const <(String, String)>[],
      ),
      _Bought(:final scan) => (
        Icons.shopping_bag_rounded,
        AppColors.ember,
        'Purchase added',
        [
          if (scan.note case final n?) ('What', n),
          ('Adds', money(scan.totalMinor)),
          if (scan.installments > 1)
            (
              'Installments',
              '${scan.installments} × ${money(scan.monthlyMinor ?? scan.totalMinor ~/ scan.installments)}',
            ),
          if (scan.date case final d?) ('Bought', date(d)),
        ],
      ),
      _Billed(:final scan, :final limit, :final bills) => (
        Icons.receipt_long_rounded,
        AppColors.sky,
        switch (bills.length) {
          0 => 'Bill updated',
          1 => 'Bill added',
          final n => '$n bills added',
        },
        [
          for (final (b, _) in bills)
            (
              billName(b),
              '${money(b.amountMinor)} · due ${DateFormat('MMM d').format(b.dueOn)}',
            ),
          if (bills.isEmpty) ...[
            if (scan.dueMinor case final d?) ('Due', money(d)),
            if (scan.dueOn case final d?) ('Due on', date(d)),
          ],
          if (limit case final l?) ('Credit limit', money(l)),
          if (scan.availableMinor case final a?) ('Available', money(a)),
          if (scan.outstandingMinor case final o?)
            ('Owed, per the app', money(o)),
        ],
      ),
    };

    // What the app says is owed, else at least what the bills ask for.
    final (int? outstanding, String says) = switch (result) {
      _Billed(:final scan) when scan.outstandingMinor != null => (
        scan.outstandingMinor,
        'The app says you owe',
      ),
      _Billed(:final bills)
          when bills.isNotEmpty &&
              progress.billsLeftMinor > progress.remainingMinor =>
        (progress.billsLeftMinor, 'Your bills add up to'),
      _ => (null, ''),
    };
    final mismatch =
        !undone &&
        !matched &&
        outstanding != null &&
        (outstanding - progress.remainingMinor).abs() >= 100;

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
                    Text(
                      undone
                          ? 'Nothing from this scan is counted.'
                          : '${money(progress.remainingMinor)} left on '
                                '${progress.debt.name}',
                      style: text.labelMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (rows.isNotEmpty) const SizedBox(height: 12),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
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
          if (mismatch) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.ember.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$says ${money(outstanding)}; Velora has '
                      '${money(progress.remainingMinor)}.',
                      style: text.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: busy ? null : () => onMatch(outstanding),
                    child: const Text('Match it'),
                  ),
                ],
              ),
            ),
          ],
          if (!undone)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: busy ? null : onUndo,
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: const Text('Undo'),
              ),
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
          Text('I couldn’t read that one', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Try a screenshot of the order or the bill with the amounts in '
            'view. Reading these needs the AI, so check your connection.',
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
