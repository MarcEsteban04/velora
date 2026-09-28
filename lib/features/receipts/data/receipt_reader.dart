import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/ai/ai_client.dart';
import '../../../core/time/app_clock.dart';
import '../domain/receipt.dart';
import '../domain/receipt_text_parser.dart';

/// A receipt photo, as bytes (for the AI) and a file (for on-device text
/// recognition).
class ReceiptPhoto {
  const ReceiptPhoto({required this.bytes, required this.path});

  final Uint8List bytes;
  final String path;
}

/// Takes or picks the photo. Swappable in tests.
abstract interface class ReceiptPhotoSource {
  Future<ReceiptPhoto?> take({required bool camera});
}

class ImagePickerPhotoSource implements ReceiptPhotoSource {
  const ImagePickerPhotoSource();

  @override
  Future<ReceiptPhoto?> take({required bool camera}) async {
    // Scaled down on the phone: plenty for reading, and quick to send.
    final file = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 82,
    );
    if (file == null) return null;
    return ReceiptPhoto(bytes: await file.readAsBytes(), path: file.path);
  }
}

/// Reads a receipt photo.
abstract interface class ReceiptReader {
  /// [categories] are the user's expense category names, for the AI to
  /// pick from. Returns null when nothing sensible could be read.
  Future<ReceiptScan?> read(ReceiptPhoto photo, List<String> categories);
}

/// The AI first (it reads messy receipts and knows what the store sells),
/// then on-device text recognition when the AI isn't available.
class SmartReceiptReader implements ReceiptReader {
  const SmartReceiptReader();

  @override
  Future<ReceiptScan?> read(ReceiptPhoto photo, List<String> categories) async {
    if (AiClient.isConfigured) {
      final ai = await _ai(photo.bytes, categories);
      if (ai != null) return ai;
    }
    return _device(photo.path);
  }

  static String prompt(List<String> categories, DateTime today) => [
    'You read shopping receipts for a budgeting app in the Philippines.',
    'Look at the photo and reply with JSON only, exactly this shape:',
    '{"is_receipt": boolean, "merchant": string | null, "total": number |',
    'null, "date": "YYYY-MM-DD" | null, "category": string | null,',
    '"items": [{"name": string, "amount": number}]}',
    'total is the final amount paid (grand total or amount due, including',
    'tax), never the subtotal, cash tendered or change. Amounts are plain',
    'numbers in pesos, like 1245.50.',
    'Today is ${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}.',
    'category must be one of: ${categories.join(', ')}; pick the best fit',
    'for what was bought, or null.',
    'items: up to 6 main lines as printed, shortened to a few words.',
    'If it isn\'t a receipt or you can\'t read the total, set is_receipt',
    'to false.',
  ].join(' ');

  static ReceiptScan? parseAi(String raw, DateTime now) {
    Object? j;
    try {
      j = jsonDecode(raw.replaceAll(RegExp(r'^```(?:json)?\s*|\s*```$'), ''));
    } on FormatException {
      return null;
    }
    if (j is! Map || j['is_receipt'] == false) return null;
    double? num_(Object? v) => switch (v) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), '')),
      _ => null,
    };
    final total = num_(j['total']);
    if (total == null || total <= 0 || total > 1e8) return null;
    DateTime? date;
    if (j['date'] case final String d) {
      final parsed = DateTime.tryParse(d);
      if (parsed != null &&
          !parsed.isAfter(now) &&
          now.difference(parsed).inDays <= 400) {
        date = parsed;
      }
    }
    String? str(Object? v, int max) {
      if (v is! String) return null;
      final t = v.trim();
      if (t.isEmpty) return null;
      return t.length > max ? t.substring(0, max) : t;
    }

    return ReceiptScan(
      totalMinor: (total * 100).round(),
      source: ReceiptSource.ai,
      merchant: str(j['merchant'], 40),
      date: date,
      category: str(j['category'], 30),
      items: [
        if (j['items'] case final List list)
          for (final i in list.take(6))
            if (i is Map &&
                str(i['name'], 40) != null &&
                num_(i['amount']) != null)
              ReceiptItem(
                str(i['name'], 40)!,
                (num_(i['amount'])! * 100).round(),
              ),
      ],
    );
  }

  Future<ReceiptScan?> _ai(Uint8List jpeg, List<String> categories) async {
    final now = AppClock.now();
    final raw = await AiClient.complete(
      system: prompt(categories, now),
      messages: const [('user', 'Read this receipt.')],
      image: jpeg,
      json: true,
      maxTokens: 500,
      temperature: 0.1,
    );
    return raw == null ? null : parseAi(raw, now);
  }

  Future<ReceiptScan?> _device(String path) async {
    if (!(Platform.isAndroid || Platform.isIOS)) return null;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      return ReceiptTextParser.parse(result.text, now: AppClock.now());
    } on Object catch (error) {
      developer.log('Text recognition failed', name: 'velora', error: error);
      return null;
    } finally {
      await recognizer.close();
    }
  }
}

final receiptPhotoSourceProvider = Provider<ReceiptPhotoSource>(
  (ref) => const ImagePickerPhotoSource(),
);

final receiptReaderProvider = Provider<ReceiptReader>(
  (ref) => const SmartReceiptReader(),
);
