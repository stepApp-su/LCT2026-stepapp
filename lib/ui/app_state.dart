import 'package:flutter/foundation.dart';

import '../content/content_loader.dart';
import '../data/shared_prefs_progress_repository.dart';
import '../domain/models.dart';
import '../domain/progress.dart';
import '../domain/repositories.dart';

/// Хранит загруженный контент и прогресс, оповещает UI об изменениях.
class AppState extends ChangeNotifier {
  final ContentLoader _content;
  final ProgressRepository _repository;
  final ProgressRules rules = const ProgressRules();

  List<Task> tasks = [];
  List<ShopItem> shopItems = [];
  List<Goal> goals = [];
  List<Rank> ranks = [];
  List<FinniLine> finniLines = [];
  Progress progress = const Progress();
  bool isLoading = true;

  AppState({
    ContentLoader content = const ContentLoader(),
    ProgressRepository? repository,
  })  : _content = content,
        _repository = repository ?? SharedPrefsProgressRepository();

  Future<void> load() async {
    final results = await Future.wait([
      _content.loadTasks(),
      _content.loadShopItems(),
      _content.loadGoals(),
      _content.loadRanks(),
      _content.loadFinniLines(),
      _repository.load(),
    ]);
    tasks = results[0] as List<Task>;
    shopItems = results[1] as List<ShopItem>;
    goals = results[2] as List<Goal>;
    ranks = results[3] as List<Rank>;
    finniLines = results[4] as List<FinniLine>;
    progress = results[5] as Progress;
    isLoading = false;
    notifyListeners();
  }

  Rank get currentRank => rules.currentRank(progress, ranks);

  String lineFor(String trigger) => finniLines
      .firstWhere(
        (l) => l.trigger == trigger,
        orElse: () => const FinniLine(id: '', trigger: '', text: ''),
      )
      .text;

  Future<void> completeTask(Task task) async {
    progress = rules.completeTask(progress, task);
    notifyListeners();
    await _repository.save(progress);
  }

  Future<void> purchase(ShopItem item) async {
    if (!rules.canAfford(progress, item)) return;
    progress = rules.purchase(progress, item);
    notifyListeners();
    await _repository.save(progress);
  }
}
