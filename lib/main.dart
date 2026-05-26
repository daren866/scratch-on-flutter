import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SOF',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

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
  final Map<String, dynamic> variables;
  final Map<String, dynamic> lists;
  final Map<String, dynamic> broadcasts;
  final Map<String, dynamic> blocks;
  final List<ScratchCostume> costumes;
  final List<ScratchSound> sounds;
  int layerOrder;
  double volume;
  String rotationStyle;

  ScratchTarget({
    required this.name,
    required this.isStage,
    this.isVisible = true,
    this.x = 0,
    this.y = 0,
    this.direction = 90,
    this.size = 100,
    this.currentCostume = 0,
    Map<String, dynamic>? variables,
    Map<String, dynamic>? lists,
    Map<String, dynamic>? broadcasts,
    Map<String, dynamic>? blocks,
    List<ScratchCostume>? costumes,
    List<ScratchSound>? sounds,
    this.layerOrder = 0,
    this.volume = 100,
    this.rotationStyle = 'all around',
  })  : variables = variables ?? {},
        lists = lists ?? {},
        broadcasts = broadcasts ?? {},
        blocks = blocks ?? {},
        costumes = costumes ?? [],
        sounds = sounds ?? [];

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

class BlockExecutor {
  final ProjectBank projectBank;
  bool isRunning = false;
  final VoidCallback? onFrameUpdate;
  final List<AudioPlayer> _activePlayers = [];

  BlockExecutor(this.projectBank, {this.onFrameUpdate});

  void stop() {
    isRunning = false;
    for (final player in _activePlayers) {
      player.stop();
    }
    _activePlayers.clear();
  }

  void _notifyFrameUpdate() {
    if (onFrameUpdate != null) {
      onFrameUpdate!();
    }
  }

  Future<void> run() async {
    isRunning = true;
    final greenFlagBlocks = <MapEntry<String, dynamic>>[];
    final targetByBlockId = <String, ScratchTarget>{};

    for (final target in projectBank.targets) {
      for (final entry in target.blocks.entries) {
        final block = entry.value;
        if (block is Map && block['opcode'] == 'event_whenflagclicked') {
          greenFlagBlocks.add(entry);
          targetByBlockId[entry.key] = target;
        }
      }
    }

    final futures = greenFlagBlocks.map((entry) {
      final target = targetByBlockId[entry.key];
      return _executeBlockChain(target!, entry.key);
    }).toList();

    await Future.wait(futures);

    isRunning = false;
  }

  Future<void> _executeBlockChain(ScratchTarget target, String blockId) async {
    String? currentBlockId = blockId;

    while (currentBlockId != null && isRunning) {
      final blockData = target.blocks[currentBlockId];
      if (blockData is! Map<String, dynamic>) {
        currentBlockId = null;
        continue;
      }

      await _executeBlock(target, blockData);

      currentBlockId = blockData['next'] as String?;
    }
  }

