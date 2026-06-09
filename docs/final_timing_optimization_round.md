# Final Timing Optimization Round

Date: 2026-06-09
Branch: `timing-final-optimization`
Target: Nexys A7-100T / Vivado 2025.2

## Goal

Improve implementation timing without changing game rules, maps, rendering content,
controls, scoring, audio, menu behavior, or slot switching. The focus was to expose
real timing issues, avoid broad exceptions, and reduce true 100 MHz combinational
paths.

## Files Changed

- `src/games/slot2/slot2_game_core.v`
- `src/games/slot2/game_slot2_top.v`
- `src/games/slot3/slot3_player.v`
- `src/games/slot4/game_slot4_top.v`
- `scripts/apply_timing_exceptions.tcl`
- `scripts/report_timing_post_route.tcl`
- `constraints/game_console.xdc` was audited; PS/2 pullups are present.
- Vivado-generated local report helper files were refreshed: `clockInfo.txt`,
  `tight_setup_hold_pins.txt`.

## RTL Changes

### Slot2

- Split the slot2 collision helper into row-level checks so repeated board-row
  access is more localized.
- Replaced direct ghost-position combinational update with an iterative
  `ghost_probe_y` flow. The ghost result is advanced over 100 MHz cycles and
  remains frame-visible equivalent.
- Added row-by-row piece lock flow (`ST_LOCK_ROW`) instead of folding all lock
  row writes into one large state update.
- Added `pixel_tick` video staging registers in `game_slot2_top.v` so renderer
  inputs are held at the VGA pixel boundary before RGB registration.

### Slot3

- Registered `try_x` and `try_y` in `slot3_player.v`.
- Added a small movement pending/wait sequence so player candidate position is
  presented to the map walkability logic, then committed on the following
  100 MHz cycle. This splits the player-to-map-to-player feedback path while
  preserving frame-level movement behavior.

### Slot4

- Replaced the direct `slot4_player_solid_x/y()` to `phys_blocked_q` path with
  staged probe address registers and explicit TEST/EVAL/APPLY physics states.
- Added staged status probes for grounded, failed, and complete checks. Player
  corner and foot tile addresses are registered first, tile results are evaluated
  into `_eval_q` registers, and game-state flags are applied before physics
  advances.
- Kept input sampling on `frame_tick`; the extra status/physics staging is only
  a few 100 MHz cycles and remains well inside one video frame.
- Added slot4 video staging registers under `pixel_tick` and kept rendered RGB
  registration unchanged.

## Timing Exceptions Audit

- Removed broad slot4 state/key multicycle exceptions that covered true game
  state paths.
- Kept only narrow 4-cycle/3-cycle setup/hold multicycle exceptions for VGA
  paths whose start or end registers are explicitly held by `pixel_tick`.
- `scripts/build_bitstream.tcl` sources `scripts/apply_timing_exceptions.tcl`
  after synthesis, so synthesized cell-name exceptions are applied before
  implementation.
- `scripts/report_timing_post_route.tcl` re-sources the same exception file,
  writes `timing_exception_object_counts.txt`, and uses Vivado 2025.2-compatible
  `report_exceptions`.
- Final object counts were nonzero:
  - `vga_count_regs 88`
  - `slot1_rgb_regs 12`
  - `slot2_rgb_regs 12`
  - `slot3_rgb_regs 12`
  - `slot4_rgb_regs 12`
  - `slot2_video_regs 257`
  - `slot3_video_regs 853`
  - `slot4_video_regs 52`
  - `console_rgb_sample_regs 12`

## Vivado Runs

Commands used:

```tcl
vivado -mode batch -source scripts/sync_vivado_project_sources.tcl
vivado -mode batch -source scripts/build_bitstream.tcl
vivado -mode batch -source scripts/report_timing_post_route.tcl
```

Final generated artifacts:

- Bitstream: `build/vivado/game_console_top.bit`
- Implementation checkpoint: `build/vivado/game_console_top_impl.dcp`
- Timing summary: `build/vivado/reports/timing_summary_post_route.rpt`
- Worst paths: `build/vivado/reports/timing_worst_50.rpt`
- Exceptions report: `build/vivado/reports/timing_exceptions.rpt`
- Exception object counts:
  `build/vivado/reports/timing_exception_object_counts.txt`
- Design analysis:
  `build/vivado/reports/design_analysis_post_route.rpt`
- Hierarchical utilization:
  `build/vivado/reports/utilization_hierarchical_post_route.rpt`

## Timing Results

Two baselines are useful:

- Legacy exception baseline after initial bitstream build:
  `WNS 0.005 ns`, `TNS 0.000 ns`, `WHS 0.066 ns`.
- Audited true baseline after removing broad slot4 multicycle coverage:
  `WNS -0.445 ns`, `TNS -18.104 ns`, 94 failing endpoints.

Final post-route report:

- `WNS 0.174 ns`
- `TNS 0.000 ns`
- `TNS failing endpoints 0`
- `WHS 0.037 ns` in the final build log
- `THS 0.000 ns`
- Unconstrained internal endpoints: `0`

Final worst setup path:

- Source: `u_game_slot1_top/u_tank_top/p2_move_check_y_reg[4]/C`
- Destination: `u_game_slot1_top/u_tank_top/p2_y_reg[2]/CE`
- Slack: `0.174 ns`
- Data path delay: `9.486 ns`
- Logic levels: `12`

Slot4 no longer appears as the worst failing area. Slot2 ghost/control paths are
still close to the top of the met list, but they now have positive slack.

## Behavior Impact

No user-visible game behavior is intended to change.

- No game maps, tile constants, piece shapes, scan codes, scoring constants,
  audio behavior, menu behavior, slot switching, or top-level ports were changed.
- New FSM/pipeline steps are contained inside 100 MHz frame work and complete
  long before a visible frame boundary.
- VGA exceptions are limited to pixel-enable video paths and do not cover core
  game state.

## Remaining Risks

- Timing margin is positive but still modest. Future feature additions in slot1
  tank movement or slot2 ghost/control logic can consume the remaining slack.
- There is no full behavioral simulation suite for all games, so verification is
  synthesis/implementation focused plus static RTL review.
- Some generated Vivado helper files changed during the build (`clockInfo.txt`,
  `tight_setup_hold_pins.txt`).

## Recommended Follow-Up

- Add focused smoke testbenches for slot2 ghost/drop/lock sequencing and slot4
  physics/status sequencing.
- If more margin is required, the next likely targets are slot1 tank movement
  collision CE paths and slot2 ghost/control CE paths.
- Keep future timing exceptions pixel-path only unless the RTL contains an
  explicit valid/enable protocol proving a true multicycle path.
