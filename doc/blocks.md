# Scratch VM 积木文档

本项目是 Scratch 3.0 的虚拟机实现，包含了丰富的积木类别。以下是所有积木的分类列表：

---

## 一、积木基础概念

### 1.1 积木类型 (BlockType)

积木类型定义在 [block-type.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/extension-support/block-type.js) 中：

| 积木类型 | 说明 | 图标形状 |
|---------|------|---------|
| `Boolean` | 六边形布尔值报告积木 | ◇ |
| `button` | 特殊按钮（不是实际积木） | ▢ |
| `command` | 命令积木，执行动作 | ▮▮ |
| `conditional` | 条件积木，执行子分支 | ◇⋯ |
| `event` | 事件帽子积木 | ⌂ |
| `hat` | 帽子积木，开始脚本 | ⌂ |
| `loop` | 循环积木，重复执行子分支 | ○⋯ |
| `reporter` | 报告积木，返回数值或字符串 | ▭ |

### 1.2 参数类型 (ArgumentType)

参数类型定义在 [argument-type.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/extension-support/argument-type.js) 中：

| 参数类型 | 说明 | 输入方式 |
|---------|------|---------|
| `angle` | 角度数值 | 角度选择器 |
| `Boolean` | 布尔值 | 六边形占位符 |
| `color` | 颜色数值 | 颜色选择器 |
| `number` | 数值 | 文本输入框 |
| `string` | 字符串 | 文本输入框 |
| `matrix` | 矩阵 | 矩阵输入字段 |
| `note` | MIDI音符 | 钢琴选择器 |
| `image` | 图片 | 图片选择器 |

### 1.3 数据类型转换 (Cast)

Scratch 的数据类型转换规则定义在 [cast.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/util/cast.js) 中：

#### 1.3.1 转换为数字
- `NaN` 被视为 0
- 无法转换的字符串视为 0
- 例如：`1 + "hello"` → `1 + 0` = `1`

#### 1.3.2 转换为布尔值
- 以下字符串视为 `false`：`''`、`'0'`、`'false'`（不区分大小写）
- 其他字符串视为 `true`
- 数字 0 视为 `false`，其他数字视为 `true`

#### 1.3.3 比较规则
- 如果两个值都能转换为数字，按数字比较
- 否则按字符串比较（不区分大小写）

---

## 二、核心积木 (Core Blocks)

### 1. 运动类 (Motion)
文件：`src/blocks/scratch3_motion.js`

