import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_math/vector_math_64.dart' as vector_math;
import 'main.dart';

class StageLayering {
  static const int backgroundLayer = 0;
  static const int videoLayer = 1;
  static const int penLayer = 2;
  static const int spriteLayer = 3;
}

class StageRenderer {
  static const double stageWidth = 480.0;
  static const double stageHeight = 360.0;
  static const double stageCenterX = stageWidth / 2;
  static const double stageCenterY = stageHeight / 2;

  final Map<String, Drawable> _drawables = {};
  final List<int> _layerOrder = [
    StageLayering.backgroundLayer,
    StageLayering.videoLayer,
    StageLayering.penLayer,
    StageLayering.spriteLayer,
  ];

  String createDrawable(int layerGroup) {
    final String drawableId = UniqueKey().toString();
    _drawables[drawableId] = Drawable(
      id: drawableId,
      layerGroup: layerGroup,
      x: 0.0,
      y: 0.0,
      direction: 90.0,
      scale: [1.0, 1.0],
      visible: true,
      skinId: '',
      effects: {},
      order: 0,
    );
    return drawableId;
  }

  void updateDrawablePosition(String drawableId, List<double> position) {
    final drawable = _drawables[drawableId];
    if (drawable != null) {
      final fenced = getFencedPositionOfDrawable(drawableId, position);
      drawable.x = fenced[0];
      drawable.y = fenced[1];
    }
  }

  void updateDrawableDirectionScale(String drawableId, double direction, List<double> scale) {
    final drawable = _drawables[drawableId];
    if (drawable != null) {
      drawable.direction = direction;
      drawable.scale = scale;
    }
  }

  void updateDrawableVisible(String drawableId, bool visible) {
    final drawable = _drawables[drawableId];
    if (drawable != null) {
      drawable.visible = visible;
    }
  }

  void updateDrawableSkinId(String drawableId, String skinId) {
    final drawable = _drawables[drawableId];
    if (drawable != null) {
      drawable.skinId = skinId;
    }
  }

  void updateDrawableEffect(String drawableId, String effectName, double value) {
    final drawable = _drawables[drawableId];
    if (drawable != null) {
      drawable.effects[effectName] = value;
    }
  }

  void setDrawableOrder(String drawableId, double order, int layerGroup, [bool relative = true]) {
    final drawable = _drawables[drawableId];
    if (drawable != null) {
      if (relative) {
        drawable.order += order;
      } else {
        drawable.order = order;
      }
      drawable.layerGroup = layerGroup;
    }
  }

  List<double> getFencedPositionOfDrawable(String drawableId, List<double> position) {
    final drawable = _drawables[drawableId];
    if (drawable == null) return position;

    final double x = position[0];
    final double y = position[1];

    final double minX = -stageWidth / 2;
    final double maxX = stageWidth / 2;
    final double minY = -stageHeight / 2;
    final double maxY = stageHeight / 2;

    return [
      math.max(minX, math.min(maxX, x)),
      math.max(minY, math.min(maxY, y)),
    ];
  }

  List<double> getCurrentSkinSize(String drawableId) {
    return [100.0, 100.0];
  }

  void disposeDrawable(String drawableId) {
    _drawables.remove(drawableId);
  }

  Widget buildStage(ProjectBank? projectBank) {
    return Container(
      width: stageWidth,
      height: stageHeight,
      color: const Color(0xFF87CEEB),
      child: Stack(
        children: _buildLayers(projectBank),
      ),
    );
  }

  List<Widget> _buildLayers(ProjectBank? projectBank) {
    final List<Widget> layers = [];

    for (final layerGroup in _layerOrder) {
      final layerWidgets = _buildLayer(layerGroup, projectBank);
      layers.addAll(layerWidgets);
    }

    return layers;
  }

  List<Widget> _buildLayer(int layerGroup, ProjectBank? projectBank) {
    final List<Widget> widgets = [];
    final List<Drawable> layerDrawables = _drawables.values
        .where((d) => d.layerGroup == layerGroup && d.visible)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    for (final drawable in layerDrawables) {
      final widget = _buildDrawable(drawable, projectBank);
      if (widget != null) {
        widgets.add(widget);
      }
    }

    if (layerGroup == StageLayering.spriteLayer && projectBank != null) {
      for (final target in projectBank.targets) {
        if (!target.isStage) {
          final targetWidget = _buildSpriteTarget(target);
          if (targetWidget != null) {
            widgets.add(targetWidget);
          }
        }
      }
    }

    if (layerGroup == StageLayering.backgroundLayer && projectBank != null) {
      final stage = projectBank.targets.firstWhere((t) => t.isStage, orElse: () => ScratchTarget.empty());
      final backgroundWidget = _buildBackground(stage);
      if (backgroundWidget != null) {
        widgets.insert(0, backgroundWidget);
      }
    }

    return widgets;
  }

  Widget? _buildDrawable(Drawable drawable, ProjectBank? projectBank) {
    return _buildSprite(drawable.x, drawable.y, drawable.direction, drawable.scale, drawable.skinId, projectBank);
  }

  Widget? _buildSpriteTarget(ScratchTarget target) {
    if (!target.isVisible) return null;

    final scale = target.size / 100.0;
    double effectiveDirection = target.direction;
    double effectiveScaleX = scale;

    switch (target.rotationStyle) {
      case "don't rotate":
        effectiveDirection = 90.0;
        break;
      case 'left-right':
        effectiveDirection = 90.0;
        effectiveScaleX = (target.direction < 0) ? -scale : scale;
        break;
    }

    return _buildSprite(
      target.x,
      target.y,
      effectiveDirection,
      [effectiveScaleX, scale],
      target.currentCostume.toString(),
      null,
      target: target,
    );
  }

