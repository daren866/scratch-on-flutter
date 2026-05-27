import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as audioplayers;

class ScratchThread {
  static const int STATUS_RUNNING = 0;
  static const int STATUS_PROMISE_WAIT = 1;
  static const int STATUS_YIELD = 2;
  static const int STATUS_YIELD_TICK = 3;
  static const int STATUS_DONE = 4;

  final String topBlock;
  final List<String> stack = [];
  final Map<String, dynamic> stackFrame = {};
  int status = STATUS_RUNNING;
  ScratchTarget? target;

  ScratchThread(this.topBlock) {
    stack.add(topBlock);
  }

  String? peekStack() {
    if (stack.isEmpty) return null;
    return stack.last;
  }

  void pushStack(String blockId) {
    stack.add(blockId);
  }

  void popStack() {
    if (stack.isNotEmpty) {
      stack.removeLast();
    }
  }

  String? getNextBlock(Map<String, dynamic> blocks, String blockId) {
    final block = blocks[blockId];
    if (block == null) return null;
    final next = block['next'];
    return next;
  }

  bool get isLoop => stackFrame['isLoop'] ?? false;
  set isLoop(bool value) => stackFrame['isLoop'] = value;

  bool get warpMode => stackFrame['warpMode'] ?? false;
  set warpMode(bool value) => stackFrame['warpMode'] = value;

  dynamic get loopCounter {
    if (!stackFrame.containsKey('loopCounter')) {
      return null;
    }
    return stackFrame['loopCounter'];
  }

  set loopCounter(dynamic value) {
    stackFrame['loopCounter'] = value;
  }

  double? get stackTimerStart {
    if (!stackFrame.containsKey('stackTimerStart')) {
      return null;
    }
    return stackFrame['stackTimerStart'];
  }

  set stackTimerStart(double? value) {
    if (value == null) {
      stackFrame.remove('stackTimerStart');
    } else {
      stackFrame['stackTimerStart'] = value;
    }
  }

  double? get stackTimerDuration {
    if (!stackFrame.containsKey('stackTimerDuration')) {
      return null;
    }
    return stackFrame['stackTimerDuration'];
  }

  set stackTimerDuration(double? value) {
    if (value == null) {
      stackFrame.remove('stackTimerDuration');
    } else {
      stackFrame['stackTimerDuration'] = value;
    }
  }

  bool get stackTimerNeedsInit => stackTimerStart == null;
}

class BlockUtility {
  ScratchTarget target;
  ScratchThread thread;
  ScratchRuntime runtime;

  BlockUtility(this.target, this.thread, this.runtime);

  void startBranch(int branchNum, bool isLoop) {
    final currentBlockId = thread.peekStack();
    if (currentBlockId == null) return;

    final block = _getBlock(currentBlockId);
    if (block == null) return;

    final substackKey = 'SUBSTACK${branchNum > 1 ? branchNum : ''}';
    final substack = block['inputs']?[substackKey]?['block'];

    if (substack != null) {
      thread.isLoop = isLoop;
      thread.pushStack(substack);
    }
  }

  void yield() {
    thread.status = ScratchThread.STATUS_YIELD;
  }

  void yieldTick() {
    thread.status = ScratchThread.STATUS_YIELD_TICK;
  }

  void stopAll() {
    runtime.stop();
  }

  void stopThisScript() {
    thread.status = ScratchThread.STATUS_DONE;
  }

  bool stackTimerNeedsInit() {
    return thread.stackTimerStart == null;
  }

  void startStackTimer(double duration) {
    thread.stackTimerStart = DateTime.now().millisecondsSinceEpoch.toDouble();
    thread.stackTimerDuration = duration;
  }

  bool stackTimerFinished() {
    final start = thread.stackTimerStart;
    final duration = thread.stackTimerDuration;
    if (start == null || duration == null) return true;

    final elapsed = DateTime.now().millisecondsSinceEpoch.toDouble() - start;
    return elapsed >= duration;
  }

  Map<String, dynamic>? _getBlock(String blockId) {
    final blocks = runtime.getBlocks(thread.target);
    return blocks?[blockId];
  }
}

