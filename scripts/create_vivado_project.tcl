set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ".."]]
set build_dir [file join $root_dir "build" "vivado"]

create_project game_console $build_dir -part xc7a100tcsg324-1 -force

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

set source_patterns [list \
    [file join $root_dir "src" "*.v"] \
    [file join $root_dir "src" "common" "*.v"] \
    [file join $root_dir "src" "games" "tank" "*.v"] \
    [file join $root_dir "src" "games" "slot1" "*.v"] \
    [file join $root_dir "src" "games" "slot2" "*.v"] \
    [file join $root_dir "src" "games" "slot3" "*.v"] \
    [file join $root_dir "src" "games" "slot4" "*.v"] \
]

foreach pattern $source_patterns {
    set files [glob -nocomplain $pattern]
    if {[llength $files] > 0} {
        add_files -fileset sources_1 $files
    }
}

add_files -fileset constrs_1 [file join $root_dir "constraints" "game_console.xdc"]
set_property top game_console_top [current_fileset]
if {$build_define ne ""} {
    set_property verilog_define [list $build_define] [current_fileset]
    puts "Using synthesis define: $build_define"
}
update_compile_order -fileset sources_1