| opcode | 积木名称 | 积木类型 | 参数 | 解析代码 |
|--------|---------|---------|------|---------|
| `motion_movesteps` | 移动指定步数 | command | `STEPS: number` | `const steps = Cast.toNumber(args.STEPS); const radians = MathUtil.degToRad(90 - util.target.direction); const dx = steps * Math.cos(radians); const dy = steps * Math.sin(radians); util.target.setXY(util.target.x + dx, util.target.y + dy);` |
| `motion_gotoxy` | 移动到指定坐标 | command | `X: number, Y: number` | `const x = Cast.toNumber(args.X); const y = Cast.toNumber(args.Y); util.target.setXY(x, y);` |
| `motion_goto` | 移动到指定目标 | command | `TO: string` | `// 支持 '_mouse_'、'_random_' 或角色名称` |
| `motion_turnright` | 右转指定角度 | command | `DEGREES: number` | `const degrees = Cast.toNumber(args.DEGREES); util.target.setDirection(util.target.direction + degrees);` |
| `motion_turnleft` | 左转指定角度 | command | `DEGREES: number` | `const degrees = Cast.toNumber(args.DEGREES); util.target.setDirection(util.target.direction - degrees);` |
| `motion_pointindirection` | 面向指定方向 | command | `DIRECTION: number` | `const direction = Cast.toNumber(args.DIRECTION); util.target.setDirection(direction);` |
| `motion_pointtowards` | 面向指定目标 | command | `TOWARDS: string` | `// 支持 '_mouse_'、'_random_' 或角色名称` |
| `motion_glidesecstoxy` | 滑行到坐标 | command | `SECS: number, X: number, Y: number` | `// 使用 stackFrame 保存起始位置和计时器，逐步移动` |
| `motion_glideto` | 滑行到目标 | command | `SECS: number, TO: string` | `// 先获取目标坐标，再调用 glide` |
| `motion_ifonedgebounce` | 碰到边缘反弹 | command | 无 | `const bounds = util.target.getBounds(); // 检测边缘并反弹` |
| `motion_setrotationstyle` | 设置旋转方式 | command | `STYLE: string` | `util.target.setRotationStyle(args.STYLE);` |
| `motion_changexby` | x坐标增加 | command | `DX: number` | `util.target.setX(util.target.x + Cast.toNumber(args.DX));` |
| `motion_setx` | 设置x坐标 | command | `X: number` | `util.target.setX(Cast.toNumber(args.X));` |
| `motion_changeyby` | y坐标增加 | command | `DY: number` | `util.target.setY(util.target.y + Cast.toNumber(args.DY));` |
| `motion_sety` | 设置y坐标 | command | `Y: number` | `util.target.setY(Cast.toNumber(args.Y));` |
| `motion_xposition` | 报告x坐标 | reporter | 无 | `return util.target.x;` |
| `motion_yposition` | 报告y坐标 | reporter | 无 | `return util.target.y;` |
| `motion_direction` | 报告方向 | reporter | 无 | `return util.target.direction;` |

### 2. 外观类 (Looks)
文件：`src/blocks/scratch3_looks.js`

| opcode | 积木名称 | 积木类型 | 参数 | 解析代码 |
|--------|---------|---------|------|---------|
| `looks_say` | 说话 | command | `MESSAGE: string` | `// 更新气泡状态并渲染` |
| `looks_sayforsecs` | 说话指定秒数 | command | `MESSAGE: string, SECS: number` | `// 设置气泡，等待后清除` |
| `looks_think` | 思考 | command | `MESSAGE: string` | `// 类似 say，但显示思考气泡` |
| `looks_thinkforsecs` | 思考指定秒数 | command | `MESSAGE: string, SECS: number` | `// 设置思考气泡，等待后清除` |
| `looks_show` | 显示角色 | command | 无 | `util.target.setVisible(true);` |
| `looks_hide` | 隐藏角色 | command | 无 | `util.target.setVisible(false);` |
| `looks_switchcostumeto` | 切换造型 | command | `COSTUME: string` | `util.target.setCostume(args.COSTUME);` |
| `looks_switchbackdropto` | 切换背景 | command | `BACKDROP: string` | `util.target.setBackdrop(args.BACKDROP);` |
| `looks_switchbackdroptoandwait` | 切换背景并等待 | command | `BACKDROP: string` | `// 切换背景并等待加载完成` |
| `looks_nextcostume` | 下一个造型 | command | 无 | `util.target.goToNextCostume();` |
| `looks_nextbackdrop` | 下一个背景 | command | 无 | `util.target.goToNextBackdrop();` |
| `looks_changeeffectby` | 改变特效 | command | `EFFECT: string, VALUE: number` | `util.target.changeEffect(args.EFFECT, Cast.toNumber(args.VALUE));` |
| `looks_seteffectto` | 设置特效 | command | `EFFECT: string, VALUE: number` | `util.target.setEffect(args.EFFECT, Cast.toNumber(args.VALUE));` |
| `looks_cleargraphiceffects` | 清除特效 | command | 无 | `util.target.clearGraphicEffects();` |
| `looks_changesizeby` | 改变大小 | command | `CHANGE: number` | `util.target.changeSize(Cast.toNumber(args.CHANGE));` |
| `looks_setsizeto` | 设置大小 | command | `SIZE: number` | `util.target.size = Cast.toNumber(args.SIZE);` |
| `looks_gotofrontback` | 移到最前/最后 | command | `FRONTBACK: string` | `util.target.goToFront(); 或 util.target.goToBack();` |
| `looks_goforwardbackwardlayers` | 前移/后移多层 | command | `LAYERS: number` | `util.target.goForwardLayers(Cast.toNumber(args.LAYERS));` |
| `looks_size` | 报告大小 | reporter | 无 | `return util.target.size;` |
| `looks_costumenumbername` | 报告造型编号/名称 | reporter | `WHICH: string` | `// 返回 "number" 或 "name"` |
| `looks_backdropnumbername` | 报告背景编号/名称 | reporter | `WHICH: string` | `// 返回舞台背景信息` |

