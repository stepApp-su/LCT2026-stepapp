const roomPlaces = <String, List<String>>{
  'floor': ['rug'],
  'left': [
    'bed',
    'pouf',
    'table',
    'aquarium',
    'scooter',
    'telescope',
    'treehouse',
    'bicycle',
    'trampoline'
  ],
  'right': ['flower_pot', 'cactus', 'palm', 'night_light'],
  'wall': ['poster', 'clock', 'shelf'],
  'toy': ['bouncy_ball', 'puzzle', 'ball_rope'],
};
const roomPlaceNames = {
  'floor': 'Коврик',
  'left': 'Слева от питомца',
  'right': 'Справа от питомца',
  'wall': 'На стене',
  'toy': 'Любимая игрушка',
};

Map<String, String> resolveRoomItems(
    Map<String, String> selected, Iterable<String> owned, Set<String> hidden) {
  final available = owned.toSet();
  final result = <String, String>{};
  for (final entry in roomPlaces.entries) {
    if (selected.containsKey(entry.key)) {
      final id = selected[entry.key]!;
      if (entry.value.contains(id) &&
          available.contains(id) &&
          !hidden.contains(id)) {
        result[entry.key] = id;
      }
    } else {
      final candidates = entry.value
          .where((id) => available.contains(id) && !hidden.contains(id));
      if (candidates.isNotEmpty) result[entry.key] = candidates.first;
    }
  }
  return result;
}
