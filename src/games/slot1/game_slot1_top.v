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

    wire _unused_console_api = &{
        1'b0,
        frame_tick,
        pixel_tick,
        display_active,
        pixel_x,
        pixel_y,
        btn_u,
        btn_d,
        btn_l,
        btn_r,
        btn_c,
        sw
    };
    reg tank_enable;
    wire tank_vga_hs;
    wire tank_vga_vs;

    always @(posedge clk) begin
        if (reset || !selected) begin
            tank_enable <= 1'b0;
        end else if (frame_tick) begin
            tank_enable <= 1'b1;
        end
    end

    tank_top u_tank_top (
        .CLK100MHZ(clk),
        .CPU_RESETN(tank_enable),
        .PS2_CLK(ps2_clk),
        .PS2_DATA(ps2_data),
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
        .VGA_B(vga_b),
        .VGA_HS(tank_vga_hs),
        .VGA_VS(tank_vga_vs)
    );

endmodule
