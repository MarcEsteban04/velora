import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_navigator.dart';
import '../../app_lock/application/app_lock_controller.dart';
import '../../app_lock/data/pin_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../data/auth_repository.dart';

/// "Start over": signs out of the anonymous space, forgets the PIN and
/// returns to Welcome. Both "Forgot PIN" and Settings use it, so the two
/// can't drift apart.
Future<void> startOver(ProviderContainer container) async {
  await container.read(authRepositoryProvider).signOut();
  await container.read(pinRepositoryProvider).clear();
  container.read(appLockProvider.notifier).reset();
  container.invalidate(profileProvider);
  appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
}
