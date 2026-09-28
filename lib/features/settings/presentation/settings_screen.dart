import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/storage/app_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/currency_picker_sheet.dart';
import '../../../core/widgets/dusk_backdrop.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/velora_mascot.dart';
import '../../app_lock/application/app_lock_controller.dart';
import '../../app_lock/presentation/change_pin_screen.dart';
import '../../auth/application/session_actions.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/backup_status.dart';
import '../../auth/presentation/backup_sheet.dart';
import '../../updates/application/update_providers.dart';
import '../../updates/domain/app_release.dart';
import '../../updates/presentation/update_sheet.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/presentation/coach_tone_style.dart';
import '../../streaks/application/streak_providers.dart';
import '../../streaks/presentation/streak_sheet.dart';
import '../../streaks/presentation/streak_style.dart';
import 'widgets/settings_section.dart';
import 'widgets/settings_sheets.dart';
import 'widgets/time_zone_sheet.dart';
import '../application/time_zone_actions.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/island_toast.dart';

/// Settings: profile, preferences, security, backup, about and a guarded
/// "Start over". Profile fields save to Supabase; the phone-only
/// preferences save on the device.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const SettingsScreen());

  Future<void> _updateProfile(
    BuildContext context,
    WidgetRef ref, {
    String? name,
    String? currencyCode,
    CoachTone? coachTone,
    required String done,
  }) async {
    final toast = Toast.of(context);
    try {
      await ref
          .read(profileRepositoryProvider)
          .update(name: name, currencyCode: currencyCode, coachTone: coachTone);
      final _ = await ref.refresh(profileProvider.future);
      HapticFeedback.selectionClick();
      toast.show(done);
    } on Object catch (error) {
      toast.show(
        friendlyError(error, action: 'save that'),
        tone: ToastTone.error,
      );
    }
  }

  /// Opens the update if there is one; otherwise checks again and says
  /// what it found.
  Future<void> _checkForUpdates(BuildContext context, WidgetRef ref) async {
    final toast = Toast.of(context);
    if (ref.read(updateCheckProvider).value case final UpdateAvailable u) {
      await UpdateSheet.show(context, u);
      return;
    }
    try {
      final result = await ref.refresh(updateCheckProvider.future);
      if (!context.mounted) return;
      switch (result) {
        case UpdateAvailable():
          await UpdateSheet.show(context, result);
        case UpToDate(:final installed):
          toast.show('You’re on the latest version, ${installed.name}.');
        case UpdatesNotSetUp():
          toast.show(
            'Updates aren’t set up for this account yet.',
            tone: ToastTone.info,
          );
      }
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'check for updates'));
    }
  }

  Future<void> _confirmStartOver(
    BuildContext context,
    BackupStatus backup,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: const Text('Start over?'),
        content: Text(
          backup is LinkedBackup
              ? 'This signs you out of this phone. Your space is backed up, '
                    'so you can sign back in with ${backup.email}.'
              : 'This signs you out and sets up a fresh space. Your space '
                    'isn’t backed up yet, so your accounts and history can’t '
                    'be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep my data'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.rust),
            child: const Text('Start over'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await startOver(ProviderScope.containerOf(context, listen: false));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final profile = ref.watch(profileProvider).value;
    final hideOnOpen = ref.watch(hideBalancesOnOpenProvider);
    final autoLock = ref.watch(autoLockProvider);
    final appearance = ref.watch(appearanceProvider);
    final zone = ref.watch(timeZoneProvider);
    final backup = ref.watch(backupStatusProvider);
    final installed = ref.watch(installedVersionProvider).value;
    final update = ref.watch(updateCheckProvider);
    final streak = ref.watch(streakSettingsProvider);
    final streakCtl = ref.read(streakSettingsProvider.notifier);
    final name = profile?.name ?? 'friend';
    final currency = Currencies.byCode(profile?.currencyCode ?? 'USD');
    final tone = profile?.coachTone ?? CoachTone.balanced;

    var delay = 0;
    Widget stagger(Widget child) => FadeSlideIn(
      delay: Duration(milliseconds: 50 * delay++),
      child: child,
    );

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: DuskBackdrop(showMoon: false)),
          Positioned.fill(
            child: ColoredBox(color: AppColors.night.withValues(alpha: 0.72)),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    Text('Settings', style: text.headlineSmall),
                  ],
                ),
                const SizedBox(height: 12),
                stagger(
                  _ProfileCard(
                    name: name,
                    since: profile?.onboardedAt,
                    onEdit: () async {
                      final v = await SettingsSheets.editName(context, name);
                      if (v != null && v != name && context.mounted) {
                        await _updateProfile(
                          context,
                          ref,
                          name: v,
                          done: 'Nice to meet you again, $v!',
                        );
                      }
                    },
                  ),
                ),
                stagger(
                  SettingsSection(
                    title: 'Preferences',
                    children: [
                      SettingsTile(
                        icon: SettingsSheets.appearanceIcon(appearance),
                        color: SettingsSheets.appearanceColor(appearance),
                        title: 'Appearance',
                        subtitle: appearance == Appearance.automatic
                            ? 'Follows the time of day · '
                                  '${_sceneName(AppColors.scene)} now'
                            : appearance.description,
                        value: appearance.label,
                        onTap: () async {
                          final picked = await SettingsSheets.appearance(
                            context,
                            appearance,
                          );
                          if (picked != null) {
                            HapticFeedback.selectionClick();
                            await ref
                                .read(appearanceProvider.notifier)
                                .set(picked);
                          }
                        },
                      ),
                      SettingsTile(
                        icon: Icons.public_rounded,
                        color: AppColors.sky,
                        title: 'Time zone',
                        subtitle:
                            '${AppClock.cityOf(zone)} · '
                            '${DateFormat('h:mm a').format(AppClock.now())} now',
                        value: AppClock.gmtLabel(AppClock.offsetOf(zone)),
                        onTap: () async {
                          final container = ProviderScope.containerOf(
                            context,
                            listen: false,
                          );
                          final toast = Toast.of(context);
                          final picked = await TimeZoneSheet.show(
                            context,
                            zone,
                          );
                          if (picked == null || picked == zone) return;
                          HapticFeedback.selectionClick();
                          await changeTimeZone(container, picked);
                          toast.show(
                            'Time zone set to ${AppClock.cityOf(picked)}',
                            icon: Icons.public_rounded,
                          );
                        },
                      ),
                      SettingsTile(
                        icon: Icons.currency_exchange_rounded,
                        title: 'Main currency',
                        subtitle: 'Totals and net worth use this',
                        value: currency.code,
                        onTap: () async {
                          final picked = await CurrencyPickerSheet.show(
                            context,
                            currency,
                          );
                          if (picked != null &&
                              picked != currency &&
                              context.mounted) {
                            await _updateProfile(
                              context,
                              ref,
                              currencyCode: picked.code,
                              done: 'Main currency is now ${picked.code}',
                            );
                          }
                        },
                      ),
                      SettingsTile(
                        icon: tone.icon,
                        color: tone.color,
                        title: 'Coaching style',
                        subtitle: tone.description,
                        value: tone.label,
                        onTap: () async {
                          final picked = await SettingsSheets.coachTone(
                            context,
                            current: tone,
                            name: name,
                          );
                          if (picked != null &&
                              picked != tone &&
                              context.mounted) {
                            await _updateProfile(
                              context,
                              ref,
                              coachTone: picked,
                              done:
                                  'Velora will be ${picked.label.toLowerCase()} from now on',
                            );
                          }
                        },
                      ),
                      SettingsTile(
                        icon: Icons.visibility_off_rounded,
                        color: AppColors.sky,
                        title: 'Hide balances on open',
                        subtitle: 'Start with amounts masked',
                        onTap: () => ref
                            .read(hideBalancesOnOpenProvider.notifier)
                            .set(!hideOnOpen),
                        trailing: Switch.adaptive(
                          value: hideOnOpen,
                          activeTrackColor: AppColors.leaf,
                          onChanged: (v) => ref
                              .read(hideBalancesOnOpenProvider.notifier)
                              .set(v),
                        ),
                      ),
                    ],
                  ),
                ),
                stagger(
                  SettingsSection(
                    title: 'Habits',
                    children: [
                      SettingsTile(
                        icon: streak.icon,
                        color: streak.enabled
                            ? streak.color
                            : AppColors.textMuted,
                        title: 'Home streak',
                        subtitle: 'Show your streak at the top of Home',
                        onTap: () => streakCtl.save(
                          streak.copyWith(enabled: !streak.enabled),
                        ),
                        trailing: Switch.adaptive(
                          value: streak.enabled,
                          activeTrackColor: AppColors.leaf,
                          onChanged: (v) =>
                              streakCtl.save(streak.copyWith(enabled: v)),
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.flag_rounded,
                        color: AppColors.ember,
                        title: 'Streak goal',
                        subtitle: streak.description,
                        value: streak.label(currency),
                        onTap: () => StreakSheet.editGoal(context, ref),
                      ),
                      SettingsTile(
                        icon: Icons.bedtime_rounded,
                        color: AppColors.lilac,
                        title: 'Rest days',
                        subtitle: 'Forgive one missed day each week',
                        onTap: () => streakCtl.save(
                          streak.copyWith(restDays: !streak.restDays),
                        ),
                        trailing: Switch.adaptive(
                          value: streak.restDays,
                          activeTrackColor: AppColors.leaf,
                          onChanged: (v) =>
                              streakCtl.save(streak.copyWith(restDays: v)),
                        ),
                      ),
                    ],
                  ),
                ),
                stagger(
                  SettingsSection(
                    title: 'Security',
                    children: [
                      SettingsTile(
                        icon: Icons.pin_rounded,
                        color: AppColors.lilac,
                        title: 'Change PIN',
                        onTap: () =>
                            Navigator.of(context).push(ChangePinScreen.route()),
                      ),
                      SettingsTile(
                        icon: Icons.timer_rounded,
                        color: AppColors.lilac,
                        title: 'Auto-lock',
                        value: autoLock.label.replaceFirst('After ', ''),
                        onTap: () async {
                          final picked = await SettingsSheets.autoLock(
                            context,
                            autoLock,
                          );
                          if (picked != null) {
                            await ref
                                .read(autoLockProvider.notifier)
                                .set(picked);
                          }
                        },
                      ),
                      SettingsTile(
                        icon: Icons.lock_rounded,
                        color: AppColors.lilac,
                        title: 'Lock now',
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          ref.read(appLockProvider.notifier).lock();
                        },
                      ),
                    ],
                  ),
                ),
                stagger(
                  SettingsSection(
                    title: 'Backup',
                    children: [
                      SettingsTile(
                        icon: Icons.cloud_done_rounded,
                        color: AppColors.ember,
                        title: switch (backup) {
                          LinkedBackup() => 'Backed up',
                          PendingBackup() => 'Finish backing up',
                          NoBackup() => 'Back up your space',
                        },
                        subtitle: switch (backup) {
                          LinkedBackup(:final email) =>
                            'Sign in with $email on any phone',
                          PendingBackup(:final email) =>
                            'Open the link sent to $email',
                          NoBackup() =>
                            'Add an email to open your space on any phone',
                        },
                        onTap: () => BackupSheet.show(context),
                      ),
                    ],
                  ),
                ),
                stagger(
                  SettingsSection(
                    title: 'About',
                    children: [
                      const SettingsTile(
                        icon: Icons.shield_rounded,
                        title: 'Your privacy',
                        subtitle: 'Your data is private to you. Your PIN never leaves this phone.',
                      ),
                      SettingsTile(
                        icon: Icons.system_update_rounded,
                        color: AppColors.sky,
                        title: 'Check for updates',
                        subtitle: switch (update) {
                          AsyncValue(isLoading: true) => 'Checking…',
                          AsyncValue(value: UpdateAvailable(:final release)) =>
                            'Velora ${release.versionName} is ready to install',
                          AsyncValue(value: UpToDate()) =>
                            'You’re on the latest version',
                          AsyncValue(value: UpdatesNotSetUp()) =>
                            'Not set up for this account yet',
                          _ => 'Couldn’t check. Tap to try again.',
                        },
                        badge: update.value is UpdateAvailable ? 'NEW' : null,
                        onTap: () => _checkForUpdates(context, ref),
                      ),
                      SettingsTile(
                        icon: Icons.info_rounded,
                        color: AppColors.textSecondary,
                        title: 'Version',
                        value: installed?.name ?? '…',
                      ),
                    ],
                  ),
                ),
                stagger(
                  SettingsSection(
                    title: 'Danger zone',
                    children: [
                      SettingsTile(
                        icon: Icons.restart_alt_rounded,
                        title: 'Start over',
                        subtitle: backup is LinkedBackup
                            ? 'Sign out of this phone'
                            : 'Sign out and set up a fresh space',
                        destructive: true,
                        onTap: () => _confirmStartOver(context, backup),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Made with care by Velora',
                    style: text.labelMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _sceneName(Scene scene) => switch (scene) {
  Scene.day => 'Day',
  Scene.afternoon => 'Afternoon',
  Scene.night => 'Night',
};

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.since,
    required this.onEdit,
  });

  final String name;
  final DateTime? since;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onEdit,
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(8, 10, 18, 10),
        child: Row(
          children: [
            const VeloraMascot(pose: MascotPose.profile, size: 84, halo: false),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.headlineSmall,
                  ),
                  if (since != null)
                    Text(
                      'With Velora since ${DateFormat('MMMM y').format(since!)}',
                      style: text.labelMedium,
                    ),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: 'Edit name',
              excludeSemantics: true,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceRaised,
                  border: Border.all(color: AppColors.hairline(0.08)),
                ),
                child: Icon(
                  Icons.edit_rounded,
                  size: 18,
                  color: AppColors.leafBright,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