### 3. 声音类 (Sound)
文件：`src/blocks/scratch3_sound.js`

| opcode | 积木名称 | 积木类型 | 参数 | 解析代码 |
|--------|---------|---------|------|---------|
| `sound_play` | 播放声音 | command | `SOUND_MENU: string` | `util.target.playSound(args.SOUND_MENU);` |
| `sound_playuntildone` | 播放直到完成 | command | `SOUND_MENU: string` | `// 等待声音播放完成` |
| `sound_stopallsounds` | 停止所有声音 | command | 无 | `this.runtime.audioEngine.stopAllSounds();` |
| `sound_seteffectto` | 设置声音特效 | command | `EFFECT: string, VALUE: number` | `util.target.soundEffects[effect] = value;` |
| `sound_changeeffectby` | 改变声音特效 | command | `EFFECT: string, VALUE: number` | `util.target.soundEffects[effect] += value;` |
| `sound_cleareffects` | 清除声音特效 | command | 无 | `// 重置 pitch 和 pan 为 0` |
| `sound_setvolumeto` | 设置音量 | command | `VOLUME: number` | `util.target.volume = Cast.toNumber(args.VOLUME);` |
| `sound_changevolumeby` | 改变音量 | command | `VOLUME: number` | `util.target.changeVolume(Cast.toNumber(args.VOLUME));` |
| `sound_volume` | 报告音量 | reporter | 无 | `return util.target.volume;` |

### 4. 事件类 (Events)
文件：`src/blocks/scratch3_event.js`

| opcode | 积木名称 | 积木类型 | 参数 | 解析代码 |
|--------|---------|---------|------|---------|
| `event_whenflagclicked` | 当绿旗被点击时 | hat | 无 | `// 由 Runtime.greenFlag() 触发` |
| `event_whenkeypressed` | 当按下指定键时 | hat | `KEY_OPTION: string` | `// 由 KEY_PRESSED 事件触发` |
| `event_whenthisspriteclicked` | 当角色被点击时 | hat | 无 | `// 由舞台点击事件触发` |
| `event_whentouchingobject` | 当碰到对象时 | hat | `TOUCHINGOBJECTMENU: string` | `return util.target.isTouchingObject(args.TOUCHINGOBJECTMENU);` |
| `event_whenstageclicked` | 当舞台被点击时 | hat | 无 | `// 由舞台点击事件触发` |
| `event_whenbackdropswitchesto` | 当背景切换时 | hat | `BACKDROP: string` | `// 由背景切换事件触发` |
| `event_whengreaterthan` | 当变量大于指定值时 | hat | `WHENGREATERTHANMENU: string, VALUE: number` | `// 支持 'timer' 和 'loudness'` |
| `event_whenbroadcastreceived` | 当接收到广播时 | hat | `BROADCAST_OPTION: string` | `// 由 broadcast 积木触发` |
| `event_broadcast` | 广播消息 | command | `BROADCAST_OPTION: string` | `util.startHats('event_whenbroadcastreceived', {BROADCAST_OPTION: broadcastOption});` |
| `event_broadcastandwait` | 广播并等待 | command | `BROADCAST_OPTION: string` | `// 启动广播线程并等待完成` |

