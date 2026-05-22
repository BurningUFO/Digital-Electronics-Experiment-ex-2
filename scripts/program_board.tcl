## 一键下载 bitstream 到板子
## 用法：vivado -mode batch -source scripts/program_board.tcl

set bit_file "build/vivado/game_console_top.bit"

if {![file exists $bit_file]} {
    puts "ERROR: $bit_file 不存在，先运行 build_bitstream.tcl"
    exit 1
}

open_hw_manager
connect_hw_server
open_hw_target

set device [lindex [get_hw_devices] 0]
current_hw_device $device
set_property PROGRAM.FILE $bit_file $device
program_hw_devices $device

puts ">>> 下载完成"
close_hw_target
close_hw_manager
