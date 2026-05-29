module slot2_renderer (
    input  wire        clk,
    input  wire        reset,
    input  wire        selected,
    input  wire        display_active,
    input  wire [9:0]  pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire [199:0] board,
    input  wire [2:0]  piece_type,
    input  wire [1:0]  piece_rotation,
    input  wire signed [4:0] piece_x,
    input  wire [5:0]  piece_y,
    input  wire [5:0]  ghost_piece_y,
    input  wire [2:0]  next_type,
    input  wire [15:0] score,
    input  wire [9:0]  lines,
    input  wire [3:0]  level,
    input  wire        game_over,
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b
);

    localparam BX = 40;
    localparam BY = 40;
    localparam CS = 20;

    reg [15:0] score_sample;
    reg [15:0] score_work;
    reg [9:0]  lines_sample;
    reg [9:0]  lines_work;
    reg [3:0]  level_sample;
    reg [3:0]  level_work;
    reg [3:0]  bcd_state;
    reg [3:0]  score5;
    reg [3:0]  score4;
    reg [3:0]  score3;
    reg [3:0]  score2;
    reg [3:0]  score1;
    reg [3:0]  score0;
    reg [3:0]  lines2;
    reg [3:0]  lines1;
    reg [3:0]  lines0;
    reg [3:0]  lvl1;
    reg [3:0]  lvl0;

    always @(posedge clk) begin
        if (reset) begin
            score_sample <= 16'd0;
            score_work <= 16'd0;
            lines_sample <= 10'd0;
            lines_work <= 10'd0;
            level_sample <= 4'd0;
            level_work <= 4'd0;
            bcd_state <= 4'd0;
            score5 <= 4'd0;
            score4 <= 4'd0;
            score3 <= 4'd0;
            score2 <= 4'd0;
            score1 <= 4'd0;
            score0 <= 4'd0;
            lines2 <= 4'd0;
            lines1 <= 4'd0;
            lines0 <= 4'd0;
            lvl1 <= 4'd0;
            lvl0 <= 4'd0;
        end else begin
            case (bcd_state)
                4'd0: begin
                    if ((score_sample != score) ||
                        (lines_sample != lines) ||
                        (level_sample != level)) begin
                        score_sample <= score;
                        score_work <= score;
                        lines_sample <= lines;
                        lines_work <= lines;
                        level_sample <= level;
                        level_work <= level;
                        score5 <= 4'd0;
                        score4 <= 4'd0;
                        score3 <= 4'd0;
                        score2 <= 4'd0;
                        score1 <= 4'd0;
                        score0 <= 4'd0;
                        lines2 <= 4'd0;
                        lines1 <= 4'd0;
                        lines0 <= 4'd0;
                        lvl1 <= 4'd0;
                        lvl0 <= 4'd0;
                        bcd_state <= 4'd1;
                    end
                end
                4'd1: begin
                    if (score_work >= 16'd10000) begin
                        score_work <= score_work - 16'd10000;
                        score4 <= score4 + 4'd1;
                    end else begin
                        bcd_state <= 4'd2;
                    end
                end
                4'd2: begin
                    if (score_work >= 16'd1000) begin
                        score_work <= score_work - 16'd1000;
                        score3 <= score3 + 4'd1;
                    end else begin
                        bcd_state <= 4'd3;
                    end
                end
                4'd3: begin
                    if (score_work >= 16'd100) begin
                        score_work <= score_work - 16'd100;
                        score2 <= score2 + 4'd1;
                    end else begin
                        bcd_state <= 4'd4;
                    end
                end
                4'd4: begin
                    if (score_work >= 16'd10) begin
                        score_work <= score_work - 16'd10;
                        score1 <= score1 + 4'd1;
                    end else begin
                        score0 <= score_work[3:0];
                        bcd_state <= 4'd5;
                    end
                end
                4'd5: begin
                    if (lines_work >= 10'd100) begin
                        lines_work <= lines_work - 10'd100;
                        lines2 <= lines2 + 4'd1;
                    end else begin
                        bcd_state <= 4'd6;
                    end
                end
                4'd6: begin
                    if (lines_work >= 10'd10) begin
                        lines_work <= lines_work - 10'd10;
                        lines1 <= lines1 + 4'd1;
                    end else begin
                        lines0 <= lines_work[3:0];
                        bcd_state <= 4'd7;
                    end
                end
                4'd7: begin
                    if (level_work >= 4'd10) begin
                        level_work <= level_work - 4'd10;
                        lvl1 <= lvl1 + 4'd1;
                    end else begin
                        lvl0 <= level_work;
                        bcd_state <= 4'd0;
                    end
                end
                default: bcd_state <= 4'd0;
            endcase
        end
    end

    // ======== character ROM (8x8 glyphs) ========
    function [7:0] glyph_row;
        input [7:0] ch;
        input [2:0] row;
        reg [7:0] bits;
        begin
            case (ch)
                " ": bits=8'h00;
                "0": case(row) 0:bits=8'h3C;1:bits=8'h66;2:bits=8'h6E;3:bits=8'h76;4:bits=8'h66;5:bits=8'h66;6:bits=8'h3C;default:bits=8'h00; endcase
                "1": case(row) 0:bits=8'h18;1:bits=8'h38;2:bits=8'h18;3:bits=8'h18;4:bits=8'h18;5:bits=8'h18;6:bits=8'h7E;default:bits=8'h00; endcase
                "2": case(row) 0:bits=8'h3C;1:bits=8'h66;2:bits=8'h06;3:bits=8'h0C;4:bits=8'h18;5:bits=8'h30;6:bits=8'h7E;default:bits=8'h00; endcase
                "3": case(row) 0:bits=8'h3C;1:bits=8'h66;2:bits=8'h06;3:bits=8'h1C;4:bits=8'h06;5:bits=8'h66;6:bits=8'h3C;default:bits=8'h00; endcase
                "4": case(row) 0:bits=8'h0C;1:bits=8'h1C;2:bits=8'h2C;3:bits=8'h4C;4:bits=8'h7E;5:bits=8'h0C;6:bits=8'h0C;default:bits=8'h00; endcase
                "5": case(row) 0:bits=8'h7E;1:bits=8'h60;2:bits=8'h7C;3:bits=8'h06;4:bits=8'h06;5:bits=8'h66;6:bits=8'h3C;default:bits=8'h00; endcase
                "6": case(row) 0:bits=8'h3C;1:bits=8'h60;2:bits=8'h7C;3:bits=8'h66;4:bits=8'h66;5:bits=8'h66;6:bits=8'h3C;default:bits=8'h00; endcase
                "7": case(row) 0:bits=8'h7E;1:bits=8'h06;2:bits=8'h0C;3:bits=8'h18;4:bits=8'h30;5:bits=8'h30;6:bits=8'h30;default:bits=8'h00; endcase
                "8": case(row) 0:bits=8'h3C;1:bits=8'h66;2:bits=8'h66;3:bits=8'h3C;4:bits=8'h66;5:bits=8'h66;6:bits=8'h3C;default:bits=8'h00; endcase
                "9": case(row) 0:bits=8'h3C;1:bits=8'h66;2:bits=8'h66;3:bits=8'h3E;4:bits=8'h06;5:bits=8'h0C;6:bits=8'h38;default:bits=8'h00; endcase
                "A": case(row) 0:bits=8'h18;1:bits=8'h3C;2:bits=8'h66;3:bits=8'h66;4:bits=8'h7E;5:bits=8'h66;6:bits=8'h66;default:bits=8'h00; endcase
                "B": case(row) 0:bits=8'h7C;1:bits=8'h66;2:bits=8'h66;3:bits=8'h7C;4:bits=8'h66;5:bits=8'h66;6:bits=8'h7C;default:bits=8'h00; endcase
                "C": case(row) 0:bits=8'h3C;1:bits=8'h66;2:bits=8'h60;3:bits=8'h60;4:bits=8'h60;5:bits=8'h66;6:bits=8'h3C;default:bits=8'h00; endcase
                "D": case(row) 0:bits=8'h78;1:bits=8'h6C;2:bits=8'h66;3:bits=8'h66;4:bits=8'h66;5:bits=8'h6C;6:bits=8'h78;default:bits=8'h00; endcase
                "E": case(row) 0:bits=8'h7E;1:bits=8'h60;2:bits=8'h60;3:bits=8'h7C;4:bits=8'h60;5:bits=8'h60;6:bits=8'h7E;default:bits=8'h00; endcase
                "F": case(row) 0:bits=8'h7E;1:bits=8'h60;2:bits=8'h60;3:bits=8'h7C;4:bits=8'h60;5:bits=8'h60;6:bits=8'h60;default:bits=8'h00; endcase
                "G": case(row) 0:bits=8'h3C;1:bits=8'h66;2:bits=8'h60;3:bits=8'h6E;4:bits=8'h66;5:bits=8'h66;6:bits=8'h3C;default:bits=8'h00; endcase
                "H": case(row) 0:bits=8'h66;1:bits=8'h66;2:bits=8'h66;3:bits=8'h7E;4:bits=8'h66;5:bits=8'h66;6:bits=8'h66;default:bits=8'h00; endcase
                "I": case(row) 0:bits=8'h7E;1:bits=8'h18;2:bits=8'h18;3:bits=8'h18;4:bits=8'h18;5:bits=8'h18;6:bits=8'h7E;default:bits=8'h00; endcase
                "J": case(row) 0:bits=8'h1E;1:bits=8'h0C;2:bits=8'h0C;3:bits=8'h0C;4:bits=8'h0C;5:bits=8'h6C;6:bits=8'h38;default:bits=8'h00; endcase
                "K": case(row) 0:bits=8'h66;1:bits=8'h6C;2:bits=8'h78;3:bits=8'h70;4:bits=8'h78;5:bits=8'h6C;6:bits=8'h66;default:bits=8'h00; endcase
                "L": case(row) 0:bits=8'h60;1:bits=8'h60;2:bits=8'h60;3:bits=8'h60;4:bits=8'h60;5:bits=8'h60;6:bits=8'h7E;default:bits=8'h00; endcase
                "M": case(row) 0:bits=8'hC6;1:bits=8'hEE;2:bits=8'hFE;3:bits=8'hD6;4:bits=8'hC6;5:bits=8'hC6;6:bits=8'hC6;default:bits=8'h00; endcase
                "N": case(row) 0:bits=8'h66;1:bits=8'h76;2:bits=8'h7E;3:bits=8'h6E;4:bits=8'h66;5:bits=8'h66;6:bits=8'h66;default:bits=8'h00; endcase
                "O": case(row) 0:bits=8'h3C;1:bits=8'h66;2:bits=8'h66;3:bits=8'h66;4:bits=8'h66;5:bits=8'h66;6:bits=8'h3C;default:bits=8'h00; endcase
                "P": case(row) 0:bits=8'h7C;1:bits=8'h66;2:bits=8'h66;3:bits=8'h7C;4:bits=8'h60;5:bits=8'h60;6:bits=8'h60;default:bits=8'h00; endcase
                "R": case(row) 0:bits=8'h7C;1:bits=8'h66;2:bits=8'h66;3:bits=8'h7C;4:bits=8'h78;5:bits=8'h6C;6:bits=8'h66;default:bits=8'h00; endcase
                "S": case(row) 0:bits=8'h3C;1:bits=8'h66;2:bits=8'h60;3:bits=8'h3C;4:bits=8'h06;5:bits=8'h66;6:bits=8'h3C;default:bits=8'h00; endcase
                "T": case(row) 0:bits=8'h7E;1:bits=8'h18;2:bits=8'h18;3:bits=8'h18;4:bits=8'h18;5:bits=8'h18;6:bits=8'h18;default:bits=8'h00; endcase
                "U": case(row) 0:bits=8'h66;1:bits=8'h66;2:bits=8'h66;3:bits=8'h66;4:bits=8'h66;5:bits=8'h66;6:bits=8'h3C;default:bits=8'h00; endcase
                "V": case(row) 0:bits=8'h66;1:bits=8'h66;2:bits=8'h66;3:bits=8'h66;4:bits=8'h3C;5:bits=8'h3C;6:bits=8'h18;default:bits=8'h00; endcase
                "W": case(row) 0:bits=8'hC6;1:bits=8'hC6;2:bits=8'hD6;3:bits=8'hFE;4:bits=8'hEE;5:bits=8'hC6;6:bits=8'hC6;default:bits=8'h00; endcase
                "X": case(row) 0:bits=8'h66;1:bits=8'h66;2:bits=8'h3C;3:bits=8'h18;4:bits=8'h3C;5:bits=8'h66;6:bits=8'h66;default:bits=8'h00; endcase
                "Y": case(row) 0:bits=8'h66;1:bits=8'h66;2:bits=8'h3C;3:bits=8'h18;4:bits=8'h18;5:bits=8'h18;6:bits=8'h18;default:bits=8'h00; endcase
                "Z": case(row) 0:bits=8'h7E;1:bits=8'h06;2:bits=8'h0C;3:bits=8'h18;4:bits=8'h30;5:bits=8'h60;6:bits=8'h7E;default:bits=8'h00; endcase
                "/": case(row) 0:bits=8'h02;1:bits=8'h04;2:bits=8'h08;3:bits=8'h10;4:bits=8'h20;5:bits=8'h40;6:bits=8'h80;default:bits=8'h00; endcase
                ":": case(row) 0:bits=8'h00;1:bits=8'h18;2:bits=8'h18;3:bits=8'h00;4:bits=8'h18;5:bits=8'h18;6:bits=8'h00;default:bits=8'h00; endcase
                default: bits = 8'h00;
            endcase
            glyph_row = bits;
        end
    endfunction

    // check if pixel is on for a single character at (tx,ty) with scale
    function char_on;
        input [9:0] px;
        input [9:0] py;
        input [7:0] ch;
        input [9:0] tx;
        input [9:0] ty;
        input [2:0] sc;
        reg signed [10:0] rx, ry;
        reg [2:0] gx, gy;
        reg [7:0] glyph;
        begin
            rx = {1'b0, px} - {1'b0, tx};
            ry = {1'b0, py} - {1'b0, ty};
            if (rx >= 0 && ry >= 0 && rx < 8*sc && ry < 7*sc) begin
                case (sc)
                    3'd1: begin gx = rx[2:0]; gy = ry[2:0]; end
                    3'd2: begin gx = rx[3:1]; gy = ry[3:1]; end
                    3'd4: begin gx = rx[4:2]; gy = ry[4:2]; end
                    default: begin gx = rx[2:0]; gy = ry[2:0]; end
                endcase
                glyph = glyph_row(ch, gy[2:0]);
                char_on = glyph[7 - gx[2:0]];
            end else begin
                char_on = 1'b0;
            end
        end
    endfunction

    // piece shape ROM
    function [15:0] piece_shape;
        input [2:0] pt;
        input [1:0] pr;
        begin
            case ({pt, pr})
                {3'd0,2'd0}: piece_shape=16'h0F00; {3'd0,2'd1}: piece_shape=16'h1111;
                {3'd0,2'd2}: piece_shape=16'h00F0; {3'd0,2'd3}: piece_shape=16'h1111;
                {3'd1,2'd0}: piece_shape=16'h0330; {3'd1,2'd1}: piece_shape=16'h0330;
                {3'd1,2'd2}: piece_shape=16'h0330; {3'd1,2'd3}: piece_shape=16'h0330;
                {3'd2,2'd0}: piece_shape=16'h0072; {3'd2,2'd1}: piece_shape=16'h0232;
                {3'd2,2'd2}: piece_shape=16'h0270; {3'd2,2'd3}: piece_shape=16'h0131;
                {3'd3,2'd0}: piece_shape=16'h0063; {3'd3,2'd1}: piece_shape=16'h0132;
                {3'd3,2'd2}: piece_shape=16'h0063; {3'd3,2'd3}: piece_shape=16'h0132;
                {3'd4,2'd0}: piece_shape=16'h0036; {3'd4,2'd1}: piece_shape=16'h0231;
                {3'd4,2'd2}: piece_shape=16'h0036; {3'd4,2'd3}: piece_shape=16'h0231;
                {3'd5,2'd0}: piece_shape=16'h0074; {3'd5,2'd1}: piece_shape=16'h0223;
                {3'd5,2'd2}: piece_shape=16'h0170; {3'd5,2'd3}: piece_shape=16'h0311;
                {3'd6,2'd0}: piece_shape=16'h0071; {3'd6,2'd1}: piece_shape=16'h0322;
                {3'd6,2'd2}: piece_shape=16'h0470; {3'd6,2'd3}: piece_shape=16'h0113;
                default: piece_shape=16'h0000;
            endcase
        end
    endfunction

    function [11:0] piece_rgb;
        input [2:0] pt;
        begin
            case (pt)
                3'd0: piece_rgb = {4'h0,4'hF,4'hF};
                3'd1: piece_rgb = {4'hF,4'hF,4'h0};
                3'd2: piece_rgb = {4'hA,4'h0,4'hF};
                3'd3: piece_rgb = {4'h0,4'hF,4'h0};
                3'd4: piece_rgb = {4'hF,4'h0,4'h0};
                3'd5: piece_rgb = {4'h0,4'h0,4'hF};
                3'd6: piece_rgb = {4'hF,4'h8,4'h0};
                default: piece_rgb = {4'hF,4'hF,4'hF};
            endcase
        end
    endfunction

    function [7:0] d2c;
        input [3:0] d;
        begin
            d2c = 8'h30 + {4'd0, d};
        end
    endfunction

    // signals for board area
    wire in_board;
    wire [9:0] bx, by;
    wire [4:0] cell_x, cell_y;
    wire [4:0] cell_px, cell_py;
    wire [9:0] board_idx;
    wire placed;
    wire [11:0] pc_color;
    wire in_next_box;
    wire [9:0] next_bx, next_by;
    wire [4:0] next_cell_x, next_cell_y;

    assign in_board = (pixel_x >= BX) && (pixel_x < BX + 10*CS) &&
                      (pixel_y >= BY) && (pixel_y < BY + 20*CS);
    assign bx = pixel_x - BX;
    assign by = pixel_y - BY;
    assign cell_x = (bx < 10'd20)  ? 5'd0 :
                    (bx < 10'd40)  ? 5'd1 :
                    (bx < 10'd60)  ? 5'd2 :
                    (bx < 10'd80)  ? 5'd3 :
                    (bx < 10'd100) ? 5'd4 :
                    (bx < 10'd120) ? 5'd5 :
                    (bx < 10'd140) ? 5'd6 :
                    (bx < 10'd160) ? 5'd7 :
                    (bx < 10'd180) ? 5'd8 : 5'd9;
    assign cell_y = (by < 10'd20)  ? 5'd0 :
                    (by < 10'd40)  ? 5'd1 :
                    (by < 10'd60)  ? 5'd2 :
                    (by < 10'd80)  ? 5'd3 :
                    (by < 10'd100) ? 5'd4 :
                    (by < 10'd120) ? 5'd5 :
                    (by < 10'd140) ? 5'd6 :
                    (by < 10'd160) ? 5'd7 :
                    (by < 10'd180) ? 5'd8 :
                    (by < 10'd200) ? 5'd9 :
                    (by < 10'd220) ? 5'd10 :
                    (by < 10'd240) ? 5'd11 :
                    (by < 10'd260) ? 5'd12 :
                    (by < 10'd280) ? 5'd13 :
                    (by < 10'd300) ? 5'd14 :
                    (by < 10'd320) ? 5'd15 :
                    (by < 10'd340) ? 5'd16 :
                    (by < 10'd360) ? 5'd17 :
                    (by < 10'd380) ? 5'd18 : 5'd19;
    assign cell_px = bx - (cell_x * 5'd20);
    assign cell_py = by - (cell_y * 5'd20);
    assign board_idx = cell_y * 5'd10 + {6'd0, cell_x};
    assign placed = (cell_x < 5'd10 && cell_y < 6'd20) ? board[board_idx] : 1'b0;

    assign pc_color = piece_rgb(piece_type);

    assign in_next_box = (pixel_x >= 10'd300) && (pixel_x < 10'd380) &&
                         (pixel_y >= 10'd75) && (pixel_y < 10'd155);
    assign next_bx = pixel_x - 10'd300;
    assign next_by = pixel_y - 10'd75;
    assign next_cell_x = (next_bx < 10'd20) ? 5'd0 :
                         (next_bx < 10'd40) ? 5'd1 :
                         (next_bx < 10'd60) ? 5'd2 : 5'd3;
    assign next_cell_y = (next_by < 10'd20) ? 5'd0 :
                         (next_by < 10'd40) ? 5'd1 :
                         (next_by < 10'd60) ? 5'd2 : 5'd3;

    // piece rendering helpers
    function piece_block_on;
        input [4:0] cx;
        input [5:0] cy;
        input [2:0] pt;
        input [1:0] pr;
        input signed [4:0] pxo;
        input [5:0] pyo;
        integer ri, ci;
        reg [15:0] ps;
        reg signed [5:0] block_x;
        begin
            ps = piece_shape(pt, pr);
            piece_block_on = 1'b0;
            for (ri = 0; ri < 4; ri = ri + 1) begin
                for (ci = 0; ci < 4; ci = ci + 1) begin
                    if (ps[ri*4 + ci]) begin
                        block_x = pxo + ci;
                        if (block_x >= 0 && block_x < 10 && cx == block_x[4:0] && cy == (pyo + ri[1:0]))
                            piece_block_on = 1'b1;
                    end
                end
            end
        end
    endfunction

    always @(*) begin
        vga_r = 4'h0;
        vga_g = 4'h0;
        vga_b = 4'h0;

        if (display_active && selected) begin
            // === background ===
            vga_r = 4'h1; vga_g = 4'h1; vga_b = 4'h2;

            // === board rendering ===
            if (in_board) begin
                // board fill
                vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h2;

                // grid
                if ((cell_px == 5'd0) || (cell_py == 5'd0)) begin
                    vga_r = 4'h1; vga_g = 4'h1; vga_b = 4'h3;
                end

                // border
                if (bx < 2 || by < 2 || bx >= 10*CS-2 || by >= 20*CS-2) begin
                    vga_r = 4'h6; vga_g = 4'h6; vga_b = 4'hA;
                end

                // placed blocks
                if (placed) begin
                    vga_r = 4'h8; vga_g = 4'h8; vga_b = 4'h9;
                    if ((cell_px < 5'd2) || (cell_py < 5'd2)) begin
                        vga_r = 4'hA; vga_g = 4'hA; vga_b = 4'hB;
                    end
                    if ((cell_px >= 5'd18) || (cell_py >= 5'd18)) begin
                        vga_r = 4'h5; vga_g = 4'h5; vga_b = 4'h6;
                    end
                end

                // ghost piece
                if (!game_over && piece_block_on(cell_x, cell_y, piece_type, piece_rotation, piece_x, ghost_piece_y)) begin
                    vga_r = pc_color[11:8] >> 2;
                    vga_g = pc_color[7:4] >> 2;
                    vga_b = pc_color[3:0] >> 2;
                end

                // current piece (overwrites ghost at same position)
                if (!game_over && piece_block_on(cell_x, cell_y, piece_type, piece_rotation, piece_x, piece_y)) begin
                    vga_r = pc_color[11:8];
                    vga_g = pc_color[7:4];
                    vga_b = pc_color[3:0];
                    if ((cell_px < 5'd3) || (cell_py < 5'd3)) begin
                        if (vga_r < 4'hC) vga_r = vga_r + 4'h3; else vga_r = 4'hF;
                        if (vga_g < 4'hC) vga_g = vga_g + 4'h3; else vga_g = 4'hF;
                        if (vga_b < 4'hC) vga_b = vga_b + 4'h3; else vga_b = 4'hF;
                    end
                end
            end

            // === side panel text ===
            // "NEXT" at (290, 50), scale 2
            if (char_on(pixel_x,pixel_y,"N",10'd290,10'd50,3'd2) ||
                char_on(pixel_x,pixel_y,"E",10'd306,10'd50,3'd2) ||
                char_on(pixel_x,pixel_y,"X",10'd322,10'd50,3'd2) ||
                char_on(pixel_x,pixel_y,"T",10'd338,10'd50,3'd2)) begin
                vga_r = 4'hF; vga_g = 4'hD; vga_b = 4'h6;
            end

            // next piece preview box at (300, 75), 80x80 pixels = 4x4 cells
            if (in_next_box) begin
                vga_r = 4'h1; vga_g = 4'h1; vga_b = 4'h3;
                if (!game_over && piece_block_on(next_cell_x, next_cell_y, next_type, 2'd0, 5'sd0, 6'd0)) begin
                    {vga_r,vga_g,vga_b} = piece_rgb(next_type);
                end
            end

            // "SCORE" at (290, 160), scale 2
            if (char_on(pixel_x,pixel_y,"S",10'd290,10'd160,3'd2) ||
                char_on(pixel_x,pixel_y,"C",10'd306,10'd160,3'd2) ||
                char_on(pixel_x,pixel_y,"O",10'd322,10'd160,3'd2) ||
                char_on(pixel_x,pixel_y,"R",10'd338,10'd160,3'd2) ||
                char_on(pixel_x,pixel_y,"E",10'd354,10'd160,3'd2)) begin
                vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'hF;
            end

            // score value at (290, 180), scale 2
            if (char_on(pixel_x,pixel_y,d2c(score5),10'd290,10'd180,3'd2)) {vga_r,vga_g,vga_b} = 12'hFFF;
            if (char_on(pixel_x,pixel_y,d2c(score4),10'd306,10'd180,3'd2)) {vga_r,vga_g,vga_b} = 12'hFFF;
            if (char_on(pixel_x,pixel_y,d2c(score3),10'd322,10'd180,3'd2)) {vga_r,vga_g,vga_b} = 12'hFFF;
            if (char_on(pixel_x,pixel_y,d2c(score2),10'd338,10'd180,3'd2)) {vga_r,vga_g,vga_b} = 12'hFFF;
            if (char_on(pixel_x,pixel_y,d2c(score1),10'd354,10'd180,3'd2)) {vga_r,vga_g,vga_b} = 12'hFFF;
            if (char_on(pixel_x,pixel_y,d2c(score0),10'd370,10'd180,3'd2)) {vga_r,vga_g,vga_b} = 12'hFFF;

            // "LINES" at (290, 230), scale 2
            if (char_on(pixel_x,pixel_y,"L",10'd290,10'd230,3'd2) ||
                char_on(pixel_x,pixel_y,"I",10'd306,10'd230,3'd2) ||
                char_on(pixel_x,pixel_y,"N",10'd322,10'd230,3'd2) ||
                char_on(pixel_x,pixel_y,"E",10'd338,10'd230,3'd2) ||
                char_on(pixel_x,pixel_y,"S",10'd354,10'd230,3'd2)) begin
                vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'hF;
            end

            // lines value at (290, 250), scale 2
            if (char_on(pixel_x,pixel_y,d2c(lines2),10'd290,10'd250,3'd2)) {vga_r,vga_g,vga_b} = 12'hFFF;
            if (char_on(pixel_x,pixel_y,d2c(lines1),10'd306,10'd250,3'd2)) {vga_r,vga_g,vga_b} = 12'hFFF;
            if (char_on(pixel_x,pixel_y,d2c(lines0),10'd322,10'd250,3'd2)) {vga_r,vga_g,vga_b} = 12'hFFF;

            // "LEVEL" at (290, 300), scale 2
            if (char_on(pixel_x,pixel_y,"L",10'd290,10'd300,3'd2) ||
                char_on(pixel_x,pixel_y,"E",10'd306,10'd300,3'd2) ||
                char_on(pixel_x,pixel_y,"V",10'd322,10'd300,3'd2) ||
                char_on(pixel_x,pixel_y,"E",10'd338,10'd300,3'd2) ||
                char_on(pixel_x,pixel_y,"L",10'd354,10'd300,3'd2)) begin
                vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'hF;
            end

            // level value at (290, 320), scale 2
            if (char_on(pixel_x,pixel_y,d2c(lvl1),10'd290,10'd320,3'd2)) {vga_r,vga_g,vga_b} = 12'hFFF;
            if (char_on(pixel_x,pixel_y,d2c(lvl0),10'd306,10'd320,3'd2)) {vga_r,vga_g,vga_b} = 12'hFFF;

            // === controls hint ===
            // "A/D:MOVE W:ROT" at (270, 380), scale 1
            if (char_on(pixel_x,pixel_y,"A",10'd270,10'd380,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"/",10'd278,10'd380,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"D",10'd286,10'd380,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,":",10'd294,10'd380,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"M",10'd302,10'd380,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"O",10'd310,10'd380,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"V",10'd318,10'd380,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"E",10'd326,10'd380,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y," ",10'd334,10'd380,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"W",10'd342,10'd380,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,":",10'd350,10'd380,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"R",10'd358,10'd380,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"O",10'd366,10'd380,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"T",10'd374,10'd380,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            // "S:HARD BTN D:SOFT" at (270, 392), scale 1
            if (char_on(pixel_x,pixel_y,"S",10'd270,10'd392,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,":",10'd278,10'd392,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"H",10'd286,10'd392,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"A",10'd294,10'd392,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"R",10'd302,10'd392,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"D",10'd310,10'd392,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y," ",10'd318,10'd392,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"B",10'd326,10'd392,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"T",10'd334,10'd392,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"N",10'd342,10'd392,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y," ",10'd350,10'd392,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"D",10'd358,10'd392,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,":",10'd366,10'd392,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"S",10'd374,10'd392,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"O",10'd382,10'd392,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"F",10'd390,10'd392,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"T",10'd398,10'd392,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            // "ESC : BACK" at (270, 404), scale 1
            if (char_on(pixel_x,pixel_y,"E",10'd270,10'd404,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"S",10'd278,10'd404,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"C",10'd286,10'd404,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,":",10'd294,10'd404,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"B",10'd302,10'd404,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"A",10'd310,10'd404,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"C",10'd318,10'd404,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;
            if (char_on(pixel_x,pixel_y,"K",10'd326,10'd404,3'd1)) {vga_r,vga_g,vga_b}=12'hAAA;

            // === game over overlay ===
            if (game_over) begin
                // semi-transparent darken
                // (just overlay red-ish on center)
                if (pixel_x >= 10'd120 && pixel_x < 10'd520 && pixel_y >= 10'd150 && pixel_y < 10'd330) begin
                    vga_r = (vga_r >> 1) + 4'h2;
                    vga_g = vga_g >> 2;
                    vga_b = vga_b >> 2;
                end

                // "GAME" at (230, 180), scale 4
                if (char_on(pixel_x,pixel_y,"G",10'd230,10'd180,3'd4)) begin vga_r=4'hF;vga_g=4'h0;vga_b=4'h0; end
                if (char_on(pixel_x,pixel_y,"A",10'd262,10'd180,3'd4)) begin vga_r=4'hF;vga_g=4'h0;vga_b=4'h0; end
                if (char_on(pixel_x,pixel_y,"M",10'd294,10'd180,3'd4)) begin vga_r=4'hF;vga_g=4'h0;vga_b=4'h0; end
                if (char_on(pixel_x,pixel_y,"E",10'd326,10'd180,3'd4)) begin vga_r=4'hF;vga_g=4'h0;vga_b=4'h0; end
                // "OVER" at (250, 230), scale 4
                if (char_on(pixel_x,pixel_y,"O",10'd250,10'd230,3'd4)) begin vga_r=4'hF;vga_g=4'h0;vga_b=4'h0; end
                if (char_on(pixel_x,pixel_y,"V",10'd282,10'd230,3'd4)) begin vga_r=4'hF;vga_g=4'h0;vga_b=4'h0; end
                if (char_on(pixel_x,pixel_y,"E",10'd314,10'd230,3'd4)) begin vga_r=4'hF;vga_g=4'h0;vga_b=4'h0; end
                if (char_on(pixel_x,pixel_y,"R",10'd346,10'd230,3'd4)) begin vga_r=4'hF;vga_g=4'h0;vga_b=4'h0; end

                // "PRESS CPU_RESET TO RESTART" at (235, 290), scale 1
                if (char_on(pixel_x,pixel_y,"C",10'd240,10'd290,3'd1)) begin vga_r=4'hF;vga_g=4'hF;vga_b=4'hF; end
                if (char_on(pixel_x,pixel_y,"P",10'd248,10'd290,3'd1)) begin vga_r=4'hF;vga_g=4'hF;vga_b=4'hF; end
                if (char_on(pixel_x,pixel_y,"U",10'd256,10'd290,3'd1)) begin vga_r=4'hF;vga_g=4'hF;vga_b=4'hF; end
                if (char_on(pixel_x,pixel_y," ",10'd264,10'd290,3'd1)) begin vga_r=4'hF;vga_g=4'hF;vga_b=4'hF; end
                if (char_on(pixel_x,pixel_y,"R",10'd272,10'd290,3'd1)) begin vga_r=4'hF;vga_g=4'hF;vga_b=4'hF; end
                if (char_on(pixel_x,pixel_y,"E",10'd280,10'd290,3'd1)) begin vga_r=4'hF;vga_g=4'hF;vga_b=4'hF; end
                if (char_on(pixel_x,pixel_y,"S",10'd288,10'd290,3'd1)) begin vga_r=4'hF;vga_g=4'hF;vga_b=4'hF; end
                if (char_on(pixel_x,pixel_y,"E",10'd296,10'd290,3'd1)) begin vga_r=4'hF;vga_g=4'hF;vga_b=4'hF; end
                if (char_on(pixel_x,pixel_y,"T",10'd304,10'd290,3'd1)) begin vga_r=4'hF;vga_g=4'hF;vga_b=4'hF; end
                if (char_on(pixel_x,pixel_y," ",10'd312,10'd290,3'd1)) begin vga_r=4'hF;vga_g=4'hF;vga_b=4'hF; end
                if (char_on(pixel_x,pixel_y,"T",10'd320,10'd290,3'd1)) begin vga_r=4'hF;vga_g=4'hF;vga_b=4'hF; end
                if (char_on(pixel_x,pixel_y,"O",10'd328,10'd290,3'd1)) begin vga_r=4'hF;vga_g=4'hF;vga_b=4'hF; end
                if (char_on(pixel_x,pixel_y," ",10'd336,10'd290,3'd1)) begin vga_r=4'hF;vga_g=4'hF;vga_b=4'hF; end
                if (char_on(pixel_x,pixel_y,"R",10'd344,10'd290,3'd1)) begin vga_r=4'hF;vga_g=4'hF;vga_b=4'hF; end
                if (char_on(pixel_x,pixel_y,"E",10'd352,10'd290,3'd1)) begin vga_r=4'hF;vga_g=4'hF;vga_b=4'hF; end
                if (char_on(pixel_x,pixel_y,"S",10'd360,10'd290,3'd1)) begin vga_r=4'hF;vga_g=4'hF;vga_b=4'hF; end
                if (char_on(pixel_x,pixel_y,"T",10'd368,10'd290,3'd1)) begin vga_r=4'hF;vga_g=4'hF;vga_b=4'hF; end
                if (char_on(pixel_x,pixel_y,"A",10'd376,10'd290,3'd1)) begin vga_r=4'hF;vga_g=4'hF;vga_b=4'hF; end
                if (char_on(pixel_x,pixel_y,"R",10'd384,10'd290,3'd1)) begin vga_r=4'hF;vga_g=4'hF;vga_b=4'hF; end
                if (char_on(pixel_x,pixel_y,"T",10'd392,10'd290,3'd1)) begin vga_r=4'hF;vga_g=4'hF;vga_b=4'hF; end
            end
        end
    end

endmodule