class ScratchRuntime {
  final ProjectBank projectBank;
  final VoidCallback? onFrameUpdate;
  bool _isRunning = false;

  final List<ScratchThread> threads = [];
  final List<audioplayers.AudioPlayer> _activePlayers = [];
  final Map<String, audioplayers.AudioPlayer> _soundHandles = {};

  ScratchRuntime({
    required this.projectBank,
    this.onFrameUpdate,
  });

  bool get isRunning => _isRunning;

  Map<String, dynamic>? getBlocks(ScratchTarget? target) {
    return target?.blocks;
  }

  void stop() {
    _isRunning = false;
    threads.clear();

    for (final player in _activePlayers) {
      player.stop();
      player.dispose();
    }
    _activePlayers.clear();
    _soundHandles.clear();
  }

  Future<void> run() async {
    _isRunning = true;
    threads.clear();

    final greenFlagBlocks = <MapEntry<String, ScratchTarget>>[];

    for (final target in projectBank.targets) {
      final blocks = target.blocks;
      if (blocks == null) continue;
      for (final entry in blocks.entries) {
        final block = entry.value;
        if (block is Map && block['opcode'] == 'event_whenflagclicked') {
          greenFlagBlocks.add(MapEntry(entry.key, target));
        }
      }
    }

    final futures = greenFlagBlocks.map((entry) async {
      final thread = ScratchThread(entry.key);
      thread.target = entry.value;
      threads.add(thread);
      await _executeThread(thread);
    }).toList();

    await Future.wait(futures);

    _isRunning = false;
  }

  Future<void> _executeThread(ScratchThread thread) async {
    while (thread.status != ScratchThread.STATUS_DONE && _isRunning) {
      final currentBlockId = thread.peekStack();

      if (currentBlockId == null) {
        thread.popStack();
        if (thread.stack.isEmpty) {
          thread.status = ScratchThread.STATUS_DONE;
          break;
        }
        continue;
      }

      final block = _getBlock(thread.target, currentBlockId);
      if (block == null) {
        thread.popStack();
        continue;
      }

      final opcode = block['opcode'] as String?;
      if (opcode == null) {
        thread.popStack();
        continue;
      }

      final util = BlockUtility(thread.target!, thread, this);
      final argValues = _getArgValues(thread.target!, block);

      final reported = _executeBlock(opcode, argValues, util, thread.target!);

      if (reported is Future) {
        try {
          await reported;
        } catch (e) {
          debugPrint('Block execution error: $e');
        }
      }

      if (thread.status == ScratchThread.STATUS_YIELD ||
          thread.status == ScratchThread.STATUS_YIELD_TICK) {
        thread.status = ScratchThread.STATUS_RUNNING;
        await Future.delayed(const Duration(milliseconds: 33));
        onFrameUpdate?.call();
        continue;
      }

      if (thread.status == ScratchThread.STATUS_DONE) {
        break;
      }

      if (thread.peekStack() == currentBlockId) {
        final blocks = thread.target!.blocks;
        if (blocks == null) {
          thread.popStack();
        } else {
          final nextBlockId = thread.getNextBlock(blocks, currentBlockId);
          if (nextBlockId != null) {
            thread.pushStack(nextBlockId);
          } else {
            thread.popStack();
          }
        }
      }

      while (thread.stack.isEmpty == false && thread.peekStack() == null) {
        thread.popStack();
      }

      if (thread.stack.isEmpty) {
        thread.status = ScratchThread.STATUS_DONE;
      }
    }
  }

  Map<String, dynamic>? _getBlock(ScratchTarget? target, String blockId) {
    if (target == null) return null;
    return target.blocks?[blockId];
  }

