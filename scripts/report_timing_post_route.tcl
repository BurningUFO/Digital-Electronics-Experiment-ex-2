set impl_dcp "build/vivado/game_console_top_impl.dcp"
set report_dir "build/vivado/reports"

file mkdir $report_dir
open_checkpoint $impl_dcp

if {[file exists scripts/apply_timing_exceptions.tcl]} {
    source scripts/apply_timing_exceptions.tcl
}

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

report_utilization \
    -hierarchical \
    -file [file join $report_dir "utilization_hierarchical.rpt"]

report_design_analysis \
    -timing \
    -logic_level_distribution \
    -congestion \
    -file [file join $report_dir "design_analysis_post_route.rpt"]
