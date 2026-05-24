# Scratch 3.0 project.json 结构与解析指南

## 一、project.json 概述

Scratch 3.0 的项目文件（.sb3）是一个 ZIP 压缩包，包含以下内容：

| 内容 | 说明 |
|------|------|
| `project.json` | 核心配置文件，包含所有积木、变量、角色等信息 |
| 媒体资源 | 造型（PNG/SVG）、声音（WAV/MP3）等文件 |

`project.json` 的基本结构如下：

```json
{
  "targets": [...],      // 舞台和所有角色
  "monitors": [...],     // 舞台上的监视器和滑块
  "extensions": [...],   // 项目使用的扩展
  "meta": {...}          // 项目元数据
}
```

---

## 二、主要字段详解

### 1. targets（目标对象数组）

`targets` 是一个数组，**第一个元素永远是舞台（Stage）**，后面的元素是角色（Sprite）。每个目标对象包含角色的所有信息。

### 1.1 targets 中各属性详解

#### 1.1.1 `isStage`（布尔值）

**含义**：标识这个目标是舞台还是角色

| 值 | 含义 | 示例 |
|----|------|------|
| `true` | 这是舞台 | `"isStage": true` |
| `false` | 这是角色 | `"isStage": false` |

**示例**：
```json
"isStage": true    // 表示这是舞台
"isStage": false   // 表示这是一个角色
```

#### 1.1.2 `name`（字符串）

**含义**：目标的名字

| 目标类型 | 取值 | 示例 |
|---------|------|------|
| 舞台 | 固定为 `"Stage"` | `"name": "Stage"` |
| 角色 | 用户自定义名称 | `"name": "Sprite1"` 或 `"name": "小猫"` |

#### 1.1.3 `variables`（对象）

**含义**：这个目标拥有的所有变量

**结构**：键是变量ID，值是包含变量信息的数组

**数组格式**：`[变量名, 变量值, 是否为云变量?]`

| 索引 | 内容 | 类型 | 说明 |
|------|------|------|------|
| 0 | 变量名 | string | 用户定义的变量名称 |
| 1 | 变量值 | string/number | 变量的当前值 |
| 2 | 云变量标识 | boolean | 可选，true表示是云变量 |

**示例**：
```json
"variables": {
  "变量ID-1": ["得分", 0],                        // 普通变量
  "变量ID-2": ["用户名", "Player1"],              // 字符串变量
  "变量ID-3": ["☁ 高分", 100, true]              // 云变量（第三个元素为true）
}
```

**注意**：
- 云变量只能是舞台上的变量
- 云变量名称通常以 "☁" 或 "cloud" 开头
- 最多只能有 10 个云变量

#### 1.1.4 `lists`（对象）

**含义**：这个目标拥有的所有列表

**结构**：键是列表ID，值是包含列表信息的数组

**数组格式**：`[列表名, [列表项1, 列表项2, ...]]`

| 索引 | 内容 | 类型 | 说明 |
|------|------|------|------|
| 0 | 列表名 | string | 用户定义的列表名称 |
| 1 | 列表内容 | array | 包含所有列表项的数组 |

**示例**：
```json
"lists": {
  "列表ID-1": ["水果", ["苹果", "香蕉", "橙子"]],
  "列表ID-2": ["分数", [100, 95, 88, 72]]
}
```

#### 1.1.5 `broadcasts`（对象）

**含义**：项目中定义的所有广播消息

**结构**：键是广播ID，值是广播消息内容

**示例**：
```json
"broadcasts": {
  "广播ID-1": "开始游戏",
  "广播ID-2": "游戏结束",
  "广播ID-3": "下一关"
}
```

**注意**：
- 广播ID是自动生成的唯一标识
- 广播消息内容是用户输入的文本
- 同一个项目中不能有两个相同的广播消息

#### 1.1.6 `blocks`（对象）

**含义**：这个目标包含的所有积木

**结构**：键是积木ID，值是积木对象或压缩的原始积木数组

这是 project.json 中最复杂的部分，详细说明如下。

##### 1.1.6.1 普通积木格式

