import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

/// Receipt photos in the private `receipts` bucket, one folder per user.
abstract interface class ReceiptStorage {
  /// Uploads (or replaces) the photo for [transactionId]. Returns its path.
  Future<String> upload(String transactionId, Uint8List jpeg);

  /// A short-lived link to show the photo.
  Future<String> url(String path);

  Future<void> remove(String path);
}

class SupabaseReceiptStorage implements ReceiptStorage {
  SupabaseReceiptStorage(this._db);

  final SupabaseClient _db;

  StorageFileApi get _bucket => _db.storage.from('receipts');

  @override
  Future<String> upload(String transactionId, Uint8List jpeg) async {
    final user = _db.auth.currentUser?.id;
    if (user == null) throw const AuthException('Not signed in');
    // Images may be PNG from the gallery; the name only needs to be stable.
    final png = jpeg.length > 4 && jpeg[0] == 0x89 && jpeg[1] == 0x50;
    final path = '$user/$transactionId.${png ? 'png' : 'jpg'}';
    await _bucket.uploadBinary(
      path,
      jpeg,
      fileOptions: FileOptions(
        contentType: png ? 'image/png' : 'image/jpeg',
        upsert: true,
      ),
    );
    return path;
  }

  @override
  Future<String> url(String path) => _bucket.createSignedUrl(path, 3600);

  @override
  Future<void> remove(String path) => _bucket.remove([path]);
}

final receiptStorageProvider = Provider<ReceiptStorage>(
  (ref) => SupabaseReceiptStorage(ref.watch(supabaseClientProvider)),
);

/// A link to show a receipt. Links expire, so it's fetched again whenever
/// nothing is showing it.
final receiptUrlProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, path) => ref.watch(receiptStorageProvider).url(path),
);
