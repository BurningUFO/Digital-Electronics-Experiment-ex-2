# Timing exceptions for VGA rendering paths.
#
# The console VGA generator runs on CLK100MHZ but advances pixel_x/pixel_y and
# samples per-slot RGB only when pixel_tick is asserted once every four clocks.
# The multicycle paths below are restricted to registers that either start from
# that pixel-tick coordinate/staging boundary or end at RGB registers sampled on
# the same pixel_tick enable. They intentionally do not cover game-core state.

proc require_or_warn {label objects} {
    set count [llength $objects]
    puts ">>> $label: $count"
    if {$count == 0} {
        puts "WARNING: timing exception object query '$label' matched no cells."
    }
    return $count
}

set vga_count_regs [get_cells -hierarchical -filter {
    (REF_NAME =~ FD* || PRIMITIVE_TYPE =~ FLOP*) &&
    (NAME =~ */u_console_vga_sync/h_count_reg* ||
     NAME =~ */u_console_vga_sync/v_count_reg* ||
     NAME =~ u_console_vga_sync/h_count_reg* ||
     NAME =~ u_console_vga_sync/v_count_reg*)
}]

set slot1_rgb_regs [get_cells -hierarchical -filter {
    (REF_NAME =~ FD* || PRIMITIVE_TYPE =~ FLOP*) &&
    (NAME =~ */u_tank_top/VGA_R_reg* ||
     NAME =~ */u_tank_top/VGA_G_reg* ||
     NAME =~ */u_tank_top/VGA_B_reg* ||
     NAME =~ u_tank_top/VGA_R_reg* ||
     NAME =~ u_tank_top/VGA_G_reg* ||
     NAME =~ u_tank_top/VGA_B_reg*)
}]

set slot2_rgb_regs [get_cells -hierarchical -filter {
    (REF_NAME =~ FD* || PRIMITIVE_TYPE =~ FLOP*) &&
    (NAME =~ */u_game_slot2_top/vga_r_reg* ||
     NAME =~ */u_game_slot2_top/vga_g_reg* ||
     NAME =~ */u_game_slot2_top/vga_b_reg* ||
     NAME =~ u_game_slot2_top/vga_r_reg* ||
     NAME =~ u_game_slot2_top/vga_g_reg* ||
     NAME =~ u_game_slot2_top/vga_b_reg*)
}]

set slot3_rgb_regs [get_cells -hierarchical -filter {
    (REF_NAME =~ FD* || PRIMITIVE_TYPE =~ FLOP*) &&
    (NAME =~ */u_game_slot3_top/vga_r_reg* ||
     NAME =~ */u_game_slot3_top/vga_g_reg* ||
     NAME =~ */u_game_slot3_top/vga_b_reg* ||
     NAME =~ u_game_slot3_top/vga_r_reg* ||
     NAME =~ u_game_slot3_top/vga_g_reg* ||
     NAME =~ u_game_slot3_top/vga_b_reg*)
}]

set slot4_rgb_regs [get_cells -hierarchical -filter {
    (REF_NAME =~ FD* || PRIMITIVE_TYPE =~ FLOP*) &&
    (NAME =~ */u_game_slot4_top/vga_r_reg* ||
     NAME =~ */u_game_slot4_top/vga_g_reg* ||
     NAME =~ */u_game_slot4_top/vga_b_reg* ||
     NAME =~ u_game_slot4_top/vga_r_reg* ||
     NAME =~ u_game_slot4_top/vga_g_reg* ||
     NAME =~ u_game_slot4_top/vga_b_reg*)
}]