  Map<String, dynamic> _getArgValues(ScratchTarget target, Map<String, dynamic> block) {
    final args = <String, dynamic>{};
    final inputs = block['inputs'] as Map<String, dynamic>? ?? {};
    final fields = block['fields'] as Map<String, dynamic>? ?? {};

    for (final entry in inputs.entries) {
      final inputName = entry.key;
      final inputValue = entry.value;

      if (inputValue is List && inputValue.length >= 2) {
        final inputType = inputValue[0];
        final inputData = inputValue[1];

        if (inputType == 4) {
          args[inputName] = inputData;
        } else if (inputType == 6 || inputType == 7) {
          final subBlockId = inputData;
          final subBlock = _getBlock(target, subBlockId);
          if (subBlock != null) {
            args[inputName] = _evaluateReporter(subBlock, target);
          }
        }
      }
    }

    for (final entry in fields.entries) {
      final fieldName = entry.key;
      final fieldValue = entry.value;

      if (fieldValue is List && fieldValue.isNotEmpty) {
        args[fieldName] = fieldValue[0];
      } else {
        args[fieldName] = fieldValue;
      }
    }

    return args;
  }

  dynamic _evaluateReporter(Map<String, dynamic> block, ScratchTarget target) {
    final opcode = block['opcode'] as String?;

    if (opcode == 'motion_xposition') {
      return target.x;
    } else if (opcode == 'motion_yposition') {
      return target.y;
    } else if (opcode == 'motion_direction') {
      return target.direction;
    } else if (opcode == 'looks_costume') {
      return target.currentCostume?.name ?? '';
    } else if (opcode == 'looks_size') {
      return target.size;
    } else if (opcode == 'looks_backdropname' || opcode == 'looks_backdrop') {
      return target.currentCostume?.name ?? '';
    } else if (opcode == 'sensing_answer') {
      return '';
    } else if (opcode == 'sensing_mousex') {
      return 0;
    } else if (opcode == 'sensing_mousey') {
      return 0;
    } else if (opcode == 'sensing_loudness') {
      return 0;
    } else if (opcode == 'sensing_timer') {
      return 0;
    } else if (opcode == 'sensing_current') {
      return DateTime.now().second;
    } else if (opcode == 'operator_random') {
      final from = _getArgValues(target, block)['FROM'] ?? 1;
      final to = _getArgValues(target, block)['TO'] ?? 10;
      final fromNum = _toDouble(from);
      final toNum = _toDouble(to);
      return (Random().nextDouble() * (toNum - fromNum) + fromNum).round();
    } else if (opcode == 'operator_contains') {
      final args = _getArgValues(target, block);
      final string = args['STRING']?.toString().toLowerCase() ?? '';
      final cont = args['CONTAINS']?.toString().toLowerCase() ?? '';
      return string.contains(cont);
    } else if (opcode == 'operator_join') {
      final args = _getArgValues(target, block);
      return '${args['STRING1'] ?? ''}${args['STRING2'] ?? ''}';
    } else if (opcode == 'operator_letter_of') {
      final args = _getArgValues(target, block);
      final letter = _toInt(args['LETTER'] ?? 1);
      final string = args['STRING']?.toString() ?? '';
      if (letter >= 1 && letter <= string.length) {
        return string[letter - 1];
      }
      return '';
    } else if (opcode == 'operator_length') {
      final args = _getArgValues(target, block);
      return (args['STRING']?.toString() ?? '').length;
    } else if (opcode == 'operator_mod') {
      final args = _getArgValues(target, block);
      final num1 = _toDouble(args['NUM1'] ?? 0);
      final num2 = _toDouble(args['NUM2'] ?? 1);
      return (num1 % num2).toStringAsFixed(6).replaceAll(RegExp(r'\.?0+$'), '');
    } else if (opcode == 'operator_round') {
      final args = _getArgValues(target, block);
      return _toDouble(args['NUM'] ?? 0).round();
    }

    if (opcode != null && opcode.startsWith('operator_')) {
      final args = _getArgValues(target, block);
      return _evaluateOperator(opcode, args);
    }

    return 0;
  }

