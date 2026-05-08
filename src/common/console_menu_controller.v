module console_menu_controller (
    input  wire       clk,
    input  wire       reset,
    input  wire       byte_ready,
    input  wire [7:0] byte_data,
    output reg        menu_active,
    output reg  [2:0] game_sel,
    output reg  [2:0] cursor,
    output reg        launch_pulse
);

    localparam [7:0] SCAN_F0    = 8'hF0;
    localparam [7:0] SCAN_E0    = 8'hE0;
    localparam [7:0] SCAN_W     = 8'h1D;
    localparam [7:0] SCAN_S     = 8'h1B;
    localparam [7:0] SCAN_SPACE = 8'h29;
    localparam [7:0] SCAN_ENTER = 8'h5A;
    localparam [7:0] SCAN_ESC   = 8'h76;
    localparam [7:0] SCAN_UP    = 8'h75;
    localparam [7:0] SCAN_DOWN  = 8'h72;

    reg break_pending;
    reg extend_pending;

    wire is_up_key;
    wire is_down_key;
    wire is_start_key;
    wire is_back_key;

    assign is_up_key = (byte_data == SCAN_W) || (byte_data == SCAN_UP);
    assign is_down_key = (byte_data == SCAN_S) || (byte_data == SCAN_DOWN);
    assign is_start_key = (byte_data == SCAN_SPACE) || (byte_data == SCAN_ENTER);
    assign is_back_key = (byte_data == SCAN_ESC);

    always @(posedge clk) begin
        if (reset) begin
            menu_active <= 1'b1;
            game_sel <= 3'd0;
            cursor <= 3'd0;
            launch_pulse <= 1'b0;
            break_pending <= 1'b0;
            extend_pending <= 1'b0;
        end else begin
            launch_pulse <= 1'b0;

            if (byte_ready) begin
                if (byte_data == SCAN_F0) begin
                    break_pending <= 1'b1;
                end else if (byte_data == SCAN_E0) begin
                    extend_pending <= 1'b1;
                end else begin
                    if (!break_pending) begin
                        if (menu_active) begin
                            if (is_up_key) begin
                                cursor <= (cursor == 3'd0) ? 3'd4 : cursor - 3'd1;
                            end else if (is_down_key) begin
                                cursor <= (cursor == 3'd4) ? 3'd0 : cursor + 3'd1;
                            end else if (is_start_key) begin
                                game_sel <= cursor;
                                menu_active <= 1'b0;
                                launch_pulse <= 1'b1;
                            end
                        end else if (is_back_key) begin
                            cursor <= game_sel;
                            menu_active <= 1'b1;
                        end
                    end

                    break_pending <= 1'b0;
                    extend_pending <= 1'b0;
                end
            end
        end
    end

endmodule
