import 'package:flutter_test/flutter_test.dart';
import 'package:finni/ui/widgets/moni_idle.dart';

void main() {
  test('idle position and velocity match across the loop seam', () {
    for (final cycles in [2, 3, 4]) {
      const end = moniIdleSeconds * 1.0;
      const step = .00001;
      expect(
          moniIdleWave(end, cycles), closeTo(moniIdleWave(0, cycles), 1e-12));
      final before =
          (moniIdleWave(end, cycles) - moniIdleWave(end - step, cycles)) / step;
      final after =
          (moniIdleWave(step, cycles) - moniIdleWave(0, cycles)) / step;
      expect(before, closeTo(after, 1e-8));
    }
  });
}
