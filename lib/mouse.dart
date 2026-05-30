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
    print('Mouse.postData 收到数据: $data');
    
    if (data.containsKey('x')) {
      _clientX = _toDouble(data['x']);
      final canvasWidth = _toDouble(data['canvasWidth'] ?? 480);
      _scratchX = _toScratchX(_clientX, canvasWidth);
      print('更新鼠标 X: 客户端=$_clientX → Scratch=$_scratchX');
    }

    if (data.containsKey('y')) {
      _clientY = _toDouble(data['y']);
      final canvasHeight = _toDouble(data['canvasHeight'] ?? 360);
      _scratchY = _toScratchY(_clientY, canvasHeight);
      print('更新鼠标 Y: 客户端=$_clientY → Scratch=$_scratchY');
    }

    if (data.containsKey('isDown')) {
      _isDown = data['isDown'] as bool;
      print('更新鼠标按下状态: $_isDown');
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
    print('Mouse.ioQuery 被调用: $query');
    switch (query) {
      case 'getScratchX':
        print('返回 scratchX: $_scratchX');
        return _scratchX;
      case 'getScratchY':
        print('返回 scratchY: $_scratchY');
        return _scratchY;
      case 'getIsDown':
        print('返回 isDown: $_isDown');
        return _isDown;
      case 'getClientX':
        print('返回 clientX: $_clientX');
        return _clientX;
      case 'getClientY':
        print('返回 clientY: $_clientY');
        return _clientY;
      default:
        print('未知查询: $query');
        return null;
    }
  }
}