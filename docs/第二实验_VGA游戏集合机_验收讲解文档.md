# 第二个数电实验验收讲解文档：从基础 Verilog 到 VGA 游戏集合机

> 主题关键词：**学**  
> 项目名称：**Nexys A7 Game Console：基于 VGA 与 PS/2 键盘的 FPGA 游戏集合机**  
> 目标板卡：**Nexys A7-100T / XC7A100T-1CSG324C**  
> 仓库分支：`Digital-Electronics-Experiment-ex-2/timing-final-optimization`

---

## 0. 文档使用说明

这份文档不是传统实验报告，而是面向验收汇报的**讲解稿 + 技术说明 + 代码导览**。它的目标是帮助我把第二个实验讲成一个完整的 FPGA 产品，而不是零散地解释几个 Verilog 文件。

本项目我用一个字概括：**学**。

第一个时钟实验更多是在“练”已有的 Verilog、状态机、计数器、扫描显示和按键交互能力；第二个 VGA 游戏集合机则是一次明显的能力扩展：我学习了 VGA 实时显示、PS/2 键盘输入、多游戏槽位架构、像素级渲染、资源占用分析、流水化和时序收敛。

验收时建议按照下面的逻辑讲：

```text
先讲它是什么产品
    ↓
再演示用户怎么用
    ↓
再讲系统架构如何组织
    ↓
再讲我学到的关键技术：VGA、PS/2、游戏状态机
    ↓
最后讲工程优化：LUT、流水、WNS/TNS、bitstream
```

---

## 1. 项目一句话定位

这个项目最终做成的是一个运行在 Nexys A7-100T 上的 **FPGA VGA 游戏集合机**。

它上电后首先显示 VGA 菜单，用户通过 PS/2 键盘的 `W/S` 或方向键移动光标，用 `Enter/Space` 启动游戏，在游戏中按 `Esc` 返回菜单。系统包含四个游戏槽位：`TANK WAR`、`GAME TWO`、`GAME THREE`、`GAME FOUR`。四个游戏统一复用顶层提供的 VGA 像素坐标、`pixel_tick`、`display_active` 和 PS/2 byte 事件。

验收时可以这样开场：

> 我的第二个实验是一个基于 Nexys A7 的 VGA 游戏集合机。  
> 我把它的主题概括为“学”，因为它让我从之前比较熟悉的数码管、按键和计数器，进一步学习到了 VGA 图形显示、PS/2 键盘输入、多游戏槽位管理、像素级渲染、资源占用分析和 Vivado 时序收敛。  
> 所以这个实验不是简单把几个小游戏拼起来，而是一次从基础 Verilog 到图形交互系统的完整学习过程。

---

## 2. 推荐汇报结构

如果只讲第二个实验，建议控制在 **12 到 18 分钟**。如果老师要求更完整，可以讲到 20 分钟左右。

| 汇报部分 | 建议时间 | 核心目的 |
| --- | ---: | --- |
| 项目定位 | 1-2 分钟 | 让老师知道它是一个 FPGA 游戏集合机 |
| 上板演示 | 2-3 分钟 | 从用户视角展示产品完整性 |
| 系统架构 | 2-3 分钟 | 讲清楚顶层、公共外设、游戏槽位 |
| VGA 显示原理 | 3 分钟 | 体现“学”的核心技术点 |
| PS/2 键盘输入 | 2 分钟 | 讲清外设信号如何事件化 |
| 游戏逻辑与槽位 API | 2-3 分钟 | 讲清多游戏如何统一接入 |
| 资源与时序优化 | 4-5 分钟 | 展示工程深度和优化能力 |
| 学习收获总结 | 1 分钟 | 回扣“学”的主题 |

---

## 3. 演示顺序设计

现场演示建议先从用户体验开始，不要一上来就打开代码。

```text
1. 板卡上电
2. 显示器出现 VGA 菜单
3. 用 W/S 或方向键上下移动菜单光标
4. Enter / Space 启动 Tank War
5. 操作游戏几秒钟，展示 VGA 画面、键盘输入、LED/七段管/蜂鸣器反馈
6. 按 Esc 返回集合机菜单
7. 再切换到另一个游戏槽位，说明槽位可替换
8. 最后展示 Vivado timing summary：WNS 为正，TNS 为 0
```

现场可以这样讲：

> 现在板子上运行的是我的 VGA 游戏集合机。上电以后首先进入菜单界面，菜单通过 VGA 输出，选择通过 PS/2 键盘完成。  
> 我可以用 W/S 或方向键上下移动，用 Enter 或 Space 启动当前游戏。  
> 进入游戏后，VGA 画面是 FPGA 根据当前像素坐标实时渲染出来的，键盘输入经过 PS/2 接收模块转成游戏事件。  
> 按 Esc 可以返回菜单，说明这些游戏不是孤立模块，而是由统一的集合机顶层管理。

---

## 4. 系统总体架构

### 4.1 一张图讲清系统

```text
game_console_top
│
├─ console_vga_sync
│   ├─ 产生 pixel_tick
│   ├─ 产生 pixel_x / pixel_y
│   ├─ 产生 display_active
│   └─ 产生 VGA_HS / VGA_VS / frame_tick
│
├─ console_ps2_rx
│   └─ 把 PS2_CLK / PS2_DATA 解析成 byte_ready / byte_data
│
├─ console_menu_controller
│   ├─ 处理 W/S/方向键
│   ├─ 处理 Enter/Space 启动
│   └─ 处理 Esc 返回菜单
│
├─ console_menu_renderer
│   └─ 根据 pixel_x / pixel_y 渲染菜单画面
│
├─ game_slot1_top  → Tank War，包装 src/games/tank/tank_top.v
├─ game_slot2_top  → Game Two
├─ game_slot3_top  → Game Three
└─ game_slot4_top  → Game Four
```

### 4.2 架构讲解话术

> 这个项目的核心不是单个游戏，而是“主机 + 游戏槽位”的架构。  
> 顶层 `game_console_top` 负责管理公共资源，例如 VGA 时序、PS/2 键盘接收、菜单控制和输出复用。  
> 每个游戏槽位只负责自己的游戏逻辑和像素颜色输出。  
> 这样做的好处是，VGA 和 PS/2 不需要每个游戏重复写一套，游戏之间也不会抢板上的显示器、LED、七段管和蜂鸣器资源。

### 4.3 核心代码位置：总顶层

文件位置：

```text
src/game_console_top.v
```

核心代码摘录：

```verilog
// 复位：CPU_RESETN 是低有效，项目内部使用高有效 reset
assign reset = ~CPU_RESETN;

// 当前槽位是否被选中：菜单关闭后，根据 game_sel 选择一个槽位
assign slot1_selected = !menu_active && (game_sel == 3'd0);
assign slot2_selected = !menu_active && (game_sel == 3'd1);
assign slot3_selected = !menu_active && (game_sel == 3'd2);
assign slot4_selected = !menu_active && (game_sel == 3'd3);
```

公共 VGA 和 PS/2 服务在顶层统一实例化：

```verilog
console_vga_sync u_console_vga_sync (
    .clk(CLK100MHZ),
    .reset(reset),
    .pixel_tick(console_pixel_tick),
    .display_active(console_display_active),
    .pixel_x(console_pixel_x),
    .pixel_y(console_pixel_y),
    .hsync(console_hs),
    .vsync(console_vs),
    .frame_tick(console_frame_tick)
);

console_ps2_rx u_console_ps2_rx (
    .clk(CLK100MHZ),
    .reset(reset),
    .ps2_clk(PS2_CLK),
    .ps2_data(PS2_DATA),
    .byte_ready(console_ps2_byte_ready),
    .byte_data(console_ps2_byte_data)
);
```

顶层再把公共服务分发给每个槽位，例如 slot4 的连接方式是：

