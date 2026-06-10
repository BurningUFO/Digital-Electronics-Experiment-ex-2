module blank_game_slot #(
    parameter [2:0] SLOT_ID = 3'd1,
    parameter [3:0] BASE_R  = 4'h2,
    parameter [3:0] BASE_G  = 4'h8,
    parameter [3:0] BASE_B  = 4'hC
) (
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
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b,
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

    reg [23:0] frame_counter;
    reg [6:0]  digit_n;

    wire border;
    wire grid;
    wire stripe;
    wire input_active;

    assign border = (pixel_x < 10'd16) || (pixel_x >= 10'd624) ||
                    (pixel_y < 10'd16) || (pixel_y >= 10'd464);
    assign grid = (pixel_x[5:0] == 6'd0) || (pixel_y[5:0] == 6'd0);
    assign stripe = pixel_x[8:4] == (frame_counter[8:4] + {2'b00, SLOT_ID});
    assign input_active = btn_u | btn_d | btn_l | btn_r | btn_c |
                          sw[0] | sw[1] | sw[2] | sw[3] |
                          ps2_clk | ps2_data | ps2_byte_ready |
                          (|ps2_byte_data) | pixel_tick;

    always @(posedge clk) begin
        if (reset) begin
            frame_counter <= 24'd0;
        end else if (selected && frame_tick) begin
            frame_counter <= frame_counter + 24'd1;
        end
    end

    always @(*) begin
        if (!display_active || !selected) begin
            vga_r = 4'h0;
            vga_g = 4'h0;
            vga_b = 4'h0;
        end else if (border && frame_counter[4]) begin
            vga_r = 4'hF;
            vga_g = 4'hF;
            vga_b = 4'hF;
        end else if (stripe) begin
            vga_r = BASE_R ^ 4'hF;
            vga_g = BASE_G ^ 4'hF;
            vga_b = BASE_B ^ 4'hF;
        end else if (grid) begin
            vga_r = BASE_R >> 1;
            vga_g = BASE_G >> 1;
            vga_b = BASE_B >> 1;
        end else if (input_active) begin
            vga_r = BASE_R;
            vga_g = BASE_G;
            vga_b = BASE_B;
        end else begin
            vga_r = BASE_R >> 2;
            vga_g = BASE_G >> 2;
            vga_b = BASE_B >> 2;
        end
    end

    always @(*) begin
        case (SLOT_ID)
            3'd1: digit_n = 7'b1001111;
            3'd2: digit_n = 7'b0010010;
            3'd3: digit_n = 7'b0000110;
            3'd4: digit_n = 7'b1001100;
            default: digit_n = 7'b0000001;
        endcase
    end

    assign led = selected ? ((16'h0001 << SLOT_ID) | {13'd0, sw[2:0]}) : 16'h0000;
    assign an = selected ? 8'b1111_1110 : 8'b1111_1111;
    assign {ca, cb, cc, cd, ce, cf, cg} = selected ? digit_n : 7'b1111111;
    assign dp = 1'b1;
    assign buzzer = 1'b1;

endmodule
