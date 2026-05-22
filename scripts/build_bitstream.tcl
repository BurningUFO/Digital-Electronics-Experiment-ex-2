## 快速上板脚本使用方法
##
## 首次编译（完整流程，较慢）：
##   vivado -mode batch -source scripts/build_bitstream.tcl
##
## 后续增量编译（只重编变化部分，快很多）：
##   vivado -mode batch -source scripts/build_bitstream.tcl
##   （脚本会自动检测并使用上次的 checkpoint）
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

file mkdir $proj_dir

# 收集源文件
set verilog_files [glob -directory src {common/*.v} {games/**/*.v} game_console_top.v]

# 读取设计
read_verilog $verilog_files
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
