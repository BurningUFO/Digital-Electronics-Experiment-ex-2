module game_console_top (
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire        PS2_CLK,
    input  wire        PS2_DATA,
    input  wire [15:0] SW,
    input  wire        BTNU,
    input  wire        BTND,
    input  wire        BTNL,
    input  wire        BTNR,
    input  wire        BTNC,
    output wire        BUZZER,
    output wire [15:0] LED,
    output wire [7:0]  AN,
    output wire        CA,
    output wire        CB,
    output wire        CC,
    output wire        CD,
    output wire        CE,
    output wire        CF,
    output wire        CG,
    output wire        DP,
    output reg  [3:0]  VGA_R,
    output reg  [3:0]  VGA_G,
    output reg  [3:0]  VGA_B,
    output reg         VGA_HS,
    output reg         VGA_VS
);

    wire reset;
    wire [2:0] game_sel;
    wire [2:0] menu_cursor;
    wire menu_active;
    wire menu_launch_pulse;
    wire slot1_selected;
    wire slot2_selected;
    wire slot3_selected;
    wire slot4_selected;

    wire console_pixel_tick;
    wire console_display_active;
    wire [9:0] console_pixel_x;
    wire [9:0] console_pixel_y;
    wire console_hs;
    wire console_vs;
    wire console_frame_tick;
    wire console_ps2_byte_ready;
    wire [7:0] console_ps2_byte_data;
    wire [3:0] menu_vga_r;
    wire [3:0] menu_vga_g;
    wire [3:0] menu_vga_b;
    reg  [3:0] menu_vga_r_q;
    reg  [3:0] menu_vga_g_q;
    reg  [3:0] menu_vga_b_q;

    wire [3:0] slot1_vga_r;
    wire [3:0] slot1_vga_g;
    wire [3:0] slot1_vga_b;
    wire [15:0] slot1_led;
    wire [7:0] slot1_an;
    wire [7:0] slot1_seg;
    wire slot1_buzzer;

    wire [3:0] slot2_vga_r;
    wire [3:0] slot2_vga_g;
    wire [3:0] slot2_vga_b;
    reg  [3:0] slot2_vga_r_q;
    reg  [3:0] slot2_vga_g_q;
    reg  [3:0] slot2_vga_b_q;
    wire [15:0] slot2_led;
    wire [7:0] slot2_an;
    wire [7:0] slot2_seg;
    wire slot2_buzzer;

    wire [3:0] slot3_vga_r;
    wire [3:0] slot3_vga_g;
    wire [3:0] slot3_vga_b;
    wire [15:0] slot3_led;
    wire [7:0] slot3_an;
    wire [7:0] slot3_seg;
    wire slot3_buzzer;

    wire [3:0] slot4_vga_r;
    wire [3:0] slot4_vga_g;
    wire [3:0] slot4_vga_b;
    reg  [3:0] slot4_vga_r_q;
    reg  [3:0] slot4_vga_g_q;
    reg  [3:0] slot4_vga_b_q;
    wire [15:0] slot4_led;
    wire [7:0] slot4_an;
    wire [7:0] slot4_seg;
    wire slot4_buzzer;

    wire [3:0] active_slot_vga_r;
    wire [3:0] active_slot_vga_g;
    wire [3:0] active_slot_vga_b;
    wire [15:0] active_slot_led;
    wire [7:0] active_slot_an;
    wire [7:0] active_slot_seg;
    wire active_slot_buzzer;
    wire [7:0] active_seg;

    assign reset = ~CPU_RESETN;

    assign slot1_selected = !menu_active && (game_sel == 3'd0);
    assign slot2_selected = !menu_active && (game_sel == 3'd1);
    assign slot3_selected = !menu_active && (game_sel == 3'd2);
    assign slot4_selected = !menu_active && (game_sel == 3'd3);

    // Some renderers are combinational and can glitch while pixel_x/pixel_y settle.
    // Sample their RGB once per visible pixel, matching slot3's registered output style.
    always @(posedge CLK100MHZ) begin
        if (reset) begin
            menu_vga_r_q <= 4'h0;
            menu_vga_g_q <= 4'h0;
            menu_vga_b_q <= 4'h0;
            slot2_vga_r_q <= 4'h0;
            slot2_vga_g_q <= 4'h0;
            slot2_vga_b_q <= 4'h0;
            slot4_vga_r_q <= 4'h0;
            slot4_vga_g_q <= 4'h0;
            slot4_vga_b_q <= 4'h0;
        end else if (console_pixel_tick) begin
            menu_vga_r_q <= menu_vga_r;
            menu_vga_g_q <= menu_vga_g;
            menu_vga_b_q <= menu_vga_b;
            slot2_vga_r_q <= slot2_vga_r;
            slot2_vga_g_q <= slot2_vga_g;
            slot2_vga_b_q <= slot2_vga_b;
            slot4_vga_r_q <= slot4_vga_r;
            slot4_vga_g_q <= slot4_vga_g;
            slot4_vga_b_q <= slot4_vga_b;
        end
    end

    console_vga_sync u_console_vga_sync (
        .clk(CLK100MHZ),
        .reset(reset),
        .pixel_tick(console_pixel_tick),
        .display_active(console_display_active),
        .pixel_x(console_pixel_x),
        .pixel_y(console_pixel_y),
        .hsync(console_hs),
        .vsync(console_vs),
        .frame_tick(console_frame_tick)
    );

    console_ps2_rx u_console_ps2_rx (
        .clk(CLK100MHZ),
        .reset(reset),
        .ps2_clk(PS2_CLK),
        .ps2_data(PS2_DATA),
        .byte_ready(console_ps2_byte_ready),
        .byte_data(console_ps2_byte_data)
    );

    console_menu_controller u_console_menu_controller (
        .clk(CLK100MHZ),
        .reset(reset),
        .byte_ready(console_ps2_byte_ready),
        .byte_data(console_ps2_byte_data),
        .menu_active(menu_active),
        .game_sel(game_sel),
        .cursor(menu_cursor),
        .launch_pulse(menu_launch_pulse)
    );

    console_menu_renderer u_console_menu_renderer (
        .clk(CLK100MHZ),
        .reset(reset),
        .frame_tick(console_frame_tick),
        .display_active(console_display_active),
        .pixel_x(console_pixel_x),
        .pixel_y(console_pixel_y),
        .cursor(menu_cursor),
        .vga_r(menu_vga_r),
        .vga_g(menu_vga_g),
        .vga_b(menu_vga_b)
    );

`ifdef BUILD_TANK_ONLY
    `define STUB_SLOT2
    `define STUB_SLOT3
    `define STUB_SLOT4
`elsif BUILD_SLOT1_ONLY
    `define STUB_SLOT2
    `define STUB_SLOT3
    `define STUB_SLOT4
`elsif BUILD_SLOT2_ONLY
    `define STUB_SLOT1
    `define STUB_SLOT3
    `define STUB_SLOT4
`elsif BUILD_SLOT3_ONLY
    `define STUB_SLOT1
    `define STUB_SLOT2
    `define STUB_SLOT4
`elsif BUILD_SLOT4_ONLY
    `define STUB_SLOT1
    `define STUB_SLOT2
    `define STUB_SLOT3
`elsif BUILD_MENU_ONLY
    `define STUB_SLOT1
    `define STUB_SLOT2
    `define STUB_SLOT3
    `define STUB_SLOT4
`endif

`ifdef SIM_TANK_ONLY
    `define STUB_SLOT2
    `define STUB_SLOT3
    `define STUB_SLOT4
`elsif SIM_SLOT1_ONLY
    `define STUB_SLOT2
    `define STUB_SLOT3
    `define STUB_SLOT4
`elsif SIM_SLOT2_ONLY
    `define STUB_SLOT1
    `define STUB_SLOT3
    `define STUB_SLOT4
`elsif SIM_SLOT3_ONLY
    `define STUB_SLOT1
    `define STUB_SLOT2
    `define STUB_SLOT4
`elsif SIM_SLOT4_ONLY
    `define STUB_SLOT1
    `define STUB_SLOT2
    `define STUB_SLOT3
`endif

`ifdef STUB_SLOT1
    assign slot1_vga_r = 4'h0;
    assign slot1_vga_g = 4'h0;
    assign slot1_vga_b = 4'h0;
    assign slot1_led = 16'h0000;
    assign slot1_an = 8'hff;
    assign slot1_seg = 8'hff;
    assign slot1_buzzer = 1'b1;
`else
    game_slot1_top u_game_slot1_top (
        .clk(CLK100MHZ),
        .reset(reset | ~slot1_selected),
        .selected(slot1_selected),
        .frame_tick(console_frame_tick),
        .pixel_tick(console_pixel_tick),
        .display_active(console_display_active),
        .pixel_x(console_pixel_x),
        .pixel_y(console_pixel_y),
        .btn_u(BTNU),
        .btn_d(BTND),
        .btn_l(BTNL),
        .btn_r(BTNR),
        .btn_c(BTNC),
        .sw(SW),
        .ps2_clk(PS2_CLK),
        .ps2_data(PS2_DATA),
        .vga_r(slot1_vga_r),
        .vga_g(slot1_vga_g),
        .vga_b(slot1_vga_b),
        .led(slot1_led),
        .an(slot1_an),
        .ca(slot1_seg[7]),
        .cb(slot1_seg[6]),
        .cc(slot1_seg[5]),
        .cd(slot1_seg[4]),
        .ce(slot1_seg[3]),
        .cf(slot1_seg[2]),
        .cg(slot1_seg[1]),
        .dp(slot1_seg[0]),
        .buzzer(slot1_buzzer)
    );
`endif

`ifdef STUB_SLOT2
    assign slot2_vga_r = 4'h0;
    assign slot2_vga_g = 4'h0;
    assign slot2_vga_b = 4'h0;
    assign slot2_led = 16'h0000;
    assign slot2_an = 8'hff;
    assign slot2_seg = 8'hff;
    assign slot2_buzzer = 1'b1;
`else
    game_slot2_top u_game_slot2_top (
        .clk(CLK100MHZ),
        .reset(reset | ~slot2_selected),
        .selected(slot2_selected),
        .frame_tick(console_frame_tick),
        .pixel_tick(console_pixel_tick),
        .display_active(console_display_active),
        .pixel_x(console_pixel_x),
        .pixel_y(console_pixel_y),
        .btn_u(BTNU),
        .btn_d(BTND),
        .btn_l(BTNL),
        .btn_r(BTNR),
        .btn_c(BTNC),
        .sw(SW),
        .ps2_clk(PS2_CLK),
        .ps2_data(PS2_DATA),
        .vga_r(slot2_vga_r),
        .vga_g(slot2_vga_g),
        .vga_b(slot2_vga_b),
        .led(slot2_led),
        .an(slot2_an),
        .ca(slot2_seg[7]),
        .cb(slot2_seg[6]),
        .cc(slot2_seg[5]),
        .cd(slot2_seg[4]),
        .ce(slot2_seg[3]),
        .cf(slot2_seg[2]),
        .cg(slot2_seg[1]),
        .dp(slot2_seg[0]),
        .buzzer(slot2_buzzer)
    );
`endif

`ifdef STUB_SLOT3
    assign slot3_vga_r = 4'h0;
    assign slot3_vga_g = 4'h0;
    assign slot3_vga_b = 4'h0;
    assign slot3_led = 16'h0000;
    assign slot3_an = 8'hff;
    assign slot3_seg = 8'hff;
    assign slot3_buzzer = 1'b1;
`else
    game_slot3_top u_game_slot3_top (
        .clk(CLK100MHZ),
        .reset(reset | ~slot3_selected),
        .selected(slot3_selected),
        .frame_tick(console_frame_tick),
        .pixel_tick(console_pixel_tick),
        .display_active(console_display_active),
        .pixel_x(console_pixel_x),
        .pixel_y(console_pixel_y),
        .btn_u(BTNU),
        .btn_d(BTND),
        .btn_l(BTNL),
        .btn_r(BTNR),
        .btn_c(BTNC),
        .sw(SW),
        .ps2_clk(PS2_CLK),
        .ps2_data(PS2_DATA),
        .vga_r(slot3_vga_r),
        .vga_g(slot3_vga_g),
        .vga_b(slot3_vga_b),
        .led(slot3_led),
        .an(slot3_an),
        .ca(slot3_seg[7]),
        .cb(slot3_seg[6]),
        .cc(slot3_seg[5]),
        .cd(slot3_seg[4]),
        .ce(slot3_seg[3]),
        .cf(slot3_seg[2]),
        .cg(slot3_seg[1]),
        .dp(slot3_seg[0]),
        .buzzer(slot3_buzzer)
    );
`endif

`ifdef STUB_SLOT4
    assign slot4_vga_r = 4'h0;
    assign slot4_vga_g = 4'h0;
    assign slot4_vga_b = 4'h0;
    assign slot4_led = 16'h0000;
    assign slot4_an = 8'hff;
    assign slot4_seg = 8'hff;
    assign slot4_buzzer = 1'b1;
`else
    game_slot4_top u_game_slot4_top (
        .clk(CLK100MHZ),
        .reset(reset | ~slot4_selected),
        .selected(slot4_selected),
        .frame_tick(console_frame_tick),
        .pixel_tick(console_pixel_tick),
        .display_active(console_display_active),
        .pixel_x(console_pixel_x),
        .pixel_y(console_pixel_y),
        .btn_u(BTNU),
        .btn_d(BTND),
        .btn_l(BTNL),
        .btn_r(BTNR),
        .btn_c(BTNC),
        .sw(SW),
        .ps2_clk(PS2_CLK),
        .ps2_data(PS2_DATA),
        .vga_r(slot4_vga_r),
        .vga_g(slot4_vga_g),
        .vga_b(slot4_vga_b),
        .led(slot4_led),
        .an(slot4_an),
        .ca(slot4_seg[7]),
        .cb(slot4_seg[6]),
        .cc(slot4_seg[5]),
        .cd(slot4_seg[4]),
        .ce(slot4_seg[3]),
        .cf(slot4_seg[2]),
        .cg(slot4_seg[1]),
        .dp(slot4_seg[0]),
        .buzzer(slot4_buzzer)
    );
`endif

    assign active_slot_vga_r = slot1_selected ? slot1_vga_r :
                               slot2_selected ? slot2_vga_r_q :
                               slot3_selected ? slot3_vga_r :
                                                slot4_vga_r_q;
    assign active_slot_vga_g = slot1_selected ? slot1_vga_g :
                               slot2_selected ? slot2_vga_g_q :
                               slot3_selected ? slot3_vga_g :
                                                slot4_vga_g_q;
    assign active_slot_vga_b = slot1_selected ? slot1_vga_b :
                               slot2_selected ? slot2_vga_b_q :
                               slot3_selected ? slot3_vga_b :
                                                slot4_vga_b_q;

    assign active_slot_led = slot1_selected ? slot1_led :
                             slot2_selected ? slot2_led :
                             slot3_selected ? slot3_led :
                                              slot4_led;
    assign active_slot_an = slot1_selected ? slot1_an :
                            slot2_selected ? slot2_an :
                            slot3_selected ? slot3_an :
                                             slot4_an;
    assign active_slot_seg = slot1_selected ? slot1_seg :
                             slot2_selected ? slot2_seg :
                             slot3_selected ? slot3_seg :
                                              slot4_seg;
    assign active_slot_buzzer = slot1_selected ? slot1_buzzer :
                                slot2_selected ? slot2_buzzer :
                                slot3_selected ? slot3_buzzer :
                                                 slot4_buzzer;

    assign active_seg = active_slot_seg;

    assign LED = menu_active ? (16'h8000 | (16'h0001 << menu_cursor)) :
                                active_slot_led;
    assign AN = menu_active ? 8'b1111_1111 :
                               active_slot_an;
    assign {CA, CB, CC, CD, CE, CF, CG, DP} = menu_active ? 8'hff : active_seg;
    assign BUZZER = menu_active ? 1'b1 :
                                      active_slot_buzzer;

    always @(*) begin
        if (menu_active) begin
            VGA_R = menu_vga_r_q;
            VGA_G = menu_vga_g_q;
            VGA_B = menu_vga_b_q;
            VGA_HS = console_hs;
            VGA_VS = console_vs;
        end else begin
            VGA_R = active_slot_vga_r;
            VGA_G = active_slot_vga_g;
            VGA_B = active_slot_vga_b;
            VGA_HS = console_hs;
            VGA_VS = console_vs;
        end
    end

`ifdef STUB_SLOT1
    `undef STUB_SLOT1
`endif
`ifdef STUB_SLOT2
    `undef STUB_SLOT2
`endif
`ifdef STUB_SLOT3
    `undef STUB_SLOT3
`endif
`ifdef STUB_SLOT4
    `undef STUB_SLOT4
`endif

endmodule
