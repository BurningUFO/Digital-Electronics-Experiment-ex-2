可以把 PPT 设计成一条清晰主线：

> **我不是只做了几个小游戏，而是通过这个项目学会了 FPGA 图形交互系统：VGA 显示、菜单渲染、键盘输入、槽位架构、资源分析和时序收敛。**
> 这条主线和你的文档主题“学”一致。

# 推荐 PPT 结构：18 页

## 1. 封面页

**标题：**

```text
“学”：基于 Nexys A7 的 VGA 游戏集合机
```

**副标题：**

```text
从 VGA 显示、PS/2 输入到资源分析与时序收敛
```

**页面内容：**

放一张简洁结构图：

```text
VGA 显示  +  PS/2 键盘  +  多游戏槽位  +  Vivado 优化
```

**讲解重点：**

这一页不要讲技术细节，只定调：

> 这个实验我用“学”来概括。它让我从数码管、按键这些基础外设，进入到 VGA 图形显示、键盘输入、多游戏平台和 FPGA 工程优化。

------

## 2. 项目一句话定位

**标题：**

```text
这不是单个小游戏，而是一台 FPGA 游戏集合机
```

**页面内容：**

用产品图式表达：

```text
上电 → VGA 菜单 → 键盘选择 → 启动游戏 → ESC 返回菜单
```

下方列出：

```text
TANK WAR
GAME TWO
GAME THREE
GAME FOUR
```

**讲解重点：**

> 从用户角度看，它是一台简易 FPGA 游戏主机。
> 用户通过 VGA 菜单选择游戏，通过 PS/2 键盘操作游戏，通过 ESC 返回菜单。
> 所以它不是几个游戏代码拼接，而是一个有统一入口、统一输入、统一输出的系统。

------

## 3. 本次汇报主线

**标题：**

```text
我的学习路线：从能显示，到能优化
```

**页面内容：**

做一条路线：

```text
VGA 显示原理
      ↓
菜单渲染
      ↓
PS/2 键盘输入
      ↓
Game Slot API
      ↓
资源占用分析
      ↓
WNS 为负到 post-route 收敛
```

**讲解重点：**

> 今天我不按文件顺序讲，而按学习路径讲。
> 前半部分讲我怎么让 FPGA 变成一个图形交互系统；后半部分讲我怎么从资源报告和 timing report 里发现问题，再通过 RTL 优化把设计收敛。

------

## 4. 系统总体架构

**标题：**

```text
主机 + 游戏槽位：game_console_top 如何组织系统
```

**页面内容：**

放模块图：

```text
game_console_top
│
├─ console_vga_sync          VGA 时序与像素坐标
├─ console_menu_renderer     菜单画面渲染
├─ console_ps2_rx            PS/2 字节接收
├─ console_menu_controller   菜单选择与返回
│
├─ game_slot1_top            Tank War
├─ game_slot2_top            Game Two
├─ game_slot3_top            Game Three
└─ game_slot4_top            Game Four
```

**讲解重点：**

> 顶层负责公共服务：VGA、键盘、菜单和输出复用。
> 游戏槽位只负责自己的游戏逻辑和画面输出。
> 这让我学到，复杂项目不能每个模块各自为政，而要先抽象出公共服务层。

------

## 5. VGA 显示原理：不是传图片，而是实时扫描

**标题：**

```text
VGA 的本质：每个像素周期输出一个颜色
```

**页面内容：**

放一张扫描示意图：

```text
一行一行扫描
左 → 右
上 → 下

当前坐标：(pixel_x, pixel_y)
当前颜色：VGA_R/G/B
同步信号：VGA_HS / VGA_VS
```

右侧放一句核心结论：

```text
FPGA 不是“画完一张图再发送”
而是“扫描到哪里，就实时输出哪里的颜色”
```

**讲解重点：**