```verilog
game_slot4_top u_game_slot4_top (
    .clk(CLK100MHZ),
    .reset(reset | ~slot4_selected),
    .selected(slot4_selected),
    .frame_tick(console_frame_tick),
    .pixel_tick(console_pixel_tick),
    .display_active(console_display_active),
    .pixel_x(console_pixel_x),
    .pixel_y(console_pixel_y),
    .btn_u(BTNU),
    .btn_d(BTND),
    .btn_l(BTNL),
    .btn_r(BTNR),
    .btn_c(BTNC),
    .sw(SW),
    .ps2_clk(PS2_CLK),
    .ps2_data(PS2_DATA),
    .ps2_byte_ready(console_ps2_byte_ready),
    .ps2_byte_data(console_ps2_byte_data),
    .vga_r(slot4_vga_r),
    .vga_g(slot4_vga_g),
    .vga_b(slot4_vga_b),
    .led(slot4_led),
    .an(slot4_an),
    .buzzer(slot4_buzzer)
);
```

输出复用的核心思想是：菜单激活时显示菜单；菜单关闭时显示当前游戏。

```verilog
assign active_slot_vga_r = slot1_selected ? slot1_vga_r :
                           slot2_selected ? slot2_vga_r :
                           slot3_selected ? slot3_vga_r :
                                            slot4_vga_r;

assign active_slot_led = slot1_selected ? slot1_led :
                         slot2_selected ? slot2_led :
                         slot3_selected ? slot3_led :
                                          slot4_led;

assign LED    = menu_active ? (16'h8000 | (16'h0001 << menu_cursor)) : active_slot_led;
assign AN     = menu_active ? 8'b1111_1111 : active_slot_an;
assign BUZZER = menu_active ? 1'b1 : active_slot_buzzer;

always @(*) begin
    if (menu_active) begin
        VGA_R  = menu_vga_r_q;
        VGA_G  = menu_vga_g_q;
        VGA_B  = menu_vga_b_q;
        VGA_HS = console_hs;
        VGA_VS = console_vs;
    end else begin
        VGA_R  = active_slot_vga_r;
        VGA_G  = active_slot_vga_g;
        VGA_B  = active_slot_vga_b;
        VGA_HS = console_hs;
        VGA_VS = console_vs;
    end
end
```

这段代码在汇报时可以解释为：

> 顶层不关心每个游戏内部如何实现，它只关心当前哪个槽位被选择，然后把对应槽位的 RGB、LED、七段管和蜂鸣器输出接到真实板卡外设上。这就是我把多个游戏组织成一个“游戏集合机”的关键。

---

## 5. VGA 显示原理：从数码管到实时像素扫描

### 5.1 先讲概念

VGA 是本项目最重要的学习点。它和数码管/OLED 的思路很不一样。

数码管显示通常是“准备好要显示的数字，然后周期扫描位选”；VGA 显示则是显示器按固定时序从左到右、从上到下扫描，FPGA 必须在每个像素周期输出当前像素的 RGB 颜色，同时输出水平同步 `HS` 和垂直同步 `VS`。

可以这样讲：

> VGA 显示不是 FPGA 把一整张图片一次性传给显示器。  
> FPGA 做的是实时生成扫描时序：当前扫描到第几列、第几行，就把对应像素的颜色输出到 VGA_R/G/B。  
> 所以我需要先用计数器生成 `pixel_x` 和 `pixel_y`，再让菜单或游戏渲染器根据这个坐标决定当前像素颜色。

### 5.2 VGA 显示链路

```text
100 MHz 主时钟 CLK100MHZ
        ↓
像素使能 pixel_tick，大约每 4 个主时钟产生一次
        ↓
h_count / v_count 计数
        ↓
pixel_x / pixel_y / display_active
        ↓
菜单渲染器或游戏渲染器
        ↓
VGA_R / VGA_G / VGA_B
        ↓
VGA_HS / VGA_VS 同步显示器
```

### 5.3 核心代码位置：VGA 时序发生器

文件位置：

```text
src/common/console_vga_sync.v
```

核心代码摘录：

```verilog
module console_vga_sync (
    input  wire clk,
    input  wire reset,
    output wire pixel_tick,
    output wire display_active,
    output wire [9:0] pixel_x,
    output wire [9:0] pixel_y,
    output reg  hsync,
    output reg  vsync,
    output wire frame_tick
);
```

#### 5.3.1 640×480 可见区与消隐区参数

```verilog
localparam integer H_VISIBLE = 640;
localparam integer H_FRONT   = 16;
localparam integer H_SYNC    = 96;
localparam integer H_BACK    = 48;
localparam integer H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

localparam integer V_VISIBLE = 480;
localparam integer V_FRONT   = 10;
localparam integer V_SYNC    = 2;
localparam integer V_BACK    = 33;
localparam integer V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;
```

解释：

- `H_VISIBLE=640`：一行真正显示的 640 个像素。
- `H_FRONT/H_SYNC/H_BACK`：水平前沿、同步脉冲和后沿，这些时间不显示有效图像。
- `V_VISIBLE=480`：一帧真正显示的 480 行。
- `V_FRONT/V_SYNC/V_BACK`：垂直方向的消隐和同步区域。
- 所以整个 VGA 扫描不只是 640×480，还包含不可见的同步和回扫区。

#### 5.3.2 从 100 MHz 主时钟得到像素节拍

```verilog
reg [1:0] pix_div;
assign pixel_tick = (pix_div == 2'b11);

always @(posedge clk) begin
    if (reset) begin
        pix_div <= 2'b00;
    end else begin
        pix_div <= pix_div + 2'b01;
    end
end
```

解释：

> 板卡主时钟是 100 MHz，而 640×480@60Hz VGA 常用 25 MHz 级别像素时钟。这里没有新建独立时钟，而是用 `pix_div` 每 4 个主时钟产生一次 `pixel_tick`。这样所有逻辑仍在 100 MHz 主时钟域里，只是在 `pixel_tick=1` 的时候推进 VGA 坐标。

#### 5.3.3 产生当前像素坐标

```verilog
reg [9:0] h_count;
reg [9:0] v_count;

assign display_active = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
assign pixel_x = h_count;
assign pixel_y = v_count;

assign frame_tick = pixel_tick &&
                    (h_count == H_TOTAL - 1) &&
                    (v_count == V_TOTAL - 1);
```

解释：

- `h_count` 表示当前扫描列。
- `v_count` 表示当前扫描行。
- `display_active` 表示当前是否在 640×480 可见区。
- `frame_tick` 表示一帧结束，可以作为游戏状态更新的低速节拍。

#### 5.3.4 水平和垂直计数器

```verilog
always @(posedge clk) begin
    if (reset) begin
        h_count <= 10'd0;
        v_count <= 10'd0;
    end else if (pixel_tick) begin
        if (h_count == H_TOTAL - 1) begin
            h_count <= 10'd0;
            if (v_count == V_TOTAL - 1) begin
                v_count <= 10'd0;
            end else begin
                v_count <= v_count + 10'd1;
            end
        end else begin
            h_count <= h_count + 10'd1;
        end
    end
end
```

解释：

> 每来一个像素节拍，水平计数器加一；一行结束后水平计数器归零，垂直计数器加一；一帧结束后垂直计数器也归零。这样就形成了从左到右、从上到下的扫描顺序。

#### 5.3.5 产生 HS / VS 同步信号

```verilog
always @(posedge clk) begin
    if (reset) begin
        hsync <= 1'b1;
        vsync <= 1'b1;
    end else if (pixel_tick) begin
        hsync <= ~((h_count >= H_VISIBLE + H_FRONT) &&
                   (h_count <  H_VISIBLE + H_FRONT + H_SYNC));

        vsync <= ~((v_count >= V_VISIBLE + V_FRONT) &&
                   (v_count <  V_VISIBLE + V_FRONT + V_SYNC));
    end
end
```

解释：

> `hsync` 和 `vsync` 是显示器识别行同步和帧同步的信号。这里用计数器判断当前是否进入同步脉冲区，并输出低有效同步脉冲。

### 5.4 VGA 部分的核心收获

验收时建议强调下面这句话：

> VGA 让我真正理解到，硬件显示不是“调用绘图函数”，而是“每个像素周期都要在时序限制内给出正确颜色”。因此，画面越丰富，像素级组合逻辑就越多，后面 LUT 占用和 WNS 优化也就越重要。

---

## 6. 菜单渲染：把像素坐标变成界面

### 6.1 菜单渲染的角色

文件位置：

```text
src/common/console_menu_renderer.v
```