  Future<void> _executeBlock(ScratchTarget target, Map<String, dynamic> block) async {
    final opcode = block['opcode'] as String?;

    if (opcode == null) return;

    switch (opcode) {
      case 'motion_movesteps':
        await _executeMotionMoveSteps(target, block);
        break;
      case 'motion_gotoxy':
        await _executeMotionGoToXY(target, block);
        break;
      case 'motion_turnright':
        await _executeMotionTurnRight(target, block);
        break;
      case 'motion_turnleft':
        await _executeMotionTurnLeft(target, block);
        break;
      case 'motion_pointindirection':
        await _executeMotionPointInDirection(target, block);
        break;
      case 'motion_changexby':
        await _executeMotionChangeXBy(target, block);
        break;
      case 'motion_setx':
        await _executeMotionSetX(target, block);
        break;
      case 'motion_changeyby':
        await _executeMotionChangeYBy(target, block);
        break;
      case 'motion_sety':
        await _executeMotionSetY(target, block);
        break;
      case 'motion_goto':
        await _executeMotionGoTo(target, block);
        break;
      case 'motion_pointtowards':
        await _executeMotionPointTowards(target, block);
        break;
      case 'motion_ifonedgebounce':
        await _executeMotionIfOnEdgeBounce(target, block);
        break;
      case 'motion_setrotationstyle':
        await _executeMotionSetRotationStyle(target, block);
        break;
      case 'motion_glidesecstoxy':
        await _executeMotionGlideSecsToXY(target, block);
        break;
      case 'looks_say':
        await _executeLooksSay(target, block);
        break;
      case 'looks_sayforsecs':
        await _executeLooksSayForSecs(target, block);
        break;
      case 'looks_think':
        await _executeLooksThink(target, block);
        break;
      case 'looks_thinkforsecs':
        await _executeLooksThinkForSecs(target, block);
        break;
      case 'looks_show':
        await _executeLooksShow(target, block);
        break;
      case 'looks_hide':
        await _executeLooksHide(target, block);
        break;
      case 'looks_nextcostume':
        await _executeLooksNextCostume(target, block);
        break;
      case 'looks_switchcostumeto':
        await _executeLooksSwitchCostumeTo(target, block);
        break;
      case 'looks_nextbackdrop':
        await _executeLooksNextBackdrop(target, block);
        break;
      case 'looks_switchbackdropto':
        await _executeLooksSwitchBackdropTo(target, block);
        break;
      case 'looks_changesizeby':
        await _executeLooksChangeSizeBy(target, block);
        break;
      case 'looks_setsizeto':
        await _executeLooksSetSizeTo(target, block);
        break;
      case 'looks_gotofrontback':
        await _executeLooksGoToFrontBack(target, block);
        break;
      case 'looks_goforwardbackwardlayers':
        await _executeLooksGoForwardBackwardLayers(target, block);
        break;
      case 'looks_changeeffectby':
        await _executeLooksChangeEffectBy(target, block);
        break;
      case 'looks_seteffectto':
        await _executeLooksSetEffectTo(target, block);
        break;
      case 'looks_cleargraphiceffects':
        await _executeLooksClearGraphicEffects(target, block);
        break;
      case 'sound_play':
        await _executeSoundPlay(target, block);
        break;
      case 'sound_playuntildone':
        await _executeSoundPlayUntilDone(target, block);
        break;
      case 'sound_stopallsounds':
        await _executeSoundStopAllSounds(target, block);
        break;
      case 'sound_setvolumeto':
        await _executeSoundSetVolumeTo(target, block);
        break;
      case 'sound_changevolumeby':
        await _executeSoundChangeVolumeBy(target, block);
        break;
      case 'event_broadcast':
        await _executeEventBroadcast(target, block);
        break;
      case 'event_broadcastandwait':
        await _executeEventBroadcastAndWait(target, block);
        break;
      case 'control_wait':
        await _executeControlWait(target, block);
        break;
      case 'control_repeat':
        await _executeControlRepeat(target, block);
        break;
      case 'control_forever':
        await _executeControlForever(target, block);
        break;
      case 'control_if':
        await _executeControlIf(target, block);
        break;
      case 'control_if_else':
        await _executeControlIfElse(target, block);
        break;
      case 'control_stop':
        await _executeControlStop(target, block);
        break;
      case 'control_create_clone_of':
        await _executeControlCreateCloneOf(target, block);
        break;
      case 'control_delete_this_clone':
        await _executeControlDeleteThisClone(target, block);
        break;
      case 'operator_add':
        await _executeOperatorAdd(target, block);
        break;
      case 'operator_subtract':
        await _executeOperatorSubtract(target, block);
        break;
      case 'operator_multiply':
        await _executeOperatorMultiply(target, block);
        break;
      case 'operator_divide':
        await _executeOperatorDivide(target, block);
        break;
      case 'operator_random':
        await _executeOperatorRandom(target, block);
        break;
      case 'operator_join':
        await _executeOperatorJoin(target, block);
        break;
      case 'operator_letter_of':
        await _executeOperatorLetterOf(target, block);
        break;
      case 'operator_length':
        await _executeOperatorLength(target, block);
        break;
      case 'operator_round':
        await _executeOperatorRound(target, block);
        break;
      case 'operator_mod':
        await _executeOperatorMod(target, block);
        break;
      case 'operator_lt':
        await _executeOperatorLt(target, block);
        break;
      case 'operator_equals':
        await _executeOperatorEquals(target, block);
        break;
      case 'operator_gt':
        await _executeOperatorGt(target, block);
        break;
      case 'operator_and':
        await _executeOperatorAnd(target, block);
        break;
      case 'operator_or':
        await _executeOperatorOr(target, block);
        break;
      case 'operator_not':
        await _executeOperatorNot(target, block);
        break;
      case 'operator_contains':
        await _executeOperatorContains(target, block);
        break;
      case 'data_setvariableto':
        await _executeDataSetVariableTo(target, block);
        break;
      case 'data_changevariableby':
        await _executeDataChangeVariableBy(target, block);
        break;
      case 'data_addtolist':
        await _executeDataAddToList(target, block);
        break;
      case 'data_deleteoflist':
        await _executeDataDeleteOfList(target, block);
        break;
      case 'data_deletealloflist':
        await _executeDataDeleteAllOfList(target, block);
        break;
      case 'data_insertatlist':
        await _executeDataInsertAtList(target, block);
        break;
      case 'data_replaceitemoflist':
        await _executeDataReplaceItemOfList(target, block);
        break;
      case 'sensing_touchingobject':
        await _executeSensingTouchingObject(target, block);
        break;
      case 'sensing_touchingcolor':
        await _executeSensingTouchingColor(target, block);
        break;
      case 'sensing_distanceto':
        await _executeSensingDistanceTo(target, block);
        break;
      case 'sensing_mousex':
        await _executeSensingMouseX(target, block);
        break;
      case 'sensing_mousey':
        await _executeSensingMouseY(target, block);
        break;
      case 'sensing_mousedown':
        await _executeSensingMouseDown(target, block);
        break;
      case 'sensing_keypressed':
        await _executeSensingKeyPressed(target, block);
        break;
      case 'sensing_timer':
        await _executeSensingTimer(target, block);
        break;
      case 'sensing_resettimer':
        await _executeSensingResetTimer(target, block);
        break;
      case 'sensing_askandwait':
        await _executeSensingAskAndWait(target, block);
        break;
    }
  }

