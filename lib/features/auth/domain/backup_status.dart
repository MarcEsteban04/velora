/// Whether the space is tied to an email, so it can be opened on any phone.
sealed class BackupStatus {
  const BackupStatus();

  const factory BackupStatus.none() = NoBackup;
  const factory BackupStatus.pending(String email) = PendingBackup;
  const factory BackupStatus.linked(String email) = LinkedBackup;
}

/// Only on this phone.
final class NoBackup extends BackupStatus {
  const NoBackup();
}

/// A confirmation link was sent to [email] and hasn't been opened yet.
final class PendingBackup extends BackupStatus {
  const PendingBackup(this.email);

  final String email;
}

/// Backed up: signing in with [email] opens this space anywhere.
final class LinkedBackup extends BackupStatus {
  const LinkedBackup(this.email);

  final String email;
}
