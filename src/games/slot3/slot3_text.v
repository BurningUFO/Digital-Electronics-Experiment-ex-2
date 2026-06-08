module slot3_text (
    input  wire [9:0]  pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire [4:0]  msg_id,
    input  wire [9:0]  origin_x,
    input  wire [9:0]  origin_y,
    input  wire [1:0]  scale,
    output wire        hit
);

    wire [9:0] lx = pixel_x - origin_x;
    wire [9:0] ly = pixel_y - origin_y;

    wire [6:0] col = (scale == 2'd2) ? lx[9:3] :
                     (scale == 2'd1) ? lx[9:2] : lx[9:1];
    wire [4:0] row = (scale == 2'd2) ? ly[9:3] :
                     (scale == 2'd1) ? ly[9:2] : ly[9:1];

    (* rom_style = "distributed" *) reg [6:0] div6_rom [0:127];
    integer div_i;
    reg [3:0] div_q;
    reg [2:0] div_r;
    initial begin
        div_q = 4'd0;
        div_r = 3'd0;
        for (div_i = 0; div_i < 128; div_i = div_i + 1) begin
            div6_rom[div_i] = {div_q, div_r};
            if (div_r == 3'd5) begin
                div_r = 3'd0;
                div_q = div_q + 4'd1;
            end else begin
                div_r = div_r + 3'd1;
            end
        end
    end

    wire [4:0] char_idx;
    wire [6:0] div6_lookup = div6_rom[col];
    wire [2:0] cx = div6_lookup[2:0];
    wire [3:0] char_pos = div6_lookup[6:3];

    wire in_bounds = (pixel_x >= origin_x) && (pixel_y >= origin_y) && (row < 5'd7);

    slot3_msg_lut u_msg_lut (
        .msg_id(msg_id),
        .char_pos(char_pos),
        .char_idx(char_idx)
    );

    wire [4:0] font_bits;
    slot3_font_rom u_font (
        .char_idx(char_idx),
        .row(row[2:0]),
        .bits(font_bits)
    );

    assign hit = in_bounds && (cx < 3'd5) && font_bits[3'd4 - cx[2:0]] && (char_idx != 5'd31);

endmodule


module slot3_msg_lut (
    input  wire [4:0] msg_id,
    input  wire [3:0] char_pos,
    output reg  [4:0] char_idx
);
    // A=0 B=1 C=2 D=3 E=4 F=5 G=6 H=7 I=8 J=9 K=10 L=11 M=12
    // N=13 O=14 P=15 Q=16 R=17 S=18 T=19 U=20 V=21 W=22 X=23 Y=24 Z=25
    // 0=26 1=27 2=28 3=29 4=30 5=31(unused as space)
    // space = 31

    always @(*) begin
        char_idx = 5'd31;
        case (msg_id)
            5'd0: // "MATRIX"
                case (char_pos)
                    4'd0: char_idx = 5'd12; // M
                    4'd1: char_idx = 5'd0;  // A
                    4'd2: char_idx = 5'd19; // T
                    4'd3: char_idx = 5'd17; // R
                    4'd4: char_idx = 5'd8;  // I
                    4'd5: char_idx = 5'd23; // X
                    default: char_idx = 5'd31;
                endcase
            5'd1: // "START"
                case (char_pos)
                    4'd0: char_idx = 5'd18; // S
                    4'd1: char_idx = 5'd19; // T
                    4'd2: char_idx = 5'd0;  // A
                    4'd3: char_idx = 5'd17; // R
                    4'd4: char_idx = 5'd19; // T
                    default: char_idx = 5'd31;
                endcase
            5'd2: // "LEVEL"
                case (char_pos)
                    4'd0: char_idx = 5'd11; // L
                    4'd1: char_idx = 5'd4;  // E
                    4'd2: char_idx = 5'd21; // V
                    4'd3: char_idx = 5'd4;  // E
                    4'd4: char_idx = 5'd11; // L
                    default: char_idx = 5'd31;
                endcase
            5'd3: // "EXIT"
                case (char_pos)
                    4'd0: char_idx = 5'd4;  // E
                    4'd1: char_idx = 5'd23; // X
                    4'd2: char_idx = 5'd8;  // I
                    4'd3: char_idx = 5'd19; // T
                    default: char_idx = 5'd31;
                endcase
            5'd4: // "WIN"
                case (char_pos)
                    4'd0: char_idx = 5'd22; // W
                    4'd1: char_idx = 5'd8;  // I
                    4'd2: char_idx = 5'd13; // N
                    default: char_idx = 5'd31;
                endcase
            5'd5: // "LOSE"
                case (char_pos)
                    4'd0: char_idx = 5'd11; // L
                    4'd1: char_idx = 5'd14; // O
                    4'd2: char_idx = 5'd18; // S
                    4'd3: char_idx = 5'd4;  // E
                    default: char_idx = 5'd31;
                endcase
            5'd6: // "FIND"
                case (char_pos)
                    4'd0: char_idx = 5'd5;  // F
                    4'd1: char_idx = 5'd8;  // I
                    4'd2: char_idx = 5'd13; // N
                    4'd3: char_idx = 5'd3;  // D
                    default: char_idx = 5'd31;
                endcase
            5'd7: // "HACK"
                case (char_pos)
                    4'd0: char_idx = 5'd7;  // H
                    4'd1: char_idx = 5'd0;  // A
                    4'd2: char_idx = 5'd2;  // C
                    4'd3: char_idx = 5'd10; // K
                    default: char_idx = 5'd31;
                endcase
            5'd8: // "RESCUE"
                case (char_pos)
                    4'd0: char_idx = 5'd17; // R
                    4'd1: char_idx = 5'd4;  // E
                    4'd2: char_idx = 5'd18; // S
                    4'd3: char_idx = 5'd2;  // C
                    4'd4: char_idx = 5'd20; // U
                    4'd5: char_idx = 5'd4;  // E
                    default: char_idx = 5'd31;
                endcase
            5'd9: // "PHONE"
                case (char_pos)
                    4'd0: char_idx = 5'd15; // P
                    4'd1: char_idx = 5'd7;  // H
                    4'd2: char_idx = 5'd14; // O
                    4'd3: char_idx = 5'd13; // N
                    4'd4: char_idx = 5'd4;  // E
                    default: char_idx = 5'd31;
                endcase
            5'd10: // "RED"
                case (char_pos)
                    4'd0: char_idx = 5'd17; // R
                    4'd1: char_idx = 5'd4;  // E
                    4'd2: char_idx = 5'd3;  // D
                    default: char_idx = 5'd31;
                endcase
            5'd11: // "BLUE"
                case (char_pos)
                    4'd0: char_idx = 5'd1;  // B
                    4'd1: char_idx = 5'd11; // L
                    4'd2: char_idx = 5'd20; // U
                    4'd3: char_idx = 5'd4;  // E
                    default: char_idx = 5'd31;
                endcase
            5'd12: // "OVER"
                case (char_pos)
                    4'd0: char_idx = 5'd14; // O
                    4'd1: char_idx = 5'd21; // V
                    4'd2: char_idx = 5'd4;  // E
                    4'd3: char_idx = 5'd17; // R
                    default: char_idx = 5'd31;
                endcase
            5'd13: // "GAME"
                case (char_pos)
                    4'd0: char_idx = 5'd6;  // G
                    4'd1: char_idx = 5'd0;  // A
                    4'd2: char_idx = 5'd12; // M
                    4'd3: char_idx = 5'd4;  // E
                    default: char_idx = 5'd31;
                endcase
            5'd14: // "PILL"
                case (char_pos)
                    4'd0: char_idx = 5'd15; // P
                    4'd1: char_idx = 5'd8;  // I
                    4'd2: char_idx = 5'd11; // L
                    4'd3: char_idx = 5'd11; // L
                    default: char_idx = 5'd31;
                endcase
            5'd15: // "AMMO"
                case (char_pos)
                    4'd0: char_idx = 5'd0;  // A
                    4'd1: char_idx = 5'd12; // M
                    4'd2: char_idx = 5'd12; // M
                    4'd3: char_idx = 5'd14; // O
                    default: char_idx = 5'd31;
                endcase
            5'd16: // "CHARGE"
                case (char_pos)
                    4'd0: char_idx = 5'd2;  // C
                    4'd1: char_idx = 5'd7;  // H
                    4'd2: char_idx = 5'd0;  // A
                    4'd3: char_idx = 5'd17; // R
                    4'd4: char_idx = 5'd6;  // G
                    4'd5: char_idx = 5'd4;  // E
                    default: char_idx = 5'd31;
                endcase
            5'd17: // "EMP"
                case (char_pos)
                    4'd0: char_idx = 5'd4;  // E
                    4'd1: char_idx = 5'd12; // M
                    4'd2: char_idx = 5'd15; // P
                    default: char_idx = 5'd31;
                endcase
            5'd18: // "RESCUE"
                case (char_pos)
                    4'd0: char_idx = 5'd17; // R
                    4'd1: char_idx = 5'd4;  // E
                    4'd2: char_idx = 5'd18; // S
                    4'd3: char_idx = 5'd2;  // C
                    4'd4: char_idx = 5'd20; // U
                    4'd5: char_idx = 5'd4;  // E
                    default: char_idx = 5'd31;
                endcase
            5'd19: // "GOAL"
                case (char_pos)
                    4'd0: char_idx = 5'd6;  // G
                    4'd1: char_idx = 5'd14; // O
                    4'd2: char_idx = 5'd0;  // A
                    4'd3: char_idx = 5'd11; // L
                    default: char_idx = 5'd31;
                endcase
            5'd20: // "BOMB"
                case (char_pos)
                    4'd0: char_idx = 5'd1;  // B
                    4'd1: char_idx = 5'd14; // O
                    4'd2: char_idx = 5'd12; // M
                    4'd3: char_idx = 5'd1;  // B
                    default: char_idx = 5'd31;
                endcase
            default: char_idx = 5'd31;
        endcase
    end

endmodule


module slot3_font_rom (
    input  wire [4:0] char_idx,
    input  wire [2:0] row,
    output reg  [4:0] bits
);

    always @(*) begin
        bits = 5'b00000;
        case (char_idx)
            5'd0: // A
                case (row)
                    3'd0: bits = 5'b01110;
                    3'd1: bits = 5'b10001;
                    3'd2: bits = 5'b10001;
                    3'd3: bits = 5'b11111;
                    3'd4: bits = 5'b10001;
                    3'd5: bits = 5'b10001;
                    3'd6: bits = 5'b10001;
                    default: bits = 5'b00000;
                endcase
            5'd1: // B
                case (row)
                    3'd0: bits = 5'b11110;
                    3'd1: bits = 5'b10001;
                    3'd2: bits = 5'b10001;
                    3'd3: bits = 5'b11110;
                    3'd4: bits = 5'b10001;
                    3'd5: bits = 5'b10001;
                    3'd6: bits = 5'b11110;
                    default: bits = 5'b00000;
                endcase
            5'd2: // C
                case (row)
                    3'd0: bits = 5'b01110;
                    3'd1: bits = 5'b10001;
                    3'd2: bits = 5'b10000;
                    3'd3: bits = 5'b10000;
                    3'd4: bits = 5'b10000;
                    3'd5: bits = 5'b10001;
                    3'd6: bits = 5'b01110;
                    default: bits = 5'b00000;
                endcase
            5'd3: // D
                case (row)
                    3'd0: bits = 5'b11100;
                    3'd1: bits = 5'b10010;
                    3'd2: bits = 5'b10001;
                    3'd3: bits = 5'b10001;
                    3'd4: bits = 5'b10001;
                    3'd5: bits = 5'b10010;
                    3'd6: bits = 5'b11100;
                    default: bits = 5'b00000;
                endcase
            5'd4: // E
                case (row)
                    3'd0: bits = 5'b11111;
                    3'd1: bits = 5'b10000;
                    3'd2: bits = 5'b10000;
                    3'd3: bits = 5'b11110;
                    3'd4: bits = 5'b10000;
                    3'd5: bits = 5'b10000;
                    3'd6: bits = 5'b11111;
                    default: bits = 5'b00000;
                endcase
            5'd5: // F
                case (row)
                    3'd0: bits = 5'b11111;
                    3'd1: bits = 5'b10000;
                    3'd2: bits = 5'b10000;
                    3'd3: bits = 5'b11110;
                    3'd4: bits = 5'b10000;
                    3'd5: bits = 5'b10000;
                    3'd6: bits = 5'b10000;
                    default: bits = 5'b00000;
                endcase
            5'd6: // G
                case (row)
                    3'd0: bits = 5'b01110;
                    3'd1: bits = 5'b10001;
                    3'd2: bits = 5'b10000;
                    3'd3: bits = 5'b10111;
                    3'd4: bits = 5'b10001;
                    3'd5: bits = 5'b10001;
                    3'd6: bits = 5'b01110;
                    default: bits = 5'b00000;
                endcase
            5'd7: // H
                case (row)
                    3'd0: bits = 5'b10001;
                    3'd1: bits = 5'b10001;
                    3'd2: bits = 5'b10001;
                    3'd3: bits = 5'b11111;
                    3'd4: bits = 5'b10001;
                    3'd5: bits = 5'b10001;
                    3'd6: bits = 5'b10001;
                    default: bits = 5'b00000;
                endcase
            5'd8: // I
                case (row)
                    3'd0: bits = 5'b11111;
                    3'd1: bits = 5'b00100;
                    3'd2: bits = 5'b00100;
                    3'd3: bits = 5'b00100;
                    3'd4: bits = 5'b00100;
                    3'd5: bits = 5'b00100;
                    3'd6: bits = 5'b11111;
                    default: bits = 5'b00000;
                endcase
            5'd9: // J
                case (row)
                    3'd0: bits = 5'b00111;
                    3'd1: bits = 5'b00010;
                    3'd2: bits = 5'b00010;
                    3'd3: bits = 5'b00010;
                    3'd4: bits = 5'b10010;
                    3'd5: bits = 5'b10010;
                    3'd6: bits = 5'b01100;
                    default: bits = 5'b00000;
                endcase
            5'd10: // K
                case (row)
                    3'd0: bits = 5'b10001;
                    3'd1: bits = 5'b10010;
                    3'd2: bits = 5'b10100;
                    3'd3: bits = 5'b11000;
                    3'd4: bits = 5'b10100;
                    3'd5: bits = 5'b10010;
                    3'd6: bits = 5'b10001;
                    default: bits = 5'b00000;
                endcase
            5'd11: // L
                case (row)
                    3'd0: bits = 5'b10000;
                    3'd1: bits = 5'b10000;
                    3'd2: bits = 5'b10000;
                    3'd3: bits = 5'b10000;
                    3'd4: bits = 5'b10000;
                    3'd5: bits = 5'b10000;
                    3'd6: bits = 5'b11111;
                    default: bits = 5'b00000;
                endcase
            5'd12: // M
                case (row)
                    3'd0: bits = 5'b10001;
                    3'd1: bits = 5'b11011;
                    3'd2: bits = 5'b10101;
                    3'd3: bits = 5'b10101;
                    3'd4: bits = 5'b10001;
                    3'd5: bits = 5'b10001;
                    3'd6: bits = 5'b10001;
                    default: bits = 5'b00000;
                endcase
            5'd13: // N
                case (row)
                    3'd0: bits = 5'b10001;
                    3'd1: bits = 5'b11001;
                    3'd2: bits = 5'b10101;
                    3'd3: bits = 5'b10011;
                    3'd4: bits = 5'b10001;
                    3'd5: bits = 5'b10001;
                    3'd6: bits = 5'b10001;
                    default: bits = 5'b00000;
                endcase
            5'd14: // O
                case (row)
                    3'd0: bits = 5'b01110;
                    3'd1: bits = 5'b10001;
                    3'd2: bits = 5'b10001;
                    3'd3: bits = 5'b10001;
                    3'd4: bits = 5'b10001;
                    3'd5: bits = 5'b10001;
                    3'd6: bits = 5'b01110;
                    default: bits = 5'b00000;
                endcase
            5'd15: // P
                case (row)
                    3'd0: bits = 5'b11110;
                    3'd1: bits = 5'b10001;
                    3'd2: bits = 5'b10001;
                    3'd3: bits = 5'b11110;
                    3'd4: bits = 5'b10000;
                    3'd5: bits = 5'b10000;
                    3'd6: bits = 5'b10000;
                    default: bits = 5'b00000;
                endcase
            5'd16: // Q
                case (row)
                    3'd0: bits = 5'b01110;
                    3'd1: bits = 5'b10001;
                    3'd2: bits = 5'b10001;
                    3'd3: bits = 5'b10001;
                    3'd4: bits = 5'b10101;
                    3'd5: bits = 5'b10010;
                    3'd6: bits = 5'b01101;
                    default: bits = 5'b00000;
                endcase
            5'd17: // R
                case (row)
                    3'd0: bits = 5'b11110;
                    3'd1: bits = 5'b10001;
                    3'd2: bits = 5'b10001;
                    3'd3: bits = 5'b11110;
                    3'd4: bits = 5'b10100;
                    3'd5: bits = 5'b10010;
                    3'd6: bits = 5'b10001;
                    default: bits = 5'b00000;
                endcase
            5'd18: // S
                case (row)
                    3'd0: bits = 5'b01110;
                    3'd1: bits = 5'b10001;
                    3'd2: bits = 5'b10000;
                    3'd3: bits = 5'b01110;
                    3'd4: bits = 5'b00001;
                    3'd5: bits = 5'b10001;
                    3'd6: bits = 5'b01110;
                    default: bits = 5'b00000;
                endcase
            5'd19: // T
                case (row)
                    3'd0: bits = 5'b11111;
                    3'd1: bits = 5'b00100;
                    3'd2: bits = 5'b00100;
                    3'd3: bits = 5'b00100;
                    3'd4: bits = 5'b00100;
                    3'd5: bits = 5'b00100;
                    3'd6: bits = 5'b00100;
                    default: bits = 5'b00000;
                endcase
            5'd20: // U
                case (row)
                    3'd0: bits = 5'b10001;
                    3'd1: bits = 5'b10001;
                    3'd2: bits = 5'b10001;
                    3'd3: bits = 5'b10001;
                    3'd4: bits = 5'b10001;
                    3'd5: bits = 5'b10001;
                    3'd6: bits = 5'b01110;
                    default: bits = 5'b00000;
                endcase
            5'd21: // V
                case (row)
                    3'd0: bits = 5'b10001;
                    3'd1: bits = 5'b10001;
                    3'd2: bits = 5'b10001;
                    3'd3: bits = 5'b10001;
                    3'd4: bits = 5'b10001;
                    3'd5: bits = 5'b01010;
                    3'd6: bits = 5'b00100;
                    default: bits = 5'b00000;
                endcase
            5'd22: // W
                case (row)
                    3'd0: bits = 5'b10001;
                    3'd1: bits = 5'b10001;
                    3'd2: bits = 5'b10001;
                    3'd3: bits = 5'b10101;
                    3'd4: bits = 5'b10101;
                    3'd5: bits = 5'b11011;
                    3'd6: bits = 5'b10001;
                    default: bits = 5'b00000;
                endcase
            5'd23: // X
                case (row)
                    3'd0: bits = 5'b10001;
                    3'd1: bits = 5'b01010;
                    3'd2: bits = 5'b00100;
                    3'd3: bits = 5'b00100;
                    3'd4: bits = 5'b00100;
                    3'd5: bits = 5'b01010;
                    3'd6: bits = 5'b10001;
                    default: bits = 5'b00000;
                endcase
            5'd24: // Y
                case (row)
                    3'd0: bits = 5'b10001;
                    3'd1: bits = 5'b10001;
                    3'd2: bits = 5'b01010;
                    3'd3: bits = 5'b00100;
                    3'd4: bits = 5'b00100;
                    3'd5: bits = 5'b00100;
                    3'd6: bits = 5'b00100;
                    default: bits = 5'b00000;
                endcase
            5'd25: // Z
                case (row)
                    3'd0: bits = 5'b11111;
                    3'd1: bits = 5'b00001;
                    3'd2: bits = 5'b00010;
                    3'd3: bits = 5'b00100;
                    3'd4: bits = 5'b01000;
                    3'd5: bits = 5'b10000;
                    3'd6: bits = 5'b11111;
                    default: bits = 5'b00000;
                endcase
            5'd26: // 0
                case (row)
                    3'd0: bits = 5'b01110;
                    3'd1: bits = 5'b10001;
                    3'd2: bits = 5'b10011;
                    3'd3: bits = 5'b10101;
                    3'd4: bits = 5'b11001;
                    3'd5: bits = 5'b10001;
                    3'd6: bits = 5'b01110;
                    default: bits = 5'b00000;
                endcase
            5'd27: // 1
                case (row)
                    3'd0: bits = 5'b00100;
                    3'd1: bits = 5'b01100;
                    3'd2: bits = 5'b00100;
                    3'd3: bits = 5'b00100;
                    3'd4: bits = 5'b00100;
                    3'd5: bits = 5'b00100;
                    3'd6: bits = 5'b01110;
                    default: bits = 5'b00000;
                endcase
            5'd28: // 2
                case (row)
                    3'd0: bits = 5'b01110;
                    3'd1: bits = 5'b10001;
                    3'd2: bits = 5'b00001;
                    3'd3: bits = 5'b00110;
                    3'd4: bits = 5'b01000;
                    3'd5: bits = 5'b10000;
                    3'd6: bits = 5'b11111;
                    default: bits = 5'b00000;
                endcase
            5'd29: // 3
                case (row)
                    3'd0: bits = 5'b01110;
                    3'd1: bits = 5'b10001;
                    3'd2: bits = 5'b00001;
                    3'd3: bits = 5'b00110;
                    3'd4: bits = 5'b00001;
                    3'd5: bits = 5'b10001;
                    3'd6: bits = 5'b01110;
                    default: bits = 5'b00000;
                endcase
            5'd30: // 4
                case (row)
                    3'd0: bits = 5'b00010;
                    3'd1: bits = 5'b00110;
                    3'd2: bits = 5'b01010;
                    3'd3: bits = 5'b10010;
                    3'd4: bits = 5'b11111;
                    3'd5: bits = 5'b00010;
                    3'd6: bits = 5'b00010;
                    default: bits = 5'b00000;
                endcase
            default: bits = 5'b00000;
        endcase
    end

endmodule
