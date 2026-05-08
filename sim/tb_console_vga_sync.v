`timescale 1ns/1ps

module tb_console_vga_sync;

    reg clk;
    reg reset;
    wire pixel_tick;
    wire display_active;
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire hsync;
    wire vsync;
    wire frame_tick;

    console_vga_sync dut (
        .clk(clk),
        .reset(reset),
        .pixel_tick(pixel_tick),
        .display_active(display_active),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .hsync(hsync),
        .vsync(vsync),
        .frame_tick(frame_tick)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset = 1'b1;
        #100;
        reset = 1'b0;
        wait (frame_tick);
        wait (frame_tick);
        $finish;
    end

endmodule
