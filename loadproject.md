# Scratch VM 项目加载详解

本指南详细介绍 Scratch VM 如何加载 SB3 项目文件到内存的全过程。

---

## 一、加载流程总览

```
┌─────────────────────────────────────────────────────────────┐
│                    1. 输入阶段                              │
│         (SB3文件 / JSON字符串 / ArrayBuffer)              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                 2. ZIP 解压缩                               │
│              使用 JSZip 提取 project.json                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                 3. 项目验证                                 │
│           使用 scratch-parser 验证格式                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                 4. 反序列化                                 │
│         sb3.deserialize() 解析 JSON 为对象                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                 5. 资产加载                                 │
│         造型(SVG/PNG) 和声音(WAV) 的解码                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                 6. 目标安装                                 │
│         舞台 + 角色 → Runtime.targets[]                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                 7. 初始化完成                                │
│              Runtime 就绪，可执行积木                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 二、核心函数入口

### 2.1 主要加载函数

文件：[virtual-machine.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/virtual-machine.js#L307-L361)

```javascript
loadProject(input) {
    // input: string | object | ArrayBuffer
    // 返回: Promise
}
```

**支持三种输入格式**：

| 输入类型 | 示例 | 说明 |
|---------|------|------|
| JSON 字符串 | `"{\"targets\":[...]}"` | 直接的项目 JSON |
| JSON 对象 | `{targets: [...]}` | 已经解析的对象 |
| ArrayBuffer | `ArrayBuffer` | ZIP 文件的二进制数据 |

### 2.2 简化调用示例

```javascript
const vm = new VirtualMachine();

// 方式1：从文件加载
const response = await fetch('my-project.sb3');
const buffer = await response.arrayBuffer();
await vm.loadProject(buffer);

// 方式2：从 JSON 对象加载
await vm.loadProject(projectJsonObject);

// 方式3：从 JSON 字符串加载
await vm.loadProject(JSON.stringify(projectJsonObject));
```

---

## 三、ZIP 解压缩详解

### 3.1 JSZip 的使用

SB3 文件本质上是一个 ZIP 压缩包，包含以下内容：

```
my-project.sb3 (ZIP文件)
├── project.json          # 核心配置文件
├── e.g. costume1.svg    # 造型文件
├── e.g. costume2.png     # 造型文件
├── e.e. sound1.wav      # 声音文件
└── ...
```

### 3.2 解压缩过程

文件：[virtual-machine.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/virtual-machine.js)

```javascript
// JSZip 加载 ZIP 文件
const JSZip = require('jszip');
const zip = new JSZip();

// 解压 ZIP
zip.loadAsync(arrayBuffer).then(zip => {
    // 读取 project.json
    return zip.file('project.json').async('string');
}).then(projectJsonString => {
    // 解析为对象
    const projectData = JSON.parse(projectJsonString);
    // 获取其他资源
    const assets = [];
    zip.forEach((relativePath, file) => {
        if (relativePath !== 'project.json') {
            assets.push({
                path: relativePath,
                data: file.async('uint8array')
            });
        }
    });
    return { projectData, assets };
});
```

### 3.3 资源文件的定位

资源文件通过 MD5+扩展名定位：

```javascript
// project.json 中的引用
{
    "costumes": [{
        "assetId": "7da4181ee167de7b3f5d1a91880277ff",
        "dataFormat": "svg",
        "md5ext": "7da4181ee167de7b3f5d1a91880277ff.svg"
    }]
}

// ZIP 中查找
// 文件名: 7da4181ee167de7b3f5d1a91880277ff.svg
```

---

## 四、项目验证

### 4.1 scratch-parser 验证器

文件：[virtual-machine.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/virtual-machine.js#L319-L349)

```javascript
const validate = require('scratch-parser');

