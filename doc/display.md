# Scratch VM 舞台渲染实现指南

## 一、渲染架构概述

Scratch VM 的舞台渲染采用分层架构，将渲染逻辑委托给外部渲染器（如 scratch-render）处理。

### 1.1 渲染层次结构

| 层级 | 名称 | 说明 | 顺序 |
|------|------|------|------|
| 1 | BACKGROUND_LAYER | 舞台背景层 | 最底层 |
| 2 | VIDEO_LAYER | 视频输入层 | 背景之上 |
| 3 | PEN_LAYER | 画笔层 | 视频之上 |
| 4 | SPRITE_LAYER | 角色层 | 最顶层 |

### 1.2 核心组件

| 组件 | 文件 | 职责 |
|------|------|------|
| RenderedTarget | [rendered-target.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/sprites/rendered-target.js) | 管理角色/舞台的渲染状态 |
| StageLayering | [stage-layering.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/engine/stage-layering.js) | 定义图层顺序常量 |
| Runtime | [runtime.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/engine/runtime.js) | 协调渲染器和目标 |

---

## 二、坐标系统

### 2.1 Scratch 坐标系统

```
         Y: 180 (顶部)
           ↑
           |
  X: -240  |  X: 240
    ┌──────┼──────┐
    │      │      │
    │   ★  │      │  ← (0, 0) 原点
    │      │      │
    └──────┼──────┘
           |
           ↓
         Y: -180 (底部)
```

**关键参数**：
- 舞台宽度：480 像素（X: -240 ~ 240）
- 舞台高度：360 像素（Y: -180 ~ 180）
- 原点：舞台中心 (0, 0)

### 2.2 坐标转换流程

```
用户输入 (Scratch坐标)
        ↓
  setXY(x, y)
        ↓
  renderer.getFencedPositionOfDrawable()  ← 边界检测
        ↓
  renderer.updateDrawablePosition()       ← 发送到渲染器
        ↓
  requestRedraw()                         ← 请求重绘
```

---

## 三、渲染流程实现

### 3.1 创建可绘制对象

```javascript
// 在 RenderedTarget 初始化时调用
initDrawable(layerGroup) {
    if (this.renderer) {
        this.drawableID = this.renderer.createDrawable(layerGroup);
    }
    // 如果是克隆体，启动帽子脚本
    if (!this.isOriginal) {
        this.runtime.startHats('control_start_as_clone', null, this);
    }
}
```

### 3.2 更新位置

```javascript
setXY(x, y, force) {
    // 舞台不能移动
    if (this.isStage) return;
    // 拖拽时除非强制否则不能移动
    if (this.dragging && !force) return;
    
    if (this.renderer) {
        // 获取围栏位置（防止角色移出舞台）
        const position = this.renderer.getFencedPositionOfDrawable(this.drawableID, [x, y]);
        this.x = position[0];
        this.y = position[1];
        
        // 更新渲染器中的位置
        this.renderer.updateDrawablePosition(this.drawableID, position);
        
        if (this.visible) {
            this.emit(RenderedTarget.EVENT_TARGET_VISUAL_CHANGE, this);
            this.runtime.requestRedraw();
        }
    } else {
        this.x = x;
        this.y = y;
    }
    
    this.emit(RenderedTarget.EVENT_TARGET_MOVED, this, oldX, oldY, force);
    this.runtime.requestTargetsUpdate(this);
}
```

### 3.3 更新方向和缩放

```javascript
setDirection(direction) {
    if (this.isStage) return;
    if (!isFinite(direction)) return;
    
    // 保持方向在 -179 到 180 范围内
    this.direction = MathUtil.wrapClamp(direction, -179, 180);
    
    if (this.renderer) {
        // 获取渲染方向和缩放（考虑旋转样式）
        const {direction: renderedDirection, scale} = this._getRenderedDirectionAndScale();
        this.renderer.updateDrawableDirectionScale(this.drawableID, renderedDirection, scale);
        
        if (this.visible) {
            this.emit(RenderedTarget.EVENT_TARGET_VISUAL_CHANGE, this);
            this.runtime.requestRedraw();
        }
    }
    this.runtime.requestTargetsUpdate(this);
}

// 计算实际渲染方向和缩放（考虑旋转样式）
_getRenderedDirectionAndScale() {
    let finalDirection = this.direction;
    let finalScale = [this.size, this.size];
    
    if (this.rotationStyle === 'dont rotate') {
        // 不旋转：强制方向为 90°
        finalDirection = 90;
    } else if (this.rotationStyle === 'left-right') {
        // 左右翻转：方向固定为 90°，根据方向决定水平翻转
        finalDirection = 90;
        const scaleFlip = (this.direction < 0) ? -1 : 1;
        finalScale = [scaleFlip * this.size, this.size];
    }
    
    return {direction: finalDirection, scale: finalScale};
}
```