```json
{
  "opcode": "motion_movesteps",    // 积木的操作码
  "next": "下一个积木ID",           // 下一个积木的ID（可选）
  "parent": "父积木ID",            // 父积木的ID（可选）
  "inputs": {                      // 输入参数
    "STEPS": [1, "原始积木ID"]
  },
  "fields": {                      // 字段
    "DIRECTION": ["90"]
  },
  "shadow": false,                 // 是否是阴影积木
  "topLevel": true,                // 是否是顶层积木
  "x": 100,                        // 在舞台上的X坐标（仅顶层积木）
  "y": 200,                        // 在舞台上的Y坐标（仅顶层积木）
  "mutation": {...}                // 变异数据（可选，用于某些特殊积木）
}
```

**各属性详解**：

| 属性 | 类型 | 含义 | 示例 |
|------|------|------|------|
| `opcode` | string | 积木的唯一标识符 | `"motion_movesteps"`, `"control_repeat"` |
| `next` | string/null | 下一个积木的ID，如果这是最后一个则为空 | `"abc123"` 或 `null` |
| `parent` | string/null | 父积木的ID，如果是顶层积木则为空 | `"xyz789"` 或 `null` |
| `inputs` | object | 输入端口，包含子积木或参数 | 详见下文 |
| `fields` | object | 字段，包含下拉菜单或文本值 | 详见下文 |
| `shadow` | boolean | 是否是阴影积木（用户在编辑界面看到的默认值） | `true` 或 `false` |
| `topLevel` | boolean | 是否是顶层积木（直接在脚本区的积木） | `true` 或 `false` |
| `x` | number | 积木在编辑区的X坐标（仅顶层积木有） | `100` |
| `y` | number | 积木在编辑区的Y坐标（仅顶层积木有） | `200` |
| `mutation` | object | 特殊积木的额外数据（如自定义积木定义） | 可选 |

##### 1.1.6.2 原始积木（压缩格式）

某些简单的积木（如数字输入）会被压缩为数组格式以节省空间：

```json
[类型常量, 值, ID?, X?, Y?]
```

**类型常量对照表**：

| 常量值 | 积木类型 | 说明 | 示例 |
|--------|---------|------|------|
| 4 | `math_number` | 数字输入 | `[4, 10]` |
| 5 | `math_positive_number` | 正数输入 | `[5, 5]` |
| 6 | `math_whole_number` | 整数输入 | `[6, 3]` |
| 7 | `math_integer` | 整数输入 | `[7, 42]` |
| 8 | `math_angle` | 角度输入 | `[8, 90]` |
| 9 | `colour_picker` | 颜色选择器 | `[9, "#FF0000"]` |
| 10 | `text` | 文本输入 | `[10, "Hello"]` |
| 11 | `event_broadcast_menu` | 广播消息选择器 | `[11, "消息1", "广播ID"]` |
| 12 | `data_variable` | 变量选择器 | `[12, "得分", "变量ID"]` |
| 13 | `data_listcontents` | 列表选择器 | `[13, "水果", "列表ID"]` |

**示例**：
```json
// 一个普通数字10被压缩为：
[4, 10]

// 一个带ID的变量被压缩为：
[12, "得分", "6C~ysz%{q=IY/@VyR,}u"]

// 一个顶层变量（带位置信息）：
[12, "列表", "abc123", 50, 100]
```

##### 1.1.6.3 inputs（输入端口）

`inputs` 对象定义了积木的输入端口，每个输入都是一个数组：

```json
"inputs": {
  "输入名称": [关系类型, 值/ID, 阴影ID?]
}
```

**关系类型**：

| 类型值 | 含义 | 说明 |
|--------|------|------|
| 1 | `INPUT_SAME_BLOCK_SHADOW` | 块和阴影相同，只存储块ID |
| 2 | `INPUT_BLOCK_NO_SHADOW` | 有块但没有阴影 |
| 3 | `INPUT_DIFF_BLOCK_SHADOW` | 块和阴影不同 |

**示例**：
```json
// "移动10步"积木的输入
"inputs": {
  "STEPS": [1, [4, 10]]  // 类型1，值为压缩的数字10
}

// "重复执行10次"积木的输入
"inputs": {
  "TIMES": [1, [4, 10]],                    // 重复次数
  "SUBSTACK": [2, "子积木ID"]               // 类型2，没有阴影
}
```

##### 1.1.6.4 fields（字段）

`fields` 对象定义了积木的下拉菜单和文本字段：

```json
"fields": {
  "字段名": [值, ID?]
}
```

