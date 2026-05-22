set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ".."]]
set proj_file [file join $root_dir "build" "vivado" "game_console.xpr"]

if {![file exists $proj_file]} {
    source [file join $script_dir "create_vivado_project.tcl"]
    exit
}

open_project $proj_file

set source_patterns [list \
    [file join $root_dir "src" "*.v"] \
    [file join $root_dir "src" "common" "*.v"] \
    [file join $root_dir "src" "games" "tank" "*.v"] \
    [file join $root_dir "src" "games" "slot1" "*.v"] \
    [file join $root_dir "src" "games" "slot2" "*.v"] \
    [file join $root_dir "src" "games" "slot3" "*.v"] \
    [file join $root_dir "src" "games" "slot4" "*.v"] \
]

set existing_sources [list]
foreach f [get_files -quiet -of_objects [get_filesets sources_1]] {
    lappend existing_sources [file normalize $f]
}

set added_count 0
foreach pattern $source_patterns {
    foreach f [glob -nocomplain $pattern] {
        set nf [file normalize $f]
        if {[lsearch -exact $existing_sources $nf] < 0} {
            add_files -fileset sources_1 $nf
            lappend existing_sources $nf
            incr added_count
            puts "Added source: $nf"
        }
    }
}

set xdc_file [file normalize [file join $root_dir "constraints" "game_console.xdc"]]
set existing_constraints [list]
foreach f [get_files -quiet -of_objects [get_filesets constrs_1]] {
    lappend existing_constraints [file normalize $f]
}
if {[file exists $xdc_file] && [lsearch -exact $existing_constraints $xdc_file] < 0} {
    add_files -fileset constrs_1 $xdc_file
    puts "Added constraint: $xdc_file"
}

set_property top game_console_top [current_fileset]
update_compile_order -fileset sources_1

proc try_set_run_property {prop value run_name} {
    set run_obj [get_runs -quiet $run_name]
    if {[llength $run_obj] == 0} {
        puts "WARNING: run '$run_name' not found; skip $prop"
        return
    }
    if {[catch {set_property $prop $value $run_obj} msg]} {
        puts "WARNING: skip run property $run_name/$prop: $msg"
    } else {
        puts "Set run property: $run_name/$prop = $value"
    }
}

set exception_script [file normalize [file join $script_dir "apply_timing_exceptions.tcl"]]
if {[file exists $exception_script]} {
    try_set_run_property STEPS.SYNTH_DESIGN.TCL.POST $exception_script synth_1
    try_set_run_property STEPS.OPT_DESIGN.TCL.PRE $exception_script impl_1
}

try_set_run_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt synth_1
try_set_run_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE Explore impl_1
try_set_run_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore impl_1
try_set_run_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true impl_1
try_set_run_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE Explore impl_1
try_set_run_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore impl_1
try_set_run_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true impl_1
try_set_run_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore impl_1

puts "Source sync finished. Added $added_count source file(s)."

close_project