### 3.4 批量更新属性

```javascript
updateAllDrawableProperties() {
    if (this.renderer) {
        const {direction, scale} = this._getRenderedDirectionAndScale();
        
        // 更新位置
        this.renderer.updateDrawablePosition(this.drawableID, [this.x, this.y]);
        // 更新方向和缩放
        this.renderer.updateDrawableDirectionScale(this.drawableID, direction, scale);
        // 更新可见性
        this.renderer.updateDrawableVisible(this.drawableID, this.visible);
        
        // 更新造型
        const costume = this.getCostumes()[this.currentCostume];
        this.renderer.updateDrawableSkinId(this.drawableID, costume.skinId);
        
        // 更新所有特效
        for (const effectName in this.effects) {
            this.renderer.updateDrawableEffect(this.drawableID, effectName, this.effects[effectName]);
        }
        
        if (this.visible) {
            this.emit(RenderedTarget.EVENT_TARGET_VISUAL_CHANGE, this);
            this.runtime.requestRedraw();
        }
    }
    this.runtime.requestTargetsUpdate(this);
}
```

---

## 四、避免渲染偏移的关键技巧

### 4.1 使用围栏位置

**问题**：直接设置坐标可能导致角色移出舞台边界

**解决方案**：使用 `getFencedPositionOfDrawable` 方法

```javascript
// 正确做法：使用围栏位置
const position = this.renderer.getFencedPositionOfDrawable(this.drawableID, [x, y]);
this.x = position[0];
this.y = position[1];
this.renderer.updateDrawablePosition(this.drawableID, position);

// 错误做法：直接设置（可能导致偏移）
// this.x = x;
// this.y = y;
// this.renderer.updateDrawablePosition(this.drawableID, [x, y]);
```

### 4.2 保持坐标在有效范围

```javascript
// 在 setXY 中确保坐标在舞台范围内
const stageWidth = this.runtime.constructor.STAGE_WIDTH;  // 480
const stageHeight = this.runtime.constructor.STAGE_HEIGHT; // 360

// X 范围: -240 ~ 240
// Y 范围: -180 ~ 180
```

### 4.3 使用 keepInFence 方法

```javascript
// 将位置限制在围栏内
keepInFence(newX, newY, optFence) {
    let fence = optFence;
    if (!fence) {
        fence = {
            left: -this.runtime.constructor.STAGE_WIDTH / 2,   // -240
            right: this.runtime.constructor.STAGE_WIDTH / 2,    // 240
            top: this.runtime.constructor.STAGE_HEIGHT / 2,     // 180
            bottom: -this.runtime.constructor.STAGE_HEIGHT / 2  // -180
        };
    }
    
    const bounds = this.getBounds();
    if (!bounds) return;
    
    // 调整边界到目标位置
    bounds.left += (newX - this.x);
    bounds.right += (newX - this.x);
    bounds.top += (newY - this.y);
    bounds.bottom += (newY - this.y);
    
    // 计算需要移动的距离
    let dx = 0;
    let dy = 0;
    
    if (bounds.left < fence.left) {
        dx += fence.left - bounds.left;
    }
    if (bounds.right > fence.right) {
        dx += fence.right - bounds.right;
    }
    if (bounds.top > fence.top) {
        dy += fence.top - bounds.top;
    }
    if (bounds.bottom < fence.bottom) {
        dy += fence.bottom - bounds.bottom;
    }
    
    return [newX + dx, newY + dy];
}
```

### 4.4 正确处理旋转样式

**问题**：旋转样式会影响实际渲染方向，不正确处理会导致视觉偏移

**解决方案**：使用 `_getRenderedDirectionAndScale()` 方法

```javascript
// 获取实际渲染参数
const {direction, scale} = this._getRenderedDirectionAndScale();

// 更新渲染器
this.renderer.updateDrawableDirectionScale(this.drawableID, direction, scale);
```

### 4.5 确保尺寸限制