### 5. 控制类 (Control)
文件：`src/blocks/scratch3_control.js`

| opcode | 积木名称 | 积木类型 | 参数 | 解析代码 |
|--------|---------|---------|------|---------|
| `control_wait` | 等待指定秒数 | command | `DURATION: number` | `// 使用 stackTimer 等待` |
| `control_wait_until` | 等待直到条件成立 | command | `CONDITION: boolean` | `if (!Cast.toBoolean(args.CONDITION)) util.yield();` |
| `control_repeat` | 重复执行指定次数 | loop | `TIMES: number` | `util.stackFrame.loopCounter--; if (util.stackFrame.loopCounter >= 0) util.startBranch(1, true);` |
| `control_repeat_until` | 重复直到条件成立 | loop | `CONDITION: boolean` | `if (!Cast.toBoolean(args.CONDITION)) util.startBranch(1, true);` |
| `control_while` | 当条件成立时重复 | loop | `CONDITION: boolean` | `if (Cast.toBoolean(args.CONDITION)) util.startBranch(1, true);` |
| `control_forever` | 永远重复执行 | loop | 无 | `util.startBranch(1, true);` |
| `control_if` | 如果条件成立则执行 | conditional | `CONDITION: boolean` | `if (Cast.toBoolean(args.CONDITION)) util.startBranch(1, false);` |
| `control_if_else` | 如果...否则... | conditional | `CONDITION: boolean` | `if (Cast.toBoolean(args.CONDITION)) util.startBranch(1, false); else util.startBranch(2, false);` |
| `control_stop` | 停止脚本 | command | `STOP_OPTION: string` | `// 支持 'all'、'this script'、'other scripts in sprite'` |
| `control_create_clone_of` | 创建克隆体 | command | `CLONE_OPTION: string` | `const newClone = cloneTarget.makeClone(); this.runtime.addTarget(newClone);` |
| `control_start_as_clone` | 当作为克隆体启动时 | hat | 无 | `// 克隆体创建时触发` |
| `control_delete_this_clone` | 删除此克隆体 | command | 无 | `if (!util.target.isOriginal) this.runtime.disposeTarget(util.target);` |
| `control_get_counter` | 获取计数器值 | reporter | 无 | `return this._counter;` |
| `control_incr_counter` | 增加计数器 | command | 无 | `this._counter++;` |
| `control_clear_counter` | 清除计数器 | command | 无 | `this._counter = 0;` |

### 6. 侦测类 (Sensing)
文件：`src/blocks/scratch3_sensing.js`