> VGA 是我这个项目学到的第一个核心点。
> 以前数码管显示只需要准备数字并扫描位选；VGA 则要求 FPGA 按像素节拍不断输出 RGB，同时产生 HS 和 VS。
> 这直接引出后面的渲染路径、LUT 占用和时序问题。

------

## 6. VGA 时序发生器核心代码

**标题：**

```text
console_vga_sync：用计数器生成像素坐标
```

**页面内容：**

放代码片段，不要太长：

```verilog
// src/common/console_vga_sync.v

localparam H_VISIBLE = 640;
localparam H_FRONT   = 16;
localparam H_SYNC    = 96;
localparam H_BACK    = 48;
localparam H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

localparam V_VISIBLE = 480;
localparam V_FRONT   = 10;
localparam V_SYNC    = 2;
localparam V_BACK    = 33;
localparam V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;
```

再放简化逻辑：

```verilog
pixel_tick = (pix_div == 2'b11);

if (pixel_tick) begin
    h_count <= h_count + 1;
    if (h_count == H_TOTAL - 1) begin
        h_count <= 0;
        v_count <= v_count + 1;
    end
end
```

**讲解重点：**

> 这里的关键是两个计数器。
> `h_count` 表示当前列，`v_count` 表示当前行。
> 可见区是 640×480，但实际扫描还包括 front porch、sync pulse 和 back porch。
> 所以 VGA 控制器本质上是一个严格按时序运行的坐标发生器。

------

## 7. 为什么使用 pixel_tick，而不是新建 25 MHz 时钟

**标题：**

```text
单时钟域设计：100MHz 主时钟 + pixel_tick 使能
```

**页面内容：**

对比图：

```text
不推荐：
100MHz 主时钟 + 25MHz 新时钟
        ↓
多时钟域问题

当前设计：
100MHz 主时钟
        ↓
pixel_tick 作为 clock enable
        ↓
所有逻辑仍在同一时钟域
```

**讲解重点：**

> 板卡主时钟是 100MHz，而 640×480 VGA 需要 25MHz 级别像素节拍。
> 我没有新建独立 25MHz 时钟，而是用 `pixel_tick` 作为使能信号。
> 这样所有逻辑仍然在 100MHz 同一时钟域里，避免了不必要的跨时钟域问题，也方便 Vivado 做时序分析。

------

## 8. 菜单渲染：像素坐标如何变成界面

**标题：**

```text
菜单不是图片，而是一组像素级判断
```

**页面内容：**

放菜单渲染伪代码：

```verilog
// src/common/console_menu_renderer.v 伪代码

if (!display_active)
    rgb = 12'h000;
else if (pixel 命中标题)
    rgb = title_color;
else if (pixel 命中菜单项文字) begin
    if (该项 == cursor)
        rgb = highlight_color;
    else
        rgb = normal_text_color;
end
else if (pixel 命中边框)
    rgb = border_color;
else
    rgb = background_color;
```

旁边放菜单渲染链路：

```text
pixel_x / pixel_y
      ↓
区域判断
      ↓
文字 / 边框 / 高亮
      ↓
RGB 输出
```

**讲解重点：**

> 菜单看起来只是一个界面，但在 FPGA 里它不是图片文件，而是像素坐标判断。
> 当前像素属于标题、菜单项、高亮框、边框还是背景，都要用组合逻辑判断。
> 这也是为什么 VGA 项目很容易出现 LUT 高的问题。

------

## 9. 菜单控制与渲染的配合

**标题：**

```text
菜单控制器决定“选谁”，渲染器决定“怎么画”
```

**页面内容：**

放双模块关系：

```text
console_ps2_rx
      ↓ byte_ready / byte_data
console_menu_controller
      ↓ cursor / game_sel / menu_active
console_menu_renderer
      ↓ menu_vga_r/g/b
VGA 输出
```

右侧放顶层代码概念：

```verilog
if (menu_active)
    VGA_RGB = menu_rgb;
else
    VGA_RGB = active_slot_rgb;
```

**讲解重点：**