这个模块负责在 `menu_active=1` 时，根据当前像素坐标 `pixel_x/pixel_y` 和菜单光标 `cursor` 输出菜单画面的 RGB。

顶层中菜单渲染器的连接方式是：

```verilog
console_menu_renderer u_console_menu_renderer (
    .clk(CLK100MHZ),
    .reset(reset),
    .frame_tick(console_frame_tick),
    .display_active(console_display_active),
    .pixel_x(console_pixel_x),
    .pixel_y(console_pixel_y),
    .cursor(menu_cursor),
    .vga_r(menu_vga_r),
    .vga_g(menu_vga_g),
    .vga_b(menu_vga_b)
);
```

顶层还在 `pixel_tick` 边界采样菜单 RGB：

```verilog
always @(posedge CLK100MHZ) begin
    if (reset) begin
        menu_vga_r_q <= 4'h0;
        menu_vga_g_q <= 4'h0;
        menu_vga_b_q <= 4'h0;
    end else if (console_pixel_tick) begin
        menu_vga_r_q <= menu_vga_r;
        menu_vga_g_q <= menu_vga_g;
        menu_vga_b_q <= menu_vga_b;
    end
end
```

这段代码的讲法是：

> 菜单渲染器可能包含文字、边框、选中高亮等组合判断。为了让 VGA 输出更稳定，顶层在 `pixel_tick` 边界对菜单 RGB 进行寄存采样。这样显示输出与像素推进节拍对齐。

### 6.2 菜单渲染逻辑的伪代码

菜单渲染器的完整代码较长，可以在汇报时用伪代码说明：

```verilog
// 文件：src/common/console_menu_renderer.v
// 伪代码：根据当前像素坐标决定菜单颜色
always @(*) begin
    if (!display_active) begin
        rgb = 12'h000;                 // 消隐区输出黑色
    end else if (pixel 命中标题文字) begin
        rgb = title_color;
    end else if (pixel 命中某个菜单项文字) begin
        if (该菜单项 == cursor)
            rgb = highlight_color;     // 当前选中项高亮
        else
            rgb = normal_text_color;
    end else if (pixel 命中边框或背景装饰) begin
        rgb = decoration_color;
    end else begin
        rgb = background_color;
    end
end
```

这部分可以和资源优化联系起来：

> 菜单渲染虽然看起来只是界面，但它实际上也是像素级组合逻辑。如果文字、字模和图形判断全部写成 `case/function/if`，就会占用不少 LUT。后期资源分析里，菜单渲染器就是一个典型的 LUT 热点。

---

## 7. PS/2 键盘输入：把物理信号变成游戏事件

### 7.1 为什么需要 PS/2

板上的五个按键适合做简单控制，但游戏集合机需要更自然的输入方式。因此项目使用 PS/2 键盘作为主要输入设备。

可以这样讲：

> 这里我学到的重点是，外设输入不能直接当普通按键使用。PS/2 是串行协议，键盘会按位发送扫描码。FPGA 需要先同步 `PS2_CLK` 和 `PS2_DATA`，在 PS/2 时钟下降沿采样，组装成一个 byte 事件，再由菜单或游戏模块解释这个 byte 的含义。

### 7.2 输入处理链路

```text
PS2_CLK / PS2_DATA
        ↓
console_ps2_rx
        ↓
byte_ready / byte_data
        ↓
console_menu_controller
        ↓
W/S 或方向键：移动菜单
Enter / Space：启动游戏
Esc：返回菜单
        ↓
游戏槽位也可以接收同一份 ps2_byte_ready / ps2_byte_data
```

### 7.3 核心代码位置：PS/2 接收器

文件位置：

```text
src/common/console_ps2_rx.v
```

核心代码摘录：

```verilog
module console_ps2_rx (
    input  wire clk,
    input  wire reset,
    input  wire ps2_clk,
    input  wire ps2_data,
    output reg  byte_ready,
    output reg [7:0] byte_data
);
```

先同步 PS/2 时钟和数据，再检测下降沿：

```verilog
reg ps2_clk_ff0;
reg ps2_clk_ff1;
reg ps2_data_ff0;
reg ps2_data_ff1;

wire ps2_clk_fall;
assign ps2_clk_fall = ps2_clk_ff1 & ~ps2_clk_ff0;

always @(posedge clk) begin
    if (reset) begin
        ps2_clk_ff0  <= 1'b1;
        ps2_clk_ff1  <= 1'b1;
        ps2_data_ff0 <= 1'b1;
        ps2_data_ff1 <= 1'b1;
    end else begin
        ps2_clk_ff0  <= ps2_clk;
        ps2_clk_ff1  <= ps2_clk_ff0;
        ps2_data_ff0 <= ps2_data;
        ps2_data_ff1 <= ps2_data_ff0;
    end
end
```

接收 11 位 PS/2 数据帧：起始位、8 位数据、校验位、停止位。项目中核心逻辑如下：

```verilog
if (ps2_clk_fall) begin
    case (bit_count)
        4'd0: begin
            if (ps2_data_ff1 == 1'b0)
                bit_count <= 4'd1;     // 起始位为 0
        end
        4'd1: begin shift_data[0] <= ps2_data_ff1; bit_count <= 4'd2; end
        4'd2: begin shift_data[1] <= ps2_data_ff1; bit_count <= 4'd3; end
        4'd3: begin shift_data[2] <= ps2_data_ff1; bit_count <= 4'd4; end
        4'd4: begin shift_data[3] <= ps2_data_ff1; bit_count <= 4'd5; end
        4'd5: begin shift_data[4] <= ps2_data_ff1; bit_count <= 4'd6; end
        4'd6: begin shift_data[5] <= ps2_data_ff1; bit_count <= 4'd7; end
        4'd7: begin shift_data[6] <= ps2_data_ff1; bit_count <= 4'd8; end
        4'd8: begin shift_data[7] <= ps2_data_ff1; bit_count <= 4'd9; end
        4'd9: begin bit_count <= 4'd10; end       // 校验位，本项目不展开讲
        4'd10: begin
            if (ps2_data_ff1 == 1'b1) begin       // 停止位为 1
                byte_data  <= shift_data;
                byte_ready <= 1'b1;
            end
            bit_count <= 4'd0;
        end
        default: bit_count <= 4'd0;
    endcase
end
```

讲解重点：

> `console_ps2_rx` 不直接判断用户按了哪个键，它只负责协议层，把物理串行输入变成 `byte_ready + byte_data`。这样底层外设接收和上层游戏控制就解耦了。

### 7.4 核心代码位置：菜单控制器

文件位置：

```text
src/common/console_menu_controller.v
```

扫描码定义：

```verilog
localparam [7:0] SCAN_F0    = 8'hF0;
localparam [7:0] SCAN_E0    = 8'hE0;
localparam [7:0] SCAN_W     = 8'h1D;
localparam [7:0] SCAN_S     = 8'h1B;
localparam [7:0] SCAN_SPACE = 8'h29;
localparam [7:0] SCAN_ENTER = 8'h5A;
localparam [7:0] SCAN_ESC   = 8'h76;
localparam [7:0] SCAN_UP    = 8'h75;
localparam [7:0] SCAN_DOWN  = 8'h72;

assign is_up_key    = (byte_data == SCAN_W) || (byte_data == SCAN_UP);
assign is_down_key  = (byte_data == SCAN_S) || (byte_data == SCAN_DOWN);
assign is_start_key = (byte_data == SCAN_SPACE) || (byte_data == SCAN_ENTER);
assign is_back_key  = (byte_data == SCAN_ESC);
```

菜单状态机核心逻辑：

