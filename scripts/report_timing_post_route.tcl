set impl_dcp "build/vivado/game_console_top_impl.dcp"
set report_dir "build/vivado/reports"

file mkdir $report_dir
open_checkpoint $impl_dcp

if {[file exists scripts/apply_timing_exceptions.tcl]} {
    source scripts/apply_timing_exceptions.tcl
}

set exception_count_file [file join $report_dir "timing_exception_object_counts.txt"]
set exception_count_fh [open $exception_count_file "w"]
foreach object_group {
    vga_count_regs
    slot1_rgb_regs
    slot2_rgb_regs
    slot3_rgb_regs
    slot4_rgb_regs
    slot2_video_regs
    slot3_video_regs
    slot4_video_regs
    console_rgb_sample_regs
} {
    if {[info exists $object_group]} {
        puts $exception_count_fh "$object_group [llength [set $object_group]]"
    } else {
        puts $exception_count_fh "$object_group NOT_DEFINED"
    }
}
close $exception_count_fh

report_timing_summary \
    -delay_type max \
    -report_unconstrained \
    -check_timing_verbose \
    -max_paths 50 \
    -file [file join $report_dir "timing_summary_post_route.rpt"]

report_timing \
    -delay_type max \
    -sort_by slack \
    -max_paths 50 \
    -nworst 1 \
    -input_pins \
    -file [file join $report_dir "timing_worst_50.rpt"]

if {[catch {report_exceptions -file [file join $report_dir "timing_exceptions.rpt"]} exception_msg]} {
    set exception_error_fh [open [file join $report_dir "timing_exceptions.rpt"] "w"]
    puts $exception_error_fh "report_exceptions failed: $exception_msg"
    close $exception_error_fh
    puts "WARNING: report_exceptions failed: $exception_msg"
}

report_utilization \
    -hierarchical \
    -file [file join $report_dir "utilization_hierarchical.rpt"]

report_utilization \
    -hierarchical \
    -file [file join $report_dir "utilization_hierarchical_post_route.rpt"]

report_design_analysis \
    -timing \
    -logic_level_distribution \
    -congestion \
    -file [file join $report_dir "design_analysis_post_route.rpt"]
