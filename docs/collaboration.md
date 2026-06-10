# Collaboration Plan

## 分工建议

| 槽位 | 负责人 | 文件夹 | 顶层模块 |
| --- | --- | --- | --- |
| `slot1` | 坦克大战 | `src/games/slot1/` | `game_slot1_top` |
| `slot2` | 成员 B | `src/games/slot2/` | `game_slot2_top` |
| `slot3` | 成员 C | `src/games/slot3/` | `game_slot3_top` |
| `slot4` | 成员 D | `src/games/slot4/` | `game_slot4_top` |

坦克大战实现放在 `src/games/tank/`，由 `src/games/slot1/game_slot1_top.v` 按统一槽位 API 包装接入菜单。维护坦克时优先改 `src/games/tank/`，不要把坦克内部模块名复制到其他槽位。

## 合并规则

- 每人只提交自己槽位目录下的 Verilog、文档和仿真文件。
- 不改 `src/game_console_top.v`，除非要新增统一端口或改游戏选择逻辑。
- 不改 `constraints/game_console.xdc`，除非新增外设引脚；新增前必须先统一顶层端口名。
- 每个成员的内部模块名必须带槽位前缀，例如 `slot2_snake_core`，不要叫通用名 `game_core`。
- 每个槽位必须能在 `reset=1` 时静音、熄灭本槽输出并回到初始状态。
- 提交前至少保证 Vivado elaboration 不报模块缺失。
- 不要用 `SW[2:0]` 作为全局选游戏；游戏选择已经由 VGA 菜单和 PS/2 键盘完成。

## 推荐开发流程

1. 先在自己的 `game_slotN_top` 内画静态 VGA 画面。
2. 再接入按键、开关或 PS/2 输入。
3. 然后实现游戏核心状态机。
4. 最后加七段管、LED、蜂鸣器。
5. 合并前在集合机菜单里选择自己的槽位并单独测试。

## 外设共享原则

当前顶层共享这些板上资源：

- VGA：总顶层统一输出，`slot1..slot4` 只输出当前像素 RGB。
- `SW[15:0]`：不再用于全局选游戏，可由各游戏内部自行约定用途。
- `CPU_RESETN`：全局复位。
- LED、七段管、蜂鸣器：只输出当前被选择游戏的信号。
- PS/2：总顶层统一实例化 `console_ps2_rx`，并把 `ps2_byte_ready/ps2_byte_data` 分发给各槽位；`ps2_clk/ps2_data` 仅为槽位 API 兼容保留端口。

## 已完成的结构统一

坦克大战已经从旧式独立顶层改为复用集合机公共服务：`tank_top` 不再实例化内部 `vga_sync` 或 `ps2_rx`，而是消费总顶层分发的 `pixel_x/pixel_y/display_active/pixel_tick` 和 `ps2_byte_ready/ps2_byte_data`。slot1 退出时由总顶层对该槽位拉高 reset，LED、七段管、蜂鸣器也按 `selected` 做输出隔离。

当前剩余的工程债主要是 `tank_top.v` 文件仍然较大，后续如需继续产品化，可以再按输入、状态、地图、渲染、音效拆成多个 `tank_` 前缀子模块。