| opcode | 积木名称 | 积木类型 | 参数 | 解析代码 |
|--------|---------|---------|------|---------|
| `sensing_touchingobject` | 是否碰到对象 | Boolean | `TOUCHINGOBJECTMENU: string` | `return util.target.isTouchingObject(args.TOUCHINGOBJECTMENU);` |
| `sensing_touchingcolor` | 是否碰到颜色 | Boolean | `COLOR: color` | `return util.target.isTouchingColor(Cast.toRgbColorList(args.COLOR));` |
| `sensing_coloristouchingcolor` | 颜色是否碰到颜色 | Boolean | `COLOR: color, COLOR2: color` | `return util.target.colorIsTouchingColor(targetColor, maskColor);` |
| `sensing_distanceto` | 到指定对象的距离 | reporter | `DISTANCETOMENU: string` | `// 计算到目标的距离` |
| `sensing_timer` | 计时器时间 | reporter | 无 | `return util.ioQuery('clock', 'projectTimer');` |
| `sensing_resettimer` | 重置计时器 | command | 无 | `this._timer.reset();` |
| `sensing_of` | 获取对象属性 | reporter | `PROPERTY: string, OBJECT: string` | `// 获取指定对象的属性值` |
| `sensing_mousex` | 鼠标x坐标 | reporter | 无 | `return util.ioQuery('mouse', 'getScratchX');` |
| `sensing_mousey` | 鼠标y坐标 | reporter | 无 | `return util.ioQuery('mouse', 'getScratchY');` |
| `sensing_setdragmode` | 设置拖拽模式 | command | `DRAG_MODE: string` | `util.target.setDragMode(args.DRAG_MODE);` |
| `sensing_mousedown` | 鼠标是否按下 | Boolean | 无 | `return util.ioQuery('mouse', 'isDown');` |
| `sensing_keypressed` | 按键是否按下 | Boolean | `KEY_OPTION: string` | `return util.ioQuery('keyboard', 'isKeyPressed', [key]);` |
| `sensing_current` | 当前时间/日期 | reporter | `CURRENTMENU: string` | `// 返回年、月、日、时、分、秒等` |
| `sensing_dayssince2000` | 自2000年以来的天数 | reporter | 无 | `// 计算从2000年1月1日至今的天数` |
| `sensing_loudness` | 音量 | reporter | 无 | `return this.runtime.audioEngine.getLoudness();` |
| `sensing_loud` | 是否大声 | Boolean | 无 | `return this.runtime.audioEngine.getLoudness() > 10;` |
| `sensing_answer` | 回答的内容 | reporter | 无 | `return this._answer;` |
| `sensing_askandwait` | 询问并等待 | command | `QUESTION: string` | `return new Promise(resolve => { /* 等待用户回答 */ });` |
| `sensing_username` | 用户名 | reporter | 无 | `return util.ioQuery('user', 'getUsername');` |

### 7. 运算类 (Operators)
文件：`src/blocks/scratch3_operators.js`

| opcode | 积木名称 | 积木类型 | 参数 | 解析代码 |
|--------|---------|---------|------|---------|
| `operator_add` | 加法 | reporter | `NUM1: number, NUM2: number` | `return Cast.toNumber(args.NUM1) + Cast.toNumber(args.NUM2);` |
| `operator_subtract` | 减法 | reporter | `NUM1: number, NUM2: number` | `return Cast.toNumber(args.NUM1) - Cast.toNumber(args.NUM2);` |
| `operator_multiply` | 乘法 | reporter | `NUM1: number, NUM2: number` | `return Cast.toNumber(args.NUM1) * Cast.toNumber(args.NUM2);` |
| `operator_divide` | 除法 | reporter | `NUM1: number, NUM2: number` | `return Cast.toNumber(args.NUM1) / Cast.toNumber(args.NUM2);` |
| `operator_lt` | 小于比较 | Boolean | `OPERAND1: any, OPERAND2: any` | `return Cast.compare(args.OPERAND1, args.OPERAND2) < 0;` |
| `operator_equals` | 等于比较 | Boolean | `OPERAND1: any, OPERAND2: any` | `return Cast.compare(args.OPERAND1, args.OPERAND2) === 0;` |
| `operator_gt` | 大于比较 | Boolean | `OPERAND1: any, OPERAND2: any` | `return Cast.compare(args.OPERAND1, args.OPERAND2) > 0;` |
| `operator_and` | 与运算 | Boolean | `OPERAND1: boolean, OPERAND2: boolean` | `return Cast.toBoolean(args.OPERAND1) && Cast.toBoolean(args.OPERAND2);` |
| `operator_or` | 或运算 | Boolean | `OPERAND1: boolean, OPERAND2: boolean` | `return Cast.toBoolean(args.OPERAND1) || Cast.toBoolean(args.OPERAND2);` |
| `operator_not` | 非运算 | Boolean | `OPERAND: boolean` | `return !Cast.toBoolean(args.OPERAND);` |
| `operator_random` | 取随机数 | reporter | `FROM: number, TO: number` | `// 返回指定范围内的随机数` |
| `operator_join` | 连接字符串 | reporter | `STRING1: string, STRING2: string` | `return Cast.toString(args.STRING1) + Cast.toString(args.STRING2);` |
| `operator_letter_of` | 获取字符 | reporter | `STRING: string, LETTER: number` | `return str.charAt(index);` |
| `operator_length` | 字符串长度 | reporter | `STRING: string` | `return Cast.toString(args.STRING).length;` |
| `operator_contains` | 字符串是否包含 | Boolean | `STRING1: string, STRING2: string` | `return format(args.STRING1).includes(format(args.STRING2));` |
| `operator_mod` | 取余数 | reporter | `NUM1: number, NUM2: number` | `let result = n % modulus; if (result / modulus < 0) result += modulus;` |
| `operator_round` | 四舍五入 | reporter | `NUM: number` | `return Math.round(Cast.toNumber(args.NUM));` |
| `operator_mathop` | 数学函数 | reporter | `OPERATOR: string, NUM: number` | `// 支持 abs、floor、sqrt、sin、cos 等` |

