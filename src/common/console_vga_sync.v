module console_vga_sync (
    input  wire       clk,
    input  wire       reset,
    output wire       pixel_tick,
    output wire       display_active,
    output wire [9:0] pixel_x,
    output wire [9:0] pixel_y,
    output reg        hsync,
    output reg        vsync,
    output wire       frame_tick
);

    localparam integer H_VISIBLE = 640;
`ifdef SIM_SHORT_BLANK
    localparam integer H_FRONT   = 2;
    localparam integer H_SYNC    = 4;
    localparam integer H_BACK    = 2;
`else
    localparam integer H_FRONT   = 16;
    localparam integer H_SYNC    = 96;
    localparam integer H_BACK    = 48;
`endif
    localparam integer H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

    localparam integer V_VISIBLE = 480;
`ifdef SIM_SHORT_BLANK
    localparam integer V_FRONT   = 1;
    localparam integer V_SYNC    = 1;
    localparam integer V_BACK    = 1;
`else
    localparam integer V_FRONT   = 10;
    localparam integer V_SYNC    = 2;
    localparam integer V_BACK    = 33;
`endif
    localparam integer V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

    reg [9:0] h_count;
    reg [9:0] v_count;

`ifdef SIM_FAST_VGA
    assign pixel_tick = 1'b1;
`else
    reg [1:0] pix_div;
    assign pixel_tick = (pix_div == 2'b11);

    always @(posedge clk) begin
        if (reset) begin
            pix_div <= 2'b00;
        end else begin
            pix_div <= pix_div + 2'b01;
        end
    end
`endif

    assign display_active = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
    assign pixel_x = h_count;
    assign pixel_y = v_count;
    assign frame_tick = pixel_tick &&
                        (h_count == H_TOTAL - 1) &&
                        (v_count == V_TOTAL - 1);

    always @(posedge clk) begin
        if (reset) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
        end else if (pixel_tick) begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 10'd0;
                if (v_count == V_TOTAL - 1) begin
                    v_count <= 10'd0;
                end else begin
                    v_count <= v_count + 10'd1;
                end
            end else begin
                h_count <= h_count + 10'd1;
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            hsync <= 1'b1;
            vsync <= 1'b1;
        end else if (pixel_tick) begin
            hsync <= ~((h_count >= H_VISIBLE + H_FRONT) &&
                       (h_count <  H_VISIBLE + H_FRONT + H_SYNC));
            vsync <= ~((v_count >= V_VISIBLE + V_FRONT) &&
                       (v_count <  V_VISIBLE + V_FRONT + V_SYNC));
        end
    end

endmodule
