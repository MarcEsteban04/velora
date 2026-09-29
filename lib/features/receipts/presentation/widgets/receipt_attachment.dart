import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/friendly_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/island_toast.dart';
import '../../data/receipt_reader.dart';
import 'receipt_image.dart';

/// The Receipt section of the entry screen: "Take a photo" and "Choose from
/// photos" when there's none, or a thumbnail with Replace and Remove.
///
/// It only picks: the caller saves. [bytes] is a new, unsaved photo;
/// [path] the one already stored.
class ReceiptAttachment extends ConsumerWidget {
  const ReceiptAttachment({
    super.key,
    required this.bytes,
    required this.path,
    required this.onPicked,
    required this.onRemoved,
  });

  final Uint8List? bytes;
  final String? path;
  final ValueChanged<Uint8List> onPicked;
  final VoidCallback onRemoved;

  Future<void> _pick(BuildContext context, WidgetRef ref, bool camera) async {
    final photo = await pickReceiptPhoto(context, ref, camera: camera);
    if (photo != null) onPicked(photo);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final has = bytes != null || path != null;

    Widget label() => Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        'RECEIPT',
        style: text.labelMedium?.copyWith(fontSize: 12, letterSpacing: 1.6),
      ),
    );

    if (!has) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label(),
          Row(
            children: [
              _Tile(
                semanticLabel: 'Take a photo of the receipt',
                onTap: () => _pick(context, ref, true),
                child: Icon(
                  Icons.photo_camera_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Tile(
                  semanticLabel: 'Choose the receipt from photos',
                  onTap: () => _pick(context, ref, false),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_rounded,
                        color: AppColors.accentBright,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Choose from photos',
                        style: text.titleMedium?.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label(),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.hairline(0.08)),
          ),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: 'View the receipt',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () async {
                    final action = await ReceiptViewer.show(
                      context,
                      bytes: bytes,
                      path: path,
                      canEdit: true,
                    );
                    if (!context.mounted) return;
                    switch (action) {
                      case ReceiptViewerAction.replace:
                        await _pick(context, ref, true);
                      case ReceiptViewerAction.remove:
                        onRemoved();
                      case null:
                        break;
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: ReceiptImage(
                        bytes: bytes,
                        path: path,
                        cacheWidth: 192,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.attach_file_rounded,
                          size: 16,
                          color: AppColors.accentBright,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Receipt attached',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium?.copyWith(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      bytes != null && path == null
                          ? 'Saved with the transaction'
                          : bytes != null
                          ? 'Replaces the old one when you save'
                          : 'Tap to view',
                      style: text.labelMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Replace receipt',
                onPressed: () => _pick(context, ref, false),
                icon: Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
              IconButton(
                tooltip: 'Remove receipt',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onRemoved();
                },
                icon: Icon(Icons.close_rounded, color: AppColors.rust),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.semanticLabel,
    required this.onTap,
    required this.child,
  });

  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    excludeSemantics: true,
    child: Material(
      color: AppColors.surface.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.hairline(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(height: 56, width: 64, child: Center(child: child)),
      ),
    ),
  );
}

/// Takes or picks a receipt photo. Null if cancelled; explains a denied
/// camera.
Future<Uint8List?> pickReceiptPhoto(
  BuildContext context,
  WidgetRef ref, {
  required bool camera,
}) async {
  final toast = Toast.of(context);
  try {
    final photo = await ref
        .read(receiptPhotoSourceProvider)
        .take(camera: camera);
    if (photo == null) return null;
    HapticFeedback.selectionClick();
    return photo.bytes;
  } on PlatformException catch (error) {
    toast.error(
      error.code.contains('denied')
          ? 'Velora needs camera access. Allow it in your phone’s settings.'
          : friendlyError(error, action: 'open the camera'),
    );
    return null;
  }
}

/// Asks where the photo comes from, then takes or picks it.
Future<Uint8List?> chooseReceiptPhoto(
  BuildContext context,
  WidgetRef ref,
) async {
  final camera = await showModalBottomSheet<bool>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.photo_camera_rounded,
                color: AppColors.accentBright,
              ),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library_rounded,
                color: AppColors.accentBright,
              ),
              title: const Text('Choose from photos'),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    ),
  );
  if (camera == null || !context.mounted) return null;
  return pickReceiptPhoto(context, ref, camera: camera);
}
