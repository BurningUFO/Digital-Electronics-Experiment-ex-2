set proj_dir "build/vivado"
set top "game_console_top"
set impl_dcp "$proj_dir/${top}_impl.dcp"
set bit_file "$proj_dir/${top}.bit"

open_checkpoint $impl_dcp

if {[file exists scripts/apply_timing_exceptions.tcl]} {
    source scripts/apply_timing_exceptions.tcl
}

phys_opt_design -directive AggressiveExplore
route_design -directive Explore
phys_opt_design -directive AggressiveExplore
route_design -directive Explore

write_checkpoint -force $impl_dcp
write_bitstream -force $bit_file