```verilog
always @(posedge clk) begin
    if (reset) begin
        menu_active  <= 1'b1;
        game_sel     <= 3'd0;
        cursor       <= 3'd0;
        launch_pulse <= 1'b0;
        break_pending  <= 1'b0;
        extend_pending <= 1'b0;
    end else begin
        launch_pulse <= 1'b0;

        if (byte_ready) begin
            if (byte_data == SCAN_F0) begin
                break_pending <= 1'b1;     // key release 前缀
            end else if (byte_data == SCAN_E0) begin
                extend_pending <= 1'b1;    // 扩展键前缀
            end else begin
                if (!break_pending) begin
                    if (menu_active) begin
                        if (is_up_key)
                            cursor <= (cursor == 3'd0) ? MENU_LAST_ITEM : cursor - 3'd1;
                        else if (is_down_key)
                            cursor <= (cursor == MENU_LAST_ITEM) ? 3'd0 : cursor + 3'd1;
                        else if (is_start_key) begin
                            game_sel     <= cursor;
                            menu_active  <= 1'b0;
                            launch_pulse <= 1'b1;
                        end
                    end else if (is_back_key) begin
                        cursor      <= game_sel;
                        menu_active <= 1'b1;
                    end
                end
                break_pending  <= 1'b0;
                extend_pending <= 1'b0;
            end
        end
    end
end
```

讲解重点：

> 键盘输入被分成两层：底层 PS/2 接收器只输出扫描码；菜单控制器再把扫描码解释为“上移、下移、开始、返回”。这种分层让输入系统更清晰，也方便游戏槽位复用同一份键盘事件。

---

## 8. Game Slot API：让每个游戏像“卡带”一样接入

### 8.1 为什么需要统一接口

如果每个游戏都随便定义自己的端口，总顶层会非常混乱，也很难统一切换 VGA、LED、七段管和蜂鸣器输出。

所以项目定义了统一的 `game_slotN_top` 接口。每个游戏都接收相同的公共输入，例如 `clk/reset/selected/frame_tick/pixel_tick/pixel_x/pixel_y/ps2_byte_ready/ps2_byte_data`，并输出相同类型的外设信号。

讲解话术：

> 我把每个游戏设计成一个统一接口的槽位模块。顶层像游戏主机，槽位像卡带。只要一个游戏遵守接口，就能被集合机菜单启动、显示和退出。这样未来新增游戏时不需要重写整个顶层。

### 8.2 核心代码位置：API 文档

文件位置：

```text
docs/game_api.md
```

槽位模块标准端口：

```verilog
module game_slotN_top (
    input  wire clk,              // 100 MHz
    input  wire reset,            // active-high
    input  wire selected,         // 当前槽位是否被集合机菜单启动
    input  wire frame_tick,        // VGA 每帧一个脉冲
    input  wire pixel_tick,        // 25 MHz 级别像素使能
    input  wire display_active,    // 当前像素是否在 640x480 可见区
    input  wire [9:0] pixel_x,
    input  wire [9:0] pixel_y,

    input  wire btn_u,
    input  wire btn_d,
    input  wire btn_l,
    input  wire btn_r,
    input  wire btn_c,
    input  wire [15:0] sw,

    input  wire ps2_clk,
    input  wire ps2_data,
    input  wire ps2_byte_ready,
    input  wire [7:0] ps2_byte_data,

    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b,
    output wire [15:0] led,
    output wire [7:0] an,
    output wire ca, cb, cc, cd, ce, cf, cg, dp,
    output wire buzzer
);
```

必须遵守的核心规则：

```text
1. 游戏模块不要新建独立时钟，统一使用 100 MHz clk 和 clock enable。
2. reset 高有效，复位时游戏状态和输出必须回到安全状态。
3. display_active=0 时 RGB 应输出 0。
4. PS/2 优先使用顶层解析后的 ps2_byte_ready / ps2_byte_data。
5. selected=0 或 reset=1 时，游戏应停止改变内部状态。
6. 全局游戏选择由菜单处理，成员游戏不要再用 SW[2:0] 自己选游戏。
```

### 8.3 推荐内部结构

```text
game_slotN_top
├─ slotN_tick_gen       // 产生游戏节拍
├─ slotN_input          // 键盘/按键输入解释
├─ slotN_game_core      // 游戏规则、状态、碰撞、计分
├─ slotN_renderer       // 根据 pixel_x/y 输出 RGB
├─ slotN_sound          // 蜂鸣器或音效
└─ slotN_debug          // LED/七段管调试输出
```

---

## 9. 游戏逻辑如何讲：不要逐行讲，讲硬件游戏共性

### 9.1 所有游戏的共性架构

四个游戏规则不同，但 FPGA 实现结构可以统一讲成四层：

```text
输入层
  键盘事件 / 板上按键 / 开关
        ↓
游戏状态层
  玩家位置 / 地图 / 子弹 / 方块 / 碰撞 / 分数 / 胜负
        ↓
节拍控制层
  frame_tick 控制低速状态更新
  game_tick / gravity_tick 控制移动、重力或动画
        ↓
像素渲染层
  根据 pixel_x / pixel_y 判断当前像素颜色
        ↓
输出层
  VGA / LED / 七段管 / 蜂鸣器
```

讲解话术：

> 软件游戏里可以先更新状态，再调用绘图函数画一帧。  
> 但 FPGA 游戏更接近实时电路：游戏状态在时钟边沿更新，而 VGA 渲染器必须在每个像素周期根据坐标输出颜色。  
> 因此，我需要把游戏状态更新和像素渲染分开，并且让渲染路径足够短，能满足时序。

---

## 10. Slot1：Tank War 作为完整游戏接入集合机

### 10.1 文件位置

```text
src/games/slot1/game_slot1_top.v
src/games/tank/tank_top.v
```

`slot1` 是坦克大战槽位适配层，内部包装 `tank_top.v`。在最终结构里，Tank War 不再自己实例化独立 VGA 或 PS/2，而是复用集合机顶层提供的公共 `pixel_x/pixel_y/display_active/pixel_tick` 和 `ps2_byte_ready/ps2_byte_data`。

讲解话术：

> Tank War 是我第一个完整接入集合机的游戏。它证明了统一槽位 API 是可行的：坦克大战本体只关心自己的游戏状态、碰撞、地图、渲染和音效；菜单切换、VGA 时序和 PS/2 接收都由集合机顶层统一提供。

### 10.2 可以这样讲游戏本身

> Tank War 的核心逻辑包括玩家控制、坦克移动、方向、子弹、碰撞、胜负状态以及 VGA 渲染。  
> 从硬件角度看，最关键的是把“游戏状态更新”和“像素颜色输出”分离：坦克位置、子弹位置这些状态在时钟边沿更新；渲染器根据当前 `pixel_x/pixel_y` 判断这个像素是否属于地图、坦克、子弹或 UI。

---

## 11. Slot2：状态机、方块/棋盘状态与视频 staging

### 11.1 文件位置

```text
src/games/slot2/game_slot2_top.v
src/games/slot2/slot2_game_core.v
src/games/slot2/slot2_renderer.v
src/games/slot2/slot2_input.v
src/games/slot2/slot2_tick_gen.v
```

从代码结构看，Slot2 使用了棋盘 `board[199:0]`、当前方块 `piece_type/piece_rotation/piece_x/piece_y`、ghost 位置、分数、行数、等级和 game over 等状态。可以在汇报中称为 `GAME TWO`，技术上重点讲它体现了“游戏核心状态 + 像素渲染 + 时序优化”的结构。

### 11.2 关键代码：Slot2 顶层分层

文件位置：

```text
src/games/slot2/game_slot2_top.v
```

核心结构摘录：

```verilog
wire gravity_tick;
wire move_left, move_right, rotate_cw, soft_drop, hard_drop;
wire [199:0] board;
wire [2:0] piece_type, next_type;
wire [1:0] piece_rotation;
wire signed [4:0] piece_x;
wire [5:0] piece_y, ghost_piece_y;
wire [15:0] score;
wire [9:0] lines;
wire [3:0] level;
wire game_over;
```

模块划分：

```verilog
slot2_tick_gen u_tick (...);     // 根据 frame_tick / level 产生 gravity_tick
slot2_input    u_input (...);    // 把键盘/按键解释为 move/rotate/drop
slot2_game_core u_core (...);    // 维护棋盘、方块、分数、行数、等级
slot2_renderer u_render (...);   // 根据 pixel_x/y 渲染画面
```

讲解话术：

> Slot2 的结构比较能体现硬件游戏设计的分层：输入模块只产生动作脉冲，核心模块维护棋盘和方块状态，渲染模块把状态转成 VGA 像素颜色。这样每一层职责清晰，也更方便后期优化。

### 11.3 关键代码：视频 staging 优化

