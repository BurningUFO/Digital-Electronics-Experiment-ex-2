// Shared 640x480 VGA timing generator.
//
// The board clock stays at 100 MHz.  pixel_tick is a clock-enable pulse that is
// asserted once every four clocks to approximate the 25 MHz VGA pixel rate.  All
// renderers should use pixel_tick as an enable, not as a separate clock.
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

    // Horizontal timing: visible area, front porch, sync pulse, back porch.
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

    // Vertical timing: visible area, front porch, sync pulse, back porch.
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
    // Verilator/behavioral simulations can advance one pixel every clock to run
    // much faster than real VGA timing.
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

    // Coordinates are valid for the whole raster, but display_active identifies
    // the 640x480 visible region where RGB should be nonzero.
    assign display_active = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
    assign pixel_x = h_count;
    assign pixel_y = v_count;
    assign frame_tick = pixel_tick &&
                        (h_count == H_TOTAL - 1) &&
                        (v_count == V_TOTAL - 1);

    // Raster scan counters advance only on the pixel enable.
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

    // VGA sync pulses are active-low and are registered on the same pixel
    // boundary as the coordinate update.
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
