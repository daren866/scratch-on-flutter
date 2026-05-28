import 'dart:typed_data';

class ScratchAsset {
  final String name;
  final String md5ext;
  final String dataFormat;
  final Uint8List data;

  ScratchAsset({
    required this.name,
    required this.md5ext,
    required this.dataFormat,
    required this.data,
  });
}

class ScratchCostume extends ScratchAsset {
  final int rotationCenterX;
  final int rotationCenterY;
  final int bitmapResolution;

  ScratchCostume({
    required super.name,
    required super.md5ext,
    required super.dataFormat,
    required super.data,
    required this.rotationCenterX,
    required this.rotationCenterY,
    required this.bitmapResolution,
  });
}

class ScratchSound extends ScratchAsset {
  final String format;
  final int rate;
  final int sampleCount;

  ScratchSound({
    required super.name,
    required super.md5ext,
    required super.dataFormat,
    required super.data,
    required this.format,
    required this.rate,
    required this.sampleCount,
  });
}

class ScratchTarget {
  final String name;
  final bool isStage;
  bool isVisible;
  double x;
  double y;
  double direction;
  double size;
  int currentCostume;
  String say;
  final Map<String, dynamic> variables;
  final Map<String, dynamic> lists;
  final Map<String, dynamic> broadcasts;
  final Map<String, dynamic> blocks;
  final List<ScratchCostume> costumes;
  final List<ScratchSound> sounds;
  int layerOrder;
  double volume;
  String rotationStyle;
  final Map<String, double> effects;
  final List<Map<String, dynamic>> penStrokes;

  ScratchTarget({
    required this.name,
    required this.isStage,
    this.isVisible = true,
    this.x = 0,
    this.y = 0,
    this.direction = 90,
    this.size = 100,
    this.currentCostume = 0,
    this.say = '',
    Map<String, dynamic>? variables,
    Map<String, dynamic>? lists,
    Map<String, dynamic>? broadcasts,
    Map<String, dynamic>? blocks,
    List<ScratchCostume>? costumes,
    List<ScratchSound>? sounds,
    this.layerOrder = 0,
    this.volume = 100,
    this.rotationStyle = 'all around',
    Map<String, double>? effects,
    List<Map<String, dynamic>>? penStrokes,
  })  : variables = variables ?? {},
        lists = lists ?? {},
        broadcasts = broadcasts ?? {},
        blocks = blocks ?? {},
        costumes = costumes ?? [],
        sounds = sounds ?? [],
        effects = effects ?? {},
        penStrokes = penStrokes ?? [];

  ScratchCostume? get currentCostumeObj {
    if (costumes.isEmpty || currentCostume < 0 || currentCostume >= costumes.length) {
      return null;
    }
    return costumes[currentCostume];
  }

  void setXY(double newX, double newY) {
    x = newX;
    y = newY;
  }

  void setDirection(double newDirection) {
    direction = newDirection;
  }

  void setX(double newX) {
    x = newX;
  }

  void setY(double newY) {
    y = newY;
  }
}

class ProjectBank {
  final Map<String, dynamic> projectJson;
  final List<ScratchTarget> targets;
  final List<ScratchCostume> allCostumes;
  final List<ScratchSound> allSounds;
  final DateTime loadedAt;

  ProjectBank({
    required this.projectJson,
    required this.targets,
    required this.allCostumes,
    required this.allSounds,
    DateTime? loadedAt,
  }) : loadedAt = loadedAt ?? DateTime.now();

  String get projectVersion => projectJson['projectVersion']?.toString() ?? '3.0';
  String? get projectId => projectJson['projectId'];
}