文件位置：

```text
src/games/slot2/game_slot2_top.v
```

在最终优化中，Slot2 在 `pixel_tick` 边界寄存渲染输入，降低渲染路径对动态状态变化的敏感性：

```verilog
(* keep = "true" *) reg selected_video_q;
(* keep = "true" *) reg [199:0] board_video_q;
(* keep = "true" *) reg [2:0] piece_type_video_q;
(* keep = "true" *) reg [1:0] piece_rotation_video_q;
(* keep = "true" *) reg signed [4:0] piece_x_video_q;
(* keep = "true" *) reg [5:0] piece_y_video_q;
(* keep = "true" *) reg [5:0] ghost_piece_y_video_q;
(* keep = "true" *) reg [2:0] next_type_video_q;
(* keep = "true" *) reg [15:0] score_video_q;
(* keep = "true" *) reg [9:0] lines_video_q;
(* keep = "true" *) reg [3:0] level_video_q;
(* keep = "true" *) reg game_over_video_q;

always @(posedge clk) begin
    if (reset) begin
        selected_video_q <= 1'b0;
        board_video_q <= 200'd0;
        // 其他视频寄存器复位省略
    end else if (pixel_tick) begin
        selected_video_q <= selected;
        board_video_q <= board;
        piece_type_video_q <= piece_type;
        piece_rotation_video_q <= piece_rotation;
        piece_x_video_q <= piece_x;
        piece_y_video_q <= piece_y;
        ghost_piece_y_video_q <= ghost_piece_y;
        next_type_video_q <= next_type;
        score_video_q <= score;
        lines_video_q <= lines;
        level_video_q <= level;
        game_over_video_q <= game_over;
    end
end
```

渲染结果也在 `pixel_tick` 边界寄存：

```verilog
always @(posedge clk) begin
    if (reset) begin
        vga_r <= 4'h0;
        vga_g <= 4'h0;
        vga_b <= 4'h0;
    end else if (pixel_tick) begin
        vga_r <= render_r;
        vga_g <= render_g;
        vga_b <= render_b;
    end
end
```

讲解话术：

> 这个优化体现了我后期对 FPGA 时序的理解：渲染器不应该直接面对大量随时变化的游戏状态，而是在像素边界锁存一份稳定的视频状态。这样既能减少毛刺风险，也有利于 Vivado 分析和优化 VGA 路径。

---

## 12. Slot3：玩家移动路径拆分，切断反馈长路径

### 12.1 文件位置

```text
src/games/slot3/slot3_player.v
```

Slot3 的一个关键时序优化点是注册 `try_x/try_y`，并使用 `move_pending/move_wait` 把“候选位置 → 地图可行性判断 → 玩家位置回写”拆开。

### 12.2 核心代码摘录

```verilog
output reg [9:0] try_x,
output reg [8:0] try_y,
```

复位时初始化当前坐标和候选坐标：

```verilog
if (reset || start_level) begin
    neo_x <= 10'd48;
    neo_y <= 9'd384;
    neo_dir <= 2'd1;

    try_x <= 10'd48;
    try_y <= 9'd384;
    move_pending <= 1'b0;
    move_wait <= 1'b0;
    move_dir_pending <= 2'd1;
end
```

移动请求分阶段处理：

```verilog
if (move_pending) begin
    if (move_wait) begin
        move_wait <= 1'b0;
    end else begin
        if (walkable) begin
            neo_x <= try_x;
            neo_y <= try_y;
            neo_dir <= move_dir_pending;
        end
        move_pending <= 1'b0;
    end
end

if (frame_tick) begin
    if (!move_pending && move_req) begin
        try_x <= candidate_x;
        try_y <= candidate_y;
        move_pending <= 1'b1;
        move_wait <= 1'b1;

        if (input_up_q)          move_dir_pending <= 2'd0;
        else if (input_right_q)  move_dir_pending <= 2'd1;
        else if (input_down_q)   move_dir_pending <= 2'd2;
        else                     move_dir_pending <= 2'd3;
    end else if (!move_pending) begin
        try_x <= neo_x;
        try_y <= neo_y;
    end
end
```

讲解话术：

> 原来如果在一拍内完成“按键输入 → 计算候选坐标 → 查询地图是否可走 → 更新玩家坐标”，路径会比较长。  
> 后来我把候选位置 `try_x/try_y` 先寄存下来，让地图判断在下一拍给出 `walkable`，再决定是否提交到 `neo_x/neo_y`。  
> 玩家从肉眼看不到延迟变化，因为这一切都发生在 100 MHz 时钟下，远快于一帧画面的时间，但对时序收敛很有帮助。

---

## 13. Slot4：tile map、碰撞检测与 staged probe 思想

### 13.1 文件位置

```text
src/games/slot4/game_slot4_top.v
```

Slot4 中可以看到明显的 tile map 和双角色逻辑，例如 `fire_x/fire_y`、`water_x/water_y`、门、宝石、危险 tile、地面检测、关卡完成与失败判断等。这个槽位后期优化重点是把碰撞和状态探测拆成更明确的阶段。

### 13.2 典型 tile 查询代码

文件位置：

```text
src/games/slot4/game_slot4_top.v
```

原理上，渲染和碰撞都需要把像素坐标映射到 tile 坐标。代码中用函数把像素转成格子：

```verilog
function [4:0] slot4_pixel_to_cell_y;
    input [9:0] py;
    begin
        if (py < 10'd20)       slot4_pixel_to_cell_y = 5'd0;
        else if (py < 10'd40)  slot4_pixel_to_cell_y = 5'd1;
        else if (py < 10'd60)  slot4_pixel_to_cell_y = 5'd2;
        // 中间省略：每 20 像素映射到一个 cell
        else if (py < 10'd460) slot4_pixel_to_cell_y = 5'd22;
        else                   slot4_pixel_to_cell_y = 5'd23;
    end
endfunction
```

`CELL=20` 时，优化后的思路不再依赖像素路径中的 `/ CELL` 和 `% CELL`，而是通过比较链和移位加法表达 cell 边界与局部坐标：

```verilog
function [4:0] slot4_cell_local;
    input [9:0] p;
    input [4:0] cell_idx;
    reg [9:0] origin;
    begin
        origin = ({5'd0, cell_idx} << 4) + ({5'd0, cell_idx} << 2); // cell_idx * 20
        slot4_cell_local = p - origin;
    end
endfunction
```

讲解话术：

> Slot4 中 tile 是 20×20 像素。如果直接在像素路径里写 `pixel_x / 20` 或 `pixel_x % 20`，Vivado 可能综合出比较大的组合网络。  
> 所以后期优化时，我把这类运算改成更硬件友好的比较、移位和加法，让像素路径更可控。

### 13.3 碰撞探测与状态评估

Slot4 中典型的 solid 判断：

```verilog
function slot4_is_solid_tile;
    input [3:0] tile;
    input open_gate;
    begin
        slot4_is_solid_tile = (tile == TILE_WALL) ||
                              ((tile == TILE_GATE) && !open_gate);
    end
endfunction
```

角色是否撞墙，需要检查角色边缘或角点：

```verilog
function slot4_player_solid;
    input [1:0] lvl;
    input [9:0] px;
    input [9:0] py;
    input open_gate;
    begin
        slot4_player_solid =
            slot4_solid_at(lvl, px, py, open_gate) ||
            slot4_solid_at(lvl, px + PLAYER_W - 1, py, open_gate) ||
            slot4_solid_at(lvl, px, py + PLAYER_H - 1, open_gate) ||
            slot4_solid_at(lvl, px + PLAYER_W - 1, py + PLAYER_H - 1, open_gate);
    end
endfunction
```

最终优化文档中，Slot4 的思路可以概括为下面的伪代码：

