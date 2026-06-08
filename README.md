# Nexys A7 Game Console

目标板卡：`Nexys A7-100T`，器件 `XC7A100T-1CSG324C`。

这个目录是最终集合机项目的起点。当前方案把原来的空 `slot1` 替换为已经完成的坦克大战，因此集合机现在包含四个游戏槽：`slot1` 到 `slot4`。

## 当前选择方式

显示器会先显示集合机菜单。使用 PS/2 键盘选择游戏：

- `W/S` 或方向键上下移动
- `Enter/Space` 启动当前游戏
- `Esc` 从游戏返回集合机菜单

| 菜单项 | 游戏 |
| --- | --- |
| `TANK WAR` | `src/games/slot1/game_slot1_top.v`，内部包装 `src/games/tank/tank_top.v` |
| `GAME TWO` | `src/games/slot2/game_slot2_top.v` |
| `GAME THREE` | `src/games/slot3/game_slot3_top.v` |
| `GAME FOUR` | `src/games/slot4/game_slot4_top.v` |

四个菜单项分别对应 `slot1` 到 `slot4`。成员只需要保持各自 `game_slotN_top` 的模块名和端口不变即可合并。

## Vivado 建工程

推荐用脚本创建工程：

```tcl
cd nexys_game_console
vivado -mode batch -source scripts/create_vivado_project.tcl
```

也可以手动新建 Vivado 工程：

1. 选择 part：`xc7a100tcsg324-1`。
2. 添加 `src/` 下所有 `.v` 文件。
3. 添加 `constraints/game_console.xdc`。
4. 设置顶层模块为 `game_console_top`。
5. Generate Bitstream 后上板。

## 协作入口

先读：

- `docs/game_api.md`
- `docs/collaboration.md`

不要直接改 `game_console_top.v` 和 `constraints/game_console.xdc`，除非小组已经确认要新增外设或修改统一 API。
