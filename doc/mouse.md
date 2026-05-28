# Scratch VM 鼠标坐标捕捉实现

## 一、鼠标系统概述

Scratch VM 的鼠标系统负责捕捉和转换鼠标在舞台上的坐标，使得积木能够获取鼠标位置、检测鼠标按下状态、以及判断鼠标是否碰到角色等。

### 1.1 核心组件

| 组件 | 文件 | 职责 |
|------|------|------|
| Mouse | [mouse.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/io/mouse.js) | 鼠标输入设备抽象 |
| Runtime | [runtime.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/engine/runtime.js) | 管理 IO 设备 |
| Scratch3MotionBlocks | [scratch3_motion.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/blocks/scratch3_motion.js) | 鼠标相关的运动积木 |
| Scratch3SensingBlocks | [scratch3_sensing.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/blocks/scratch3_sensing.js) | 鼠标相关的侦测积木 |

---

## 二、坐标系统

### 2.1 坐标系转换

Scratch 使用**舞台坐标系统**，而浏览器使用**客户端坐标系统**。两者需要转换：

```
浏览器客户端坐标 (0,0) ───────────────────→ Scratch 舞台坐标 (0,0)
        ↓                                              ↑
   canvasWidth × canvasHeight                  -240 ≤ X ≤ 240
   (例如: 480 × 360)                          -180 ≤ Y ≤ 180
```

### 2.2 坐标转换公式

```javascript
// 客户端 X → Scratch X
scratchX = Math.round(MathUtil.clamp(
    480 * ((clientX / canvasWidth) - 0.5),
    -240,
    240
));

// 客户端 Y → Scratch Y
scratchY = Math.round(MathUtil.clamp(
    -360 * ((clientY / canvasHeight) - 0.5),
    -180,
    180
));
```

### 2.3 坐标转换图解

```
客户端坐标系                    Scratch 坐标系
    (0,0) ─────→ X                  
        │                         Y: 180 ─┬─────────────────┐
        │                            │    │                 │
        ↓                            │    │                 │
        Y                      X: -240    │     (0,0)       │  X: 240
                                     │    │                 │
                                     │    │                 │
                                Y: -180 └─────────────────┘
        
    canvasWidth = 480              舞台尺寸: 480 × 360
    canvasHeight = 360
```

**转换关系**：
- **X轴**：`scratchX = (clientX / canvasWidth - 0.5) * 480`
- **Y轴**：`scratchY = -(clientY / canvasHeight - 0.5) * 360`
- **注意**：Y轴方向相反！

---

## 三、Mouse 类实现

### 3.1 核心属性

```javascript
class Mouse {
    constructor(runtime) {
        this._x = 0;           // 客户端 X 坐标
        this._y = 0;           // 客户端 Y 坐标
        this._isDown = false;  // 鼠标是否按下
        this.runtime = runtime;
    }
}
```

### 3.2 坐标获取方法

```javascript
// 获取客户端坐标
getClientX() {
    return this._clientX;
}

getClientY() {
    return this._clientY;
}

// 获取 Scratch 舞台坐标
getScratchX() {
    return this._scratchX;  // 范围: -240 ~ 240
}

getScratchY() {
    return this._scratchY;  // 范围: -180 ~ 180
}
```

### 3.3 数据更新方法

```javascript
postData(data) {
    // 更新 X 坐标
    if (data.x) {
        this._clientX = data.x;
        this._scratchX = Math.round(MathUtil.clamp(
            480 * ((data.x / data.canvasWidth) - 0.5),
            -240,
            240
        ));
    }
    
    // 更新 Y 坐标
    if (data.y) {
        this._clientY = data.y;
        this._scratchY = Math.round(MathUtil.clamp(
            -360 * ((data.y / data.canvasHeight) - 0.5),
            -180,
            180
        ));
    }
    
    // 更新鼠标状态
    if (typeof data.isDown !== 'undefined') {
        const previousDownState = this._isDown;
        this._isDown = data.isDown;
        
        // 触发点击帽子积木...
    }
}
```

---

## 四、坐标转换详解

### 4.1 转换公式分解

#### X 坐标转换

```javascript
scratchX = 480 * ((clientX / canvasWidth) - 0.5)
```