**示例**：
```json
// "面向90度"积木的字段
"fields": {
  "DIRECTION": ["90"]           // 值为字符串"90"
}

// "广播消息1"积木的字段
"fields": {
  "BROADCAST_OPTION": ["开始游戏", "广播ID-123"]
}
```

#### 1.1.7 `comments`（对象）

**含义**：积木上的注释

**结构**：键是评论ID，值是评论信息

**示例**：
```json
"comments": {
  "评论ID-1": {
    "blockId": "积木ID",        // 关联的积木ID（可选）
    "x": 100,                   // X坐标
    "y": 200,                   // Y坐标
    "width": 200,               // 宽度
    "height": 100,              // 高度
    "minimized": false,         // 是否最小化
    "text": "这里是注释内容"     // 注释文本
  }
}
```

#### 1.1.8 `costumes`（造型数组）

**含义**：这个目标的所有造型

**示例**：
```json
"costumes": [
  {
    "name": "backdrop1",                           // 造型名称
    "bitmapResolution": 1,                         // 位图分辨率
    "dataFormat": "svg",                           // 数据格式（svg 或 png）
    "assetId": "7da4181ee167de7b3f5d1a91880277ff", // 资产ID（MD5哈希）
    "md5ext": "7da4181ee167de7b3f5d1a91880277ff.svg", // MD5+扩展名
    "rotationCenterX": 240,                        // 旋转中心X
    "rotationCenterY": 180                          // 旋转中心Y
  }
]
```

**格式说明**：

| 字段 | 类型 | 含义 | 示例值 |
|------|------|------|--------|
| `name` | string | 造型名称，用户可见 | `"cat"` |
| `bitmapResolution` | number | 位图分辨率，SVG为1，位图为2 | `1` 或 `2` |
| `dataFormat` | string | 图像格式 | `"svg"` 或 `"png"` |
| `assetId` | string | 资产唯一标识（MD5哈希） | `"7da4181ee167de..."` |
| `md5ext` | string | MD5+文件扩展名，用于查找ZIP中的文件 | `"7da4181ee167de7b.svg"` |
| `rotationCenterX` | number | 造型旋转中心X坐标 | `240` |
| `rotationCenterY` | number | 造型旋转中心Y坐标 | `180` |

#### 1.1.9 `sounds`（声音数组）

**示例**：
```json
"sounds": [
  {
    "name": "meow",                                   // 声音名称
    "assetId": "83c36d806dc92327b9e7049a565c6bff",    // 资产ID
    "dataFormat": "wav",                              // 数据格式
    "format": "",                                     // 格式信息
    "rate": 22050,                                    // 采样率（Hz）
    "sampleCount": 18688,                             // 采样数量
    "md5ext": "83c36d806dc92327b9e7049a565c6bff.wav"  // MD5+扩展名
  }
]
```

**格式说明**：

| 字段 | 类型 | 含义 | 示例值 |
|------|------|------|--------|
| `name` | string | 声音名称 | `"meow"` |
| `assetId` | string | 资产唯一标识 | `"83c36d806dc923..."` |
| `dataFormat` | string | 音频格式 | `"wav"` 或 `"mp3"` |
| `rate` | number | 采样率（每秒采样次数） | `22050`, `44100` |
| `sampleCount` | number | 总采样数 | `18688` |

#### 1.1.10 `currentCostume`（数字）

**含义**：当前造型索引（从0开始）

**示例**：
```json
"currentCostume": 0  // 显示第一个造型
```

#### 1.1.11 仅舞台有的属性

| 属性 | 类型 | 含义 | 示例值 |
|------|------|------|--------|
| `layerOrder` | number | 图层顺序，0表示最底层 | `0` |
| `volume` | number | 音量百分比 | `100` |
| `tempo` | number | 速度（BPM，每分钟节拍数） | `60` |
| `videoTransparency` | number | 视频透明度（0-100） | `50` |
| `videoState` | string | 视频状态 | `"on"`, `"off"`, `"on-flipped"` |
| `textToSpeechLanguage` | string/null | 语音语言 | `"en-US"`, `null` |

#### 1.1.12 仅角色有的属性

