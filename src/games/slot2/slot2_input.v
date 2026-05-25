module slot2_input (
    input  wire       clk,
    input  wire       reset,
    input  wire       selected,
    input  wire       frame_tick,
    input  wire       btn_l,
    input  wire       btn_r,
    input  wire       btn_d,
    input  wire       btn_u,
    input  wire       btn_c,
    input  wire       ps2_clk,
    input  wire       ps2_data,
    output reg        move_left,
    output reg        move_right,
    output reg        rotate_cw,
    output reg        soft_drop,
    output reg        hard_drop
);

    localparam DAS_INIT  = 5'd10;
    localparam DAS_REPEAT = 5'd3;

    reg btn_l_prev, btn_r_prev, btn_d_prev, btn_u_prev, btn_c_prev;
    reg btn_l_held, btn_r_held;
    reg [4:0] das_counter;
    reg das_active;

    wire ps2_byte_ready;
    wire [7:0] ps2_byte_data;
    wire key_a;
    wire key_d;
    wire key_w;
    wire key_s;

    wire left_cmd = btn_l | key_a;
    wire right_cmd = btn_r | key_d;
    wire rotate_cmd = btn_u | key_w;
    wire soft_drop_cmd = btn_d;
    wire hard_drop_cmd = btn_c | key_s;

    slot2_ps2_rx u_slot2_ps2_rx (
        .clk(clk),
        .reset(reset | ~selected),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .byte_ready(ps2_byte_ready),
        .byte_data(ps2_byte_data)
    );

    slot2_keyboard_mapper u_slot2_keyboard_mapper (
        .clk(clk),
        .reset(reset | ~selected),
        .byte_ready(ps2_byte_ready),
        .byte_data(ps2_byte_data),
        .key_a(key_a),
        .key_d(key_d),
        .key_w(key_w),
        .key_s(key_s)
    );

    always @(posedge clk) begin
        if (reset) begin
            btn_l_prev <= 1'b0;
            btn_r_prev <= 1'b0;
            btn_d_prev <= 1'b0;
            btn_u_prev <= 1'b0;
            btn_c_prev <= 1'b0;
            btn_l_held <= 1'b0;
            btn_r_held <= 1'b0;
            das_counter <= 5'd0;
            das_active <= 1'b0;
            move_left <= 1'b0;
            move_right <= 1'b0;
            rotate_cw <= 1'b0;
            soft_drop <= 1'b0;
            hard_drop <= 1'b0;
        end else begin
            move_left <= 1'b0;
            move_right <= 1'b0;
            rotate_cw <= 1'b0;
            soft_drop <= 1'b0;
            hard_drop <= 1'b0;

            if (selected) begin
                btn_l_prev <= left_cmd;
                btn_r_prev <= right_cmd;
                btn_d_prev <= soft_drop_cmd;
                btn_u_prev <= rotate_cmd;
                btn_c_prev <= hard_drop_cmd;

                if (left_cmd && !btn_l_prev) begin
                    move_left <= 1'b1;
                    btn_l_held <= 1'b1;
                    das_counter <= 5'd0;
                    das_active <= 1'b0;
                end else if (!left_cmd) begin
                    btn_l_held <= 1'b0;
                end

                if (right_cmd && !btn_r_prev) begin
                    move_right <= 1'b1;
                    btn_r_held <= 1'b1;
                    das_counter <= 5'd0;
                    das_active <= 1'b0;
                end else if (!right_cmd) begin
                    btn_r_held <= 1'b0;
                end

                if (soft_drop_cmd && !btn_d_prev) begin
                    soft_drop <= 1'b1;
                end else if (soft_drop_cmd && frame_tick) begin
                    soft_drop <= 1'b1;
                end

                if (rotate_cmd && !btn_u_prev) begin
                    rotate_cw <= 1'b1;
                end

                if (hard_drop_cmd && !btn_c_prev) begin
                    hard_drop <= 1'b1;
                end

                if ((btn_l_held && !btn_r_held) || (!btn_l_held && btn_r_held)) begin
                    if (frame_tick) begin
                        if (!das_active) begin
                            if (das_counter >= DAS_INIT - 5'd1) begin
                                das_active <= 1'b1;
                                das_counter <= 5'd0;
                                if (btn_l_held) move_left <= 1'b1;
                                if (btn_r_held) move_right <= 1'b1;
                            end else begin
                                das_counter <= das_counter + 5'd1;
                            end
                        end else begin
                            if (das_counter >= DAS_REPEAT - 5'd1) begin
                                das_counter <= 5'd0;
                                if (btn_l_held) move_left <= 1'b1;
                                if (btn_r_held) move_right <= 1'b1;
                            end else begin
                                das_counter <= das_counter + 5'd1;
                            end
                        end
                    end
                end else if (!btn_l_held && !btn_r_held) begin
                    das_counter <= 5'd0;
                    das_active <= 1'b0;
                end
            end else begin
                btn_l_prev <= 1'b0;
                btn_r_prev <= 1'b0;
                btn_d_prev <= 1'b0;
                btn_u_prev <= 1'b0;
                btn_c_prev <= 1'b0;
                btn_l_held <= 1'b0;
                btn_r_held <= 1'b0;
                das_counter <= 5'd0;
                das_active <= 1'b0;
            end
        end
    end

endmodule

module slot2_ps2_rx (
    input  wire       clk,
    input  wire       reset,
    input  wire       ps2_clk,
    input  wire       ps2_data,
    output reg        byte_ready,
    output reg  [7:0] byte_data
);

    reg ps2_clk_ff0;
    reg ps2_clk_ff1;
    reg ps2_data_ff0;
    reg ps2_data_ff1;
    reg [3:0] bit_count;
    reg [7:0] shift_data;

    wire ps2_clk_fall = ps2_clk_ff1 & ~ps2_clk_ff0;

    always @(posedge clk) begin
        if (reset) begin
            ps2_clk_ff0 <= 1'b1;
            ps2_clk_ff1 <= 1'b1;
            ps2_data_ff0 <= 1'b1;
            ps2_data_ff1 <= 1'b1;
            bit_count <= 4'd0;
            shift_data <= 8'd0;
            byte_ready <= 1'b0;
            byte_data <= 8'd0;
        end else begin
            ps2_clk_ff0 <= ps2_clk;
            ps2_clk_ff1 <= ps2_clk_ff0;
            ps2_data_ff0 <= ps2_data;
            ps2_data_ff1 <= ps2_data_ff0;
            byte_ready <= 1'b0;

            if (ps2_clk_fall) begin
                case (bit_count)
                    4'd0: begin
                        if (ps2_data_ff1 == 1'b0)
                            bit_count <= 4'd1;
                    end
                    4'd1: begin shift_data[0] <= ps2_data_ff1; bit_count <= 4'd2; end
                    4'd2: begin shift_data[1] <= ps2_data_ff1; bit_count <= 4'd3; end
                    4'd3: begin shift_data[2] <= ps2_data_ff1; bit_count <= 4'd4; end
                    4'd4: begin shift_data[3] <= ps2_data_ff1; bit_count <= 4'd5; end
                    4'd5: begin shift_data[4] <= ps2_data_ff1; bit_count <= 4'd6; end
                    4'd6: begin shift_data[5] <= ps2_data_ff1; bit_count <= 4'd7; end
                    4'd7: begin shift_data[6] <= ps2_data_ff1; bit_count <= 4'd8; end
                    4'd8: begin shift_data[7] <= ps2_data_ff1; bit_count <= 4'd9; end
                    4'd9: begin bit_count <= 4'd10; end
                    4'd10: begin
                        if (ps2_data_ff1 == 1'b1) begin
                            byte_data <= shift_data;
                            byte_ready <= 1'b1;
                        end
                        bit_count <= 4'd0;
                    end
                    default: bit_count <= 4'd0;
                endcase
            end
        end
    end

endmodule

module slot2_keyboard_mapper (
    input  wire       clk,
    input  wire       reset,
    input  wire       byte_ready,
    input  wire [7:0] byte_data,
    output reg        key_a,
    output reg        key_d,
    output reg        key_w,
    output reg        key_s
);

    localparam [7:0] SCAN_F0 = 8'hF0;
    localparam [7:0] SCAN_E0 = 8'hE0;
    localparam [7:0] SCAN_A  = 8'h1C;
    localparam [7:0] SCAN_D  = 8'h23;
    localparam [7:0] SCAN_S  = 8'h1B;
    localparam [7:0] SCAN_W  = 8'h1D;

    reg break_pending;
    reg extend_pending;

    always @(posedge clk) begin
        if (reset) begin
            key_a <= 1'b0;
            key_d <= 1'b0;
            key_w <= 1'b0;
            key_s <= 1'b0;
            break_pending <= 1'b0;
            extend_pending <= 1'b0;
        end else if (byte_ready) begin
            if (byte_data == SCAN_F0) begin
                break_pending <= 1'b1;
            end else if (byte_data == SCAN_E0) begin
                extend_pending <= 1'b1;
            end else begin
                if (!extend_pending) begin
                    case (byte_data)
                        SCAN_A: key_a <= ~break_pending;
                        SCAN_D: key_d <= ~break_pending;
                        SCAN_W: key_w <= ~break_pending;
                        SCAN_S: key_s <= ~break_pending;
                        default: begin end
                    endcase
                end

                break_pending <= 1'b0;
                extend_pending <= 1'b0;
            end
        end
    end

endmodule