```verilog
// 文件：src/games/slot4/game_slot4_top.v
// 伪代码：把直接碰撞判断拆成探测、评估、应用
case (physics_state)
    TEST: begin
        // 先寄存要查询的 tile 地址，而不是一拍内直接算完整结果
        probe_addr0_q <= calc_corner_addr(next_x, next_y);
        probe_addr1_q <= calc_corner_addr(next_x + PLAYER_W - 1, next_y);
        physics_state <= EVAL;
    end

    EVAL: begin
        // 下一拍读出 tile，再评估是否 solid / failed / complete
        blocked_eval_q  <= is_solid(tile_rom[probe_addr0_q]) ||
                           is_solid(tile_rom[probe_addr1_q]);
        failed_eval_q   <= hit_danger_tile;
        complete_eval_q <= all_gems_collected && at_door;
        physics_state <= APPLY;
    end

    APPLY: begin
        // 再下一拍真正更新角色坐标和游戏状态
        if (!blocked_eval_q)
            player_pos <= next_pos;
        level_failed_q   <= failed_eval_q;
        level_complete_q <= complete_eval_q;
        physics_state <= TEST;
    end
endcase
```

讲解话术：

> Slot4 的优化重点是把一拍内很长的“坐标计算 → tile 地址 → tile 读取 → solid 判断 → 角色状态更新”拆开。  
> 这样玩家看到的游戏行为没有变化，但 FPGA 每个时钟周期内要完成的组合逻辑减少了，时序更容易收敛。

---

## 14. 资源占用分析：LUT 高、FF 低说明什么

### 14.1 文件位置

```text
docs/资源占用分析.md
```

资源分析中记录，顶层 `game_console_top` 使用约：

```text
LUT：30146 / 63400，约 48%
FF ： 4371 / 126800，约 3%
```

这说明：

> 当前设计不是 FPGA 资源完全不够，而是实现风格比较偏“像素级大组合逻辑”。LUT 占用高，但寄存器使用率很低，说明很多文字、地图、sprite、tile、对象命中和图层优先级判断都被综合成了组合逻辑网络。

### 14.2 可以放在 PPT 里的表

| 指标 | 数值 | 说明 |
| --- | ---: | --- |
| LUT | 30146 / 63400，约 48% | 组合逻辑压力明显 |
| FF | 4371 / 126800，约 3% | 寄存器使用很少 |
| 主要问题 | LUT 高、FF 低 | 像素级组合渲染和对象判断较重 |
| 优化方向 | 用寄存器、ROM、pipeline 换组合路径 | 缩短关键路径，提高 WNS |

### 14.3 如何解释给老师听

> 一开始我看到 LUT 接近一半，会以为只是代码写得太多。后来分析报告后，我意识到问题更具体：它不是寄存器太多，而是组合逻辑太重。  
> 对 VGA 游戏来说，每个像素都可能要判断背景、地图、玩家、子弹、文字、UI、图层优先级。如果这些都在一个组合块里完成，就会形成很多 LUT 和很长的组合路径。  
> 所以后期优化不是盲目减少寄存器，而是反过来，适当增加寄存器，用 pipeline 和 staging 把长组合逻辑切短。

---

## 15. 时序优化：从 WNS 为负到 post-route 收敛

### 15.1 文件位置

```text
docs/final_timing_optimization_round.md
scripts/apply_timing_exceptions.tcl
scripts/build_bitstream.tcl
scripts/report_timing_post_route.tcl
```

最终优化目标非常明确：

```text
不改变游戏规则、不改变地图、不改变渲染内容、不改变控制方式、
不改变计分、不改变音频、不改变菜单行为、不改变槽位切换；
只优化 RTL 结构和时序路径。
```

### 15.2 WNS / TNS 怎么讲

可以这样解释：

> WNS 是 Worst Negative Slack，表示最差路径还差多少时间。如果 WNS 为负，说明最慢的一条路径在一个时钟周期内来不及。  
> TNS 是 Total Negative Slack，表示所有失败路径的 slack 总和。如果 TNS 为 0，说明没有负 slack 路径。  
> 所以最终目标是 WNS 为正，TNS 为 0。

### 15.3 最终时序结果

| 阶段 | WNS | TNS | 失败端点 |
| --- | ---: | ---: | ---: |
| 移除宽泛例外后的真实基线 | -0.445 ns | -18.104 ns | 94 |
| 最终 post-route | +0.174 ns | 0.000 ns | 0 |

讲解话术：

> 这个结果说明，项目最后不是靠掩盖问题通过，而是在真实 100 MHz 约束下完成了时序收敛。虽然最终余量不算特别大，但已经从负 WNS 优化到了正 WNS，TNS 也归零。

### 15.4 优化一：Slot2 ghost / lock / video staging

文件位置：

```text
src/games/slot2/slot2_game_core.v
src/games/slot2/game_slot2_top.v
```

核心思想：

```text
原来：一拍内直接完成 ghost 位置计算、碰撞判断和锁定行更新
优化：ghost 改成迭代 probe，lock 改成 ST_LOCK_ROW，视频路径增加 pixel_tick staging
```

`slot2_game_core.v` 中状态定义示例：

```verilog
localparam ST_PLAYING       = 4'd0;
localparam ST_HARD_DROP     = 4'd1;
localparam ST_LOCK_ROW      = 4'd2;
localparam ST_CLEAR_ANIM    = 4'd3;
localparam ST_ROW_SCAN      = 4'd4;
localparam ST_COMPACT_PREP  = 4'd5;
localparam ST_COMPACT_SCAN  = 4'd6;
localparam ST_COMPACT_APPLY = 4'd7;
localparam ST_GAME_OVER     = 4'd8;
```

`ST_LOCK_ROW` 的意义是：不要把所有行写入都折叠成一拍，而是逐行完成 piece lock。

```verilog
ST_LOCK_ROW: begin
    case (lock_abs_y)
        7'd0:  board_reg[0   +: 10] <= board_reg[0   +: 10] | lock_mask;
        7'd1:  board_reg[10  +: 10] <= board_reg[10  +: 10] | lock_mask;
        7'd2:  board_reg[20  +: 10] <= board_reg[20  +: 10] | lock_mask;
        // 中间省略：按行定位 board_reg
        7'd16: board_reg[160 +: 10] <= board_reg[160 +: 10] | lock_mask;
    endcase
end
```

讲解话术：

> Slot2 优化体现的是“把一次大计算拆成多个小步骤”。这不会改变用户看到的游戏行为，因为这些步骤都在 100 MHz 时钟下、远小于一帧时间内完成，但可以显著缩短单拍组合逻辑。

### 15.5 优化二：Slot3 player-map-player 反馈路径拆分

文件位置：

```text
src/games/slot3/slot3_player.v
```

核心思想：

```text
原来：玩家输入 → 候选坐标 → 地图 walkable → 直接更新玩家位置
优化：候选坐标 try_x/try_y 先寄存，下一拍根据 walkable 决定是否提交
```

核心代码已在第 12 节贴出。验收时可以重点说：

> 这是一个典型的“反馈路径拆分”。我把从玩家状态到地图判断再回到玩家状态的长路径切成两拍，从而降低单周期组合逻辑深度。

### 15.6 优化三：Slot4 tile / physics staged probe

文件位置：

```text
src/games/slot4/game_slot4_top.v
```

核心思想：

```text
原来：直接函数调用完成坐标、tile、solid、failed、complete 判断
优化：先寄存 probe 地址，再评估 tile 结果，再应用到角色和关卡状态
```

讲解话术：

> Slot4 的碰撞和关卡判定涉及多个 tile 点，例如角色角点、脚底点、门、宝石和危险区域。  
> 如果所有判断一拍内完成，组合链会很长。  
> 后来我把它拆成地址探测、结果评估和状态应用三个阶段，这就是我在这个项目里学到的流水化思想。

### 15.7 优化四：只保留窄范围 VGA multicycle，不掩盖核心路径

文件位置：

```text
scripts/apply_timing_exceptions.tcl
```

这个脚本的注释说明了最终约束策略：

```tcl
# Timing exceptions for VGA rendering paths.
#
# The console VGA generator runs on CLK100MHZ but advances pixel_x/pixel_y and
# samples per-slot RGB only when pixel_tick is asserted once every four clocks.
# The multicycle paths below are restricted to registers that either start from
# that pixel-tick coordinate/staging boundary or end at RGB registers sampled on
# the same pixel_tick enable. They intentionally do not cover game-core state.
```

讲解话术：

