import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'dart:convert';

class StageRenderer extends CustomPainter {
  final ProjectBank projectBank;

  StageRenderer(this.projectBank);

  @override
  void paint(Canvas canvas, Size size) {
    final targets = projectBank.targets;
    if (targets.isEmpty) return;

    final stage = targets.firstWhere(
      (t) => t.isStage,
      orElse: () => targets.first,
    );

    final sprites = targets.where((t) => !t.isStage).toList()
      ..sort((a, b) => a.layerOrder.compareTo(b.layerOrder));

    final scratchStageWidth = 480.0;
    final scratchStageHeight = 360.0;
    final renderWidth = size.width;
    final renderHeight = size.height;

    final scaleX = renderWidth / scratchStageWidth;
    final scaleY = renderHeight / scratchStageHeight;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    if (stage.costumes.isNotEmpty && stage.costumes[stage.currentCostume].data.isNotEmpty) {
      final costume = stage.costumes[stage.currentCostume];
      _drawCostume(canvas, costume, scratchStageWidth / 2, scratchStageHeight / 2, 100, 0, 'all around', scratchStageWidth, scratchStageHeight);
    }

    for (final sprite in sprites) {
      if (!sprite.isVisible || sprite.costumes.isEmpty) continue;
      final costume = sprite.costumes[sprite.currentCostume];
      if (costume.data.isEmpty) continue;

      _drawCostume(
        canvas,
        costume,
        sprite.x + scratchStageWidth / 2,
        scratchStageHeight / 2 - sprite.y,
        sprite.size,
        sprite.direction,
        sprite.rotationStyle,
        scratchStageWidth,
        scratchStageHeight,
      );
    }

    canvas.restore();
  }

  void _drawCostume(
    Canvas canvas,
    ScratchCostume costume,
    double x,
    double y,
    double size,
    double direction,
    String rotationStyle,
    double stageWidth,
    double stageHeight,
  ) {
    final scale = size / 100;
    double rotation = 0;

    if (rotationStyle == 'all around') {
      rotation = (direction - 90) * 3.1415926535 / 180;
    }

    canvas.save();
    canvas.translate(x, y);

    if (rotationStyle == 'left-right') {
      if (direction < 0 || direction > 180) {
        canvas.scale(-1, 1);
      }
    } else if (rotationStyle == 'all around') {
      canvas.rotate(rotation);
    }

    canvas.scale(scale);
    canvas.translate(-costume.rotationCenterX, -costume.rotationCenterY);

    if (costume.dataFormat == 'svg') {
      _drawSvg(canvas, costume.data, stageWidth, stageHeight);
    } else {
      _drawPng(canvas, costume.data);
    }

    canvas.restore();
  }

  void _drawSvg(Canvas canvas, Uint8List data, double width, double height) {
    try {
      final svgString = String.fromCharCodes(data);
      final picture = svgStringToPicture(svgString, width, height);
      if (picture != null) {
        canvas.drawPicture(picture);
      }
    } catch (e) {
      debugPrint('SVG rendering error: $e');
    }
  }

  ui.Picture? svgStringToPicture(String svgString, double width, double height) {
    try {
      final builder = ui.PictureRecorder();
      final canvas = Canvas(builder);
      final svgDrawable = SvgDrawable(svgString);
      svgDrawable.draw(canvas, Size(width, height));
      return builder.endRecording();
    } catch (e) {
      return null;
    }
  }

  void _drawPng(Canvas canvas, Uint8List data) {
    try {
      ui.decodeImageFromList(data, (image) {
        canvas.drawImage(image, Offset.zero, Paint());
      });
    } catch (e) {
      debugPrint('PNG rendering error: $e');
    }
  }

  @override
  bool shouldRepaint(covariant StageRenderer oldDelegate) {
    return oldDelegate.projectBank != projectBank;
  }
}

class SvgDrawable {
  final String svgString;
  SvgDrawable(this.svgString);

  void draw(Canvas canvas, Size size) {
    try {
      final svgPicture = SvgPicture.string(
        svgString,
        width: size.width,
        height: size.height,
      );
    } catch (e) {
      debugPrint('SVG draw error: $e');
    }
  }
}

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
  final bool isVisible;
  final double x;
  final double y;
  final double direction;
  final double size;
  final int currentCostume;
  final Map<String, dynamic> variables;
  final Map<String, dynamic> lists;
  final Map<String, dynamic> broadcasts;
  final Map<String, dynamic> blocks;
  final List<ScratchCostume> costumes;
  final List<ScratchSound> sounds;
  final int layerOrder;
  final double volume;
  final String rotationStyle;

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
                            const SizedBox(width: 12),
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
    return Container(
      width: 480,
      height: 320,
      color: Colors.lightBlue[100],
      child: CustomPaint(
        painter: StageRenderer(_projectBank!),
        size: const Size(480, 320),
      ),
    );
  }
}
