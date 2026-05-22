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
                btn_l_prev <= btn_l;
                btn_r_prev <= btn_r;
                btn_d_prev <= btn_d;
                btn_u_prev <= btn_u;
                btn_c_prev <= btn_c;

                if (btn_l && !btn_l_prev) begin
                    move_left <= 1'b1;
                    btn_l_held <= 1'b1;
                    das_counter <= 5'd0;
                    das_active <= 1'b0;
                end else if (!btn_l) begin
                    btn_l_held <= 1'b0;
                end

                if (btn_r && !btn_r_prev) begin
                    move_right <= 1'b1;
                    btn_r_held <= 1'b1;
                    das_counter <= 5'd0;
                    das_active <= 1'b0;
                end else if (!btn_r) begin
                    btn_r_held <= 1'b0;
                end

                if (btn_d && !btn_d_prev) begin
                    soft_drop <= 1'b1;
                end else if (btn_d && frame_tick) begin
                    soft_drop <= 1'b1;
                end

                if (btn_u && !btn_u_prev) begin
                    rotate_cw <= 1'b1;
                end

                if (btn_c && !btn_c_prev) begin
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
                btn_l_held <= 1'b0;
                btn_r_held <= 1'b0;
                das_counter <= 5'd0;
                das_active <= 1'b0;
            end
        end
    end

endmodule

