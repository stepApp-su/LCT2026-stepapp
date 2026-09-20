import 'progress.dart';

/// Абстракция хранилища прогресса. Реализация — в lib/data.
abstract class ProgressRepository {
  Future<Progress> load();
  Future<void> save(Progress progress);
}
