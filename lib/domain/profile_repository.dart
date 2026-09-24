import 'models/models.dart';

sealed class ProfileLoad {
  const ProfileLoad();
}

final class ProfileMissing extends ProfileLoad {
  const ProfileMissing();
}

final class ProfileLoaded extends ProfileLoad {
  const ProfileLoaded(this.profile, {required this.fromVersion});

  final Profile profile;

  final int fromVersion;
}

final class ProfileUnreadable extends ProfileLoad {
  const ProfileUnreadable(this.reason);

  final String reason;
}

abstract interface class ProfileRepository {
  Future<ProfileLoad> load();

  Future<void> save(Profile profile);

  Future<void> reset(Profile initial);

  Future<void> delete();
}
