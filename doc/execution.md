# Scratch VM 积木执行流程

## 一、执行架构概述

Scratch VM 的积木执行采用**线程式架构**，每个脚本运行在独立的线程中，由 Sequencer 统一调度。

### 1.1 核心组件

| 组件 | 文件 | 职责 |
|------|------|------|
| Sequencer | [sequencer.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/engine/sequencer.js) | 线程调度器，管理所有线程的执行 |
| Thread | [thread.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/engine/thread.js) | 单个脚本的执行上下文 |
| execute | [execute.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/engine/execute.js) | 执行单个积木 |
| BlockCached | [execute.js](#L162) | 积木的缓存表示，优化执行性能 |
| BlockUtility | [block-utility.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/engine/block-utility.js) | 提供执行工具函数 |

### 1.2 执行流程总览

```
┌─────────────────────────────────────────────────────────────────┐
│                    执行流程概览                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  1. 触发事件（绿旗、按键、广播等）                              │
│     → Runtime.startHats(opcode, params)                      │
└────────────────────────┬──────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. 创建线程                                                  │
│     → new Thread(topBlockId)                                 │
│     → thread.target = target                                 │
│     → thread.pushStack(topBlockId)                           │
└────────────────────────┬──────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  3. Sequencer 调度                                          │
│     → stepThreads() 遍历所有线程                              │
│     → stepThread(thread) 执行单个线程                        │
└────────────────────────┬──────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  4. 执行积木                                                  │
│     → execute(sequencer, thread)                            │
│     → BlockCached 获取缓存的积木信息                          │
│     → blockFunction(argValues, blockUtility)                 │
└────────────────────────┬──────────────────────────────────────┘
                         │
                         ▼
┌───────────────────────────────────────────────────────────────┐
│  5. 处理返回值                                              │
│     → Promise → STATUS_PROMISE_WAIT                         │
│     → 普通值 → handleReport()                               │
└────────────────────────┬──────────────────────────────────────┘
                         │
                         ▼
┌───────────────────────────────────────────────────────────────┐
│  6. 控制流处理                                               │
│     → 普通积木: goToNextBlock()                              │
│     → 循环/条件: startBranch() → pushStack(branchId)        │
└───────────────────────────────────────────────────────────────┘
```

---

## 二、线程管理

### 2.1 Thread 类结构

```javascript
class Thread {
    constructor(firstBlock) {
        this.topBlock = firstBlock;      // 顶层积木ID
        this.stack = [];                 // 执行栈
        this.stackFrames = [];           // 栈帧（存储执行上下文）
        this.status = Thread.STATUS_RUNNING;  // 线程状态
        this.target = null;              // 所属目标（角色/舞台）
        this.blockContainer = null;      // 积木容器
    }
}
```

### 2.2 线程状态

| 状态 | 值 | 说明 |
|------|-----|------|
| `STATUS_RUNNING` | 0 | 正常运行 |
| `STATUS_PROMISE_WAIT` | 1 | 等待 Promise 解析 |
| `STATUS_YIELD` | 2 | 主动让出执行权 |
| `STATUS_YIELD_TICK` | 3 | 单 tick 让出 |
| `STATUS_DONE` | 4 | 执行完成 |

### 2.3 栈帧结构 (_StackFrame)

```javascript
class _StackFrame {
    isLoop: false;           // 是否是循环
    warpMode: false;         // 是否加速模式
    justReported: null;      // 刚报告的值
    reporting: '';           // 正在等待的报告
    reported: null;          // 已报告的值（Promise时保存）
    waitingReporter: null;   // 等待中的报告器
    params: null;            // 过程参数
    executionContext: null;  // 执行上下文
}
```

---

## 三、执行调度流程

### 3.1 stepThreads - 线程调度主循环

```javascript
stepThreads() {
    const WORK_TIME = 0.75 * this.runtime.currentStepTime;  // 工作时间限制
    this.timer.start();
    
    while (
        this.runtime.threads.length > 0 &&        // 还有线程
        numActiveThreads > 0 &&                   // 有活跃线程
        this.timer.timeElapsed() < WORK_TIME &&   // 未超时
        (this.runtime.turboMode || !this.runtime.redrawRequested)  // 加速模式或无需重绘
    ) {
        // 遍历所有线程
        for (let i = 0; i < threads.length; i++) {
            const activeThread = threads[i];
            
            if (activeThread.status === Thread.STATUS_RUNNING ||
                activeThread.status === Thread.STATUS_YIELD) {
                this.stepThread(activeThread);
            }
        }
        
        // 过滤已完成的线程
        // ...
    }
}
```

### 3.2 stepThread - 执行单个线程

```javascript
stepThread(thread) {
    let currentBlockId = thread.peekStack();
    
    while (currentBlockId = thread.peekStack()) {
        // 执行当前积木
        execute(this, thread);
        
        // 处理线程状态
        if (thread.status === Thread.STATUS_YIELD) {
            thread.status = Thread.STATUS_RUNNING;
            return;  // 让出执行权
        } else if (thread.status === Thread.STATUS_PROMISE_WAIT) {
            return;  // 等待 Promise
        } else if (thread.status === Thread.STATUS_YIELD_TICK) {
            return;  // 单 tick 让出
        }
        
        // 如果没有控制流变化，切换到下一个积木
        if (thread.peekStack() === currentBlockId) {
            thread.goToNextBlock();
        }
        
        // 处理栈弹出
        while (!thread.peekStack()) {
            thread.popStack();
            // 处理循环、等待等情况
        }
    }
}
```

---

## 四、积木执行核心流程

### 4.1 execute - 执行单个积木

```javascript
const execute = function (sequencer, thread) {
    const runtime = sequencer.runtime;
    
    // 获取当前积木
    const currentBlockId = thread.peekStack();
    let blockCached = BlocksExecuteCache.getCached(blockContainer, currentBlockId, BlockCached);
    
    // 获取操作列表
    const ops = blockCached._ops;
    const length = ops.length;
    
    // 遍历执行所有操作
    for (let i = 0; i < length; i++) {
        const lastOperation = i === length - 1;
        const opCached = ops[i];
        
        // 获取积木函数和参数
        const blockFunction = opCached._blockFunction;
        const argValues = opCached._argValues;
        
        // 执行积木函数
        const primitiveReportedValue = blockFunction(argValues, blockUtility);
        
        // 处理 Promise
        if (isPromise(primitiveReportedValue)) {
            handlePromise(primitiveReportedValue, sequencer, thread, opCached, lastOperation);
            break;
        } else if (thread.status === Thread.STATUS_RUNNING) {
            if (lastOperation) {
                handleReport(primitiveReportedValue, sequencer, thread, opCached, lastOperation);
            } else {
                // 将返回值传递给父积木
                const inputName = opCached._parentKey;
                const parentValues = opCached._parentValues;
                parentValues[inputName] = primitiveReportedValue;
            }
        }
    }
};
```

### 4.2 BlockCached - 积木缓存

BlockCached 是积木的优化表示，预计算执行顺序：

```javascript
class BlockCached {
    constructor(blockContainer, cached) {
        this.id = cached.id;
        this.opcode = cached.opcode;
        this.fields = cached.fields;
        this.inputs = cached.inputs;
        
        // 预计算操作列表
        this._ops = [];
        
        // 收集所有输入子积木
        for (const inputName in this._inputs) {
            const input = this._inputs[inputName];
            if (input.block) {
                const inputCached = BlocksExecuteCache.getCached(blockContainer, input.block, BlockCached);
                this._ops.push(...inputCached._ops);
                inputCached._parentKey = inputName;
                inputCached._parentValues = this._argValues;
            }
        }
        
        // 添加自身作为最后一个操作
        if (this._definedBlockFunction) {
            this._ops.push(this);
        }
    }
}
```

**执行顺序示例**：
```
"移动 10 步"积木
└── 输入: STEPS = (运算) 5 + 3
    ├── 输入: NUM1 = 5 (原始积木)
    └── 输入: NUM2 = 3 (原始积木)

操作列表: [NUM1, NUM2, 运算_add, motion_movesteps]
```

---

## 五、控制流处理

### 5.1 条件分支

```javascript
// control_if 积木执行
if (args.CONDITION) {
    util.startBranch(1, false);  // 执行分支1
}

// startBranch 实现
sequencer.stepToBranch(thread, branchNum, isLoop);
```

### 5.2 循环

```javascript
// control_repeat 积木执行
const times = Math.round(Cast.toNumber(args.TIMES));

if (typeof util.stackFrame.loopCounter === 'undefined') {
    util.stackFrame.loopCounter = times;  // 初始化循环计数器
}

util.stackFrame.loopCounter--;

if (util.stackFrame.loopCounter >= 0) {
    util.startBranch(1, true);  // isLoop = true
}
```

### 5.3 等待

```javascript
// control_wait 积木执行
if (util.stackTimerNeedsInit()) {
    const duration = Math.max(0, 1000 * Cast.toNumber(args.DURATION));
    util.startStackTimer(duration);
    util.yield();  // 让出执行权
} else if (!util.stackTimerFinished()) {
    util.yield();  // 继续等待
}
```

### 5.4 Promise 处理

```javascript
const handlePromise = (primitiveReportedValue, sequencer, thread, blockCached, lastOperation) => {
    // 设置线程状态为等待 Promise
    thread.status = Thread.STATUS_PROMISE_WAIT;
    
    // Promise 解析处理
    primitiveReportedValue.then(resolvedValue => {
        handleReport(resolvedValue, sequencer, thread, blockCached, lastOperation);
        
        if (lastOperation) {
            let nextBlockId;
            do {
                const popped = thread.popStack();
                nextBlockId = thread.target.blocks.getNextBlock(popped);
                if (nextBlockId !== null) break;
            } while (stackFrame !== null && !stackFrame.isLoop);
            
            thread.pushStack(nextBlockId);
        }
    }, rejectionReason => {
        log.warn('Primitive rejected promise: ', rejectionReason);
        thread.status = Thread.STATUS_RUNNING;
        thread.popStack();
    });
};
```

---

## 六、积木函数执行

### 6.1 积木函数签名

```javascript
// 积木函数接收两个参数
blockFunction(args, util)

// args: 参数对象，包含所有字段和输入的值
// util: BlockUtility 实例，提供执行上下文

// 示例：motion_movesteps
moveSteps(args, util) {
    const steps = Cast.toNumber(args.STEPS);
    const radians = MathUtil.degToRad(90 - util.target.direction);
    const dx = steps * Math.cos(radians);
    const dy = steps * Math.sin(radians);
    util.target.setXY(util.target.x + dx, util.target.y + dy);
}
```

### 6.2 BlockUtility 提供的方法

| 方法 | 说明 |
|------|------|
| `util.target` | 当前目标（角色/舞台） |
| `util.runtime` | Runtime 实例 |
| `util.stackFrame` | 当前栈帧 |
| `util.startBranch(index, isLoop)` | 启动分支执行 |
| `util.yield()` | 让出执行权 |
| `util.yieldTick()` | 让出一个 tick |
| `util.stopAll()` | 停止所有脚本 |
| `util.stopThisScript()` | 停止当前脚本 |
| `util.ioQuery(service, func, args)` | 查询 IO 设备 |
| `util.startHats(opcode, params)` | 启动帽子脚本 |

---

## 七、执行流程示例

### 7.1 简单脚本执行

```
脚本: 当绿旗被点击 → 移动 10 步 → 说 "Hello"

执行步骤:
1. Runtime.startHats('event_whenflagclicked')
2. 创建线程, pushStack('hatBlockId')
3. stepThread → execute(hatBlock)
   - hat 积木返回 true (边缘触发)
   - handleReport → 继续执行
4. goToNextBlock() → pushStack('motion_movesteps')
5. execute(motion_movesteps)
   - 执行 moveSteps()
   - 更新角色位置
6. goToNextBlock() → pushStack('looks_say')
7. execute(looks_say)
   - 执行 say()
   - 显示气泡
8. goToNextBlock() → 返回 null
9. popStack() → 栈为空
10. thread.status = STATUS_DONE
```

### 7.2 循环执行

```
脚本: 重复执行 3 次 → 移动 10 步

执行步骤:
1. pushStack('control_repeat')
2. execute(control_repeat)
   - 初始化 loopCounter = 3
   - loopCounter-- → 2
   - startBranch(1, true) → pushStack('motion_movesteps')
3. execute(motion_movesteps)
4. popStack → 回到 control_repeat
5. execute(control_repeat)
   - loopCounter-- → 1
   - startBranch(1, true) → pushStack('motion_movesteps')
6. ... 重复直到 loopCounter < 0
7. 循环结束，goToNextBlock()
```

### 7.3 等待执行

```
脚本: 等待 2 秒 → 移动 10 步

执行步骤:
1. pushStack('control_wait')
2. execute(control_wait)
   - 初始化定时器 (2000ms)
   - util.yield() → STATUS_YIELD
3. 下一个 tick: execute(control_wait)
   - 检查定时器未完成
   - util.yield() → STATUS_YIELD
4. ... 等待直到定时器完成
5. 定时器完成 → 继续
6. goToNextBlock() → pushStack('motion_movesteps')
```

---

## 八、性能优化

### 8.1 BlockCached 缓存

- 预计算操作列表，避免每次执行时动态遍历
- 缓存字段和输入值，减少重复计算
- 缓存 blockFunction 引用，避免动态查找

### 8.2 执行时间限制

```javascript
const WORK_TIME = 0.75 * this.runtime.currentStepTime;

while (this.timer.timeElapsed() < WORK_TIME) {
    // 执行线程
}
```

### 8.3 Warp Mode（加速模式）

```javascript
if (isWarpMode) {
    // 加速模式：不限制单个线程执行时间
    while (thread.warpTimer.timeElapsed() <= Sequencer.WARP_TIME) {
        execute(this, thread);
    }
}
```

### 8.4 栈帧复用

```javascript
// 使用对象池复用栈帧
const _stackFrameFreeList = [];

_StackFrame.create(warpMode) {
    const stackFrame = _stackFrameFreeList.pop();
    if (stackFrame) {
        stackFrame.warpMode = Boolean(warpMode);
        return stackFrame;
    }
    return new _StackFrame(warpMode);
}

_StackFrame.release(stackFrame) {
    _stackFrameFreeList.push(stackFrame.reset());
}
```

---

## 九、线程生命周期

```
创建线程
    ↓
pushStack(topBlock)
    ↓
stepThread (循环执行)
    ↓
├── 正常完成: popStack → 栈空 → STATUS_DONE
├── 遇到等待: yield → STATUS_YIELD → 下次继续
├── Promise等待: STATUS_PROMISE_WAIT → 解析后继续
└── 被停止: stopThisScript → STATUS_DONE
```

---

## 十、关键 API 总结

### 10.1 Sequencer

| 方法 | 说明 |
|------|------|
| `stepThreads()` | 调度所有线程 |
| `stepThread(thread)` | 执行单个线程 |
| `stepToBranch(thread, branchNum, isLoop)` | 跳转到分支 |
| `stepToProcedure(thread, procedureCode)` | 跳转到过程 |
| `retireThread(thread)` | 终止线程 |

### 10.2 Thread

| 方法 | 说明 |
|------|------|
| `pushStack(blockId)` | 入栈 |
| `popStack()` | 出栈 |
| `peekStack()` | 查看栈顶 |
| `goToNextBlock()` | 跳转到下一个积木 |
| `pushReportedValue(value)` | 保存报告值 |

### 10.3 BlockUtility

| 方法 | 说明 |
|------|------|
| `startBranch(index, isLoop)` | 启动分支 |
| `yield()` | 让出执行权 |
| `yieldTick()` | 让出一个 tick |
| `startStackTimer(duration)` | 启动栈定时器 |
| `stackTimerFinished()` | 检查定时器是否完成 |

---

## 十一、调试技巧

### 11.1 查看线程状态

```javascript
// 输出所有线程状态
for (const thread of runtime.threads) {
    console.log(`Thread: ${thread.topBlock}`);
    console.log(`Status: ${thread.status}`);
    console.log(`Stack: ${thread.stack}`);
}
```

### 11.2 查看当前执行的积木

```javascript
const currentBlockId = thread.peekStack();
const block = thread.target.blocks.getBlock(currentBlockId);
console.log(`Current block: ${block.opcode}`);
```

### 11.3 性能分析

```javascript
// 启用性能分析器
runtime.profiler = new Profiler();

// 查看执行统计
console.log(runtime.profiler.getStats());
```

---

## 十二、总结

### 执行流程核心要点：

1. **线程模型**：每个脚本是独立线程，由 Sequencer 调度
2. **栈式执行**：使用栈管理控制流（循环、条件、过程调用）
3. **操作列表优化**：BlockCached 预计算执行顺序，避免重复遍历
4. **异步支持**：支持 Promise 返回值，线程等待直到解析
5. **时间分片**：限制单帧执行时间，保证流畅性
6. **加速模式**：支持 warp mode，跳过时间限制

通过这种设计，Scratch VM 能够高效地执行复杂的脚本，同时保持良好的响应性和可扩展性。
