// Slot 1 adapter for Tank War.
//
// The original tank game has its own top-level-style port names, so this wrapper
// translates the common Game Slot API into tank_top.  All physical VGA and PS/2
// services still come from game_console_top; this file should remain thin.
module game_slot1_top (
    input  wire        clk,
    input  wire        reset,
    input  wire        selected,
    input  wire        frame_tick,
    input  wire        pixel_tick,
    input  wire        display_active,
    input  wire [9:0]  pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire        btn_u,
    input  wire        btn_d,
    input  wire        btn_l,
    input  wire        btn_r,
    input  wire        btn_c,
    input  wire [15:0] sw,
    input  wire        ps2_clk,
    input  wire        ps2_data,
    input  wire        ps2_byte_ready,
    input  wire [7:0]  ps2_byte_data,
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire [15:0] led,
    output wire [7:0]  an,
    output wire        ca,
    output wire        cb,
    output wire        cc,
    output wire        cd,
    output wire        ce,
    output wire        cf,
    output wire        cg,
    output wire        dp,
    output wire        buzzer
);

    // Keep unused common slot inputs connected so synthesis does not warn about
    // intentionally ignored API fields.  Tank uses PS/2 byte events rather than
    // board buttons or raw PS/2 lines.
    wire _unused_slot1_api = &{
        1'b0,
        frame_tick,
        btn_u,
        btn_d,
        btn_l,
        btn_r,
        btn_c,
        sw,
        ps2_clk,
        ps2_data
    };

    // Tank receives reset when the console is reset or when this slot is not
    // launched.  That prevents hidden gameplay/audio state from leaking across
    // menu switches.
    tank_top u_tank_top (
        .CLK100MHZ(clk),
        .reset(reset | ~selected),
        .selected(selected),
        .pixel_tick(pixel_tick),
        .display_active(display_active),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .ps2_byte_ready(ps2_byte_ready),
        .ps2_byte_data(ps2_byte_data),
        .BUZZER(buzzer),
        .LED(led),
        .AN(an),
        .CA(ca),
        .CB(cb),
        .CC(cc),
        .CD(cd),
        .CE(ce),
        .CF(cf),
        .CG(cg),
        .DP(dp),
        .VGA_R(vga_r),
        .VGA_G(vga_g),
        .VGA_B(vga_b)
    );

endmodule
