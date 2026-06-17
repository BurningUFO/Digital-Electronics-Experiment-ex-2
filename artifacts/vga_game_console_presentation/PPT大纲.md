# PPT 大纲

主题：《“学”：基于 Nexys A7 的 VGA 游戏集合机》

主线：我不是只做了几个小游戏，而是学习并完成了一个 FPGA 图形交互系统：VGA 显示、菜单渲染、PS/2 输入、Game Slot API、资源占用分析和时序收敛。

## 第 1 页：“学”：基于 Nexys A7 的 VGA 游戏集合机

**核心结论：** 从基础 Verilog 进入 FPGA 图形交互系统。

**页面要点：**
- 板卡：Nexys A7-100T / XC7A100T-1CSG324C
- 关键词：VGA / PS2 / Game Slot / LUT / WNS
- 主线：显示、输入、平台化、资源分析、时序收敛

**图示/版式：** cover

**引用：** README.md；docs/第二实验_VGA游戏集合机_验收讲解文档.md

## 第 2 页：这不是单个小游戏，而是一台 FPGA 游戏集合机

**核心结论：** 从用户角度，它有统一入口、统一输入和返回路径。

**页面要点：**
- 上电后先进入 VGA 菜单
- PS/2 键盘选择并启动游戏
- 游戏中按 Esc 返回菜单
- 四个槽位：TANK WAR / GAME TWO / GAME THREE / GAME FOUR

**图示/版式：** user_flow

**引用：** README.md

## 第 3 页：我的学习路线：从能显示，到能优化

**核心结论：** 本次汇报按学习路径讲，不按文件列表讲。

**页面要点：**
- 先解释 VGA 实时像素扫描
- 再解释菜单渲染和 PS/2 输入事件化
- 然后说明 Game Slot API 的平台化意义
- 最后用资源和时序报告说明工程优化过程

**图示/版式：** learning_route

**引用：** docs/PPT设计方案.md；docs/第二实验_VGA游戏集合机_验收讲解文档.md

## 第 4 页：主机 + 游戏槽位：game_console_top 如何组织系统

**核心结论：** 顶层提供公共服务，槽位只负责自身逻辑和画面。

**页面要点：**
- common 模块：VGA 同步、菜单渲染、PS/2 接收、菜单控制
- slot1 到 slot4 使用统一端口接入
- VGA、LED、七段管、蜂鸣器由顶层统一复用

**图示/版式：** architecture

**引用：** src/game_console_top.v；docs/game_api.md

## 第 5 页：VGA 的本质：每个像素周期输出一个颜色

**核心结论：** FPGA 不是发送整张图片，而是扫描到哪里就实时给出哪里的 RGB。

**页面要点：**
- `pixel_x / pixel_y` 表示当前扫描坐标
- `display_active` 表示当前是否在 640x480 可见区
- `VGA_R/G/B` 给出当前像素颜色
- `VGA_HS / VGA_VS` 让显示器识别行和帧同步

**图示/版式：** vga_scan

**引用：** src/common/console_vga_sync.v

## 第 6 页：console_vga_sync：用计数器生成像素坐标

**核心结论：** VGA 控制器本质上是两个计数器加同步脉冲生成逻辑。

**页面要点：**
- 可见区为 640x480，扫描还包含 front/sync/back 消隐区
- `pix_div` 每 4 个 100MHz 周期产生一次像素使能
- `h_count/v_count` 同步推进，得到当前像素坐标

**图示/版式：** code

**引用：** src/common/console_vga_sync.v:13；src/common/console_vga_sync.v:43

## 第 7 页：单时钟域设计：100MHz 主时钟 + pixel_tick 使能

**核心结论：** 没有新建 25MHz 时钟，而是用 clock enable 保持单时钟域。

**页面要点：**
- 板卡主时钟是 100MHz
- `pixel_tick` 作为 VGA 像素推进使能
- 所有主要逻辑仍由 `CLK100MHZ` 驱动
- 时序约束和跨模块协作更清晰

**图示/版式：** single_clock

**引用：** src/common/console_vga_sync.v；docs/game_api.md

## 第 8 页：菜单不是图片，而是一组像素级判断

**核心结论：** 菜单渲染同样是实时像素逻辑，也是 LUT 压力来源之一。

**页面要点：**
- `pixel_x/y` 进入区域判断
- 标题、菜单项、帮助文字和边框都由坐标命中决定
- `cursor` 只决定哪一项高亮

**图示/版式：** menu_render

**引用：** src/common/console_menu_renderer.v

## 第 9 页：菜单控制器决定“选谁”，渲染器决定“怎么画”

**核心结论：** 输入事件、菜单状态和像素渲染分层，顶层再做显示复用。

**页面要点：**
- `console_ps2_rx` 输出 byte 事件
- `console_menu_controller` 更新 `cursor / game_sel / menu_active`
- `console_menu_renderer` 根据 `cursor` 和坐标输出菜单 RGB
- 顶层根据 `menu_active` 选择菜单或当前游戏画面

**图示/版式：** menu_control

**引用：** src/common/console_ps2_rx.v；src/common/console_menu_controller.v；src/common/console_menu_renderer.v

## 第 10 页：PS/2 输入不是按键电平，而是串行协议

**核心结论：** 键盘先发送扫描码，FPGA 必须先协议解析再事件化。

**页面要点：**
- 一帧包含 start、8 位 scan code、parity、stop
- 数据位 LSB first
- 在 PS/2 时钟下降沿采样
- 底层只输出 `byte_ready + byte_data`

**图示/版式：** ps2_frame

**引用：** src/common/console_ps2_rx.v

