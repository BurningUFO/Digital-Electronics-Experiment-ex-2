## 快速上板脚本使用方法
##
## 完整编译：
##   vivado -mode batch -source scripts/build_bitstream.tcl
##
## 编译完成后 bitstream 在：
##   build/vivado/game_console_top.bit
##
## 上板下载：
##   vivado -mode batch -source scripts/program_board.tcl

set proj_dir "build/vivado"
set part "xc7a100tcsg324-1"
set top "game_console_top"
set bit_file "$proj_dir/${top}.bit"
set synth_dcp "$proj_dir/${top}_synth.dcp"
set impl_dcp "$proj_dir/${top}_impl.dcp"
set build_define ""

if {[info exists ::env(GAME_CONSOLE_BUILD)]} {
    switch -- [string tolower $::env(GAME_CONSOLE_BUILD)] {
        tank  { set build_define "BUILD_TANK_ONLY" }
        slot1 { set build_define "BUILD_SLOT1_ONLY" }
        slot2 { set build_define "BUILD_SLOT2_ONLY" }
        slot3 { set build_define "BUILD_SLOT3_ONLY" }
        slot4 { set build_define "BUILD_SLOT4_ONLY" }
        menu  { set build_define "BUILD_MENU_ONLY" }
        full  { set build_define "" }
        default {
            puts "WARNING: unknown GAME_CONSOLE_BUILD=$::env(GAME_CONSOLE_BUILD), using full build"
        }
    }
}

file mkdir $proj_dir

# 收集源文件
set verilog_files [glob -directory src {common/*.v} {games/**/*.v} game_console_top.v]

# 读取设计
if {$build_define ne ""} {
    puts "Using synthesis define: $build_define"
    read_verilog -define $build_define $verilog_files
} else {
    read_verilog $verilog_files
}
read_xdc constraints/game_console.xdc

# Synthesis
synth_design -top $top -part $part -flatten_hierarchy rebuilt
write_checkpoint -force $synth_dcp

# Timing exceptions that refer to synthesized cell names must be applied after
# the netlist exists. Source them before implementation and persist in the DCP.
if {[file exists scripts/apply_timing_exceptions.tcl]} {
    source scripts/apply_timing_exceptions.tcl
}

# Implementation
opt_design -directive Explore
place_design -directive Explore
phys_opt_design -directive Explore
route_design -directive Explore
phys_opt_design -directive AggressiveExplore
route_design -directive Explore
write_checkpoint -force $impl_dcp

# Bitstream
write_bitstream -force $bit_file

puts "========================================="
puts ">>> Bitstream 生成完成: $bit_file"
puts "========================================="