  dynamic _evaluateOperator(String opcode, Map<String, dynamic> args) {
    final num1 = _toDouble(args['NUM1'] ?? 0);
    final num2 = _toDouble(args['NUM2'] ?? 0);

    switch (opcode) {
      case 'operator_add':
        return (num1 + num2).toStringAsFixed(6).replaceAll(RegExp(r'\.?0+$'), '');
      case 'operator_subtract':
        return (num1 - num2).toStringAsFixed(6).replaceAll(RegExp(r'\.?0+$'), '');
      case 'operator_multiply':
        return (num1 * num2).toStringAsFixed(6).replaceAll(RegExp(r'\.?0+$'), '');
      case 'operator_divide':
        if (num2 == 0) return 'Infinity';
        return (num1 / num2).toStringAsFixed(6).replaceAll(RegExp(r'\.?0+$'), '');
      case 'operator_gt':
        return num1 > num2;
      case 'operator_lt':
        return num1 < num2;
      case 'operator_equals':
        return num1 == num2;
      case 'operator_and':
        return _toBool(num1) && _toBool(num2);
      case 'operator_or':
        return _toBool(num1) || _toBool(num2);
      case 'operator_not':
        return !_toBool(args['OPERAND'] ?? false);
      case 'operator_join':
        return '${args['STRING1'] ?? ''}${args['STRING2'] ?? ''}';
      default:
        return 0;
    }
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
      return double.tryParse(value) != 0;
    }
    return false;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  dynamic _executeBlock(String opcode, Map<String, dynamic> args, BlockUtility util, ScratchTarget target) {
    switch (opcode) {
      case 'motion_movesteps':
        return _motionMoveSteps(args, target);
      case 'motion_turnright':
        return _motionTurnRight(args, target);
      case 'motion_turnleft':
        return _motionTurnLeft(args, target);
      case 'motion_goto':
        return _motionGoTo(args, target);
      case 'motion_gotoxy':
        return _motionGoToXY(args, target);
      case 'motion_changexby':
        return _motionChangeXBy(args, target);
      case 'motion_changeyby':
        return _motionChangeYBy(args, target);
      case 'motion_setx':
        return _motionSetX(args, target);
      case 'motion_sety':
        return _motionSetY(args, target);
      case 'motion_setrotationstyle':
        return _motionSetRotationStyle(args, target);
      case 'motion_pointindirection':
        return _motionPointInDirection(args, target);
      case 'motion_pointtowards':
        return _motionPointTowards(args, target, this);
      case 'looks_say':
        return _looksSay(args, target);
      case 'looks_sayforsecs':
        return _looksSayForSecs(args, target, util);
      case 'looks_switchcostumeto':
        return _looksSwitchCostumeTo(args, target);
      case 'looks_switchbackdropto':
        return _looksSwitchBackdropTo(args, target);
      case 'looks_changeeffectby':
        return _looksChangeEffectBy(args, target);
      case 'looks_seteffectto':
        return _looksSetEffectTo(args, target);
      case 'looks_changesizeby':
        return _looksChangeSizeBy(args, target);
      case 'looks_setsizeto':
        return _looksSetSizeTo(args, target);
      case 'looks_show':
        return _looksShow(target);
      case 'looks_hide':
        return _looksHide(target);
      case 'looks_gotofrontback':
        return _looksGoToFrontBack(args, target);
      case 'looks_goforwardbackwardlayers':
        return _looksGoForwardBackwardLayers(args, target);
      case 'control_wait':
        return _controlWait(args, util);
      case 'control_repeat':
        return _controlRepeat(args, util);
      case 'control_forever':
        return _controlForever(args, util);
      case 'control_if':
        return _controlIf(args, util);
      case 'control_if_else':
        return _controlIfElse(args, util);
      case 'control_wait_until':
        return _controlWaitUntil(args, util);
      case 'control_stop':
        return _controlStop(args, util);
      case 'sound_play':
        return _soundPlay(args, target);
      case 'sound_playuntildone':
        return _soundPlayUntilDone(args, target);
      case 'sound_stopallsounds':
        return _soundStopAllSounds();
      case 'sound_changevolumeby':
        return _soundChangeVolumeBy(args, target);
      case 'sound_setvolumeto':
        return _soundSetVolumeTo(args, target);
      case 'pen_clear':
        return _penClear(target);
      case 'pen_stamp':
        return _penStamp(target);
      case 'event_whenflagclicked':
        return true;
      case 'event_whenkeypressed':
        return true;
      case 'event_whenthisspriteclicked':
        return true;
      case 'event_whenbackdropswitchesto':
        return true;
      case 'event_whenbroadcastreceived':
        return true;
      case 'event_broadcast':
        return _eventBroadcast(args, target, this);
      case 'event_broadcastandwait':
        return _eventBroadcastAndWait(args, target, this, util);
      default:
        return null;
    }
  }

