# Verilator + SDL2 Simulation

这个仿真直接运行 `game_console_top`，用 SDL2 显示 640x480 VGA 输出，并把 PC 键盘事件转换成 PS/2 set-2 扫描码。

## 在 WSL2 中运行

从 Windows 当前仓库进入 WSL：

```bash
cd /mnt/c/Users/YOUNG/Desktop/workplace/2025_2026_2/SDSY/extended_experiment/nexys_game_console
make -f sim/verilator/Makefile run
```

如果编译很慢，建议把仓库放到 WSL 自己的 ext4 文件系统里再跑：

```bash
cp -a /mnt/c/Users/YOUNG/Desktop/workplace/2025_2026_2/SDSY/extended_experiment/nexys_game_console ~/nexys_game_console
cd ~/nexys_game_console
make -f sim/verilator/Makefile run
```

## 按需仿真（推荐日常开发使用）

只跑单个 slot，其余 stub 掉，大幅减少 eval 计算量：

```bash
make -f sim/verilator/Makefile run-tank    # 只跑坦克
make -f sim/verilator/Makefile run-slot1   # 只跑 slot1
make -f sim/verilator/Makefile run-slot2   # 只跑 slot2
make -f sim/verilator/Makefile run-slot3   # 只跑 slot3（Matrix）
make -f sim/verilator/Makefile run-slot4   # 只跑 slot4
make -f sim/verilator/Makefile run         # 全量集成验证
```

## 性能调优

默认使用 4 线程编译和运行，可以通过环境变量调整：

```bash
make -f sim/verilator/Makefile run THREADS=8
```

跳帧渲染（每 N+1 帧才采样一帧画面到 framebuffer，游戏逻辑仍每帧运行）：

```bash
build/verilator/obj_dir/Vgame_console_top --frame-skip 1
```

不限速运行（尽可能快，不等 SDL 展示节奏）：

```bash
build/verilator/obj_dir/Vgame_console_top --no-throttle
```

只做一次 Verilator lint：

```bash
make -f sim/verilator/Makefile lint
```

只跑 120 帧后自动退出：

```bash
make -f sim/verilator/Makefile frames
```

窗口缩放：

```bash
build/verilator/obj_dir/Vgame_console_top --scale 3
```

## 键盘映射

PS/2 键盘输入：

- `W/A/S/D`
- 方向键
- `Enter`
- `Space`
- `Esc`
- `J`
- `K`

模拟板载按键：

- `F1` -> `BTNU`
- `F2` -> `BTND`
- `F3` -> `BTNL`
- `F4` -> `BTNR`
- `F5` -> `BTNC`
- `F12` -> 按住时拉低 `CPU_RESETN`

模拟拨码开关：

- `F6` -> toggle `SW[0]`
- `F7` -> toggle `SW[1]`
- `F8` -> toggle `SW[2]`

## 适合检查什么

- 集合机菜单能否显示、上下选择、启动游戏、`Esc` 返回菜单。
- 各游戏的 VGA 画面和基本状态机是否正常。
- PS/2 键盘扫描码处理是否能响应。
- 合并后是否存在 Verilator 可发现的语法/宽度/锁存器等问题。

## 不能替代什么

- 不能替代 Vivado synthesis/implementation/timing。
- 不能验证真实板卡管脚、电气约束、时序收敛、BRAM/DSP 推断质量。
- 不能保证 PS/2 真实键盘的所有边界情况，只能快速发现大部分输入逻辑问题。
