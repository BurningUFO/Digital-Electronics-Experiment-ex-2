set slot3_rgb_regs [get_cells -hierarchical -filter {(REF_NAME =~ FD* || PRIMITIVE_TYPE =~ FLOP*) && (NAME =~ */u_game_slot3_top/vga_r_reg* || NAME =~ */u_game_slot3_top/vga_g_reg* || NAME =~ */u_game_slot3_top/vga_b_reg* || NAME =~ u_game_slot3_top/vga_r_reg* || NAME =~ u_game_slot3_top/vga_g_reg* || NAME =~ u_game_slot3_top/vga_b_reg*)}]
set vga_count_regs [get_cells -hierarchical -filter {NAME =~ */u_console_vga_sync/h_count_reg* || NAME =~ */u_console_vga_sync/v_count_reg* || NAME =~ u_console_vga_sync/h_count_reg* || NAME =~ u_console_vga_sync/v_count_reg*}]
set slot3_video_regs [get_cells -hierarchical -filter {(REF_NAME =~ FD* || PRIMITIVE_TYPE =~ FLOP*) && (NAME =~ */u_game_slot3_top/*_video_q_reg* || NAME =~ u_game_slot3_top/*_video_q_reg*)}]
set tank_vga_regs [get_cells -hierarchical -filter {(REF_NAME =~ FD* || PRIMITIVE_TYPE =~ FLOP*) && (NAME =~ */u_tank_top/VGA_R_reg* || NAME =~ */u_tank_top/VGA_G_reg* || NAME =~ */u_tank_top/VGA_B_reg* || NAME =~ */u_tank_top/VGA_HS_reg || NAME =~ */u_tank_top/VGA_VS_reg || NAME =~ u_tank_top/VGA_R_reg* || NAME =~ u_tank_top/VGA_G_reg* || NAME =~ u_tank_top/VGA_B_reg* || NAME =~ u_tank_top/VGA_HS_reg || NAME =~ u_tank_top/VGA_VS_reg)}]
set tank_vga_count_regs [get_cells -hierarchical -filter {NAME =~ */u_tank_top/u_vga_sync/h_count_reg* || NAME =~ */u_tank_top/u_vga_sync/v_count_reg* || NAME =~ u_tank_top/u_vga_sync/h_count_reg* || NAME =~ u_tank_top/u_vga_sync/v_count_reg*}]
set console_rgb_sample_regs [get_cells -hierarchical -filter {(REF_NAME =~ FD* || PRIMITIVE_TYPE =~ FLOP*) && (NAME =~ *menu_vga_*_q_reg* || NAME =~ *slot1_vga_*_q_reg* || NAME =~ *slot2_vga_*_q_reg* || NAME =~ *slot4_vga_*_q_reg*)}]
set slot4_state_regs [get_cells -hierarchical -filter {(REF_NAME =~ FD* || PRIMITIVE_TYPE =~ FLOP*) && NAME =~ *u_game_slot4_top/* && NAME !~ *u_game_slot4_top/u_slot4_ps2_rx/* && NAME !~ *u_game_slot4_top/u_slot4_keyboard_mapper/*}]
set slot4_key_regs [get_cells -hierarchical -filter {(REF_NAME =~ FD* || PRIMITIVE_TYPE =~ FLOP*) && (NAME =~ *u_game_slot4_top/u_slot4_keyboard_mapper/fire_left_reg* || NAME =~ *u_game_slot4_top/u_slot4_keyboard_mapper/fire_right_reg* || NAME =~ *u_game_slot4_top/u_slot4_keyboard_mapper/fire_jump_reg* || NAME =~ *u_game_slot4_top/u_slot4_keyboard_mapper/water_left_reg* || NAME =~ *u_game_slot4_top/u_slot4_keyboard_mapper/water_right_reg* || NAME =~ *u_game_slot4_top/u_slot4_keyboard_mapper/water_jump_reg*)}]

puts ">>> slot3 RGB multicycle endpoints: [llength $slot3_rgb_regs]"
puts ">>> VGA counter multicycle starts: [llength $vga_count_regs]"
puts ">>> slot3 video multicycle starts: [llength $slot3_video_regs]"
puts ">>> tank VGA multicycle endpoints: [llength $tank_vga_regs]"
puts ">>> tank VGA counter multicycle starts: [llength $tank_vga_count_regs]"
puts ">>> console RGB sample endpoints: [llength $console_rgb_sample_regs]"
puts ">>> slot4 state regs: [llength $slot4_state_regs]"
puts ">>> slot4 key regs: [llength $slot4_key_regs]"

if {[llength $slot3_rgb_regs] && [llength $vga_count_regs]} {
    set_multicycle_path 4 -setup -from $vga_count_regs -to $slot3_rgb_regs
    set_multicycle_path 3 -hold  -from $vga_count_regs -to $slot3_rgb_regs
} else {
    puts "WARNING: slot3 VGA multicycle exception skipped because object query was empty."
}

if {[llength $slot3_rgb_regs] && [llength $slot3_video_regs]} {
    set_multicycle_path 4 -setup -from $slot3_video_regs -to $slot3_rgb_regs
    set_multicycle_path 3 -hold  -from $slot3_video_regs -to $slot3_rgb_regs
} else {
    puts "WARNING: slot3 video multicycle exception skipped because object query was empty."
}

if {[llength $tank_vga_regs] && [llength $tank_vga_count_regs]} {
    set_multicycle_path 4 -setup -from $tank_vga_count_regs -to $tank_vga_regs
    set_multicycle_path 3 -hold  -from $tank_vga_count_regs -to $tank_vga_regs
} else {
    puts "WARNING: tank VGA multicycle exception skipped because object query was empty."
}

if {[llength $console_rgb_sample_regs]} {
    set_multicycle_path 4 -setup -to $console_rgb_sample_regs
    set_multicycle_path 3 -hold  -to $console_rgb_sample_regs
} else {
    puts "WARNING: console RGB sample multicycle exception skipped because object query was empty."
}

if {[llength $slot4_key_regs] && [llength $slot4_state_regs]} {
    set_multicycle_path 2 -setup -from $slot4_key_regs -to $slot4_state_regs
    set_multicycle_path 1 -hold  -from $slot4_key_regs -to $slot4_state_regs
} else {
    puts "WARNING: slot4 key multicycle exception skipped because object query was empty."
}

if {[llength $slot4_state_regs]} {
    set_multicycle_path 2 -setup -from $slot4_state_regs -to $slot4_state_regs
    set_multicycle_path 1 -hold  -from $slot4_state_regs -to $slot4_state_regs
} else {
    puts "WARNING: slot4 state multicycle exception skipped because object query was empty."
}
