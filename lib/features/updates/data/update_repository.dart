import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/app_release.dart';

/// Finds new builds in the private "releases" bucket, which
/// `scripts/publish_update.py` fills.
abstract interface class UpdateRepository {
  Future<InstalledVersion> installed();

  Future<UpdateCheck> check();

  /// A short-lived link to the release's APK.
  Future<String> downloadUrl(AppRelease release);
}

class SupabaseUpdateRepository implements UpdateRepository {
  SupabaseUpdateRepository(this._db);

  final SupabaseClient _db;

  static const _bucket = 'releases';

  @override
  Future<InstalledVersion> installed() async {
    final info = await PackageInfo.fromPlatform();
    return InstalledVersion(
      name: info.version,
      code: int.tryParse(info.buildNumber) ?? 0,
    );
  }

  @override
  Future<UpdateCheck> check() async {
    final current = await installed();
    // Asked first so a missing grant isn't mistaken for "nothing new".
    final allowed = await _db.rpc<bool>('can_download_releases');
    if (allowed != true) return UpdatesNotSetUp(current);

    final AppRelease latest;
    try {
      final bytes = await _db.storage.from(_bucket).download('latest.json');
      latest = AppRelease.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      );
    } on StorageException catch (error) {
      // Nothing published yet.
      if (error.statusCode == '400' || error.statusCode == '404') {
        return UpToDate(current);
      }
      rethrow;
    }
    return latest.versionCode > current.code
        ? UpdateAvailable(current, latest)
        : UpToDate(current);
  }

  @override
  Future<String> downloadUrl(AppRelease release) =>
      _db.storage.from(_bucket).createSignedUrl(release.apkPath, 15 * 60);
}

/// Downloads an APK and opens Android's installer.
abstract interface class UpdateInstaller {
  Stream<InstallProgress> install(String url, AppRelease release);
}

class OtaUpdateInstaller implements UpdateInstaller {
  @override
  Stream<InstallProgress> install(String url, AppRelease release) => OtaUpdate()
      .execute(
        url,
        destinationFilename: 'velora-${release.versionCode}.apk',
        sha256checksum: release.sha256,
      )
      .map(
        (event) => switch (event.status) {
          OtaStatus.DOWNLOADING => Downloading(
            (double.tryParse(event.value ?? '') ?? 0) / 100,
          ),
          OtaStatus.INSTALLING ||
          OtaStatus.INSTALLATION_DONE => const HandedToInstaller(),
          OtaStatus.CHECKSUM_ERROR => const InstallFailed(
            'The download was damaged. Please try again.',
          ),
          OtaStatus.PERMISSION_NOT_GRANTED_ERROR => const InstallFailed(
            'Allow Velora to install apps in your phone’s settings, then try '
            'again.',
          ),
          OtaStatus.CANCELED => const InstallFailed(
            'The update was cancelled.',
          ),
          _ => const InstallFailed(
            'The update didn’t download. Check your connection and try again.',
          ),
        },
      );
}

final updateRepositoryProvider = Provider<UpdateRepository>(
  (ref) => SupabaseUpdateRepository(ref.watch(supabaseClientProvider)),
);

final updateInstallerProvider = Provider<UpdateInstaller>(
  (ref) => OtaUpdateInstaller(),
);
