// Input mapper for slot 3.
//
// Movement is exposed as held direction signals.  Actions are one-cycle pulses:
// confirm/start, shoot, bomb, EMP, cloak placeholder, Esc, and bullet-time
// Space.  F0/E0 scan-code prefixes are tracked so make/release events become
// stable key flags.
module slot3_input (
    input  wire       clk,
    input  wire       reset,
    input  wire       selected,
    input  wire       ps2_byte_ready,
    input  wire [7:0] ps2_byte_data,
    input  wire       btn_u,
    input  wire       btn_d,
    input  wire       btn_l,
    input  wire       btn_r,
    input  wire       btn_c,
    output wire       input_up,
    output wire       input_down,
    output wire       input_left,
    output wire       input_right,
    output wire       confirm_pulse,
    output wire       shoot_pulse,
    output wire       bomb_pulse,
    output wire       emp_pulse,
    output wire       cloak_pulse,
    output wire       esc_pulse,
    output wire       space_pulse
);

    reg        ps2_break;
    reg        ps2_ext;
    localparam [18:0] PS2_PREFIX_TIMEOUT_CYCLES = 19'd500000;
    reg [18:0] ps2_prefix_timeout_q;

    reg key_w, key_a, key_s, key_d;
    reg key_space, key_enter, key_esc;
    reg key_j, key_k, key_e, key_q;
    reg key_up, key_down, key_left, key_right;

    reg btn_c_prev, key_enter_prev, key_space_prev;
    reg key_esc_prev, key_j_prev, key_k_prev;
    reg key_e_prev, key_q_prev;

    // Buttons and keyboard are equivalent movement sources.
    assign input_up    = btn_u | key_w | key_up;
    assign input_down  = btn_d | key_s | key_down;
    assign input_left  = btn_l | key_a | key_left;
    assign input_right = btn_r | key_d | key_right;

    // One-shot action pulses are generated from rising edges of held key flags.
    assign confirm_pulse = (btn_c & ~btn_c_prev) |
                           (key_enter & ~key_enter_prev) |
                           (key_space & ~key_space_prev);
    assign space_pulse   = key_space & ~key_space_prev;
    assign esc_pulse     = key_esc & ~key_esc_prev;
    assign shoot_pulse   = key_j & ~key_j_prev;
    assign bomb_pulse    = key_k & ~key_k_prev;
    assign emp_pulse     = key_e & ~key_e_prev;
    assign cloak_pulse   = key_q & ~key_q_prev;

    always @(posedge clk) begin
        if (reset || !selected) begin
            ps2_break <= 1'b0;
            ps2_ext <= 1'b0;
            ps2_prefix_timeout_q <= 19'd0;
            key_w <= 1'b0; key_a <= 1'b0; key_s <= 1'b0; key_d <= 1'b0;
            key_space <= 1'b0; key_enter <= 1'b0; key_esc <= 1'b0;
            key_j <= 1'b0; key_k <= 1'b0; key_e <= 1'b0; key_q <= 1'b0;
            key_up <= 1'b0; key_down <= 1'b0; key_left <= 1'b0; key_right <= 1'b0;
            btn_c_prev <= 1'b0; key_enter_prev <= 1'b0; key_space_prev <= 1'b0;
            key_esc_prev <= 1'b0; key_j_prev <= 1'b0; key_k_prev <= 1'b0;
            key_e_prev <= 1'b0; key_q_prev <= 1'b0;
        end else begin
            btn_c_prev <= btn_c;
            key_enter_prev <= key_enter;
            key_space_prev <= key_space;
            key_esc_prev <= key_esc;
            key_j_prev <= key_j;
            key_k_prev <= key_k;
            key_e_prev <= key_e;
            key_q_prev <= key_q;

            // Decode PS/2 scan codes into held key registers.  Arrow keys are
            // only accepted after E0; letter/action keys are plain make codes.
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
                        8'h29: key_space <= ~ps2_break;
                        8'h5A: key_enter <= ~ps2_break;
                        8'h76: key_esc   <= ~ps2_break;
                        8'h3B: key_j     <= ~ps2_break;
                        8'h42: key_k     <= ~ps2_break;
                        8'h24: key_e     <= ~ps2_break;
                        8'h15: key_q     <= ~ps2_break;
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
        end
    end

endmodule
