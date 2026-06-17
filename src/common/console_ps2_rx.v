// PS/2 serial receiver shared by the console.
//
// This module performs only the protocol-level work:
// - synchronize and debounce the asynchronous PS/2 clock/data lines;
// - sample bits on filtered PS/2 clock falling edges;
// - check start, odd parity, and stop bits;
// - emit a one-cycle byte_ready pulse with the received scan-code byte.
//
// It does not interpret key meanings.  Menu and game input modules consume the
// byte stream and handle F0/E0 prefixes according to their own controls.
module console_ps2_rx (
    input  wire       clk,
    input  wire       reset,
    input  wire       ps2_clk,
    input  wire       ps2_data,
    output reg        byte_ready,
    output reg  [7:0] byte_data
);

    // Abort a partially received frame if the keyboard stops toggling.  At
    // 100 MHz this is long compared with normal PS/2 bit spacing, but short
    // enough to recover from a broken or unplugged frame.
    localparam [17:0] FRAME_TIMEOUT_CYCLES = 18'd200000;

    reg ps2_clk_meta;
    reg ps2_clk_sync;
    reg ps2_data_meta;
    reg ps2_data_sync;
    reg [7:0] ps2_clk_hist;
    reg [7:0] ps2_data_hist;
    reg ps2_clk_q;
    reg ps2_data_q;
    reg [3:0] bit_count;
    reg [7:0] shift_data;
    reg parity_bit;
    reg [17:0] frame_timeout_q;

    wire [7:0] ps2_clk_hist_next;
    wire [7:0] ps2_data_hist_next;
    wire ps2_clk_next;
    wire ps2_data_next;
    wire ps2_clk_fall_next;
    wire ps2_parity_ok;

    // Eight-sample digital filters remove short glitches on the PS/2 lines.  A
    // filtered value changes only after all history bits agree.
    assign ps2_clk_hist_next = {ps2_clk_hist[6:0], ps2_clk_sync};
    assign ps2_data_hist_next = {ps2_data_hist[6:0], ps2_data_sync};
    assign ps2_clk_next = (&ps2_clk_hist_next) ? 1'b1 :
                          (~|ps2_clk_hist_next) ? 1'b0 :
                          ps2_clk_q;
    assign ps2_data_next = (&ps2_data_hist_next) ? 1'b1 :
                           (~|ps2_data_hist_next) ? 1'b0 :
                           ps2_data_q;
    assign ps2_clk_fall_next = ps2_clk_q & ~ps2_clk_next;
    // PS/2 uses odd parity, so data XOR parity must be 1.
    assign ps2_parity_ok = (^shift_data) ^ parity_bit;

    always @(posedge clk) begin
        if (reset) begin
            ps2_clk_meta <= 1'b1;
            ps2_clk_sync <= 1'b1;
            ps2_data_meta <= 1'b1;
            ps2_data_sync <= 1'b1;
            ps2_clk_hist <= 8'hff;
            ps2_data_hist <= 8'hff;
            ps2_clk_q <= 1'b1;
            ps2_data_q <= 1'b1;
            bit_count <= 4'd0;
            shift_data <= 8'd0;
            parity_bit <= 1'b0;
            frame_timeout_q <= 18'd0;
            byte_ready <= 1'b0;
            byte_data <= 8'd0;
        end else begin
            ps2_clk_meta <= ps2_clk;
            ps2_clk_sync <= ps2_clk_meta;
            ps2_data_meta <= ps2_data;
            ps2_data_sync <= ps2_data_meta;
            ps2_clk_hist <= ps2_clk_hist_next;
            ps2_data_hist <= ps2_data_hist_next;
            ps2_clk_q <= ps2_clk_next;
            ps2_data_q <= ps2_data_next;
            byte_ready <= 1'b0;

            // PS/2 devices present stable data around the falling edge of the
            // PS/2 clock.  The bit counter walks through start, 8 data bits,
            // parity, and stop.
            if (ps2_clk_fall_next) begin
                frame_timeout_q <= 18'd0;
                case (bit_count)
                    4'd0: begin
                        if (ps2_data_next == 1'b0) begin
                            bit_count <= 4'd1;
                        end
                    end
                    4'd1: begin
                        shift_data[0] <= ps2_data_next;
                        bit_count <= 4'd2;
                    end
                    4'd2: begin
                        shift_data[1] <= ps2_data_next;
                        bit_count <= 4'd3;
                    end
                    4'd3: begin
                        shift_data[2] <= ps2_data_next;
                        bit_count <= 4'd4;
                    end
                    4'd4: begin
                        shift_data[3] <= ps2_data_next;
                        bit_count <= 4'd5;
                    end
                    4'd5: begin
                        shift_data[4] <= ps2_data_next;
                        bit_count <= 4'd6;
                    end
                    4'd6: begin
                        shift_data[5] <= ps2_data_next;
                        bit_count <= 4'd7;
                    end
                    4'd7: begin
                        shift_data[6] <= ps2_data_next;
                        bit_count <= 4'd8;
                    end
                    4'd8: begin
                        shift_data[7] <= ps2_data_next;
                        bit_count <= 4'd9;
                    end
                    4'd9: begin
                        parity_bit <= ps2_data_next;
                        bit_count <= 4'd10;
                    end
                    4'd10: begin
                        if (ps2_data_next == 1'b1 && ps2_parity_ok) begin
                            byte_data <= shift_data;
                            byte_ready <= 1'b1;
                        end
                        bit_count <= 4'd0;
                    end
                    default: begin
                        bit_count <= 4'd0;
                    end
                endcase
            end else if (bit_count != 4'd0) begin
                if (frame_timeout_q == FRAME_TIMEOUT_CYCLES) begin
                    bit_count <= 4'd0;
                    frame_timeout_q <= 18'd0;
                end else begin
                    frame_timeout_q <= frame_timeout_q + 18'd1;
                end
            end else begin
                frame_timeout_q <= 18'd0;
            end
        end
    end

endmodule