> 这里我学到的是，时序优化不能只靠加宽泛约束。  
> 对于明确由 `pixel_tick` 保持的视频路径，可以给窄范围 multicycle，因为这些路径本来就是 4 个主时钟推进一次。  
> 但游戏核心状态路径不能用宽泛 multicycle 掩盖，因为它们是真实 100 MHz 状态更新路径，必须通过 RTL 拆分来解决。

---

## 16. Vivado 构建与最终产物

### 16.1 建工程方式

仓库推荐使用脚本创建 Vivado 工程：

```tcl
cd nexys_game_console
vivado -mode batch -source scripts/create_vivado_project.tcl
```

手动建工程时要点：

```text
1. 选择 part：xc7a100tcsg324-1
2. 添加 src/ 下所有 .v 文件
3. 添加 constraints/game_console.xdc
4. 设置顶层模块为 game_console_top
5. Generate Bitstream 后上板
```

### 16.2 最终构建命令

最终时序优化文档中记录的构建命令：

```tcl
vivado -mode batch -source scripts/sync_vivado_project_sources.tcl
vivado -mode batch -source scripts/build_bitstream.tcl
vivado -mode batch -source scripts/report_timing_post_route.tcl
```

最终生成产物：

```text
build/vivado/game_console_top.bit
build/vivado/game_console_top_impl.dcp
build/vivado/reports/timing_summary_post_route.rpt
build/vivado/reports/timing_worst_50.rpt
build/vivado/reports/timing_exceptions.rpt
build/vivado/reports/timing_exception_object_counts.txt
build/vivado/reports/design_analysis_post_route.rpt
build/vivado/reports/utilization_hierarchical_post_route.rpt
```

---

## 17. XDC 与板级外设连接

### 17.1 文件位置

```text
constraints/game_console.xdc
```

约束文件完成了以下外设绑定：

```text
CLK100MHZ
CPU_RESETN
PS2_CLK / PS2_DATA
BTNU / BTND / BTNL / BTNR / BTNC
SW[15:0]
VGA_R[3:0] / VGA_G[3:0] / VGA_B[3:0]
VGA_HS / VGA_VS
BUZZER
LED[15:0]
AN[7:0]
CA / CB / CC / CD / CE / CF / CG / DP
```

关键示例：

```tcl
set_property PACKAGE_PIN E3 [get_ports CLK100MHZ]
set_property IOSTANDARD LVCMOS33 [get_ports CLK100MHZ]
create_clock -period 10.000 [get_ports CLK100MHZ]

set_property PACKAGE_PIN F4 [get_ports PS2_CLK]
set_property IOSTANDARD LVCMOS33 [get_ports PS2_CLK]
set_property PULLUP true [get_ports PS2_CLK]

set_property PACKAGE_PIN B2 [get_ports PS2_DATA]
set_property IOSTANDARD LVCMOS33 [get_ports PS2_DATA]
set_property PULLUP true [get_ports PS2_DATA]

set_property PACKAGE_PIN B11 [get_ports VGA_HS]
set_property IOSTANDARD LVCMOS33 [get_ports VGA_HS]

set_property PACKAGE_PIN B12 [get_ports VGA_VS]
set_property IOSTANDARD LVCMOS33 [get_ports VGA_VS]
```

讲解话术：

> XDC 的作用是把 Verilog 顶层端口绑定到真实 FPGA 引脚。对于这个项目，最关键的约束是 100 MHz 主时钟、VGA 引脚、PS/2 引脚、按键、开关、LED 和七段管。  
> PS/2 的时钟和数据线还启用了 pull-up，因为 PS/2 总线空闲时需要保持高电平。

---

## 18. 完整验收讲稿

下面是一段可以直接背诵或改写的完整讲稿。

### 18.1 开场

> 我的第二个数电实验是一个基于 Nexys A7-100T 的 VGA 游戏集合机，我把它的主题概括为“学”。  
> 因为和第一个时钟项目相比，这个项目引入了很多我之前没有系统掌握的新内容：VGA 实时显示、PS/2 键盘输入、多游戏槽位架构、像素级渲染、资源占用分析和时序优化。  
> 所以我不是把它看成简单做几个小游戏，而是把它看作一次从基础 Verilog 到 FPGA 图形交互系统的学习过程。

### 18.2 产品介绍

> 从用户角度看，它是一台简易 FPGA 游戏主机。上电后显示器会出现 VGA 菜单，用户可以用键盘的 W/S 或方向键上下选择游戏，用 Enter 或 Space 启动游戏，进入游戏后可以按 Esc 返回菜单。  
> 目前集合机有四个槽位，分别是 Tank War、Game Two、Game Three 和 Game Four。  
> VGA 是主显示设备，PS/2 键盘是主输入设备，LED、七段管和蜂鸣器作为辅助反馈。

### 18.3 架构介绍

> 架构上，我没有让每个游戏各写一套 VGA 和键盘逻辑，而是把公共服务放到总顶层 `game_console_top` 中。  
> 顶层统一实例化 `console_vga_sync` 产生 VGA 时序和像素坐标，统一实例化 `console_ps2_rx` 接收键盘扫描码，再由 `console_menu_controller` 管理菜单状态。  
> 每个游戏都按照统一的 Game Slot API 接入，只需要接收 `pixel_x/pixel_y`、`pixel_tick`、`display_active` 和键盘 byte 事件，然后输出自己的 RGB、LED、七段管和蜂鸣器信号。  
> 这样整个系统就像一台游戏主机，游戏槽位像卡带一样可以替换。

### 18.4 VGA 原理

> VGA 是这个项目我学到的第一个核心内容。  
> VGA 显示不是把一整张图片传给显示器，而是 FPGA 按照固定时序一行一行、一点一点地实时输出颜色。  
> 在我的 `console_vga_sync.v` 中，水平可见区是 640，垂直可见区是 480，同时还包含 front porch、sync pulse 和 back porch。  
> 板卡主时钟是 100 MHz，我用 `pix_div` 每 4 个主时钟产生一次 `pixel_tick`，相当于用 25 MHz 级别的像素节拍推进 `h_count` 和 `v_count`。  
> 当前像素坐标 `pixel_x/pixel_y` 会交给菜单或游戏渲染器，渲染器再根据这个坐标判断当前像素应该显示背景、地图、角色、子弹、文字还是 UI。

### 18.5 PS/2 输入

> 另一个重要学习点是 PS/2 键盘输入。  
> PS/2 不是普通按键，而是串行协议。底层 `console_ps2_rx` 会同步 PS/2 时钟和数据，在 PS/2 时钟下降沿采样，接收起始位、8 位数据、校验位和停止位，最终输出 `byte_ready` 和 `byte_data`。  
> 上层 `console_menu_controller` 再把扫描码解释成 W/S、方向键、Enter、Space 和 Esc。  
> 这里我学到的是外设输入要先协议解析，再事件化，最后才交给菜单或游戏状态机使用。

### 18.6 游戏槽位和游戏逻辑

> 游戏部分我采用统一槽位接口。每个游戏都有相同端口，包括时钟、复位、是否被选中、帧脉冲、像素节拍、像素坐标、键盘事件，以及 VGA、LED、七段管和蜂鸣器输出。  
> 游戏内部一般分成输入层、状态层、节拍层、渲染层和输出层。  
> 比如 Tank War 负责坦克移动、方向、子弹、碰撞和胜负；Slot2 维护棋盘、方块、ghost、分数和等级；Slot3 使用 `try_x/try_y` 拆分玩家移动和地图判断；Slot4 则使用 tile map 和分阶段碰撞检测。  
> 这些游戏虽然规则不同，但都复用同一套顶层 VGA 和 PS/2 服务。

### 18.7 资源分析

> 项目后期我开始分析 Vivado 资源报告，发现 LUT 占用较高，而 FF 占用很低。  
> 顶层大约使用了 30146 个 LUT，占 48%，但 FF 只有 4371 个，占 3%。  
> 这说明问题不是寄存器太多，而是像素级组合逻辑太重。  
> 对 VGA 游戏来说，文字、地图、sprite、tile、对象命中检测和图层优先级都会变成组合逻辑。如果都在一个周期里完成，就会消耗很多 LUT，并造成关键路径变长。  
> 所以我的优化方向不是一味减少寄存器，而是适当增加寄存器和 pipeline，把长组合逻辑切短。