validate(input, false, (error, res) => {
    if (error) {
        // 验证失败
        reject(error);
    } else {
        // 验证成功
        // res[0] = project.json 对象
        // res[1] = JSZip 对象
        resolve(res);
    }
});
```

### 4.2 验证器参数

```javascript
validate(input, isSprite, callback);
```

| 参数 | 类型 | 说明 |
|------|------|------|
| input | string/ArrayBuffer | 要验证的数据 |
| isSprite | boolean | `false`=整个项目, `true`=单个角色 |
| callback | function | 回调函数 `(error, result)` |

### 4.3 版本兼容处理

```javascript
// 版本2: Scratch 2.0 项目 (.sb2)
// 版本3: Scratch 3.0 项目 (.sb3)
const projectVersion = projectJSON.projectVersion;

if (projectVersion === 2) {
    // 使用 SB2 反序列化器
    const sb2 = require('./serialization/sb2');
    return sb2.deserialize(projectJSON, runtime, false, zip);
}

if (projectVersion === 3) {
    // 使用 SB3 反序列化器
    const sb3 = require('./serialization/sb3');
    return sb3.deserialize(projectJSON, runtime, zip);
}
```

---

## 五、反序列化详解

### 5.1 反序列化主函数

文件：[sb3.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/serialization/sb3.js#L1255-L1312)

```javascript
const deserialize = function(json, runtime, zip, isSingleSprite) {
    const extensions = {
        extensionIDs: new Set(),
        extensionURLs: new Map()
    };

    // 1. 保存项目来源
    if (json.meta && json.meta.origin) {
        runtime.origin = json.meta.origin;
    }

    // 2. 处理目标顺序
    const targetObjects = (isSingleSprite ? [json] : json.targets || [])
        .map((t, i) => Object.assign(t, {targetPaneOrder: i}))
        .sort((a, b) => a.layerOrder - b.layerOrder);

    // 3. 解析资产
    return Promise.resolve(
        targetObjects.map(target =>
            parseScratchAssets(target, runtime, zip))
    )
        // 4. 解析目标
        .then(assets => Promise.all(
            targetObjects.map((target, index) =>
                parseScratchObject(target, runtime, extensions, zip, assets[index])
            )
        ))
        // 5. 处理变量ID
        .then(targets => replaceUnsafeCharsInVariableIds(targets))
        // 6. 处理监视器
        .then(targets => {
            (json.monitors || []).forEach(monitor =>
                deserializeMonitor(monitor, runtime, targets, extensions)
            );
            return targets;
        })
        // 7. 返回结果
        .then(targets => ({ targets, extensions }));
};
```

### 5.2 资产解析

文件：[sb3.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/serialization/sb3.js#L862-L934)

```javascript
const parseScratchAssets = function(object, runtime, zip) {
    const assets = {
        costumePromises: [],  // 造型加载 Promise 数组
        soundPromises: [],    // 声音加载 Promise 数组
        soundBank: runtime.audioEngine ?
            runtime.audioEngine.createBank() : null
    };

    // 解析造型
    assets.costumePromises = object.costumes.map(costumeSource => {
        const costume = {
            asset: costumeSource.asset,
            assetId: costumeSource.assetId,
            skinId: null,
            name: costumeSource.name,
            bitmapResolution: costumeSource.bitmapResolution,
            rotationCenterX: costumeSource.rotationCenterX,
            rotationCenterY: costumeSource.rotationCenterY
        };

        // 处理数据格式
        const dataFormat = costumeSource.dataFormat || 'png';
        const md5ext = costumeSource.md5ext ||
            `${costumeSource.assetId}.${dataFormat}`;

        costume.md5 = md5ext;
        costume.dataFormat = dataFormat;

        // 解码并加载
        return deserializeCostume(costume, runtime, zip)
            .then(() => loadCostume(md5ext, costume, runtime));
    });

    // 解析声音
    assets.soundPromises = object.sounds.map(soundSource => {
        const sound = {
            assetId: soundSource.assetId,
            format: soundSource.format,
            rate: soundSource.rate,
            sampleCount: soundSource.sampleCount,
            name: soundSource.name,
            md5: soundSource.md5ext,
            dataFormat: soundSource.dataFormat,
            data: null
        };

        // 解码并加载
        return deserializeSound(sound, runtime, zip)
            .then(() => loadSound(sound, runtime, assets.soundBank));
    });

    return assets;
};
```

### 5.3 目标对象解析

文件：[sb3.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/serialization/sb3.js#L946-L1108)

```javascript
const parseScratchObject = function(object, runtime, extensions, zip, assets) {
    // 1. 创建积木容器
    const blocks = new Blocks(runtime);

    // 2. 创建 Sprite 对象
    const sprite = new Sprite(blocks, runtime);
    sprite.name = object.name;

    // 3. 反序列化积木
    if (object.blocks) {
        deserializeBlocks(object.blocks);

        // 创建每个积木
        for (const blockId in object.blocks) {
            const blockJSON = object.blocks[blockId];
            blocks.createBlock(blockJSON);

            // 记录扩展
            const extensionID = getExtensionIdForOpcode(blockJSON.opcode);
            if (extensionID) {
                extensions.extensionIDs.add(extensionID);
            }
        }
    }

    // 4. 加载造型和声音
    Promise.all(assets.costumePromises).then(costumes => {
        sprite.costumes = costumes;
    });
    Promise.all(assets.soundPromises).then(sounds => {
        sprite.sounds = sounds;
        sprite.soundBank = assets.soundBank || null;
    });

    // 5. 创建目标克隆
    const target = sprite.createClone(
        object.isStage ? StageLayering.BACKGROUND_LAYER : StageLayering.SPRITE_LAYER
    );

    // 6. 加载属性
    if (object.tempo) target.tempo = object.tempo;
    if (object.volume) target.volume = object.volume;
    if (object.videoTransparency) target.videoTransparency = object.videoTransparency;
    if (object.videoState) target.videoState = object.videoState;
    if (object.textToSpeechLanguage) target.textToSpeechLanguage = object.textToSpeechLanguage;

    // 7. 加载变量
    if (object.variables) {
        for (const [varId, variable] of Object.entries(object.variables)) {
            const isCloud = variable.length === 3 && variable[2] &&
                object.isStage && runtime.canAddCloudVariable();
            const newVariable = new Variable(
                varId,
                variable[0],  // 名称
                Variable.SCALAR_TYPE,
                isCloud
            );
            if (isCloud) runtime.addCloudVariable();
            newVariable.value = variable[1];  // 值
            target.variables[newVariable.id] = newVariable;
        }
    }

    // 8. 加载列表
    if (object.lists) {
        for (const [listId, list] of Object.entries(object.lists)) {
            const newList = new Variable(
                listId,
                list[0],
                Variable.LIST_TYPE,
                false
            );
            newList.value = list[1];
            target.variables[newList.id] = newList;
        }
    }

    // 9. 加载广播
    if (object.broadcasts) {
        for (const [broadcastId, broadcast] of Object.entries(object.broadcasts)) {
            const newBroadcast = new Variable(
                broadcastId,
                broadcast,
                Variable.BROADCAST_MESSAGE_TYPE,
                false
            );
            target.variables[newBroadcast.id] = newBroadcast;
        }
    }

    // 10. 加载位置和方向
    if (object.x) target.x = object.x;
    if (object.y) target.y = object.y;
    if (object.direction) target.direction = object.direction;
    if (object.size) target.size = object.size;
    if (object.visible) target.visible = object.visible;
    if (object.rotationStyle) target.rotationStyle = object.rotationStyle;
    if (object.currentCostume) target.currentCostume = object.currentCostume;

    return Promise.all(assets.costumePromises.concat(assets.soundPromises))
        .then(() => target);
};
```

### 5.4 积木反序列化

文件：[sb3.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/serialization/sb3.js#L828-L847)

```javascript
const deserializeBlocks = function(blocks) {
    for (const blockId in blocks) {
        const block = blocks[blockId];

        if (Array.isArray(block)) {
            // 原始积木（压缩格式）转换为完整对象
            delete blocks[blockId];
            deserializeInputDesc(block, null, false, blocks);
            continue;
        }

        // 添加 ID
        block.id = blockId;

        // 反序列化输入
        block.inputs = deserializeInputs(block.inputs, blockId, blocks);

        // 反序列化字段
        block.fields = deserializeFields(block.fields);
    }
    return blocks;
};
```

---

## 六、资产加载详解

### 6.1 造型加载

文件：[load-costume.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/import/load-costume.js)

```javascript
const loadCostume = function(md5ext, costume, runtime, version) {
    const storage = runtime.storage;

    // 从存储获取资产数据
    return storage.get(storage.AssetType.ImageBitmap, md5ext)
        .then(asset => {
            costume.asset = asset;

            // 根据格式处理
            if (costume.dataFormat === 'svg') {
                // SVG 矢量图处理
                return loadSvg(costume, runtime);
            } else {
                // PNG/JPG 位图处理
                return loadBitmap(costume, runtime);
            }
        });
};
```

### 6.2 声音加载

文件：[load-sound.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/import/load-sound.js)

```javascript
const loadSound = function(sound, runtime, soundBank) {
    const storage = runtime.storage;

    // 从存储获取声音数据
    return storage.get(storage.AssetType.Sound, sound.md5)
        .then(asset => {
            sound.asset = asset;

            // 解码为音频缓冲区
            return decodeSound(asset.data, sound);
        })
        .then(() => {
            // 添加到声音银行
            if (soundBank) {
                soundBank.addSound(sound);
            }
        });
};
```

---

## 七、目标安装

### 7.1 安装函数

文件：[virtual-machine.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/virtual-machine.js#L527-L570)

```javascript
installTargets(targets, extensions, wholeProject) {
    const extensionPromises = [];

    // 1. 加载需要的扩展
    extensions.extensionIDs.forEach(extensionID => {
        if (!this.extensionManager.isExtensionLoaded(extensionID)) {
            const extensionURL = extensions.extensionURLs.get(extensionID) || extensionID;
            extensionPromises.push(
                this.extensionManager.loadExtensionURL(extensionURL)
            );
        }
    });

    // 2. 等待扩展加载完成
    return Promise.all(extensionPromises).then(() => {
        // 3. 添加目标到运行时
        targets.forEach(target => {
            this.runtime.addTarget(target);
            target.updateAllDrawableProperties();

            // 确保角色名称唯一
            if (target.isSprite()) {
                this.renameSprite(target.id, target.getName());
            }
        });

        // 4. 排序可执行目标
        this.runtime.executableTargets.sort((a, b) =>
            a.layerOrder - b.layerOrder
        );

        // 5. 删除临时属性
        targets.forEach(target => delete target.layerOrder);

        // 6. 选择编辑目标
        if (wholeProject && targets.length > 1) {
            this.editingTarget = targets[1];  // 第一个角色
        } else {
            this.editingTarget = targets[0];
        }

        // 7. 修复变量引用
        if (!wholeProject) {
            this.editingTarget.fixUpVariableReferences();
        }

        // 8. 发出更新事件
        this.emitTargetsUpdate(false);
        this.emitWorkspaceUpdate();
        this.runtime.setEditingTarget(this.editingTarget);

        // 9. 设置云变量设备
        this.runtime.ioDevices.cloud.setStage(
            this.runtime.getTargetForStage()
        );
    });
}
```

### 7.2 Runtime.targets 结构

```javascript
runtime.targets = [
    {
        // 舞台对象 (isStage: true)
        isStage: true,
        name: "Stage",
        sprite: Sprite,
        blocks: Blocks,
        variables: {...},
        costumes: [...],
        sounds: [...],
        // ...
    },
    {
        // 角色对象 (isStage: false)
        isStage: false,
        name: "Sprite1",
        sprite: Sprite,
        blocks: Blocks,
        variables: {...},
        // ...
    },
    // 更多角色...
];
```

---

## 八、完整加载示例

```javascript
const VirtualMachine = require('scratch-vm');
const vm = new VirtualMachine();

