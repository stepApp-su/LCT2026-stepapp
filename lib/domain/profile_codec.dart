import 'dart:convert';

import 'models/models.dart';
import 'profile_repository.dart';

final class ProfileDefaults {
  const ProfileDefaults({required this.state, required this.dayIncome});

  final PetState state;

  final int dayIncome;
}

abstract final class ProfileCodec {
  static const int currentVersion = 2;

  static String encode(Profile profile) => jsonEncode({
        'schemaVersion': currentVersion,
        'profile': profile.toJson(),
      });

  static ProfileLoad decode(String raw) {
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return const ProfileUnreadable('не JSON');
    }
    if (json is! Map) return const ProfileUnreadable('не объект');
    final version = json['schemaVersion'];
    if (version is! int) return const ProfileUnreadable('нет версии формата');
    if (version > currentVersion) {
      return ProfileUnreadable('формат $version новее приложения');
    }
    if (version != currentVersion) {
      return ProfileUnreadable('формат $version хранится под своим ключом');
    }
    try {
      return ProfileLoaded(
        Profile.fromJson((json['profile'] as Map).cast<String, Object?>()),
        fromVersion: currentVersion,
      );
    } catch (e) {
      return ProfileUnreadable('$e');
    }
  }

  static ProfileLoad migrateV1(
      Map<String, Object?> snapshot, ProfileDefaults defaults) {
    try {
      if (snapshot['onboarded'] != true) return const ProfileMissing();

      final transactions = [
        for (final t in (snapshot['journal'] as List? ?? const []))
          Transaction.fromJson((t as Map).cast<String, Object?>())
      ];
      var dayNumber = (snapshot['day'] as int?) ?? 1;
      for (final t in transactions) {
        if (t.dayNumber > dayNumber) dayNumber = t.dayNumber;
      }
      final plan =
          (snapshot['plan'] as Map?)?.cast<String, Object?>() ?? const {};
      final stats = snapshot['stats'] as Map?;

      final profile = Profile.create(
        petName: (snapshot['petName'] ?? 'Мони') as String,
        species: 'fox',
        palette: 0,
        simpleMode: snapshot['simpleMode'] != false,
        wallet: Wallet.create(
          balance: (snapshot['balance'] ?? 0) as int,
          savings: (snapshot['savings'] ?? 0) as int,
        ),
        state: stats == null
            ? defaults.state
            : PetState.fromJson(stats.cast<String, Object?>()),
        progress: PetProgress.initial(),
        goalId: snapshot['goalId'] as String?,
        currentDay: GameDay.create(
          number: dayNumber,
          income: defaults.dayIncome,
          plan: BudgetPlan.create(
            mandatory: (plan['mandatory'] ?? 0) as int,
            optional: (plan['optional'] ?? 0) as int,
            savings: (plan['savings'] ?? 0) as int,
            income: defaults.dayIncome,
          ),
          transactions: [
            for (final t in transactions)
              if (t.dayNumber == dayNumber) t
          ],
          planConfirmed: snapshot['confirmed'] == true,
        ),
        journal: [
          for (final t in transactions)
            if (t.dayNumber < dayNumber) t
        ],
        ownedItems: (snapshot['owned'] as List? ?? const []).cast<String>(),
        equipped:
            (snapshot['outfit'] as Map? ?? const {}).cast<String, String?>(),
        completedTasks: (snapshot['legacyCompletedTasks'] as List? ?? const [])
            .cast<String>(),
        wishlist: (snapshot['wishlist'] as List? ?? const []).cast<String>(),
        settings: ProfileSettings(motion: snapshot['motion'] != false),
      );
      return ProfileLoaded(profile, fromVersion: 1);
    } catch (e) {
      return ProfileUnreadable('формат 1: $e');
    }
  }
}

Profile reconcileProfile(
  Profile profile, {
  required Set<String> goalIds,
  required Set<String> itemIds,
}) {
  final goalId = profile.goalId;
  final wallpaper = profile.activeWallpaperId;
  return profile.copyWith(
    goalId: goalId != null && goalIds.contains(goalId) ? goalId : null,
    wishlist: [
      for (final id in profile.wishlist)
        if (itemIds.contains(id)) id
    ],
    equipped: {
      for (final MapEntry(:key, :value) in profile.equipped.entries)
        key: value != null && itemIds.contains(value) ? value : null
    },
    activeWallpaperId:
        wallpaper != null && itemIds.contains(wallpaper) ? wallpaper : null,
  );
}
