module slot2_input (
    input  wire       clk,
    input  wire       reset,
    input  wire       selected,
    input  wire       frame_tick,
    input  wire       ps2_byte_ready,
    input  wire [7:0] ps2_byte_data,
    input  wire       btn_l,
    input  wire       btn_r,
    input  wire       btn_d,
    input  wire       btn_u,
    input  wire       btn_c,
    output reg        move_left,
    output reg        move_right,
    output reg        rotate_cw,
    output reg        soft_drop,
    output reg        hard_drop
);

    localparam DAS_INIT  = 5'd10;
    localparam DAS_REPEAT = 5'd3;

    reg        ps2_break;
    reg        ps2_ext;
    reg        key_w;
    reg        key_a;
    reg        key_s;
    reg        key_d;
    reg        key_c;
    reg        key_up;
    reg        key_down;
    reg        key_left;
    reg        key_right;

    reg btn_l_prev, btn_r_prev, btn_d_prev, btn_u_prev, btn_c_prev;
    reg left_prev, right_prev, down_prev, rotate_prev, hard_prev;
    reg btn_l_held, btn_r_held;
    reg [4:0] das_counter;
    reg das_active;

    wire left_in = btn_l | key_a | key_left;
    wire right_in = btn_r | key_d | key_right;
    wire down_in = btn_d | key_s | key_down;
    wire rotate_in = btn_u | key_w | key_up;
    wire hard_in = btn_c | key_c;

    always @(posedge clk) begin
        if (reset) begin
            ps2_break <= 1'b0;
            ps2_ext <= 1'b0;
            key_w <= 1'b0;
            key_a <= 1'b0;
            key_s <= 1'b0;
            key_d <= 1'b0;
            key_c <= 1'b0;
            key_up <= 1'b0;
            key_down <= 1'b0;
            key_left <= 1'b0;
            key_right <= 1'b0;
            btn_l_prev <= 1'b0;
            btn_r_prev <= 1'b0;
            btn_d_prev <= 1'b0;
            btn_u_prev <= 1'b0;
            btn_c_prev <= 1'b0;
            left_prev <= 1'b0;
            right_prev <= 1'b0;
            down_prev <= 1'b0;
            rotate_prev <= 1'b0;
            hard_prev <= 1'b0;
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
                if (ps2_byte_ready) begin
                    if (ps2_byte_data == 8'hF0) begin
                        ps2_break <= 1'b1;
                    end else if (ps2_byte_data == 8'hE0) begin
                        ps2_ext <= 1'b1;
                    end else begin
                        case (ps2_byte_data)
                            8'h1D: key_w     <= ~ps2_break;
                            8'h1C: key_a     <= ~ps2_break;
                            8'h1B: key_s     <= ~ps2_break;
                            8'h23: key_d     <= ~ps2_break;
                            8'h21: key_c     <= ~ps2_break;
                            8'h75: key_up    <= ps2_ext ? ~ps2_break : key_up;
                            8'h72: key_down  <= ps2_ext ? ~ps2_break : key_down;
                            8'h6B: key_left  <= ps2_ext ? ~ps2_break : key_left;
                            8'h74: key_right <= ps2_ext ? ~ps2_break : key_right;
                            default: ;
                        endcase
                        ps2_break <= 1'b0;
                        ps2_ext <= 1'b0;
                    end
                end

                btn_l_prev <= btn_l;
                btn_r_prev <= btn_r;
                btn_d_prev <= btn_d;
                btn_u_prev <= btn_u;
                btn_c_prev <= btn_c;
                left_prev <= left_in;
                right_prev <= right_in;
                down_prev <= down_in;
                rotate_prev <= rotate_in;
                hard_prev <= hard_in;

                if (left_in && !left_prev) begin
                    move_left <= 1'b1;
                    btn_l_held <= 1'b1;
                    das_counter <= 5'd0;
                    das_active <= 1'b0;
                end else if (!left_in) begin
                    btn_l_held <= 1'b0;
                end

                if (right_in && !right_prev) begin
                    move_right <= 1'b1;
                    btn_r_held <= 1'b1;
                    das_counter <= 5'd0;
                    das_active <= 1'b0;
                end else if (!right_in) begin
                    btn_r_held <= 1'b0;
                end

                if (down_in && !down_prev) begin
                    soft_drop <= 1'b1;
                end else if (down_in && frame_tick) begin
                    soft_drop <= 1'b1;
                end

                if (rotate_in && !rotate_prev) begin
                    rotate_cw <= 1'b1;
                end

                if (hard_in && !hard_prev) begin
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
                ps2_break <= 1'b0;
                ps2_ext <= 1'b0;
                key_w <= 1'b0;
                key_a <= 1'b0;
                key_s <= 1'b0;
                key_d <= 1'b0;
                key_c <= 1'b0;
                key_up <= 1'b0;
                key_down <= 1'b0;
                key_left <= 1'b0;
                key_right <= 1'b0;
                left_prev <= 1'b0;
                right_prev <= 1'b0;
                down_prev <= 1'b0;
                rotate_prev <= 1'b0;
                hard_prev <= 1'b0;
                btn_l_held <= 1'b0;
                btn_r_held <= 1'b0;
                das_counter <= 5'd0;
                das_active <= 1'b0;
            end
        end
    end

endmodule
