set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ".."]]
set proj_file [file join $root_dir "build" "vivado" "game_console.xpr"]

if {![file exists $proj_file]} {
    puts "ERROR: Vivado project not found: $proj_file"
    exit 1
}

open_project $proj_file
update_compile_order -fileset sources_1
reset_run synth_1
launch_runs synth_1 -jobs 11
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
puts "synth_1 status: $synth_status"

if {[string first "Complete" $synth_status] < 0} {
    puts "ERROR: synth_1 did not complete successfully."
    exit 1
}

close_project
