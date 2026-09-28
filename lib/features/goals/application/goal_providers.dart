import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/goal_repository.dart';
import '../domain/goal.dart';

final goalsProvider = FutureProvider<List<Goal>>(
  (ref) => ref.watch(goalRepositoryProvider).fetchGoals(),
);

final goalEntriesProvider = FutureProvider<List<GoalEntry>>(
  (ref) => ref.watch(goalRepositoryProvider).fetchEntries(),
);

/// Every goal with its progress: unfinished first (soonest date first),
/// then finished ones. Null while loading.
final goalProgressProvider = Provider<List<GoalProgress>?>((ref) {
  final goals = ref.watch(goalsProvider).value;
  final entries = ref.watch(goalEntriesProvider).value;
  if (goals == null || entries == null) return null;
  final now = DateTime.now();
  final list = [for (final g in goals) GoalProgress.of(g, entries, now: now)];
  list.sort((a, b) {
    if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
    final da = a.goal.targetDate, db = b.goal.targetDate;
    if (da != null && db != null) return da.compareTo(db);
    if (da != null) return -1;
    if (db != null) return 1;
    return a.goal.createdAt.compareTo(b.goal.createdAt);
  });
  return list;
});

/// Changes goals, then refreshes what shows them.
class GoalActions {
  GoalActions(this._container);

  factory GoalActions.of(BuildContext context) =>
      GoalActions(ProviderScope.containerOf(context, listen: false));

  final ProviderContainer _container;

  GoalRepository get _repo => _container.read(goalRepositoryProvider);

  void _refresh() => _container
    ..invalidate(goalsProvider)
    ..invalidate(goalEntriesProvider);

  Future<Goal> create(GoalDraft draft) async {
    final g = await _repo.create(draft);
    _refresh();
    return g;
  }

  Future<void> update(String id, GoalDraft draft) async {
    await _repo.update(id, draft);
    _refresh();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _refresh();
  }

  Future<void> addEntry(String goalId, int amountMinor, {String? note}) async {
    await _repo.addEntry(goalId, amountMinor, note: note);
    _container.invalidate(goalEntriesProvider);
  }

  Future<void> deleteEntry(String id) async {
    await _repo.deleteEntry(id);
    _container.invalidate(goalEntriesProvider);
  }
}