// 1. 初始化（附加必要的组件）
vm.attachAudioEngine(new AudioEngine());
vm.attachRenderer(new RenderWebGL());
vm.attachStorage(new ScratchStorage());

// 2. 开始加载
async function loadProject(fileBuffer) {
    try {
        // 加载项目
        await vm.loadProject(fileBuffer);

        // 3. 项目已加载，可以开始了
        console.log('项目加载成功！');
        console.log(`目标数量: ${vm.runtime.targets.length}`);

        // 4. 启动运行
        vm.start();
        vm.greenFlag();

    } catch (error) {
        console.error('加载失败:', error);
    }
}

// 加载 SB3 文件
fetch('https://example.com/project.sb3')
    .then(response => response.arrayBuffer())
    .then(buffer => loadProject(buffer));
```

---

## 九、时序图

```
┌────────┬────────┬─────────┬──────────┬──────────┬──────────┐
│ 用户   │  VM    │  JSZip  │ scratch- │  sb3.js  │ Runtime  │
│        │        │         │ parser   │          │          │
└────────┴────────┴─────────┴──────────┴──────────┴──────────┘
   │
   │ loadProject(buffer)
   │
   ├─────────►
   │                  loadAsync(buffer)
   │              ◄─────────────────
   │                  zip.file('project.json')
   │              ◄──────────────────
   │                  validate(projectJson)
   │              ───────────────────►
   │                                    │ validate()
   │                               ◄────┴──────────
   │                  [json, zip]
   │              ◄──────────────────
   │ deserializeProject(json, zip)
   │ ──────────────────────────────────────────────►
   │                                             │
   │              deserialize(json, runtime, zip)
   │              ◄───────────────────────────────
   │                  │
   │                  ├─► parseScratchAssets()
   │                  │      loadCostume()
   │                  │      loadSound()
   │                  │
   │                  ├─► parseScratchObject()
   │                  │      deserializeBlocks()
   │                  │      创建 Sprite
   │                  │      创建 Target
   │                  │
   │                  ├─► deserializeMonitor()
   │                  │
   │                  ◄───────────────────────────────
   │
   │ installTargets(targets, extensions)
   │ ──────────────────────────────────────────────►
   │                                             │
   │                                             ├─► loadExtension()
   │                                             │
   │                                             ├─► addTarget()
   │                                             │
   │                                             ├─► setEditingTarget()
   │                                             │
   │               Promise
   │              ◄─────────────────────────────────────
   │
   │ project loaded!
   │
   ▼