| 属性 | 类型 | 含义 | 示例值 |
|------|------|------|--------|
| `layerOrder` | number | 图层顺序，越大越在上面 | `1`, `2`, `3` |
| `volume` | number | 音量百分比 | `100` |
| `visible` | boolean | 是否可见 | `true` |
| `x` | number | X坐标 | `0`, `-50`, `100` |
| `y` | number | Y坐标 | `0`, `50`, `-100` |
| `size` | number | 大小百分比 | `100` |
| `direction` | number | 方向角度 | `90`（向右） |
| `draggable` | boolean | 是否可拖拽 | `false` |
| `rotationStyle` | string | 旋转样式 | `"all around"`, `"left-right"`, `"don't rotate"` |

**rotationStyle 取值说明**：

| 值 | 含义 | 效果 |
|----|------|------|
| `"all around"` | 任意旋转 | 角色可以旋转到任意方向 |
| `"left-right"` | 左右翻转 | 只在左右方向翻转，不旋转 |
| `"don't rotate"` | 不旋转 | 始终保持初始方向 |

**direction 取值范围**：
- `0`：向上
- `90`：向右
- `180`：向下
- `-90` 或 `270`：向左
- 其他值会被规范化到这个范围

---

### 2. monitors（监视器数组）

**含义**：舞台上显示的监视器、滑块、大数字显示器等

**示例**：
```json
[
  {
    "id": "monitor-123",              // 监视器ID
    "mode": "default",               // 显示模式
    "opcode": "data_variable",        // 关联的积木opcode
    "params": {                       // 参数
      "VARIABLE": "得分"
    },
    "spriteName": null,               // 关联的角色（全局监视器为null）
    "value": 0,                       // 当前值
    "width": 100,                     // 宽度
    "height": 50,                     // 高度
    "x": 10,                          // X坐标
    "y": 10,                          // Y坐标
    "visible": true,                  // 是否可见
    "sliderMin": 0,                   // 滑块最小值
    "sliderMax": 100,                 // 滑块最大值
    "isDiscrete": false                // 是否离散
  }
]
```

**mode 取值**：

| 模式 | 说明 | 适用场景 |
|------|------|---------|
| `"default"` | 默认监视器 | 变量、数字显示 |
| `"slider"` | 滑块 | 可调节的变量 |
| `"list"` | 列表监视器 | 列表显示 |

---

### 3. extensions（扩展数组）

**含义**：项目使用的扩展列表

**示例**：
```json
["pen", "music"]
```

**常见扩展ID**：

| 扩展ID | 名称 | 说明 |
|--------|------|------|
| `"pen"` | 画笔 | 绘图功能 |
| `"music"` | 音乐 | 演奏乐器 |
| `"videoSensing"` | 视频侦测 | 摄像头交互 |
| `"text2speech"` | 文本转语音 | 朗读功能 |
| `"translate"` | 翻译 | 翻译文本 |
| `"microbit"` | micro:bit | 硬件连接 |
| `"wedo2"` | WeDo 2.0 | LEGO机器人 |
| `"boost"` | BOOST | LEGO机器人 |
| `"ev3"` | EV3 | LEGO机器人 |
| `"makeymakey"` | Makey Makey | 硬件连接 |

---

### 4. meta（元数据对象）

**含义**：项目文件本身的元信息

**示例**：
```json
{
  "semver": "3.0.0",                           // Scratch版本（固定为3.0.0）
  "vm": "1.0.0",                               // 虚拟机版本号
  "agent": "Mozilla/5.0 (Windows NT 10.0; ...", // 用户代理字符串
  "origin": "scratch.mit.edu"                  // 来源网站（可选）
}
```

**各字段说明**：

| 字段 | 类型 | 含义 | 说明 |
|------|------|------|------|
| `semver` | string | Scratch文件格式版本 | 固定为 `"3.0.0"` |
| `vm` | string | Scratch VM版本号 | 如 `"1.0.0"`, `"2.0.0"` |
| `agent` | string | 浏览器用户代理 | 用于追踪来源 |
| `origin` | string | 项目来源网站 | 可选，如 `"scratch.mit.edu"`, `"cs-first.com"` |

---

## 三、完整示例

以下是一个简化的 project.json 示例：

