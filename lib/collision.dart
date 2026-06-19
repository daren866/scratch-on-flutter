import 'dart:math' as math;

import 'models.dart';

class BoundingBox {
  double left;
  double right;
  double top;
  double bottom;

  BoundingBox({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
  });

  factory BoundingBox.fromBounds(
    double minX,
    double maxX,
    double minY,
    double maxY,
  ) {
    return BoundingBox(
      left: minX,
      right: maxX,
      top: maxY,
      bottom: minY,
    );
  }

  factory BoundingBox.fromPoints(List<math.Point<double>> points) {
    if (points.isEmpty) {
      return BoundingBox(left: 0, right: 0, top: 0, bottom: 0);
    }

    double minX = points.first.x;
    double maxX = points.first.x;
    double minY = points.first.y;
    double maxY = points.first.y;

    for (final point in points) {
      if (point.x < minX) minX = point.x;
      if (point.x > maxX) maxX = point.x;
      if (point.y < minY) minY = point.y;
      if (point.y > maxY) maxY = point.y;
    }

    return BoundingBox.fromBounds(minX, maxX, minY, maxY);
  }

  factory BoundingBox.fromTarget(ScratchTarget target) {
    final sizeScale = target.size / 100;
    final width = 48 * sizeScale;
    final height = 48 * sizeScale;

    return BoundingBox(
      left: target.x - width / 2,
      right: target.x + width / 2,
      top: target.y + height / 2,
      bottom: target.y - height / 2,
    );
  }

  bool intersects(BoundingBox other) {
    return left <= other.right &&
        right >= other.left &&
        top >= other.bottom &&
        bottom <= other.top;
  }

  bool containsPoint(double x, double y) {
    return x >= left && x <= right && y >= bottom && y <= top;
  }

  BoundingBox? get intersection(BoundingBox other) {
    if (!intersects(other)) {
      return null;
    }

    return BoundingBox(
      left: math.max(left, other.left),
      right: math.min(right, other.right),
      top: math.min(top, other.top),
      bottom: math.max(bottom, other.bottom),
    );
  }

  double get width => right - left;

  double get height => top - bottom;

  @override
  String toString() {
    return 'BoundingBox(left: $left, right: $right, top: $top, bottom: $bottom)';
  }
}

class CollisionDetector {
  final ProjectBank projectBank;

  CollisionDetector(this.projectBank);

  bool isTouchingSprite(ScratchTarget target, String spriteName) {
    if (!target.isVisible || target.isStage) {
      return false;
    }

    final otherTarget = projectBank.targets.firstWhere(
      (t) => !t.isStage && t.name == spriteName,
      orElse: () => target,
    );

    if (otherTarget == target || !otherTarget.isVisible) {
      return false;
    }

    return _checkSpriteCollision(target, otherTarget);
  }

  bool isTouchingPoint(ScratchTarget target, double x, double y) {
    if (!target.isVisible || target.isStage) {
      return false;
    }

    return _checkPointCollision(target, x, y);
  }

  bool isTouchingMouse(ScratchTarget target, double mouseX, double mouseY) {
    return isTouchingPoint(target, mouseX, mouseY);
  }

  bool isTouchingEdge(ScratchTarget target) {
    if (!target.isVisible || target.isStage) {
      return false;
    }

    return _checkEdgeCollision(target);
  }

  bool isTouchingColor(ScratchTarget target, int color) {
    if (!target.isVisible || target.isStage) {
      return false;
    }
    return false;
  }

  double distanceTo(ScratchTarget target, String spriteName) {
    if (target.isStage) {
      return 0;
    }

    final otherTarget = projectBank.targets.firstWhere(
      (t) => !t.isStage && t.name == spriteName,
      orElse: () => target,
    );

    if (otherTarget == target) {
      return 0;
    }

    final dx = otherTarget.x - target.x;
    final dy = otherTarget.y - target.y;

    return math.sqrt(dx * dx + dy * dy);
  }

  double distanceToPoint(ScratchTarget target, double x, double y) {
    if (target.isStage) {
      return 0;
    }

    final dx = x - target.x;
    final dy = y - target.y;

    return math.sqrt(dx * dx + dy * dy);
  }

  List<String> getTouchingSprites(ScratchTarget target) {
    if (!target.isVisible || target.isStage) {
      return [];
    }

    final touching = <String>[];

    for (final other in projectBank.targets) {
      if (other.isStage || !other.isVisible || other == target) {
        continue;
      }

      if (_checkSpriteCollision(target, other)) {
        touching.add(other.name);
      }
    }

    return touching;
  }

  bool _checkSpriteCollision(ScratchTarget target, ScratchTarget other) {
    final targetBox = BoundingBox.fromTarget(target);
    final otherBox = BoundingBox.fromTarget(other);

    return targetBox.intersects(otherBox);
  }

  bool _checkPointCollision(ScratchTarget target, double x, double y) {
    final box = BoundingBox.fromTarget(target);
    return box.containsPoint(x, y);
  }

  bool _checkEdgeCollision(ScratchTarget target) {
    const stageWidth = 480.0;
    const stageHeight = 360.0;
    const halfWidth = stageWidth / 2;
    const halfHeight = stageHeight / 2;

    final box = BoundingBox.fromTarget(target);

    return box.left <= -halfWidth ||
        box.right >= halfWidth ||
        box.bottom <= -halfHeight ||
        box.top >= halfHeight;
  }

  List<ScratchTarget> findCollisions(ScratchTarget target) {
    if (!target.isVisible || target.isStage) {
      return [];
    }

    final collisions = <ScratchTarget>[];

    for (final other in projectBank.targets) {
      if (other.isStage || !other.isVisible || other == target) {
        continue;
      }

      if (_checkSpriteCollision(target, other)) {
        collisions.add(other);
      }
    }

    return collisions;
  }
}