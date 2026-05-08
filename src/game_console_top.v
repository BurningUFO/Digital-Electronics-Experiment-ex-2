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
    wire tank_selected;
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

    wire [3:0] tank_vga_r;
    wire [3:0] tank_vga_g;
    wire [3:0] tank_vga_b;
    wire tank_vga_hs;
    wire tank_vga_vs;
    wire [15:0] tank_led;
    wire [7:0] tank_an;
    wire tank_ca;
    wire tank_cb;
    wire tank_cc;
    wire tank_cd;
    wire tank_ce;
    wire tank_cf;
    wire tank_cg;
    wire tank_dp;
    wire tank_buzzer;

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
    wire [7:0] tank_seg;
    wire [7:0] active_seg;

    assign reset = ~CPU_RESETN;

    assign tank_selected = !menu_active && (game_sel == 3'd0);
    assign slot1_selected = !menu_active && (game_sel == 3'd1);
    assign slot2_selected = !menu_active && (game_sel == 3'd2);
    assign slot3_selected = !menu_active && (game_sel == 3'd3);
    assign slot4_selected = !menu_active && (game_sel == 3'd4);

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

    tank_top u_tank_top (
        .CLK100MHZ(CLK100MHZ),
        .CPU_RESETN(CPU_RESETN & tank_selected),
        .PS2_CLK(PS2_CLK),
        .PS2_DATA(PS2_DATA),
        .BUZZER(tank_buzzer),
        .LED(tank_led),
        .AN(tank_an),
        .CA(tank_ca),
        .CB(tank_cb),
        .CC(tank_cc),
        .CD(tank_cd),
        .CE(tank_ce),
        .CF(tank_cf),
        .CG(tank_cg),
        .DP(tank_dp),
        .VGA_R(tank_vga_r),
        .VGA_G(tank_vga_g),
        .VGA_B(tank_vga_b),
        .VGA_HS(tank_vga_hs),
        .VGA_VS(tank_vga_vs)
    );

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

    assign active_slot_vga_r = slot1_selected ? slot1_vga_r :
                               slot2_selected ? slot2_vga_r :
                               slot3_selected ? slot3_vga_r :
                                                slot4_vga_r;
    assign active_slot_vga_g = slot1_selected ? slot1_vga_g :
                               slot2_selected ? slot2_vga_g :
                               slot3_selected ? slot3_vga_g :
                                                slot4_vga_g;
    assign active_slot_vga_b = slot1_selected ? slot1_vga_b :
                               slot2_selected ? slot2_vga_b :
                               slot3_selected ? slot3_vga_b :
                                                slot4_vga_b;

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

    assign tank_seg = {tank_ca, tank_cb, tank_cc, tank_cd, tank_ce, tank_cf, tank_cg, tank_dp};
    assign active_seg = tank_selected ? tank_seg : active_slot_seg;

    assign LED = menu_active ? (16'h8000 | (16'h0001 << menu_cursor)) :
                 tank_selected ? tank_led :
                                 active_slot_led;
    assign AN = menu_active ? 8'b1111_1111 :
                tank_selected ? tank_an :
                                active_slot_an;
    assign {CA, CB, CC, CD, CE, CF, CG, DP} = menu_active ? 8'hff : active_seg;
    assign BUZZER = menu_active ? 1'b1 :
                    tank_selected ? tank_buzzer :
                                    active_slot_buzzer;

    always @(*) begin
        if (menu_active) begin
            VGA_R = menu_vga_r;
            VGA_G = menu_vga_g;
            VGA_B = menu_vga_b;
            VGA_HS = console_hs;
            VGA_VS = console_vs;
        end else if (tank_selected) begin
            VGA_R = tank_vga_r;
            VGA_G = tank_vga_g;
            VGA_B = tank_vga_b;
            VGA_HS = tank_vga_hs;
            VGA_VS = tank_vga_vs;
        end else begin
            VGA_R = active_slot_vga_r;
            VGA_G = active_slot_vga_g;
            VGA_B = active_slot_vga_b;
            VGA_HS = console_hs;
            VGA_VS = console_vs;
        end
    end

endmodule
