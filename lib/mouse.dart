import 'dart:math' as math;

class Mouse {
  double _clientX = 0;
  double _clientY = 0;
  double _scratchX = 0;
  double _scratchY = 0;
  bool _isDown = false;

  double get clientX => _clientX;
  double get clientY => _clientY;
  double get scratchX => _scratchX;
  double get scratchY => _scratchY;
  bool get isDown => _isDown;

  void postData(Map<String, dynamic> data) {
    if (data.containsKey('x')) {
      _clientX = _toDouble(data['x']);
      final canvasWidth = _toDouble(data['canvasWidth'] ?? 480);
      _scratchX = _toScratchX(_clientX, canvasWidth);
    }

    if (data.containsKey('y')) {
      _clientY = _toDouble(data['y']);
      final canvasHeight = _toDouble(data['canvasHeight'] ?? 360);
      _scratchY = _toScratchY(_clientY, canvasHeight);
    }

    if (data.containsKey('isDown')) {
      _isDown = data['isDown'] as bool;
    }
  }

  double _toScratchX(double clientX, double canvasWidth) {
    final value = 480 * ((clientX / canvasWidth) - 0.5);
    return _clamp(value, -240, 240);
  }

  double _toScratchY(double clientY, double canvasHeight) {
    final value = -360 * ((clientY / canvasHeight) - 0.5);
    return _clamp(value, -180, 180);
  }

  double _clamp(double value, double min, double max) {
    return math.max(min, math.min(max, value));
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0.0;
  }

  dynamic ioQuery(String query) {
    switch (query) {
      case 'getScratchX':
        return _scratchX;
      case 'getScratchY':
        return _scratchY;
      case 'getIsDown':
        return _isDown;
      case 'getClientX':
        return _clientX;
      case 'getClientY':
        return _clientY;
      default:
        return null;
    }
  }
}