  dynamic _motionMoveSteps(Map<String, dynamic> args, ScratchTarget target) {
    final steps = _toDouble(args['STEPS'] ?? 0);
    final radians = (90 - target.direction) * pi / 180;
    final dx = steps * cos(radians);
    final dy = steps * sin(radians);
    target.x = target.x + dx;
    target.y = target.y + dy;
    onFrameUpdate?.call();
    return null;
  }

  dynamic _motionTurnRight(Map<String, dynamic> args, ScratchTarget target) {
    final degrees = _toDouble(args['DEGREES'] ?? 0);
    target.direction = target.direction + degrees;
    onFrameUpdate?.call();
    return null;
  }

  dynamic _motionTurnLeft(Map<String, dynamic> args, ScratchTarget target) {
    final degrees = _toDouble(args['DEGREES'] ?? 0);
    target.direction = target.direction - degrees;
    onFrameUpdate?.call();
    return null;
  }

  dynamic _motionGoTo(Map<String, dynamic> args, ScratchTarget target) {
    final targetName = args['TO']?.toString() ?? '';
    if (targetName == '_random_') {
      target.x = Random().nextDouble() * 480 - 240;
      target.y = Random().nextDouble() * 360 - 180;
    } else if (targetName == '_mouse_') {
      target.x = 0;
      target.y = 0;
    } else if (targetName == '_random_') {
      target.x = Random().nextDouble() * 480 - 240;
      target.y = Random().nextDouble() * 360 - 180;
    }
    onFrameUpdate?.call();
    return null;
  }

  dynamic _motionGoToXY(Map<String, dynamic> args, ScratchTarget target) {
    target.x = _toDouble(args['X'] ?? 0);
    target.y = _toDouble(args['Y'] ?? 0);
    onFrameUpdate?.call();
    return null;
  }

  dynamic _motionChangeXBy(Map<String, dynamic> args, ScratchTarget target) {
    target.x = target.x + _toDouble(args['DX'] ?? 0);
    onFrameUpdate?.call();
    return null;
  }

  dynamic _motionChangeYBy(Map<String, dynamic> args, ScratchTarget target) {
    target.y = target.y + _toDouble(args['DY'] ?? 0);
    onFrameUpdate?.call();
    return null;
  }

  dynamic _motionSetX(Map<String, dynamic> args, ScratchTarget target) {
    target.x = _toDouble(args['X'] ?? 0);
    onFrameUpdate?.call();
    return null;
  }

  dynamic _motionSetY(Map<String, dynamic> args, ScratchTarget target) {
    target.y = _toDouble(args['Y'] ?? 0);
    onFrameUpdate?.call();
    return null;
  }

  dynamic _motionSetRotationStyle(Map<String, dynamic> args, ScratchTarget target) {
    target.rotationStyle = args['STYLE']?.toString() ?? 'normal';
    return null;
  }

  dynamic _motionPointInDirection(Map<String, dynamic> args, ScratchTarget target) {
    target.direction = _toDouble(args['DIRECTION'] ?? 90);
    onFrameUpdate?.call();
    return null;
  }

  dynamic _motionPointTowards(Map<String, dynamic> args, ScratchTarget target, ScratchRuntime runtime) {
    final towards = args['TOWARDS']?.toString() ?? '';
    double dx = 0;
    double dy = 0;

    for (final t in runtime.projectBank.targets) {
      if (t.name == towards) {
        dx = t.x - target.x;
        dy = t.y - target.y;
        break;
      }
    }

    if (dx == 0 && dy == 0) {
      target.direction = 90;
    } else {
      target.direction = atan2(dy, dx) * 180 / pi + 90;
    }
    onFrameUpdate?.call();
    return null;
  }