### 18.8 时序优化

> 最后一个重点是时序优化。  
> 我后期做了一轮专门的 timing optimization，目标是不改变游戏规则、地图、渲染内容、控制方式和菜单行为，只优化 RTL 结构和时序路径。  
> 具体做法包括：Slot2 把 ghost 和 lock 流程拆开，并加入 `pixel_tick` 视频 staging；Slot3 把玩家移动候选坐标 `try_x/try_y` 先寄存，下一拍再根据 `walkable` 提交；Slot4 把 tile 碰撞和状态判断拆成探测、评估、应用阶段；时序约束方面去掉宽泛 multicycle，只保留明确由 `pixel_tick` 保持的视频路径例外。  
> 最终移除宽泛例外后的真实基线是 WNS=-0.445ns、TNS=-18.104ns、94 个失败端点；优化后 post-route WNS=+0.174ns，TNS=0，失败端点为 0，并成功生成 bitstream。  
> 这说明项目最后不是靠隐藏问题通过，而是在真实 100 MHz 约束下完成了时序收敛。

### 18.9 总结

> 所以我把第二个实验总结为“学”。  
> 这个项目让我从简单的数码管显示和按键输入，进入到 VGA 图形系统、PS/2 外设协议、多游戏平台架构、资源分析和时序优化。  
> 我最大的收获是：FPGA 设计不是代码能综合就结束了，而是要让功能、结构、资源和时序都能统一起来。  
> 这个项目最终让我从“实现一个功能”进一步理解到“设计一个能交互、能显示、能扩展、能优化、能生成 bitstream 的硬件系统”。

---

## 19. PPT 页结构建议

| 页码 | 标题 | 内容 |
| --- | --- | --- |
| 1 | “学”：基于 Nexys A7 的 VGA 游戏集合机 | 项目标题、主题、板卡 |
| 2 | 项目定位 | VGA 菜单、PS/2 键盘、四个游戏槽位 |
| 3 | 用户操作流程 | 上电 → 菜单 → 选择 → 游戏 → Esc 返回 |
| 4 | 系统总体架构 | `game_console_top` + common + slot1~slot4 |
| 5 | VGA 显示原理 | `pixel_tick`、`h_count/v_count`、RGB、HS/VS |
| 6 | VGA 核心代码 | `src/common/console_vga_sync.v` 摘录 |
| 7 | PS/2 输入 | `console_ps2_rx` 和菜单扫描码 |
| 8 | Game Slot API | 统一端口、像卡带一样接入 |
| 9 | 游戏逻辑共性 | 输入层、状态层、节拍层、渲染层、输出层 |
| 10 | 资源占用分析 | LUT 30146、FF 4371，LUT 高 FF 低 |
| 11 | 优化思想 | staging、pipeline、小 FSM、多拍计算 |
| 12 | 时序优化案例 | Slot2/Slot3/Slot4 具体优化 |
| 13 | 最终时序结果 | WNS -0.445 → +0.174，TNS 归零 |
| 14 | 学习收获 | VGA、PS/2、槽位架构、LUT、WNS/TNS |
| 15 | 结束页 | 从功能实现到工程实现 |

---

## 20. 老师可能问的问题与回答

### Q1：为什么这个项目叫“学”？

> 因为它涉及了很多我之前没有系统掌握的内容，包括 VGA 实时显示、PS/2 键盘输入、多游戏槽位架构、像素级渲染、资源报告分析和时序优化。它不是简单做游戏规则，而是让我学习了完整的 FPGA 图形交互系统开发流程。

### Q2：VGA 显示最核心的原理是什么？

> VGA 的核心是像素时序。FPGA 用计数器产生当前扫描坐标 `pixel_x/pixel_y`，在可见区输出 RGB，在同步区输出 HS/VS。菜单和游戏渲染器根据当前像素坐标实时计算颜色。

### Q3：为什么要用 `pixel_tick`，而不是新建一个 25 MHz 时钟？

> 项目保持单一 100 MHz 主时钟域，用 `pixel_tick` 作为 clock enable 推进 VGA 坐标。这样可以避免多时钟域问题，时序约束也更清晰。

### Q4：PS/2 输入为什么要先解析成 byte？

> PS/2 是串行协议，键盘发送的是扫描码，不是普通高低电平按键。`console_ps2_rx` 负责把物理线上的串行位解析成 byte 事件，上层菜单或游戏再解释这个 byte 是哪个键。

### Q5：Game Slot API 的意义是什么？

> 它让顶层和游戏解耦。顶层负责 VGA、PS/2、菜单和输出复用；游戏只负责自己的逻辑和渲染。以后新增游戏时，只要遵守接口，就能接入集合机。

### Q6：为什么 LUT 高、FF 低？

> 因为 VGA 游戏中大量对象判断、tile 查询、文字显示和图层优先级都在像素级组合逻辑中完成。FF 少说明寄存器用得不多，LUT 高说明组合逻辑压力大。因此优化方向是适当增加寄存器和 pipeline，而不是继续减少寄存器。

### Q7：你是怎么优化时序的？

> 我主要通过 RTL 拆分优化：Slot2 把 ghost 和 lock 流程拆成多拍；Slot3 用 `try_x/try_y` 切断玩家到地图再回到玩家的反馈路径；Slot4 把 tile 探测、结果评估和状态应用分阶段；VGA 路径只保留窄范围的 `pixel_tick` multicycle，不用宽泛约束掩盖游戏核心路径。

### Q8：最终时序结果说明什么？

> 最终 post-route WNS=+0.174ns，TNS=0，失败端点为 0，说明所有受约束路径都满足时序，bitstream 可以生成并上板运行。

---

## 21. 最后总结句

验收最后可以用下面这段话收尾：

> 通过这个 VGA 游戏集合机项目，我学到的不只是某一个游戏怎么写，而是 FPGA 图形交互系统应该怎样组织。  
> VGA 让我理解了实时像素扫描，PS/2 让我理解了外设协议解析，Game Slot API 让我理解了系统接口设计，资源和时序优化让我理解了从功能代码到可实现硬件之间的差距。  
> 所以这个项目对我最大的意义，是让我从“写出能工作的 Verilog”进一步走向“设计一个能显示、能输入、能扩展、能优化、能真正生成 bitstream 的 FPGA 产品”。

---

## 22. 代码路径速查表

| 讲解点 | 文件位置 | 汇报用途 |
| --- | --- | --- |
| 总顶层 | `src/game_console_top.v` | 公共服务、槽位选择、输出复用 |
| VGA 时序 | `src/common/console_vga_sync.v` | `pixel_tick`、坐标、HS/VS、frame_tick |
| PS/2 接收 | `src/common/console_ps2_rx.v` | 物理串行输入转 byte 事件 |
| 菜单控制 | `src/common/console_menu_controller.v` | W/S、方向键、Enter、Space、Esc |
| 菜单渲染 | `src/common/console_menu_renderer.v` | 菜单画面与光标高亮 |
| 槽位 API | `docs/game_api.md` | 统一端口规范 |
| Tank War 槽位 | `src/games/slot1/game_slot1_top.v` | 包装 `tank_top` 接入集合机 |
| Tank War 主体 | `src/games/tank/tank_top.v` | 坦克大战游戏逻辑 |
| Slot2 顶层 | `src/games/slot2/game_slot2_top.v` | 游戏状态、渲染、video staging |
| Slot2 核心 | `src/games/slot2/slot2_game_core.v` | ghost、lock、行扫描、状态机 |
| Slot3 玩家 | `src/games/slot3/slot3_player.v` | `try_x/try_y`、pending/wait 时序拆分 |
| Slot4 顶层 | `src/games/slot4/game_slot4_top.v` | tile map、碰撞、状态探测 |
| 资源分析 | `docs/资源占用分析.md` | LUT/FF 分布和优化方向 |
| 最终优化记录 | `docs/final_timing_optimization_round.md` | WNS/TNS、优化项、bitstream |
| 时序例外 | `scripts/apply_timing_exceptions.tcl` | 窄范围 VGA multicycle |
| XDC 约束 | `constraints/game_console.xdc` | 板级引脚绑定 |
