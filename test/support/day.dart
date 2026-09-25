import 'dart:convert';
import 'dart:io';

import 'package:finni/content/content_repository.dart';
import 'package:finni/domain/game_clock.dart';
import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/profile_codec.dart';
import 'package:finni/domain/profile_repository.dart';
import 'package:finni/domain/services/day_controller.dart';
import 'package:finni/domain/services/day_summary_service.dart';
import 'package:finni/domain/services/pet_state_service.dart';
import 'package:finni/domain/services/title_service.dart';
import 'package:finni/domain/services/wallet_service.dart';

Map<String, Object?> bedtimeTextsJson() =>
    ((jsonDecode(File('assets/content/economy.json').readAsStringSync())
            as Map)['bedtime'] as Map)
        .cast<String, Object?>();

final class MemoryProfileRepository implements ProfileRepository {
  String? stored;
  int saves = 0;
  bool failNextSave = false;

  @override
  Future<ProfileLoad> load() async =>
      stored == null ? const ProfileMissing() : ProfileCodec.decode(stored!);

  Future<Profile> loadProfile() async => switch (await load()) {
        ProfileLoaded(:final profile) => profile,
        final other => throw StateError('профиль не читается: $other'),
      };

  @override
  Future<void> save(Profile profile) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('не удалось сохранить');
    }
    stored = ProfileCodec.encode(profile);
    saves++;
  }

  @override
  Future<void> reset(Profile initial) => save(initial);

  @override
  Future<void> delete() async => stored = null;
}

DayController dayController(
  ContentBundle content, {
  required ProfileRepository repository,
  required GameClock clock,
}) =>
    DayController(
      economy: content.economy,
      shop: content.shop,
      events: content.events,
      titles: TitleService.forContent(content.titles,
          tasks: content.tasks, shop: content.shop),
      summaries: DaySummaryService(templates: content.summaries.explain),
      repository: repository,
      clock: clock,
    );

Profile liveDay(
  Profile profile,
  ContentBundle content, {
  required DateTime at,
  BudgetPlan? plan,
  List<String> buy = const [],
  int deposit = 0,
  String? task,
  int taskReward = 10,
}) {
  final day = profile.currentDay.number;
  final wallet =
      WalletService(initial: profile.wallet, journal: profile.allTransactions);
  final pet = PetStateService(
    rules: content.economy.pet,
    initial: profile.state,
    dayNumber: day,
    actionsToday: profile.petActionsToday,
    changesToday: profile.petChangesToday,
  );
  final owned = {...profile.ownedItems};
  for (final id in buy) {
    final item = content.shop.byId(id)!;
    final outcome = wallet.spend(
      amount: item.price,
      itemId: id,
      category: item.category,
      reasonText: item.diaryText,
      at: at,
      dayNumber: day,
    );
    if (outcome is! WalletOk) throw StateError('не хватило на $id');
    pet.applyPurchase(item);
    if (content.shop.isUnique(item)) owned.add(id);
  }
  if (deposit > 0 &&
      wallet.toSavings(amount: deposit, at: at, dayNumber: day) is! WalletOk) {
    throw StateError('не хватило на копилку');
  }
  if (task != null) {
    wallet.earn(
      amount: taskReward,
      sourceId: 'task:$task',
      reasonText: 'Задание выполнено.',
      at: at,
      dayNumber: day,
    );
    pet.perform('task_done');
  }
  return profile.copyWith(
    wallet: wallet.wallet,
    state: pet.state,
    ownedItems: owned.toList(),
    journal: [
      for (final t in wallet.journal)
        if (t.dayNumber < day) t
    ],
    currentDay: profile.currentDay.copyWith(
      plan: plan,
      planConfirmed: plan != null ? true : null,
      transactions: wallet.journalOfDay(day),
    ),
    completedTasks:
        task == null ? null : {...profile.completedTasks, task}.toList(),
    petActionsToday: pet.actionsToday,
    petChangesToday: pet.changesToday,
  );
}

Map<String, Object?> withoutMoments(Map<String, Object?> json) => {
      for (final e in json.entries)
        if (e.key != 'at') e.key: _stripMoments(e.value)
    };

Object? _stripMoments(Object? value) => switch (value) {
      Map() => withoutMoments(value.cast<String, Object?>()),
      List() => [for (final v in value) _stripMoments(v)],
      _ => value,
    };