set slot2_video_regs [get_cells -hierarchical -filter {
    (REF_NAME =~ FD* || PRIMITIVE_TYPE =~ FLOP*) &&
    (NAME =~ */u_game_slot2_top/*_video_q_reg* ||
     NAME =~ u_game_slot2_top/*_video_q_reg*)
}]

set slot3_video_regs [get_cells -hierarchical -filter {
    (REF_NAME =~ FD* || PRIMITIVE_TYPE =~ FLOP*) &&
    (NAME =~ */u_game_slot3_top/*_video_q_reg* ||
     NAME =~ u_game_slot3_top/*_video_q_reg*)
}]

set slot4_video_regs [get_cells -hierarchical -filter {
    (REF_NAME =~ FD* || PRIMITIVE_TYPE =~ FLOP*) &&
    (NAME =~ */u_game_slot4_top/*_video_q_reg* ||
     NAME =~ u_game_slot4_top/*_video_q_reg*)
}]

set console_rgb_sample_regs [get_cells -hierarchical -filter {
    (REF_NAME =~ FD* || PRIMITIVE_TYPE =~ FLOP*) &&
    (NAME =~ *menu_vga_*_q_reg* ||
     NAME =~ *slot1_vga_*_q_reg* ||
     NAME =~ *slot2_vga_*_q_reg* ||
     NAME =~ *slot3_vga_*_q_reg* ||
     NAME =~ *slot4_vga_*_q_reg*)
}]

require_or_warn "VGA counter multicycle starts" $vga_count_regs
require_or_warn "slot1 RGB multicycle endpoints" $slot1_rgb_regs
require_or_warn "slot2 RGB multicycle endpoints" $slot2_rgb_regs
require_or_warn "slot3 RGB multicycle endpoints" $slot3_rgb_regs
require_or_warn "slot4 RGB multicycle endpoints" $slot4_rgb_regs
require_or_warn "slot2 video multicycle starts" $slot2_video_regs
require_or_warn "slot3 video multicycle starts" $slot3_video_regs
require_or_warn "slot4 video multicycle starts" $slot4_video_regs
require_or_warn "console RGB sample endpoints" $console_rgb_sample_regs

proc apply_pixel_multicycle {label starts ends} {
    if {[llength $starts] && [llength $ends]} {
        puts ">>> Applying 4-cycle VGA pixel multicycle: $label"
        set_multicycle_path 4 -setup -from $starts -to $ends
        set_multicycle_path 3 -hold  -from $starts -to $ends
    } else {
        puts "WARNING: skipped VGA pixel multicycle '$label' because start or end query was empty."
    }
}

# VGA counters only advance on pixel_tick; these paths feed RGB registers that
# are also sampled on pixel_tick, so data has four CLK100MHZ cycles to settle.
apply_pixel_multicycle "console counters to slot1/tank RGB" $vga_count_regs $slot1_rgb_regs
apply_pixel_multicycle "console counters to slot2 RGB" $vga_count_regs $slot2_rgb_regs
apply_pixel_multicycle "console counters to slot3 RGB" $vga_count_regs $slot3_rgb_regs
apply_pixel_multicycle "console counters to slot4 RGB" $vga_count_regs $slot4_rgb_regs

# Slot video staging registers are updated only under pixel_tick and feed RGB
# registers sampled under the same pixel_tick enable.
apply_pixel_multicycle "slot2 video staging to RGB" $slot2_video_regs $slot2_rgb_regs
apply_pixel_multicycle "slot3 video staging to RGB" $slot3_video_regs $slot3_rgb_regs
apply_pixel_multicycle "slot4 video staging to RGB" $slot4_video_regs $slot4_rgb_regs

# The top-level menu/slot samples are pixel_tick RGB holding registers. Limit
# this exception to those explicit sample registers only.
if {[llength $console_rgb_sample_regs]} {
    puts ">>> Applying 4-cycle VGA pixel multicycle: top-level RGB sample endpoints"
    set_multicycle_path 4 -setup -to $console_rgb_sample_regs
    set_multicycle_path 3 -hold  -to $console_rgb_sample_regs
} else {
    puts "WARNING: skipped top-level RGB sample multicycle because endpoint query was empty."
}