**分解**：
1. `clientX / canvasWidth`：将客户端 X 转换为 0~1 的比例
2. `... - 0.5`：将比例中心点从 0.5 移到 0（这样左边缘是负数，右边缘是正数）
3. `... * 480`：将比例转换为舞台坐标

**示例**：
| 客户端 X | canvasWidth | 计算过程 | Scratch X |
|---------|------------|---------|---------|
| 0 | 480 | (0/480 - 0.5) * 480 | -240 |
| 240 | 480 | (240/480 - 0.5) * 480 | 0 |
| 480 | 480 | (480/480 - 0.5) * 480 | 240 |

#### Y 坐标转换

```javascript
scratchY = -360 * ((clientY / canvasHeight) - 0.5)
```

**分解**：
1. `clientY / canvasHeight`：将客户端 Y 转换为 0~1 的比例
2. `... - 0.5`：将比例中心点从 0.5 移到 0
3. `... * 360`：将比例转换为舞台坐标
4. `-...`：反转 Y 轴方向（因为浏览器 Y 轴向下，Scratch Y 轴向上）

**示例**：
| 客户端 Y | canvasHeight | 计算过程 | Scratch Y |
|---------|-------------|---------|---------|
| 0 | 360 | -(0/360 - 0.5) * 360 | 180 |
| 180 | 360 | -(180/360 - 0.5) * 360 | 0 |
| 360 | 360 | -(360/360 - 0.5) * 360 | -180 |

### 4.2 坐标边界限制

```javascript
MathUtil.clamp(value, min, max)
```

- **X 坐标**：限制在 `-240` 到 `240` 之间
- **Y 坐标**：限制在 `-180` 到 `180` 之间

当鼠标移出画布边界时，坐标会被限制在有效范围内。

---

## 五、鼠标相关积木

### 5.1 侦测类积木

| 积木名称 | opcode | 类型 | 说明 |
|---------|--------|------|------|
| 鼠标的 X 坐标 | `sensing_mousex` | reporter | 返回鼠标的 Scratch X 坐标 |
| 鼠标的 Y 坐标 | `sensing_mousey` | reporter | 返回鼠标的 Scratch Y 坐标 |
| 鼠标是否按下 | `sensing_mousedown` | Boolean | 返回鼠标是否按下 |

### 5.2 积木实现

```javascript
// 积木函数定义
getMouseX(args, util) {
    return util.ioQuery('mouse', 'getScratchX');
}

getMouseY(args, util) {
    return util.ioQuery('mouse', 'getScratchY');
}

getMouseDown(args, util) {
    return util.ioQuery('mouse', 'getIsDown');
}
```

### 5.3 运动类积木中的鼠标应用

```javascript
// 移动到鼠标位置
getTargetXY(targetName, util) {
    if (targetName === '_mouse_') {
        targetX = util.ioQuery('mouse', 'getScratchX');
        targetY = util.ioQuery('mouse', 'getScratchY');
        return [targetX, targetY];
    }
    // ... 其他处理
}

// 面向鼠标方向
pointTowards(args, util) {
    if (args.TOWARDS === '_mouse_') {
        targetX = util.ioQuery('mouse', 'getScratchX');
        targetY = util.ioQuery('mouse', 'getScratchY');
        // 计算方向...
    }
}

// 到鼠标的距离
distanceTo(args, util) {
    if (args.DISTANCETOMENU === '_mouse_') {
        targetX = util.ioQuery('mouse', 'getScratchX');
        targetY = util.ioQuery('mouse', 'getScratchY');
        // 计算距离...
    }
}
```

---

## 六、鼠标点击检测

### 6.1 点击帽子积木

| 积木名称 | opcode | 触发条件 |
|---------|--------|---------|
| 当角色被点击 | `event_whenthisspriteclicked` | 鼠标按下/释放 |
| 当舞台被点击 | `event_whenstageclicked` | 鼠标按下/释放 |

### 6.2 点击检测实现