> 菜单控制器和菜单渲染器是分开的。
> 控制器只关心当前光标、当前游戏选择、是否启动游戏；渲染器只关心根据 `cursor` 和像素坐标画出菜单。
> 这种分层让逻辑更清楚，也方便后面做输出复用。

------

## 10. PS/2 键盘输入：从物理信号到 byte 事件

**标题：**

```text
PS/2 输入不是按键电平，而是串行协议
```

**页面内容：**

放 11 位帧结构：

```text
start bit
  ↓
8-bit scan code，LSB first
  ↓
parity
  ↓
stop bit
```

放处理链路：

```text
PS2_CLK / PS2_DATA
      ↓
下降沿采样
      ↓
shift_data[7:0]
      ↓
byte_ready + byte_data
```

**讲解重点：**

> PS/2 键盘不是普通按键。
> 它会通过时钟线和数据线发送扫描码。
> FPGA 要先同步 PS/2 信号，再在 PS/2 时钟下降沿采样，组装成 byte。
> 所以这里学到的是：外设输入必须先协议解析，再交给上层状态机。

------

## 11. PS/2 接收核心代码

**标题：**

```text
console_ps2_rx：下降沿采样并组装扫描码
```

**页面内容：**

放代码：

```verilog
// src/common/console_ps2_rx.v

assign ps2_clk_fall = ps2_clk_ff1 & ~ps2_clk_ff0;

if (ps2_clk_fall) begin
    case (bit_count)
        4'd0: if (ps2_data_ff1 == 1'b0)
                  bit_count <= 4'd1;

        4'd1: begin
            shift_data[0] <= ps2_data_ff1;
            bit_count <= 4'd2;
        end

        // 省略 data[1] ~ data[7]

        4'd10: begin
            if (ps2_data_ff1 == 1'b1) begin
                byte_data  <= shift_data;
                byte_ready <= 1'b1;
            end
            bit_count <= 4'd0;
        end
    endcase
end
```

**讲解重点：**

> 这段代码只做协议接收，不判断具体按键含义。
> 它输出的是 `byte_ready` 和 `byte_data`。
> 这样底层 PS/2 协议和上层菜单控制解耦。

------

## 12. 扫描码如何变成菜单操作

**标题：**

```text
扫描码事件化：W/S、Enter、Esc 如何控制菜单
```

**页面内容：**

放扫描码表：

```text
W / Up       → 光标上移
S / Down     → 光标下移
Enter/Space  → 启动游戏
Esc          → 返回菜单
F0           → key release 前缀
E0           → 扩展键前缀
```

放关键代码：

```verilog
// src/common/console_menu_controller.v

assign is_up_key    = (byte_data == SCAN_W) || (byte_data == SCAN_UP);
assign is_down_key  = (byte_data == SCAN_S) || (byte_data == SCAN_DOWN);
assign is_start_key = (byte_data == SCAN_SPACE) || (byte_data == SCAN_ENTER);
assign is_back_key  = (byte_data == SCAN_ESC);
```

**讲解重点：**

> `console_ps2_rx` 只负责收到哪个扫描码。
> `console_menu_controller` 再把扫描码解释成菜单动作。
> 这一步叫事件化：把底层输入转成“上移、下移、开始、返回”这些系统事件。

------

## 13. Game Slot API：让游戏像卡带一样接入

**标题：**

```text
统一槽位 API：从“多个游戏”到“游戏平台”
```

**页面内容：**

放接口分组，不要放完整长代码：

```text
公共输入：
clk / reset / selected
frame_tick / pixel_tick
display_active / pixel_x / pixel_y
ps2_byte_ready / ps2_byte_data
btn / sw

统一输出：
vga_r / vga_g / vga_b
led
an / ca~dp
buzzer
```

**讲解重点：**

> 如果每个游戏都自己定义接口，顶层会非常混乱。
> 所以我把每个游戏都做成统一槽位模块。
> 顶层只根据当前选中的槽位复用输出，而不需要关心游戏内部怎么实现。
> 这就是从“写游戏模块”到“设计游戏平台”的区别。

