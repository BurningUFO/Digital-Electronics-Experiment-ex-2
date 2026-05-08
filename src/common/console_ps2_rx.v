module console_ps2_rx (
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

    wire ps2_clk_fall;

    assign ps2_clk_fall = ps2_clk_ff1 & ~ps2_clk_ff0;

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
                        if (ps2_data_ff1 == 1'b0) begin
                            bit_count <= 4'd1;
                        end
                    end
                    4'd1: begin
                        shift_data[0] <= ps2_data_ff1;
                        bit_count <= 4'd2;
                    end
                    4'd2: begin
                        shift_data[1] <= ps2_data_ff1;
                        bit_count <= 4'd3;
                    end
                    4'd3: begin
                        shift_data[2] <= ps2_data_ff1;
                        bit_count <= 4'd4;
                    end
                    4'd4: begin
                        shift_data[3] <= ps2_data_ff1;
                        bit_count <= 4'd5;
                    end
                    4'd5: begin
                        shift_data[4] <= ps2_data_ff1;
                        bit_count <= 4'd6;
                    end
                    4'd6: begin
                        shift_data[5] <= ps2_data_ff1;
                        bit_count <= 4'd7;
                    end
                    4'd7: begin
                        shift_data[6] <= ps2_data_ff1;
                        bit_count <= 4'd8;
                    end
                    4'd8: begin
                        shift_data[7] <= ps2_data_ff1;
                        bit_count <= 4'd9;
                    end
                    4'd9: begin
                        bit_count <= 4'd10;
                    end
                    4'd10: begin
                        if (ps2_data_ff1 == 1'b1) begin
                            byte_data <= shift_data;
                            byte_ready <= 1'b1;
                        end
                        bit_count <= 4'd0;
                    end
                    default: begin
                        bit_count <= 4'd0;
                    end
                endcase
            end
        end
    end

endmodule
