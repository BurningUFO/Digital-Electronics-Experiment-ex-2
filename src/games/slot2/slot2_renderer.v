// Pixel renderer for the slot 2 falling-block game.
//
// Inputs are staged by game_slot2_top on pixel_tick.  This module maps the
// current pixel to one of the visual layers: background, board/grid, placed
// cells, ghost piece, current piece, next preview, text, and game-over overlay.
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

    // Convert score/lines/level into decimal digits over several clocks.  The
    // renderer then reads cached digits, avoiding per-pixel division.
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

    // piece shape ROM.  This mirrors the core's tetromino encoding but is kept
    // local so rendering does not depend on core internals.
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

    // Per-piece RGB palette, packed as {R,G,B}.
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

    // Fixed sidebar and overlay strings.
    function [7:0] fixed_text_char;
        input [3:0] msg_id;
        input [4:0] idx;
        begin
            fixed_text_char = " ";
            case (msg_id)
                4'd0: begin
                    case (idx)
                        5'd0: fixed_text_char = "N";
                        5'd1: fixed_text_char = "E";
                        5'd2: fixed_text_char = "X";
                        5'd3: fixed_text_char = "T";
                        default: fixed_text_char = " ";
                    endcase
                end
                4'd1: begin
                    case (idx)
                        5'd0: fixed_text_char = "S";
                        5'd1: fixed_text_char = "C";
                        5'd2: fixed_text_char = "O";
                        5'd3: fixed_text_char = "R";
                        5'd4: fixed_text_char = "E";
                        default: fixed_text_char = " ";
                    endcase
                end
                4'd2: begin
                    case (idx)
                        5'd0: fixed_text_char = "L";
                        5'd1: fixed_text_char = "I";
                        5'd2: fixed_text_char = "N";
                        5'd3: fixed_text_char = "E";
                        5'd4: fixed_text_char = "S";
                        default: fixed_text_char = " ";
                    endcase
                end
                4'd3: begin
                    case (idx)
                        5'd0: fixed_text_char = "L";
                        5'd1: fixed_text_char = "E";
                        5'd2: fixed_text_char = "V";
                        5'd3: fixed_text_char = "E";
                        5'd4: fixed_text_char = "L";
                        default: fixed_text_char = " ";
                    endcase
                end
                4'd4: begin
                    case (idx)
                        5'd0: fixed_text_char = "A";
                        5'd1: fixed_text_char = "/";
                        5'd2: fixed_text_char = "D";
                        5'd3: fixed_text_char = ":";
                        5'd4: fixed_text_char = "M";
                        5'd5: fixed_text_char = "O";
                        5'd6: fixed_text_char = "V";
                        5'd7: fixed_text_char = "E";
                        5'd8: fixed_text_char = " ";
                        5'd9: fixed_text_char = "W";
                        5'd10: fixed_text_char = ":";
                        5'd11: fixed_text_char = "R";
                        5'd12: fixed_text_char = "O";
                        5'd13: fixed_text_char = "T";
                        default: fixed_text_char = " ";
                    endcase
                end
                4'd5: begin
                    case (idx)
                        5'd0: fixed_text_char = "S";
                        5'd1: fixed_text_char = ":";
                        5'd2: fixed_text_char = "H";
                        5'd3: fixed_text_char = "A";
                        5'd4: fixed_text_char = "R";
                        5'd5: fixed_text_char = "D";
                        5'd6: fixed_text_char = " ";
                        5'd7: fixed_text_char = "B";
                        5'd8: fixed_text_char = "T";
                        5'd9: fixed_text_char = "N";
                        5'd10: fixed_text_char = " ";
                        5'd11: fixed_text_char = "D";
                        5'd12: fixed_text_char = ":";
                        5'd13: fixed_text_char = "S";
                        5'd14: fixed_text_char = "O";
                        5'd15: fixed_text_char = "F";
                        5'd16: fixed_text_char = "T";
                        default: fixed_text_char = " ";
                    endcase
                end
                4'd6: begin
                    case (idx)
                        5'd0: fixed_text_char = "E";
                        5'd1: fixed_text_char = "S";
                        5'd2: fixed_text_char = "C";
                        5'd3: fixed_text_char = ":";
                        5'd4: fixed_text_char = "B";
                        5'd5: fixed_text_char = "A";
                        5'd6: fixed_text_char = "C";
                        5'd7: fixed_text_char = "K";
                        default: fixed_text_char = " ";
                    endcase
                end
                4'd7: begin
                    case (idx)
                        5'd0: fixed_text_char = "G";
                        5'd1: fixed_text_char = "A";
                        5'd2: fixed_text_char = "M";
                        5'd3: fixed_text_char = "E";
                        default: fixed_text_char = " ";
                    endcase
                end
                4'd8: begin
                    case (idx)
                        5'd0: fixed_text_char = "O";
                        5'd1: fixed_text_char = "V";
                        5'd2: fixed_text_char = "E";
                        5'd3: fixed_text_char = "R";
                        default: fixed_text_char = " ";
                    endcase
                end
                default: begin
                    case (idx)
                        5'd0: fixed_text_char = "C";
                        5'd1: fixed_text_char = "P";
                        5'd2: fixed_text_char = "U";
                        5'd3: fixed_text_char = " ";
                        5'd4: fixed_text_char = "R";
                        5'd5: fixed_text_char = "E";
                        5'd6: fixed_text_char = "S";
                        5'd7: fixed_text_char = "E";
                        5'd8: fixed_text_char = "T";
                        5'd9: fixed_text_char = " ";
                        5'd10: fixed_text_char = "T";
                        5'd11: fixed_text_char = "O";
                        5'd12: fixed_text_char = " ";
                        5'd13: fixed_text_char = "R";
                        5'd14: fixed_text_char = "E";
                        5'd15: fixed_text_char = "S";
                        5'd16: fixed_text_char = "T";
                        5'd17: fixed_text_char = "A";
                        5'd18: fixed_text_char = "R";
                        5'd19: fixed_text_char = "T";
                        default: fixed_text_char = " ";
                    endcase
                end
            endcase
        end
    endfunction

    function [7:0] digit_text_char;
        input [1:0] msg_id;
        input [2:0] idx;
        begin
            digit_text_char = " ";
            case (msg_id)
                2'd0: begin
                    case (idx)
                        3'd0: digit_text_char = d2c(score5);
                        3'd1: digit_text_char = d2c(score4);
                        3'd2: digit_text_char = d2c(score3);
                        3'd3: digit_text_char = d2c(score2);
                        3'd4: digit_text_char = d2c(score1);
                        3'd5: digit_text_char = d2c(score0);
                        default: digit_text_char = " ";
                    endcase
                end
                2'd1: begin
                    case (idx)
                        3'd0: digit_text_char = d2c(lines2);
                        3'd1: digit_text_char = d2c(lines1);
                        3'd2: digit_text_char = d2c(lines0);
                        default: digit_text_char = " ";
                    endcase
                end
                default: begin
                    case (idx)
                        3'd0: digit_text_char = d2c(lvl1);
                        3'd1: digit_text_char = d2c(lvl0);
                        default: digit_text_char = " ";
                    endcase
                end
            endcase
        end
    endfunction

    // Return true when the current pixel hits a fixed text string.
    function text_on;
        input [9:0] px;
        input [9:0] py;
        input [9:0] tx;
        input [9:0] ty;
        input [2:0] sc;
        input [3:0] msg_id;
        input [4:0] char_count;
        reg signed [10:0] rx;
        reg signed [10:0] ry;
        reg [6:0] char_idx;
        reg [2:0] gx;
        reg [2:0] gy;
        reg [7:0] glyph;
        reg y_in;
        begin
            rx = $signed({1'b0, px}) - $signed({1'b0, tx});
            ry = $signed({1'b0, py}) - $signed({1'b0, ty});
            char_idx = 5'd0;
            gx = 3'd0;
            gy = 3'd0;
            y_in = 1'b0;
            text_on = 1'b0;

            if ((rx >= 11'sd0) && (ry >= 11'sd0)) begin
                case (sc)
                    3'd2: begin
                        char_idx = rx[10:4];
                        gx = rx[3:1];
                        gy = ry[3:1];
                        y_in = (ry < 11'sd14);
                    end
                    3'd4: begin
                        char_idx = rx[10:5];
                        gx = rx[4:2];
                        gy = ry[4:2];
                        y_in = (ry < 11'sd28);
                    end
                    default: begin
                        char_idx = rx[10:3];
                        gx = rx[2:0];
                        gy = ry[2:0];
                        y_in = (ry < 11'sd7);
                    end
                endcase

                if (y_in && (char_idx < {2'b00, char_count})) begin
                    glyph = glyph_row(fixed_text_char(msg_id, char_idx[4:0]), gy);
                    text_on = glyph[7 - gx];
                end
            end
        end
    endfunction

    // Return true when the current pixel hits one of the cached decimal digits.
    function digit_text_on;
        input [9:0] px;
        input [9:0] py;
        input [9:0] tx;
        input [9:0] ty;
        input [1:0] msg_id;
        input [2:0] char_count;
        reg signed [10:0] rx;
        reg signed [10:0] ry;
        reg [5:0] char_idx;
        reg [2:0] gx;
        reg [2:0] gy;
        reg [7:0] glyph;
        begin
            rx = $signed({1'b0, px}) - $signed({1'b0, tx});
            ry = $signed({1'b0, py}) - $signed({1'b0, ty});
            char_idx = rx[10:4];
            gx = rx[3:1];
            gy = ry[3:1];
            digit_text_on = 1'b0;

            if ((rx >= 11'sd0) && (ry >= 11'sd0) &&
                (ry < 11'sd14) && (char_idx < {3'b000, char_count})) begin
                glyph = glyph_row(digit_text_char(msg_id, char_idx[2:0]), gy);
                digit_text_on = glyph[7 - gx];
            end
        end
    endfunction

    // Constant multiply helpers for board coordinate mapping.  They avoid
    // generic pixel-path multiplication/division.
    function [9:0] mul20_5;
        input [4:0] value;
        begin
            mul20_5 = ({5'd0, value} << 4) + ({5'd0, value} << 2);
        end
    endfunction

    function [9:0] mul10_5;
        input [4:0] value;
        begin
            mul10_5 = ({5'd0, value} << 3) + ({5'd0, value} << 1);
        end
    endfunction

    // Signals for board area and next-piece preview coordinate decoding.
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
    assign cell_px = bx - mul20_5(cell_x);
    assign cell_py = by - mul20_5(cell_y);
    assign board_idx = mul10_5(cell_y) + {5'd0, cell_x};
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

    // Piece rendering helper.  It converts a board cell coordinate into a 4x4
    // piece-local coordinate and tests the corresponding shape bit.
    function piece_block_on;
        input [4:0] cx;
        input [5:0] cy;
        input [2:0] pt;
        input [1:0] pr;
        input signed [4:0] pxo;
        input [5:0] pyo;
        reg [15:0] ps;
        reg signed [5:0] rel_x;
        reg [5:0] rel_y;
        reg [3:0] shape_bit_idx;
        begin
            ps = piece_shape(pt, pr);
            rel_x = $signed({1'b0, cx}) - pxo;
            rel_y = cy - pyo;
            shape_bit_idx = {rel_y[1:0], rel_x[1:0]};

            if ((rel_x >= 6'sd0) && (rel_x < 6'sd4) &&
                (cy >= pyo) && (rel_y < 6'd4)) begin
                piece_block_on = ps[shape_bit_idx];
            end else begin
                piece_block_on = 1'b0;
            end
        end
    endfunction

    // Layered pixel compositor.  Later checks override earlier background/grid
    // colors, so current piece appears above ghost and fixed blocks.
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
            if (text_on(pixel_x, pixel_y, 10'd290, 10'd50, 3'd2, 4'd0, 5'd4)) begin
                vga_r = 4'hF; vga_g = 4'hD; vga_b = 4'h6;
            end

            // next piece preview box at (300, 75), 80x80 pixels = 4x4 cells
            if (in_next_box) begin
                vga_r = 4'h1; vga_g = 4'h1; vga_b = 4'h3;
                if (!game_over && piece_block_on(next_cell_x, next_cell_y, next_type, 2'd0, 5'sd0, 6'd0)) begin
                    {vga_r,vga_g,vga_b} = piece_rgb(next_type);
                end
            end

            if (text_on(pixel_x, pixel_y, 10'd290, 10'd160, 3'd2, 4'd1, 5'd5)) begin
                vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'hF;
            end

            if (digit_text_on(pixel_x, pixel_y, 10'd290, 10'd180, 2'd0, 3'd6)) begin
                {vga_r, vga_g, vga_b} = 12'hFFF;
            end

            if (text_on(pixel_x, pixel_y, 10'd290, 10'd230, 3'd2, 4'd2, 5'd5)) begin
                vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'hF;
            end

            if (digit_text_on(pixel_x, pixel_y, 10'd290, 10'd250, 2'd1, 3'd3)) begin
                {vga_r, vga_g, vga_b} = 12'hFFF;
            end

            if (text_on(pixel_x, pixel_y, 10'd290, 10'd300, 3'd2, 4'd3, 5'd5)) begin
                vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'hF;
            end

            if (digit_text_on(pixel_x, pixel_y, 10'd290, 10'd320, 2'd2, 3'd2)) begin
                {vga_r, vga_g, vga_b} = 12'hFFF;
            end

            // === controls hint ===
            if (text_on(pixel_x, pixel_y, 10'd270, 10'd380, 3'd1, 4'd4, 5'd14) ||
                text_on(pixel_x, pixel_y, 10'd270, 10'd392, 3'd1, 4'd5, 5'd17) ||
                text_on(pixel_x, pixel_y, 10'd270, 10'd404, 3'd1, 4'd6, 5'd8)) begin
                {vga_r, vga_g, vga_b} = 12'hAAA;
            end

            // === game over overlay ===
            if (game_over) begin
                // semi-transparent darken
                // (just overlay red-ish on center)
                if (pixel_x >= 10'd120 && pixel_x < 10'd520 && pixel_y >= 10'd150 && pixel_y < 10'd330) begin
                    vga_r = (vga_r >> 1) + 4'h2;
                    vga_g = vga_g >> 2;
                    vga_b = vga_b >> 2;
                end

                if (text_on(pixel_x, pixel_y, 10'd230, 10'd180, 3'd4, 4'd7, 5'd4) ||
                    text_on(pixel_x, pixel_y, 10'd250, 10'd230, 3'd4, 4'd8, 5'd4)) begin
                    {vga_r, vga_g, vga_b} = 12'hF00;
                end

                if (text_on(pixel_x, pixel_y, 10'd240, 10'd290, 3'd1, 4'd9, 5'd20)) begin
                    {vga_r, vga_g, vga_b} = 12'hFFF;
                end
            end
        end
    end

endmodule