  dynamic _looksSay(Map<String, dynamic> args, ScratchTarget target) {
    target.say = args['MESSAGE']?.toString() ?? '';
    return null;
  }

  dynamic _looksSayForSecs(Map<String, dynamic> args, ScratchTarget target, BlockUtility util) {
    target.say = args['MESSAGE']?.toString() ?? '';

    if (util.stackTimerNeedsInit()) {
      final duration = math.max(0.0, 1000 * _toDouble(args['SECS'] ?? 1));
      util.startStackTimer(duration);
      util.yield();
    } else if (!util.stackTimerFinished()) {
      util.yield();
    }
    return null;
  }

  dynamic _looksSwitchCostumeTo(Map<String, dynamic> args, ScratchTarget target) {
    final costumeName = args['COSTUME']?.toString() ?? '';
    for (final costume in target.costumes) {
      if (costume.name == costumeName) {
        target.currentCostumeIndex = target.costumes.indexOf(costume);
        break;
      }
    }
    onFrameUpdate?.call();
    return null;
  }

  dynamic _looksSwitchBackdropTo(Map<String, dynamic> args, ScratchTarget target) {
    final backdropName = args['BACKDROP']?.toString() ?? '';
    for (final costume in target.costumes) {
      if (costume.name == backdropName) {
        target.currentCostumeIndex = target.costumes.indexOf(costume);
        break;
      }
    }
    onFrameUpdate?.call();
    return null;
  }

  dynamic _looksChangeEffectBy(Map<String, dynamic> args, ScratchTarget target) {
    final effect = args['EFFECT']?.toString().toLowerCase() ?? '';
    final value = _toDouble(args['CHANGE'] ?? 0);

    switch (effect) {
      case 'color':
        target.effects['color'] = (target.effects['color'] ?? 0) + value;
        break;
      case 'fisheye':
        target.effects['fisheye'] = (target.effects['fisheye'] ?? 0) + value;
        break;
      case 'whirl':
        target.effects['whirl'] = (target.effects['whirl'] ?? 0) + value;
        break;
      case 'pixelate':
        target.effects['pixelate'] = (target.effects['pixelate'] ?? 0) + value;
        break;
      case 'mosaic':
        target.effects['mosaic'] = (target.effects['mosaic'] ?? 0) + value;
        break;
      case 'brightness':
        target.effects['brightness'] = (target.effects['brightness'] ?? 0) + value;
        break;
      case 'ghost':
        target.effects['ghost'] = (target.effects['ghost'] ?? 0) + value;
        break;
    }
    onFrameUpdate?.call();
    return null;
  }

  dynamic _looksSetEffectTo(Map<String, dynamic> args, ScratchTarget target) {
    final effect = args['EFFECT']?.toString().toLowerCase() ?? '';
    final value = _toDouble(args['VALUE'] ?? 0);

    switch (effect) {
      case 'color':
        target.effects['color'] = value;
        break;
      case 'fisheye':
        target.effects['fisheye'] = value;
        break;
      case 'whirl':
        target.effects['whirl'] = value;
        break;
      case 'pixelate':
        target.effects['pixelate'] = value;
        break;
      case 'mosaic':
        target.effects['mosaic'] = value;
        break;
      case 'brightness':
        target.effects['brightness'] = value;
        break;
      case 'ghost':
        target.effects['ghost'] = value;
        break;
    }
    onFrameUpdate?.call();
    return null;
  }

  dynamic _looksChangeSizeBy(Map<String, dynamic> args, ScratchTarget target) {
    target.size = target.size + _toDouble(args['CHANGE'] ?? 0);
    onFrameUpdate?.call();
    return null;
  }

  dynamic _looksSetSizeTo(Map<String, dynamic> args, ScratchTarget target) {
    target.size = _toDouble(args['SIZE'] ?? 100);
    onFrameUpdate?.call();
    return null;
  }

  dynamic _looksShow(ScratchTarget target) {
    target.visible = true;
    onFrameUpdate?.call();
    return null;
  }

  dynamic _looksHide(ScratchTarget target) {
    target.visible = false;
    onFrameUpdate?.call();
    return null;
  }