```javascript
setSize(size) {
    if (this.isStage) return;
    
    if (this.renderer) {
        // 获取当前造型尺寸
        const costumeSize = this.renderer.getCurrentSkinSize(this.drawableID);
        const origW = costumeSize[0];
        const origH = costumeSize[1];
        
        // 计算最小和最大缩放
        const minScale = Math.min(1, Math.max(5 / origW, 5 / origH));
        const maxScale = Math.min(
            (1.5 * this.runtime.constructor.STAGE_WIDTH) / origW,
            (1.5 * this.runtime.constructor.STAGE_HEIGHT) / origH
        );
        
        // 限制尺寸在有效范围内
        this.size = MathUtil.clamp(size / 100, minScale, maxScale) * 100;
        
        const {direction, scale} = this._getRenderedDirectionAndScale();
        this.renderer.updateDrawableDirectionScale(this.drawableID, direction, scale);
        
        if (this.visible) {
            this.emit(RenderedTarget.EVENT_TARGET_VISUAL_CHANGE, this);
            this.runtime.requestRedraw();
        }
    }
    this.runtime.requestTargetsUpdate(this);
}
```

### 4.6 正确初始化可绘制对象

**问题**：克隆体创建时如果不初始化 drawable 会导致渲染偏移

**解决方案**：在克隆时调用 `initDrawable` 和 `updateAllDrawableProperties`

```javascript
makeClone() {
    // ... 克隆逻辑 ...
    
    // 初始化 drawable
    newClone.initDrawable(StageLayering.SPRITE_LAYER);
    // 更新所有属性
    newClone.updateAllDrawableProperties();
    
    return newClone;
}
```

---

## 五、常见偏移问题及解决方案

### 5.1 问题：角色位置偏移

**原因**：直接设置 x/y 而未使用围栏位置

**解决方案**：

```javascript
// 错误
this.x = x;
this.y = y;

// 正确
const position = this.renderer.getFencedPositionOfDrawable(this.drawableID, [x, y]);
this.x = position[0];
this.y = position[1];
this.renderer.updateDrawablePosition(this.drawableID, position);
```

### 5.2 问题：旋转方向错误

**原因**：未考虑旋转样式导致实际渲染方向与预期不符

**解决方案**：

```javascript
// 错误
this.renderer.updateDrawableDirectionScale(this.drawableID, this.direction, [this.size, this.size]);

// 正确
const {direction, scale} = this._getRenderedDirectionAndScale();
this.renderer.updateDrawableDirectionScale(this.drawableID, direction, scale);
```

### 5.3 问题：克隆体位置错误

**原因**：克隆时未正确复制原始角色属性

**解决方案**：

```javascript
makeClone() {
    // 复制所有属性
    newClone.x = this.x;
    newClone.y = this.y;
    newClone.direction = this.direction;
    newClone.draggable = this.draggable;
    newClone.visible = this.visible;
    newClone.size = this.size;
    newClone.currentCostume = this.currentCostume;
    newClone.rotationStyle = this.rotationStyle;
    newClone.effects = Clone.simple(this.effects);
    
    // 初始化并更新
    newClone.initDrawable(StageLayering.SPRITE_LAYER);
    newClone.updateAllDrawableProperties();
}
```

### 5.4 问题：舞台边缘检测错误

**原因**：使用硬编码的边界值而非动态获取

**解决方案**：

```javascript
// 错误
if (x < -240 || x > 240 || y < -180 || y > 180) { ... }

// 正确
const stageWidth = this.runtime.constructor.STAGE_WIDTH;
const stageHeight = this.runtime.constructor.STAGE_HEIGHT;

if (x < -stageWidth / 2 || x > stageWidth / 2 || 
    y < -stageHeight / 2 || y > stageHeight / 2) { ... }
```

---

## 六、渲染性能优化

### 6.1 批量更新属性

当多个属性同时改变时，使用 `updateAllDrawableProperties()` 避免多次渲染调用：

```javascript
// 多个属性变更时使用批量更新
const clone = sprite.makeClone();
clone.x = 100;
clone.y = 50;
clone.size = 150;
clone.updateAllDrawableProperties();  // 一次调用更新所有属性
```

### 6.2 延迟重绘

使用 `requestRedraw()` 而非立即重绘，让渲染器优化批量操作：

```javascript
// requestRedraw 会将重绘请求加入队列
this.runtime.requestRedraw();
```

