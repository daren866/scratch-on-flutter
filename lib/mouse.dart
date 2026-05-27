class ScratchMouse {
  int _clientX = 0;
  int _clientY = 0;
  int _scratchX = 0;
  int _scratchY = 0;
  bool _isDown = false;

  final int canvasWidth = 480;
  final int canvasHeight = 360;

  int get scratchX => _scratchX;
  int get scratchY => _scratchY;
  bool get isDown => _isDown;

  void updatePosition(int clientX, int clientY) {
    _clientX = clientX;
    _clientY = clientY;

    _scratchX = _toScratchX(clientX);
    _scratchY = _toScratchY(clientY);
  }

  void updateMouseDown(bool isDown) {
    _isDown = isDown;
  }

  int _toScratchX(int clientX) {
    final x = (clientX / canvasWidth - 0.5) * 480;
    return x.round().clamp(-240, 240);
  }

  int _toScratchY(int clientY) {
    final y = -(clientY / canvasHeight - 0.5) * 360;
    return y.round().clamp(-180, 180);
  }

  Map<String, dynamic> toJson() {
    return {
      'clientX': _clientX,
      'clientY': _clientY,
      'scratchX': _scratchX,
      'scratchY': _scratchY,
      'isDown': _isDown,
    };
  }
}
