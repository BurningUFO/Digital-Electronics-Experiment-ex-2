# Slot2 代码实现框架说明

本文档用于解释 `src/games/slot2/` 下的实现思路，便于课程汇报或答辩时快速说明设计结构。

## 1. 总体架构

`slot2` 采用典型的“输入 - 节拍 - 游戏逻辑 - 渲染 - 外设反馈”分层结构：

```text
按键/键盘输入
      |
      v
slot2_input  --->  move_left / move_right / rotate_cw / soft_drop / hard_drop
      |
      v
slot2_tick_gen ---> gravity_tick
      |
      v
slot2_game_core ---> board / piece / score / lines / level / game_over
      |
      v
slot2_renderer ---> VGA 图像
      |
      +----> 7 段数码管 / LED / buzzer
```

顶层文件是 [game_slot2_top.v](../src/games/slot2/game_slot2_top.v)，负责把各模块连接起来，并把核心状态转换成数码管、LED 和蜂鸣器输出。

## 2. 各模块职责

### 2.1 `game_slot2_top.v`

顶层只做“编排”，不直接实现游戏规则。

主要功能：

- 连接 `slot2_tick_gen`、`slot2_input`、`slot2_game_core`、`slot2_renderer`
- 将分数、等级、消行数显示到 7 段数码管
- 将 `lock_pulse`、`line_clear_pulse`、`game_over` 转成 LED 和蜂鸣器反馈

可以把它理解成“总控层”。

### 2.2 `slot2_tick_gen.v`

该模块负责产生重力下落节拍 `gravity_tick`。

核心思想：

- `level` 越高，`gravity_threshold` 越小
- 每到一定帧数，就输出一个 `gravity_tick`

这相当于控制方块“自动下落速度”。

### 2.3 `slot2_input.v`

该模块负责输入统一和脉冲整形。

输入来源有两类：

- 板载按键 `btn_l / btn_r / btn_u / btn_d / btn_c`
- PS/2 键盘，映射为 `A / D / W / S`

输出统一成五个动作信号：

- `move_left`
- `move_right`
- `rotate_cw`
- `soft_drop`
- `hard_drop`

其中左右移动加入了 DAS 机制：

- 首次按下立即移动一次
- 长按后按固定间隔重复移动

这能让操作手感更接近真实 Tetris。

### 2.4 `slot2_game_core.v`

这是整个游戏的核心。

它负责：

- 管理棋盘
- 管理当前方块和下一个方块
- 做碰撞检测
- 做落地锁定
- 做消行和压缩
- 做计分和升级
- 判断 `game_over`

#### 关键数据结构

- 棋盘 `board_reg`：`200 bit`，表示 20 行 x 10 列
- 方块形状：`16 bit`，表示 4x4 方块模板
- 当前方块位置：`cur_x / cur_y`
- 当前方块旋转：`cur_rot`
- 预览落点：`ghost_y_reg`

#### 关键函数

- `piece_shape()`：根据方块类型和旋转得到 4x4 形状
- `board_row()`：取出棋盘某一行
- `shape_row_bits()`：取出方块某一行
- `collision()`：判断是否越界或碰撞
- `lock_to_board()`：把方块写入棋盘
- `level_goal()`：判断升级阈值

#### 状态机

模块内部用状态机驱动完整流程：

| 状态 | 含义 |
| --- | --- |
| `ST_PLAYING` | 正常游戏中，处理移动、旋转、下落 |
| `ST_HARD_DROP` | 硬降流程，方块快速落到底 |
| `ST_CLEAR_ANIM` | 消行前等待动画时间 |
| `ST_ROW_SCAN` | 扫描每一行，找满行 |
| `ST_COMPACT_PREP` | 准备压缩棋盘 |
| `ST_COMPACT_SCAN` | 从下往上扫描并搬运未消除的行 |
| `ST_COMPACT_APPLY` | 应用压缩结果，更新分数和等级 |
| `ST_GAME_OVER` | 游戏结束 |

### 2.5 `slot2_renderer.v`

该模块只负责画面显示，不参与规则运算。

主要内容：

- 画棋盘格子
- 画当前方块
- 画 ghost 方块
- 画 next 预览
- 画 score / lines / level
- 画操作提示和 game over 覆盖层

它本质上是一个“像素级渲染器”。

## 3. 核心实现思想

### 3.1 状态机驱动

游戏流程不是靠大量零散逻辑拼起来的，而是由状态机统一控制。

好处：

- 流程清晰
- 便于调试
- 便于解释每一步在做什么

### 3.2 位运算表示棋盘

棋盘和方块都采用二进制位图表示。

好处：

- 碰撞判断直接做位运算
- 消行和合并效率高
- 硬件实现简单

### 3.3 输入、逻辑、显示解耦

输入只负责产生动作脉冲，核心只负责规则判定，渲染只负责出图。

这使得：

- 规则改动不会影响显示
- 显示改动不会影响游戏逻辑
- 更适合 FPGA 这类分层硬件设计

## 4. 汇报时的讲法

可以直接这样描述：

> 这个 slot2 采用分层式硬件架构。顶层负责连接输入、节拍、核心逻辑和渲染模块。  
> 游戏核心使用 200 位棋盘和 16 位方块模板来做位图化管理，通过碰撞检测控制移动、旋转和落地。  
> 方块落地后先锁定到棋盘，再通过状态机完成扫行、压缩、计分和升级。  
> 渲染模块只根据当前状态画 VGA 图像，数码管、LED 和蜂鸣器则作为外设反馈，构成完整游戏闭环。

## 5. 关键文件

- [game_slot2_top.v](../src/games/slot2/game_slot2_top.v)
- [slot2_game_core.v](../src/games/slot2/slot2_game_core.v)
- [slot2_input.v](../src/games/slot2/slot2_input.v)
- [slot2_tick_gen.v](../src/games/slot2/slot2_tick_gen.v)
- [slot2_renderer.v](../src/games/slot2/slot2_renderer.v)