  Future<void> _executeMotionMoveSteps(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final stepsData = inputs['STEPS'] as List?;
    
    double steps = 0;
    if (stepsData != null && stepsData.length >= 2) {
      final value = stepsData[1];
      steps = _castToNumber(value);
    }

    final radians = (90 - target.direction) * math.pi / 180;
    final dx = steps * math.cos(radians);
    final dy = steps * math.sin(radians);

    target.setXY(target.x + dx, target.y + dy);
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _executeMotionGoToXY(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final xData = inputs['X'] as List?;
    final yData = inputs['Y'] as List?;

    double x = 0;
    double y = 0;

    if (xData != null && xData.length >= 2) {
      x = _castToNumber(xData[1]);
    }
    if (yData != null && yData.length >= 2) {
      y = _castToNumber(yData[1]);
    }

    target.setXY(x, y);
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _executeMotionTurnRight(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final degreesData = inputs['DEGREES'] as List?;

    double degrees = 0;
    if (degreesData != null && degreesData.length >= 2) {
      degrees = _castToNumber(degreesData[1]);
    }

    target.setDirection(target.direction + degrees);
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeMotionTurnLeft(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final degreesData = inputs['DEGREES'] as List?;

    double degrees = 0;
    if (degreesData != null && degreesData.length >= 2) {
      degrees = _castToNumber(degreesData[1]);
    }

    target.setDirection(target.direction - degrees);
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeMotionPointInDirection(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final directionData = inputs['DIRECTION'] as List?;

    double direction = 90;
    if (directionData != null && directionData.length >= 2) {
      direction = _castToNumber(directionData[1]);
    }

    target.setDirection(direction);
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeMotionChangeXBy(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final dxData = inputs['DX'] as List?;

    double dx = 0;
    if (dxData != null && dxData.length >= 2) {
      dx = _castToNumber(dxData[1]);
    }

    target.setX(target.x + dx);
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _executeMotionSetX(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final xData = inputs['X'] as List?;

    double x = 0;
    if (xData != null && xData.length >= 2) {
      x = _castToNumber(xData[1]);
    }

    target.setX(x);
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _executeMotionChangeYBy(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final dyData = inputs['DY'] as List?;

    double dy = 0;
    if (dyData != null && dyData.length >= 2) {
      dy = _castToNumber(dyData[1]);
    }

    target.setY(target.y + dy);
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _executeMotionSetY(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final yData = inputs['Y'] as List?;

    double y = 0;
    if (yData != null && yData.length >= 2) {
      y = _castToNumber(yData[1]);
    }

    target.setY(y);
    await Future.delayed(const Duration(milliseconds: 100));
  }

  double _castToNumber(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is List && value.isNotEmpty) {
      return _castToNumber(value[1]);
    }
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0;
    }
    return 0;
  }

  String _castToString(dynamic value) {
    if (value is String) {
      return value;
    }
    if (value is List && value.isNotEmpty) {
      return _castToString(value[1]);
    }
    return value?.toString() ?? '';
  }

  bool _castToBoolean(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is List && value.isNotEmpty) {
      return _castToBoolean(value[1]);
    }
    if (value is String) {
      final lower = value.toLowerCase();
      return lower != '' && lower != '0' && lower != 'false';
    }
    return false;
  }

  Future<void> _executeMotionGoTo(ScratchTarget target, Map<String, dynamic> block) async {
    final fields = block['fields'] as Map? ?? {};
    final toData = fields['TO'] as List?;
    final to = toData != null && toData.isNotEmpty ? _castToString(toData[0]) : '';
    
    if (to == '_mouse_') {
      target.setXY(0, 0);
    } else if (to == '_random_') {
      target.setXY((math.Random().nextDouble() - 0.5) * 480, (math.Random().nextDouble() - 0.5) * 360);
    } else {
      final sprite = projectBank.targets.firstWhere(
        (t) => !t.isStage && t.name == to,
        orElse: () => target,
      );
      target.setXY(sprite.x, sprite.y);
    }
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _executeMotionPointTowards(ScratchTarget target, Map<String, dynamic> block) async {
    final fields = block['fields'] as Map? ?? {};
    final towardsData = fields['TOWARDS'] as List?;
    final towards = towardsData != null && towardsData.isNotEmpty ? _castToString(towardsData[0]) : '';
    
    double targetX = 0;
    double targetY = 0;
    
    if (towards == '_mouse_') {
      targetX = 0;
      targetY = 0;
    } else if (towards == '_random_') {
      targetX = (math.Random().nextDouble() - 0.5) * 480;
      targetY = (math.Random().nextDouble() - 0.5) * 360;
    } else {
      final sprite = projectBank.targets.firstWhere(
        (t) => !t.isStage && t.name == towards,
        orElse: () => target,
      );
      targetX = sprite.x;
      targetY = sprite.y;
    }
    
    final dx = targetX - target.x;
    final dy = targetY - target.y;
    double angle = math.atan2(dy, dx) * 180 / math.pi;
    angle = (angle + 90) % 360;
    if (angle < 0) angle += 360;
    
    target.setDirection(angle);
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeMotionIfOnEdgeBounce(ScratchTarget target, Map<String, dynamic> block) async {
    final bounds = 240.0;
    double newDirection = target.direction;
    
    if (target.x.abs() > bounds) {
      newDirection = 180 - newDirection;
      target.setX(target.x > 0 ? bounds : -bounds);
    }
    if (target.y.abs() > 180.0) {
      newDirection = -newDirection;
      target.setY(target.y > 0 ? 180.0 : -180.0);
    }
    
    target.setDirection(newDirection);
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeMotionSetRotationStyle(ScratchTarget target, Map<String, dynamic> block) async {
    final fields = block['fields'] as Map? ?? {};
    final styleData = fields['STYLE'] as List?;
    final style = styleData != null && styleData.isNotEmpty ? _castToString(styleData[0]) : 'all around';
    target.rotationStyle = style;
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeMotionGlideSecsToXY(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final secsData = inputs['SECS'] as List?;
    final xData = inputs['X'] as List?;
    final yData = inputs['Y'] as List?;
    
    final secs = secsData != null && secsData.length >= 2 ? _castToNumber(secsData[1]) : 1;
    final targetX = xData != null && xData.length >= 2 ? _castToNumber(xData[1]) : 0;
    final targetY = yData != null && yData.length >= 2 ? _castToNumber(yData[1]) : 0;
    
    final startX = target.x;
    final startY = target.y;
    final steps = 20;
    final stepDuration = (secs * 1000) / steps;
    
    for (int i = 1; i <= steps; i++) {
      if (!isRunning) break;
      final t = i / steps;
      target.setXY(startX + (targetX - startX) * t, startY + (targetY - startY) * t);
      await Future.delayed(Duration(milliseconds: stepDuration.round()));
    }
  }

  Future<void> _executeLooksSay(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final messageData = inputs['MESSAGE'] as List?;
    final message = messageData != null && messageData.length >= 2 ? _castToString(messageData[1]) : '';
    debugPrint('角色 ${target.name} 说: $message');
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _executeLooksSayForSecs(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final messageData = inputs['MESSAGE'] as List?;
    final secsData = inputs['SECS'] as List?;
    
    final message = messageData != null && messageData.length >= 2 ? _castToString(messageData[1]) : '';
    final secs = secsData != null && secsData.length >= 2 ? _castToNumber(secsData[1]) : 1;
    
    debugPrint('角色 ${target.name} 说: $message (持续 $secs 秒)');
    await Future.delayed(Duration(milliseconds: (secs * 1000).round()));
  }

  Future<void> _executeLooksThink(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final messageData = inputs['MESSAGE'] as List?;
    final message = messageData != null && messageData.length >= 2 ? _castToString(messageData[1]) : '';
    debugPrint('角色 ${target.name} 想: $message');
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _executeLooksThinkForSecs(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final messageData = inputs['MESSAGE'] as List?;
    final secsData = inputs['SECS'] as List?;
    
    final message = messageData != null && messageData.length >= 2 ? _castToString(messageData[1]) : '';
    final secs = secsData != null && secsData.length >= 2 ? _castToNumber(secsData[1]) : 1;
    
    debugPrint('角色 ${target.name} 想: $message (持续 $secs 秒)');
    await Future.delayed(Duration(milliseconds: (secs * 1000).round()));
  }

  Future<void> _executeLooksShow(ScratchTarget target, Map<String, dynamic> block) async {
    target.isVisible = true;
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeLooksHide(ScratchTarget target, Map<String, dynamic> block) async {
    target.isVisible = false;
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeLooksNextCostume(ScratchTarget target, Map<String, dynamic> block) async {
    if (target.costumes.isNotEmpty) {
      target.currentCostume = (target.currentCostume + 1) % target.costumes.length;
    }
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _executeLooksSwitchCostumeTo(ScratchTarget target, Map<String, dynamic> block) async {
    final fields = block['fields'] as Map? ?? {};
    final costumeData = fields['COSTUME'] as List?;
    final costumeName = costumeData != null && costumeData.isNotEmpty ? _castToString(costumeData[0]) : '';
    
    final index = target.costumes.indexWhere((c) => c.name == costumeName);
    if (index != -1) {
      target.currentCostume = index;
    }
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeLooksNextBackdrop(ScratchTarget target, Map<String, dynamic> block) async {
    final stage = projectBank.targets.firstWhere((t) => t.isStage);
    if (stage.costumes.isNotEmpty) {
      stage.currentCostume = (stage.currentCostume + 1) % stage.costumes.length;
    }
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _executeLooksSwitchBackdropTo(ScratchTarget target, Map<String, dynamic> block) async {
    final stage = projectBank.targets.firstWhere((t) => t.isStage);
    final fields = block['fields'] as Map? ?? {};
    final backdropData = fields['BACKDROP'] as List?;
    final backdropName = backdropData != null && backdropData.isNotEmpty ? _castToString(backdropData[0]) : '';
    
    final index = stage.costumes.indexWhere((c) => c.name == backdropName);
    if (index != -1) {
      stage.currentCostume = index;
    }
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeLooksChangeSizeBy(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final changeData = inputs['CHANGE'] as List?;
    final change = changeData != null && changeData.length >= 2 ? _castToNumber(changeData[1]) : 0;
    target.size = (target.size + change).clamp(0, 1000);
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeLooksSetSizeTo(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final sizeData = inputs['SIZE'] as List?;
    final size = sizeData != null && sizeData.length >= 2 ? _castToNumber(sizeData[1]) : 100;
    target.size = (size.clamp(0, 1000)).toDouble();
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeLooksGoToFrontBack(ScratchTarget target, Map<String, dynamic> block) async {
    final fields = block['fields'] as Map? ?? {};
    final frontBackData = fields['FRONTBACK'] as List?;
    final frontBack = frontBackData != null && frontBackData.isNotEmpty ? _castToString(frontBackData[0]) : '';
    
    if (frontBack == 'front') {
      target.layerOrder = projectBank.targets.fold(0, (max, t) => math.max(max, t.layerOrder)) + 1;
    } else {
      target.layerOrder = 0;
    }
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeLooksGoForwardBackwardLayers(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final layersData = inputs['LAYERS'] as List?;
    final layers = layersData != null && layersData.length >= 2 ? _castToNumber(layersData[1]) : 0;
    target.layerOrder = ((target.layerOrder + layers).clamp(0, 1000)).toInt();
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeLooksChangeEffectBy(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeLooksSetEffectTo(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeLooksClearGraphicEffects(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeSoundPlay(ScratchTarget target, Map<String, dynamic> block) async {
    final fields = block['fields'] as Map? ?? {};
    final soundData = fields['SOUND_MENU'] as List?;
    final soundName = soundData != null && soundData.isNotEmpty ? _castToString(soundData[0]) : '';

    debugPrint('播放声音: $soundName');

    final sound = target.sounds.firstWhere(
      (s) => s.name == soundName,
      orElse: () => ScratchSound(
        name: '',
        md5ext: '',
        dataFormat: '',
        data: Uint8List(0),
        format: '',
        rate: 0,
        sampleCount: 0,
      ),
    );

    if (sound.name.isNotEmpty && sound.data.isNotEmpty) {
      try {
        final audioSource = _createAudioSource(sound);
        if (audioSource != null) {
          final player = AudioPlayer();
          _activePlayers.add(player);
          await player.setAudioSource(audioSource);
          await player.setVolume(target.volume / 100);
          await player.play();
          player.playerStateStream.listen((state) {
            if (!state.playing) {
              player.dispose();
              _activePlayers.remove(player);
            }
          });
        }
      } catch (e) {
        debugPrint('播放声音失败: $e');
      }
    }

    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _executeSoundPlayUntilDone(ScratchTarget target, Map<String, dynamic> block) async {
    final fields = block['fields'] as Map? ?? {};
    final soundData = fields['SOUND_MENU'] as List?;
    final soundName = soundData != null && soundData.isNotEmpty ? _castToString(soundData[0]) : '';

    debugPrint('播放声音直到完成: $soundName');

    final sound = target.sounds.firstWhere(
      (s) => s.name == soundName,
      orElse: () => ScratchSound(
        name: '',
        md5ext: '',
        dataFormat: '',
        data: Uint8List(0),
        format: '',
        rate: 0,
        sampleCount: 0,
      ),
    );

    if (sound.name.isNotEmpty && sound.data.isNotEmpty) {
      try {
        final audioSource = _createAudioSource(sound);
        if (audioSource != null) {
          final player = AudioPlayer();
          _activePlayers.add(player);
          await player.setAudioSource(audioSource);
          await player.setVolume(target.volume / 100);
          await player.play();

          while (player.playing && isRunning) {
            await Future.delayed(const Duration(milliseconds: 50));
          }

          player.dispose();
          _activePlayers.remove(player);
        }
      } catch (e) {
        debugPrint('播放声音失败: $e');
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  AudioSource? _createAudioSource(ScratchSound sound) {
    if (sound.dataFormat == 'wav') {
      return _WavAudioSource(sound.data);
    } else if (sound.dataFormat == 'mp3') {
      return _Mp3AudioSource(sound.data);
    }
    return null;
  }

  Future<void> _executeSoundStopAllSounds(ScratchTarget target, Map<String, dynamic> block) async {
    debugPrint('停止所有声音');
    for (final player in _activePlayers) {
      player.stop();
    }
    _activePlayers.clear();
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeSoundSetVolumeTo(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final volumeData = inputs['VOLUME'] as List?;
    final volume = volumeData != null && volumeData.length >= 2 ? _castToNumber(volumeData[1]) : 100;
    target.volume = (volume.clamp(0, 100)).toDouble();
    for (final player in _activePlayers) {
      player.setVolume(target.volume / 100);
    }
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeSoundChangeVolumeBy(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final volumeData = inputs['VOLUME'] as List?;
    final volume = volumeData != null && volumeData.length >= 2 ? _castToNumber(volumeData[1]) : 0;
    target.volume = ((target.volume + volume).clamp(0, 100)).toDouble();
    for (final player in _activePlayers) {
      player.setVolume(target.volume / 100);
    }
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeEventBroadcast(ScratchTarget target, Map<String, dynamic> block) async {
    final fields = block['fields'] as Map? ?? {};
    final broadcastData = fields['BROADCAST_OPTION'] as List?;
    final broadcastOption = broadcastData != null && broadcastData.isNotEmpty ? _castToString(broadcastData[0]) : '';
    
    debugPrint('广播: $broadcastOption');
    
    for (final t in projectBank.targets) {
      for (final entry in t.blocks.entries) {
        final blockData = entry.value;
        if (blockData is Map && blockData['opcode'] == 'event_whenbroadcastreceived') {
          final bFields = blockData['fields'] as Map? ?? {};
          final bData = bFields['BROADCAST_OPTION'] as List?;
          final bOption = bData != null && bData.isNotEmpty ? _castToString(bData[0]) : '';
          if (bOption == broadcastOption) {
            await _executeBlockChain(t, entry.key);
          }
        }
      }
    }
  }

  Future<void> _executeEventBroadcastAndWait(ScratchTarget target, Map<String, dynamic> block) async {
    await _executeEventBroadcast(target, block);
  }

  Future<void> _executeControlWait(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final durationData = inputs['DURATION'] as List?;
    final duration = durationData != null && durationData.length >= 2 ? _castToNumber(durationData[1]) : 1;
    await Future.delayed(Duration(milliseconds: (duration * 1000).round()));
  }

  Future<void> _executeControlRepeat(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final timesData = inputs['TIMES'] as List?;
    final times = timesData != null && timesData.length >= 2 ? _castToNumber(timesData[1]) : 1;
    final substack = inputs['SUBSTACK'] as List?;
    
    if (substack == null || substack.length < 2) {
      return;
    }
    
    final substackBlockId = substack[1] as String;
    
    for (int i = 0; i < times.toInt() && isRunning; i++) {
      await _executeBlockChain(target, substackBlockId);
      if (isRunning) {
        await Future.delayed(const Duration(milliseconds: 33));
        _notifyFrameUpdate();
      }
    }
  }

  Future<void> _executeControlForever(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final substack = inputs['SUBSTACK'] as List?;
    
    if (substack == null || substack.length < 2) {
      return;
    }
    
    final substackBlockId = substack[1] as String;
    
    while (isRunning) {
      await _executeBlockChain(target, substackBlockId);
      if (isRunning) {
        await Future.delayed(const Duration(milliseconds: 33));
        _notifyFrameUpdate();
      }
    }
  }

  Future<void> _executeControlIf(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final conditionData = inputs['CONDITION'] as List?;
    bool condition = false;
    
    if (conditionData != null && conditionData.length >= 2) {
      condition = _castToBoolean(conditionData[1]);
    }
    
    if (condition) {
      final substack = block['inputs']?['SUBSTACK'] as List?;
      if (substack != null && substack.length >= 2) {
        await _executeBlockChain(target, substack[1] as String);
      }
    }
  }

  Future<void> _executeControlIfElse(ScratchTarget target, Map<String, dynamic> block) async {
    final inputs = block['inputs'] as Map? ?? {};
    final conditionData = inputs['CONDITION'] as List?;
    bool condition = false;
    
    if (conditionData != null && conditionData.length >= 2) {
      condition = _castToBoolean(conditionData[1]);
    }
    
    if (condition) {
      final substack = block['inputs']?['SUBSTACK'] as List?;
      if (substack != null && substack.length >= 2) {
        await _executeBlockChain(target, substack[1] as String);
      }
    } else {
      final substack2 = block['inputs']?['SUBSTACK2'] as List?;
      if (substack2 != null && substack2.length >= 2) {
        await _executeBlockChain(target, substack2[1] as String);
      }
    }
  }

  Future<void> _executeControlStop(ScratchTarget target, Map<String, dynamic> block) async {
    final fields = block['fields'] as Map? ?? {};
    final stopOptionData = fields['STOP_OPTION'] as List?;
    final stopOption = stopOptionData != null && stopOptionData.isNotEmpty ? _castToString(stopOptionData[0]) : 'all';
    
    if (stopOption == 'all') {
      isRunning = false;
    }
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeControlCreateCloneOf(ScratchTarget target, Map<String, dynamic> block) async {
    debugPrint('创建克隆体');
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _executeControlDeleteThisClone(ScratchTarget target, Map<String, dynamic> block) async {
    debugPrint('删除克隆体');
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeOperatorAdd(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeOperatorSubtract(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeOperatorMultiply(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeOperatorDivide(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeOperatorRandom(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeOperatorJoin(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeOperatorLetterOf(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeOperatorLength(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeOperatorRound(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeOperatorMod(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeOperatorLt(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeOperatorEquals(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeOperatorGt(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeOperatorAnd(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeOperatorOr(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeOperatorNot(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeOperatorContains(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeDataSetVariableTo(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeDataChangeVariableBy(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeDataAddToList(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeDataDeleteOfList(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeDataDeleteAllOfList(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeDataInsertAtList(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeDataReplaceItemOfList(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _executeSensingTouchingObject(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeSensingTouchingColor(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeSensingDistanceTo(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeSensingMouseX(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeSensingMouseY(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeSensingMouseDown(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeSensingKeyPressed(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeSensingTimer(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeSensingResetTimer(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> _executeSensingAskAndWait(ScratchTarget target, Map<String, dynamic> block) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _selectedFilePath;
  Uint8List? _selectedFileBytes;
  ProjectBank? _projectBank;
  bool _isLoading = false;
  String _statusMessage = '请选择 SB3 文件';

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sb3'],
        withData: true,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _selectedFileBytes = result.files.single.bytes;
          _projectBank = null;
          _statusMessage = '文件已选择，请点击加载';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '选择文件失败: $e';
      });
    }
  }

  Future<void> _loadProject() async {
    if (_selectedFileBytes == null) {
      setState(() {
        _statusMessage = '请先选择文件';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '正在加载文件...';
    });

    try {
      final bank = await _parseSB3(_selectedFileBytes!);

      setState(() {
        _projectBank = bank;
        _isLoading = false;
        _statusMessage = '加载成功！\n'
            '项目版本: ${bank.projectVersion}\n'
            '目标数量: ${bank.targets.length}\n'
            '造型数量: ${bank.allCostumes.length}\n'
            '声音数量: ${bank.allSounds.length}\n'
            '点击渲染查看舞台';
      });

      debugPrint('项目加载成功！');
      debugPrint('目标数量: ${bank.targets.length}');
      for (var target in bank.targets) {
        debugPrint('  - ${target.name} (${target.isStage ? "舞台" : "角色"}), 造型: ${target.costumes.length}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '加载失败: $e';
      });
      debugPrint('加载失败: $e');
    }
  }

  Future<ProjectBank> _parseSB3(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);

    Map<String, dynamic>? projectJson;
    final Map<String, Uint8List> assets = {};

    for (final file in archive) {
      if (file.isFile) {
        final data = file.content as List<int>;
        final bytes = Uint8List.fromList(data);

        if (file.name == 'project.json') {
          final jsonString = utf8.decode(bytes);
          projectJson = json.decode(jsonString) as Map<String, dynamic>;
        } else {
          assets[file.name] = bytes;
        }
      }
    }

    if (projectJson == null) {
      throw Exception('project.json not found in SB3 file');
    }

    final targets = <ScratchTarget>[];
    final allCostumes = <ScratchCostume>[];
    final allSounds = <ScratchSound>[];

    final targetsJson = projectJson['targets'] as List<dynamic>? ?? [];

    for (final targetJson in targetsJson) {
      final target = _parseTarget(targetJson as Map<String, dynamic>, assets);
      targets.add(target);
      allCostumes.addAll(target.costumes);
      allSounds.addAll(target.sounds);
    }

    return ProjectBank(
      projectJson: projectJson,
      targets: targets,
      allCostumes: allCostumes,
      allSounds: allSounds,
    );
  }

  ScratchTarget _parseTarget(
    Map<String, dynamic> targetJson,
    Map<String, Uint8List> assets,
  ) {
    final costumesJson = targetJson['costumes'] as List<dynamic>? ?? [];
    final soundsJson = targetJson['sounds'] as List<dynamic>? ?? [];

    final costumes = costumesJson.map((costumeJson) {
      return _parseCostume(costumeJson as Map<String, dynamic>, assets);
    }).toList();

    final sounds = soundsJson.map((soundJson) {
      return _parseSound(soundJson as Map<String, dynamic>, assets);
    }).toList();

    return ScratchTarget(
      name: targetJson['name'] ?? 'Unknown',
      isStage: targetJson['isStage'] ?? false,
      isVisible: targetJson['visible'] ?? true,
      x: (targetJson['x'] ?? 0).toDouble(),
      y: (targetJson['y'] ?? 0).toDouble(),
      direction: (targetJson['direction'] ?? 90).toDouble(),
      size: ((targetJson['size'] ?? 100) as num).roundToDouble(),
      currentCostume: ((targetJson['currentCostume'] ?? 0) as num).toInt(),
      variables: Map<String, dynamic>.from(targetJson['variables'] ?? {}),
      lists: Map<String, dynamic>.from(targetJson['lists'] ?? {}),
      broadcasts: Map<String, dynamic>.from(targetJson['broadcasts'] ?? {}),
      blocks: Map<String, dynamic>.from(targetJson['blocks'] ?? {}),
      costumes: costumes,
      sounds: sounds,
      layerOrder: ((targetJson['layerOrder'] ?? 0) as num).toInt(),
      volume: (targetJson['volume'] ?? 100).toDouble(),
      rotationStyle: targetJson['rotationStyle'] ?? 'all around',
    );
  }

  ScratchCostume _parseCostume(
    Map<String, dynamic> costumeJson,
    Map<String, Uint8List> assets,
  ) {
    final md5ext = costumeJson['md5ext'] ?? '';
    final dataFormat = costumeJson['dataFormat'] ?? 'png';
    Uint8List? data;

    if (assets.containsKey(md5ext)) {
      data = assets[md5ext];
    }

    return ScratchCostume(
      name: costumeJson['name'] ?? 'costume',
      md5ext: md5ext,
      dataFormat: dataFormat,
      data: data ?? Uint8List(0),
      rotationCenterX: ((costumeJson['rotationCenterX'] ?? 0) as num).toInt(),
      rotationCenterY: ((costumeJson['rotationCenterY'] ?? 0) as num).toInt(),
      bitmapResolution: ((costumeJson['bitmapResolution'] ?? 1) as num).toInt(),
    );
  }

  ScratchSound _parseSound(
    Map<String, dynamic> soundJson,
    Map<String, Uint8List> assets,
  ) {
    final md5ext = soundJson['md5ext'] ?? '';
    final dataFormat = soundJson['dataFormat'] ?? 'wav';
    Uint8List? data;

    if (assets.containsKey(md5ext)) {
      data = assets[md5ext];
    }

    return ScratchSound(
      name: soundJson['name'] ?? 'sound',
      md5ext: md5ext,
      dataFormat: dataFormat,
      data: data ?? Uint8List(0),
      format: soundJson['format'] ?? '',
      rate: ((soundJson['rate'] ?? 44100) as num).toInt(),
      sampleCount: ((soundJson['sampleCount'] ?? 0) as num).toInt(),
    );
  }

  void _render() {
    if (_projectBank == null) {
      setState(() {
        _statusMessage = '请先加载项目';
      });
      return;
    }

    setState(() {
      _statusMessage = '渲染完成！\n'
          '舞台: ${_projectBank!.targets.where((t) => t.isStage).length}\n'
          '角色: ${_projectBank!.targets.where((t) => !t.isStage).length}';
    });
  }

  bool _isRunning = false;
  BlockExecutor? _currentExecutor;

  Future<void> _runProject() async {
    if (_projectBank == null) {
      setState(() {
        _statusMessage = '请先加载项目';
      });
      return;
    }

    _currentExecutor = BlockExecutor(
      _projectBank!,
      onFrameUpdate: () {
        if (mounted) {
          setState(() {});
        }
      },
    );

    setState(() {
      _isRunning = true;
      _statusMessage = '运行中...';
    });

    await _currentExecutor!.run();

    if (mounted) {
      setState(() {
        _isRunning = false;
        _currentExecutor = null;
        _statusMessage = '运行完成！';
      });
    }
  }

  void _stopProject() {
    if (_currentExecutor != null) {
      _currentExecutor!.stop();
      if (mounted) {
        setState(() {
          _statusMessage = '已停止';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            height: 60,
            color: Colors.grey[300],
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerLeft,
            child: const Text(
              'SOF',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '舞台渲染画面',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 480,
                          height: 320,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.black38,
                              width: 2,
                            ),
                          ),
                          child: _projectBank != null
                              ? _buildStageWidget()
                              : Center(
                                  child: Text(
                                    _statusMessage,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'sb3文件',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _selectedFilePath ?? '未选择文件',
                            style: TextStyle(
                              fontSize: 14,
                              color: _selectedFilePath != null
                                  ? Colors.black87
                                  : Colors.black45,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _pickFile,
                            icon: const Icon(Icons.folder_open, size: 18),
                            label: const Text('选择文件'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              foregroundColor: Colors.black87,
                              elevation: 0,
                              side: BorderSide(
                                color: Colors.black38,
                                width: 1,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _render,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[300],
                                  foregroundColor: Colors.black87,
                                  elevation: 0,
                                  side: BorderSide(
                                    color: Colors.black38,
                                    width: 1,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                                child: const Text(
                                  '渲染',
                                  style: TextStyle(
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _loadProject,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[300],
                                  foregroundColor: Colors.black87,
                                  elevation: 0,
                                  side: BorderSide(
                                    color: Colors.black38,
                                    width: 1,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        '加载',
                                        style: TextStyle(
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : (_isRunning ? _stopProject : _runProject),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isRunning ? Colors.red : Colors.lightGreen,
                                  foregroundColor: _isRunning ? Colors.white : Colors.black87,
                                  elevation: 0,
                                  side: BorderSide(
                                    color: _isRunning ? Colors.red[700]! : Colors.green[600]!,
                                    width: 1,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                                child: _isRunning
                                    ? const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.stop, size: 16, color: Colors.white),
                                          SizedBox(width: 4),
                                          Text(
                                            '停止',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.play_arrow, size: 16),
                                          SizedBox(width: 4),
                                          Text(
                                            '运行',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageWidget() {
    final targets = _projectBank!.targets;

    final stage = targets.firstWhere(
      (t) => t.isStage,
      orElse: () => targets.first,
    );

    final sprites = targets.where((t) => !t.isStage).toList()
      ..sort((a, b) => a.layerOrder.compareTo(b.layerOrder));

    return Container(
      width: 480,
      height: 320,
      color: Colors.white,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (stage.costumes.isNotEmpty && stage.costumes[stage.currentCostume].data.isNotEmpty)
            _buildCostumeWidget(
              stage.costumes[stage.currentCostume],
              fit: BoxFit.cover,
            )
          else
            Container(
              color: Colors.lightBlue[100],
              child: const Center(
                child: Text('舞台背景'),
              ),
            ),
          ...sprites.map((sprite) {
            if (!sprite.isVisible || sprite.costumes.isEmpty) {
              return const SizedBox.shrink();
            }

            final costume = sprite.costumes[sprite.currentCostume];
            if (costume.data.isEmpty) {
              return const SizedBox.shrink();
            }

            final scratchStageWidth = 480.0;
            final scratchStageHeight = 360.0;
            final renderWidth = 480.0;
            final renderHeight = 320.0;

            final scaleX = renderWidth / scratchStageWidth;
            final scaleY = renderHeight / scratchStageHeight;

            final screenX = (sprite.x + scratchStageWidth / 2) * scaleX;
            final screenY = (scratchStageHeight / 2 - sprite.y) * scaleY;

            final scaledSize = sprite.size / 100 / costume.bitmapResolution;
            final scaledRotationCenterX = costume.rotationCenterX.toDouble() * scaledSize;
            final scaledRotationCenterY = costume.rotationCenterY.toDouble() * scaledSize;

            Widget child = _buildCostumeWidget(costume, fit: BoxFit.contain);

            if (sprite.rotationStyle == 'left-right' &&
                (sprite.direction < 0 || sprite.direction > 180)) {
              child = Transform.flip(flipX: true, child: child);
            } else if (sprite.rotationStyle == 'all around') {
              child = Transform.rotate(
                angle: (sprite.direction - 90) * math.pi / 180,
                child: child,
              );
            }

            return Positioned(
              left: screenX - scaledRotationCenterX,
              top: screenY - scaledRotationCenterY,
              child: Transform.scale(
                scale: scaledSize,
                child: child,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCostumeWidget(
    ScratchCostume costume, {
    BoxFit fit = BoxFit.contain,
    double direction = 90,
    String rotationStyle = 'all around',
  }) {
    if (costume.data.isEmpty) {
      return Container(
        width: 50,
        height: 50,
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image, size: 24),
      );
    }

    Widget imageWidget;
    if (costume.dataFormat == 'svg') {
      imageWidget = SvgPicture.memory(
        costume.data,
        fit: fit,
      );
    } else {
      imageWidget = Image.memory(
        costume.data,
        fit: fit,
      );
    }

    if (rotationStyle == 'all around') {
      final rotation = (direction - 90) * math.pi / 180;
      return Transform.rotate(
        angle: rotation,
        child: imageWidget,
      );
    } else if (rotationStyle == 'left-right') {
      if (direction < 0 || direction > 180) {
        return Transform.flip(
          flipX: true,
          child: imageWidget,
        );
      }
    }

    return imageWidget;
  }
}

// ignore: experimental_member_use
class _WavAudioSource extends StreamAudioSource {
  final Uint8List _data;

  _WavAudioSource(this._data);

  @override
  // ignore: experimental_member_use
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _data.length;
    // ignore: experimental_member_use
    return StreamAudioResponse(
      sourceLength: _data.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_data.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}

// ignore: experimental_member_use
class _Mp3AudioSource extends StreamAudioSource {
  final Uint8List _data;

  _Mp3AudioSource(this._data);

  @override
  // ignore: experimental_member_use
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _data.length;
    // ignore: experimental_member_use
    return StreamAudioResponse(
      sourceLength: _data.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_data.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