### 6.3 隐藏时跳过渲染

```javascript
if (this.visible) {
    this.emit(RenderedTarget.EVENT_TARGET_VISUAL_CHANGE, this);
    this.runtime.requestRedraw();
}
```

---

## 七、图层管理

### 7.1 图层顺序操作

```javascript
// 移到最前面
goToFront() {
    if (this.renderer) {
        this.renderer.setDrawableOrder(this.drawableID, Infinity, StageLayering.SPRITE_LAYER);
    }
    this.runtime.setExecutablePosition(this, Infinity);
}

// 移到最后面
goToBack() {
    if (this.renderer) {
        this.renderer.setDrawableOrder(this.drawableID, -Infinity, StageLayering.SPRITE_LAYER, false);
    }
    this.runtime.setExecutablePosition(this, -Infinity);
}

// 前移/后移指定层数
goForwardLayers(nLayers) {
    if (this.renderer) {
        this.renderer.setDrawableOrder(this.drawableID, nLayers, StageLayering.SPRITE_LAYER, true);
    }
    this.runtime.moveExecutable(this, nLayers);
}
```

### 7.2 图层组顺序

```javascript
// 图层组顺序（从后到前）
const layerGroups = [
    StageLayering.BACKGROUND_LAYER,  // 背景
    StageLayering.VIDEO_LAYER,       // 视频
    StageLayering.PEN_LAYER,         // 画笔
    StageLayering.SPRITE_LAYER       // 角色
];
```

---

## 八、完整示例：创建并渲染角色

```javascript
// 1. 创建角色
const sprite = new Sprite(runtime);
sprite.name = "MySprite";

// 2. 添加造型
sprite.addCostumeAt({
    name: "costume1",
    bitmapResolution: 1,
    dataFormat: "svg",
    assetId: "abc123",
    md5ext: "abc123.svg",
    rotationCenterX: 47,
    rotationCenterY: 55
}, 0);

// 3. 创建渲染目标
const target = sprite.createClone();

// 4. 设置属性
target.x = 100;
target.y = 50;
target.size = 150;
target.direction = 90;
target.visible = true;

// 5. 初始化并渲染
target.initDrawable(StageLayering.SPRITE_LAYER);
target.updateAllDrawableProperties();

// 6. 添加到运行时
runtime.addTarget(target);
```

---

## 九、关键 API 总结

| 方法 | 说明 |
|------|------|
| `initDrawable(layerGroup)` | 初始化可绘制对象 |
| `setXY(x, y, force)` | 设置位置（带围栏检测） |
| `setDirection(direction)` | 设置方向 |
| `setSize(size)` | 设置尺寸（带范围限制） |
| `setVisible(visible)` | 设置可见性 |
| `setEffect(effectName, value)` | 设置特效 |
| `updateAllDrawableProperties()` | 批量更新所有属性 |
| `keepInFence(x, y, fence)` | 将位置限制在围栏内 |
| `goToFront()` | 移到最前面 |
| `goToBack()` | 移到最后面 |
| `requestRedraw()` | 请求重绘 |

---

## 十、调试技巧

### 10.1 检查坐标

```javascript
// 输出当前位置
console.log(`X: ${target.x}, Y: ${target.y}`);
console.log(`Direction: ${target.direction}`);
console.log(`Size: ${target.size}`);
```

### 10.2 检查边界

```javascript
const bounds = target.getBounds();
console.log(`Bounds:`, bounds);
```

### 10.3 检查渲染器状态

```javascript
if (target.renderer) {
    console.log("Renderer connected");
    console.log("Drawable ID:", target.drawableID);
} else {
    console.log("No renderer connected");
}
```

---

## 十一、总结

### 避免渲染偏移的核心要点：

1. **使用围栏位置**：通过 `getFencedPositionOfDrawable` 确保位置在舞台内
2. **正确处理旋转样式**：使用 `_getRenderedDirectionAndScale` 获取实际渲染参数
3. **克隆体正确初始化**：调用 `initDrawable` 和 `updateAllDrawableProperties`
4. **使用常量而非硬编码**：使用 `STAGE_WIDTH` 和 `STAGE_HEIGHT` 常量
5. **批量更新属性**：使用 `updateAllDrawableProperties` 减少渲染调用
6. **检查可见性**：隐藏的角色不需要触发重绘

通过遵循以上原则，可以确保角色渲染位置准确无误，避免偏移问题。