------

## 14. 槽位输出复用：菜单和游戏如何共享 VGA

**标题：**

```text
输出复用：菜单激活显示菜单，否则显示当前游戏
```

**页面内容：**

放简化代码：

```verilog
// src/game_console_top.v 伪代码

active_slot_rgb =
    slot1_selected ? slot1_rgb :
    slot2_selected ? slot2_rgb :
    slot3_selected ? slot3_rgb :
                     slot4_rgb;

if (menu_active)
    VGA_RGB = menu_rgb;
else
    VGA_RGB = active_slot_rgb;
```

放图：

```text
slot1 RGB ┐
slot2 RGB ├─ active_slot_rgb ┐
slot3 RGB ┤                  ├─ VGA_RGB
slot4 RGB ┘                  │
menu RGB  ───────────────────┘
```

**讲解重点：**

> 所有游戏都可以输出 RGB，但真实 VGA 端口只有一组。
> 因此顶层必须根据当前状态选择输出源。
> 菜单激活时显示菜单；进入游戏后显示当前 slot 的 RGB。
> 这让多个游戏共享同一套 VGA 外设。

------

## 15. 资源占用分析：LUT 高、FF 低说明什么

**标题：**

```text
资源报告告诉我：问题不是寄存器太多，而是组合逻辑太重
```

**页面内容：**

放大表格：

| 指标 | 使用量        | 占比   | 说明             |
| ---- | ------------- | ------ | ---------------- |
| LUT  | 30146 / 63400 | 约 48% | 组合逻辑压力明显 |
| FF   | 4371 / 126800 | 约 3%  | 寄存器使用很少   |

下方结论：

```text
LUT 高 + FF 低
    ↓
大量逻辑在组合路径中展开
    ↓
像素渲染 / tile 判断 / 字体 / 图层优先级是主要来源
```

**讲解重点：**

> 一开始看到 LUT 接近一半，我以为只是游戏内容太多。
> 后来分析后发现更关键的问题是 RTL 风格：很多像素级判断都在组合逻辑里完成。
> FF 很低说明寄存器并没有用多，反而说明可以适当用寄存器和流水来换时序。

------

## 16. 为什么 VGA 游戏容易 LUT 高

**标题：**

```text
每个像素都要回答一个问题：这里该显示什么？
```

**页面内容：**

放像素渲染决策树：

```text
当前像素 (x, y)
    ↓
是否在可见区？
    ↓
是否命中背景？
    ↓
是否命中地图 tile？
    ↓
是否命中玩家 / 敌人？
    ↓
是否命中子弹 / 道具？
    ↓
是否命中文字 / UI？
    ↓
图层优先级
    ↓
RGB 输出
```

右侧写：

```text
这些判断如果都在一拍内完成：
比较器多
mux 多
case/function 展开多
组合路径长
```

**讲解重点：**

> VGA 游戏不是只在状态更新时复杂，而是在每个像素周期都可能复杂。
> 菜单、地图、角色、文字、UI 都会变成坐标比较和图层选择。
> 所以后期优化的方向不是删功能，而是改变计算组织方式。

------

## 17. 时序问题：WNS 为负意味着什么

**标题：**

```text
代码能综合，不代表电路能按 100MHz 跑
```

**页面内容：**

放概念图：

```text
100MHz 时钟周期 = 10ns

寄存器 A
   ↓ 组合逻辑
寄存器 B

组合逻辑延迟 < 10ns  →  WNS 为正
组合逻辑延迟 > 10ns  →  WNS 为负
```

放定义：

```text
WNS：最差路径的时序余量
TNS：所有失败路径负 slack 总和
```

**讲解重点：**

> 这个项目后期最大的工程问题是时序。
> 功能写完、综合通过，并不代表实现后能稳定运行。
> WNS 为负说明至少有一条路径在一个时钟周期内来不及。
> 所以我后期做的不是改变游戏内容，而是在不改变可见行为的前提下切短组合路径。

