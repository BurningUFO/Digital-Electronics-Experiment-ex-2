module game_slot4_top (
    input  wire        clk,
    input  wire        reset,
    input  wire        selected,
    input  wire        frame_tick,
    input  wire        pixel_tick,
    input  wire        display_active,
    input  wire [9:0]  pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire        btn_u,
    input  wire        btn_d,
    input  wire        btn_l,
    input  wire        btn_r,
    input  wire        btn_c,
    input  wire [15:0] sw,
    input  wire        ps2_clk,
    input  wire        ps2_data,
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b,
    output wire [15:0] led,
    output wire [7:0]  an,
    output wire        ca,
    output wire        cb,
    output wire        cc,
    output wire        cd,
    output wire        ce,
    output wire        cf,
    output wire        cg,
    output wire        dp,
    output wire        buzzer
);

    localparam integer CELL = 20;
    localparam integer SCREEN_W = 640;
    localparam integer SCREEN_H = 480;
    localparam integer PLAYER_W = 14;
    localparam integer PLAYER_H = 18;
    localparam signed [5:0] GRAVITY = 6'sd1;
    localparam signed [5:0] MAX_FALL = 6'sd8;
    localparam signed [5:0] JUMP_VEL = -6'sd12;
    localparam integer MOVE_STEP = 3;

    localparam [3:0] TILE_EMPTY      = 4'd0;
    localparam [3:0] TILE_WALL       = 4'd1;
    localparam [3:0] TILE_FIRE       = 4'd2;
    localparam [3:0] TILE_WATER      = 4'd3;
    localparam [3:0] TILE_POISON     = 4'd4;
    localparam [3:0] TILE_FIRE_GEM   = 4'd5;
    localparam [3:0] TILE_WATER_GEM  = 4'd6;
    localparam [3:0] TILE_FIRE_DOOR  = 4'd7;
    localparam [3:0] TILE_WATER_DOOR = 4'd8;
    localparam [3:0] TILE_BUTTON     = 4'd9;
    localparam [3:0] TILE_GATE       = 4'd10;

    wire ps2_byte_ready;
    wire [7:0] ps2_byte_data;
    wire fire_left_key;
    wire fire_right_key;
    wire fire_jump_key;
    wire water_left_key;
    wire water_right_key;
    wire water_jump_key;

    reg [1:0] level;
    reg won;
    reg [9:0] fire_x;
    reg [9:0] fire_y;
    reg [9:0] water_x;
    reg [9:0] water_y;
    reg signed [5:0] fire_vy;
    reg signed [5:0] water_vy;
    reg [3:0] fire_gems;
    reg [3:0] water_gems;
    reg [1:0] button_mask;
    reg [23:0] frame_counter;

    reg [4:0] cell_x;
    reg [4:0] cell_y;
    reg [4:0] local_x;
    reg [4:0] local_y;
    reg [3:0] draw_tile;
    reg [6:0] seg_n;

    reg signed [5:0] fire_vy_calc;
    reg signed [5:0] water_vy_calc;
    reg signed [11:0] fire_y_calc;
    reg signed [11:0] water_y_calc;
    reg [9:0] fire_x_calc;
    reg [9:0] water_x_calc;
    reg [1:0] next_level;

    wire gate_open;
    wire fire_grounded;
    wire water_grounded;
    wire fire_left_cmd;
    wire fire_right_cmd;
    wire fire_jump_cmd;
    wire water_left_cmd;
    wire water_right_cmd;
    wire water_jump_cmd;
    wire fire_pixel;
    wire water_pixel;
    wire fire_eye;
    wire water_eye;
    wire fire_all_gems;
    wire water_all_gems;
    wire level_complete;
    wire level_failed;
    wire unused_inputs;

    assign unused_inputs = pixel_tick | btn_d | (|sw[15:3]);

    assign gate_open = (level == 2'd0) ? 1'b1 :
                       (level == 2'd1) ? button_mask[0] :
                                         (button_mask[0] & button_mask[1]);

    assign fire_grounded = slot4_player_solid(level, fire_x, fire_y + 10'd1, gate_open);
    assign water_grounded = slot4_player_solid(level, water_x, water_y + 10'd1, gate_open);

    assign fire_left_cmd = fire_left_key | btn_l;
    assign fire_right_cmd = fire_right_key | btn_r;
    assign fire_jump_cmd = fire_jump_key | btn_u;
    assign water_left_cmd = water_left_key | sw[0];
    assign water_right_cmd = water_right_key | sw[1];
    assign water_jump_cmd = water_jump_key | sw[2];

    assign fire_all_gems = (fire_gems[1:0] == 2'b11);
    assign water_all_gems = (water_gems[1:0] == 2'b11);
    assign level_complete = fire_all_gems && water_all_gems &&
                            slot4_player_touch_tile(level, fire_x, fire_y, TILE_FIRE_DOOR) &&
                            slot4_player_touch_tile(level, water_x, water_y, TILE_WATER_DOOR);

    assign level_failed = slot4_fire_bad(level, fire_x, fire_y) ||
                          slot4_water_bad(level, water_x, water_y);

    assign fire_pixel = selected && display_active && !won &&
                        (pixel_x >= fire_x) && (pixel_x < fire_x + PLAYER_W) &&
                        (pixel_y >= fire_y) && (pixel_y < fire_y + PLAYER_H);

    assign water_pixel = selected && display_active && !won &&
                         (pixel_x >= water_x) && (pixel_x < water_x + PLAYER_W) &&
                         (pixel_y >= water_y) && (pixel_y < water_y + PLAYER_H);

    assign fire_eye = fire_pixel &&
                      (pixel_x >= fire_x + 10'd9) && (pixel_x <= fire_x + 10'd11) &&
                      (pixel_y >= fire_y + 10'd5) && (pixel_y <= fire_y + 10'd7);

    assign water_eye = water_pixel &&
                       (pixel_x >= water_x + 10'd2) && (pixel_x <= water_x + 10'd4) &&
                       (pixel_y >= water_y + 10'd5) && (pixel_y <= water_y + 10'd7);

    slot4_ps2_rx u_slot4_ps2_rx (
        .clk(clk),
        .reset(reset | ~selected),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .byte_ready(ps2_byte_ready),
        .byte_data(ps2_byte_data)
    );

    slot4_keyboard_mapper u_slot4_keyboard_mapper (
        .clk(clk),
        .reset(reset | ~selected),
        .byte_ready(ps2_byte_ready),
        .byte_data(ps2_byte_data),
        .fire_left(fire_left_key),
        .fire_right(fire_right_key),
        .fire_jump(fire_jump_key),
        .water_left(water_left_key),
        .water_right(water_right_key),
        .water_jump(water_jump_key)
    );

    function [9:0] slot4_fire_start_x;
        input [1:0] lvl;
        begin
            case (lvl)
                2'd0: slot4_fire_start_x = 10'd43;
                2'd1: slot4_fire_start_x = 10'd43;
                default: slot4_fire_start_x = 10'd43;
            endcase
        end
    endfunction

    function [9:0] slot4_fire_start_y;
        input [1:0] lvl;
        begin
            case (lvl)
                2'd0: slot4_fire_start_y = 10'd122;
                2'd1: slot4_fire_start_y = 10'd122;
                default: slot4_fire_start_y = 10'd122;
            endcase
        end
    endfunction

    function [9:0] slot4_water_start_x;
        input [1:0] lvl;
        begin
            case (lvl)
                2'd0: slot4_water_start_x = 10'd543;
                2'd1: slot4_water_start_x = 10'd543;
                default: slot4_water_start_x = 10'd543;
            endcase
        end
    endfunction

    function [9:0] slot4_water_start_y;
        input [1:0] lvl;
        begin
            case (lvl)
                2'd0: slot4_water_start_y = 10'd122;
                2'd1: slot4_water_start_y = 10'd122;
                default: slot4_water_start_y = 10'd122;
            endcase
        end
    endfunction

    function [3:0] slot4_tile_raw;
        input [1:0] lvl;
        input [4:0] tx;
        input [4:0] ty;
        begin
            slot4_tile_raw = TILE_EMPTY;

            if ((tx == 5'd0) || (tx == 5'd31) || (ty == 5'd0) || (ty == 5'd23)) begin
                slot4_tile_raw = TILE_WALL;
            end else begin
                case (lvl)
                    2'd0: begin
                        if ((tx == 5'd14) && (ty == 5'd1))
                            slot4_tile_raw = TILE_FIRE_DOOR;
                        else if ((tx == 5'd16) && (ty == 5'd1))
                            slot4_tile_raw = TILE_WATER_DOOR;
                        else if (((tx == 5'd9) && (ty == 5'd3)) ||
                                 ((tx == 5'd11) && (ty == 5'd12)))
                            slot4_tile_raw = TILE_FIRE_GEM;
                        else if (((tx == 5'd22) && (ty == 5'd3)) ||
                                 ((tx == 5'd20) && (ty == 5'd12)))
                            slot4_tile_raw = TILE_WATER_GEM;
                        else if ((ty == 5'd4) && (((tx >= 5'd6) && (tx <= 5'd12)) ||
                                                   ((tx >= 5'd19) && (tx <= 5'd25))))
                            slot4_tile_raw = TILE_WALL;
                        else if ((ty == 5'd7) && (((tx >= 5'd2) && (tx <= 5'd6)) ||
                                                   ((tx >= 5'd25) && (tx <= 5'd29))))
                            slot4_tile_raw = TILE_WALL;
                        else if ((ty == 5'd9) && (tx >= 5'd8) && (tx <= 5'd11))
                            slot4_tile_raw = TILE_FIRE;
                        else if ((ty == 5'd9) && (tx >= 5'd20) && (tx <= 5'd23))
                            slot4_tile_raw = TILE_WATER;
                        else if ((ty == 5'd10) && (((tx >= 5'd6) && (tx <= 5'd13)) ||
                                                    ((tx >= 5'd18) && (tx <= 5'd25))))
                            slot4_tile_raw = TILE_WALL;
                        else if ((ty == 5'd13) && (((tx >= 5'd4) && (tx <= 5'd9)) ||
                                                    ((tx >= 5'd22) && (tx <= 5'd27))))
                            slot4_tile_raw = TILE_WALL;
                        else if ((ty == 5'd15) && (tx >= 5'd14) && (tx <= 5'd15))
                            slot4_tile_raw = TILE_POISON;
                        else if ((ty == 5'd16) && (tx >= 5'd12) && (tx <= 5'd19))
                            slot4_tile_raw = TILE_WALL;
                        else if ((ty == 5'd18) && (((tx >= 5'd4) && (tx <= 5'd7)) ||
                                                    ((tx >= 5'd24) && (tx <= 5'd27))))
                            slot4_tile_raw = TILE_WALL;
                    end
                    2'd1: begin
                        if ((tx == 5'd12) && (ty == 5'd1))
                            slot4_tile_raw = TILE_FIRE_DOOR;
                        else if ((tx == 5'd21) && (ty == 5'd1))
                            slot4_tile_raw = TILE_WATER_DOOR;
                        else if (((tx == 5'd6) && (ty == 5'd3)) ||
                                 ((tx == 5'd20) && (ty == 5'd18)))
                            slot4_tile_raw = TILE_FIRE_GEM;
                        else if (((tx == 5'd25) && (ty == 5'd3)) ||
                                 ((tx == 5'd8) && (ty == 5'd18)))
                            slot4_tile_raw = TILE_WATER_GEM;
                        else if ((tx == 5'd15) && (ty >= 5'd6) && (ty <= 5'd10))
                            slot4_tile_raw = TILE_GATE;
                        else if ((tx == 5'd11) && (ty == 5'd12))
                            slot4_tile_raw = TILE_BUTTON;
                        else if ((ty == 5'd4) && (((tx >= 5'd4) && (tx <= 5'd9)) ||
                                                   ((tx >= 5'd23) && (tx <= 5'd28))))
                            slot4_tile_raw = TILE_WALL;
                        else if ((ty == 5'd7) && (((tx >= 5'd2) && (tx <= 5'd6)) ||
                                                   ((tx >= 5'd24) && (tx <= 5'd29))))
                            slot4_tile_raw = TILE_WALL;
                        else if ((ty == 5'd9) && (tx >= 5'd8) && (tx <= 5'd11))
                            slot4_tile_raw = TILE_FIRE;
                        else if ((ty == 5'd9) && (tx >= 5'd21) && (tx <= 5'd24))
                            slot4_tile_raw = TILE_WATER;
                        else if ((ty == 5'd10) && (((tx >= 5'd6) && (tx <= 5'd14)) ||
                                                    ((tx >= 5'd16) && (tx <= 5'd25))))
                            slot4_tile_raw = TILE_WALL;
                        else if ((ty == 5'd13) && (tx >= 5'd8) && (tx <= 5'd13))
                            slot4_tile_raw = TILE_WALL;
                        else if ((ty == 5'd15) && (((tx >= 5'd4) && (tx <= 5'd7)) ||
                                                    ((tx >= 5'd23) && (tx <= 5'd26))))
                            slot4_tile_raw = TILE_POISON;
                        else if ((ty == 5'd16) && (((tx >= 5'd2) && (tx <= 5'd9)) ||
                                                    ((tx >= 5'd21) && (tx <= 5'd29))))
                            slot4_tile_raw = TILE_WALL;
                        else if ((ty == 5'd19) && (((tx >= 5'd4) && (tx <= 5'd9)) ||
                                                    ((tx >= 5'd18) && (tx <= 5'd23))))
                            slot4_tile_raw = TILE_WALL;
                    end
                    default: begin
                        if ((tx == 5'd10) && (ty == 5'd1))
                            slot4_tile_raw = TILE_FIRE_DOOR;
                        else if ((tx == 5'd21) && (ty == 5'd1))
                            slot4_tile_raw = TILE_WATER_DOOR;
                        else if (((tx == 5'd5) && (ty == 5'd3)) ||
                                 ((tx == 5'd21) && (ty == 5'd12)))
                            slot4_tile_raw = TILE_FIRE_GEM;
                        else if (((tx == 5'd26) && (ty == 5'd3)) ||
                                 ((tx == 5'd8) && (ty == 5'd12)))
                            slot4_tile_raw = TILE_WATER_GEM;
                        else if (((tx == 5'd8) || (tx == 5'd24)) && (ty >= 5'd6) && (ty <= 5'd9))
                            slot4_tile_raw = TILE_GATE;
                        else if (((tx == 5'd5) && (ty == 5'd6)) ||
                                 ((tx == 5'd26) && (ty == 5'd6)))
                            slot4_tile_raw = TILE_BUTTON;
                        else if ((ty == 5'd3) && (tx == 5'd14))
                            slot4_tile_raw = TILE_POISON;
                        else if ((ty == 5'd4) && (((tx >= 5'd3) && (tx <= 5'd8)) ||
                                                   ((tx >= 5'd20) && (tx <= 5'd27))))
                            slot4_tile_raw = TILE_WALL;
                        else if ((ty == 5'd7) && (((tx >= 5'd2) && (tx <= 5'd6)) ||
                                                   ((tx >= 5'd25) && (tx <= 5'd29))))
                            slot4_tile_raw = TILE_WALL;
                        else if ((ty == 5'd9) && (tx >= 5'd4) && (tx <= 5'd7))
                            slot4_tile_raw = TILE_FIRE;
                        else if ((ty == 5'd9) && (tx >= 5'd23) && (tx <= 5'd26))
                            slot4_tile_raw = TILE_WATER;
                        else if ((ty == 5'd9) && (tx >= 5'd14) && (tx <= 5'd17))
                            slot4_tile_raw = TILE_POISON;
                        else if ((ty == 5'd10) && (((tx >= 5'd2) && (tx <= 5'd10)) ||
                                                    ((tx >= 5'd13) && (tx <= 5'd18)) ||
                                                    ((tx >= 5'd21) && (tx <= 5'd29))))
                            slot4_tile_raw = TILE_WALL;
                        else if ((ty == 5'd13) && (((tx >= 5'd4) && (tx <= 5'd9)) ||
                                                    ((tx >= 5'd20) && (tx <= 5'd25))))
                            slot4_tile_raw = TILE_WALL;
                        else if ((ty == 5'd15) && (tx >= 5'd10) && (tx <= 5'd13))
                            slot4_tile_raw = TILE_FIRE;
                        else if ((ty == 5'd15) && (tx >= 5'd18) && (tx <= 5'd21))
                            slot4_tile_raw = TILE_WATER;
                        else if ((ty == 5'd16) && (tx >= 5'd8) && (tx <= 5'd23))
                            slot4_tile_raw = TILE_WALL;
                        else if ((ty == 5'd18) && (((tx >= 5'd4) && (tx <= 5'd7)) ||
                                                    ((tx >= 5'd23) && (tx <= 5'd26))))
                            slot4_tile_raw = TILE_POISON;
                        else if ((ty == 5'd19) && (((tx >= 5'd2) && (tx <= 5'd9)) ||
                                                    ((tx >= 5'd22) && (tx <= 5'd29))))
                            slot4_tile_raw = TILE_WALL;
                    end
                endcase
            end
        end
    endfunction

    function slot4_is_solid_tile;
        input [3:0] tile;
        input open_gate;
        begin
            slot4_is_solid_tile = (tile == TILE_WALL) || ((tile == TILE_GATE) && !open_gate);
        end
    endfunction

    function [3:0] slot4_tile_at_pixel;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        reg [4:0] tx;
        reg [4:0] ty;
        begin
            if ((px >= SCREEN_W) || (py >= SCREEN_H)) begin
                slot4_tile_at_pixel = TILE_WALL;
            end else begin
                tx = px / CELL;
                ty = py / CELL;
                slot4_tile_at_pixel = slot4_tile_raw(lvl, tx, ty);
            end
        end
    endfunction

    function slot4_solid_at;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        input open_gate;
        begin
            slot4_solid_at = slot4_is_solid_tile(slot4_tile_at_pixel(lvl, px, py), open_gate);
        end
    endfunction

    function slot4_player_solid;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        input open_gate;
        begin
            slot4_player_solid =
                slot4_solid_at(lvl, px, py, open_gate) ||
                slot4_solid_at(lvl, px + PLAYER_W - 1, py, open_gate) ||
                slot4_solid_at(lvl, px, py + PLAYER_H - 1, open_gate) ||
                slot4_solid_at(lvl, px + PLAYER_W - 1, py + PLAYER_H - 1, open_gate);
        end
    endfunction

    function slot4_player_touch_tile;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        input [3:0] tile;
        begin
            slot4_player_touch_tile =
                (slot4_tile_at_pixel(lvl, px, py) == tile) ||
                (slot4_tile_at_pixel(lvl, px + PLAYER_W - 1, py) == tile) ||
                (slot4_tile_at_pixel(lvl, px, py + PLAYER_H - 1) == tile) ||
                (slot4_tile_at_pixel(lvl, px + PLAYER_W - 1, py + PLAYER_H - 1) == tile);
        end
    endfunction

    function slot4_fire_bad;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        begin
            slot4_fire_bad = slot4_player_touch_tile(lvl, px, py, TILE_WATER) ||
                             slot4_player_touch_tile(lvl, px, py, TILE_POISON);
        end
    endfunction

    function slot4_water_bad;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        begin
            slot4_water_bad = slot4_player_touch_tile(lvl, px, py, TILE_FIRE) ||
                              slot4_player_touch_tile(lvl, px, py, TILE_POISON);
        end
    endfunction

    function slot4_player_over_cell;
        input [9:0] px;
        input [9:0] py;
        input [4:0] tx;
        input [4:0] ty;
        reg [9:0] cell_left;
        reg [9:0] cell_top;
        begin
            cell_left = tx * CELL;
            cell_top = ty * CELL;
            slot4_player_over_cell =
                (px + PLAYER_W > cell_left) && (px < cell_left + CELL) &&
                (py + PLAYER_H > cell_top) && (py < cell_top + CELL);
        end
    endfunction

    function [3:0] slot4_fire_pick_mask;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        begin
            slot4_fire_pick_mask = 4'b0000;
            case (lvl)
                2'd0: begin
                    if (slot4_player_over_cell(px, py, 5'd9, 5'd3))
                        slot4_fire_pick_mask[0] = 1'b1;
                    if (slot4_player_over_cell(px, py, 5'd11, 5'd12))
                        slot4_fire_pick_mask[1] = 1'b1;
                end
                2'd1: begin
                    if (slot4_player_over_cell(px, py, 5'd6, 5'd3))
                        slot4_fire_pick_mask[0] = 1'b1;
                    if (slot4_player_over_cell(px, py, 5'd20, 5'd18))
                        slot4_fire_pick_mask[1] = 1'b1;
                end
                default: begin
                    if (slot4_player_over_cell(px, py, 5'd5, 5'd3))
                        slot4_fire_pick_mask[0] = 1'b1;
                    if (slot4_player_over_cell(px, py, 5'd21, 5'd12))
                        slot4_fire_pick_mask[1] = 1'b1;
                end
            endcase
        end
    endfunction

    function [3:0] slot4_water_pick_mask;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        begin
            slot4_water_pick_mask = 4'b0000;
            case (lvl)
                2'd0: begin
                    if (slot4_player_over_cell(px, py, 5'd22, 5'd3))
                        slot4_water_pick_mask[0] = 1'b1;
                    if (slot4_player_over_cell(px, py, 5'd20, 5'd12))
                        slot4_water_pick_mask[1] = 1'b1;
                end
                2'd1: begin
                    if (slot4_player_over_cell(px, py, 5'd25, 5'd3))
                        slot4_water_pick_mask[0] = 1'b1;
                    if (slot4_player_over_cell(px, py, 5'd8, 5'd18))
                        slot4_water_pick_mask[1] = 1'b1;
                end
                default: begin
                    if (slot4_player_over_cell(px, py, 5'd26, 5'd3))
                        slot4_water_pick_mask[0] = 1'b1;
                    if (slot4_player_over_cell(px, py, 5'd8, 5'd12))
                        slot4_water_pick_mask[1] = 1'b1;
                end
            endcase
        end
    endfunction

    function [1:0] slot4_button_pick_mask;
        input [1:0] lvl;
        input [9:0] fx;
        input [9:0] fy;
        input [9:0] wx;
        input [9:0] wy;
        begin
            slot4_button_pick_mask = 2'b00;
            if (lvl == 2'd1) begin
                if (slot4_player_over_cell(fx, fy, 5'd11, 5'd12) ||
                    slot4_player_over_cell(wx, wy, 5'd11, 5'd12))
                    slot4_button_pick_mask[0] = 1'b1;
            end else if (lvl == 2'd2) begin
                if (slot4_player_over_cell(fx, fy, 5'd5, 5'd6) ||
                    slot4_player_over_cell(wx, wy, 5'd5, 5'd6))
                    slot4_button_pick_mask[0] = 1'b1;
                if (slot4_player_over_cell(fx, fy, 5'd26, 5'd6) ||
                    slot4_player_over_cell(wx, wy, 5'd26, 5'd6))
                    slot4_button_pick_mask[1] = 1'b1;
            end
        end
    endfunction

    function slot4_fire_gem_collected;
        input [1:0] lvl;
        input [4:0] tx;
        input [4:0] ty;
        input [3:0] mask;
        begin
            slot4_fire_gem_collected = 1'b0;
            case (lvl)
                2'd0: begin
                    if ((tx == 5'd9) && (ty == 5'd3))
                        slot4_fire_gem_collected = mask[0];
                    else if ((tx == 5'd11) && (ty == 5'd12))
                        slot4_fire_gem_collected = mask[1];
                end
                2'd1: begin
                    if ((tx == 5'd6) && (ty == 5'd3))
                        slot4_fire_gem_collected = mask[0];
                    else if ((tx == 5'd20) && (ty == 5'd18))
                        slot4_fire_gem_collected = mask[1];
                end
                default: begin
                    if ((tx == 5'd5) && (ty == 5'd3))
                        slot4_fire_gem_collected = mask[0];
                    else if ((tx == 5'd21) && (ty == 5'd12))
                        slot4_fire_gem_collected = mask[1];
                end
            endcase
        end
    endfunction

    function slot4_water_gem_collected;
        input [1:0] lvl;
        input [4:0] tx;
        input [4:0] ty;
        input [3:0] mask;
        begin
            slot4_water_gem_collected = 1'b0;
            case (lvl)
                2'd0: begin
                    if ((tx == 5'd22) && (ty == 5'd3))
                        slot4_water_gem_collected = mask[0];
                    else if ((tx == 5'd20) && (ty == 5'd12))
                        slot4_water_gem_collected = mask[1];
                end
                2'd1: begin
                    if ((tx == 5'd25) && (ty == 5'd3))
                        slot4_water_gem_collected = mask[0];
                    else if ((tx == 5'd8) && (ty == 5'd18))
                        slot4_water_gem_collected = mask[1];
                end
                default: begin
                    if ((tx == 5'd26) && (ty == 5'd3))
                        slot4_water_gem_collected = mask[0];
                    else if ((tx == 5'd8) && (ty == 5'd12))
                        slot4_water_gem_collected = mask[1];
                end
            endcase
        end
    endfunction

    function [6:0] slot4_seg_digit;
        input [3:0] digit;
        begin
            case (digit)
                4'd0: slot4_seg_digit = 7'b0000001;
                4'd1: slot4_seg_digit = 7'b1001111;
                4'd2: slot4_seg_digit = 7'b0010010;
                4'd3: slot4_seg_digit = 7'b0000110;
                4'd4: slot4_seg_digit = 7'b1001100;
                4'd5: slot4_seg_digit = 7'b0100100;
                4'd6: slot4_seg_digit = 7'b0100000;
                4'd7: slot4_seg_digit = 7'b0001111;
                4'd8: slot4_seg_digit = 7'b0000000;
                4'd9: slot4_seg_digit = 7'b0000100;
                default: slot4_seg_digit = 7'b1111111;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (reset) begin
            level <= 2'd0;
            won <= 1'b0;
            fire_x <= slot4_fire_start_x(2'd0);
            fire_y <= slot4_fire_start_y(2'd0);
            water_x <= slot4_water_start_x(2'd0);
            water_y <= slot4_water_start_y(2'd0);
            fire_vy <= 6'sd0;
            water_vy <= 6'sd0;
            fire_gems <= 4'b0000;
            water_gems <= 4'b0000;
            button_mask <= 2'b00;
            frame_counter <= 24'd0;
        end else if (selected && frame_tick) begin
            frame_counter <= frame_counter + 24'd1;

            if (btn_c) begin
                fire_x <= slot4_fire_start_x(level);
                fire_y <= slot4_fire_start_y(level);
                water_x <= slot4_water_start_x(level);
                water_y <= slot4_water_start_y(level);
                fire_vy <= 6'sd0;
                water_vy <= 6'sd0;
                fire_gems <= 4'b0000;
                water_gems <= 4'b0000;
                button_mask <= 2'b00;
                won <= 1'b0;
            end else if (!won) begin
                fire_gems <= fire_gems | slot4_fire_pick_mask(level, fire_x, fire_y);
                water_gems <= water_gems | slot4_water_pick_mask(level, water_x, water_y);
                button_mask <= button_mask | slot4_button_pick_mask(level, fire_x, fire_y, water_x, water_y);

                if (level_failed) begin
                    fire_x <= slot4_fire_start_x(level);
                    fire_y <= slot4_fire_start_y(level);
                    water_x <= slot4_water_start_x(level);
                    water_y <= slot4_water_start_y(level);
                    fire_vy <= 6'sd0;
                    water_vy <= 6'sd0;
                    fire_gems <= 4'b0000;
                    water_gems <= 4'b0000;
                    button_mask <= 2'b00;
                end else if (level_complete) begin
                    if (level == 2'd2) begin
                        won <= 1'b1;
                    end else begin
                        next_level = level + 2'd1;
                        level <= next_level;
                        fire_x <= slot4_fire_start_x(next_level);
                        fire_y <= slot4_fire_start_y(next_level);
                        water_x <= slot4_water_start_x(next_level);
                        water_y <= slot4_water_start_y(next_level);
                        fire_vy <= 6'sd0;
                        water_vy <= 6'sd0;
                        fire_gems <= 4'b0000;
                        water_gems <= 4'b0000;
                        button_mask <= 2'b00;
                    end
                end else begin
                    fire_x_calc = fire_x;
                    if (fire_left_cmd && !fire_right_cmd) begin
                        fire_x_calc = (fire_x > MOVE_STEP) ? fire_x - MOVE_STEP : 10'd1;
                    end else if (fire_right_cmd && !fire_left_cmd) begin
                        fire_x_calc = (fire_x < SCREEN_W - PLAYER_W - MOVE_STEP) ?
                                      fire_x + MOVE_STEP :
                                      SCREEN_W - PLAYER_W - 1;
                    end

                    if (!slot4_player_solid(level, fire_x_calc, fire_y, gate_open))
                        fire_x <= fire_x_calc;

                    water_x_calc = water_x;
                    if (water_left_cmd && !water_right_cmd) begin
                        water_x_calc = (water_x > MOVE_STEP) ? water_x - MOVE_STEP : 10'd1;
                    end else if (water_right_cmd && !water_left_cmd) begin
                        water_x_calc = (water_x < SCREEN_W - PLAYER_W - MOVE_STEP) ?
                                       water_x + MOVE_STEP :
                                       SCREEN_W - PLAYER_W - 1;
                    end

                    if (!slot4_player_solid(level, water_x_calc, water_y, gate_open))
                        water_x <= water_x_calc;

                    fire_vy_calc = fire_vy;
                    if (fire_jump_cmd && fire_grounded) begin
                        fire_vy_calc = JUMP_VEL;
                    end else if (fire_vy < MAX_FALL) begin
                        fire_vy_calc = fire_vy + GRAVITY;
                    end

                    fire_y_calc = $signed({2'b00, fire_y}) + {{6{fire_vy_calc[5]}}, fire_vy_calc};
                    if (fire_y_calc < 12'sd1) begin
                        fire_y <= 10'd1;
                        fire_vy <= 6'sd0;
                    end else if (fire_y_calc > SCREEN_H - PLAYER_H - 1) begin
                        fire_y <= SCREEN_H - PLAYER_H - 1;
                        fire_vy <= 6'sd0;
                    end else if (!slot4_player_solid(level, fire_x, fire_y_calc[9:0], gate_open)) begin
                        fire_y <= fire_y_calc[9:0];
                        fire_vy <= fire_vy_calc;
                    end else begin
                        fire_vy <= 6'sd0;
                    end

                    water_vy_calc = water_vy;
                    if (water_jump_cmd && water_grounded) begin
                        water_vy_calc = JUMP_VEL;
                    end else if (water_vy < MAX_FALL) begin
                        water_vy_calc = water_vy + GRAVITY;
                    end

                    water_y_calc = $signed({2'b00, water_y}) + {{6{water_vy_calc[5]}}, water_vy_calc};
                    if (water_y_calc < 12'sd1) begin
                        water_y <= 10'd1;
                        water_vy <= 6'sd0;
                    end else if (water_y_calc > SCREEN_H - PLAYER_H - 1) begin
                        water_y <= SCREEN_H - PLAYER_H - 1;
                        water_vy <= 6'sd0;
                    end else if (!slot4_player_solid(level, water_x, water_y_calc[9:0], gate_open)) begin
                        water_y <= water_y_calc[9:0];
                        water_vy <= water_vy_calc;
                    end else begin
                        water_vy <= 6'sd0;
                    end
                end
            end
        end
    end

    always @(*) begin
        cell_x = pixel_x / CELL;
        cell_y = pixel_y / CELL;
        local_x = pixel_x - (cell_x * CELL);
        local_y = pixel_y - (cell_y * CELL);
        draw_tile = slot4_tile_raw(level, cell_x, cell_y);

        if ((draw_tile == TILE_FIRE_GEM) && slot4_fire_gem_collected(level, cell_x, cell_y, fire_gems))
            draw_tile = TILE_EMPTY;
        else if ((draw_tile == TILE_WATER_GEM) && slot4_water_gem_collected(level, cell_x, cell_y, water_gems))
            draw_tile = TILE_EMPTY;
        else if ((draw_tile == TILE_GATE) && gate_open)
            draw_tile = TILE_EMPTY;

        if (!display_active || !selected) begin
            vga_r = 4'h0;
            vga_g = 4'h0;
            vga_b = 4'h0;
        end else if (won) begin
            vga_r = pixel_x[5] ^ pixel_y[4] ? 4'hF : 4'h2;
            vga_g = pixel_x[6] ^ frame_counter[4] ? 4'hD : 4'h4;
            vga_b = pixel_y[5] ^ frame_counter[3] ? 4'h7 : 4'hF;
        end else if (fire_eye || water_eye) begin
            vga_r = 4'h1;
            vga_g = 4'h1;
            vga_b = 4'h1;
        end else if (fire_pixel) begin
            if (pixel_y < fire_y + 10'd4) begin
                vga_r = 4'hF;
                vga_g = 4'hC;
                vga_b = 4'h2;
            end else begin
                vga_r = 4'hE;
                vga_g = 4'h3 + frame_counter[3];
                vga_b = 4'h1;
            end
        end else if (water_pixel) begin
            if (pixel_y < water_y + 10'd4) begin
                vga_r = 4'h9;
                vga_g = 4'hF;
                vga_b = 4'hF;
            end else begin
                vga_r = 4'h1;
                vga_g = 4'h8;
                vga_b = 4'hF;
            end
        end else begin
            vga_r = 4'h0;
            vga_g = 4'h1 + {2'b00, pixel_y[6:5]};
            vga_b = 4'h3 + {2'b00, pixel_x[6:5]};

            case (draw_tile)
                TILE_WALL: begin
                    if ((local_x == 5'd0) || (local_y == 5'd0) ||
                        (local_x == 5'd19) || (local_y == 5'd19)) begin
                        vga_r = 4'h9;
                        vga_g = 4'h9;
                        vga_b = 4'h9;
                    end else if (local_y < 5'd4) begin
                        vga_r = 4'h6;
                        vga_g = 4'h6;
                        vga_b = 4'h7;
                    end else begin
                        vga_r = 4'h3;
                        vga_g = 4'h3;
                        vga_b = 4'h4;
                    end
                end
                TILE_FIRE: begin
                    vga_r = 4'hF;
                    vga_g = (local_y[2] ^ frame_counter[3]) ? 4'h6 : 4'h2;
                    vga_b = 4'h0;
                end
                TILE_WATER: begin
                    vga_r = 4'h0;
                    vga_g = (local_x[2] ^ frame_counter[3]) ? 4'h9 : 4'hC;
                    vga_b = 4'hF;
                end
                TILE_POISON: begin
                    vga_r = 4'h3;
                    vga_g = (local_x[2] ^ local_y[2] ^ frame_counter[3]) ? 4'hF : 4'h9;
                    vga_b = 4'h2;
                end
                TILE_FIRE_GEM: begin
                    if ((local_x >= 5'd5) && (local_x <= 5'd14) &&
                        (local_y >= 5'd4) && (local_y <= 5'd15)) begin
                        vga_r = 4'hF;
                        vga_g = 4'h6 + frame_counter[3];
                        vga_b = 4'h2;
                    end
                end
                TILE_WATER_GEM: begin
                    if ((local_x >= 5'd5) && (local_x <= 5'd14) &&
                        (local_y >= 5'd4) && (local_y <= 5'd15)) begin
                        vga_r = 4'h4;
                        vga_g = 4'hC;
                        vga_b = 4'hF;
                    end
                end
                TILE_FIRE_DOOR: begin
                    if ((local_x < 5'd3) || (local_x > 5'd16) || (local_y < 5'd3)) begin
                        vga_r = 4'hF;
                        vga_g = 4'h4;
                        vga_b = 4'h1;
                    end else begin
                        vga_r = 4'h5;
                        vga_g = 4'h1;
                        vga_b = 4'h0;
                    end
                end
                TILE_WATER_DOOR: begin
                    if ((local_x < 5'd3) || (local_x > 5'd16) || (local_y < 5'd3)) begin
                        vga_r = 4'h2;
                        vga_g = 4'hC;
                        vga_b = 4'hF;
                    end else begin
                        vga_r = 4'h0;
                        vga_g = 4'h2;
                        vga_b = 4'h6;
                    end
                end
                TILE_BUTTON: begin
                    if ((local_y >= 5'd12) && (local_y <= 5'd16) &&
                        (local_x >= 5'd4) && (local_x <= 5'd15)) begin
                        vga_r = gate_open ? 4'h5 : 4'hF;
                        vga_g = gate_open ? 4'hF : 4'hD;
                        vga_b = 4'h2;
                    end
                end
                TILE_GATE: begin
                    if ((local_x < 5'd5) || (local_x > 5'd14)) begin
                        vga_r = 4'hB;
                        vga_g = 4'hC;
                        vga_b = 4'hD;
                    end else begin
                        vga_r = 4'h4;
                        vga_g = 4'h5;
                        vga_b = 4'h7;
                    end
                end
                default: begin
                    if ((local_x == 5'd0) || (local_y == 5'd0)) begin
                        vga_r = 4'h0;
                        vga_g = 4'h0;
                        vga_b = 4'h2;
                    end
                end
            endcase
        end
    end

    always @(*) begin
        if (!selected) begin
            seg_n = 7'b1111111;
        end else if (won) begin
            seg_n = slot4_seg_digit(4'd8);
        end else begin
            seg_n = slot4_seg_digit({2'b00, level} + 4'd1);
        end
    end

    assign led = selected ? {
        won,
        gate_open,
        button_mask,
        water_gems[1:0],
        fire_gems[1:0],
        4'b0000,
        level,
        fire_grounded,
        water_grounded
    } : 16'h0000;

    assign an = selected ? 8'b1111_1110 : 8'b1111_1111;
    assign {ca, cb, cc, cd, ce, cf, cg} = seg_n;
    assign dp = 1'b1;
    assign buzzer = 1'b1 | unused_inputs;

endmodule

module slot4_ps2_rx (
    input  wire       clk,
    input  wire       reset,
    input  wire       ps2_clk,
    input  wire       ps2_data,
    output reg        byte_ready,
    output reg  [7:0] byte_data
);

    reg ps2_clk_ff0;
    reg ps2_clk_ff1;
    reg ps2_data_ff0;
    reg ps2_data_ff1;
    reg [3:0] bit_count;
    reg [7:0] shift_data;

    wire ps2_clk_fall;

    assign ps2_clk_fall = ps2_clk_ff1 & ~ps2_clk_ff0;

    always @(posedge clk) begin
        if (reset) begin
            ps2_clk_ff0 <= 1'b1;
            ps2_clk_ff1 <= 1'b1;
            ps2_data_ff0 <= 1'b1;
            ps2_data_ff1 <= 1'b1;
            bit_count <= 4'd0;
            shift_data <= 8'd0;
            byte_ready <= 1'b0;
            byte_data <= 8'd0;
        end else begin
            ps2_clk_ff0 <= ps2_clk;
            ps2_clk_ff1 <= ps2_clk_ff0;
            ps2_data_ff0 <= ps2_data;
            ps2_data_ff1 <= ps2_data_ff0;
            byte_ready <= 1'b0;

            if (ps2_clk_fall) begin
                case (bit_count)
                    4'd0: begin
                        if (ps2_data_ff1 == 1'b0)
                            bit_count <= 4'd1;
                    end
                    4'd1: begin shift_data[0] <= ps2_data_ff1; bit_count <= 4'd2; end
                    4'd2: begin shift_data[1] <= ps2_data_ff1; bit_count <= 4'd3; end
                    4'd3: begin shift_data[2] <= ps2_data_ff1; bit_count <= 4'd4; end
                    4'd4: begin shift_data[3] <= ps2_data_ff1; bit_count <= 4'd5; end
                    4'd5: begin shift_data[4] <= ps2_data_ff1; bit_count <= 4'd6; end
                    4'd6: begin shift_data[5] <= ps2_data_ff1; bit_count <= 4'd7; end
                    4'd7: begin shift_data[6] <= ps2_data_ff1; bit_count <= 4'd8; end
                    4'd8: begin shift_data[7] <= ps2_data_ff1; bit_count <= 4'd9; end
                    4'd9: begin bit_count <= 4'd10; end
                    4'd10: begin
                        if (ps2_data_ff1 == 1'b1) begin
                            byte_data <= shift_data;
                            byte_ready <= 1'b1;
                        end
                        bit_count <= 4'd0;
                    end
                    default: bit_count <= 4'd0;
                endcase
            end
        end
    end

endmodule

module slot4_keyboard_mapper (
    input  wire       clk,
    input  wire       reset,
    input  wire       byte_ready,
    input  wire [7:0] byte_data,
    output reg        fire_left,
    output reg        fire_right,
    output reg        fire_jump,
    output reg        water_left,
    output reg        water_right,
    output reg        water_jump
);

    localparam [7:0] SCAN_F0    = 8'hF0;
    localparam [7:0] SCAN_E0    = 8'hE0;
    localparam [7:0] SCAN_W     = 8'h1D;
    localparam [7:0] SCAN_A     = 8'h1C;
    localparam [7:0] SCAN_D     = 8'h23;
    localparam [7:0] SCAN_UP    = 8'h75;
    localparam [7:0] SCAN_LEFT  = 8'h6B;
    localparam [7:0] SCAN_RIGHT = 8'h74;

    reg break_pending;
    reg extend_pending;

    always @(posedge clk) begin
        if (reset) begin
            fire_left <= 1'b0;
            fire_right <= 1'b0;
            fire_jump <= 1'b0;
            water_left <= 1'b0;
            water_right <= 1'b0;
            water_jump <= 1'b0;
            break_pending <= 1'b0;
            extend_pending <= 1'b0;
        end else if (byte_ready) begin
            if (byte_data == SCAN_F0) begin
                break_pending <= 1'b1;
            end else if (byte_data == SCAN_E0) begin
                extend_pending <= 1'b1;
            end else begin
                if (extend_pending) begin
                    case (byte_data)
                        SCAN_LEFT:  water_left  <= ~break_pending;
                        SCAN_RIGHT: water_right <= ~break_pending;
                        SCAN_UP:    water_jump  <= ~break_pending;
                        default: begin end
                    endcase
                end else begin
                    case (byte_data)
                        SCAN_A: fire_left  <= ~break_pending;
                        SCAN_D: fire_right <= ~break_pending;
                        SCAN_W: fire_jump  <= ~break_pending;
                        default: begin end
                    endcase
                end

                break_pending <= 1'b0;
                extend_pending <= 1'b0;
            end
        end
    end

endmodule