```json
{
  "targets": [
    {
      "isStage": true,
      "name": "Stage",
      "variables": {
        "☁ 高分": ["☁ 高分", 100, true]
      },
      "lists": {},
      "broadcasts": {
        "msg1": "开始"
      },
      "blocks": {
        "topBlock1": {
          "opcode": "event_whenflagclicked",
          "next": "block2",
          "parent": null,
          "inputs": {},
          "fields": {},
          "shadow": false,
          "topLevel": true,
          "x": 100,
          "y": 100
        },
        "block2": {
          "opcode": "control_forever",
          "next": null,
          "parent": "topBlock1",
          "inputs": {
            "SUBSTACK": [2, "block3"]
          },
          "fields": {},
          "shadow": false,
          "topLevel": false
        },
        "block3": {
          "opcode": "looks_say",
          "next": null,
          "parent": "block2",
          "inputs": {
            "MESSAGE": [1, [10, "Hello!"]]
          },
          "fields": {},
          "shadow": false,
          "topLevel": false
        }
      },
      "comments": {},
      "currentCostume": 0,
      "costumes": [...],
      "sounds": [...],
      "layerOrder": 0
    },
    {
      "isStage": false,
      "name": "Sprite1",
      "variables": {
        "score": ["得分", 0]
      },
      "lists": {},
      "broadcasts": {},
      "blocks": {...},
      "comments": {},
      "currentCostume": 0,
      "costumes": [...],
      "sounds": [...],
      "layerOrder": 1,
      "volume": 100,
      "visible": true,
      "x": 0,
      "y": 0,
      "size": 100,
      "direction": 90,
      "draggable": false,
      "rotationStyle": "all around"
    }
  ],
  "monitors": [...],
  "extensions": [],
  "meta": {
    "semver": "3.0.0",
    "vm": "1.0.0",
    "agent": "..."
  }
}
```

---

## 四、解析流程

### 4.1 使用 scratch-vm 官方解析

在 [sb3.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/serialization/sb3.js) 中定义了主要的解析和序列化函数。

### 4.2 解析步骤详解

1. **反序列化（读取项目）**
   - 读取 ZIP 文件中的 project.json
   - 解析 `targets` 数组，逐个处理每个目标
   - 对每个目标，解析 `blocks` 对象：
     - 先处理普通积木，建立块与块之间的连接关系
     - 再处理原始积木（数组格式），转换为完整的积木对象
   - 解析 `variables`、`lists`、`broadcasts` 创建运行时对象
   - 处理 `costumes` 和 `sounds`，加载媒体资源
   - 处理 `monitors` 创建监视器

2. **序列化（保存项目）**
   - 将运行时对象转换为 JSON 格式
   - 压缩积木，将简单的值（如数字）转换为数组格式
   - 序列化媒体资源为 MD5 格式
   - 添加 `meta` 元数据

### 4.3 手动解析示例

```javascript
// 读取项目
const project = JSON.parse(fs.readFileSync('project.json'));

// 遍历所有目标
for (const target of project.targets) {
  console.log(`目标: ${target.name}`);
  console.log(`类型: ${target.isStage ? '舞台' : '角色'}`);

  // 遍历变量
  for (const [id, data] of Object.entries(target.variables)) {
    const [name, value, isCloud] = data;
    console.log(`  变量: ${name} = ${value}${isCloud ? ' (云变量)' : ''}`);
  }

  // 遍历积木
  for (const [id, block] of Object.entries(target.blocks)) {
    if (Array.isArray(block)) {
      // 原始积木（压缩格式）
      console.log(`  原始积木 [${id}]: 类型=${block[0]}, 值=${block[1]}`);
    } else {
      // 普通积木
      console.log(`  积木 [${id}]: ${block.opcode}`);
    }
  }
}
```

---

## 五、常见问题与注意事项

### 5.1 积木ID的处理
- 积木ID在**序列化时不存储**，只存储连接关系
- 反序列化时，所有ID都会**重新生成**
- 不要依赖积木ID进行任何逻辑判断

### 5.2 变量ID的唯一性
- 变量ID在整个项目中**必须唯一**
- 列表和广播也有独立的ID空间
- 导入项目时，ID会被重新分配

### 5.3 云变量限制
- 只有舞台上的变量可以是云变量
- 每个项目最多10个云变量
- 云变量名称通常以特殊字符开头

### 5.4 媒体资源路径
- 所有资源文件都在ZIP包中
- 文件名格式：`{assetId}.{dataFormat}`
- 如：`7da4181ee167de7b3f5d1a91880277ff.svg`

### 5.5 坐标系统
- Scratch舞台宽度：480像素
- Scratch舞台高度：360像素
- 中心点：(0, 0)
- 右边界X：240
- 上边界Y：180
