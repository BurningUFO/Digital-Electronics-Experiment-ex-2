set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ".."]]
set build_dir [file join $root_dir "build" "vivado"]

create_project game_console $build_dir -part xc7a100tcsg324-1 -force

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
update_compile_order -fileset sources_1
