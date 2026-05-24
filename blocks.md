# Scratch VM 积木文档

本项目是 Scratch 3.0 的虚拟机实现，包含了丰富的积木类别。以下是所有积木的分类列表：

---

## 一、积木基础概念

### 1.1 积木类型 (BlockType)

积木类型定义在 [block-type.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/extension-support/block-type.js) 中：

| 积木类型 | 说明 |
|---------|------|
| `Boolean` | 六边形布尔值报告积木 |
| `button` | 特殊按钮（不是实际积木），用于创建变量等操作 |
| `command` | 命令积木，执行动作 |
| `conditional` | 条件积木，可能执行子分支，线程继续执行下一块 |
| `event` | 事件帽子积木，由其他代码触发执行 |
| `hat` | 帽子积木，条件性地开始积木栈 |
| `loop` | 循环积木，执行子分支后可能再次执行 |
| `reporter` | 报告积木，返回数值或字符串值 |

### 1.2 参数类型 (ArgumentType)

参数类型定义在 [argument-type.js](file:///g:/scratch-vm-develop/scratch-vm-develop/src/extension-support/argument-type.js) 中：

| 参数类型 | 说明 |
|---------|------|
| `angle` | 角度数值，带角度选择器 |
| `Boolean` | 布尔值，六边形占位符 |
| `color` | 颜色数值，带颜色选择器 |
| `number` | 数值，带文本输入框 |
| `string` | 字符串，带文本输入框 |
| `matrix` | 矩阵，矩阵输入字段 |
| `note` | MIDI音符，钢琴选择器 |
| `image` | 图片，作为积木标签的一部分 |

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

| 积木 | 功能描述 |
|------|----------|
| `motion_movesteps` | 移动指定步数 |
| `motion_gotoxy` | 移动到指定坐标 |
| `motion_goto` | 移动到随机位置、鼠标或其他角色 |
| `motion_turnright` | 右转指定角度 |
| `motion_turnleft` | 左转指定角度 |
| `motion_pointindirection` | 面向指定方向 |
| `motion_pointtowards` | 面向鼠标或其他角色 |
| `motion_glidesecstoxy` | 在指定时间内滑行到坐标 |
| `motion_glideto` | 滑行到随机位置、鼠标或其他角色 |
| `motion_ifonedgebounce` | 碰到边缘就反弹 |
| `motion_setrotationstyle` | 设置旋转方式（左右翻转/不旋转/任意） |
| `motion_changexby` | x坐标增加指定值 |
| `motion_setx` | 设置x坐标 |
| `motion_changeyby` | y坐标增加指定值 |
| `motion_sety` | 设置y坐标 |
| `motion_xposition` | 报告x坐标 |
| `motion_yposition` | 报告y坐标 |
| `motion_direction` | 报告方向 |

### 2. 外观类 (Looks)
文件：`src/blocks/scratch3_looks.js`

| 积木 | 功能描述 |
|------|----------|
| `looks_say` | 说话指定文本 |
| `looks_sayforsecs` | 说话指定秒数 |
| `looks_think` | 思考指定文本 |
| `looks_thinkforsecs` | 思考指定秒数 |
| `looks_show` | 显示角色 |
| `looks_hide` | 隐藏角色 |
| `looks_switchcostumeto` | 切换到指定造型 |
| `looks_switchbackdropto` | 切换到指定背景 |
| `looks_switchbackdroptoandwait` | 切换背景并等待 |
| `looks_nextcostume` | 下一个造型 |
| `looks_nextbackdrop` | 下一个背景 |
| `looks_changeeffectby` | 改变指定特效 |
| `looks_seteffectto` | 设置指定特效 |
| `looks_cleargraphiceffects` | 清除所有图形特效 |
| `looks_changesizeby` | 改变大小 |
| `looks_setsizeto` | 设置大小 |
| `looks_gotofrontback` | 移到最前面/最后面 |
| `looks_goforwardbackwardlayers` | 向前/后移动多层 |
| `looks_size` | 报告大小 |
| `looks_costumenumbername` | 报告造型编号/名称 |
| `looks_backdropnumbername` | 报告背景编号/名称 |

### 3. 声音类 (Sound)
文件：`src/blocks/scratch3_sound.js`

| 积木 | 功能描述 |
|------|----------|
| `sound_play` | 播放指定声音 |
| `sound_playuntildone` | 播放声音直到播放完 |
| `sound_stopallsounds` | 停止所有声音 |
| `sound_seteffectto` | 设置声音特效 |
| `sound_changeeffectby` | 改变声音特效 |
| `sound_cleareffects` | 清除所有声音特效 |
| `sound_setvolumeto` | 设置音量 |
| `sound_changevolumeby` | 改变音量 |
| `sound_volume` | 报告音量 |

### 4. 事件类 (Events)
文件：`src/blocks/scratch3_event.js`

| 积木 | 功能描述 |
|------|----------|
| `event_whenflagclicked` | 当绿旗被点击时 |
| `event_whenkeypressed` | 当按下指定键时 |
| `event_whenthisspriteclicked` | 当角色被点击时 |
| `event_whentouchingobject` | 当碰到指定对象时 |
| `event_whenstageclicked` | 当舞台被点击时 |
| `event_whenbackdropswitchesto` | 当背景切换到时 |
| `event_whengreaterthan` | 当变量大于指定值时 |
| `event_whenbroadcastreceived` | 当接收到广播时 |
| `event_broadcast` | 广播消息 |
| `event_broadcastandwait` | 广播并等待 |

### 5. 控制类 (Control)
文件：`src/blocks/scratch3_control.js`

| 积木 | 功能描述 |
|------|----------|
| `control_wait` | 等待指定秒数 |
| `control_wait_until` | 等待直到条件成立 |
| `control_repeat` | 重复执行指定次数 |
| `control_repeat_until` | 重复执行直到条件成立 |
| `control_while` | 当条件成立时重复执行 |
| `control_forever` | 永远重复执行 |
| `control_if` | 如果条件成立则执行 |
| `control_if_else` | 如果条件成立执行第一个分支，否则执行第二个分支 |
| `control_stop` | 停止（全部/这个脚本/其他脚本） |
| `control_create_clone_of` | 创建克隆体 |
| `control_start_as_clone` | 当作为克隆体启动时 |
| `control_delete_this_clone` | 删除此克隆体 |
| `control_get_counter` | 获取计数器值 |
| `control_incr_counter` | 增加计数器 |
| `control_clear_counter` | 清除计数器 |
| `control_all_at_once` | 同时执行（Scratch 2.0兼容） |

### 6. 侦测类 (Sensing)
文件：`src/blocks/scratch3_sensing.js`

| 积木 | 功能描述 |
|------|----------|
| `sensing_touchingobject` | 是否碰到指定对象 |
| `sensing_touchingcolor` | 是否碰到指定颜色 |
| `sensing_coloristouchingcolor` | 颜色是否碰到另一种颜色 |
| `sensing_distanceto` | 到指定对象的距离 |
| `sensing_timer` | 计时器时间 |
| `sensing_resettimer` | 重置计时器 |
| `sensing_of` | 获取指定对象的属性 |
| `sensing_mousex` | 鼠标x坐标 |
| `sensing_mousey` | 鼠标y坐标 |
| `sensing_setdragmode` | 设置拖拽模式 |
| `sensing_mousedown` | 鼠标是否被按下 |
| `sensing_keypressed` | 按键是否被按下 |
| `sensing_current` | 当前时间/日期/年份等 |
| `sensing_dayssince2000` | 自2000年以来的天数 |
| `sensing_loudness` | 音量 |
| `sensing_loud` | 是否大声 |
| `sensing_answer` | 回答的内容 |
| `sensing_askandwait` | 询问并等待回答 |
| `sensing_username` | 用户名 |

### 7. 运算类 (Operators)
文件：`src/blocks/scratch3_operators.js`

| 积木 | 功能描述 |
|------|----------|
| `operator_add` | 加法 |
| `operator_subtract` | 减法 |
| `operator_multiply` | 乘法 |
| `operator_divide` | 除法 |
| `operator_lt` | 小于比较 |
| `operator_equals` | 等于比较 |
| `operator_gt` | 大于比较 |
| `operator_and` | 与运算 |
| `operator_or` | 或运算 |
| `operator_not` | 非运算 |
| `operator_random` | 取随机数 |
| `operator_join` | 连接两个字符串 |
| `operator_letter_of` | 获取字符串中指定位置的字符 |
| `operator_length` | 字符串长度 |
| `operator_contains` | 字符串是否包含 |
| `operator_mod` | 取余数 |
| `operator_round` | 四舍五入 |
| `operator_mathop` | 数学函数（绝对值、平方根、正弦、余弦等） |

### 8. 变量类 (Data)
文件：`src/blocks/scratch3_data.js`

| 积木 | 功能描述 |
|------|----------|
| `data_variable` | 报告变量值 |
| `data_setvariableto` | 设置变量值 |
| `data_changevariableby` | 变量值增加 |
| `data_showvariable` | 显示变量 |
| `data_hidevariable` | 隐藏变量 |
| `data_listcontents` | 列表内容 |
| `data_addtolist` | 添加到列表 |
| `data_deleteoflist` | 删除列表项 |
| `data_deletealloflist` | 删除列表所有项 |
| `data_insertatlist` | 在列表指定位置插入项 |
| `data_replaceitemoflist` | 替换列表项 |
| `data_itemoflist` | 获取列表指定项 |
| `data_itemnumoflist` | 获取列表项的位置 |
| `data_lengthoflist` | 列表长度 |
| `data_listcontainsitem` | 列表是否包含项 |
| `data_showlist` | 显示列表 |
| `data_hidelist` | 隐藏列表 |

### 9. 自定义积木 (Procedures)
文件：`src/blocks/scratch3_procedures.js`

支持创建自定义积木和带参数的自定义积木。

---

## 二、扩展积木 (Extensions)

### 1. 画笔类 (Pen)
文件：`src/extensions/scratch3_pen/index.js`

| 积木 | 功能描述 |
|------|----------|
| `clear` | 全部擦除 |
| `stamp` | 盖章 |
| `penDown` | 落笔 |
| `penUp` | 抬笔 |
| `setPenColorToColor` | 设置画笔颜色 |
| `changePenColorParamBy` | 改变画笔颜色参数 |
| `setPenColorParamTo` | 设置画笔颜色参数 |
| `changePenSizeBy` | 改变画笔粗细 |
| `setPenSizeTo` | 设置画笔粗细 |



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