### 8. 变量类 (Data)
文件：`src/blocks/scratch3_data.js`

| opcode | 积木名称 | 积木类型 | 参数 | 解析代码 |
|--------|---------|---------|------|---------|
| `data_variable` | 报告变量值 | reporter | `VARIABLE: variable` | `return util.target.lookupOrCreateVariable(id, name).value;` |
| `data_setvariableto` | 设置变量值 | command | `VARIABLE: variable, VALUE: any` | `variable.value = args.VALUE;` |
| `data_changevariableby` | 变量值增加 | command | `VARIABLE: variable, VALUE: number` | `variable.value = castedValue + dValue;` |
| `data_showvariable` | 显示变量 | command | `VARIABLE: variable` | `this.changeMonitorVisibility(args.VARIABLE.id, true);` |
| `data_hidevariable` | 隐藏变量 | command | `VARIABLE: variable` | `this.changeMonitorVisibility(args.VARIABLE.id, false);` |
| `data_listcontents` | 列表内容 | reporter | `LIST: list` | `// 返回列表项的字符串表示` |
| `data_addtolist` | 添加到列表 | command | `ITEM: any, LIST: list` | `list.value.push(args.ITEM);` |
| `data_deleteoflist` | 删除列表项 | command | `INDEX: number, LIST: list` | `list.value.splice(index - 1, 1);` |
| `data_deletealloflist` | 删除所有项 | command | `LIST: list` | `list.value = [];` |
| `data_insertatlist` | 在指定位置插入 | command | `ITEM: any, INDEX: number, LIST: list` | `list.value.splice(index - 1, 0, args.ITEM);` |
| `data_replaceitemoflist` | 替换列表项 | command | `ITEM: any, INDEX: number, LIST: list` | `list.value[index - 1] = args.ITEM;` |
| `data_itemoflist` | 获取指定项 | reporter | `INDEX: number, LIST: list` | `return list.value[index - 1];` |
| `data_itemnumoflist` | 获取项的位置 | reporter | `ITEM: any, LIST: list` | `return list.value.indexOf(args.ITEM) + 1;` |
| `data_lengthoflist` | 列表长度 | reporter | `LIST: list` | `return list.value.length;` |
| `data_listcontainsitem` | 列表是否包含项 | Boolean | `ITEM: any, LIST: list` | `return list.value.includes(args.ITEM);` |
| `data_showlist` | 显示列表 | command | `LIST: list` | `this.changeMonitorVisibility(args.LIST.id, true);` |
| `data_hidelist` | 隐藏列表 | command | `LIST: list` | `this.changeMonitorVisibility(args.LIST.id, false);` |

### 9. 自定义积木 (Procedures)
文件：`src/blocks/scratch3_procedures.js`

支持创建自定义积木和带参数的自定义积木。

---

## 三、扩展积木 (Extensions)

### 1. 画笔类 (Pen)
文件：`src/extensions/scratch3_pen/index.js`

