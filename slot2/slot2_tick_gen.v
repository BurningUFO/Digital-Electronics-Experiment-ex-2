module slot4_tick_gen (
    input  wire       clk,
    input  wire       reset,
    input  wire       frame_tick,
    input  wire [3:0] level,
    output reg        gravity_tick
);

    reg [5:0] frame_counter;
    reg [5:0] gravity_threshold;

    always @(*) begin
        case (level)
            4'd0:  gravity_threshold = 6'd48;
            4'd1:  gravity_threshold = 6'd43;
            4'd2:  gravity_threshold = 6'd38;
            4'd3:  gravity_threshold = 6'd33;
            4'd4:  gravity_threshold = 6'd28;
            4'd5:  gravity_threshold = 6'd23;
            4'd6:  gravity_threshold = 6'd18;
            4'd7:  gravity_threshold = 6'd13;
            4'd8:  gravity_threshold = 6'd8;
            4'd9:  gravity_threshold = 6'd6;
            4'd10: gravity_threshold = 6'd5;
            4'd11: gravity_threshold = 6'd4;
            default: gravity_threshold = 6'd3;
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            frame_counter <= 6'd0;
            gravity_tick <= 1'b0;
        end else begin
            gravity_tick <= 1'b0;
            if (frame_tick) begin
                if (frame_counter >= gravity_threshold - 6'd1) begin
                    frame_counter <= 6'd0;
                    gravity_tick <= 1'b1;
                end else begin
                    frame_counter <= frame_counter + 6'd1;
                end
            end
        end
    end

endmodule
