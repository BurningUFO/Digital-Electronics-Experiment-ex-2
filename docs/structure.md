# Project Structure

```text
nexys_game_console/
├─ src/
│  ├─ game_console_top.v          # 总顶层，负责键盘菜单和输出复用
│  ├─ common/
│  │  ├─ console_vga_sync.v       # 统一 640x480 VGA 时序
│  │  ├─ console_ps2_rx.v         # 集合机共享 PS/2 byte 接收
│  │  ├─ console_menu_controller.v # 菜单状态机
│  │  ├─ console_menu_renderer.v  # VGA 菜单渲染
│  │  └─ blank_game_slot.v        # 空槽位占位画面
│  └─ games/
│     ├─ tank/
│     │  └─ tank_top.v            # 坦克大战主体，复用集合机 VGA/PS2 公共接口
│     ├─ slot1/
│     │  └─ game_slot1_top.v      # 坦克大战槽位适配
│     ├─ slot2/
│     │  └─ game_slot2_top.v
│     ├─ slot3/
│     │  └─ game_slot3_top.v
│     └─ slot4/
│        └─ game_slot4_top.v
├─ constraints/
│  └─ game_console.xdc
├─ docs/
├─ sim/
└─ scripts/
   └─ create_vivado_project.tcl
```

设计原则：总顶层稳定，四个游戏槽位可替换。每个游戏只要保持自己的顶层模块名和端口，就能直接被 `game_console_top` 复用。