## 第 11 页：console_ps2_rx：下降沿采样并组装扫描码

**核心结论：** 这个模块只做协议层接收，不解释具体按键含义。

**页面要点：**
- PS/2 时钟和数据先同步并做历史滤波
- `bit_count` 记录当前接收到帧的哪一位
- 停止位为 1 且奇校验通过时产生 `byte_ready`

**图示/版式：** code

**引用：** src/common/console_ps2_rx.v:12；src/common/console_ps2_rx.v:40；src/common/console_ps2_rx.v:70

## 第 12 页：扫描码事件化：W/S、Enter、Esc 如何控制菜单

**核心结论：** 底层 byte 被转换成上移、下移、启动、返回这些系统事件。

**页面要点：**
- `F0` 表示 key release 前缀，下一码不触发动作
- `E0` 记录扩展键前缀，方向键扫描码仍由上层识别
- 菜单内启动游戏；游戏中 Esc 返回菜单

**图示/版式：** scan_codes

**引用：** src/common/console_menu_controller.v:12；src/common/console_menu_controller.v:33

## 第 13 页：统一槽位 API：从“多个游戏”到“游戏平台”

**核心结论：** 每个游戏像卡带一样接入，顶层只依赖统一端口。

**页面要点：**
- 公共输入：`clk / reset / selected`
- 显示输入：`frame_tick / pixel_tick / display_active / pixel_x/y`
- 输入事件：`ps2_byte_ready / ps2_byte_data`、按钮和开关
- 统一输出：VGA RGB、LED、七段管、蜂鸣器

**图示/版式：** game_slot_api

**引用：** docs/game_api.md

## 第 14 页：输出复用：菜单激活显示菜单，否则显示当前游戏

**核心结论：** 真实 VGA 端口只有一组，所有菜单和游戏画面都必须由顶层仲裁。

**页面要点：**
- slot1 到 slot4 先复用为 `active_slot_*`
- 菜单态覆盖 VGA、LED、七段管和蜂鸣器输出
- HS/VS 始终来自公共 `console_vga_sync`

**图示/版式：** mux

**引用：** src/game_console_top.v:400；src/game_console_top.v:440

## 第 15 页：资源报告告诉我：问题不是寄存器太多，而是组合逻辑太重

**核心结论：** LUT 约 48%，FF 约 3%，说明组合路径和像素渲染是主要压力。

**页面要点：**
- LUT：30146 / 63400，约 48%
- FF：4371 / 126800，约 3%
- 菜单、文字、地图、sprite、tile 和对象命中检测都会消耗 LUT
- 优化方向是适当增加寄存器和 staging，而不是继续减少 FF

**图示/版式：** resource_chart

**引用：** docs/资源占用分析.md

## 第 16 页：每个像素都要回答一个问题：这里该显示什么？

**核心结论：** VGA 游戏的复杂度来自每个像素周期的坐标判断和图层优先级。

**页面要点：**
- 是否在可见区
- 是否命中背景、地图 tile、玩家、敌人、子弹、道具
- 是否命中文字或 UI
- 最终按图层优先级选择 RGB

**图示/版式：** pixel_decision

**引用：** docs/资源占用分析.md；src/common/console_menu_renderer.v；src/games/slot3/slot3_renderer.v；src/games/slot4/game_slot4_top.v

## 第 17 页：代码能综合，不代表电路能按 100MHz 跑

**核心结论：** WNS 为负说明至少有一条路径在一个周期内来不及。

**页面要点：**
- 100MHz 时钟周期为 10ns
- 寄存器 A 到寄存器 B 中间的组合逻辑必须在周期内稳定
- WNS：最差路径时序余量
- TNS：所有失败路径负 slack 总和

**图示/版式：** timing_concept

**引用：** docs/final_timing_optimization_round.md

## 第 18 页：最终优化结果：从负 slack 到时序收敛

**核心结论：** 先暴露真实基线，再通过 RTL staging/pipeline 把 WNS 拉正。

**页面要点：**
- 真实基线：WNS=-0.445ns，TNS=-18.104ns，失败端点 94
- 最终 post-route：WNS=+0.174ns，TNS=0.000ns，失败端点 0
- 只保留窄范围 VGA pixel multicycle，不覆盖游戏核心状态
- 最终成功生成 bitstream

**图示/版式：** timing_results

**引用：** docs/final_timing_optimization_round.md；scripts/apply_timing_exceptions.tcl

## 第 19 页：优化思想：把一拍大计算拆成多拍小计算

**核心结论：** 用户可见行为不变，但硬件每拍需要完成的逻辑更少。

**页面要点：**
- Slot2：ghost 迭代、lock row-by-row、video staging
- Slot3：`try_x / try_y` 寄存，下一拍判断 walkable
- Slot4：tile probe -> eval -> apply
- 约束：4-cycle VGA multicycle 只用于 pixel_tick 视频路径

**图示/版式：** optimization_cases

**引用：** src/games/slot2/slot2_game_core.v；src/games/slot2/game_slot2_top.v；src/games/slot3/slot3_player.v；src/games/slot4/game_slot4_top.v

## 第 20 页：从功能实现到工程实现

**核心结论：** 最终收获是把显示、输入、架构、资源和时序统一起来。

**页面要点：**
- VGA：理解实时像素扫描
- 菜单：理解坐标判断和图层优先级
- PS/2：理解外设协议解析和事件化
- Game Slot API：理解平台化系统架构
- LUT/WNS：理解从 Verilog 功能到可实现硬件的差距

**图示/版式：** summary

**引用：** README.md；docs/资源占用分析.md；docs/final_timing_optimization_round.md
