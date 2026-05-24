import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
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
  ProjectBank? _projectBank;
  bool _isLoading = false;
  String _statusMessage = '请选择 SB3 文件';

  Future<void> _pickAndLoadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sb3'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        setState(() {
          _selectedFilePath = filePath;
          _isLoading = true;
          _statusMessage = '正在加载文件...';
        });

        await _loadProject(filePath);
      }
    } catch (e) {
      setState(() {
        _statusMessage = '选择文件失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProject(String filePath) async {
    try {
      final file = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sb3'],
        withData: true,
      );

      if (file == null || file.files.isEmpty) {
        setState(() {
          _statusMessage = '文件读取失败';
          _isLoading = false;
        });
        return;
      }

      final bytes = file.files.single.bytes;
      if (bytes == null) {
        setState(() {
          _statusMessage = '文件数据为空';
          _isLoading = false;
        });
        return;
      }

      final bank = await _parseSB3(bytes);

      setState(() {
        _projectBank = bank;
        _isLoading = false;
        _statusMessage = '加载成功！\n'
            '项目版本: ${bank.projectVersion}\n'
            '目标数量: ${bank.targets.length}\n'
            '造型数量: ${bank.allCostumes.length}\n'
            '声音数量: ${bank.allSounds.length}';
      });

      debugPrint('项目加载成功！');
      debugPrint('目标数量: ${bank.targets.length}');
      debugPrint('造型数量: ${bank.allCostumes.length}');
      debugPrint('声音数量: ${bank.allSounds.length}');

    } catch (e) {
      setState(() {
        _statusMessage = '加载失败: $e';
        _isLoading = false;
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
      size: (targetJson['size'] ?? 100).toDouble(),
      currentCostume: targetJson['currentCostume'] ?? 0,
      variables: Map<String, dynamic>.from(targetJson['variables'] ?? {}),
      lists: Map<String, dynamic>.from(targetJson['lists'] ?? {}),
      broadcasts: Map<String, dynamic>.from(targetJson['broadcasts'] ?? {}),
      blocks: Map<String, dynamic>.from(targetJson['blocks'] ?? {}),
      costumes: costumes,
      sounds: sounds,
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
      rotationCenterX: costumeJson['rotationCenterX'] ?? 0,
      rotationCenterY: costumeJson['rotationCenterY'] ?? 0,
      bitmapResolution: costumeJson['bitmapResolution'] ?? 1,
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
      rate: soundJson['rate'] ?? 44100,
      sampleCount: soundJson['sampleCount'] ?? 0,
    );
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
                              ? Center(
                                  child: Text(
                                    _statusMessage,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                )
                              : null,
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
                            onPressed: _isLoading ? null : _pickAndLoadFile,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.folder_open, size: 18),
                            label: Text(_isLoading ? '加载中...' : '选择文件'),
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
                                onPressed: () {},
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
                                onPressed: _projectBank != null
                                    ? () {
                                        setState(() {
                                          _statusMessage =
                                              '已加载项目:\n${_projectBank!.targets.length} 个目标\n'
                                              '${_projectBank!.allCostumes.length} 个造型\n'
                                              '${_projectBank!.allSounds.length} 个声音';
                                        });
                                      }
                                    : null,
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
}
