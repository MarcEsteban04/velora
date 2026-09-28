import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pin_repository.dart';

class AppLockState {
  const AppLockState({required this.hasPin, required this.locked});

  final bool hasPin;
  final bool locked;
}

/// Decides when the lock screen covers the app. It locks on a cold start and
/// again after the app has been in the background longer than [_grace].
final appLockProvider = AsyncNotifierProvider<AppLockController, AppLockState>(
  AppLockController.new,
);

class AppLockController extends AsyncNotifier<AppLockState> {
  static const _grace = Duration(seconds: 30);
  DateTime? _backgroundedAt;

  @override
  Future<AppLockState> build() async {
    final listener = AppLifecycleListener(
      onHide: () => _backgroundedAt = DateTime.now(),
      onShow: _onReturn,
    );
    ref.onDispose(listener.dispose);

    final hasPin = await ref.read(pinRepositoryProvider).hasPin();
    return AppLockState(hasPin: hasPin, locked: hasPin);
  }

  void _onReturn() {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    final current = state.value;
    if (since == null || current == null || !current.hasPin) return;
    if (DateTime.now().difference(since) > _grace) {
      state = AsyncData(AppLockState(hasPin: true, locked: true));
    }
  }

  void unlock() =>
      state = const AsyncData(AppLockState(hasPin: true, locked: false));

  /// Call after a PIN is saved. The user just proved they know it, so the
  /// app stays unlocked.
  void pinCreated() => unlock();

  void reset() =>
      state = const AsyncData(AppLockState(hasPin: false, locked: false));
}
