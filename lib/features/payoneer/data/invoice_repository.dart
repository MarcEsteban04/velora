import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/time/app_clock.dart';
import '../domain/invoice.dart';

abstract interface class InvoiceRepository {
  /// Every invoice, newest first.
  Future<List<Invoice>> fetchAll();

  Future<Invoice> create(InvoiceDraft draft);

  Future<Invoice> update(String id, InvoiceDraft draft);

  Future<void> setStatus(String id, InvoiceStatus status);

  Future<void> delete(String id);

  /// Marks it paid and logs [amountMinor] as income on its account, in one
  /// step. Returns the new transaction's id.
  Future<String> markPaid(
    Invoice invoice, {
    required int amountMinor,
    required DateTime paidAt,
    String? categoryId,
    String? note,
  });
}

class SupabaseInvoiceRepository implements InvoiceRepository {
  SupabaseInvoiceRepository(this._db);

  final SupabaseClient _db;

  SupabaseQueryBuilder get _table => _db.from('invoices');

  @override
  Future<List<Invoice>> fetchAll() async {
    final rows = await _table
        .select()
        .order('issued_on', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(Invoice.fromRow).toList();
  }

  @override
  Future<Invoice> create(InvoiceDraft draft) async =>
      Invoice.fromRow(await _table.insert(draft.toRow()).select().single());

  @override
  Future<Invoice> update(String id, InvoiceDraft draft) async =>
      Invoice.fromRow(
        await _table.update(draft.toRow()).eq('id', id).select().single(),
      );

  @override
  Future<void> setStatus(String id, InvoiceStatus status) =>
      _table.update({'status': status.name}).eq('id', id);

  @override
  Future<void> delete(String id) => _table.delete().eq('id', id);

  @override
  Future<String> markPaid(
    Invoice invoice, {
    required int amountMinor,
    required DateTime paidAt,
    String? categoryId,
    String? note,
  }) async => await _db.rpc<String>(
    'mark_invoice_paid',
    params: {
      'p_invoice': invoice.id,
      'p_amount_minor': amountMinor,
      'p_paid_at': AppClock.toUtc(paidAt).toIso8601String(),
      'p_category': categoryId,
      'p_note': note,
    },
  );
}

final invoiceRepositoryProvider = Provider<InvoiceRepository>(
  (ref) => SupabaseInvoiceRepository(ref.watch(supabaseClientProvider)),
);