  dynamic _looksGoToFrontBack(Map<String, dynamic> args, ScratchTarget target) {
    final frontBack = args['FRONT_BACK']?.toString() ?? '';
    if (frontBack == 'front') {
      target.layerOrder = 9999;
    } else {
      target.layerOrder = 0;
    }
    onFrameUpdate?.call();
    return null;
  }

  dynamic _looksGoForwardBackwardLayers(Map<String, dynamic> args, ScratchTarget target) {
    final forwardBackward = args['FORWARD_BACKWARD']?.toString() ?? '';
    final num = _toInt(args['NUM'] ?? 1);
    if (forwardBackward == 'forward') {
      target.layerOrder = target.layerOrder + num;
    } else {
      target.layerOrder = max(0, target.layerOrder - num);
    }
    onFrameUpdate?.call();
    return null;
  }

  dynamic _controlWait(Map<String, dynamic> args, BlockUtility util) {
    if (util.stackTimerNeedsInit()) {
      final duration = math.max(0.0, 1000 * _toDouble(args['DURATION'] ?? 1));
      util.startStackTimer(duration);
      util.yield();
    } else if (!util.stackTimerFinished()) {
      util.yield();
    }
    return null;
  }

  dynamic _controlRepeat(Map<String, dynamic> args, BlockUtility util) {
    final times = _toInt(args['TIMES'] ?? 10);

    if (util.thread.loopCounter == null) {
      util.thread.loopCounter = times;
    }

    util.thread.loopCounter = (util.thread.loopCounter as int) - 1;

    if (util.thread.loopCounter >= 0) {
      util.startBranch(1, true);
    } else {
      util.thread.loopCounter = null;
    }
    return null;
  }

  dynamic _controlForever(Map<String, dynamic> args, BlockUtility util) {
    util.startBranch(1, true);
    return null;
  }

  dynamic _controlIf(Map<String, dynamic> args, BlockUtility util) {
    final condition = args['CONDITION'] ?? false;
    if (_toBool(condition)) {
      util.startBranch(1, false);
    }
    return null;
  }

  dynamic _controlIfElse(Map<String, dynamic> args, BlockUtility util) {
    final condition = args['CONDITION'] ?? false;
    if (_toBool(condition)) {
      util.startBranch(1, false);
    } else {
      util.startBranch(2, false);
    }
    return null;
  }

  dynamic _controlWaitUntil(Map<String, dynamic> args, BlockUtility util) {
    final condition = args['CONDITION'] ?? false;
    if (!_toBool(condition)) {
      util.yield();
    }
    return null;
  }

  dynamic _controlStop(Map<String, dynamic> args, BlockUtility util) {
    final stopOption = args['STOP_OPTION']?.toString() ?? 'all';
    switch (stopOption) {
      case 'all':
        util.stopAll();
        break;
      case 'this script':
        util.stopThisScript();
        break;
      case 'other scripts in sprite':
        break;
    }
    return null;
  }

  dynamic _soundPlay(Map<String, dynamic> args, ScratchTarget target) async {
    final soundName = args['SOUND_MENU']?.toString() ?? '';
    final sound = _findSound(target, soundName);
    if (sound == null) return null;

    final player = audioplayers.AudioPlayer();
    _activePlayers.add(player);

    try {
      final source = audioplayers.BytesSource(sound.data);
      await player.play(source, volume: target.volume.toDouble());
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }

    player.onPlayerComplete.listen((_) {
      player.dispose();
      _activePlayers.remove(player);
    });

    return null;
  }

  dynamic _soundPlayUntilDone(Map<String, dynamic> args, ScratchTarget target) async {
    final soundName = args['SOUND_MENU']?.toString() ?? '';
    final sound = _findSound(target, soundName);
    if (sound == null) return null;

    final player = audioplayers.AudioPlayer();
    _activePlayers.add(player);

    try {
      final source = audioplayers.BytesSource(sound.data);
      await player.play(source, volume: target.volume.toDouble());
      await player.onPlayerComplete.first;
    } catch (e) {
      debugPrint('Error playing sound until done: $e');
    } finally {
      await player.dispose();
      _activePlayers.remove(player);
    }

    return null;
  }