```

---

## 十、关键文件索引

| 文件 | 职责 | 关键函数 |
|------|------|---------|
| [virtual-machine.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/virtual-machine.js) | VM 主入口 | `loadProject()`, `installTargets()` |
| [sb3.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/serialization/sb3.js) | SB3 序列化 | `deserialize()`, `serialize()` |
| [load-costume.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/import/load-costume.js) | 造型加载 | `loadCostume()` |
| [load-sound.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/import/load-sound.js) | 声音加载 | `loadSound()` |
| [runtime.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/engine/runtime.js) | 运行时管理 | 管理所有目标和执行 |
| [sprite.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/sprites/sprite.js) | 角色管理 | 创建和管理角色 |

---

## 十一、调试技巧

### 11.1 查看加载进度

```javascript
vm.loadProject(buffer).then(() => {
    console.log('加载完成!');
    console.log('所有目标:', vm.runtime.targets.map(t => t.sprite.name));
});
```

### 11.2 监听事件

```javascript
vm.on('targetsUpdate', (data) => {
    console.log('目标更新:', data.targetList.length);
});

vm.on('workspaceUpdate', (data) => {
    console.log('工作区更新');
});
```

### 11.3 常见错误处理

```javascript
try {
    await vm.loadProject(buffer);
} catch (error) {
    if (error.validationError) {
        console.error('项目格式验证失败');
    } else if (error.message.includes('zip')) {
        console.error('ZIP 解压失败');
    } else {
        console.error('加载失败:', error);
    }
}
```