```javascript
postData(data) {
    if (typeof data.isDown !== 'undefined') {
        const previousDownState = this._isDown;
        this._isDown = data.isDown;
        
        // 状态没有变化，不触发
        if (previousDownState === this._isDown) return;
        
        // 拖拽结束后不触发点击
        if (data.wasDragged) return;
        
        // 画布边界外不触发
        if (!(data.x > 0 && data.x < data.canvasWidth &&
            data.y > 0 && data.y < data.canvasHeight)) return;
        
        // 找出点击的目标
        const target = this._pickTarget(data.x, data.y);
        
        const isNewMouseDown = !previousDownState && this._isDown;
        const isNewMouseUp = previousDownState && !this._isDown;
        
        // 可拖拽目标在鼠标释放时触发
        // 不可拖拽目标在鼠标按下时触发
        if (target.draggable && isNewMouseUp) {
            this._activateClickHats(target);
        } else if (!target.draggable && isNewMouseDown) {
            this._activateClickHats(target);
        }
    }
}
```

### 6.3 目标拾取

```javascript
_pickTarget(x, y) {
    if (this.runtime.renderer) {
        // 使用渲染器的 pick 方法检测
        const drawableID = this.runtime.renderer.pick(x, y);
        
        // 查找对应的目标
        for (let i = 0; i < this.runtime.targets.length; i++) {
            const target = this.runtime.targets[i];
            if (target.drawableID === drawableID) {
                return target;
            }
        }
    }
    
    // 没有找到目标，返回舞台
    return this.runtime.getTargetForStage();
}
```

---

## 七、IO 设备集成

### 7.1 Runtime 中的设备注册

```javascript
// runtime.js
constructor() {
    // ... 其他初始化
    
    this.ioDevices = {
        mouse: new Mouse(this),
        mouseWheel: new MouseWheel(this),
        keyboard: new Keyboard(this),
        clock: new Clock(this),
        cloud: new Cloud(this),
        video: new Video(this)
    };
}
```

### 7.2 积木中访问鼠标

```javascript
// 通过 ioQuery 方法访问
util.ioQuery('mouse', 'getScratchX');  // 获取鼠标 X 坐标
util.ioQuery('mouse', 'getScratchY');  // 获取鼠标 Y 坐标
util.ioQuery('mouse', 'getIsDown');    // 获取鼠标按下状态
```

---

## 八、完整执行流程

### 8.1 鼠标移动流程

```
1. 浏览器事件: mousemove
   ↓
2. GUI 层处理事件
   ↓
3. 调用 vm.postData({ x, y, canvasWidth, canvasHeight })
   ↓
4. Mouse.postData(data)
   ↓
5. 计算 Scratch 坐标
   - scratchX = 480 * ((x / canvasWidth) - 0.5)
   - scratchY = -360 * ((y / canvasHeight) - 0.5)
   ↓
6. 存储坐标
   - this._scratchX
   - this._scratchY
   ↓
7. 积木执行时获取
   - sensing_mousex → getScratchX() → 返回 scratchX
   - sensing_mousey → getScratchY() → 返回 scratchY
```

### 8.2 鼠标点击流程

```
1. 浏览器事件: mousedown
   ↓
2. GUI 层处理事件
   ↓
3. 调用 vm.postData({ x, y, isDown: true })
   ↓
4. Mouse.postData(data)
   ↓
5. 检测点击目标
   - renderer.pick(x, y) → drawableID
   - 查找对应目标
   ↓
6. 触发点击帽子
   - event_whenthisspriteclicked 或 event_whenstageclicked
   ↓
7. 启动相应脚本
```

---

## 九、常见问题

### 9.1 坐标偏移问题

**问题**：鼠标坐标与角色位置不匹配

**原因**：
- 画布尺寸与舞台尺寸不一致
- 坐标转换公式错误
- 没有考虑画布的 CSS 缩放

**解决方案**：
```javascript
// 确保使用正确的画布尺寸
postData(data) {
    // 使用实际的渲染画布尺寸，而非 CSS 显示尺寸
    const canvasWidth = renderer.getCanvas().width;
    const canvasHeight = renderer.getCanvas().height;
    // ...
}
```

### 9.2 边界检测问题

**问题**：鼠标在舞台边缘时坐标不准确

**原因**：坐标被 clamp 限制后，与实际位置有偏差

