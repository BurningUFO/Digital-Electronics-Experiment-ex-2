// Input mapper for the slot 2 falling-block game.
//
// It merges board buttons and PS/2 set-2 scan codes into gameplay commands:
// left/right movement with delayed auto-shift, rotate, soft drop, and hard drop.
// PS/2 F0/E0 prefixes are tracked locally so held/released keys become stable
// key-state bits instead of raw scan-code pulses.
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

    // DAS = delayed auto-shift.  After an initial hold delay, left/right repeats
    // every DAS_REPEAT frames while exactly one horizontal direction is held.
    localparam DAS_INIT  = 5'd10;
    localparam DAS_REPEAT = 5'd3;
    localparam [18:0] PS2_PREFIX_TIMEOUT_CYCLES = 19'd500000;

    reg        ps2_break;
    reg        ps2_ext;
    reg [18:0] ps2_prefix_timeout_q;
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
            ps2_prefix_timeout_q <= 19'd0;
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
                // Decode PS/2 make/break bytes into held key flags.  Arrow keys
                // are accepted only after an E0 prefix; WASD/C work without it.
                if (ps2_byte_ready) begin
                    ps2_prefix_timeout_q <= 19'd0;
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
                end else if (ps2_break || ps2_ext) begin
                    if (ps2_prefix_timeout_q == PS2_PREFIX_TIMEOUT_CYCLES) begin
                        ps2_break <= 1'b0;
                        ps2_ext <= 1'b0;
                        ps2_prefix_timeout_q <= 19'd0;
                    end else begin
                        ps2_prefix_timeout_q <= ps2_prefix_timeout_q + 19'd1;
                    end
                end else begin
                    ps2_prefix_timeout_q <= 19'd0;
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

                // Edge-triggered movement provides immediate response.  The DAS
                // section below handles repeats after the first move.
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

                // Horizontal auto-repeat is frame-based so game speed stays
                // stable even though the system clock is 100 MHz.
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
                ps2_prefix_timeout_q <= 19'd0;
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
