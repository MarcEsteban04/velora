/// The version running on this phone.
class InstalledVersion {
  const InstalledVersion({required this.name, required this.code});

  /// For people, for example "0.1.2".
  final String name;

  /// Android's versionCode (the "+n" in pubspec.yaml). Higher is newer.
  final int code;
}

/// A published build, as described by `latest.json` in the releases bucket.
class AppRelease {
  const AppRelease({
    required this.versionCode,
    required this.versionName,
    required this.apkPath,
    this.sha256,
    this.sizeBytes,
    this.notes = '',
    this.publishedAt,
  });

  factory AppRelease.fromJson(Map<String, dynamic> json) => AppRelease(
    versionCode: (json['versionCode'] as num).toInt(),
    versionName: json['versionName'] as String,
    apkPath: json['apk'] as String,
    sha256: json['sha256'] as String?,
    sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
    notes: (json['notes'] as String?)?.trim() ?? '',
    publishedAt: switch (json['publishedAt']) {
      final String s => DateTime.tryParse(s),
      _ => null,
    },
  );

  final int versionCode;
  final String versionName;

  /// The APK's path inside the bucket.
  final String apkPath;
  final String? sha256;
  final int? sizeBytes;
  final String notes;
  final DateTime? publishedAt;

  /// "38 MB", or null when unknown.
  String? get sizeLabel => switch (sizeBytes) {
    final b? => '${(b / (1024 * 1024)).round()} MB',
    null => null,
  };
}

/// What a check for updates found.
sealed class UpdateCheck {
  const UpdateCheck(this.installed);

  final InstalledVersion installed;
}

final class UpToDate extends UpdateCheck {
  const UpToDate(super.installed);
}

final class UpdateAvailable extends UpdateCheck {
  const UpdateAvailable(super.installed, this.release);

  final AppRelease release;
}

/// This account isn't on the release list (see the app_updates migration).
final class UpdatesNotSetUp extends UpdateCheck {
  const UpdatesNotSetUp(super.installed);
}

/// Where an install is up to.
sealed class InstallProgress {
  const InstallProgress();
}

final class Downloading extends InstallProgress {
  const Downloading(this.fraction);

  /// 0 to 1.
  final double fraction;
}

/// Android's installer is open; the rest happens there.
final class HandedToInstaller extends InstallProgress {
  const HandedToInstaller();
}

final class InstallFailed extends InstallProgress {
  const InstallFailed(this.message);

  final String message;
}
