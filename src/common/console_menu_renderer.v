module console_menu_renderer (
    input  wire       clk,
    input  wire       reset,
    input  wire       frame_tick,
    input  wire       display_active,
    input  wire [9:0] pixel_x,
    input  wire [9:0] pixel_y,
    input  wire [2:0] cursor,
    output reg  [3:0] vga_r,
    output reg  [3:0] vga_g,
    output reg  [3:0] vga_b
);

    localparam integer TITLE_X = 104;
    localparam integer TITLE_Y = 36;
    localparam integer TITLE_SCALE = 5;
    localparam integer TITLE_COUNT = 12;

    localparam integer ITEM_X = 128;
    localparam integer ITEM_Y0 = 132;
    localparam integer ITEM_W = 384;
    localparam integer ITEM_H = 46;
    localparam integer ITEM_GAP = 14;
    localparam integer ITEM_TEXT_X = 190;
    localparam integer ITEM_TEXT_OFFSET_Y = 12;
    localparam integer ITEM_SCALE = 3;
    localparam integer ITEM_COUNT = 11;
    localparam integer ITEM_STEP = ITEM_H + ITEM_GAP;

    localparam integer HELP_X = 92;
    localparam integer HELP_Y = 438;
    localparam integer HELP_SCALE = 2;
    localparam integer HELP_COUNT = 40;

    reg [25:0] blink_counter;

    integer item_y;
    integer title_rel_x;
    integer title_rel_y;
    integer title_char_idx;
    integer title_cell_x;
    integer title_cell_y;
    integer item_rel_x;
    integer item_rel_y;
    integer item_char_idx;
    integer item_cell_x;
    integer item_cell_y;
    integer help_rel_x;
    integer help_rel_y;
    integer help_char_idx;
    integer help_cell_x;
    integer help_cell_y;

    reg title_on;
    reg item_text_on;
    reg help_on;
    reg selected_item;
    reg item_body;
    reg item_border;
    reg [2:0] active_item;
    reg [7:0] item_char_value;

    always @(posedge clk) begin
        if (reset) begin
            blink_counter <= 26'd0;
        end else if (frame_tick) begin
            blink_counter <= blink_counter + 26'd1;
        end
    end

    function [7:0] title_char;
        input integer idx;
        begin
            case (idx)
                0: title_char = "G";
                1: title_char = "A";
                2: title_char = "M";
                3: title_char = "E";
                4: title_char = " ";
                5: title_char = "C";
                6: title_char = "O";
                7: title_char = "N";
                8: title_char = "S";
                9: title_char = "O";
                10: title_char = "L";
                11: title_char = "E";
                default: title_char = " ";
            endcase
        end
    endfunction

    function [7:0] item_char;
        input [2:0] item;
        input integer idx;
        begin
            case (item)
                3'd0: begin
                    case (idx)
                        0: item_char = "T";
                        1: item_char = "A";
                        2: item_char = "N";
                        3: item_char = "K";
                        4: item_char = " ";
                        5: item_char = "W";
                        6: item_char = "A";
                        7: item_char = "R";
                        default: item_char = " ";
                    endcase
                end
                3'd1: begin
                    case (idx)
                        0: item_char = "G";
                        1: item_char = "A";
                        2: item_char = "M";
                        3: item_char = "E";
                        4: item_char = " ";
                        5: item_char = "T";
                        6: item_char = "W";
                        7: item_char = "O";
                        default: item_char = " ";
                    endcase
                end
                3'd2: begin
                    case (idx)
                        0: item_char = "G";
                        1: item_char = "A";
                        2: item_char = "M";
                        3: item_char = "E";
                        4: item_char = " ";
                        5: item_char = "T";
                        6: item_char = "H";
                        7: item_char = "R";
                        8: item_char = "E";
                        9: item_char = "E";
                        default: item_char = " ";
                    endcase
                end
                3'd3: begin
                    case (idx)
                        0: item_char = "G";
                        1: item_char = "A";
                        2: item_char = "M";
                        3: item_char = "E";
                        4: item_char = " ";
                        5: item_char = "F";
                        6: item_char = "O";
                        7: item_char = "U";
                        8: item_char = "R";
                        default: item_char = " ";
                    endcase
                end
                default: begin
                    item_char = " ";
                end
            endcase
        end
    endfunction

    function [7:0] help_char;
        input integer idx;
        begin
            case (idx)
                0: help_char = "W";
                1: help_char = "S";
                2: help_char = " ";
                3: help_char = "O";
                4: help_char = "R";
                5: help_char = " ";
                6: help_char = "A";
                7: help_char = "R";
                8: help_char = "R";
                9: help_char = "O";
                10: help_char = "W";
                11: help_char = "S";
                12: help_char = " ";
                13: help_char = "S";
                14: help_char = "E";
                15: help_char = "L";
                16: help_char = "E";
                17: help_char = "C";
                18: help_char = "T";
                19: help_char = " ";
                20: help_char = "E";
                21: help_char = "N";
                22: help_char = "T";
                23: help_char = "E";
                24: help_char = "R";
                25: help_char = " ";
                26: help_char = "S";
                27: help_char = "T";
                28: help_char = "A";
                29: help_char = "R";
                30: help_char = "T";
                31: help_char = " ";
                32: help_char = "E";
                33: help_char = "S";
                34: help_char = "C";
                35: help_char = " ";
                36: help_char = "B";
                37: help_char = "A";
                38: help_char = "C";
                39: help_char = "K";
                default: help_char = " ";
            endcase
        end
    endfunction

    function [4:0] glyph_row;
        input [7:0] ch;
        input [2:0] row;
        begin
            case (ch)
                "A": case (row)
                    0: glyph_row = 5'b01110;
                    1: glyph_row = 5'b10001;
                    2: glyph_row = 5'b10001;
                    3: glyph_row = 5'b11111;
                    4: glyph_row = 5'b10001;
                    5: glyph_row = 5'b10001;
                    6: glyph_row = 5'b10001;
                    default: glyph_row = 5'b00000;
                endcase
                "B": case (row)
                    0: glyph_row = 5'b11110;
                    1: glyph_row = 5'b10001;
                    2: glyph_row = 5'b10001;
                    3: glyph_row = 5'b11110;
                    4: glyph_row = 5'b10001;
                    5: glyph_row = 5'b10001;
                    6: glyph_row = 5'b11110;
                    default: glyph_row = 5'b00000;
                endcase
                "C": case (row)
                    0: glyph_row = 5'b01110;
                    1: glyph_row = 5'b10001;
                    2: glyph_row = 5'b10000;
                    3: glyph_row = 5'b10000;
                    4: glyph_row = 5'b10000;
                    5: glyph_row = 5'b10001;
                    6: glyph_row = 5'b01110;
                    default: glyph_row = 5'b00000;
                endcase
                "E": case (row)
                    0: glyph_row = 5'b11111;
                    1: glyph_row = 5'b10000;
                    2: glyph_row = 5'b10000;
                    3: glyph_row = 5'b11110;
                    4: glyph_row = 5'b10000;
                    5: glyph_row = 5'b10000;
                    6: glyph_row = 5'b11111;
                    default: glyph_row = 5'b00000;
                endcase
                "F": case (row)
                    0: glyph_row = 5'b11111;
                    1: glyph_row = 5'b10000;
                    2: glyph_row = 5'b10000;
                    3: glyph_row = 5'b11110;
                    4: glyph_row = 5'b10000;
                    5: glyph_row = 5'b10000;
                    6: glyph_row = 5'b10000;
                    default: glyph_row = 5'b00000;
                endcase
                "G": case (row)
                    0: glyph_row = 5'b01110;
                    1: glyph_row = 5'b10001;
                    2: glyph_row = 5'b10000;
                    3: glyph_row = 5'b10111;
                    4: glyph_row = 5'b10001;
                    5: glyph_row = 5'b10001;
                    6: glyph_row = 5'b01110;
                    default: glyph_row = 5'b00000;
                endcase
                "H": case (row)
                    0: glyph_row = 5'b10001;
                    1: glyph_row = 5'b10001;
                    2: glyph_row = 5'b10001;
                    3: glyph_row = 5'b11111;
                    4: glyph_row = 5'b10001;
                    5: glyph_row = 5'b10001;
                    6: glyph_row = 5'b10001;
                    default: glyph_row = 5'b00000;
                endcase
                "K": case (row)
                    0: glyph_row = 5'b10001;
                    1: glyph_row = 5'b10010;
                    2: glyph_row = 5'b10100;
                    3: glyph_row = 5'b11000;
                    4: glyph_row = 5'b10100;
                    5: glyph_row = 5'b10010;
                    6: glyph_row = 5'b10001;
                    default: glyph_row = 5'b00000;
                endcase
                "L": case (row)
                    0: glyph_row = 5'b10000;
                    1: glyph_row = 5'b10000;
                    2: glyph_row = 5'b10000;
                    3: glyph_row = 5'b10000;
                    4: glyph_row = 5'b10000;
                    5: glyph_row = 5'b10000;
                    6: glyph_row = 5'b11111;
                    default: glyph_row = 5'b00000;
                endcase
                "M": case (row)
                    0: glyph_row = 5'b10001;
                    1: glyph_row = 5'b11011;
                    2: glyph_row = 5'b10101;
                    3: glyph_row = 5'b10101;
                    4: glyph_row = 5'b10001;
                    5: glyph_row = 5'b10001;
                    6: glyph_row = 5'b10001;
                    default: glyph_row = 5'b00000;
                endcase
                "N": case (row)
                    0: glyph_row = 5'b10001;
                    1: glyph_row = 5'b11001;
                    2: glyph_row = 5'b10101;
                    3: glyph_row = 5'b10011;
                    4: glyph_row = 5'b10001;
                    5: glyph_row = 5'b10001;
                    6: glyph_row = 5'b10001;
                    default: glyph_row = 5'b00000;
                endcase
                "O": case (row)
                    0: glyph_row = 5'b01110;
                    1: glyph_row = 5'b10001;
                    2: glyph_row = 5'b10001;
                    3: glyph_row = 5'b10001;
                    4: glyph_row = 5'b10001;
                    5: glyph_row = 5'b10001;
                    6: glyph_row = 5'b01110;
                    default: glyph_row = 5'b00000;
                endcase
                "R": case (row)
                    0: glyph_row = 5'b11110;
                    1: glyph_row = 5'b10001;
                    2: glyph_row = 5'b10001;
                    3: glyph_row = 5'b11110;
                    4: glyph_row = 5'b10100;
                    5: glyph_row = 5'b10010;
                    6: glyph_row = 5'b10001;
                    default: glyph_row = 5'b00000;
                endcase
                "S": case (row)
                    0: glyph_row = 5'b01111;
                    1: glyph_row = 5'b10000;
                    2: glyph_row = 5'b10000;
                    3: glyph_row = 5'b01110;
                    4: glyph_row = 5'b00001;
                    5: glyph_row = 5'b00001;
                    6: glyph_row = 5'b11110;
                    default: glyph_row = 5'b00000;
                endcase
                "T": case (row)
                    0: glyph_row = 5'b11111;
                    1: glyph_row = 5'b00100;
                    2: glyph_row = 5'b00100;
                    3: glyph_row = 5'b00100;
                    4: glyph_row = 5'b00100;
                    5: glyph_row = 5'b00100;
                    6: glyph_row = 5'b00100;
                    default: glyph_row = 5'b00000;
                endcase
                "U": case (row)
                    0: glyph_row = 5'b10001;
                    1: glyph_row = 5'b10001;
                    2: glyph_row = 5'b10001;
                    3: glyph_row = 5'b10001;
                    4: glyph_row = 5'b10001;
                    5: glyph_row = 5'b10001;
                    6: glyph_row = 5'b01110;
                    default: glyph_row = 5'b00000;
                endcase
                "W": case (row)
                    0: glyph_row = 5'b10001;
                    1: glyph_row = 5'b10001;
                    2: glyph_row = 5'b10001;
                    3: glyph_row = 5'b10101;
                    4: glyph_row = 5'b10101;
                    5: glyph_row = 5'b11011;
                    6: glyph_row = 5'b10001;
                    default: glyph_row = 5'b00000;
                endcase
                default: glyph_row = 5'b00000;
            endcase
        end
    endfunction

    function glyph_pixel;
        input [7:0] ch;
        input integer x;
        input integer y;
        reg [4:0] row_bits;
        begin
            if ((x >= 0) && (x < 5) && (y >= 0) && (y < 7)) begin
                row_bits = glyph_row(ch, y[2:0]);
                glyph_pixel = row_bits[4 - x];
            end else begin
                glyph_pixel = 1'b0;
            end
        end
    endfunction

    function [9:0] mul30_4;
        input [3:0] value;
        begin
            mul30_4 = ({6'd0, value} << 5) - ({6'd0, value} << 1);
        end
    endfunction

    function [9:0] mul18_5;
        input [4:0] value;
        begin
            mul18_5 = ({5'd0, value} << 4) + ({5'd0, value} << 1);
        end
    endfunction

    function [9:0] mul12_6;
        input [5:0] value;
        begin
            mul12_6 = ({4'd0, value} << 3) + ({4'd0, value} << 2);
        end
    endfunction

    function [3:0] div30_u10;
        input [9:0] value;
        begin
            if (value < 10'd30) div30_u10 = 4'd0;
            else if (value < 10'd60) div30_u10 = 4'd1;
            else if (value < 10'd90) div30_u10 = 4'd2;
            else if (value < 10'd120) div30_u10 = 4'd3;
            else if (value < 10'd150) div30_u10 = 4'd4;
            else if (value < 10'd180) div30_u10 = 4'd5;
            else if (value < 10'd210) div30_u10 = 4'd6;
            else if (value < 10'd240) div30_u10 = 4'd7;
            else if (value < 10'd270) div30_u10 = 4'd8;
            else if (value < 10'd300) div30_u10 = 4'd9;
            else if (value < 10'd330) div30_u10 = 4'd10;
            else div30_u10 = 4'd11;
        end
    endfunction

    function [4:0] div18_u10;
        input [9:0] value;
        begin
            if (value < 10'd18) div18_u10 = 5'd0;
            else if (value < 10'd36) div18_u10 = 5'd1;
            else if (value < 10'd54) div18_u10 = 5'd2;
            else if (value < 10'd72) div18_u10 = 5'd3;
            else if (value < 10'd90) div18_u10 = 5'd4;
            else if (value < 10'd108) div18_u10 = 5'd5;
            else if (value < 10'd126) div18_u10 = 5'd6;
            else if (value < 10'd144) div18_u10 = 5'd7;
            else if (value < 10'd162) div18_u10 = 5'd8;
            else if (value < 10'd180) div18_u10 = 5'd9;
            else div18_u10 = 5'd10;
        end
    endfunction

    function [5:0] div12_u10;
        input [9:0] value;
        begin
            if (value < 10'd12) div12_u10 = 6'd0;
            else if (value < 10'd24) div12_u10 = 6'd1;
            else if (value < 10'd36) div12_u10 = 6'd2;
            else if (value < 10'd48) div12_u10 = 6'd3;
            else if (value < 10'd60) div12_u10 = 6'd4;
            else if (value < 10'd72) div12_u10 = 6'd5;
            else if (value < 10'd84) div12_u10 = 6'd6;
            else if (value < 10'd96) div12_u10 = 6'd7;
            else if (value < 10'd108) div12_u10 = 6'd8;
            else if (value < 10'd120) div12_u10 = 6'd9;
            else if (value < 10'd132) div12_u10 = 6'd10;
            else if (value < 10'd144) div12_u10 = 6'd11;
            else if (value < 10'd156) div12_u10 = 6'd12;
            else if (value < 10'd168) div12_u10 = 6'd13;
            else if (value < 10'd180) div12_u10 = 6'd14;
            else if (value < 10'd192) div12_u10 = 6'd15;
            else if (value < 10'd204) div12_u10 = 6'd16;
            else if (value < 10'd216) div12_u10 = 6'd17;
            else if (value < 10'd228) div12_u10 = 6'd18;
            else if (value < 10'd240) div12_u10 = 6'd19;
            else if (value < 10'd252) div12_u10 = 6'd20;
            else if (value < 10'd264) div12_u10 = 6'd21;
            else if (value < 10'd276) div12_u10 = 6'd22;
            else if (value < 10'd288) div12_u10 = 6'd23;
            else if (value < 10'd300) div12_u10 = 6'd24;
            else if (value < 10'd312) div12_u10 = 6'd25;
            else if (value < 10'd324) div12_u10 = 6'd26;
            else if (value < 10'd336) div12_u10 = 6'd27;
            else if (value < 10'd348) div12_u10 = 6'd28;
            else if (value < 10'd360) div12_u10 = 6'd29;
            else if (value < 10'd372) div12_u10 = 6'd30;
            else if (value < 10'd384) div12_u10 = 6'd31;
            else if (value < 10'd396) div12_u10 = 6'd32;
            else if (value < 10'd408) div12_u10 = 6'd33;
            else if (value < 10'd420) div12_u10 = 6'd34;
            else if (value < 10'd432) div12_u10 = 6'd35;
            else if (value < 10'd444) div12_u10 = 6'd36;
            else if (value < 10'd456) div12_u10 = 6'd37;
            else if (value < 10'd468) div12_u10 = 6'd38;
            else div12_u10 = 6'd39;
        end
    endfunction

    function [2:0] div5_u6;
        input [5:0] value;
        begin
            if (value < 6'd5) div5_u6 = 3'd0;
            else if (value < 6'd10) div5_u6 = 3'd1;
            else if (value < 6'd15) div5_u6 = 3'd2;
            else if (value < 6'd20) div5_u6 = 3'd3;
            else if (value < 6'd25) div5_u6 = 3'd4;
            else if (value < 6'd30) div5_u6 = 3'd5;
            else div5_u6 = 3'd6;
        end
    endfunction

    function [2:0] div3_u5;
        input [4:0] value;
        begin
            if (value < 5'd3) div3_u5 = 3'd0;
            else if (value < 5'd6) div3_u5 = 3'd1;
            else if (value < 5'd9) div3_u5 = 3'd2;
            else if (value < 5'd12) div3_u5 = 3'd3;
            else if (value < 5'd15) div3_u5 = 3'd4;
            else if (value < 5'd18) div3_u5 = 3'd5;
            else div3_u5 = 3'd6;
        end
    endfunction

    always @(*) begin
        title_on = 1'b0;
        item_text_on = 1'b0;
        help_on = 1'b0;
        selected_item = 1'b0;
        item_body = 1'b0;
        item_border = 1'b0;
        active_item = 3'd0;
        item_char_value = " ";
        item_y = ITEM_Y0;

        if (display_active) begin
            title_rel_x = pixel_x - TITLE_X;
            title_rel_y = pixel_y - TITLE_Y;
            if ((title_rel_x >= 0) && (title_rel_y >= 0) &&
                (title_rel_x < TITLE_COUNT * 6 * TITLE_SCALE) &&
                (title_rel_y < 7 * TITLE_SCALE)) begin
                title_char_idx = div30_u10(title_rel_x[9:0]);
                title_cell_x = div5_u6(title_rel_x[9:0] - mul30_4(title_char_idx[3:0]));
                title_cell_y = div5_u6(title_rel_y[5:0]);
                title_on = glyph_pixel(title_char(title_char_idx), title_cell_x, title_cell_y);
            end

            if ((pixel_x >= ITEM_X) && (pixel_x < ITEM_X + ITEM_W)) begin
                if ((pixel_y >= ITEM_Y0) && (pixel_y < ITEM_Y0 + ITEM_H)) begin
                    item_body = 1'b1;
                    active_item = 3'd0;
                    item_y = ITEM_Y0;
                end else if ((pixel_y >= ITEM_Y0 + ITEM_STEP) && (pixel_y < ITEM_Y0 + ITEM_STEP + ITEM_H)) begin
                    item_body = 1'b1;
                    active_item = 3'd1;
                    item_y = ITEM_Y0 + ITEM_STEP;
                end else if ((pixel_y >= ITEM_Y0 + (2 * ITEM_STEP)) && (pixel_y < ITEM_Y0 + (2 * ITEM_STEP) + ITEM_H)) begin
                    item_body = 1'b1;
                    active_item = 3'd2;
                    item_y = ITEM_Y0 + (2 * ITEM_STEP);
                end else if ((pixel_y >= ITEM_Y0 + (3 * ITEM_STEP)) && (pixel_y < ITEM_Y0 + (3 * ITEM_STEP) + ITEM_H)) begin
                    item_body = 1'b1;
                    active_item = 3'd3;
                    item_y = ITEM_Y0 + (3 * ITEM_STEP);
                end
            end

            if (item_body) begin
                selected_item = (cursor == active_item);
                item_border = (pixel_x < ITEM_X + 10'd4) ||
                              (pixel_x >= ITEM_X + ITEM_W - 10'd4) ||
                              (pixel_y < item_y + 10'd4) ||
                              (pixel_y >= item_y + ITEM_H - 10'd4);

                item_rel_x = pixel_x - ITEM_TEXT_X;
                item_rel_y = pixel_y - (item_y + ITEM_TEXT_OFFSET_Y);
                if ((item_rel_x >= 0) && (item_rel_y >= 0) &&
                    (item_rel_x < ITEM_COUNT * 6 * ITEM_SCALE) &&
                    (item_rel_y < 7 * ITEM_SCALE)) begin
                    item_char_idx = div18_u10(item_rel_x[9:0]);
                    item_cell_x = div3_u5(item_rel_x[9:0] - mul18_5(item_char_idx[4:0]));
                    item_cell_y = div3_u5(item_rel_y[4:0]);
                    item_char_value = item_char(active_item, item_char_idx);
                    item_text_on = glyph_pixel(item_char_value, item_cell_x, item_cell_y);
                end
            end

            help_rel_x = pixel_x - HELP_X;
            help_rel_y = pixel_y - HELP_Y;
            if ((help_rel_x >= 0) && (help_rel_y >= 0) &&
                (help_rel_x < HELP_COUNT * 6 * HELP_SCALE) &&
                (help_rel_y < 7 * HELP_SCALE)) begin
                help_char_idx = div12_u10(help_rel_x[9:0]);
                help_cell_x = (help_rel_x[9:0] - mul12_6(help_char_idx[5:0])) >> 1;
                help_cell_y = help_rel_y[3:1];
                help_on = glyph_pixel(help_char(help_char_idx), help_cell_x, help_cell_y);
            end
        end

        if (!display_active) begin
            vga_r = 4'h0;
            vga_g = 4'h0;
            vga_b = 4'h0;
        end else begin
            vga_r = {2'b00, pixel_y[8:7]};
            vga_g = {1'b0, pixel_x[8:6]};
            vga_b = 4'h4;

            if (((pixel_x[5:0] == 6'd0) || (pixel_y[5:0] == 6'd0))) begin
                vga_r = vga_r >> 1;
                vga_g = vga_g >> 1;
                vga_b = vga_b >> 1;
            end

            if (title_on) begin
                vga_r = 4'hF;
                vga_g = 4'hD;
                vga_b = 4'h8;
            end else if (help_on) begin
                vga_r = 4'hD;
                vga_g = 4'hE;
                vga_b = 4'hF;
            end else if (item_text_on) begin
                if (selected_item) begin
                    vga_r = 4'h0;
                    vga_g = 4'h1;
                    vga_b = 4'h2;
                end else begin
                    vga_r = 4'hE;
                    vga_g = 4'hF;
                    vga_b = 4'hF;
                end
            end else if (item_body) begin
                if (selected_item) begin
                    if (item_border || blink_counter[4]) begin
                        vga_r = 4'hF;
                        vga_g = 4'hB;
                        vga_b = 4'h2;
                    end else begin
                        vga_r = 4'hC;
                        vga_g = 4'h8;
                        vga_b = 4'h1;
                    end
                end else if (item_border) begin
                    vga_r = 4'h4;
                    vga_g = 4'h7;
                    vga_b = 4'hA;
                end else begin
                    vga_r = 4'h1 + active_item;
                    vga_g = 4'h2;
                    vga_b = 4'h4;
                end
            end
        end
    end

endmodule
