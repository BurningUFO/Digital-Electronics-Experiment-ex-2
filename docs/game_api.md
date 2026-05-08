# Game Slot API

四个新游戏槽必须保持相同端口。总顶层已经实例化这些模块：

- `game_slot1_top`
- `game_slot2_top`
- `game_slot3_top`
- `game_slot4_top`

每个成员只改自己负责的 `src/games/slotN/` 目录。模块名和端口名必须保持不变，否则总顶层无法直接合并。

## 端口定义

```verilog
module game_slotN_top (
    input  wire        clk,             // 100 MHz
    input  wire        reset,           // active-high, selected=false 时也会被拉高
    input  wire        selected,        // 当前槽位是否由集合机菜单启动
    input  wire        frame_tick,      // VGA 每帧一个脉冲
    input  wire        pixel_tick,      // 25 MHz 像素使能
    input  wire        display_active,  // 当前像素在 640x480 可见区
    input  wire [9:0]  pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire        btn_u,
    input  wire        btn_d,
    input  wire        btn_l,
    input  wire        btn_r,
    input  wire        btn_c,
    input  wire [15:0] sw,
    input  wire        ps2_clk,
    input  wire        ps2_data,
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire [15:0] led,
    output wire [7:0]  an,
    output wire        ca,
    output wire        cb,
    output wire        cc,
    output wire        cd,
    output wire        ce,
    output wire        cf,
    output wire        cg,
    output wire        dp,
    output wire        buzzer
);
```

## 必须遵守

- `clk` 只用板载 `100 MHz`，不要在游戏模块里新建独立时钟，使用 clock enable。
- `reset` 是高有效；复位时游戏状态、输出和蜂鸣器必须回到安全状态。
- `display_active=0` 时 `vga_r/g/b` 应输出 `0`。
- `buzzer=1` 表示静音；如果使用低有效蜂鸣器，响铃时才短暂输出 `0`。
- 七段数码管为低有效，空闲建议 `an=8'hff`、`ca..dp=1`。
- 如果使用 PS/2，必须在 `selected=0` 或 `reset=1` 时停止改变游戏状态。
- 全局游戏选择由集合机菜单处理，成员游戏不要再用 `SW[2:0]` 做游戏选择。

## 推荐内部结构

```text
game_slotN_top
├─ slotN_tick_gen
├─ slotN_input
├─ slotN_game_core
├─ slotN_renderer
├─ slotN_sound
└─ slotN_debug
```

内部模块名加 `slotN_` 前缀，避免不同成员写出同名模块导致 Vivado 编译冲突。
