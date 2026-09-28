import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/update_repository.dart';
import '../domain/app_release.dart';

final installedVersionProvider = FutureProvider<InstalledVersion>(
  (ref) => ref.watch(updateRepositoryProvider).installed(),
);

/// The latest check. Refresh it to check again.
final updateCheckProvider = FutureProvider<UpdateCheck>(
  (ref) => ref.watch(updateRepositoryProvider).check(),
);