**解决方案**：
```javascript
// 使用客户端坐标进行边界检测
if (data.x < 0 || data.x > canvasWidth ||
    data.y < 0 || data.y > canvasHeight) {
    // 在边界外，不处理
}
```

### 9.3 HiDPI 屏幕问题

**问题**：在 Retina 等高分辨率屏幕上坐标不准

**原因**：`devicePixelRatio` 导致实际像素与 CSS 像素不一致

**解决方案**：
```javascript
// 获取实际渲染尺寸
const rect = canvas.getBoundingClientRect();
const dpr = window.devicePixelRatio || 1;

// 计算实际像素位置
const x = (event.clientX - rect.left) * dpr;
const y = (event.clientY - rect.top) * dpr;
```

---

## 十、性能优化

### 10.1 减少坐标更新

```javascript
// 鼠标移动时，使用节流（throttle）
let lastUpdate = 0;
const THROTTLE_MS = 16;  // 约 60fps

if (Date.now() - lastUpdate > THROTTLE_MS) {
    mouse.postData(data);
    lastUpdate = Date.now();
}
```

### 10.2 延迟坐标转换

```javascript
// 缓存转换结果
let cachedScratchX = null;
let cachedScratchY = null;

setClientPosition(x, y) {
    this._clientX = x;
    this._clientY = y;
    // 延迟计算 Scratch 坐标
    this._scratchCoordsValid = false;
}

getScratchX() {
    if (!this._scratchCoordsValid) {
        this._recalculateScratchCoords();
    }
    return this._scratchX;
}
```

---

## 十一、调试技巧

### 11.1 查看鼠标坐标

```javascript
// 在 postData 中添加日志
postData(data) {
    console.log(`Mouse: client(${data.x}, ${data.y}) → scratch(${this._scratchX}, ${this._scratchY})`);
    // ...
}
```

### 11.2 测试坐标转换

```javascript
// 测试用例
const tests = [
    { clientX: 0, clientY: 0, expected: { x: -240, y: 180 } },
    { clientX: 240, clientY: 180, expected: { x: 0, y: 0 } },
    { clientX: 480, clientY: 360, expected: { x: 240, y: -180 } }
];

tests.forEach(test => {
    const result = {
        x: Math.round(480 * ((test.clientX / 480) - 0.5)),
        y: Math.round(-360 * ((test.clientY / 360) - 0.5))
    };
    console.log(`Expected: ${test.expected}, Got: ${result}`);
});
```

### 11.3 可视化调试

```javascript
// 在舞台上显示鼠标位置
class DebugMouseOverlay {
    constructor(runtime) {
        this.runtime = runtime;
    }
    
    draw() {
        const mouse = this.runtime.ioDevices.mouse;
        const ctx = this.runtime.renderer.getContext();
        
        // 绘制十字线
        ctx.strokeStyle = 'red';
        ctx.beginPath();
        ctx.moveTo(mouse.getScratchX(), -180);
        ctx.lineTo(mouse.getScratchX(), 180);
        ctx.moveTo(-240, mouse.getScratchY());
        ctx.lineTo(240, mouse.getScratchY());
        ctx.stroke();
    }
}
```

---

## 十二、总结

### 12.1 核心要点

1. **双坐标系**：浏览器使用客户端坐标系，Scratch 使用舞台坐标系
2. **公式转换**：
   - X: `scratchX = 480 * ((clientX / canvasWidth) - 0.5)`
   - Y: `scratchY = -360 * ((clientY / canvasHeight) - 0.5)`
3. **Y轴反转**：浏览器 Y 轴向下，Scratch Y 轴向上
4. **边界限制**：使用 `MathUtil.clamp()` 限制在有效范围内
5. **点击检测**：通过渲染器的 `pick()` 方法检测点击的目标

### 12.2 性能考虑

- 鼠标移动事件使用节流
- 坐标转换结果可以缓存
- 避免在每一帧都进行完整的坐标转换

### 12.3 兼容性

- 需要考虑 HiDPI 屏幕
- 需要处理画布缩放
- 需要处理画布大小变化

通过正确实现鼠标坐标捕捉系统，Scratch VM 能够准确地将用户的鼠标输入转换为舞台坐标，使各种鼠标相关的积木和交互功能正常工作。