  Widget? _buildSprite(
    double x,
    double y,
    double direction,
    List<double> scale,
    String skinId,
    ProjectBank? projectBank, {
    ScratchTarget? target,
  }) {
    final screenX = x + stageCenterX;
    final screenY = -y + stageCenterY;

    Widget? content;

    if (target != null && target.costumes.isNotEmpty && target.currentCostume < target.costumes.length) {
      final costume = target.costumes[target.currentCostume];
      content = _buildCostume(costume);
    }

    content ??= Container(
      width: 50 * scale[0].abs(),
      height: 50 * scale[1].abs(),
      color: Colors.blue,
    );

    return Positioned(
      left: screenX - (content.key != null ? 0 : 25 * scale[0].abs()),
      top: screenY - (content.key != null ? 0 : 25 * scale[1].abs()),
      child: Transform(
        transform: Matrix4.identity()
          ..translateByDouble(
            (content.key != null ? 0 : 25 * scale[0].abs()),
            (content.key != null ? 0 : 25 * scale[1].abs()),
            0,
            1,
          )
          ..rotateZ(math.pi - direction * math.pi / 180)
          ..scaleByVector3(vector_math.Vector3(scale[0], scale[1], 1)),
        origin: Offset(
          content.key != null ? 0 : 25 * scale[0].abs(),
          content.key != null ? 0 : 25 * scale[1].abs(),
        ),
        child: content,
      ),
    );
  }

  Widget? _buildCostume(ScratchCostume costume) {
    if (costume.data.isEmpty) return null;

    if (costume.dataFormat == 'svg') {
      try {
        return SvgPicture.memory(
          costume.data,
          fit: BoxFit.contain,
          width: costume.bitmapResolution * 100,
          height: costume.bitmapResolution * 100,
        );
      } catch (e) {
        return null;
      }
    } else if (costume.dataFormat == 'png' || costume.dataFormat == 'jpg') {
      return Image.memory(
        costume.data,
        fit: BoxFit.contain,
        width: costume.bitmapResolution * 100,
        height: costume.bitmapResolution * 100,
      );
    }

    return null;
  }

  Widget? _buildBackground(ScratchTarget stage) {
    if (stage.costumes.isEmpty) return null;

    final currentCostume = stage.currentCostume;
    if (currentCostume < 0 || currentCostume >= stage.costumes.length) return null;

    final costume = stage.costumes[currentCostume];
    return _buildCostume(costume);
  }

  void requestRedraw() {}

  Map<String, Drawable> get drawables => _drawables;
}

class Drawable {
  final String id;
  int layerGroup;
  double x;
  double y;
  double direction;
  List<double> scale;
  bool visible;
  String skinId;
  Map<String, double> effects;
  double order;

  Drawable({
    required this.id,
    required this.layerGroup,
    required this.x,
    required this.y,
    required this.direction,
    required this.scale,
    required this.visible,
    required this.skinId,
    required this.effects,
    required this.order,
  });
}

extension RenderedTarget on ScratchTarget {
  void initDrawable(StageRenderer renderer, int layerGroup) {
    drawableId = renderer.createDrawable(layerGroup);
    updateAllDrawableProperties(renderer);

    if (!isOriginal) {
    }
  }

  void updateAllDrawableProperties(StageRenderer renderer) {
    if (drawableId == null) return;

    final rendered = _getRenderedDirectionAndScale();

    renderer.updateDrawablePosition(drawableId!, [x, y]);
    renderer.updateDrawableDirectionScale(drawableId!, rendered['direction'] as double, rendered['scale'] as List<double>);
    renderer.updateDrawableVisible(drawableId!, isVisible);

    if (costumes.isNotEmpty && currentCostume < costumes.length) {
      renderer.updateDrawableSkinId(drawableId!, costumes[currentCostume].md5ext);
    }

    for (final effectName in effects.keys) {
      renderer.updateDrawableEffect(drawableId!, effectName, effects[effectName] ?? 0);
    }
  }

  Map<String, dynamic> _getRenderedDirectionAndScale() {
    double finalDirection = direction;
    double finalScaleX = size / 100.0;
    double finalScaleY = size / 100.0;

    switch (rotationStyle) {
      case "don't rotate":
        finalDirection = 90.0;
        break;
      case 'left-right':
        finalDirection = 90.0;
        finalScaleX = (direction < 0) ? -size / 100.0 : size / 100.0;
        break;
    }

    return {
      'direction': finalDirection,
      'scale': <double>[finalScaleX, finalScaleY],
    };
  }

  void setXY(double newX, double newY, StageRenderer renderer, {bool force = false}) {
    if (isStage) return;

    final position = renderer.getFencedPositionOfDrawable(drawableId ?? '', [newX, newY]);
    x = position[0];
    y = position[1];

    renderer.updateDrawablePosition(drawableId ?? '', position);
    renderer.requestRedraw();
  }

  void goToFront(StageRenderer renderer) {
    if (drawableId != null) {
      renderer.setDrawableOrder(drawableId!, double.infinity, StageLayering.spriteLayer);
    }
  }

  void goToBack(StageRenderer renderer) {
    if (drawableId != null) {
      renderer.setDrawableOrder(drawableId!, double.negativeInfinity, StageLayering.spriteLayer, false);
    }
  }

  void goForwardLayers(StageRenderer renderer, int nLayers) {
    if (drawableId != null) {
      renderer.setDrawableOrder(drawableId!, nLayers.toDouble(), StageLayering.spriteLayer, true);
    }
  }

  void goBackwardLayers(StageRenderer renderer, int nLayers) {
    if (drawableId != null) {
      renderer.setDrawableOrder(drawableId!, -nLayers.toDouble(), StageLayering.spriteLayer, true);
    }
  }
}