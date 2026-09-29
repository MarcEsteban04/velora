import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/receipt_storage.dart';

/// A receipt photo: fresh [bytes] not saved yet, or a stored [path].
class ReceiptImage extends ConsumerWidget {
  const ReceiptImage({
    super.key,
    this.bytes,
    this.path,
    this.fit = BoxFit.cover,
    this.cacheWidth,
  }) : assert(bytes != null || path != null);

  final Uint8List? bytes;
  final String? path;
  final BoxFit fit;

  /// Decode at this width for thumbnails.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bytes case final b?) {
      return Image.memory(
        b,
        fit: fit,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
      );
    }
    final url = ref.watch(receiptUrlProvider(path!));
    return url.when(
      data: (u) => Image.network(
        u,
        fit: fit,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const _Loading(),
        errorBuilder: (context, _, _) => const _Broken(),
      ),
      loading: () => const _Loading(),
      error: (_, _) => const _Broken(),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.surfaceRaised,
    child: Center(
      child: SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.accentBright,
        ),
      ),
    ),
  );
}

class _Broken extends StatelessWidget {
  const _Broken();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.surfaceRaised,
    child: Center(
      child: Icon(
        Icons.image_not_supported_rounded,
        color: AppColors.textMuted,
        semanticLabel: 'Receipt unavailable',
      ),
    ),
  );
}

/// What the viewer's buttons asked for.
enum ReceiptViewerAction { replace, remove }

/// A receipt full screen, pinch to zoom. Optional Replace and Remove.
abstract final class ReceiptViewer {
  static Future<ReceiptViewerAction?> show(
    BuildContext context, {
    Uint8List? bytes,
    String? path,
    bool canEdit = false,
  }) => Navigator.of(context).push<ReceiptViewerAction>(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (context, animation, _) => FadeTransition(
        opacity: animation,
        child: _Viewer(bytes: bytes, path: path, canEdit: canEdit),
      ),
    ),
  );
}

class _Viewer extends StatelessWidget {
  const _Viewer({this.bytes, this.path, required this.canEdit});

  final Uint8List? bytes;
  final String? path;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: ReceiptImage(
                    bytes: bytes,
                    path: path,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: white),
              ),
            ),
            if (canEdit)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.pop(context, ReceiptViewerAction.replace),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: white,
                          side: const BorderSide(color: Colors.white38),
                          shape: const StadiumBorder(),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: const Icon(Icons.photo_camera_rounded),
                        label: const Text('Replace'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.pop(context, ReceiptViewerAction.remove),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF8A80),
                          side: const BorderSide(color: Colors.white38),
                          shape: const StadiumBorder(),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Remove'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