------

## 18. 从负 WNS 到 post-route 收敛

**标题：**

```text
最终优化结果：从负 slack 到时序收敛
```

**页面内容：**

放结果表：

| 阶段                     | WNS       | TNS        | 失败端点 |
| ------------------------ | --------- | ---------- | -------- |
| 移除宽泛例外后的真实基线 | -0.445 ns | -18.104 ns | 94       |
| 最终 post-route          | +0.174 ns | 0.000 ns   | 0        |

下方放优化路线：

```text
Slot2：ghost / lock 拆多拍 + video staging
Slot3：try_x / try_y 注册，切断反馈路径
Slot4：tile probe → eval → apply
约束：只保留窄范围 VGA multicycle
```

**讲解重点：**

> 这里是本项目最能体现独立思考和优化过程的部分。
> 我没有靠宽泛时序例外掩盖问题，而是先暴露真实基线，再针对具体长路径改 RTL。
> 最终 post-route WNS 为正，TNS 为 0，失败端点为 0，说明实现后时序收敛。

------

# 备用扩展页：建议放在附录

如果老师时间多，或者答辩时需要展开，可以准备 4 页附录。

## 附录 A：Slot2 优化案例

**标题：**

```text
Slot2：把 ghost / lock 从一拍大逻辑拆成多拍流程
```

放：

```text
Before：一拍内完成 ghost 计算、碰撞、锁定
After ：ghost 迭代 probe，lock row-by-row
```

讲一句：

> 这类优化的本质是用状态机把大组合逻辑拆成多个小步骤。

------

## 附录 B：Slot3 优化案例

**标题：**

```text
Slot3：try_x / try_y 切断 player-map-player 反馈路径
```

放：

```text
输入 → candidate_x/y → try_x/y 寄存
下一拍 → walkable 判断
再下一步 → 提交 neo_x/y
```

讲一句：

> 用户感觉不到延迟，但硬件关键路径明显变短。

------

## 附录 C：Slot4 优化案例

**标题：**

```text
Slot4：tile 碰撞拆成 probe / eval / apply
```

放：

```text
TEST：寄存 tile 查询地址
EVAL：判断 solid / failed / complete
APPLY：更新角色和关卡状态
```

讲一句：

> 这体现了我从软件式“一步算完”转向硬件式“分阶段流水”的思路。

------

## 附录 D：代码路径速查

**标题：**

```text
核心代码位置
```

放表：

| 讲解点        | 文件位置                                  |
| ------------- | ----------------------------------------- |
| 总顶层        | `src/game_console_top.v`                  |
| VGA 时序      | `src/common/console_vga_sync.v`           |
| 菜单渲染      | `src/common/console_menu_renderer.v`      |
| PS/2 接收     | `src/common/console_ps2_rx.v`             |
| 菜单控制      | `src/common/console_menu_controller.v`    |
| Game Slot API | `docs/game_api.md`                        |
| 资源分析      | `docs/资源占用分析.md`                    |
| 时序优化      | `docs/final_timing_optimization_round.md` |

------

# 最推荐的整体页数

如果时间比较紧，建议用 **14 页压缩版**：

```text
1 封面
2 项目定位
3 汇报主线
4 系统架构
5 VGA 原理
6 VGA 核心代码
7 菜单渲染
8 PS/2 输入
9 Game Slot API
10 输出复用
11 资源占用分析
12 LUT 高 FF 低原因
13 时序优化过程
14 最终结果与学习收获
```

如果你希望质量更高、讲得更完整，就用上面的 **18 页完整版**。

# 结束页建议

最后一页可以用这句话收束：

> 这个项目让我真正理解：FPGA 设计不是“写出能跑的游戏”就结束了，而是要让显示、输入、架构、资源和时序全部统一起来。VGA 和 PS/2 让我学会外设系统，Game Slot API 让我学会平台化设计，LUT/WNS 优化让我学会从功能代码走向可实现硬件。