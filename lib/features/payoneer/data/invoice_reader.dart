import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:printing/printing.dart';

import '../../../core/ai/ai_client.dart';
import '../../../core/time/app_clock.dart';
import '../../receipts/data/receipt_reader.dart';
import '../domain/invoice_scan.dart';

/// Where an invoice comes from: the camera, a photo or screenshot, or a
/// PDF or image file (Payoneer's invoices are usually PDFs).
abstract interface class InvoiceDocumentSource {
  Future<ReceiptPhoto?> take({required bool camera});

  /// A PDF (its first page, rendered) or an image file.
  Future<ReceiptPhoto?> import();
}

class DeviceInvoiceDocumentSource implements InvoiceDocumentSource {
  const DeviceInvoiceDocumentSource(this._photos);

  final ReceiptPhotoSource _photos;

  @override
  Future<ReceiptPhoto?> take({required bool camera}) =>
      _photos.take(camera: camera);

  @override
  Future<ReceiptPhoto?> import() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final isPdf =
        file.extension?.toLowerCase() == 'pdf' ||
        (bytes.length > 4 && String.fromCharCodes(bytes.take(4)) == '%PDF');
    final image = isPdf ? await _firstPage(bytes) : bytes;
    if (image == null) return null;
    // On-device text recognition reads from a file.
    final out = File(
      '${Directory.systemTemp.path}/velora_invoice_'
      '${DateTime.now().millisecondsSinceEpoch}.${isPdf ? 'png' : file.extension ?? 'jpg'}',
    );
    await out.writeAsBytes(image, flush: true);
    return ReceiptPhoto(bytes: image, path: out.path);
  }

  /// The first page as a PNG, sharp enough to read small print.
  static Future<Uint8List?> _firstPage(Uint8List pdf) async {
    await for (final page in Printing.raster(pdf, pages: const [0], dpi: 150)) {
      return page.toPng();
    }
    return null;
  }
}

/// Reads an invoice or payment notice.
abstract interface class InvoiceReader {
  /// [userName] is who the invoice is from, so it's never taken for the
  /// client. [currencyCode] is the account's, for amounts without one.
  Future<InvoiceScan?> read(
    ReceiptPhoto page, {
    required String userName,
    required String currencyCode,
  });
}

/// The AI first, then on-device text recognition when it's unavailable.
class SmartInvoiceReader implements InvoiceReader {
  const SmartInvoiceReader();

  @override
  Future<InvoiceScan?> read(
    ReceiptPhoto page, {
    required String userName,
    required String currencyCode,
  }) async {
    if (AiClient.isConfigured) {
      final now = AppClock.now();
      final raw = await AiClient.complete(
        system: prompt(userName: userName, today: now),
        messages: const [('user', 'Read this.')],
        image: page.bytes,
        json: true,
        maxTokens: 400,
        temperature: 0.1,
      );
      final scan = raw == null
          ? null
          : InvoiceScan.parseAi(raw, now: now, fallbackCurrency: currencyCode);
      if (scan != null) return scan;
    }
    return _device(page.path);
  }

  static String prompt({required String userName, required DateTime today}) => [
    'You read invoices and payment notices for a freelancer named',
    '$userName, who bills clients through Payoneer.',
    'Reply with JSON only, exactly this shape:',
    '{"is_invoice": boolean, "reference": string | null, "client":',
    'string | null, "amount": number | null, "currency": string | null,',
    '"issued": "YYYY-MM-DD" | null, "paid": boolean, "paid_amount":',
    'number | null, "paid_on": "YYYY-MM-DD" | null}',
    'reference is the invoice or payment request number.',
    'client is who was billed or who paid: the customer, never',
    '$userName and never Payoneer.',
    'amount is the total billed, a plain number like 2000.00; currency',
    'is its ISO code, like USD.',
    'paid is true only when the document shows the payment was',
    'received or completed; paid_amount is what arrived after fees, if',
    'shown. Dates are when it was issued and paid.',
    'Today is ${today.year}-${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}.',
    'If it isn\'t an invoice, payment request or payment notice, or you',
    'can\'t read the amount, set is_invoice to false.',
  ].join(' ');

  Future<InvoiceScan?> _device(String path) async {
    if (!(Platform.isAndroid || Platform.isIOS)) return null;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      return InvoiceTextParser.parse(result.text, now: AppClock.now());
    } on Object catch (error) {
      developer.log('Text recognition failed', name: 'velora', error: error);
      return null;
    } finally {
      await recognizer.close();
    }
  }
}

final invoiceDocumentSourceProvider = Provider<InvoiceDocumentSource>(
  (ref) => DeviceInvoiceDocumentSource(ref.watch(receiptPhotoSourceProvider)),
);

final invoiceReaderProvider = Provider<InvoiceReader>(
  (ref) => const SmartInvoiceReader(),
);