| opcode | 积木名称 | 积木类型 | 参数 | 解析代码 |
|--------|---------|---------|------|---------|
| `clear` | 全部擦除 | command | 无 | `this.penLayer.clear();` |
| `stamp` | 盖章 | command | 无 | `// 将当前造型印到画笔层` |
| `penDown` | 落笔 | command | 无 | `this.penDown = true;` |
| `penUp` | 抬笔 | command | 无 | `this.penDown = false;` |
| `setPenColorToColor` | 设置画笔颜色 | command | `COLOR: color` | `this.penColor = Cast.toRgbColorList(args.COLOR);` |
| `changePenColorParamBy` | 改变颜色参数 | command | `COLOR_PARAM: string, VALUE: number` | `// 改变色相/饱和度/亮度` |
| `setPenColorParamTo` | 设置颜色参数 | command | `COLOR_PARAM: string, VALUE: number` | `// 设置色相/饱和度/亮度` |
| `changePenSizeBy` | 改变画笔粗细 | command | `CHANGE: number` | `this.penSize += Cast.toNumber(args.CHANGE);` |
| `setPenSizeTo` | 设置画笔粗细 | command | `SIZE: number` | `this.penSize = Cast.toNumber(args.SIZE);` |

---

## 四、文件结构
```
src/
├── blocks/                    # 核心积木
│   ├── scratch3_control.js
│   ├── scratch3_data.js
│   ├── scratch3_event.js
│   ├── scratch3_looks.js
│   ├── scratch3_motion.js
│   ├── scratch3_operators.js
│   ├── scratch3_procedures.js
│   ├── scratch3_sensing.js
│   └── scratch3_sound.js
├── extensions/                # 扩展积木
│   └── scratch3_pen/
├── extension-support/       # 扩展支持
│   ├── block-type.js    # 积木类型定义
│   └── argument-type.js # 参数类型定义
└── util/                   # 工具函数
    └── cast.js           # 数据类型转换
```

---

## 五、积木执行流程

```
┌─────────────────────────────────────────────────────────────┐
│                    积木执行流程                              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  1. 解析积木 JSON                                          │
│     - opcode → 操作码                                      │
│     - inputs → 输入参数                                     │
│     - fields → 字段值                                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  2. 参数类型转换                                            │
│     - Cast.toNumber()                                      │
│     - Cast.toBoolean()                                     │
│     - Cast.toString()                                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  3. 执行积木函数                                            │
│     - 从 getPrimitives() 获取对应函数                        │
│     - 传入 args 和 util 参数                                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  4. 更新目标状态                                            │
│     - util.target.x, y, direction                          │
│     - util.target.visible, size                            │
│     - 触发重绘事件                                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  5. 处理控制流                                              │
│     - util.startBranch() → 执行子分支                       │
│     - util.yield() → 让出执行权                             │
│     - util.stackFrame → 保存执行状态                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 六、关键 API 说明

### 6.1 util 对象

| 属性/方法 | 说明 |
|----------|------|
| `util.target` | 当前执行积木的目标（角色或舞台） |
| `util.runtime` | Runtime 实例 |
| `util.stackFrame` | 当前栈帧，用于保存执行状态 |
| `util.startBranch(index, loop)` | 启动子分支执行 |
| `util.yield()` | 让出执行权，等待下一帧 |
| `util.yieldTick()` | 让出执行权，等待下一个 tick |
| `util.stopAll()` | 停止所有脚本 |
| `util.stopThisScript()` | 停止当前脚本 |
| `util.ioQuery(service, func, args)` | 查询 IO 设备 |

### 6.2 Cast 工具类

| 方法 | 说明 |
|------|------|
| `Cast.toNumber(value)` | 转换为数字 |
| `Cast.toBoolean(value)` | 转换为布尔值 |
| `Cast.toString(value)` | 转换为字符串 |
| `Cast.toRgbColorList(value)` | 转换为 RGB 颜色数组 |
| `Cast.compare(a, b)` | 比较两个值 |
| `Cast.isInt(value)` | 判断是否为整数 |
