import 'content_json.dart';
import 'pet.dart';

enum RoomSpotType { wallpaper, goal, item }

final class RoomSpot {
  const RoomSpot._({
    required this.id,
    required this.type,
    required this.layer,
    required this.x,
    required this.y,
    required this.scale,
    required this.size,
    required this.z,
    required this.accepts,
    required this.acceptsKind,
  });

  factory RoomSpot.fromJson(Map<String, Object?> json) {
    final id = jsonText(json['id'], 'spots.id');
    final type = jsonEnum(RoomSpotType.values, json['type'], 'spots.type');
    if (type == RoomSpotType.wallpaper) {
      return RoomSpot._(
        id: id,
        type: type,
        layer: null,
        x: null,
        y: null,
        scale: null,
        size: null,
        z: null,
        accepts: const [],
        acceptsKind: jsonText(json['acceptsKind'], 'spots.acceptsKind'),
      );
    }
    return RoomSpot._(
      id: id,
      type: type,
      layer: jsonTextOrNull(json['layer'], 'spots.layer'),
      x: jsonNum(json['x'], 'spots.x', min: 0, max: 1),
      y: jsonNum(json['y'], 'spots.y', min: 0, max: 1),
      scale: jsonNum(json['scale'] ?? 1, 'spots.scale', min: 0.01),
      size: jsonNum(json['size'] ?? 0.14, 'spots.size', min: 0.01, max: 1),
      z: jsonInt(json['z'] ?? 0, 'spots.z'),
      accepts: jsonStrings(json['accepts'] ?? const [], 'spots.accepts'),
      acceptsKind: null,
    );
  }

  final String id;
  final RoomSpotType type;
  final String? layer;
  final double? x;
  final double? y;
  final double? scale;
  final double? size;
  final int? z;
  final List<String> accepts;
  final String? acceptsKind;
}

final class RoomDef {
  const RoomDef._({
    required this.id,
    required this.title,
    required this.enabled,
    required this.unlockCozyLevel,
    required this.iconId,
    required this.backgroundsByStage,
    required this.defaultWallpaperId,
    required this.spots,
  });

  factory RoomDef.fromJson(Map<String, Object?> json) {
    final id = jsonText(json['id'], 'id');
    final unlock = jsonMap(json['unlock'], 'unlock');
    final rawBackgrounds = jsonMap(json['backgroundsByStage'], 'backgroundsByStage');
    final backgrounds = <PetStage, String>{
      for (final stage in PetStage.values)
        stage: jsonText(rawBackgrounds[stage.name], 'backgroundsByStage.${stage.name}'),
    };
    final spots = [
      for (final raw in jsonMaps(json['spots'], 'spots')) RoomSpot.fromJson(raw),
    ];
    requireUniqueIds(spots.map((s) => s.id), '$id.spots.id');
    requireUniqueIds([for (final spot in spots) ...spot.accepts], '$id.spots.accepts');
    return RoomDef._(
      id: id,
      title: jsonText(json['title'], 'title'),
      enabled: jsonBool(json['enabled'] ?? true, 'enabled'),
      unlockCozyLevel: jsonInt(unlock['cozyLevel'], 'unlock.cozyLevel', min: 1),
      iconId: jsonText(json['iconId'], 'iconId'),
      backgroundsByStage: Map.unmodifiable(backgrounds),
      defaultWallpaperId: jsonText(json['defaultWallpaperId'], 'defaultWallpaperId'),
      spots: List.unmodifiable(spots),
    );
  }

  final String id;
  final String title;
  final bool enabled;
  final int unlockCozyLevel;
  final String iconId;
  final Map<PetStage, String> backgroundsByStage;
  final String defaultWallpaperId;
  final List<RoomSpot> spots;

  Set<String> get acceptedIds => {for (final spot in spots) ...spot.accepts};

  RoomSpot? spotFor(String id) {
    for (final spot in spots) {
      if (spot.accepts.contains(id)) return spot;
    }
    return null;
  }
}

final class RoomCatalog {
  const RoomCatalog._({
    required this.schemaVersion,
    required this.aspectRatio,
    required this.texts,
    required this.rooms,
  });

  static const Set<String> requiredTexts = {
    'roomUnlocked',
    'roomLocked',
    'chooseForSpot',
    'emptySpot',
    'goalLocked',
  };

  factory RoomCatalog.create({
    int schemaVersion = 1,
    required double aspectRatio,
    required Map<String, String> texts,
    required List<RoomDef> rooms,
  }) {
    if (rooms.isEmpty) throw ArgumentError('нет ни одной комнаты');
    if (aspectRatio <= 0) {
      throw ArgumentError.value(aspectRatio, 'canvas.aspectRatio', 'больше нуля');
    }
    requireUniqueIds(rooms.map((r) => r.id), 'rooms.id');
    if (!rooms.any((r) => r.enabled)) {
      throw ArgumentError('нет ни одной включённой комнаты');
    }
    return RoomCatalog._(
      schemaVersion: schemaVersion,
      aspectRatio: aspectRatio,
      texts: Map.unmodifiable(texts),
      rooms: List.unmodifiable(rooms),
    );
  }

  factory RoomCatalog.fromJson(Map<String, Object?> json) {
    final canvas = jsonMap(json['canvas'], 'canvas');
    return RoomCatalog.create(
      schemaVersion: jsonInt(json['schemaVersion'] ?? 1, 'schemaVersion', min: 1),
      aspectRatio: jsonNum(canvas['aspectRatio'], 'canvas.aspectRatio'),
      texts: jsonTexts(json['texts'], 'texts', required: requiredTexts),
      rooms: [for (final raw in jsonMaps(json['rooms'], 'rooms')) RoomDef.fromJson(raw)],
    );
  }

  final int schemaVersion;
  final double aspectRatio;
  final Map<String, String> texts;
  final List<RoomDef> rooms;

  RoomDef? byId(String id) {
    for (final room in rooms) {
      if (room.id == id) return room;
    }
    return null;
  }
}