  dynamic _soundStopAllSounds() {
    for (final player in _activePlayers) {
      player.stop();
      player.dispose();
    }
    _activePlayers.clear();
    _soundHandles.clear();
    return null;
  }

  dynamic _soundChangeVolumeBy(Map<String, dynamic> args, ScratchTarget target) {
    target.volume = target.volume + _toInt(args['VOLUME'] ?? 0);
    for (final player in _activePlayers) {
      player.setVolume(target.volume.toDouble());
    }
    return null;
  }

  dynamic _soundSetVolumeTo(Map<String, dynamic> args, ScratchTarget target) {
    target.volume = _toInt(args['VOLUME'] ?? 100);
    for (final player in _activePlayers) {
      player.setVolume(target.volume.toDouble());
    }
    return null;
  }

  ScratchSound? _findSound(ScratchTarget target, String soundName) {
    for (final sound in target.sounds) {
      if (sound.name == soundName) {
        return sound;
      }
    }
    return null;
  }

  dynamic _penClear(ScratchTarget target) {
    target.penStrokes.clear();
    onFrameUpdate?.call();
    return null;
  }

  dynamic _penStamp(ScratchTarget target) {
    target.penStrokes.add({
      'x': target.x,
      'y': target.y,
      'costume': target.currentCostumeIndex,
      'direction': target.direction,
      'size': target.size,
    });
    onFrameUpdate?.call();
    return null;
  }

  dynamic _eventBroadcast(Map<String, dynamic> args, ScratchTarget target, ScratchRuntime runtime) {
    final broadcastName = args['BROADCAST_INPUT']?.toString() ?? '';
    for (final t in runtime.projectBank.targets) {
      final blocks = t.blocks;
      if (blocks == null) continue;
      for (final entry in blocks.entries) {
        final block = entry.value;
        if (block is Map && block['opcode'] == 'event_whenbroadcastreceived') {
          final receivedBroadcast = block['fields']?['BROADCAST_OPTION']?[0];
          if (receivedBroadcast?.toString() == broadcastName) {
            final thread = ScratchThread(entry.key);
            thread.target = t;
            runtime.threads.add(thread);
          }
        }
      }
    }
    return null;
  }

  dynamic _eventBroadcastAndWait(Map<String, dynamic> args, ScratchTarget target, ScratchRuntime runtime, BlockUtility util) {
    _eventBroadcast(args, target, runtime);
    util.yield();
    return null;
  }
}

class ScratchSound {
  final String name;
  final Uint8List data;
  final String format;
  final int? rate;
  final int? sampleCount;

  ScratchSound({
    required this.name,
    required this.data,
    this.format = 'wav',
    this.rate,
    this.sampleCount,
  });
}

class ScratchTarget {
  final String name;
  final bool isStage;
  final Map<String, dynamic>? blocks;
  List<ScratchCostume> costumes = [];
  List<ScratchSound> sounds = [];
  int currentCostumeIndex = 0;
  double x = 0;
  double y = 0;
  double direction = 90;
  double size = 100;
  bool visible = true;
  String rotationStyle = 'normal';
  int layerOrder = 0;
  int volume = 100;
  String say = '';
  final Map<String, double> effects = {};
  final List<Map<String, dynamic>> penStrokes = [];

  ScratchTarget({
    required this.name,
    required this.isStage,
    this.blocks,
  });

  ScratchCostume? get currentCostume {
    if (costumes.isEmpty || currentCostumeIndex < 0 || currentCostumeIndex >= costumes.length) {
      return null;
    }
    return costumes[currentCostumeIndex];
  }
}

class ScratchCostume {
  final String name;
  final String? dataBase64;
  final int? bitmapResolution;
  final double? rotationCenterX;
  final double? rotationCenterY;
  Uint8List? imageData;

  ScratchCostume({
    required this.name,
    this.dataBase64,
    this.bitmapResolution,
    this.rotationCenterX,
    this.rotationCenterY,
  });
}

class ProjectBank {
  final List<ScratchTarget> targets = [];
  Map<String, dynamic>? info;
}
