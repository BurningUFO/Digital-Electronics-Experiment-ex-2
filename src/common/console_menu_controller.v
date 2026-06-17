// Converts PS/2 scan-code bytes into console menu state.
//
// The controller treats key make events as commands:
// - W / Up: move cursor up;
// - S / Down: move cursor down;
// - Enter / Space: launch the highlighted game;
// - Esc: return from a game to the menu.
//
// F0 release prefixes are tracked so key releases do not trigger menu actions.
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
    localparam [2:0] MENU_LAST_ITEM = 3'd3;
    // If an F0/E0 prefix is seen without a following scan code, clear the prefix
    // state so one bad byte cannot poison all later keyboard input.
    localparam [18:0] PREFIX_TIMEOUT_CYCLES = 19'd500000;

    reg break_pending;
    reg extend_pending;
    reg [18:0] prefix_timeout_q;

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
            prefix_timeout_q <= 19'd0;
        end else begin
            launch_pulse <= 1'b0;

            if (byte_ready) begin
                prefix_timeout_q <= 19'd0;
                if (byte_data == SCAN_F0) begin
                    break_pending <= 1'b1;
                end else if (byte_data == SCAN_E0) begin
                    extend_pending <= 1'b1;
                end else begin
                    // Only make codes change menu state.  Release codes are
                    // consumed by break_pending and then ignored.
                    if (!break_pending) begin
                        if (menu_active) begin
                            if (is_up_key) begin
                                cursor <= (cursor == 3'd0) ? MENU_LAST_ITEM : cursor - 3'd1;
                            end else if (is_down_key) begin
                                cursor <= (cursor == MENU_LAST_ITEM) ? 3'd0 : cursor + 3'd1;
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
            end else if (break_pending || extend_pending) begin
                if (prefix_timeout_q == PREFIX_TIMEOUT_CYCLES) begin
                    break_pending <= 1'b0;
                    extend_pending <= 1'b0;
                    prefix_timeout_q <= 19'd0;
                end else begin
                    prefix_timeout_q <= prefix_timeout_q + 19'd1;
                end
            end else begin
                prefix_timeout_q <= 19'd0;
            end
        end
    end

endmodule
